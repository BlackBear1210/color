@tool
extends Area2D
## ============================================================================
## [2026-08-06 신규] 연결통로 — 스테이지와 스테이지를 잇는 "걸어 들어가는 공간"
## ----------------------------------------------------------------------------
## ▣ 포탈을 없앤 이유 (도형님 요청: "난 이게임에 포탈로 이동하는게 싫어")
##   포탈은 "여기서 저기로 순간이동한다"는 게임 규칙을 드러낸다.
##   우리 게임 톤(LIMBO / 리틀 나이트메어 / 레인월드 계열)에서는
##   **공간이 물리적으로 이어져 있어야** 한다. 그래서 스테이지 끝을
##   지형에 파인 **가로 터널**로 만들었다. 플레이어는 문을 여는 게 아니라
##   그냥 걸어 들어가고, 터널 안이 어두우니 화면이 자연스럽게 까매진다.
##
## ▣ 한 스크립트가 출구와 입구를 둘 다 한다
##   출구(스테이지 끝, 오른쪽으로 파고듦)  : 안쪽 깊이 들어가면 다음 씬으로
##   입구(스테이지 시작, 왼쪽에서 뻗어옴)  : 판정 없음. 여기서 걸어 나오며 화면이 밝아진다
##   같은 스크립트라 **입구와 출구의 그림이 완전히 똑같다.** 그래야 통로를 지난 뒤
##   "방금 그 통로에서 나왔다"고 읽힌다 (VINE 의 이어지는 배경과 같은 원리).
##
## ▣ 스스로 통로를 짓는다 (지형 빌더에 의존하지 않는다)
##   바닥 / 천장 / 막다른 뒷벽을 이 노드가 StaticBody2D 로 직접 만든다.
##   → 지형 폴리곤을 정교하게 파낼 필요 없이 지면 끝에 툭 놓기만 하면 통로가 완성된다.
##   → 천장이 있어서 플레이어가 통로를 **뛰어넘어 갈 수 없다** = 반드시 통로를 지난다.
##
## ▣ 배치 규약
##   · 원점 = 통로 **바닥 중앙**. 지면 높이에 그대로 놓으면 된다.
##   · 출구는 +x 방향(오른쪽)으로 파고들고, 입구는 −x 방향(왼쪽)에서 뻗어온다.
##   · `속빛` = **이어지는 쪽 스테이지의 하늘색**. 통로 저 끝에서 그 색 빛이 새어나오므로
##     지나가기 전에 이미 다음 지역의 분위기가 보인다.
## ============================================================================
class_name 연결통로

## ⚠ class_name 대신 **경로 preload** 로 잡는다 — 새 스크립트의 전역 클래스 이름은
##   에디터가 한 번 훑어야 등록돼서, 그 전에 헤드리스 검사를 돌리면 통째로 죽는다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")

enum 역할_ { 출구, 입구 }

@export var 역할: 역할_ = 역할_.출구:
	set(v): 역할 = v; _재구성()

## 통로 안쪽 높이(px). 플레이어 키가 약 47px 이라 100 이하로는 내리지 말 것.
@export_range(80, 400) var 높이: float = 150.0:
	set(v): 높이 = v; _재구성()

## 통로가 지형 속으로 파고드는 깊이(px). 이 거리를 걷는 동안 화면이 어두워진다.
## 암전시간(0.85초) × 이동속도(390px/s) ≈ 330px 이므로 그보다 넉넉하게 잡는다.
@export_range(160, 1200) var 깊이: float = 420.0:
	set(v): 깊이 = v; _재구성()

## 벽·바닥·천장의 두께(px). 두꺼울수록 "덩어리에서 파낸 굴"로 보인다.
@export_range(24, 200) var 두께: float = 90.0:
	set(v): 두께 = v; _재구성()

@export_group("연결")
## 출구 전용 — 걸어 들어가면 넘어갈 다음 스테이지 씬.
@export_file("*.tscn") var 다음_씬: String = ""
## 다음 씬에서 걸어 나올 입구 통로 노드의 이름. 비우면 그 씬의 기본 시작 위치.
@export var 다음_진입점: String = "입구통로"

@export_group("연출")
## 통로 저 끝에서 새어나오는 빛 = **이어지는 지역의 하늘색**.
@export var 속빛: Color = Color(0.31, 0.32, 0.34):
	set(v): 속빛 = v; _속빛_갱신(); queue_redraw()
