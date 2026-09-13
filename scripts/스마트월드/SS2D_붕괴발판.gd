@tool
extends "res://scripts/스마트월드/지형.gd"
## 이전 PaintPlatform 부품을 섞지 않고 SS2D 편집·페인트코어 계약을 그대로 유지한다.

@export_range(0.2, 4.0, 0.05) var 붕괴_대기: float = 0.9
@export_range(1.0, 12.0, 0.1) var 복구_대기: float = 3.0

var _붕괴단계: int = 0
var _남은시간: float = 0.0


func _ready() -> void:
	super._ready()
	# 편집 중에는 타이머나 충돌을 바꾸지 않아 저장된 형상을 보존한다.
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _붕괴단계 == 0:
		if _실제로_밟혔나():
			_붕괴단계 = 1
			_남은시간 = 붕괴_대기
		return
	_남은시간 -= delta
	if _붕괴단계 == 1:
		# 지형 좌표를 흔들면 라이더가 밀린다. 기존 셰이더가 반영하는 알파만 점멸한다.
		var 밝기 := 0.65 + 0.35 * absf(sin(_남은시간 * 24.0))
		self_modulate = Color(1.0, 1.0, 1.0, 밝기)
		if _남은시간 <= 0.0:
			_붕괴단계 = 2
			_남은시간 = 복구_대기
			_충돌레이어_갱신()
	elif _남은시간 <= 0.0 and not _복구위치에_플레이어가_있나():
		# 플레이어 몸 안에서 발판이 되살아나 끼이는 것을 막는다.
		_붕괴단계 = 0
		self_modulate = Color.WHITE
		_충돌레이어_갱신()


func _실제로_밟혔나() -> bool:
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return false
	for 후보 in get_tree().get_nodes_in_group("player"):
		var 몸 := 후보 as CharacterBody2D
		if 몸 == null or not 몸.is_on_floor():
			continue
		for i in 몸.get_slide_collision_count():
			var 접촉 := 몸.get_slide_collision(i)
			if 접촉.get_collider() == 폴리.get_parent() and 접촉.get_normal().dot(Vector2.UP) > 0.5:
				return true
	return false


func _복구위치에_플레이어가_있나() -> bool:
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null or 폴리.polygon.is_empty():
		return false
	var 범위 := Rect2(폴리.polygon[0], Vector2.ZERO)
	for 점 in 폴리.polygon:
		범위 = 범위.expand(점)
	for 몸 in get_tree().get_nodes_in_group("player"):
		if 몸 is Node2D and 범위.grow(64.0).has_point(폴리.to_local(몸.global_position + Vector2(0, -48))):
			return true
	return false


func _충돌레이어_갱신() -> void:
	super._충돌레이어_갱신()
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return
	# 페인트 회수·덮어칠이 들어와도 무너진 동안에는 충돌이 다시 켜지지 않는다.
	폴리.set_deferred("disabled", _붕괴단계 == 2)
	if _붕괴단계 == 2:
		폴리.get_parent().set_deferred("collision_layer", 0)
		self_modulate = Color(1, 1, 1, 0.16)


func 명중(색: int, 월드좌표: Vector2) -> String:
	if _붕괴단계 == 2:
		return "blocked"
	return super.명중(색, 월드좌표)


func 강제_초기화() -> void:
	_붕괴단계 = 0
	_남은시간 = 0.0
	self_modulate = Color.WHITE
	super.강제_초기화()
