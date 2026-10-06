extends SceneTree
## ============================================================================
## [2026-09-27 신규] 방 레이어 수리 — 아스트라 v02 3 장을 게임에 쓸 수 있게 고친다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/수리_방레이어.gd
##
## ▣ 왜 만들었나 (도형님 지시 2026-09-27)
##   `room_layers_v02` 3 장은 그림은 좋은데 **게임 규칙을 네 군데 어긴다.**
##   다시 생성하는 대신 **엔진의 Image API 로 직접 고친다** — 붓질·구도는 그대로 두고
##   규칙을 어긴 픽셀만 손본다. 재생성하면 화풍이 또 달라지기 때문이다.
##
##   ① L1 아래 13 % 에 바닥과 반사가 그려져 있다
##      → 실제 지형 바닥이 그 위에 또 온다. 아래쪽을 어둠으로 녹인다.
##   ② L2·L3 물체 둘레에 옅은 흰 후광이 있다
##      → 밝은 윤곽은 **밟을 수 있는 발판**으로 읽힌다. 반투명 밝은 띠를 죽인다.
##   ③ L3 샹들리에 촛불이 켜져 있다
##      → 이 게임은 **굳은 빛을 실제로 밟는다**. 배경 발광체는 플레이어를 죽인다.
##      → 전경 명도 상한(16 %)으로 눌러 불꽃과 후광을 같이 없앤다.
##   ④ 한 장이 화면 하나밖에 못 덮는다
##      → L1 의 **민무늬 벽 구간을 잘라 좌우 대칭 타일**로 만든다. 이 타일만 반복하고
##        창·문·가구는 비반복으로 드문드문 놓는다(하수도 배경이 쓰는 방식 그대로).
##      → L2 는 **덩어리별로 잘라** 가구 낱장으로 만든다. 방마다 다르게 놓으려면 낱장이어야 한다.
##
## ▣ 원본은 건드리지 않는다
##   읽기: `assets/background/집/room_layers_v02/`  (그대로 둔다)
##   쓰기: `assets/background/집/room_kit_v03/`      (새 폴더)
## ============================================================================

const 입력 := "res://assets/background/집/room_layers_v02/"
const 출력 := "res://assets/background/집/room_kit_v03/"

# ── 규칙 상수 (docs/레벨디자인_가이드.md §5 · 프롬프트 v03 §2) ────────────────
const 전경_명도상한 := 0.13      ## 전경(L3)이 넘으면 안 되는 밝기. 넘으면 발광체로 보인다
const 전경_무릎 := 0.10          ## 이 밝기까지는 그대로 두고, 위쪽만 눌러 압축한다
const 중경_명도상한 := 0.36      ## 중경(L2) 상한. 전경보다는 밝아도 된다
const 후광_알파컷 := 0.10        ## 이보다 옅은 알파는 통째로 0 — 넓게 퍼진 후광의 정체
const 후광_경계알파 := 0.45      ## 이 알파 아래의 가장자리는 밝기를 눌러 흰 테를 없앤다
const 후광_경계명도 := 0.18

# L1 에서 바닥을 녹이기 시작/끝내는 높이(세로 비율). 제작 노트의 바닥선 0.87 보다 조금 위에서 시작.
## ★1 차 실행 결과를 보고 조정(2026-09-27). 0.82 에서 시작하니 바닥과 벽이 만나는
##   **밝은 가로선**이 살아남아 선반처럼 보였다. 더 일찍 시작하고 더 일찍 끝낸다.
const 바닥_페이드시작 := 0.775
const 바닥_페이드끝 := 0.900
# 바닥을 녹여 넣을 색 = 방 벽 아래쪽 어둠
const 바닥_어둠 := Color(0.043, 0.043, 0.048)

# L1 에서 잘라 반복 타일로 쓸 민무늬 벽 구간(가로 비율). 창(0.18~0.43)과 문(0.70~0.88)을 피한다.
const 타일_좌 := 0.455
const 타일_우 := 0.675

# 가구 덩어리를 찾을 때 쓰는 알파 문턱. 이보다 진한 픽셀만 "물체"로 본다.
const 덩어리_알파 := 0.35
const 덩어리_최소픽셀 := 4000    ## 이보다 작은 조각은 먼지·잡티로 보고 버린다
const 덩어리_여백 := 8

