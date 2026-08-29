extends SceneTree
## ============================================================================
## [2026-08-29 신규] 검정 텍스처의 **흰색 짝**을 만든다 (멱등)
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_흰색짝.gd
##   godot --headless --path . -s res://tools/생성_흰색짝.gd -- \
##       --폴더=res://assets/textures/smartshape --파일=res://assets/tileset/brick_black_seamless_341x307.png
##   (--확인만 을 주면 무엇을 만들지만 찍고 아무것도 안 만든다)
##
## ★만든 뒤에는 반드시 임포트를 한 번 돌려야 게임이 그 PNG 를 읽는다:
##   godot --headless --path . --import
##
## ▣ 왜 필요한가
##   `지형.gd` 는 검정 아트의 **흰색 짝**을 찾아 페인트 셰이더에 물린다.
##   짝이 없으면 셰이더가 밝기 반전으로 때우지만, 그건 어디까지나 **안전망**이고
##   진짜 아트가 아니다(알파·감마 처리가 파이프라인과 미세하게 다르다).
##   그런데 타일셋에 엣지를 **손으로 한 장 추가**하면(예: 성진님의 `edge_top_thin.png`)
##   `생성_타일셋_파생.gd` 를 다시 돌리지 않는 한 흰색 짝이 영영 안 생긴다.
##   실제로 brick_v2_opaque 가 검정 12 장 / 흰색 8 장으로 어긋나 있었고,
##   그 때문에 벽돌 Template 3 종의 윗면 테두리가 칠해지지 않았다.
##   → 손으로 늘어난 것만 골라 짝을 채우는 도구를 따로 둔다.
##
## ▣ 만드는 방식이 두 가지다 (`--방식=`)
##
##   `반전`(기본) : Color(1-r, 1-r, 1-r, a) — 파이프라인(`생성_타일셋_파생.gd _반전()`)과 같은 식.
##   `파임유지`   : 바탕 톤만 뒤집고 **디테일의 명암 방향은 그대로** 둔다.
##
## ▣ 왜 두 번째가 필요한가 (2026-08-29 · 성진님 제보 "그냥 페인트가 덮히는 것처럼 보인다")
##   반전은 **밝은 디테일(하이라이트)** 을 가진 그림에는 맞다 — 잔디의 흰 풀잎, 나무의 결.
##   뒤집으면 어두운 선이 되어 흰 바탕 위에서 잘 읽힌다.
##   그런데 **어두운 디테일(파인 곳)** 을 가진 그림은 반대로 망가진다.
##   벽돌이 그렇다. 검정 벽돌은 벽돌면(0.149)보다 **줄눈이 더 어둡다**(0.0).
##   반전하면 줄눈이 1.0 이 되어 **줄눈이 빛나고** 벽돌면은 회색이 된다
##   → 흰 바탕에 흰 선이라 아무것도 안 읽히고, 흰 물감을 한 겹 부은 것처럼 보인다.
##   (실측: 벽돌 채움은 어두운 디테일 2273 : 밝은 디테일 866 으로 어두운 쪽이 2.6 배)
##
##   `파임유지` 는 이렇게 만든다:  흰색 = (1 - 중앙값) + (r - 중앙값) x 대비
##   중앙값(바탕 톤)은 그대로 뒤집히고, 줄눈은 **바탕보다 어두운 회색 선**으로 남는다.
##   디자이너가 예전 타일맵 흑/백 두 판을 그렸을 때 쓴 것과 같은 문법이다.
##
## ⚠ 아무 데나 쓰면 안 된다. 잔디에 쓰면 흰 풀잎이 날아가 흐릿해진다(눈으로 확인).
##   재질마다 어느 쪽인지는 `--진단` 으로 재 보고 정한다.
##   알파(실루엣)는 두 방식 모두 건드리지 않는다.
##
## ▣ 멱등
##   이미 있는 짝은 건너뛴다. 몇 번을 돌려도 결과가 같다(규약 5).
##   일부러 다시 굽고 싶을 때만 `--덮어쓰기`.
## ============================================================================

const 기본폴더 := "res://assets/textures/smartshape"

var _폴더들: PackedStringArray = PackedStringArray()
var _파일들: PackedStringArray = PackedStringArray()
var _덮어쓰기 := false
var _확인만 := false
## "반전" 또는 "파임유지"
var _방식 := "반전"
## 파임유지에서 디테일을 몇 배로 세게 남길지. 1.0 이면 원본과 같은 폭.
var _대비 := 1.6
## 밝은 디테일 / 어두운 디테일 중 어느 쪽이 우세한지만 재고 끝낸다.
var _진단 := false

var _만듦 := 0
var _건너뜀 := 0
var _실패 := 0


func _init() -> void:
	_인자읽기()
	if _폴더들.is_empty() and _파일들.is_empty():
		_폴더들.push_back(기본폴더)
	call_deferred("_실행")


func _인자읽기() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--폴더="):
			_폴더들.push_back(a.substr(a.find("=") + 1))
		elif a.begins_with("--파일="):
			_파일들.push_back(a.substr(a.find("=") + 1))
		elif a == "--덮어쓰기":
			_덮어쓰기 = true
		elif a == "--확인만":
			_확인만 = true
		elif a == "--진단":
			_진단 = true
		elif a.begins_with("--방식="):
			_방식 = a.substr(a.find("=") + 1)
		elif a.begins_with("--대비="):
			_대비 = a.substr(a.find("=") + 1).to_float()


