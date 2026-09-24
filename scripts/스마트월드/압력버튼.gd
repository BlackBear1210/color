@tool
extends AnimatableBody2D
## ============================================================================
## 압력 버튼 — 밟기 상호작용과 이동 대상을 인스펙터에서 연결하는 범용 장치
## ----------------------------------------------------------------------------
## 버튼은 직접 길을 만들지 않는다. `대상들`에 움직일 Node2D를 지정하고, 같은
## 순서의 `대상_이동량들`에 이동 벡터를 넣는다. 그래서 벽·발판·문 등 어떤
## Node2D라도 하나의 버튼으로 움직일 수 있다.
##
## 2-2 입구는 버튼에서 내린 뒤에도 통로가 유지되어야 실제로 건널 수 있으므로
## `한 번 누르면 유지`를 쓴다. 다른 퍼즐에서는 `누르는 동안만`으로 바꿔
## 양동이·상자 등을 올려두는 유지형 버튼으로 쓸 수 있다.
## ============================================================================
class_name 압력버튼

# 호퍼와 같은 주철 부품을 분리해서 상판만 눌리고 고정 프레임은 움직이지 않게 한다.
const 주철_부품 = preload("res://assets/textures/obstacles/switch/cast_iron_v1/parts.png")

@export_group("버튼 모양")
@export_range(48.0, 320.0) var 폭: float = 96.0:
	set(v):
		폭 = v
		_재구성()
@export_range(12.0, 80.0) var 높이: float = 24.0:
	set(v):
		높이 = v
		_재구성()
@export_range(12.0, 120.0) var 감지_높이: float = 44.0:
	set(v):
		감지_높이 = v
		_재구성()

@export_group("상호작용 설정")
## 0=버튼 위에 무게가 있는 동안만, 1=처음 밟은 뒤 계속 켜짐.
@export_enum("누르는 동안만", "한 번 누르면 유지") var 작동방식: int = 0
## 기본 player 외에 양동이·상자 그룹을 추가하면 그 물체도 버튼을 누를 수 있다.
@export var 누름_가능_그룹: PackedStringArray = PackedStringArray(["player"])
## 이 버튼과 동시에 눌려야 할 다른 버튼들. 이 버튼만 `대상들`을 움직이면 된다.
## 따라서 두 버튼이 같은 벽을 서로 다른 위치로 덮어쓰는 충돌을 막는다.
@export var 동시_버튼들: Array[NodePath] = []

@export_group("움직일 대상")
## 대상들과 이동량들은 같은 번호끼리 짝이다. NodePath는 인스펙터의 노드 선택기로 넣는다.
@export var 대상들: Array[NodePath] = []
## 예: Vector2(0, 800)은 아래 800px, Vector2(320, 0)은 오른쪽 320px 이동이다.
@export var 대상_이동량들: Array[Vector2] = []
@export_range(40.0, 1200.0) var 이동속도: float = 360.0

var _감지: Area2D
var _대상_노드들: Array[Node2D] = []
var _대상_시작위치들: Array[Vector2] = []
var _기억된_눌림 := false
var _활성 := false
var _눌림_표현 := 0.0


func _ready() -> void:
	_재구성()
	_대상_연결_갱신()
	if Engine.is_editor_hint():
		return
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var 지금_눌림 := _누를_수_있는_몸이_올라섰나()
	if 지금_눌림:
		_기억된_눌림 = true
	var 새_활성 := _기억된_눌림 if 작동방식 == 1 else 지금_눌림
	if 새_활성 and not _동시_버튼도_눌렸나():
		새_활성 = false
	if 새_활성 != _활성:
		_활성 = 새_활성
		queue_redraw()
	# 활성 전환 한 번만 다시 그리면 눌림/복귀 중간 프레임이 멎으므로 이동 중에도 갱신한다.
	var 이전_표현 := _눌림_표현
	_눌림_표현 = move_toward(_눌림_표현, 1.0 if 지금_눌림 else 0.0, delta * 8.0)
	if 이전_표현 != _눌림_표현:
		queue_redraw()
	_대상_이동(delta)


func _대상_연결_갱신() -> void:
	_대상_노드들.clear()
	_대상_시작위치들.clear()
	for 경로 in 대상들:
		var 대상 := get_node_or_null(경로) as Node2D
		if 대상 == null:
			# 아직 씬 트리에 붙지 않은 @tool 편집 순간에는 조용히 건너뛴다.
			# 게임 실행 때도 못 찾으면 그 대상만 움직이지 않아 다른 연결은 안전하게 유지된다.
			continue
		# ★[2026-09-07] 메타 이름은 **ASCII 식별자**여야 한다(`Object::set_meta` 검사).
		#   `_압력버튼_원래위치` 는 밑줄로 시작해서, 밑줄을 뗀 `압력버튼_원래위치` 는
		#   한글이라서 둘 다 거부됐다 — 씬을 열 때마다 "Invalid metadata identifier" 가
		#   뜨고 원래 위치가 한 번도 안 적혔다(하수도 2-2 · 2-7 에서 실제로 났다).
		대상.set_meta("pressure_button_origin", 대상.position)
		_대상_노드들.append(대상)
		_대상_시작위치들.append(대상.position)