## 통로 안쪽 어둠의 진하기. 1.0 = 완전한 검정.
@export_range(0.0, 1.0) var 어둠: float = 0.94

## ★통로를 감싼 암반을 위/아래로 얼마나 더 그릴지(px). **그림만** 커진다(콜리전은 그대로).
## [2026-08-06] 스크린샷을 보니 통로가 지면 위에 얹힌 **콘크리트 상자**처럼 보였다.
## 두께(90px)만큼만 그리면 "굴을 판 것" 이 아니라 "구조물을 세운 것" 으로 읽힌다.
## 위로 넉넉히 늘려 천장 매스와 이어 붙이고, 아래로도 늘려 바닥 지형에 파묻으면
## 비로소 **덩어리에서 파낸 구멍**으로 보인다.
@export_range(0, 1200) var 암반_위: float = 340.0
@export_range(0, 1200) var 암반_아래: float = 420.0

var _t: float = 0.0
var _광원: PointLight2D = null
var _발동함: bool = false          ## 한 번만 넘어가게 (프레임마다 여러 번 겹칠 수 있다)


## 출구는 +1(오른쪽), 입구는 −1(왼쪽). 통로 몸통이 뻗어나가는 방향.
func 방향() -> float:
	return 1.0 if 역할 == 역할_.출구 else -1.0


func _ready() -> void:
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("연결통로")
	# 판정은 출구만. 입구는 순수한 배경 겸 스폰 지점이다.
	monitoring = 역할 == 역할_.출구
	collision_layer = 0        # 아무도 이걸 감지할 필요 없다
	collision_mask = 1         # 플레이어(레이어 1)만 본다
	if 역할 == 역할_.출구 and not body_entered.is_connected(_몸_들어옴):
		body_entered.connect(_몸_들어옴)
	set_process(true)


## 입구 통로에서 플레이어가 걸어 나올 때의 시작 위치(월드 좌표).
## 통로 **가장 깊은 안쪽**에 세워야 "걸어 나오는" 그림이 된다.
func 걸어나올_위치() -> Vector2:
	return global_position + Vector2(방향() * 깊이 * 0.62, 0.0)


# ── 통로 짓기 ───────────────────────────────────────────────────────────────
## 바닥·천장·뒷벽(StaticBody2D) + 판정(CollisionShape2D)을 만들거나 갱신한다.
## 값이 바뀔 때마다 다시 부르므로 **있으면 재사용, 없으면 생성** 구조로 짰다.
func _재구성() -> void:
	if not is_inside_tree():
		return
	var d := 방향()
	var 중심x := d * 깊이 * 0.5

	# ── 판정 영역 ── 통로 안쪽 60% 지점부터. 입구를 스치기만 해도 넘어가면 안 된다.
	var cs := _가져오기("판정", CollisionShape2D) as CollisionShape2D
	var sh := cs.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		cs.shape = sh
	sh.size = Vector2(깊이 * 0.34, 높이 * 0.9)
	cs.position = Vector2(d * 깊이 * 0.66, -높이 * 0.5)

	# ── 통로 몸통 ── 바닥 / 천장 / 막다른 뒷벽
	# 바닥은 통로 입구보다 살짝 앞으로 내밀어(+d*24) 지면과 이가 맞게 한다.
	_벽("바닥", Vector2(중심x + d * 12.0, 두께 * 0.5), Vector2(깊이 + 48.0, 두께))
	_벽("천장", Vector2(중심x + d * 12.0, -높이 - 두께 * 0.5), Vector2(깊이 + 48.0, 두께))
	# 뒷벽 — 출구는 여기 닿기 전에 씬이 바뀌고, 입구는 여기 앞에서 스폰된다.
	_벽("뒷벽", Vector2(d * (깊이 + 두께 * 0.5), -높이 * 0.5), Vector2(두께, 높이 + 두께 * 2.0))

	# ── 속빛 광원 ──
	if _광원 == null:
		_광원 = _가져오기("속빛광원", PointLight2D) as PointLight2D
		if _광원.texture == null:
			_광원.texture = _빛_텍스처()
	_광원.position = Vector2(d * 깊이 * 0.78, -높이 * 0.5)
	_광원.texture_scale = 높이 * 3.4 / 256.0
	# ★[2026-09-05] 프로젝트 조명 표준(height 128 · ADD). 예전에는 height 를 안 줘서
	#   기본값 0 이었고, 그래서 지형 노멀맵이 이 빛에 전혀 반응하지 않았다.
	조명표준.적용(_광원, 0.85)
	_속빛_갱신()
	queue_redraw()


