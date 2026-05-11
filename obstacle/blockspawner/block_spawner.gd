extends Node2D

@export var block_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var spawn_count: int = 1
@export var spawn_delay: float = 0.15   # 블록 사이 간격 (초)
@export var spawn_y_offset: float = -40.0

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.autostart = true
	_timer.timeout.connect(_on_spawn_timer)
	add_child(_timer)

func _draw() -> void:
	draw_circle(Vector2(0, spawn_y_offset), 8.0, Color.YELLOW)
	draw_line(Vector2(-20, spawn_y_offset), Vector2(20, spawn_y_offset), Color.YELLOW, 3.0)

func _on_spawn_timer() -> void:
	for i in spawn_count:
		await get_tree().create_timer(spawn_delay * i).timeout
		_spawn_block()

func _spawn_block() -> void:
	if block_scene == null:
		push_error("BlockSpawner: block_scene이 설정되지 않았습니다.")
		return
	var block: RigidBody2D = block_scene.instantiate()
	block.global_position = Vector2(global_position.x, global_position.y + spawn_y_offset)
	get_tree().current_scene.add_child(block)

func set_spawning(enabled: bool) -> void:
	if enabled:
		_timer.start()
	else:
		_timer.stop()