## 4 방향 이웃. 타입을 박아 둬야 채우기 안에서 `cx + dxy.x` 의 타입 추론이 산다.
const 이웃4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(출력))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(출력 + "shell/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(출력 + "props/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(출력 + "fg/"))

	print("════════ 방 레이어 수리 ════════")

	# ── L1 ────────────────────────────────────────────────────────────────────
	var l1 := _읽기(입력 + "L1_far_room.png")
	if l1 == null: quit(1); return
	print("\n[L1] %d × %d" % [l1.get_width(), l1.get_height()])
	_바닥_녹이기(l1)
	# ★배경 명도는 15~40 % 대역이다. **45~55 % 는 회색 안전 지형 전용**이라
	#   배경이 거기 들어가면 "밟아도 되는 회색 발판"으로 읽힌다(레벨디자인_가이드 §5).
	#   1 차 촬영에서 벽 아래쪽 징두리 띠가 딱 50 % 로 나와 플레이어 눈높이를 가로질렀다.
	#   창(60~75 %)은 윗대역이라 정상이므로 `면제_이상` 으로 살려 둔다.
	_명도_상한(l1, 0.30, 0.42, 0.58)
	var 타일 := _벽타일_뽑기(l1)          # ★페더를 먹이기 **전에** 타일을 뜬다(타일은 불투명이어야 한다)
	# ★방 스프라이트는 반복 벽 **위에** 드문드문 놓인다. 불투명 사각형 그대로 두면
	#   좌우·위 경계가 화면에 **직선**으로 드러난다(3 차 촬영에서 확인).
	#   가장자리를 알파로 녹이면 뒤의 반복 벽에 스며들어 경계가 사라진다.
	_가장자리_페더(l1, 260, 150)
	_저장(l1, 출력 + "shell/room_far_window_door.png")
	# 반복 타일에는 창이 없다 → 면제 없이 전부 40 % 아래로 누른다
	_명도_상한(타일, 0.26, 0.38, 1.01)
	# ★위·아래를 알파로 녹인다. 배경판(순수 어둠) 위에 세로로 반복하면 이 녹은 띠가
	#   **층과 층 사이 바닥 슬래브**로 읽힌다 — 집이 여러 층인 것이 그냥 표현된다.
	#   녹이지 않고 세로 반복하면 밝은 처마와 검은 바닥이 맞부딪혀 **밝은 가로 띠**가 생긴다
	#   (1 차 촬영에서 실제로 그랬다).
	_세로_페더(타일, 110, 90)
	_저장(타일, 출력 + "shell/wall_tile_repeat.png")

	# ── L2 ────────────────────────────────────────────────────────────────────
	var l2 := _읽기(입력 + "L2_mid_furnishings_stairs.png")
	if l2 == null: quit(1); return
	print("\n[L2] %d × %d" % [l2.get_width(), l2.get_height()])
	_후광_제거(l2, 중경_명도상한, false, 1.0, 0.45)
	_저장(l2, 출력 + "props/_mid_all_cleaned.png")
	_덩어리_쪼개기(l2, 출력 + "props/", "prop")

	# ── L3 ────────────────────────────────────────────────────────────────────
	var l3 := _읽기(입력 + "L3_near_frame.png")
	if l3 == null: quit(1); return
	print("\n[L3] %d × %d" % [l3.get_width(), l3.get_height()])
	# ★샹들리에는 **도려낸다.** 촛불과 그 둘레 후광이 알파 0.1~0.9 에 넓게 물려 있어
	#   밝기만 눌러서는 안 없어진다(2 차 실행에서 확인). 규칙을 어기는 물체 하나만 빼고,
	#   불 꺼진 샹들리에는 v03 프롬프트 C4 로 **낱장 프랍**을 따로 받아 원하는 자리에 놓는다.
	_영역_지우기(l3, Rect2(0.53, 0.00, 0.25, 0.40))
	_후광_제거(l3, 전경_명도상한, true, 4.5)
	_저장(l3, 출력 + "fg/_near_all_cleaned.png")
	_덩어리_쪼개기(l3, 출력 + "fg/", "fg")

	print("\n════════ 끝. 출력: %s ════════" % 출력)
	quit(0)


