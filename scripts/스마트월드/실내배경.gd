@tool
extends Node2D
## ============================================================================
## [2026-08-18 도형 · 신규] 실내 배경 — 거실 → 굴뚝 → 지붕 → 하수도
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나 (도형님 요청 그대로)
##   "앞 부분을 집의 거실 부분 부터, 앞의 중간에 올라가는 부분이 집 안의 굴뚝 부분이야.
##    굴뚝 부분을 올라가면 내가 설명한 지붕의 느낌으로 배경이 자연스럽게 전환 되고
##    그 다음에 지하 하수도로 점차 연결이 되는 느낌으로 연출을 할거야."
##
##   기존 `stage_backdrop.gd` 는 **바깥 풍경** 전용이다(하늘 + 나무 실루엣을
##   왼쪽→오른쪽으로 섞는다). 집 안은 하늘이 없다. 벽이 있고, 그 벽이
##   **위로 올라갈수록** 벽지 → 그을린 벽돌 → 서까래로 바뀐다.
##   → 가로가 아니라 **세로로 섞는** 배경이 필요하다. 그게 이 노드다.
##
## ▣ 어떻게 "자연스럽게" 전환하나
##   두 방 종류를 동시에 그리고 알파로 겹친다. 섞이는 구간(`전환_시작y ~ 전환_끝y`)은
##   **굴뚝 한 칸 높이보다 길게** 잡는다. 짧으면 올라가는 도중 배경이 "탁" 바뀌어
##   컷처럼 보인다 — 씬을 안 가는 이유 자체가 사라진다.
##   섞임 값은 카메라 중심 y 를 쓴다. 플레이어 y 를 쓰면 점프할 때마다 배경이 출렁인다.
##
## ▣ 그림을 코드로 그리는 이유
##   흑백 게임이라 배경은 **명도만** 다루면 된다(레벨디자인_가이드 §5 명도 규칙:
##   배경은 15~40% 대역, 45~55% 는 회색 지형 전용이라 절대 침범 금지).
##   그래서 텍스처 없이 사각형·선만으로 충분하고, 디자이너 그림이 나오면
##   `아트슬롯` 을 꽂아 그대로 대체할 수 있다.
##
## ▣ 성능
##   `_draw()` 는 배경이 바뀔 때만 다시 돈다(섞임 값이 실제로 변했을 때).
##   가만히 서 있으면 다시 안 그린다 — 화면 가득한 배경이라 매 프레임 그리면 비싸다.
## ============================================================================
class_name 실내배경

## ★[2026-08-25] `부엌` 을 **맨 뒤에** 붙였다. 앞에 끼워 넣으면 이미 저장된 씬의
##   `아래_방 = 4`(이층방) 같은 정수값이 통째로 다른 방을 가리키게 된다.
enum 방_ { 거실, 굴뚝, 지붕, 하수도, 이층방, 복도, 부엌 }

## 배경 그림을 `영역` 사각형에 앉히는 법.
enum 맞춤_ {
	덮기,    ## 영역을 꽉 채우는 배율로 키우고, 넘치는 만큼 원본에서 잘라낸다 (빈틈 없음)
	늘이기,  ## 영역에 그대로 늘린다. ★영역을 그림 비율에 맞춰 뒀을 때만 쓸 것(안 그러면 찌그러진다)
	맞추기,  ## 그림 전체가 다 보이게 넣는다. 남는 자리는 검정
}

## 배경이 덮는 영역(월드 좌표). 카메라 리밋보다 넉넉하게 잡는다.
@export var 영역: Rect2 = Rect2(-800, -1800, 6000, 3200):
	set(v): 영역 = v; queue_redraw()

@export_group("전환")
## 아래쪽(= y 가 큰 쪽)에 있는 방.
@export var 아래_방: 방_ = 방_.거실:
	set(v): 아래_방 = v; queue_redraw()
## 위쪽(= y 가 작은 쪽)에 있는 방.
@export var 위_방: 방_ = 방_.굴뚝:
	set(v): 위_방 = v; queue_redraw()
## 섞임이 시작되는 y(아래). 이보다 아래는 100% `아래_방`.
@export var 전환_시작y: float = 0.0:
	set(v): 전환_시작y = v; queue_redraw()
## 섞임이 끝나는 y(위). 이보다 위는 100% `위_방`.
## ★`전환_시작y` 와 최소 400px 이상 벌릴 것 — 점프 한 번(160px)보다 짧으면 컷처럼 보인다.
@export var 전환_끝y: float = -900.0:
	set(v): 전환_끝y = v; queue_redraw()

