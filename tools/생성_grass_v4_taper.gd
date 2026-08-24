extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 taper 텍스처 생성기 (기존 엣지에서 파생 · AI 생성 없음)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_grass_v4_taper.gd [-- --길이=45 --방식=fade]
## 결과:
##   assets/textures/smartshape/grass_v4/taper/{black,white}/taper_<엣지>_<left|right>.png
##   (신규 폴더 · LOCK 된 기존 PNG 는 읽기만 한다)
##
## ▣ 왜 taper 인가 (추측 아님 — 갈라서 재고 정한 것)
##   열 평균 단차 측정 결과:
##     대조군 직선            3.00 /255
##     볼록 · 코너 없음      16.24 /255  @ 코너 꼭짓점
##     볼록 · 현재 구성      13.25 /255  @ 코너 꼭짓점
##     오목 · 코너 없음       4.09 /255
##     오목 · 현재 구성       8.96 /255  @ 코너쿼드 경계(±44.8px)
##   z_index 를 바꿔 코너를 엣지 아래로 내려도 볼록 13.64 로 거의 그대로다.
##   -> 그리는 순서 문제가 아니다. **띠가 꼭짓점에서 그냥 끊기는 것** 이 문제다.
##   끊기지 않게 하려면 띠를 코너 자리 앞에서 알파로 사라지게 해야 하고,
##   SS2D 에서 그걸 하는 정규 수단이 taper 다 (shape.gd:1734 에서 원 쿼드를 실제로 줄인다).
##
## ▣ 코드에서 확인한 taper 규칙 (추측 금지 · 전부 읽고 적음)
##   shape.gd:1730  offset = delta_normal * taper_size   <- Vector2 성분곱
##                  가로 엣지면 길이 = 텍스처 **폭**, 세로 엣지면 길이 = 텍스처 **높이**
##                  -> 정사각 텍스처라야 네 방향 길이가 같다
##   shape.gd:1730  taper_size 에 texture_scale 이 안 곱해진다
##                  -> **텍스처 1px = 월드 1px**. 길이 45 를 원하면 45px 짜리를 만든다
##   shape.gd:1726  taper_quad = quad.duplicate()  -> 띠 **폭은 그대로**(월드 90px)
##                  텍스처 높이는 무엇이든 90px 로 늘어난다
##   edge.gd:354    force_no_tiling = is_tapered  -> UV 0..1 로 늘려 한 번만 그린다
##   shape.gd:1724  fit = taper_size.x <= quad.get_length_average()
##                  안 맞으면 쿼드 **전체**가 taper 텍스처로 바뀐다 (짧은 곡선에서 위험)
##   shape.gd:1618  is_first/last_tess_point 는 `not is_edge_contiguous` 를 요구
##                  -> 4방향(부분 호)에는 걸리고, 코너전용(0~360 폐곡선)에는 안 걸린다. 의도대로다.
##
## ▣ 만드는 방식
##   fade  : 각 열 = 엣지 텍스처의 **행 평균 단면**(u 방향 평균).
##           알파에 코사인 페이드를 곱해 코너 쪽 끝에서 0 이 되게 한다.
##           단면(띠 두께·톤·알파 프로파일)이 그대로 보존되므로 톤이 안 튄다.
##   match : 안쪽 끝은 행 평균 단면, 바깥 끝은 코너가 쓰는 단면(u=0.31)으로 수렴.
##           알파는 안 건드린다.
##
##   흰색은 검정의 휘도 반전으로 만든다 (기존 파이프라인과 같은 규칙 = 구조 대응 보장).
## ============================================================================

const 루트 := "res://assets/textures/smartshape/grass_v4/"
const 출력폴더 := "res://assets/textures/smartshape/grass_v4/taper/"

## 코너 쿼드의 반너비 = 256 * 0.35 * 0.5 = 44.8 월드px. 띠는 그만큼 앞에서 사라져야 한다.
const U_TOP := 0.31
## taper 는 엣지 텍스처를 1:1 로 잘라 온다.
## taper 길이(월드) = N x 배율, 엣지 주기(월드) = 1024 x 배율 -> 배율이 약분된다.
## 그래서 u 폭은 그냥 N / 엣지폭 이다 (배율을 알 필요가 없다).

var _길이 := 45
var _방식 := "fade"
## slicefade 에서 알파를 내리는 바깥 구간의 비율 (0.55 = 바깥 55%%에서만 페이드)
var _페이드구간 := 0.55
## 단면(세로) 해상도. -1 이면 정사각(=길이와 동일). addon 이 세로 엣지 길이를
## 텍스처 높이로 정하기 때문에 정사각이 아니면 방향마다 길이가 달라진다.
var _높이 := -1


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--길이="):
			_길이 = a.substr("--길이=".length()).to_int()
		elif a.begins_with("--높이="):
			_높이 = a.substr("--높이=".length()).to_int()
		elif a.begins_with("--페이드="):
			_페이드구간 = a.substr("--페이드=".length()).to_float()
		elif a.begins_with("--방식="):
			_방식 = a.substr("--방식=".length())
	call_deferred("_실행")


