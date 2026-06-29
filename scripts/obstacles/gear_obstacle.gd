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
var _elapsed: float = 0.0

@onready var kill_area: Area2D = $KillArea


func _ready() -> void:
	_start_position = global_position
	add_to_group("obstacle")  # 총알 PaintMark 차단
	kill_area.body_entered.connect(_on_kill_area_entered)


func _physics_process(delta: float) -> void:
	# 회전
	if rotate_speed != 0.0:
		rotation_degrees += rotate_speed * delta

	# ▼ 2026-06-29 (버그수정): 기존엔 끝점에서 속도를 한 프레임에 +→- 로 순간 반전시켰는데,
	#   AnimatableBody2D(sync_to_physics=true)가 다른 바디를 밀어주려고 매 프레임 이동량으로
	#   속도를 추정하다 보니, 이 불연속 반전 프레임에서 추정이 어긋나 끝점에서 떨리는
	#   현상이 있었다(지형과 안 겹쳐도 재현됨 → 충돌 문제가 아니라 반전 방식 자체가 원인).
	#   → 사인파로 이동시켜 끝점에서 속도가 자연스럽게 0으로 줄어들게 한다(불연속 제거).
	if move_distance > 0.0:
		_elapsed += delta
		var angular_speed := move_speed / move_distance   # 중심에서 속도가 move_speed가 되도록
		var offset := sin(_elapsed * angular_speed) * move_distance
		if move_vertical:
			global_position.y = _start_position.y + offset
		else:
			global_position.x = _start_position.x + offset


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
