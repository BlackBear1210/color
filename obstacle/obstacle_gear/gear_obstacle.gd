extends AnimatableBody2D

@export_group("Movement Direction")
@export var move_horizontal: bool = true
@export var move_vertical: bool = false

@export_group("Movement Settings")
@export var move_distance: float = 100.0
@export var move_speed: float = 80.0

var _start_position: Vector2
var _direction: float = 1.0


func _ready() -> void:
	_start_position = global_position
	add_to_group("obstacle")


func _physics_process(delta: float) -> void:
	var travel := _direction * move_speed * delta
	var next_position := global_position

	if move_horizontal:
		next_position.x += travel
	elif move_vertical:
		next_position.y += travel

	var offset := next_position - _start_position
	var distance := offset.x if move_horizontal else offset.y

	if distance > move_distance or distance < 0.0:
		_direction *= -1.0

	move_and_collide(next_position - global_position)
