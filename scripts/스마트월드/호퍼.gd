@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 호퍼 — 물을 받아 배관으로 흘려보내는 깔때기
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 색칠할 수 없다.
##   · **플랫폼처럼 밟을 수 있다.**
##   · 위에서 흐르는 물을 모아서 배관으로 연결한다.
##
## ▣ 동작
##   입구(위쪽 Area2D)에 물이 닿으면 `출구_유체` 를 켜고, 그 물의 색을 물려준다.
##   물이 끊기면 출구도 꺼진다. → "위에서 물이 오면 아래로 흘러나간다"가 눈에 보인다.
## ============================================================================
class_name 호퍼

@export var 폭: float = 120.0:
	set(v): 폭 = maxf(v, 32.0); _다시_만들기()
@export var 높이: float = 56.0:
	set(v): 높이 = maxf(v, 16.0); _다시_만들기()

## 이 호퍼가 채우는 유체(보통 아래로 내려가는 물줄기). 비우면 출구 포트로 자동 탐색한다.
@export var 출구_유체: NodePath

## 2D 작업 화면에서 물줄기 시작점이 출구_포트에 닿으면 NodePath를 고르지 않아도 자동 연결한다.
@export_group("출구 포트 자동 연결")
@export var 자동_출구_연결: bool = true
@export_range(8.0, 128.0, 1.0) var 포트_연결거리: float = 36.0
@export_group("")

var _입구: Area2D
var _출구: 유체 = null
var _수동_출구: bool = false


func _ready() -> void:
	collision_layer = 1               # 밟을 수 있다
	collision_mask = 0
	_다시_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("호퍼")
	if not 출구_유체.is_empty():
		_출구 = get_node_or_null(출구_유체) as 유체
		_수동_출구 = _출구 != null
		if _출구 == null:
			push_warning("[호퍼:%s] 출구_유체 경로(%s)에서 유체 노드를 못 찾음" % [name, 출구_유체])
	if _출구 == null and 자동_출구_연결:
		_출구 = _포트에_닿은_유체_찾기()
	if _출구:
		_출구.켜짐 = false             # 물이 들어오기 전엔 꺼둔다
	# 자동 포트는 다른 노드의 _ready 순서보다 늦게 발견될 수 있어, 출구가 아직 없어도 검사한다.
	set_physics_process(_출구 != null or 자동_출구_연결)
	queue_redraw()


