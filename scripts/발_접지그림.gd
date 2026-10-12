extends Node2D
## 발 아래 짧은 접지 그림자로 목재 상판 위에 서 있음을 읽히게 한다. 충돌·색 판정에는 참여하지 않는다.
const 발_모션 := preload("res://scripts/player_anim.gd")
var _몸: CharacterBody2D
var _그림: AnimatedSprite2D

func _ready() -> void:
	_몸 = get_parent() as CharacterBody2D
	_그림 = _몸.get_node_or_null("CharacterSprite") as AnimatedSprite2D
	# 발 그림의 스냅·기울기·눌림이 갱신된 뒤 따라가야 이동 중 그림자만 한 프레임 뒤처지지 않는다.
	if _그림:
		process_priority = _그림.process_priority + 1
	top_level = true
	visible = false
	get_parent().move_child(self, 0)
	queue_redraw()

func _process(_delta: float) -> void:
	visible = _몸 != null and _몸.is_on_floor() and _몸.is_physics_processing()
	# 하수도는 공중 투영도 맡는 전용 그림자를 쓰므로 공통 그림자를 겹쳐 발 뒤에 두 겹으로 남기지 않는다.
	if visible and _몸.has_node("발밑그림자"):
		visible = false
	if not visible or _그림 == null:
		return
	var 면: Dictionary = _그림.call("_발밑_접촉")
	if 면.is_empty():
		visible = false
		return
	# 지형 접점에 깊이를 다시 더하면 부드럽게 보정되는 실제 발과 어긋난다.
	# 본체 모션과 같은 발끝 기준을 월드로 옮겨 높이 보정·기울기·스쿼시를 그대로 따른다.
	var 발끝 := Vector2(0, 발_모션.FOOT_Y - 발_모션.FRAME_PX * 0.5)
	global_position = _그림.to_global(발끝)
	# 잠긴 발을 가린 뒤에도 접지 그림자가 수면 위에 남으면 발처럼 보인다. 같은 물 윤곽에서 숨긴다.
	for pool in get_tree().get_nodes_in_group("웅덩이"):
		if pool.get("켜짐") and pool.has_method("물그림_다각형"):
			if Geometry2D.is_point_in_polygon(pool.to_local(global_position), pool.call("물그림_다각형")):
				visible = false
				return
	global_rotation = 0.0
	global_scale = Vector2.ONE

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.22))
	# 세 겹의 알파가 누적돼 발밑이 검게 뭉쳤으므로 중심 합성 진함을 약 45%에서 20%로 낮춘다.
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.04))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.07))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.10))
