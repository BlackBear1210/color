extends Node2D
## 각 스테이지의 베이스 스크립트.
## KillZone 에 빠진 바디에 die() 를 호출하고, Camera2D 맵 경계를 설정한다.

## 카메라가 이동 가능한 맵 경계 (픽셀 단위)
@export var camera_limit_left:   int = 0
@export var camera_limit_top:    int = 0
@export var camera_limit_right:  int = 100000
@export var camera_limit_bottom: int = 100000

@onready var kill_zone: Area2D = $MapPhysics/KillZone

func _ready() -> void:
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)
	# Player 는 _ready() 이후에 추가되므로 한 프레임 뒤에 적용
	call_deferred("_apply_camera_limits")

func _apply_camera_limits() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left   = camera_limit_left
			cam.limit_top    = camera_limit_top
			cam.limit_right  = camera_limit_right
			cam.limit_bottom = camera_limit_bottom

func _on_kill_zone_entered(body: Node) -> void:
	if body.has_method("die"):
		body.die()
