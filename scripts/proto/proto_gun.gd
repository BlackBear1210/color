extends Node2D
## [2026-07-13 도형 · 신규] 프로토 총: 마우스 조준 + 좌클릭 발사 + E 회수.
## 기존 gun.gd 를 수정하지 않기 위해 zone_01 에서만 쓰는 별도 스크립트.
## (zone_01 루트가 기존 Gun 노드를 런타임에 제거하고 이 총을 붙인다)
## E 키는 project.godot 을 건드리지 않으려고 액션 등록 없이 물리 키를 직접 읽는다.
class_name ProtoGun

const BULLET_SCENE: PackedScene = preload("res://scenes/proto/ProtoBullet.tscn")

var paint_system: PaintSystem
var terrain: TileMapLayer
var player: Node          # player.gd (player_color 를 읽기만 함)

@onready var muzzle: Marker2D = Marker2D.new()

func setup(ps: PaintSystem, layer: TileMapLayer, p: Node) -> void:
	paint_system = ps
	terrain      = layer
	player       = p

func _ready() -> void:
	muzzle.position = Vector2(26, 0)
	add_child(muzzle)

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"):
		_try_shoot()

func _unhandled_key_input(event: InputEvent) -> void:
	# E = 회수 (액션 미등록: project.godot 무수정 원칙)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E:
		paint_system.recover(terrain)

func _try_shoot() -> void:
	var color: int = player.get("player_color")
	if not paint_system.consume(color):
		return                            # 잔량 0 → fire_denied 시그널이 UI에 전달됨
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(paint_system, color,
		(get_global_mouse_position() - muzzle.global_position).normalized())
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
