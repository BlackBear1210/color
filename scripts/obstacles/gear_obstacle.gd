extends AnimatableBody2D

## 톱니 장애물 (GearObstacle)
## 회전 또는 이동하며 플레이어에 닿으면 사망

@export var rotate_speed: float = 90.0     # 초당 회전 각도 (0이면 회전 없음)
@export var move_distance: float = 0.0     # 왕복 이동 거리 (0이면 이동 없음)
@export var move_speed: float = 100.0      # 이동 속도

# ▼ 2026-06-22 추가(stage_3): 이동 방향을 좌우/위아래로 선택.
#   false = 좌우(가로) 왕복(기존 동작) / true = 위아래(세로) 왕복.
#   왜: stage_3 가 '좌우로 움직이는 톱니'와 '위아래로 움직이는 톱니' 둘 다 요구.
@export var move_vertical: bool = false

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

	# 왕복 이동 (move_vertical 에 따라 축 선택)
	if move_distance > 0.0:
		# ▼ 2026-06-22: 세로면 y, 가로면 x 축으로 왕복. 시작점 기준 거리로 방향 반전.
		if move_vertical:
			global_position.y += move_speed * _move_dir * delta
			if abs(global_position.y - _start_position.y) >= move_distance:
				_move_dir *= -1.0
		else:
			global_position.x += move_speed * _move_dir * delta
			if abs(global_position.x - _start_position.x) >= move_distance:
				_move_dir *= -1.0


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