## 이름으로 자식을 찾고, 없으면 만들어서 붙인다.
## (에디터에서 값만 바꿔도 노드가 계속 늘어나는 사고를 막는다)
func _가져오기(이름: String, 형: Variant) -> Node:
	var n := get_node_or_null(NodePath(이름))
	if n == null:
		n = 형.new()
		n.name = 이름
		add_child(n)
		# 에디터에서 만든 노드는 owner 를 줘야 씬에 저장된다
		if Engine.is_editor_hint() and owner:
			n.owner = owner
	return n


## 사각형 벽 하나(StaticBody2D + CollisionShape2D). 그림은 _draw 가 따로 그린다.
func _벽(이름: String, 위치: Vector2, 크기: Vector2) -> void:
	var 바디 := _가져오기(이름, StaticBody2D) as StaticBody2D
	바디.position = 위치
	바디.collision_layer = 1      # 플레이어가 밟는 일반 지형과 같은 레이어
	바디.collision_mask = 0
	var cs := 바디.get_node_or_null("모양") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "모양"
		# ★오목 폴리곤 기즈모가 에디터 2D 뷰를 뒤덮는 문제(2026-08-02)와 같은 이유로 숨긴다.
		#   visible 은 디버그 그리기만 끄는 것이라 물리 판정에는 영향이 없다.
		cs.visible = false
		바디.add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	r.size = 크기


func _속빛_갱신() -> void:
	if _광원:
		# 하늘색을 그대로 쓰면 너무 어둡다. 밝기를 끌어올려 "새어나오는 빛"으로 만든다.
		_광원.color = 속빛.lightened(0.55)


## 가운데가 밝고 가장자리가 0 으로 떨어지는 원형 그라데이션.
## 여러 통로가 공유해도 되지만 통로 수가 적어 그냥 매번 만든다.
func _빛_텍스처() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t


# ── 판정 ────────────────────────────────────────────────────────────────────
func _몸_들어옴(몸: Node2D) -> void:
	if _발동함 or Engine.is_editor_hint():
		return
	if not (몸 is CharacterBody2D):
		return
	if 다음_씬.is_empty():
		push_warning("연결통로(%s): 다음_씬 이 비어 있다" % name)
		return
	_발동함 = true
	# 씬 경로는 지금 씬을 기억해 둔다 — 나중에 되돌아가기를 붙일 때 쓴다.
	var 지금 := ""
	var 현재씬 := get_tree().current_scene
	if 현재씬:
		지금 = 현재씬.scene_file_path
	장면전환.통로로_이동(self, 다음_씬, 다음_진입점, 지금)


