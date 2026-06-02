extends Node2D

# ── 인스펙터 ───────────────────────────────────────────────────────
@export_enum("BLACK:0", "WHITE:1")
var start_color: int       = ColorDefs.BLACK

@export var hold_time: float       = 2.0    # 한 색이 유지되는 시간(초)
@export var transition_time: float = 0.5    # 색 전환에 걸리는 시간(초)
@export var light_radius: float    = 200.0  # 부채꼴 반지름(px)
@export var light_angle: float     = 90.0   # 부채꼴 각도(도)

# ── player.gd 가 읽는 값 ───────────────────────────────────────────
# _check_color_death() 의 plat.get("color_state") 로 접근됨
var color_state: int = ColorDefs.BLACK

# ── 내부 ──────────────────────────────────────────────────────────
var _is_transitioning: bool = false
var _timer: float = 0.0

@onready var _area:    Area2D             = $DetectionArea
@onready var _polygon: CollisionPolygon2D = $DetectionArea/CollisionPolygon2D
@onready var _visual:  Sprite2D           = $LightVisual


func _ready() -> void:
	color_state = start_color
	_timer      = hold_time
	_area.add_to_group("death_zones")
	_build_fan_polygon()
	_update_visual()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if _is_transitioning:
			_end_transition()
		else:
			_start_transition()


# 전환 시작: death_zones 에서 제거 → 플레이어 안전
func _start_transition() -> void:
	_is_transitioning = true
	_timer = transition_time
	_area.remove_from_group("death_zones")
	# TODO: 시각 전환 연출 (트윈, 깜빡임 등)


# 전환 완료: 색 교체 후 death_zones 복구
func _end_transition() -> void:
	_is_transitioning = false
	color_state = ColorDefs.WHITE if color_state == ColorDefs.BLACK \
			else ColorDefs.BLACK
	_timer = hold_time
	_area.add_to_group("death_zones")
	_update_visual()


# 부채꼴 충돌체 자동 생성
# 노드 회전값으로 방향 조절 가능 (에디터에서 LightObstacle 회전)
func _build_fan_polygon() -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)  # 부채꼴 꼭짓점(중심)

	var half_rad := deg_to_rad(light_angle * 0.5)
	var steps    := 16  # 높을수록 곡선이 부드러움

	for i in steps + 1:
		var angle := -half_rad + (half_rad * 2.0 / steps) * i
		points.append(Vector2(cos(angle), sin(angle)) * light_radius)

	_polygon.polygon = points


# 비주얼 색상 업데이트
func _update_visual() -> void:
	if _visual:
		_visual.modulate = Color.BLACK if color_state == ColorDefs.BLACK \
				else Color.WHITE
