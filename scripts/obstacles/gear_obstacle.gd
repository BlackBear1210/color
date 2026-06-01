extends AnimatableBody2D

## 톱니 장애물 (GearObstacle)
## 회전 또는 이동하며 플레이어에 닿으면 사망

@export var rotate_speed: float = 90.0     # 초당 회전 각도 (0이면 회전 없음)
@export var move_distance: float = 0.0     # 왕복 이동 거리 (0이면 이동 없음)
@export var move_speed: float = 100.0      # 이동 속도

var _start_position: Vector2
var _move_dir: float = 1.0

@onready var kill_area: Area2D = $KillArea


func _ready() -> void:
	_start_position = global_position
	add_to_group("obstacle")  # 총알 PaintMark 차단
	kill_area.body_entered.connect(_on_kill_area_entered)


func _physics_process(delta: float) -> void:
	# 회전
	if rotate_speed != 0.0:
		rotation_degrees += rotate_speed * delta

	# 왕복 이동
	if move_distance > 0.0:
		global_position.x += move_speed * _move_dir * delta
		var dist := global_position.x - _start_position.x
		if abs(dist) >= move_distance:
			_move_dir *= -1.0


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