func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		push_error("읽기 실패: %s" % 경로)
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		push_error("디코드 실패: %s" % 경로)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## 엣지 텍스처의 "행 평균 단면".
## 알파 가중으로 휘도를 평균내고 알파는 따로 평균낸다.
## (알파로 안 나누면 반투명한 술 부분이 어둡게 끌려간다)
func _행평균단면(im: Image) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	var 휘도 := PackedFloat64Array(); 휘도.resize(H)
	var 알파 := PackedFloat64Array(); 알파.resize(H)
	for y in H:
		var ls := 0.0
		var asum := 0.0
		for x in W:
			var c := im.get_pixel(x, y)
			ls += c.r * c.a
			asum += c.a
		휘도[y] = ls / maxf(asum, 0.0001)
		알파[y] = asum / float(W)
	return [휘도, 알파]


## 세로 위치 t(0..1) 에서의 단면 값을 선형보간으로 뽑는다.
func _단면샘플(단면: Array, t: float) -> Vector2:
	var 휘도: PackedFloat64Array = 단면[0]
	var 알파: PackedFloat64Array = 단면[1]
	var H := 휘도.size()
	var f: float = clampf(t, 0.0, 1.0) * float(H - 1)
	var i0 := int(floor(f))
	var i1: int = mini(i0 + 1, H - 1)
	var fr := f - float(i0)
	return Vector2(lerp(휘도[i0], 휘도[i1], fr), lerp(알파[i0], 알파[i1], fr))


## 엣지 텍스처의 임의 (u, v) 를 쌍선형으로 뽑는다. u 는 순환, v 는 클램프.
## (코너 합성 apply_final.py sample() 과 같은 규칙)
func _엣지샘플(im: Image, u: float, t: float) -> Vector2:
	var W := im.get_width()
	var H := im.get_height()
	var x := fposmod(u, 1.0) * float(W) - 0.5
	var y: float = clampf(t, 0.0, 1.0) * float(H - 1)
	var x0 := int(floor(x)); var y0 := int(floor(y))
	var fx := x - float(x0); var fy := y - float(y0)
	var x0m := ((x0 % W) + W) % W
	var x1m := (((x0 + 1) % W) + W) % W
	var y0c := clampi(y0, 0, H - 1); var y1c := clampi(y0 + 1, 0, H - 1)
	var a := im.get_pixel(x0m, y0c).lerp(im.get_pixel(x1m, y0c), fx)
	var b := im.get_pixel(x0m, y1c).lerp(im.get_pixel(x1m, y1c), fx)
	var c := a.lerp(b, fy)
	return Vector2(c.r, c.a)


## 코너가 쓰는 단면 = 엣지 텍스처의 u=0.31 열 (쌍선형)
func _코너단면(im: Image, t: float) -> Vector2:
	var W := im.get_width()
	var H := im.get_height()
	var x := fposmod(U_TOP, 1.0) * float(W) - 0.5
	var y: float = clampf(t, 0.0, 1.0) * float(H - 1)
	var x0 := int(floor(x)); var y0 := int(floor(y))
	var fx := x - float(x0); var fy := y - float(y0)
	var x0m := ((x0 % W) + W) % W
	var x1m := (((x0 + 1) % W) + W) % W
	var y0c := clampi(y0, 0, H - 1); var y1c := clampi(y0 + 1, 0, H - 1)
	var a := im.get_pixel(x0m, y0c).lerp(im.get_pixel(x1m, y0c), fx)
	var b := im.get_pixel(x0m, y1c).lerp(im.get_pixel(x1m, y1c), fx)
	var c := a.lerp(b, fy)
	return Vector2(c.r, c.a)