@export_group("모양")
## 배경 밝기 배수. 챕터 팔레트 위에 얹히므로 1.0 이 기본이다.
@export_range(0.2, 2.0) var 밝기: float = 1.0:
	set(v): 밝기 = v; queue_redraw()
## 무늬(벽지 줄·벽돌 줄눈·서까래) 개수의 기준. 클수록 촘촘하다.
@export_range(0.3, 3.0) var 밀도: float = 1.0:
	set(v): 밀도 = v; queue_redraw()
## 실루엣(가구·연통·서까래) 배치 난수 씨앗. 바꾸면 배치가 통째로 달라진다.
@export var 씨앗: int = 20260818:
	set(v): 씨앗 = v; queue_redraw()

@export_group("그림")
## ============================================================================
## ★[2026-08-25 도형 요청 "배경을 넣어서 집안을 표현"] 디자이너 원화를 꽂는 자리
## ----------------------------------------------------------------------------
##   `assets/background/*.png` 의 방 원화를 여기 꽂으면, 그 방은 아래 `_draw()` 의
##   **코드 그림 대신 원화**가 나온다. 비워 두면 예전과 똑같이 코드가 그린다.
##   → 장애물의 `아트슬롯` 과 같은 사상이다: 코드를 안 고치고 그림으로 갈아끼운다.
##
##   ★왜 새 노드를 안 만들고 여기에 넣었나
##     이 노드는 이미 **두 방을 세로로 섞는**(거실 ⇄ 굴뚝) 기능을 갖고 있다.
##     새 노드를 만들면 그 크로스페이드를 처음부터 다시 짜야 한다.
##     여기에 텍스처 두 장을 붙이면 방 전환 연출이 **그대로 공짜로** 따라온다.
## ============================================================================
## 아래쪽 방에 깔 원화.
@export var 그림_아래: Texture2D = null:
	set(v): 그림_아래 = v; queue_redraw()
## 위쪽 방에 깔 원화 (세로로 이어진 두 방을 한 씬에서 섞을 때만 쓴다).
@export var 그림_위: Texture2D = null:
	set(v): 그림_위 = v; queue_redraw()
@export var 그림_맞춤: 맞춤_ = 맞춤_.덮기:
	set(v): 그림_맞춤 = v; queue_redraw()
## 그림에서 **잘라 쓸 부분**(원본 px). 크기가 0 이면 전체를 쓴다.
## 바닥 앞쪽 띠만 떠서 플레이어 **앞**(z_index 양수)에 한 겹 더 깔면 깊이감이 생긴다.
@export var 그림_원본영역: Rect2 = Rect2():
	set(v): 그림_원본영역 = v; queue_redraw()
## 그림 밝기 배수.
## ⚠ 챕터 `어둠`(CanvasModulate ≈0.72)이 화면 전체에 곱해지므로 원화가 한 단 더 어두워진다.
##   1.3~1.6 쯤 올려야 원화의 명암이 산다. (명도 규칙 §5 의 0.15~0.40 대역 제한은
##   **코드 그림**에 걸린 제약이고, 원화는 디자이너가 이미 그 톤으로 그려서 준다)
@export_range(0.2, 3.0) var 그림_밝기: float = 1.0:
	set(v): 그림_밝기 = v; queue_redraw()
## 좌우 반전. 원화의 문·창 위치를 진행 방향(왼→오른쪽)에 맞추고 싶을 때 켠다.
## ★`연결통로` 의 출구는 구조상 **오른쪽(+x)으로만** 파고든다. 원화의 문이 왼쪽에 있으면
##   이걸 켜서 방을 통째로 뒤집는 것이 가장 싼 해결책이다(지형 x 좌표도 같이 뒤집을 것).
@export var 좌우반전: bool = false:
	set(v): 좌우반전 = v; queue_redraw()
## ★켜면 이 노드를 **플레이어 앞**(z_index +40)에 그린다.
##   원화의 "앞쪽 바닥 띠"만 `그림_원본영역` 으로 떠서 한 겹 더 깔면, 플레이어가 그 띠
##   뒤로 들어가며 방에 **깊이**가 생긴다(2.5D). 끄면 예전대로 맨 뒤(z −60).
@export var 앞에_그리기: bool = false:
	set(v):
		앞에_그리기 = v
		z_index = 40 if 앞에_그리기 else -60

# ── 내부 ────────────────────────────────────────────────────────────────────
var _섞임: float = 0.0            ## 0 = 완전히 아래_방 / 1 = 완전히 위_방
var _마지막섞임: float = -1.0
var _캠: Camera2D = null


