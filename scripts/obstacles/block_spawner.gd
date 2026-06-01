extends Node2D

## BlockSpawner
## 일정 간격으로 FallingBlock을 현재 씬에 스폰

@export var block_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_y_offset: float = 0.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_block()


func _spawn_block() -> void:
	if block_scene == null:
		push_warning("BlockSpawner: block_scene이 설정되지 않았습니다.")
		return

	var block: Node = block_scene.instantiate()
	get_tree().current_scene.add_child(block)
	block.global_position = Vector2(global_position.x, global_position.y + spawn_y_offset)
