@tool
extends StaticBody2D
## 단색 지형 영역. BLACK / WHITE / GRAY 셋 중 하나.
## - StaticBody2D: 자기 색 레이어에 올라가 같은 색 플레이어만 충돌
## - 자식 DeathDetector(Area2D): "이 영역은 X색" 마커. 색 판정은 player.gd 가 담당.
## - 발판 색은 변하지 않음. 색 덮어쓰기는 PaintMark 가 담당.
##
## ── 색상 반전 기믹을 위한 확장 포인트 ──────────────────────────────────
##   is_white : 현재 발판이 흰색이면 true / 검정이면 false (런타임 상태).
##   flip_color()       : 총알에 맞았을 때 외부에서 호출 → BLACK ↔ WHITE 즉시 반전.
##   set_collision_to() : 특정 색으로 강제 지정 (퍼즐 트리거 등에서 사용).

# 레이어 비트 (project.godot 의 layer_names 와 일치)
const LAYER_BLACK: int      = 1 << 1  # layer 2
const LAYER_WHITE: int      = 1 << 2  # layer 3
const LAYER_GRAY: int       = 1 << 3  # layer 4
const LAYER_DEATH_ZONE: int = 1 << 6  # layer 7

# 인스펙터 드롭다운으로 색 선택
@export_enum("BLACK:0", "WHITE:1", "GRAY:2") var color_state: int = ColorDefs.BLACK:
	set(value):
		color_state = value
		# is_white 를 color_state 와 항상 동기화
		is_white = (value == ColorDefs.WHITE)
		_apply_color_state()

# ── 색상 반전 기믹용 상태 변수 ──────────────────────────────────────────
# true  = 현재 흰색 발판 / false = 현재 검정 발판
# GRAY 발판에서는 의미 없으므로 무시됨.
var is_white: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# color_state 로 is_white 초기값 동기화
	is_white = (color_state == ColorDefs.WHITE)
	# DeathDetector 를 그룹에 등록 (player ColorSensor 가 탐지)
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector and not detector.is_in_group("death_zones"):
		detector.add_to_group("death_zones")

func _apply_color_state() -> void:
	# StaticBody 본체: 자기 색 레이어에만 존재
	match color_state:
		ColorDefs.BLACK: collision_layer = LAYER_BLACK
		ColorDefs.WHITE: collision_layer = LAYER_WHITE
		ColorDefs.GRAY:  collision_layer = LAYER_GRAY
	collision_mask = 0

	# DeathDetector: 회색은 사망 판정 없으므로 monitorable 끄기
	var detector := get_node_or_null("DeathDetector") as Area2D
	if detector:
		detector.monitoring   = false
		detector.monitorable  = color_state != ColorDefs.GRAY
		detector.collision_layer = LAYER_DEATH_ZONE
		detector.collision_mask  = 0

	# 에디터 가시화용 (배포 전 숨겨도 됨)
	var preview := get_node_or_null("Preview") as Polygon2D
	if preview:
		match color_state:
			ColorDefs.BLACK: preview.color = Color(0.05, 0.05, 0.05)
			ColorDefs.WHITE: preview.color = Color(0.95, 0.95, 0.95)
			ColorDefs.GRAY:  preview.color = Color(0.5,  0.5,  0.5)

# ── 색상 반전 기믹 함수 ─────────────────────────────────────────────────
## BLACK ↔ WHITE 를 즉시 반전한다.
## 페인트 총알(Bullet.gd)이 발판에 맞았을 때 호출하면 됨.
## GRAY 발판은 반전 불가 — 아무 일도 일어나지 않음.
func flip_color() -> void:
	if color_state == ColorDefs.GRAY:
		return  # 회색은 반전 대상 아님
	# setter 가 is_white 동기화와 _apply_color_state() 를 처리
	color_state = ColorDefs.WHITE if color_state == ColorDefs.BLACK else ColorDefs.BLACK

## 색을 직접 지정한다 (퍼즐 트리거, 이벤트 등에서 외부 호출용).
## 예) platform.set_collision_to(ColorDefs.WHITE)
func set_collision_to(new_color: int) -> void:
	color_state = new_color  # setter 가 모든 동기화 처리