func _ready() -> void:
	# 배경은 지형·장식·플레이어보다 훨씬 뒤. 안개층(z −6 대)보다도 뒤에 둔다.
	# ★단 `앞에_그리기` 를 켠 전경 레이어는 반대로 플레이어 **앞**에 둔다.
	z_index = 40 if 앞에_그리기 else -60
	z_as_relative = false
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _캠 == null or not is_instance_valid(_캠):
		_캠 = get_viewport().get_camera_2d()
	if _캠 == null:
		return
	_섞임 = 섞임_계산(_캠.get_screen_center_position().y)
	# ★값이 실제로 바뀌었을 때만 다시 그린다. 화면 가득한 배경이라 매 프레임은 비싸다.
	if absf(_섞임 - _마지막섞임) > 0.002:
		_마지막섞임 = _섞임
		queue_redraw()


## 주어진 y 에서의 섞임 값. 테스트가 직접 부른다.
func 섞임_계산(y: float) -> float:
	if is_equal_approx(전환_시작y, 전환_끝y):
		return 0.0
	# 전환_끝y 가 전환_시작y 보다 **위**(작다)라는 전제. 뒤집혀 있어도 동작하게 정규화한다.
	return clampf((y - 전환_시작y) / (전환_끝y - 전환_시작y), 0.0, 1.0)


# ============================================================================
# 그림
# ============================================================================
func _draw() -> void:
	if 아트슬롯.그림_있나(self):
		return
	var b := _섞임 if not Engine.is_editor_hint() else 0.0
	# 아래 방을 먼저 통째로 깔고, 위 방을 알파로 덮는다.
	# (두 방을 각각 알파로 그리면 겹치는 구간에서 배경이 투명해져 검은 틈이 보인다)
	_방_그리기(아래_방, 1.0, 그림_아래)
	if b > 0.002:
		_방_그리기(위_방, b, 그림_위)


func _방_그리기(방: 방_, 알파: float, 그림: Texture2D = null) -> void:
	# ★원화가 꽂혀 있으면 코드 그림은 쉰다 (아트슬롯과 똑같은 규칙).
	if 그림 != null:
		_그림_그리기(그림, 알파)
		return
	match 방:
		방_.거실:   _거실(알파)
		방_.굴뚝:   _굴뚝(알파)
		방_.지붕:   _지붕(알파)
		방_.하수도: _하수도(알파)
		방_.이층방: _이층방(알파)
		방_.복도:   _복도(알파)
		방_.부엌:   _부엌(알파)


# ── 원화 그리기 ─────────────────────────────────────────────────────────────
## `영역` 사각형에 원화 한 장을 앉힌다.
## ★좌표 규약: `그림_맞춤 = 늘이기` + `영역` 을 원화와 **같은 비율**로 잡으면
##   "원화 픽셀 (px,py) = 월드 (영역.position + (px,py))" 가 되어, 레벨 디자이너가
##   원화 위에서 가구를 찍은 좌표를 **그대로** 지형 좌표로 쓸 수 있다.
##   집 챕터 4 개 씬이 전부 이 규약으로 지어져 있다(`tools/build_집_배경스테이지.gd`).
func _그림_그리기(그림: Texture2D, 알파: float) -> void:
	var 원본 := 그림.get_size()
	if 원본.x <= 0.0 or 원본.y <= 0.0:
		return
	var src := 그림_원본영역
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		src = Rect2(Vector2.ZERO, 원본)
	var dst := 영역

	match 그림_맞춤:
		맞춤_.덮기:
			# 영역을 꽉 채우는 배율을 고르고, 넘치는 만큼 **원본에서** 가운데 기준으로 잘라낸다.
			var s := maxf(영역.size.x / src.size.x, 영역.size.y / src.size.y)
			var 쓸크기 := 영역.size / s
			src = Rect2(src.position + (src.size - 쓸크기) * 0.5, 쓸크기)
		맞춤_.맞추기:
			var s2 := minf(영역.size.x / src.size.x, 영역.size.y / src.size.y)
			var 크기 := src.size * s2
			dst = Rect2(영역.get_center() - 크기 * 0.5, 크기)
			# 남는 자리는 검정으로 메운다. 비워 두면 뒤(빈 화면)가 그대로 비친다.
			draw_rect(영역, Color(0.0, 0.0, 0.0, 알파), true)
		맞춤_.늘이기:
			pass

	var m := Color(그림_밝기, 그림_밝기, 그림_밝기, 알파)
	if 좌우반전:
		# ★`영역` 의 세로 중심선을 기준으로 거울 변환.
		#   목적지 Rect 의 폭을 음수로 주는 방법은 드라이버마다 동작이 갈려 쓰지 않는다.
		var c := 영역.get_center()
		draw_set_transform_matrix(Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0),
			Vector2(c.x * 2.0, 0.0)))
	draw_texture_rect_region(그림, dst, src, m)
	if 좌우반전:
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 씨앗
	return r