# ============================================================================
# 입출력
# ============================================================================
## ★`load()` 가 아니라 `Image.load_from_file()` 을 쓴다.
##   `load()` 는 `.import` 를 거쳐 **압축된 텍스처**를 주므로 픽셀을 정확히 못 고친다.
func _읽기(경로: String) -> Image:
	var 절대 := ProjectSettings.globalize_path(경로)
	if not FileAccess.file_exists(절대):
		push_error("파일이 없다: %s" % 절대)
		return null
	var im := Image.load_from_file(절대)
	if im == null:
		push_error("못 읽었다: %s" % 절대)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## 위·아래 가장자리를 알파 0 으로 녹인다(가로는 그대로 — 가로로는 이어 붙여야 하므로).
func _세로_페더(im: Image, 위: int, 아래: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	for y in h:
		var t := 1.0
		if 위 > 0:
			t = minf(t, float(y) / float(위))
		if 아래 > 0:
			t = minf(t, float(h - 1 - y) / float(아래))
		if t >= 1.0:
			continue
		t = clampf(t, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		for x in w:
			var i := (y * w + x) * 4
			d[i + 3] = int(float(d[i + 3]) * t)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  세로 페더: 위 %d px · 아래 %d px" % [위, 아래])


## 좌·우·위 가장자리를 알파 0 으로 녹인다. 아래는 이미 `_바닥_녹이기()` 가 어둠으로
## 처리했으므로 건드리지 않는다(거기까지 투명하게 만들면 바닥이 뚫려 보인다).
func _가장자리_페더(im: Image, 좌우: int, 위: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	for y in h:
		for x in w:
			var t := 1.0
			if 좌우 > 0:
				t = minf(t, minf(float(x), float(w - 1 - x)) / float(좌우))
			if 위 > 0:
				t = minf(t, float(y) / float(위))
			if t >= 1.0:
				continue
			t = clampf(t, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			var i := (y * w + x) * 4
			d[i + 3] = int(float(d[i + 3]) * t)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  가장자리 페더: 좌우 %d px · 위 %d px" % [좌우, 위])


## 명도 상한 — `무릎` 위쪽만 압축해 `상한` 안으로 밀어 넣는다.
## `면제_이상` 보다 밝은 픽셀은 **건드리지 않는다**(창유리처럼 일부러 밝은 윗대역).
func _명도_상한(im: Image, 무릎: float, 상한: float, 면제_이상: float) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var 압축 := (상한 - 무릎) / maxf(면제_이상 - 무릎, 0.001)
	var 누른 := 0
	for p in range(0, d.size(), 4):
		var r := float(d[p])     / 255.0
		var g := float(d[p + 1]) / 255.0
		var b := float(d[p + 2]) / 255.0
		var v := 0.2126 * r + 0.7152 * g + 0.0722 * b
		if v <= 무릎 or v >= 면제_이상:
			continue
		var v2 := 무릎 + (v - 무릎) * 압축
		var k := v2 / maxf(v, 0.0001)
		d[p]     = int(clampf(r * k, 0.0, 1.0) * 255.0)
		d[p + 1] = int(clampf(g * k, 0.0, 1.0) * 255.0)
		d[p + 2] = int(clampf(b * k, 0.0, 1.0) * 255.0)
		누른 += 1
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  명도 상한: %d px 를 %.0f%% 아래로 (%.0f%% 이상은 면제)"
		% [누른, 상한 * 100.0, 면제_이상 * 100.0])


## 규칙을 어기는 물체 하나를 통째로 지운다(알파 0). 사각형은 **비율**로 받는다.
## 가장자리는 부드럽게 빼서 잘린 자국이 안 보이게 한다.
func _영역_지우기(im: Image, 비율: Rect2) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var x0 := int(비율.position.x * w)
	var y0 := int(비율.position.y * h)
	var x1 := int((비율.position.x + 비율.size.x) * w)
	var y1 := int((비율.position.y + 비율.size.y) * h)
	var 깃 := 48.0                                  # 가장자리 페더(px)
	var d := im.get_data()
	for y in range(maxi(y0 - int(깃), 0), mini(y1 + int(깃), h)):
		for x in range(maxi(x0 - int(깃), 0), mini(x1 + int(깃), w)):
			# 사각형 바깥으로 얼마나 벗어났나 → 0 이면 완전히 지우고, 깃 밖이면 그대로 둔다
			var dx := maxf(maxf(float(x0 - x), float(x - x1)), 0.0)
			var dy := maxf(maxf(float(y0 - y), float(y - y1)), 0.0)
			var dist := sqrt(dx * dx + dy * dy)
			if dist >= 깃:
				continue
			var keep := dist / 깃
			keep = keep * keep * (3.0 - 2.0 * keep)
			var i := (y * w + x) * 4
			d[i + 3] = int(float(d[i + 3]) * keep)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  영역 지움: x %d~%d · y %d~%d (샹들리에)" % [x0, x1, y0, y1])


func _저장(im: Image, 경로: String) -> void:
	var 절대 := ProjectSettings.globalize_path(경로)
	var err := im.save_png(절대)
	if err != OK:
		push_error("저장 실패(%d): %s" % [err, 절대])
	else:
		print("  → %s  (%d × %d)" % [경로.get_file(), im.get_width(), im.get_height()])


# ============================================================================
# ① L1 바닥 녹이기
# ----------------------------------------------------------------------------
# 아래쪽을 **자르지 않고 어둠으로 녹인다.** 자르면 그림 끝이 직선으로 보이는데,
# 그 직선이 바로 "밟을 수 있는 선반"으로 읽히는 모양이다(팀 가이드 §6).
# ============================================================================
func _바닥_녹이기(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var y0 := int(h * 바닥_페이드시작)
	var y1 := int(h * 바닥_페이드끝)
	var d := im.get_data()
	for y in range(y0, h):
		# 페이드 구간에서 0 → 1 로 올라가고, 그 아래는 완전히 어둠
		var t := 1.0 if y >= y1 else float(y - y0) / float(maxi(y1 - y0, 1))
		t = t * t * (3.0 - 2.0 * t)          # smoothstep — 경계가 띠로 안 보이게
		for x in w:
			var i := (y * w + x) * 4
			var r := float(d[i])     / 255.0
			var g := float(d[i + 1]) / 255.0
			var b := float(d[i + 2]) / 255.0
			# ★밝은 픽셀은 더 빨리 녹인다. 바닥과 벽이 만나는 밝은 가로선이
			#   페이드 초반에 살아남아 **선반처럼** 보였기 때문이다(1 차 실행에서 확인).
			var v := 0.2126 * r + 0.7152 * g + 0.0722 * b
			var t2 := clampf(t * (1.0 + v * 2.6), 0.0, 1.0)
			d[i]     = int(lerpf(r, 바닥_어둠.r, t2) * 255.0)
			d[i + 1] = int(lerpf(g, 바닥_어둠.g, t2) * 255.0)
			d[i + 2] = int(lerpf(b, 바닥_어둠.b, t2) * 255.0)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  바닥 녹임: y %d~%d (%.0f%% ~ %.0f%%)" % [y0, h, 바닥_페이드시작 * 100.0, 100.0])


# ============================================================================
# ②③ 후광 제거 + 명도 상한
# ----------------------------------------------------------------------------
# 후광의 정체는 **알파가 옅은데 RGB 가 밝은 픽셀**이다. 화면에서는 물체 둘레의
# 뿌연 흰 테로 보이고, 게임에서는 "빛나는 가장자리" = 발판으로 읽힌다.
#   · 아주 옅은 알파(<0.10)는 통째로 0 — 넓게 퍼진 부분을 없앤다
#   · 중간 알파(<0.45)는 밝기를 눌러 흰 테를 죽이되 가장자리 부드러움은 남긴다
#   · 전체 밝기에 상한을 건다 — 무릎 아래는 그대로, 위쪽만 압축(불꽃이 여기서 죽는다)
# ============================================================================
##   `알파_감마` — 반투명 픽셀의 알파를 통째로 눌러 **넓게 퍼진 후광을 지운다.**
##     a' = a^감마 이므로 a=1(물체 본체)은 그대로고, a=0.3(후광)은 감마 2.6 에서 0.03 이 된다.
##     1 차 실행에서 샹들리에 둘레 후광이 알파 0.1~0.5 로 넓게 깔려 살아남았다.
##   `알파_하드컷` — 이 알파 아래를 **통째로 0** 으로 만들고 위쪽을 0~1 로 다시 편다.
##     L2 가구는 물체 둘레에 알파 0.1~0.35 짜리 뿌연 상자가 깔려 있었는데, 낱장으로
##     잘라 내니 그 상자의 **네모난 경계가 화면에 그대로 보였다**(3 차 촬영에서 확인).
##     가구는 실루엣이 단단해서 하드컷을 해도 윤곽이 1~2 px 밖에 안 상한다.
func _후광_제거(im: Image, 명도상한: float, 전경인가: bool, 알파_감마: float = 1.0,
		알파_하드컷: float = 0.0) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var 무릎 := 전경_무릎 if 전경인가 else 명도상한 * 0.7
	var 압축 := (명도상한 - 무릎) / maxf(1.0 - 무릎, 0.001)
	var 자른알파 := 0
	var 누른픽셀 := 0
	for p in range(0, d.size(), 4):
		var a := float(d[p + 3]) / 255.0
		if a <= 0.0:
			continue
		if 알파_하드컷 > 0.0:
			if a < 알파_하드컷:
				d[p + 3] = 0
				자른알파 += 1
				continue
			a = (a - 알파_하드컷) / (1.0 - 알파_하드컷)
			d[p + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
		elif 알파_감마 > 1.0 and a < 0.985:
			a = pow(a, 알파_감마)
			d[p + 3] = int(a * 255.0)
		if a < 후광_알파컷:
			d[p + 3] = 0
			자른알파 += 1
			continue
		var r := float(d[p])     / 255.0
		var g := float(d[p + 1]) / 255.0
		var b := float(d[p + 2]) / 255.0
		var v := 0.2126 * r + 0.7152 * g + 0.0722 * b
		# 밝기 상한 — 무릎 위쪽만 압축한다(어두운 부분의 계조는 그대로 남는다)
		var v2 := v
		if v > 무릎:
			v2 = 무릎 + (v - 무릎) * 압축
		# 가장자리(알파가 옅은 곳)는 한 번 더 눌러 흰 테를 없앤다
		if a < 후광_경계알파:
			v2 = minf(v2, 후광_경계명도)
		if v2 < v - 0.002:
			누른픽셀 += 1
			var k := v2 / maxf(v, 0.0001)
			d[p]     = int(clampf(r * k, 0.0, 1.0) * 255.0)
			d[p + 1] = int(clampf(g * k, 0.0, 1.0) * 255.0)
			d[p + 2] = int(clampf(b * k, 0.0, 1.0) * 255.0)
	im.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	print("  후광 제거: 알파 0 으로 %d px · 밝기 누른 것 %d px (상한 %.0f%%)"
		% [자른알파, 누른픽셀, 명도상한 * 100.0])


# ============================================================================
# ④-1 민무늬 벽 구간 → 좌우 대칭 반복 타일
# ----------------------------------------------------------------------------
# 왜 대칭인가: 잘라낸 조각의 왼끝과 오른끝은 원래 이어지지 않는다. 그대로 반복하면
# 이음매가 세로줄로 보인다. **[조각 | 좌우반전 조각]** 으로 붙이면 이음매가
# 수학적으로 사라진다(양 끝이 서로의 거울이라 값이 같다).
# 대칭이 눈에 띄는 것이 단점이지만, 시차 0.12 로 아주 천천히 흐르는 어두운 벽이라
# 세로줄 이음매보다 훨씬 덜 보인다. 진짜 반복 벽은 v03 프롬프트로 다시 받는다.
# ============================================================================
func _벽타일_뽑기(l1: Image) -> Image:
	var w := l1.get_width()
	var h := l1.get_height()
	var x0 := int(w * 타일_좌)
	var x1 := int(w * 타일_우)
	var sw := x1 - x0
	var 조각 := Image.create_empty(sw, h, false, Image.FORMAT_RGBA8)
	조각.blit_rect(l1, Rect2i(x0, 0, sw, h), Vector2i.ZERO)

	var 반전 := Image.create_empty(sw, h, false, Image.FORMAT_RGBA8)
	반전.blit_rect(l1, Rect2i(x0, 0, sw, h), Vector2i.ZERO)
	반전.flip_x()

	var 타일 := Image.create_empty(sw * 2, h, false, Image.FORMAT_RGBA8)
	타일.blit_rect(조각, Rect2i(0, 0, sw, h), Vector2i.ZERO)
	타일.blit_rect(반전, Rect2i(0, 0, sw, h), Vector2i(sw, 0))
	print("  벽 타일: 원본 x %d~%d 를 잘라 좌우대칭 %d × %d" % [x0, x1, sw * 2, h])
	return 타일


# ============================================================================
# ④-2 알파 덩어리를 낱장으로 쪼갠다
# ----------------------------------------------------------------------------
# 가구가 한 장에 묶여 있으면 방마다 배치를 바꿀 수 없다. 알파가 이어진 덩어리를
# 찾아(4방향 채우기) 각각 잘라 낸다. 원본의 **캔버스 안 위치**를 파일 이름에 적어 두어,
# 나중에 원래 구도 그대로 되돌려 놓을 수도 있게 한다.
# ============================================================================
func _덩어리_쪼개기(im: Image, 폴더: String, 접두: String) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var d := im.get_data()
	var 본것 := PackedByteArray()
	본것.resize(w * h)
	본것.fill(0)

	var 덩어리들: Array = []
	for sy in h:
		for sx in w:
			var si := sy * w + sx
			if 본것[si] == 1:
				continue
			if float(d[si * 4 + 3]) / 255.0 < 덩어리_알파:
				본것[si] = 1
				continue
			# 채우기 — 재귀 대신 스택. 1.5 M 픽셀에서 재귀는 스택이 터진다.
			var 스택: Array[int] = [si]
			본것[si] = 1
			var minx := sx; var maxx := sx
			var miny := sy; var maxy := sy
			var 수 := 0
			while not 스택.is_empty():
				var i: int = 스택.pop_back()
				var cx := i % w
				var cy := i / w
				수 += 1
				if cx < minx: minx = cx
				if cx > maxx: maxx = cx
				if cy < miny: miny = cy
				if cy > maxy: maxy = cy
				# ⚠ 배열 리터럴을 그냥 돌면 원소가 Variant 라 `cx + dxy.x` 의 타입 추론이 깨진다.
				#   (Godot 4.6 파서가 "Cannot infer the type" 으로 거부한다)
				for dxy: Vector2i in 이웃4:
					var nx: int = cx + dxy.x
					var ny: int = cy + dxy.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = ny * w + nx
					if 본것[ni] == 1:
						continue
					if float(d[ni * 4 + 3]) / 255.0 < 덩어리_알파:
						본것[ni] = 1
						continue
					본것[ni] = 1
					스택.append(ni)
			if 수 >= 덩어리_최소픽셀:
				덩어리들.append({"x": minx, "y": miny, "w": maxx - minx + 1,
					"h": maxy - miny + 1, "n": 수})

	# 왼쪽부터 번호를 매긴다 — 사람이 읽을 때 순서가 화면 순서와 같도록
	덩어리들.sort_custom(func(a, b): return a["x"] < b["x"])
	print("  덩어리 %d 개 (최소 %d px 이상)" % [덩어리들.size(), 덩어리_최소픽셀])
	var n := 0
	for c in 덩어리들:
		n += 1
		var x0 := maxi(c["x"] - 덩어리_여백, 0)
		var y0 := maxi(c["y"] - 덩어리_여백, 0)
		var x1 := mini(c["x"] + c["w"] + 덩어리_여백, w)
		var y1 := mini(c["y"] + c["h"] + 덩어리_여백, h)
		var cw := x1 - x0
		var ch := y1 - y0
		var 조각 := Image.create_empty(cw, ch, false, Image.FORMAT_RGBA8)
		조각.blit_rect(im, Rect2i(x0, y0, cw, ch), Vector2i.ZERO)
		# 이름에 원본 캔버스 위치(퍼센트)를 남긴다 — 원래 구도로 되돌릴 때 쓴다
		var 이름 := "%s_%02d_x%03d_y%03d.png" % [접두, n,
			int(round(float(x0) / float(w) * 100.0)),
			int(round(float(y0) / float(h) * 100.0))]
		_저장(조각, 폴더 + 이름)
