extends Node2D
## 색 레이저 빔 장애물 (LaserBeam)
## 항상 켜져 있는 지속형 빔. 플레이어 색이 빔과 같으면 그대로 통과하고,
## 반대 색이면 닿는 즉시 사망한다.
##
## ▼ 구현 방식 (중요)
##   색 판정은 따로 만들지 않고, platform.gd/terrain_image.gd 가 쓰는 기존
##   'DeathDetector' 패턴을 그대로 재사용한다. player.gd 의 _check_color_death() 가
##   ColorSensor 와 겹친 "death_zones" 그룹 Area2D 의 부모 노드에서 color_state 를
##   직접 읽어 판정하므로(player.gd:462 부근), 이 스크립트는 그 조건만 충족시키면
##   같은 색 통과 / 반대 색 즉사가 자동으로 작동한다.
##   → 이 스크립트는 비주얼(빔 모양·길이·두께·깜빡임)만 담당한다.
##
##   물리적으로 막는 충돌체는 없다 — 같은 색일 때 '그대로' 지나가야 하므로
##   발판(StaticBody2D)처럼 만들지 않는다.

const LAYER_DEATH_ZONE: int = 1 << 6

# player.gd 가 get("color_state") 로 직접 읽는다 → 이름 절대 불변.
@export_enum("BLACK:0", "WHITE:1") var color_state: int = ColorDefs.BLACK:
	set(value):
		color_state = value
		_apply_color()

# 빔의 길이/두께(px). 레벨에 맞춰 인스펙터에서 조절.
@export var beam_length: float = 400.0:
	set(value):
		beam_length = value
		_update_shape()
@export var beam_width: float = 12.0:
	set(value):
		beam_width = value
		_update_shape()

@onready var _visual: Polygon2D = $Visual
@onready var _detector: Area2D = $DeathDetector
@onready var _shape: CollisionShape2D = $DeathDetector/CollisionShape2D


func _ready() -> void:
	add_to_group("obstacle")  # 총알 PaintMark 차단 (레이저는 페인트 대상이 아님)

	_detector.add_to_group("death_zones")
	_detector.monitoring      = false   # 겹침은 player.gd 의 ColorSensor 쪽에서 감지
	_detector.monitorable     = true    # 항상 위험(회색 같은 예외 없음)
	_detector.collision_layer = LAYER_DEATH_ZONE
	_detector.collision_mask  = 0

	_apply_color()
	_update_shape()
	_play_pulse()


## 빔 색에 맞춰 비주얼 색만 바꾼다(판정에는 영향 없음 — color_state 가 판정을 맡음).
func _apply_color() -> void:
	if _visual == null:
		return
	_visual.color = Color(0.05, 0.05, 0.05, 0.95) if color_state == ColorDefs.BLACK \
					else Color(0.95, 0.95, 0.95, 0.95)


## beam_length/beam_width 변경을 비주얼 폴리곤 + 충돌 모양에 동시 반영.
## 빔은 이 노드의 원점에서 +Y(로컬 아래) 방향으로 뻗어나간다(회전시켜 방향 조절).
func _update_shape() -> void:
	if _visual:
		var hw := beam_width * 0.5
		_visual.polygon = PackedVector2Array([
			Vector2(-hw, 0.0), Vector2(hw, 0.0),
			Vector2(hw, beam_length), Vector2(-hw, beam_length),
		])
	if _shape and _shape.shape is RectangleShape2D:
		var rect := _shape.shape as RectangleShape2D
		rect.size = Vector2(beam_width, beam_length)
		_shape.position = Vector2(0.0, beam_length * 0.5)


## 살짝 깜빡이는 펄스 애니메이션 (켜져 있다는 느낌 강조용, 판정과 무관).
func _play_pulse() -> void:
	if _visual == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_visual, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