func _c(v: float, a: float, 색조: Vector3 = Vector3(1.0, 1.0, 1.0)) -> Color:
	# 명도 규칙 §5 — 배경은 0.15~0.40 대역. 회색 지형 대역(0.45~0.55)을 절대 안 넘게 자른다.
	var m := clampf(v * 밝기, 0.06, 0.42)
	return Color(m * 색조.x, m * 색조.y, m * 색조.z, a)


# ── 거실 ────────────────────────────────────────────────────────────────────
## 벽지(세로 줄무늬) + 걸레받이 + 가구 실루엣 + 액자.
## 색조를 아주 미세하게 따뜻하게(적황) 둬서 굴뚝의 차가운 그을음과 대비시킨다.
func _거실(a: float) -> void:
	var 따 := Vector3(1.06, 1.0, 0.92)
	draw_rect(영역, _c(0.20, a, 따), true)

	# 벽지 세로 줄무늬 — 실내라는 걸 한눈에 알리는 가장 싼 기호
	var 간격 := 148.0 / 밀도
	var x := 영역.position.x
	while x < 영역.end.x:
		draw_rect(Rect2(x, 영역.position.y, 간격 * 0.42, 영역.size.y), _c(0.24, a * 0.7, 따), true)
		x += 간격

	# 허리 몰딩 + 걸레받이 — 가로선 두 줄이 "이건 벽이다" 를 확정한다
	var 바닥y := 영역.end.y - 260.0
	draw_line(Vector2(영역.position.x, 바닥y - 420.0), Vector2(영역.end.x, 바닥y - 420.0),
		_c(0.30, a * 0.8, 따), 7.0)
	draw_rect(Rect2(영역.position.x, 바닥y, 영역.size.x, 60.0), _c(0.13, a, 따), true)

	# 마룻바닥 — 걸레받이 아래는 널판이 가로로 눕는다
	var y := 바닥y + 60.0
	while y < 영역.end.y:
		draw_line(Vector2(영역.position.x, y), Vector2(영역.end.x, y), _c(0.16, a * 0.9, 따), 3.0)
		y += 46.0 / 밀도

	# 가구 실루엣 — 소파·책장·탁자. 밟는 지형과 헷갈리지 않게 **아주 어둡게** 둔다.
	var r := _rng()
	var 개수 := int(영역.size.x / 900.0) + 1
	for i in 개수:
		var gx := 영역.position.x + 420.0 + float(i) * 900.0 + r.randf_range(-160.0, 160.0)
		var 높이 := r.randf_range(170.0, 340.0)
		var 폭 := r.randf_range(240.0, 460.0)
		draw_rect(Rect2(gx, 바닥y - 높이, 폭, 높이), _c(0.11, a * 0.95, 따), true)
		# 등받이/선반 칸
		var 칸 := int(높이 / 78.0)
		for k in 칸:
			var ky := 바닥y - 높이 + 26.0 + float(k) * 78.0
			draw_line(Vector2(gx + 12.0, ky), Vector2(gx + 폭 - 12.0, ky), _c(0.16, a * 0.7, 따), 2.0)
		# 액자 — 벽에 걸린 사각형 하나
		if i % 2 == 0:
			var fh := r.randf_range(90.0, 150.0)
			draw_rect(Rect2(gx + 60.0, 바닥y - 높이 - 260.0, fh * 1.3, fh), _c(0.27, a * 0.9, 따), false, 6.0)


