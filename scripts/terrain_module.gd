@tool
extends StaticBody2D
class_name TerrainModule
## ════════════════════════════════════════════════════════════════════════
##  지형 모듈 (Terrain Module) — "맵폴리 베타" 키트의 기본 단위
##  작성일: 2026-06-17
## ════════════════════════════════════════════════════════════════════════
## 왜 이 스크립트가 필요한가 (설계 배경):
##   기존 방식(terrain_image.gd + opaque_to_polygons)은 PNG 알파를 자동으로
##   충돌로 변환했는데, 동굴처럼 "구멍 뚫린 도넛" 모양에서 충돌이 구멍을
##   메워버리고(=stage_2 버그), 외곽이 울퉁불퉁해 발이 걸리는 문제가 있었다.
##
##   이 모듈은 "맵 레벨디자인 시스템.md" 의 2대 원칙을 코드로 구현한다:
##     원칙 A) 비주얼과 충돌을 분리한다.
##              - Visual(Polygon2D 또는 Sprite2D): 보기용. 마음껏 예뻐도 됨.
##              - Collision(CollisionPolygon2D): "밟는 면". 일부러 단순·매끈.
##     원칙 B) 10종 모듈을 크기·반전·색만 바꿔 조립한다.
##              - shape(깨끗한 폴리곤 1개)를 한 번 정해두면 충돌도 1개로 끝.
##                → 이음새(seam)가 없어 발 걸림이 구조적으로 사라진다.
##
## ◆ 사용법(에디터)
##   1) 이 모듈 씬(예: Module_GroundFlat.tscn)을 스테이지/조립씬에 인스턴스
##   2) Color State 선택(검정/흰색/회색)
##   3) (선택) Terrain Texture 에 아트 PNG 를 넣으면 Polygon2D 대신 그 그림이 보임
##      ※ 충돌은 항상 shape 폴리곤을 따른다. 그림이 울퉁불퉁해도 발은 매끈하게.
##   4) scale.x / scale.y 로 크기 조절, scale.x = -1 로 좌우 반전
##
## ◆ SnapPoints(Entry/Exit): 모듈을 이어 붙일 때 바닥 높이를 맞추는 기준점.
##   다음 모듈의 Entry 를 이전 모듈의 Exit 에 맞추면 바닥이 끊기지 않는다.

# ── 충돌 레이어 비트 (project.godot / platform.gd 와 동일하게 유지) ──────
const LAYER_BLACK: int      = 1 << 1
const LAYER_WHITE: int      = 1 << 2
const LAYER_GRAY: int       = 1 << 3
const LAYER_DEATH_ZONE: int = 1 << 6

# ── 충돌 빌드 모드 (auto_collision.gd 와 의미 동일) ──────────────────────
const BUILD_SOLIDS: int   = CollisionPolygon2D.BUILD_SOLIDS    # 속 채움(평지·언덕)
const BUILD_SEGMENTS: int = CollisionPolygon2D.BUILD_SEGMENTS  # 외곽선만(동굴·도넛)

## ※ 프로퍼티명 "color_state" 는 player.gd 가 get("color_state") 로 읽으므로
##   절대 이름을 바꾸지 말 것 (platform.gd 와 동일 규칙).
@export_enum("BLACK:0", "WHITE:1", "GRAY:2") var color_state: int = ColorDefs.BLACK:
	set(value):
		color_state = value
		is_white = (value == ColorDefs.WHITE)
		_apply_color_state()
		_refresh_visual_color()

## 모듈의 "깨끗한 단일 폴리곤". 비주얼과 충돌이 이 하나를 공유한다.
## 구멍(도넛) 없이 시계/반시계 한 방향으로 닫힌 단순 폴리곤이어야 한다.
@export var shape: PackedVector2Array = PackedVector2Array():
	set(value):
		shape = value
		_rebuild()

## (선택) 아트 텍스처. 지정하면 Polygon2D 대신 이 그림을 비주얼로 사용.
## 충돌은 그래도 shape 를 따르므로, 그림은 울퉁불퉁해도 발은 매끈하다(원칙 A).
@export var terrain_texture: Texture2D:
	set(value):
		terrain_texture = value
		_rebuild()

