extends Node2D
## 마우스 방향 조준 + 좌클릭 발사.

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet/Bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle
## ★[2026-08-23] Gun 은 이제 Player 의 **손자**다 (Player → GunRig → Gun).
##   GunRig 가 부모의 비균등 스케일을 되돌린다 — `총_받침.gd` 참고.
@onready var player: Node = _플레이어_찾기()

func _플레이어_찾기() -> Node:
	var n := get_parent()
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_parent()                       # 못 찾으면 예전처럼 부모를 쓴다

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _shoot() -> void:
	var bullet := BULLET_SCENE.instantiate()
	# 총알 색 = 발사 방향 쪽 **얼굴(입)**의 색. Gun 회전 중심이나 날아가는 Marker를
	# 쓰면 경계선 가까이에서 조준 각도만으로 색이 달라지므로, Player의 고정 입 기준을 쓴다.
	bullet.color = player.call("얼굴색", get_global_mouse_position().x - player.global_position.x) \
		if player.has_method("얼굴색") else player.get("player_color")
	bullet.direction = (get_global_mouse_position() - muzzle.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