# ── 2층 방 ──────────────────────────────────────────────────────────────────
## [2026-08-22] 미국·유럽 2층집 침실 벽지. 세로 다마스크 패널 + 굽도리(웨인스코팅)
## + 액자 + 커튼 친 창 실루엣. 거실보다 조금 밝고 따뜻하게 둬서 "사적인 방"으로 읽히게.
func _이층방(a: float) -> void:
	var 따 := Vector3(1.07, 1.0, 0.90)
	draw_rect(영역, _c(0.22, a, 따), true)

	# 웨인스코팅(허리 아래 나무 패널) 경계선 — 방의 격을 만든다
	var 허리y := 영역.position.y + 영역.size.y * 0.60
	# 허리 위 = 벽지(세로 다마스크 패널), 허리 아래 = 나무 패널
	var 패널폭 := 300.0 / 밀도
	var x := 영역.position.x
	while x < 영역.end.x:
		# 벽지 세로 패널 — 얇은 이중선으로 "무늬 있는 벽지" 를 암시
		draw_line(Vector2(x, 영역.position.y), Vector2(x, 허리y), _c(0.27, a * 0.7, 따), 3.0)
		draw_rect(Rect2(x + 패널폭 * 0.44, 영역.position.y, 패널폭 * 0.12, 허리y - 영역.position.y),
			_c(0.25, a * 0.5, 따), true)
		# 허리 아래 나무 패널 — 세로 칸막이
		draw_rect(Rect2(x + 8.0, 허리y + 10.0, 패널폭 - 16.0, 영역.end.y - 허리y - 20.0),
			_c(0.14, a * 0.9, 따), false, 4.0)
		x += 패널폭
	# 허리 몰딩(체어레일) + 걸레받이
	draw_rect(Rect2(영역.position.x, 허리y - 8.0, 영역.size.x, 16.0), _c(0.30, a, 따), true)
	draw_rect(Rect2(영역.position.x, 영역.end.y - 56.0, 영역.size.x, 56.0), _c(0.12, a, 따), true)
	# 크라운 몰딩(천장 가까이)
	draw_rect(Rect2(영역.position.x, 영역.position.y, 영역.size.x, 26.0), _c(0.28, a * 0.9, 따), true)

	# 액자 몇 개 + 커튼 친 창 실루엣
	var r := _rng()
	var 개수 := int(영역.size.x / 1100.0) + 1
	for i in 개수:
		var gx := 영역.position.x + 520.0 + float(i) * 1100.0 + r.randf_range(-120.0, 120.0)
		if i % 2 == 0:
			# 액자
			var fh := r.randf_range(120.0, 200.0)
			draw_rect(Rect2(gx, 영역.position.y + 180.0, fh * 1.25, fh), _c(0.30, a * 0.9, 따), false, 7.0)
			draw_rect(Rect2(gx + 10.0, 영역.position.y + 190.0, fh * 1.25 - 20.0, fh - 20.0), _c(0.17, a * 0.8, 따), true)
		else:
			# 커튼 친 창 — 세로로 늘어진 천 실루엣(밟는 창문커튼 오브젝트와는 무관, 순수 배경)
			var wy := 영역.position.y + 150.0
			var wh := 허리y - wy - 30.0
			draw_rect(Rect2(gx, wy, 220.0, wh), _c(0.09, a, 따), true)
			for k in 6:
				var cx := gx + 12.0 + float(k) * 34.0
				draw_line(Vector2(cx, wy + 8.0), Vector2(cx, wy + wh - 8.0), _c(0.15, a * 0.7, 따), 3.0)


# ── 복도 ────────────────────────────────────────────────────────────────────
## [2026-08-22] 유럽식 복도 — 벽 패널(웨인스코팅) + 늘어선 문 + 걸레받이 + 벽등.
## 방보다 살짝 차갑고 어둡게 둬서 "방에서 나와 통로로 나섰다" 가 읽히게.
func _복도(a: float) -> void:
	var 차 := Vector3(0.96, 0.98, 1.05)
	draw_rect(영역, _c(0.18, a, 차), true)

	# 벽 상·하 몰딩
	var 허리y := 영역.position.y + 영역.size.y * 0.55
	draw_rect(Rect2(영역.position.x, 허리y - 7.0, 영역.size.x, 14.0), _c(0.28, a, 차), true)
	draw_rect(Rect2(영역.position.x, 영역.end.y - 60.0, 영역.size.x, 60.0), _c(0.11, a, 차), true)
	draw_rect(Rect2(영역.position.x, 영역.position.y, 영역.size.x, 24.0), _c(0.26, a * 0.9, 차), true)

	# 벽 패널(허리 위) — 넓은 액자형 몰딩 사각형이 일정 간격으로
	var 칸 := 520.0 / 밀도
	var x := 영역.position.x + 40.0
	while x < 영역.end.x - 40.0:
		draw_rect(Rect2(x, 영역.position.y + 60.0, 칸 - 80.0, 허리y - 영역.position.y - 120.0),
			_c(0.23, a * 0.7, 차), false, 5.0)
		x += 칸

	# ── 늘어선 문 ── 복도라는 걸 확정하는 기호. 아주 어둡게(밟는 지형과 안 헷갈리게).
	var r := _rng()
	var 문간격 := 1200.0 / maxf(밀도, 0.5)
	var dx := 영역.position.x + 300.0
	while dx < 영역.end.x - 200.0:
		var 문높이 := 영역.end.y - 60.0 - 허리y + 40.0
		var 문y := 영역.end.y - 60.0 - 문높이
		draw_rect(Rect2(dx, 문y, 150.0, 문높이), _c(0.08, a, 차), true)          # 문짝
		draw_rect(Rect2(dx - 10.0, 문y - 14.0, 170.0, 14.0), _c(0.20, a * 0.9, 차), true)  # 문틀 상인방
		draw_rect(Rect2(dx + 12.0, 문y + 18.0, 126.0, 문높이 * 0.42), _c(0.12, a * 0.6, 차), false, 3.0)  # 문 패널
		draw_circle(Vector2(dx + 132.0, 문y + 문높이 * 0.55), 5.0, _c(0.34, a, 차))  # 손잡이
		dx += 문간격

	# 벽등(스콘스) 실루엣 — 은은한 점광 몇 개
	var lx := 영역.position.x + 620.0
	while lx < 영역.end.x:
		draw_circle(Vector2(lx, 허리y - 120.0), 22.0, _c(0.36, a * 0.6, 차))
		lx += 문간격


