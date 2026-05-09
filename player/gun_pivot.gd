extends Node2D

var black_tilemap: TileMapLayer
var white_tilemap: TileMapLayer
@export var bullet_scene: PackedScene

func _ready() -> void:
	black_tilemap = get_tree().get_first_node_in_group("black_tiles")
	white_tilemap = get_tree().get_first_node_in_group("white_tiles")

func _process(_delta: float) -> void:
	aim_at_mouse()
	
	if Input.is_action_just_pressed("shoot"):
		shoot()

func aim_at_mouse() -> void:
	look_at(get_global_mouse_position())

func shoot() -> void:
	if bullet_scene == null:
		return
	
	var muzzle = $Muzzle
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = muzzle.global_position
	
	var direction = (get_global_mouse_position() - muzzle.global_position).normalized()
	bullet.direction = direction
	bullet.player_color = get_parent().current_color
	bullet.black_tilemap = black_tilemap
	bullet.white_tilemap = white_tilemap
	bullet.collision_mask = 2 | 4
