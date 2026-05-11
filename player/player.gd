extends CharacterBody2D

enum PlayerColor {
	WHITE,
	BLACK
}

@export var move_speed: float = 150.0

@export var jump_velocity: float = -300.0
@export var gravity: float = 1700.0
@export var fall_gravity_multiplier: float = 1.2
@export var max_fall_speed: float = 500.0
@export var jump_hold_force: float = -900.0
@export var max_jump_hold_time: float = 0.18
@export var jump_cut_multiplier: float = 0.45
@export var jump_buffer_time: float = 0.12

@export var respawn_position: Vector2 = Vector2(216, 464)
@export var fall_limit: float = 600.0

var last_direction: float = 0.0
var current_color: PlayerColor = PlayerColor.BLACK

var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_buffer_timer: float = 0.0

@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	update_player_color()


func _physics_process(delta: float) -> void:
	update_jump_buffer(delta)
	apply_gravity(delta)
	handle_horizontal_movement()
	handle_jump(delta)
	handle_color_toggle()
	move_and_slide()
	check_color_tile_collision()
	check_fall_death()


func update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
		if jump_buffer_timer < 0.0:
			jump_buffer_timer = 0.0


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * fall_gravity_multiplier * delta
		else:
			velocity.y += gravity * delta
		if velocity.y > max_fall_speed:
			velocity.y = max_fall_speed
	else:
		is_jumping = false
		jump_hold_timer = 0.0


func handle_horizontal_movement() -> void:
	if Input.is_action_just_pressed("move_right"):
		last_direction = 1.0
	if Input.is_action_just_pressed("move_left"):
		last_direction = -1.0
	
	if Input.is_action_pressed("move_left") and Input.is_action_pressed("move_right"):
		velocity.x = last_direction * move_speed
	else:
		var direction := Input.get_axis("move_left", "move_right")
		velocity.x = direction * move_speed
		if direction != 0:
			last_direction = direction


func handle_jump(delta: float) -> void:
	if jump_buffer_timer > 0.0 and is_on_floor():
		velocity.y = jump_velocity
		is_jumping = true
		jump_hold_timer = 0.0
		jump_buffer_timer = 0.0

	if is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < max_jump_hold_time:
		velocity.y += jump_hold_force * delta
		jump_hold_timer += delta

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier
		is_jumping = false


func handle_color_toggle() -> void:
	if Input.is_action_just_pressed("color_toggle"):
		if current_color == PlayerColor.WHITE:
			current_color = PlayerColor.BLACK
		else:
			current_color = PlayerColor.WHITE
		update_player_color()


func update_player_color() -> void:
	match current_color:
		PlayerColor.WHITE:
			sprite_2d.modulate = Color.WHITE
		PlayerColor.BLACK:
			sprite_2d.modulate = Color.BLACK


func check_color_tile_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		
		if collider == null:
			continue
			
		if collider.is_in_group("falling_blocks"):
			die()
			return
		
		if collider.is_in_group("obstacle"):
			die()
			return
		
		if current_color == PlayerColor.WHITE and collider.is_in_group("black_tiles"):
			die()
			return
		
		if current_color == PlayerColor.BLACK and collider.is_in_group("white_tiles"):
			die()
			return
		
		


func check_fall_death() -> void:
	if global_position.y > fall_limit:
		die()


func die() -> void:
	print("사망")
	global_position = respawn_position
	velocity = Vector2.ZERO
	current_color = PlayerColor.BLACK
	update_player_color()
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		camera.snap_to_initial()
		
		