# ── 부엌 ────────────────────────────────────────────────────────────────────
## [2026-08-25 신규] 원화(`assets/background/kitchen.png`)가 없을 때만 쓰는 대타.
## 타일 벽 + 상부장 줄 + 조리대 라인. 거실보다 조금 차갑게(회청) 둬서 "물 쓰는 방"으로 읽히게.
func _부엌(a: float) -> void:
	var 차 := Vector3(0.97, 1.0, 1.03)
	draw_rect(영역, _c(0.19, a, 차), true)

	# 타일 벽 — 부엌이라는 걸 한눈에 알리는 가장 싼 기호. 벽돌보다 정사각형에 가깝게.
	var 조리대y := 영역.position.y + 영역.size.y * 0.62
	var 타일 := 96.0 / 밀도
	var y := 영역.position.y
	while y < 조리대y:
		draw_line(Vector2(영역.position.x, y), Vector2(영역.end.x, y), _c(0.25, a * 0.45, 차), 2.0)
		var x := 영역.position.x
		while x < 영역.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 타일), _c(0.25, a * 0.3, 차), 2.0)
			x += 타일
		y += 타일

	# 상부장 줄 + 조리대 + 하부장 — 가로 띠 세 줄이면 부엌 단면이 완성된다.
	var 상부y := 영역.position.y + 영역.size.y * 0.26
	draw_rect(Rect2(영역.position.x, 상부y, 영역.size.x, 190.0 / 밀도), _c(0.12, a, 차), true)
	draw_rect(Rect2(영역.position.x, 조리대y - 22.0, 영역.size.x, 22.0), _c(0.31, a, 차), true)
	draw_rect(Rect2(영역.position.x, 조리대y, 영역.size.x, 영역.end.y - 조리대y), _c(0.10, a, 차), true)

	# 문짝 칸 나누기 — 상·하부장에 세로 홈을 파면 "장" 으로 읽힌다.
	var 칸 := 300.0 / 밀도
	var cx := 영역.position.x
	while cx < 영역.end.x:
		draw_line(Vector2(cx, 상부y), Vector2(cx, 상부y + 190.0 / 밀도), _c(0.22, a * 0.7, 차), 3.0)
		draw_line(Vector2(cx, 조리대y), Vector2(cx, 영역.end.y), _c(0.18, a * 0.7, 차), 3.0)
		cx += 칸

	# 매달린 전등 — 부엌 한가운데 하나. 배경 대역(≤0.42) 안에서 가장 밝은 점.
	var r := _rng()
	var lx := 영역.get_center().x + r.randf_range(-200.0, 200.0)
	draw_line(Vector2(lx, 영역.position.y), Vector2(lx, 상부y - 40.0), _c(0.16, a, 차), 4.0)
	draw_circle(Vector2(lx, 상부y - 26.0), 30.0, _c(0.40, a * 0.8, 차))