## 동굴형 모듈이면 SEGMENTS(외곽선만) 로. 평지·언덕은 SOLIDS(기본).
@export_enum("SOLIDS:0", "SEGMENTS:1") var collision_build_mode: int = 0:
	set(value):
		collision_build_mode = value
		_rebuild()

## true  = 흰 발판 / false = 검정 발판 (color_state 와 동기화). 반전 기믹용.
var is_white: bool = false


func _ready() -> void:
	_rebuild()
	_apply_color_state()
	_refresh_visual_color()
	if Engine.is_editor_hint():
		return
	is_white = (color_state == ColorDefs.WHITE)
	# DeathDetector 를 death_zones 그룹에 등록 (player ColorSensor 가 탐지)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector and not detector.is_in_group("death_zones"):
		detector.add_to_group("death_zones")


# ── 비주얼 + 충돌을 shape 로부터 재생성 ─────────────────────────────────
## 한 함수에서 Visual / Collision / DeathDetector 를 모두 shape 에 맞춰 갱신.
## 노드가 없으면 만들고, 있으면 폴리곤만 교체한다(중복 노드 방지).
func _rebuild() -> void:
	if not is_inside_tree():
		# 씬 로드 중에는 트리 준비 후 다시 호출
		call_deferred("_rebuild")
		return
	if shape.size() < 3:
		return

	# 1) 비주얼: 텍스처가 있으면 Sprite2D, 없으면 Polygon2D(단색 채움)
	var spr := get_node_or_null("VisualSprite") as Sprite2D
	var poly := get_node_or_null("Visual") as Polygon2D
	if terrain_texture:
		if poly: poly.visible = false
		if spr == null:
			spr = Sprite2D.new()
			spr.name = "VisualSprite"
			spr.centered = false
			add_child(spr)
			spr.owner = _owner_for_save()
		spr.visible = true
		spr.texture = terrain_texture
	else:
		if spr: spr.visible = false
		if poly == null:
			poly = Polygon2D.new()
			poly.name = "Visual"
			add_child(poly)
			poly.owner = _owner_for_save()
		poly.visible = true
		poly.polygon = shape

	# 2) 충돌: shape 그대로, build_mode 적용
	var col := get_node_or_null("Collision") as CollisionPolygon2D
	if col == null:
		col = CollisionPolygon2D.new()
		col.name = "Collision"
		add_child(col)
		col.owner = _owner_for_save()
	col.polygon = shape
	col.build_mode = collision_build_mode

	_refresh_visual_color()


## 에디터에서 만든 자식이 .tscn 에 저장되도록 owner 를 정한다.
func _owner_for_save() -> Node:
	if Engine.is_editor_hint():
		return get_tree().edited_scene_root
	return null


# ── 색상 적용 (platform.gd 와 동일 규칙) ────────────────────────────────
func _apply_color_state() -> void:
	match color_state:
		ColorDefs.BLACK: collision_layer = LAYER_BLACK
		ColorDefs.WHITE: collision_layer = LAYER_WHITE
		ColorDefs.GRAY:  collision_layer = LAYER_GRAY
	collision_mask = 0
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		detector.monitoring      = false
		# 회색 지형은 사망 판정 없음 → monitorable off
		detector.monitorable     = color_state != ColorDefs.GRAY
		detector.collision_layer = LAYER_DEATH_ZONE
		detector.collision_mask  = 0


## Polygon2D 비주얼 색을 color_state 에 맞춰 칠한다 (텍스처 없을 때 미리보기용).
func _refresh_visual_color() -> void:
	var poly := get_node_or_null("Visual") as Polygon2D
	if poly == null:
		return
	match color_state:
		ColorDefs.BLACK: poly.color = Color(0.07, 0.07, 0.07)
		ColorDefs.WHITE: poly.color = Color(0.93, 0.93, 0.93)
		ColorDefs.GRAY:  poly.color = Color(0.5, 0.5, 0.5)


# ── 색상 반전 기믹 (platform.gd 와 동일 인터페이스) ─────────────────────
## 페인트 총알 등이 호출 → BLACK ↔ WHITE 즉시 반전. GRAY 는 무시.
func flip_color() -> void:
	if color_state == ColorDefs.GRAY:
		return
	color_state = ColorDefs.WHITE if color_state == ColorDefs.BLACK else ColorDefs.BLACK


func set_collision_to(new_color: int) -> void:
	color_state = new_color
