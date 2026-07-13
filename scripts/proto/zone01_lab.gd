extends Node2D
## [2026-07-13 도형 · 신규] zone_01 테스트 맵 루트 — 프로토 시스템 조립 담당.
## 기존 씬/코드를 수정하지 않기 위해, 씬 파일이 아니라 "런타임"에 조립한다:
##  1. Player 안의 기존 Gun(gun.gd) 노드를 제거 (파일은 그대로, 이 맵에서만 비활성)
##  2. ProtoGun(입 위치)을 붙이고 PaintSystem·지형·UI 를 서로 연결
##  3. 캐릭터 스프라이트가 있으면 Placeholder 대신 표시하고 색 상태에 따라 틴트

const PROTO_GUN := preload("res://scripts/proto/proto_gun.gd")
## 입에서 페인트를 뱉는 컨셉 → 총구를 입 높이에 배치 (플레이어 로컬 좌표)
## (Kenney Player 캐릭터 80×110 기준: 입 ≈ 위에서 42% 지점)
const MOUTH_POS := Vector2(12, -74)
## 캐릭터 스프라이트 (없으면 기존 Placeholder 사각형 유지)
const CHARACTER_TEXTURE_PATH := "res://assets/characters/proto_player.png"

@onready var paint_system: PaintSystem = $PaintSystem
@onready var terrain: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $Player
@onready var gauge_ui: PaintGaugeUI = $UI/PaintGaugeUI

var _sprite: Sprite2D

func _ready() -> void:
	# 1) 기존 총 비활성화 (gun.gd 는 즉시 직선 발사 + 게이지 없음 → 이 맵에서는 프로토 총 사용)
	var old_gun := player.get_node_or_null("Gun")
	if old_gun:
		old_gun.queue_free()

	# 2) 프로토 총 부착 (입 위치)
	var gun: ProtoGun = PROTO_GUN.new()
	gun.name = "ProtoGun"
	gun.position = MOUTH_POS
	player.add_child(gun)
	gun.setup(paint_system, terrain, player)

	# 3) UI 연결
	gauge_ui.setup(paint_system, player)

	# 4) 캐릭터 스프라이트 (있을 때만)
	if ResourceLoader.exists(CHARACTER_TEXTURE_PATH):
		_sprite = Sprite2D.new()
		_sprite.texture = load(CHARACTER_TEXTURE_PATH)
		var tex_h := _sprite.texture.get_height()
		if tex_h > 0:
			var s := 128.0 / float(tex_h)   # 기존 Placeholder(64×128 로컬)와 같은 키로
			_sprite.scale = Vector2(s, s)
		_sprite.position = Vector2(0, -64)
		player.add_child(_sprite)
		var ph := player.get_node_or_null("Placeholder")
		if ph:
			ph.visible = false

func _process(_delta: float) -> void:
	# 스프라이트를 색 상태에 맞춰 틴트 + 조준 방향에 맞춰 좌우 반전
	if _sprite:
		var col: int = player.get("player_color")
		_sprite.modulate = Color(0.15, 0.15, 0.15) if col == ColorDefs.BLACK else Color(1, 1, 1)
		_sprite.flip_h = get_global_mouse_position().x < player.global_position.x
