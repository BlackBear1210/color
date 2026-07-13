extends Node2D
## 마우스 방향 조준 + 좌클릭 발사.

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet/Bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _shoot() -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.direction = (get_global_mouse_position() - muzzle.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