func _실행() -> void:
	print("\n=== 흰색 짝 생성%s ===" % ("  (확인만)" if _확인만 else ""))
	for 폴더 in _폴더들:
		_폴더_훑기(폴더)
	for 파일 in _파일들:
		_파일_하나(파일)
	print("--- 만듦 %d · 이미 있음 %d · 실패 %d ---" % [_만듦, _건너뜀, _실패])
	if _만듦 > 0 and not _확인만:
		print("★ 임포트를 한 번 돌려야 게임이 읽는다:  godot --headless --path . --import")
	print("")
	quit(1 if _실패 > 0 else 0)


## 폴더 규칙 — 이름이 정확히 `black` 인 폴더 안의 png 마다 `../white/<이름>` 을 채운다.
## (taper/black 도 같은 규칙으로 걸린다)
func _폴더_훑기(뿌리: String) -> void:
	var d := DirAccess.open(뿌리)
	if d == null:
		push_error("폴더를 못 엶: %s" % 뿌리)
		_실패 += 1
		return
	d.list_dir_begin()
	var 이름 := d.get_next()
	while 이름 != "":
		if 이름.begins_with("."):
			이름 = d.get_next()
			continue
		var 경로 := 뿌리.path_join(이름)
		if d.current_is_dir():
			_폴더_훑기(경로)
		elif 이름.get_extension().to_lower() == "png" and 뿌리.get_file() == "black":
			_짝_채우기(경로, "%s/white/%s" % [뿌리.get_base_dir(), 이름])
		이름 = d.get_next()
	d.list_dir_end()


## 파일명 규칙 — `_` 로 끊어 정확히 `black` 인 토막을 `white` 로 바꾼다.
## (지형.gd `_짝_찾기()` 의 1번 규칙과 같은 규칙이다. 어긋나면 만들어도 안 쓰인다)
func _파일_하나(경로: String) -> void:
	var 파일 := 경로.get_file()
	var 조각 := 파일.get_basename().split("_")
	for i in 조각.size():
		if 조각[i] != "black":
			continue
		var 반대 := 조각.duplicate()
		반대[i] = "white"
		_짝_채우기(경로, "%s/%s.%s" % [경로.get_base_dir(), "_".join(반대), 파일.get_extension()])
		return
	push_error("파일명에 black 토막이 없다: %s" % 경로)
	_실패 += 1


func _짝_채우기(검정경로: String, 흰색경로: String) -> void:
	if _진단:
		var 진 := _png(검정경로)
		if 진 != null:
			_진단_찍기(진, 검정경로)
		return
	if FileAccess.file_exists(흰색경로) and not _덮어쓰기:
		_건너뜀 += 1
		return
	var im := _png(검정경로)
	if im == null:
		_실패 += 1
		return
	print("  + %s" % 흰색경로)
	if _확인만:
		_만듦 += 1
		return
	if _저장(_흰색으로(im), 흰색경로):
		_만듦 += 1
	else:
		_실패 += 1


# ── 입출력 · 반전 (생성_타일셋_파생.gd 와 같은 구현) ─────────────────────────
## 임포트 시스템을 거치지 않고 **파일 바이트를 직접** 읽는다.
## 방금 만든 png 는 아직 임포트가 안 됐을 수 있으므로 load() 를 쓰면 안 된다.
func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		push_error("못 읽음: %s" % 경로)
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		push_error("디코드 실패: %s" % 경로)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _저장(im: Image, 경로: String) -> bool:
	var 절대 := ProjectSettings.globalize_path(경로)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	if im.save_png(절대) != OK:
		push_error("저장 실패: %s" % 경로)
		return false
	return true


## 흰색 판 만들기. 알파(실루엣)는 두 방식 모두 그대로 둔다.
func _흰색으로(im: Image) -> Image:
	if _방식 == "파임유지":
		return _파임유지(im)
	return _반전(im)


## 흰색 = 검정의 휘도 반전. (기본 · 파이프라인과 같은 식)
func _반전(im: Image) -> Image:
	var out := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			out.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.r, 1.0 - c.r, c.a))
	return out


## 흰색 = (1 - 중앙값) + (r - 중앙값) x 대비.
## 바탕 톤은 뒤집고, 파인 곳은 **계속 파여 보이게** 둔다.
func _파임유지(im: Image) -> Image:
	var 중앙 := _중앙값(im)
	var 바탕 := 1.0 - 중앙
	var out := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var v := clampf(바탕 + (c.r - 중앙) * _대비, 0.0, 1.0)
			out.set_pixel(x, y, Color(v, v, v, c.a))
	return out


## 불투명 픽셀의 밝기 중앙값 = 이 그림의 **바탕 톤**.
## 256 칸 히스토그램으로 센다 (백만 픽셀을 정렬하면 느리다).
func _중앙값(im: Image) -> float:
	var 칸 := PackedInt32Array()
	칸.resize(256)
	var 총 := 0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			칸[clampi(int(c.r * 255.0), 0, 255)] += 1
			총 += 1
	if 총 == 0:
		return 0.5
	var 누적 := 0
	for i in 256:
		누적 += 칸[i]
		if 누적 * 2 >= 총:
			return float(i) / 255.0
	return 0.5


## 이 그림의 디테일이 바탕보다 **밝은 쪽인가 어두운 쪽인가**.
## 어두운 쪽이 우세하면 반전하면 안 된다 (줄눈이 빛난다).
func _진단_찍기(im: Image, 경로: String) -> void:
	var 중앙 := _중앙값(im)
	var 밝은 := 0.0
	var 어두운 := 0.0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			var d := c.r - 중앙
			if d > 0.0:
				밝은 += d
			else:
				어두운 -= d
	var 판정 := "어두운 디테일(파임) → 파임유지" if 어두운 > 밝은 else "밝은 디테일 → 반전"
	print("  %-30s 중앙 %.3f  밝은 %8.0f : 어두운 %8.0f   %s"
		% [경로.get_file(), 중앙, 밝은, 어두운, 판정])