## [디버그전용] 1초마다 입구가 실제로 뭘 감지하고 있는지 찍는다.
## "물이 안 들어오는 것 같다"는 제보 원인 확인용 — 겹치는 유체가 0개인지,
## 겹치는데도 종류/색이 안 맞는지 구분할 수 있다.
var _디버그_누적: float = 0.0


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	# 밟는 면 — 깔때기 윗면만 단단하다 (안쪽은 뚫려 있어야 물이 통과하는 느낌)
	var c := get_node_or_null("윗면") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "윗면"
		add_child(c)
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = Vector2(폭, 12.0)
	c.position = Vector2(0, -높이 + 6.0)

	# 입구 감지 영역 — 윗면 바로 위
	_입구 = get_node_or_null("입구") as Area2D
	if _입구 == null:
		_입구 = Area2D.new()
		_입구.name = "입구"
		var ic := CollisionShape2D.new()
		ic.name = "모양"
		ic.shape = RectangleShape2D.new()
		_입구.add_child(ic)
		add_child(_입구)
	_입구.collision_layer = 0
	_입구.collision_mask = 32          # 유체만 본다
	var ish := (_입구.get_node("모양") as CollisionShape2D).shape as RectangleShape2D
	# ★[2026-08-06 수정] 원래 세로 40px 짜리라, 위에서 내려오는 물줄기를 몇 px 만 헐겁게
	# 배치해도 아예 안 겹쳐서 영원히 감지가 안 되는 문제가 있었다(제보: "확인불가",
	# 실측 로그로 "입구 겹침 0개" 확인). 깔때기 윗면 높이는 그대로 두고, 감지 영역만
	# 위로 넉넉히(90px) 뻗게 해서 물줄기 배치가 어느 정도 어긋나도 겹치게 만든다.
	ish.size = Vector2(폭 * 0.9, 90.0)
	(_입구.get_node("모양") as CollisionShape2D).position = Vector2(0, -높이 - 39.0)
	var 출구포트 := get_node_or_null("출구_포트") as Marker2D
	if 출구포트 != null:
		# 호퍼의 원점 자체가 좁아진 아래 출구다. 물줄기의 시작점을 여기에 스냅해 둔다.
		출구포트.position = Vector2.ZERO
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _입구 == null:
		return
	if 자동_출구_연결 and not _수동_출구:
		var 자동출구 := _포트에_닿은_유체_찾기()
		if 자동출구 != _출구:
			if _출구 != null:
				_출구.켜짐 = false
			_출구 = 자동출구
	if _출구 == null:
		return
	var 받은색 := -1
	var 겹치는_영역 := _입구.get_overlapping_areas()
	for a in 겹치는_영역:
		var f := a as 유체
		if f and f.켜짐 and f.종류 == 유체.종류_.물:
			받은색 = f.색 if 받은색 < 0 else 유체.섞기(받은색, f.색)
	var 켤까 := 받은색 >= 0
	if _출구.켜짐 != 켤까:
		if OS.is_debug_build():
			print("[호퍼:%s] 출구 %s (받은색=%d, 겹치는 영역 %d개)" % [name, ("켬" if 켤까 else "끔"), 받은색, 겹치는_영역.size()])
		_출구.켜짐 = 켤까
	if 켤까 and _출구.색 != 받은색:
		_출구.색 = 받은색

	if OS.is_debug_build():
		_디버그_누적 += delta
		if _디버그_누적 >= 1.0:
			_디버그_누적 = 0.0
			var 목록 := []
			for a in 겹치는_영역:
				목록.append("%s(유체=%s)" % [a.name, a is 유체])
			print("[호퍼:%s] 입구 겹침 %d개: %s" % [name, 겹치는_영역.size(), 목록])


## 유체의 원점은 물이 시작되는 출구다. 포트 중심에서 허용 거리 안인 물만 고른다.
## 이렇게 해야 호퍼 옆을 지나가는 물줄기가 우연히 가까워도 출구로 잘못 잡히지 않는다.
func _포트에_닿은_유체_찾기() -> 유체:
	if not 자동_출구_연결 or not is_inside_tree():
		return null
	var 포트 := get_node_or_null("출구_포트") as Marker2D
	if 포트 == null:
		return null
	var 가장가까운: 유체 = null
	var 최소거리제곱 := 포트_연결거리 * 포트_연결거리
	for 노드 in get_tree().get_nodes_in_group("유체"):
		var 후보 := 노드 as 유체
		if 후보 == null or 후보.종류 != 유체.종류_.물:
			continue
		var 거리제곱 := 포트.global_position.distance_squared_to(후보.시작점_월드좌표())
		if 거리제곱 <= 최소거리제곱:
			가장가까운 = 후보
			최소거리제곱 = 거리제곱
	return 가장가까운


# ── 페인트코어와의 약속 — 색칠할 수 없다 ────────────────────────────────────
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"

func 되돌리기() -> bool:
	return false

func 현재색() -> int:
	return -1

func 반대색인가(_플레이어색: int) -> bool:
	return false


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 금속 := Color(0.24, 0.25, 0.28)
	var 밝은 := Color(0.42, 0.43, 0.46)
	var w := 폭 * 0.5
	# 깔때기 — 위가 넓고 아래가 좁은 사다리꼴
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -높이), Vector2(w, -높이), Vector2(24, 0), Vector2(-24, 0)
	]), 금속)
	# 윗면 테두리 (밟는 면임을 알려주는 밝은 띠)
	draw_rect(Rect2(Vector2(-w - 4, -높이 - 6), Vector2(폭 + 8, 10)), 밝은)
	# 안쪽 그림자 — 깊이감
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w + 10, -높이 + 6), Vector2(w - 10, -높이 + 6),
		Vector2(18, -6), Vector2(-18, -6)
	]), Color(0.10, 0.10, 0.12))
