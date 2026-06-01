@tool
extends StaticBody2D
## 이미지(PNG) 한 장으로 만드는 "색상 지형".
## 곡선·구멍이 있는 불규칙 지형도 스프라이트의 알파 모양 그대로 충돌이 자동 생성된다.
##
## 동작은 기존 platform.gd 와 동일하다 (player.gd 가 color_state 를 읽어 사망 판정):
##   - 같은 색 플레이어 → 밟힘(안전)
##   - 반대 색 플레이어 → 통과 후 ColorSensor 가 사망 판정
##   - GRAY → 미끄러짐(올라설 수 없음), 사망 판정 없음
##
## ◆ 사용법(에디터)
##   1) 이 씬(TerrainImage)을 스테이지에 인스턴스
##   2) 자식 Sprite2D 에 지형 PNG 드래그 (예: Platform_Black_01.png)
##   3) 인스펙터에서 Color State(검정/흰색/회색) 선택
##   4) 인스펙터의 "Bake Collision" 체크 → 그림 모양대로 충돌 폴리곤 자동 생성
##   (PNG·크기·위치를 바꾸면 다시 Bake 만 누르면 됨. 런타임 비용 0)

# 레이어 비트 (project.godot 의 layer_names 와 일치)
const LAYER_BLACK: int      = 1 << 1  # layer 2
const LAYER_WHITE: int      = 1 << 2  # layer 3
const LAYER_GRAY: int       = 1 << 3  # layer 4
const LAYER_DEATH_ZONE: int = 1 << 6  # layer 7

# ※ 프로퍼티명 "color_state" 는 player.gd 가 get("color_state") 로 읽으므로 절대 바꾸지 말 것
@export_enum("BLACK:0", "WHITE:1", "GRAY:2") var color_state: int = ColorDefs.BLACK:
	set(value):
		color_state = value
		_apply_color_state()

# 알파가 이 값보다 크면 "지형"으로 간주 (0~1)
@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5
# 폴리곤 단순화 정도(px). 클수록 정점↓(가벼움), 작을수록 외곽이 정밀
@export_range(0.5, 20.0, 0.5) var simplify: float = 3.0

# 인스펙터에서 체크하면 충돌을 다시 굽는다(에디터 전용)
@export var bake_collision: bool = false:
	set(value):
		bake_collision = false   # 토글처럼 즉시 false 복귀 (버튼 역할)
		if Engine.is_editor_hint():
			_bake()

func _ready() -> void:
	_apply_color_state()
	if Engine.is_editor_hint():
		return
	# 런타임: DeathDetector 를 death_zones 그룹에 등록 (player ColorSensor 가 탐지)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector and not detector.is_in_group("death_zones"):
		detector.add_to_group("death_zones")

func _apply_color_state() -> void:
	# 본체: 자기 색 레이어에만 존재 → 같은 색 플레이어만 물리 충돌
	match color_state:
		ColorDefs.BLACK: collision_layer = LAYER_BLACK
		ColorDefs.WHITE: collision_layer = LAYER_WHITE
		ColorDefs.GRAY:  collision_layer = LAYER_GRAY
	collision_mask = 0

	# DeathDetector: 회색은 사망 판정 없음 → monitorable 끄기
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		detector.monitoring      = false
		detector.monitorable     = color_state != ColorDefs.GRAY
		detector.collision_layer = LAYER_DEATH_ZONE
		detector.collision_mask  = 0

# ── 충돌 자동 생성 ────────────────────────────────────────────────
func _bake() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var root := get_tree().edited_scene_root
	# 1) 본체(물리 충돌) — 같은 색 플레이어가 밟는 영역
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, root)
	# 2) DeathDetector(색 판정) — 같은 모양으로 한 번 더
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		AutoCollision.bake_into(detector, spr, alpha_threshold, simplify, root)
	if n == 0:
		push_warning("TerrainImage '%s': 충돌 생성 실패 — Sprite2D 텍스처/알파를 확인하세요." % name)
	else:
		print("TerrainImage '%s': 폴리곤 %d개 생성 완료." % [name, n])
