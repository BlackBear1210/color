@tool
extends StaticBody2D
## 이미지(PNG) 한 장으로 만드는 "색상 지형".
## 곡선·구멍이 있는 불규칙 지형도 스프라이트의 알파 모양 그대로 충돌이 자동 생성된다.
##
## ◆ 사용법(에디터)
##   1) 이 씬(TerrainImage)을 스테이지에 인스턴스
##   2) 인스펙터의 Terrain Texture 에 지형 PNG 드래그
##   3) Color State(검정/흰색/회색) 선택
##   4) "Bake Collision" 체크 → 그림 모양대로 충돌 폴리곤 자동 생성
##   ※ Bake 없이 실행해도 런타임에 자동으로 충돌이 생성된다

const LAYER_BLACK: int      = 1 << 1
const LAYER_WHITE: int      = 1 << 2
const LAYER_GRAY: int       = 1 << 3
const LAYER_DEATH_ZONE: int = 1 << 6

# ※ 프로퍼티명 "color_state" 는 player.gd 가 get("color_state") 로 읽으므로 절대 바꾸지 말 것
@export_enum("BLACK:0", "WHITE:1", "GRAY:2") var color_state: int = ColorDefs.BLACK:
	set(value):
		color_state = value
		_apply_color_state()

# 알파가 이 값보다 크면 "지형"으로 간주 (0~1)
@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5
# 폴리곤 단순화 정도(px). 클수록 정점↓(가벼움), 작을수록 외곽이 정밀
@export_range(0.5, 20.0, 0.5) var simplify: float = 3.0

## ▼ 2026-06-17 추가: 충돌 빌드 모드.
##   SOLIDS(0)  = 속을 채움. 평지·언덕 등 "구멍 없는" 지형 기본값.
##   SEGMENTS(1) = 외곽선만. 동굴·도넛처럼 "안쪽 빈 공간"이 있는 지형 전용.
##   왜 필요?: 동굴 PNG 를 SOLIDS 로 구우면 opaque_to_polygons 의 키홀(자기교차)
##            폴리곤이 구멍을 메워버려 플레이어가 지나갈 동굴 속이 충돌로 막힌다.
##            (stage_2 BlackCave 먹통 버그의 원인) → 동굴은 이 값을 SEGMENTS 로.
@export_enum("SOLIDS:0", "SEGMENTS:1") var collision_build_mode: int = 0

## 스테이지 tscn 에서 직접 지정하는 지형 텍스처.
## 값을 설정하면 Sprite2D 에 자동 적용, 에디터에서는 충돌도 자동 재굽는다.
@export var terrain_texture: Texture2D:
	set(value):
		terrain_texture = value
		if is_inside_tree():
			_apply_texture()
			if Engine.is_editor_hint() and value != null:
				_bake()
		else:
			# 씬 로드 중 노드가 트리에 없을 때는 준비된 후 적용
			call_deferred("_apply_texture")

# 인스펙터에서 체크하면 충돌을 다시 굽는다(에디터 전용)
@export var bake_collision: bool = false:
	set(value):
		bake_collision = false
		if Engine.is_editor_hint():
			_bake()

func _ready() -> void:
	_apply_color_state()
	# terrain_texture 를 항상 Sprite2D 에 적용 (sub-scene 기본값 덮어쓰기)
	_apply_texture()
	if Engine.is_editor_hint():
		return
	# DeathDetector 그룹 등록 (player ColorSensor 가 탐지)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector and not detector.is_in_group("death_zones"):
		detector.add_to_group("death_zones")
	# 충돌 폴리곤이 없으면 런타임에 자동 생성
	_bake_if_missing()

## 런타임에 auto_baked 충돌이 하나도 없을 때만 생성 (에디터 Bake 우선)
func _bake_if_missing() -> void:
	for c in get_children():
		if c is CollisionPolygon2D and c.has_meta("auto_baked"):
			return
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		push_warning("TerrainImage '%s': terrain_texture 가 설정되지 않았습니다." % name)
		return
	# ▼ 2026-06-17: collision_build_mode 를 함께 전달 (동굴형은 SEGMENTS 로 구멍 보존)
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, null, collision_build_mode)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		# 사망 판정 영역은 "겹침 감지"만 하므로 항상 SOLIDS 가 맞다 (모드 고정)
		AutoCollision.bake_into(detector, spr, alpha_threshold, simplify, null)
	if n == 0:
		push_warning("TerrainImage '%s': 런타임 충돌 생성 실패 — 텍스처 import가 Lossless인지 확인하세요." % name)

func _apply_color_state() -> void:
	match color_state:
		ColorDefs.BLACK: collision_layer = LAYER_BLACK
		ColorDefs.WHITE: collision_layer = LAYER_WHITE
		ColorDefs.GRAY:  collision_layer = LAYER_GRAY
	collision_mask = 0
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		detector.monitoring      = false
		detector.monitorable     = color_state != ColorDefs.GRAY
		detector.collision_layer = LAYER_DEATH_ZONE
		detector.collision_mask  = 0

func _apply_texture() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr and terrain_texture:
		spr.texture = terrain_texture

# ── 충돌 자동 생성 (에디터) ────────────────────────────────────────
func _bake() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var root := get_tree().edited_scene_root
	# ▼ 2026-06-17: collision_build_mode 전달 (동굴형 지형 충돌 메움 버그 해결)
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, root, collision_build_mode)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		AutoCollision.bake_into(detector, spr, alpha_threshold, simplify, root)
	if n == 0:
		push_warning("TerrainImage '%s': 충돌 생성 실패 — Sprite2D 텍스처/알파를 확인하세요." % name)
	else:
		print("TerrainImage '%s': 폴리곤 %d개 생성 완료." % [name, n])