# ── 굴뚝 ────────────────────────────────────────────────────────────────────
## 그을린 벽돌 + 세로로 길게 떨어지는 그을음 자국 + 좁아지는 원근.
## 차갑게(청회) 둬서 거실의 따뜻함과 확실히 갈리게 한다.
func _굴뚝(a: float) -> void:
	var 차 := Vector3(0.94, 0.97, 1.06)
	draw_rect(영역, _c(0.13, a, 차), true)

	# ★[2026-08-19 고도화] 세로 명암 그라데이션 —
	#   아래(아궁이)는 어둡고 위(굴뚝 입구)는 하늘빛으로 밝아진다.
	#   "위를 올려다보는 굴뚝" 의 깊이를 만들고, 위에서 내려오는 은은한 빛과 자연스레 이어진다.
	var 단 := 24
	for i in 단:
		var gt := float(i) / float(단)                        # 0 = 맨 위, 1 = 맨 아래
		var yy := 영역.position.y + 영역.size.y * gt
		var hh := 영역.size.y / float(단) + 1.0
		draw_rect(Rect2(영역.position.x, yy, 영역.size.x, hh),
			_c(lerpf(0.30, 0.10, gt), a * 0.5, 차), true)       # 위 밝게 → 아래 어둡게 (배경 대역 안)

	# 벽돌 — 줄마다 반 칸씩 어긋나게. 어긋남이 없으면 격자무늬처럼 보여 벽돌로 안 읽힌다.
	var 벽돌h := 54.0 / 밀도
	var 벽돌w := 132.0 / 밀도
	var rb := _rng()                                         # ★[고도화] 벽돌 얼룩·결손용 난수(결정적)
	var 줄 := 0
	var y := 영역.position.y
	while y < 영역.end.y:
		draw_line(Vector2(영역.position.x, y), Vector2(영역.end.x, y), _c(0.18, a * 0.55, 차), 2.0)
		var 어긋 := (벽돌w * 0.5) if 줄 % 2 == 1 else 0.0
		var x := 영역.position.x + 어긋
		while x < 영역.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 벽돌h), _c(0.18, a * 0.40, 차), 2.0)
			# ★[고도화] 벽돌마다 미세한 명도 변주 + 드물게 빠진(부서진) 벽돌 →
			#   "같은 벽돌이 하나도 없는" 오래된 굴뚝. 배경이라 판정에는 아무 영향 없다.
			var 굴림 := rb.randf()
			if 굴림 < 0.13:
				draw_rect(Rect2(x + 3.0, y + 3.0, 벽돌w - 6.0, 벽돌h - 6.0), _c(0.05, a * 0.5, 차), true)
			elif 굴림 < 0.5:
				draw_rect(Rect2(x + 2.0, y + 2.0, 벽돌w - 4.0, 벽돌h - 4.0),
					_c(0.16 + 굴림 * 0.08, a * 0.16, 차), true)
			x += 벽돌w
		y += 벽돌h
		줄 += 1

	# 그을음 — 위에서 아래로 흘러내린 자국. 굴뚝이라는 정보의 90% 가 여기서 나온다.
	var r := _rng()
	var 개수 := int(영역.size.x / 260.0) + 2
	for i in 개수:
		var gx := 영역.position.x + r.randf_range(0.0, 영역.size.x)
		var 폭 := r.randf_range(40.0, 150.0)
		var 길이 := r.randf_range(영역.size.y * 0.25, 영역.size.y * 0.8)
		var gy := 영역.position.y + r.randf_range(0.0, 영역.size.y * 0.4)
		# 위가 진하고 아래로 흐려진다 = 흘러내린 방향이 읽힌다
		for k in 5:
			var t := float(k) / 5.0
			draw_rect(Rect2(gx + 폭 * t * 0.18, gy + 길이 * t, 폭 * (1.0 - t * 0.5), 길이 * 0.24),
				_c(0.07, a * (0.5 - t * 0.08), 차), true)

	# ★[고도화] 상단 옅은 안개 띠 — 위에서 내려오는 은은한 빛이 걸리는 자리.
	#   가로로 눕는 반투명 띠 몇 가닥이 굴뚝 위쪽 공기에 "부피" 를 준다.
	var rh := _rng()
	for i in 4:
		var hy := 영역.position.y + 영역.size.y * rh.randf_range(0.02, 0.42)
		draw_rect(Rect2(영역.position.x, hy, 영역.size.x, rh.randf_range(30.0, 80.0)),
			_c(0.34, a * 0.10, 차), true)

	# ★[고도화] 좌우 안쪽 그늘 — 굴뚝 벽에 가까울수록 어둡게(원근·깊이).
	var 그늘폭 := 영역.size.x * 0.16
	for i in 6:
		var st := float(i) / 6.0
		var 폭s := 그늘폭 * (1.0 - st)
		var as2 := a * 0.12 * (1.0 - st)
		draw_rect(Rect2(영역.position.x, 영역.position.y, 폭s, 영역.size.y), _c(0.04, as2, 차), true)
		draw_rect(Rect2(영역.end.x - 폭s, 영역.position.y, 폭s, 영역.size.y), _c(0.04, as2, 차), true)


