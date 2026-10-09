extends Node2D
## 발 아래 짧은 접지 그림자로 목재 상판 위에 서 있음을 읽히게 한다. 충돌·색 판정에는 참여하지 않는다.
var _몸: CharacterBody2D
var _그림: AnimatedSprite2D

func _ready() -> void:
	_몸 = get_parent() as CharacterBody2D
	_그림 = _몸.get_node_or_null("CharacterSprite") as AnimatedSprite2D
	top_level = true
	visible = false
	get_parent().move_child(self, 0)
	queue_redraw()

func _process(_delta: float) -> void:
	visible = _몸 != null and _몸.is_on_floor() and _몸.is_physics_processing()
	if not visible or _그림 == null:
		return
	var 면: Dictionary = _그림.call("_발밑_접촉")
	if 면.is_empty():
		visible = false
		return
	global_position = Vector2(면["point"]) + Vector2(0, float(면.get("그림깊이", 0)))
	global_rotation = 0.0
	global_scale = Vector2.ONE

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.10))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.25))