# ── 그림 ────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# 속빛이 아주 느리게 맥동한다. 정지된 그림은 "벽에 그린 그림"으로 보인다.
	_t += delta
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var d := 방향()
	var h := 높이
	var L := 깊이
	var t := 두께

	# ── 0) 통로를 감싼 암반 ────────────────────────────────────────────────
	# ★[2026-08-06 · 스크린샷 보고 고침] 처음엔 바닥/천장/뒷벽을 콜리전만 만들고
	#   그림을 안 그렸다. 그랬더니 화면에서 통로가 **허공에 뜬 검은 상자**로 보였다
	#   ("지형에 파인 굴" 이라는 게 전혀 안 읽힘 = 결국 포탈처럼 보인다).
	#   → 콜리전과 똑같은 자리에 암반 사각형을 직접 그린다. 지형 아트(black_fill)와
	#     같은 명도(0.09)로 맞춰서 주변 지형에 자연스럽게 이어 붙게 했다.
	# 지형 아트(black_fill)의 실측 명도에 맞춘 값. 밝으면 통로만 떠 보인다.
	var 암반 := Color(0.055, 0.055, 0.062)
	var 중심x := d * L * 0.5 + d * 12.0
	var 몸길이 := L + 48.0
	# 바닥 — 콜리전은 두께 t 지만, 그림은 아래로 더 내려 지형에 파묻는다
	draw_rect(Rect2(중심x - 몸길이 * 0.5, 0.0, 몸길이, t + 암반_아래), 암반)
	# 천장 — 위로 더 올려 천장 매스와 이어 붙인다
	draw_rect(Rect2(중심x - 몸길이 * 0.5, -h - t - 암반_위, 몸길이, t + 암반_위), 암반)
	# 막다른 뒷벽 (콜리전 `_벽("뒷벽", ...)` 과 같은 자리). 위아래로 넉넉히 이어 붙인다.
	var 뒷벽중심 := Vector2(d * (L + t * 0.5), -h * 0.5)
	draw_rect(Rect2(뒷벽중심.x - t * 0.5, -h - t - 암반_위,
		t, h + t * 2.0 + 암반_위 + 암반_아래), 암반)

	# ── 1) 통로 안쪽 어둠 ── 입구는 아치, 안쪽으로 갈수록 완전한 검정
	# 세로로 얇은 띠를 여러 장 겹쳐 "안으로 갈수록 어두워지는" 그라데이션을 만든다.
	# (한 장으로 칠하면 평평한 검은 사각형이라 깊이가 안 느껴진다)
	var 띠수 := 16
	for i in 띠수:
		var t0 := float(i) / float(띠수)
		var t1 := float(i + 1) / float(띠수)
		# 안쪽으로 갈수록 진해진다 (0.55 → 어둠)
		var a := lerpf(0.55, 어둠, t0)
		var 폭0 := 1.0 - t0 * 0.10        # 안쪽이 살짝 좁아진다 = 원근
		var 폭1 := 1.0 - t1 * 0.10
		draw_colored_polygon(PackedVector2Array([
			Vector2(d * L * t0, -h * 폭0),
			Vector2(d * L * t1, -h * 폭1),
			Vector2(d * L * t1, 0),
			Vector2(d * L * t0, 0),
		]), Color(0.03, 0.03, 0.035, a))

	# ── 2) 아치 입구 ── 위쪽이 둥근 구멍. 지형에서 파낸 단면처럼 보이게 한다.
	var 아치 := PackedVector2Array()
	var 단계 := 16
	아치.append(Vector2(0, 0))
	for i in 단계 + 1:
		var ang := PI * float(i) / float(단계)
		아치.append(Vector2(d * cos(ang) * 6.0, -h * 0.72 - sin(ang) * h * 0.28))
	아치.append(Vector2(0, 0))

	# ── 3) 저 끝에서 새어나오는 빛 ── 다음 지역의 하늘색
	var 맥동 := 0.86 + 0.14 * sin(_t * 0.9)
	var 빛중심 := Vector2(d * L * 0.80, -h * 0.48)
	for i in range(7, 0, -1):
		var r := h * 0.55 * float(i) / 7.0
		var a := 0.10 * 맥동 * (1.0 - float(i) / 8.0)
		draw_circle(빛중심, r, Color(속빛.r, 속빛.g, 속빛.b, a))

	# ── 4) 통로 테두리 ── 위·아래 두 줄. 지형과 통로의 경계를 또렷하게.
	# 흑백 게임이라 실루엣 경계선 한 줄이 있고 없고가 가독성을 크게 바꾼다.
	var 위 := PackedVector2Array([Vector2(0, -h), Vector2(d * L, -h)])
	var 아래 := PackedVector2Array([Vector2(0, 0), Vector2(d * L, 0)])
	draw_polyline(위, Color(0.02, 0.02, 0.02), 6.0)
	draw_polyline(아래, Color(0.02, 0.02, 0.02), 6.0)
	draw_polyline(위, Color(0.60, 0.60, 0.63, 0.75), 2.0)
	draw_polyline(아래, Color(0.60, 0.60, 0.63, 0.75), 2.0)

	# 입구 아치 윤곽 (구멍의 가장자리)
	draw_polyline(아치, Color(0.66, 0.66, 0.69, 0.55), 2.0)

	# ⚠[2026-08-06] 예전엔 암반 위·아래에 밝은 윤곽선을 한 줄씩 그었는데,
	#   암반을 위아래로 더 크게 그리도록 바꾼 뒤로는 그 선이 **덩어리 한가운데를 가로지르는
	#   가로 줄무늬**가 되어 오히려 지저분해졌다(스크린샷에서 확인).
	#   통로 입구의 아치 윤곽만으로 경계는 충분히 읽힌다 → 삭제.

	# ── 5) 바닥에 깔린 빛 반사 ── 통로 안쪽 빛이 젖은 바닥에 비친다
	draw_line(Vector2(d * L * 0.25, -4), Vector2(d * L * 0.92, -4),
		Color(속빛.r, 속빛.g, 속빛.b, 0.30), 7.0)
