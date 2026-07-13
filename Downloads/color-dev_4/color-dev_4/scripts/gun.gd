extends Node2D
## 마우스 방향 조준 + 좌클릭 발사.

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet/Bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var player: Node     = get_parent()   # Gun 은 Player 의 자식으로만 사용됨

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _shoot() -> void:
	var bullet := BULLET_SCENE.instantiate()
	# 총알 색 = 플레이어의 현재 색과 동일 (반대색 페인트 로직 폐기).
	# player.gd 에 class_name 이 없어 정적 타입 접근이 안 되므로 get() 으로 동적 조회.
	bullet.color     = player.get("player_color")
	bullet.direction = (get_global_mouse_position() - muzzle.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
