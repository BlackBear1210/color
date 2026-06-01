extends RigidBody2D

## 낙하 블록 (FallingBlock)
## BlockSpawner가 스폰 → 중력 낙하 → 플레이어 사망 처리

@export var despawn_y: float = 1200.0

@onready var kill_area: Area2D = $KillArea


func _ready() -> void:
	add_to_group("falling_blocks")
	add_to_group("obstacle")  # 총알 PaintMark 생성 차단

	kill_area.body_entered.connect(_on_kill_area_entered)


func _process(_delta: float) -> void:
	if global_position.y > despawn_y:
		queue_free()


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
		call_deferred("queue_free")
