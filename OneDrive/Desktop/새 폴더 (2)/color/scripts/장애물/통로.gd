@tool
extends Area2D
## ============================================================================
## 🚇 통로 (Passage)  —  [2026-07-25 도형 · 신규]  ※ 구 `목표문.tscn` 대체
## ----------------------------------------------------------------------------
## 스테이지와 스테이지를 잇는 **공간**. 포탈이 아니다.
##
## ▣ 왜 바꿨나
##   구 `목표문` 은 허공에 뜬 아치에 흑↔백이 맥동하는 "게임적인 포탈"이었다.
##   도형님 지적대로 이 게임 톤(LIMBO·리틀 나이트메어 계열)과 안 맞았다.
##   → 지형에 파인 **터널 입구**로 바꿨다. 안쪽은 어둡고, 저 끝에서 **다음 지역의 빛**이
##     새어나온다. 플레이어는 "문을 여는" 게 아니라 **그냥 걸어 들어간다.**
##
## ▣ 연결 규약 (자연스러운 이어짐의 핵심)
##   · 스테이지 끝 = `출구` 통로 (오른쪽을 보고 있음, `zone_exit` 그룹)
##   · 스테이지 시작 = `입구` 통로 (왼쪽을 보고 있음, 장식 전용 — 판정 없음)
##   · 출구의 **속빛 색 = 다음 스테이지 하늘색**, 입구의 속빛 = 이전 스테이지 하늘색
##     → 통로를 지나면 방금 본 빛깔의 하늘이 실제로 펼쳐진다 = 공간이 이어진 느낌
##   · 전환도 잉크 와이프가 아니라 **어둠으로 페이드**한다 (터널을 지나는 동안 어두워지는 것)
##
## ▣ 쓰는 법
##   scenes/장애물/통로.tscn 을 지형 끝에 드래그 → `역할`(출구/입구)과 `속빛` 만 지정.
##   위치 원점 = 통로 바닥 중앙(지면에 붙인다).
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

@export_enum("출구", "입구") var 역할: int = 0:
	set(v): 역할 = v; _재구성()
@export_range(48, 400) var 폭: int = 120:
	set(v): 폭 = v; _재구성()
@export_range(64, 500) var 높이: int = 150:
	set(v): 높이 = v; _재구성()
## 통로 저 끝에서 새어나오는 빛 색 = **이어지는 지역의 하늘색**
@export var 속빛: Color = Color(0.30, 0.30, 0.32):
	set(v): 속빛 = v; _속빛_갱신(); queue_redraw()

var _t: float = 0.0
var _light: PointLight2D

func _ready() -> void:
	if 역할 == 0:
		add_to_group("zone_exit")     # stage_lab 이 이 그룹만 보고 다음 스테이지로 넘긴다
	collision_layer = 0
	collision_mask = 1
	monitoring = 역할 == 0            # 입구는 장식이므로 판정 없음
	_재구성()

func _재구성() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("충돌") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "충돌"
		add_child(cs)
	var sh := cs.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		cs.shape = sh
	# 판정은 통로 안쪽 절반만 — 입구를 스치기만 해도 넘어가 버리는 것을 막는다
	sh.size = Vector2(폭 * 0.45, 높이 * 0.8)
	cs.position = Vector2(0, -높이 * 0.5)

	# 통로 안쪽에서 지형으로 새어나오는 빛
	if _light == null:
		_light = get_node_or_null("속빛광원") as PointLight2D
	if _light == null:
		_light = PointLight2D.new()
		_light.name = "속빛광원"
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 256
		tex.height = 256
		_light.texture = tex
		_light.texture_scale = 520.0 / 256.0
		_light.energy = 0.9
		add_child(_light)
	_light.position = Vector2(0, -높이 * 0.55)
	_속빛_갱신()
	queue_redraw()

func _속빛_갱신() -> void:
	if _light:
		# 하늘색을 그대로 쓰면 너무 어두우므로 밝기를 끌어올려 "새어나오는 빛"으로
		_light.color = 속빛.lightened(0.55)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := float(폭)
	var h := float(높이)
	var 방향 := 1.0 if 역할 == 0 else -1.0     # 출구는 오른쪽, 입구는 왼쪽을 향한다

	# ── 1) 통로 안쪽(어둠) — 위가 둥근 아치형 구멍 ──
	var 안쪽 := PackedVector2Array()
	var 단계 := 14
	안쪽.append(Vector2(-w * 0.5, 0))
	for i in 단계 + 1:
		var a := PI * float(i) / float(단계)
		안쪽.append(Vector2(-cos(a) * w * 0.5, -h * 0.62 - sin(a) * h * 0.38))
	안쪽.append(Vector2(w * 0.5, 0))
	draw_colored_polygon(안쪽, Color(0.035, 0.035, 0.04))

	# ── 2) 저 끝에서 새어나오는 빛 — 안쪽 깊은 곳이 밝다 ──
	# (다음 지역의 하늘색이므로, 지나가기 전에 이미 "그쪽 분위기"가 보인다)
	var 맥동 := 0.86 + 0.14 * sin(_t * 1.1)
	var 빛중심 := Vector2(방향 * w * 0.14, -h * 0.52)
	for i in range(6, 0, -1):
		var r := w * 0.42 * float(i) / 6.0
		var a := 0.055 * 맥동 * (1.0 - float(i) / 7.0) * 6.0
		draw_circle(빛중심, r, Color(속빛.r, 속빛.g, 속빛.b, a * 0.5))

	# ── 3) 통로 테두리 — 지형에서 파낸 단면 (2겹 외곽선) ──
	var 테두리 := PackedVector2Array(안쪽)
	테두리.append(안쪽[0])
	draw_polyline(테두리, Color(0.02, 0.02, 0.02), 7.0, true)
	draw_polyline(테두리, Color(0.62, 0.62, 0.64, 0.85), 2.0, true)

	# ── 4) 바닥 문지방 — 통로 안으로 이어지는 길바닥 ──
	draw_line(Vector2(-w * 0.5, -1), Vector2(w * 0.5, -1),
		Color(0.55, 0.55, 0.57, 0.7), 3.0)
	# 안쪽 바닥에 깔린 빛 반사
	draw_line(Vector2(-w * 0.30, -5), Vector2(w * 0.30, -5),
		Color(속빛.r, 속빛.g, 속빛.b, 0.35), 6.0)