func _대상_이동(delta: float) -> void:
	for i in _대상_노드들.size():
		var 대상 := _대상_노드들[i]
		if not is_instance_valid(대상):
			continue
		var 이동량 := 대상_이동량들[i] if i < 대상_이동량들.size() else Vector2.ZERO
		var 목표 := _대상_시작위치들[i] + (이동량 if _활성 else Vector2.ZERO)
		# 물리 프레임에서 Node2D를 움직여 SS2D 자식 충돌도 그림과 같은 위치로 갱신한다.
		대상.position = 대상.position.move_toward(목표, 이동속도 * delta)


func _누를_수_있는_몸이_올라섰나() -> bool:
	if _감지 == null:
		return false
	for 몸 in _감지.get_overlapping_bodies():
		for 그룹 in 누름_가능_그룹:
			if not 몸.is_in_group(그룹):
				continue
			# 양동이는 물을 실어야만 무게추가 된다. 빈 양동이까지 버튼을 누르면
			# "물을 채워 무게를 남긴다"는 퍼즐 규칙이 사라진다.
			if 그룹 == "양동이" and not bool(몸.get("물참")):
				continue
			return true
	return false


## 이 버튼의 현재 유지형/순간형 활성 상태를 다른 버튼이 읽는 안전한 공개 창구다.
func 활성인가() -> bool:
	return _활성


func _동시_버튼도_눌렸나() -> bool:
	for 경로 in 동시_버튼들:
		var 다른버튼 := get_node_or_null(경로)
		if 다른버튼 == null or not 다른버튼.has_method("활성인가"):
			return false
		if not bool(다른버튼.call("활성인가")):
			return false
	return true


func _재구성() -> void:
	if not is_inside_tree():
		return
	# Area2D는 누름만 감지하고, 별도 StaticBody2D가 실제로 밟을 수 있는 단단한 윗면이 된다.
	if _감지 == null:
		_감지 = get_node_or_null("누름감지") as Area2D
	if _감지 == null:
		_감지 = Area2D.new()
		_감지.name = "누름감지"
		add_child(_감지)
		_편집기_주인_지정(_감지)
	_감지.collision_layer = 0
	_감지.collision_mask = 1
	_감지.monitoring = true
	var 감지모양 := _감지.get_node_or_null("모양") as CollisionShape2D
	if 감지모양 == null:
		감지모양 = CollisionShape2D.new()
		감지모양.name = "모양"
		감지모양.visible = false
		_감지.add_child(감지모양)
		_편집기_주인_지정(감지모양)
	var 감지사각 := 감지모양.shape as RectangleShape2D
	if 감지사각 == null:
		감지사각 = RectangleShape2D.new()
		감지모양.shape = 감지사각
	감지사각.size = Vector2(폭 * 0.86, 감지_높이)
	감지모양.position = Vector2(0, -높이 * 0.5 - 감지_높이 * 0.5 + 4.0)

	var 발판 := get_node_or_null("밟는면") as StaticBody2D
	if 발판 == null:
		발판 = StaticBody2D.new()
		발판.name = "밟는면"
		add_child(발판)
		_편집기_주인_지정(발판)
	발판.collision_layer = 1
	발판.collision_mask = 0
	var 발판모양 := 발판.get_node_or_null("모양") as CollisionShape2D
	if 발판모양 == null:
		발판모양 = CollisionShape2D.new()
		발판모양.name = "모양"
		발판모양.visible = false
		발판.add_child(발판모양)
		_편집기_주인_지정(발판모양)
	var 발판사각 := 발판모양.shape as RectangleShape2D
	if 발판사각 == null:
		발판사각 = RectangleShape2D.new()
		발판모양.shape = 발판사각
	발판사각.size = Vector2(폭, 높이)
	발판모양.position = Vector2(0, -높이 * 0.5)
	queue_redraw()


func _편집기_주인_지정(노드: Node) -> void:
	# 새로 만든 보조 노드에만 owner를 준다. 읽어 온 SS2D 노드는 절대 다시 소유하지 않는다.
	if Engine.is_editor_hint() and get_tree() != null:
		노드.owner = get_tree().edited_scene_root


func _draw() -> void:
	# 충돌/감지는 보존하고 최대 3px의 시각적 스트로크만 아래로 눌러 기존 점프 거리를 유지한다.
	var 눌림 := _눌림_표현 * minf(3.0, 높이 * 0.125)
	draw_texture_rect_region(주철_부품, Rect2(-폭 * 0.5, -높이 * 0.55, 폭, 높이 * 0.55), Rect2(28, 425, 570, 72))
	draw_texture_rect_region(주철_부품, Rect2(-폭 * 0.455, -높이 + 눌림, 폭 * 0.91, 높이 * 0.55), Rect2(679, 395, 520, 89))
	# 표시창은 실제 출력 활성 상태, 상판은 실제 무게를 표시해 유지형 버튼도 구분한다.
	if _활성:
		draw_rect(Rect2(-폭 * 0.12, -높이 * 0.31, 폭 * 0.24, maxf(1.5, 높이 * 0.09)), Color(0.87, 0.87, 0.85))