# ── 지붕 ────────────────────────────────────────────────────────────────────
## 서까래(비스듬한 굵은 보) + 널판 사이로 새는 하늘 + 거미줄 느낌의 대각선.
## ★여기가 도형님이 빨간색으로 칠한 "지붕에 구멍이 나서 빛이 새어나오는" 자리의 배경이다.
##   실제로 빛을 쏘는 것은 `빛기둥.gd` 노드이고, 여기서는 **뚫린 널판**만 그린다.
##   둘을 나눈 이유: 구멍 위치는 레벨 디자인이 정해야 하는데 배경은 무한히 반복되기 때문.
func _지붕(a: float) -> void:
	var 따 := Vector3(1.04, 1.0, 0.94)
	draw_rect(영역, _c(0.11, a, 따), true)

	# 지붕 널 — 처마 방향으로 비스듬히 눕는다. 수평선이 없어야 "천장"이 아니라 "지붕"이다.
	var 간격 := 92.0 / 밀도
	var 기울 := 0.34                     # tan(≈19°)
	var x := 영역.position.x - 영역.size.y * 기울
	while x < 영역.end.x + 영역.size.y * 기울:
		draw_line(Vector2(x, 영역.position.y),
			Vector2(x + 영역.size.y * 기울, 영역.end.y), _c(0.17, a * 0.75, 따), 3.0)
		x += 간격

	# 서까래 — 널보다 훨씬 굵고 어둡다. 이 대비가 깊이를 만든다.
	var 서간격 := 620.0 / 밀도
	x = 영역.position.x - 영역.size.y * 기울
	while x < 영역.end.x + 영역.size.y * 기울:
		draw_line(Vector2(x, 영역.position.y),
			Vector2(x + 영역.size.y * 기울, 영역.end.y), _c(0.07, a, 따), 26.0)
		x += 서간격

	# 널이 빠진 자리 — 하늘이 비쳐 밝게 뚫린다.
	# 배경 대역(≤0.42)을 넘지 않게 자른다. 진짜 밝은 빛은 `빛기둥` 이 그린다.
	var r := _rng()
	var 구멍수 := int(영역.size.x / 1100.0) + 1
	for i in 구멍수:
		var gx := 영역.position.x + 300.0 + float(i) * 1100.0 + r.randf_range(-220.0, 220.0)
		var gy := 영역.position.y + r.randf_range(80.0, 영역.size.y * 0.55)
		var w := r.randf_range(70.0, 190.0)
		var h := r.randf_range(50.0, 120.0)
		for k in 3:
			var t := float(k) / 3.0
			draw_rect(Rect2(gx - w * t * 0.5, gy - h * t * 0.5, w * (1.0 + t), h * (1.0 + t)),
				_c(0.40, a * (0.55 - t * 0.15), 따), true)


# ── 하수도 ──────────────────────────────────────────────────────────────────
## 아치형 벽돌 터널 + 굵은 배관 + 물때. 챕터 2(폐수로)로 넘어가는 예고편이다.
func _하수도(a: float) -> void:
	var 차 := Vector3(0.90, 0.97, 1.08)
	draw_rect(영역, _c(0.10, a, 차), true)

	# 아치 — 같은 중심에서 반지름만 키운 호를 여러 겹. 터널이 안으로 이어지는 착시.
	var 중심 := Vector2(영역.position.x + 영역.size.x * 0.5, 영역.end.y - 200.0)
	var 겹 := int(9 * 밀도)
	for i in 겹:
		var 반 := 260.0 + float(i) * 210.0
		draw_arc(중심, 반, PI, TAU, 48, _c(0.15 + 0.02 * float(i % 3), a * 0.75, 차), 8.0)

	# 배관 — 벽을 따라 수평으로 지나가는 굵은 관 두 줄
	for k in 2:
		var py := 영역.position.y + 영역.size.y * (0.28 + 0.22 * float(k))
		draw_line(Vector2(영역.position.x, py), Vector2(영역.end.x, py), _c(0.08, a, 차), 44.0)
		draw_line(Vector2(영역.position.x, py - 14.0), Vector2(영역.end.x, py - 14.0),
			_c(0.20, a * 0.6, 차), 4.0)
		# 이음쇠
		var x := 영역.position.x
		while x < 영역.end.x:
			draw_rect(Rect2(x - 9.0, py - 30.0, 18.0, 60.0), _c(0.14, a, 차), true)
			x += 540.0 / 밀도