## taper 한 장을 만든다.
## facing_right = true 면 **오른쪽 끝**이 코너 쪽이다.
## 높이 = 단면 해상도. 가로 엣지는 자유롭게 키울 수 있지만 세로 엣지는 길이가
## 높이로 결정돼서 못 키운다 (shape.gd:1730 의 성분곱). _높이 로 그 차이를 실험한다.
func _만들기(엣지: Image, facing_right: bool, 높이: int = -1) -> Image:
	var N := _길이
	var H := 높이 if 높이 > 0 else N
	var 단면 := _행평균단면(엣지)
	var out := Image.create(N, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var t: float = (float(y) + 0.5) / float(H)
		var 평균 := _단면샘플(단면, t)
		var 코너 := _코너단면(엣지, t)
		for x in N:
			# s = 0 이 안쪽(띠 본체 쪽), 1 이 바깥쪽(코너 쪽)
			var s: float = (float(x) + 0.5) / float(N)
			if not facing_right:
				s = 1.0 - s
			var 휘도: float
			var 알파: float
			if _방식 == "slicefade":
				# ★ 채택안. slice 의 그림을 그대로 쓰되, 바깥 끝 일부에서만 알파를 내린다.
				#   - 그림을 평균내지 않으므로 뭉개지지 않는다 (fade 의 실패 원인)
				#   - 바깥 끝에서 띠가 사라지므로 꼭짓점의 단차가 없어진다 (slice 의 실패 원인)
				#   페이드는 바깥 _페이드구간 비율에서만 걸고, 코사인이라 시작점 기울기가 0 이다.
				var u2: float = U_TOP - (1.0 - s) * (float(N) / float(엣지.get_width()))
				var c2 := _엣지샘플(엣지, u2, t)
				휘도 = c2.x
				var k: float = clampf((s - (1.0 - _페이드구간)) / _페이드구간, 0.0, 1.0)
				알파 = c2.y * (0.5 * (1.0 + cos(PI * k)))
			elif _방식 == "slice":
				# ★ 실제 엣지 그림을 그대로 가져온다 (평균내지 않는다).
				#   코너가 쓰는 단면이 u=0.31 이므로, 그 **직전** 구간
				#   u ∈ [0.31 - N/주기, 0.31] 을 잘라 온다.
				#   -> taper 의 바깥 끝이 코너의 경계열과 수식으로 일치한다.
				#   주기 = 1024 * texture_scale(0.35) = 358.4 월드px.
				var u: float = U_TOP - (1.0 - s) * (float(N) / float(엣지.get_width()))
				var c := _엣지샘플(엣지, u, t)
				휘도 = c.x
				알파 = c.y
			elif _방식 == "match":
				# 코너 단면으로 수렴. 알파는 그대로 둔다.
				var w := s * s * (3.0 - 2.0 * s)
				휘도 = lerp(평균.x, 코너.x, w)
				알파 = lerp(평균.y, 코너.y, w)
			else:
				# fade: 단면은 유지하고 알파만 코사인으로 0 까지 내린다.
				# 코사인은 양 끝 기울기가 0 이라 시작/끝에서 단차가 안 생긴다.
				휘도 = 평균.x
				알파 = 평균.y * (0.5 * (1.0 + cos(PI * s)))
			out.set_pixel(x, y, Color(휘도, 휘도, 휘도, clampf(알파, 0.0, 1.0)))
	return out


func _저장(im: Image, 경로: String) -> void:
	var 절대 := ProjectSettings.globalize_path(경로)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	if im.save_png(절대) != OK:
		push_error("저장 실패: %s" % 경로)


## 흰색 = 검정의 휘도 반전 (알파 그대로). 기존 파이프라인과 같은 규칙.
func _반전(im: Image) -> Image:
	var out := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			out.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.r, 1.0 - c.r, c.a))
	return out


func _실행() -> void:
	print("taper 생성: 길이 %d 월드px · 방식 %s" % [_길이, _방식])
	var 엣지들 := ["grass_edge_top", "grass_edge_bottom", "grass_edge_left", "grass_edge_right"]
	var 수 := 0
	for 이름 in 엣지들:
		var im := _png(루트 + "black/" + 이름 + ".png")
		if im == null:
			quit(1)
			return
		# ★ 가로 엣지(top/bottom)는 길이가 텍스처 **폭**으로 정해지므로 높이를 마음껏 키울 수 있다.
		#   세로 엣지(left/right)는 길이가 **높이**로 정해져서 높이를 못 키운다 (addon 성분곱).
		#   이 비대칭이 실제로 화면에 나타나는지 보려고 방향별로 높이를 다르게 굽는다.
		var 높이: int = _높이 if _높이 > 0 else _길이
		for 쪽 in [["right", true], ["left", false]]:
			var t := _만들기(im, 쪽[1], 높이)
			_저장(t, 출력폴더 + "black/taper_%s_%s.png" % [이름.replace("grass_edge_", ""), 쪽[0]])
			_저장(_반전(t), 출력폴더 + "white/taper_%s_%s.png" % [이름.replace("grass_edge_", ""), 쪽[0]])
			수 += 2
	print("  %d 장 저장 (black %d + white %d)" % [수, 수 / 2, 수 / 2])
	print("  ※ LOCK 된 기존 PNG 는 읽기만 했다. 새 폴더에만 썼다.")
	quit(0)
