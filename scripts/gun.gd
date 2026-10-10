extends Node2D
## 마우스 방향 조준 + 좌클릭 발사.

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet/Bullet.tscn")
const 효과음 := preload("res://scripts/페인트_효과음.gd")

# 탄약 없는 구 테스트 씬도 실제 총알 생성 이후에만 새 모션을 재생한다.
signal fired

func _ready() -> void:
	# 자식 준비 시점에는 부모의 player 그룹이 아직 없어 부모 준비 뒤에 연결한다.
	call_deferred("_연결_모션")

func _연결_모션() -> void:
	# 스마트월드·프로토 총이 대신 발사하는 씬에서는 그 총의 탄약 연결을 덮지 않는다.
	if not is_processing() or is_queued_for_deletion():
		return
	player = _플레이어_찾기()
	var 캐릭터 := player.get_node_or_null("CharacterSprite")
	if 캐릭터 != null and 캐릭터.has_method("연결_총"):
		캐릭터.call("연결_총", self)

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
	# 테스트 씬도 새 그림의 총구를 사용하고, 총알의 색은 기존 얼굴 판정을 유지한다.
	var 시작 := muzzle.global_position
	var 캐릭터 := player.get_node_or_null("CharacterSprite")
	if 캐릭터 != null and 캐릭터.has_method("총구_월드좌표"):
		시작 = 캐릭터.call("총구_월드좌표")
	# 총알 색 = 발사 방향 쪽 **얼굴(입)**의 색. Gun 회전 중심이나 날아가는 Marker를
	# 쓰면 경계선 가까이에서 조준 각도만으로 색이 달라지므로, Player의 고정 입 기준을 쓴다.
	bullet.color = player.call("얼굴색", get_global_mouse_position().x - player.global_position.x) \
		if player.has_method("얼굴색") else player.get("player_color")
	bullet.direction = (get_global_mouse_position() - 시작).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = 시작
	fired.emit()
	# 옛 테스트 씬도 총알 생성이 끝난 실제 발사에만 같은 효과음을 쓴다.
	효과음.재생(self, "플레이어_페인트발사", 시작, -10.0)
