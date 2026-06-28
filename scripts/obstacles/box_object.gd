extends RigidBody2D
## 박스 오브젝트
##
## ◆ 동작
##   • 기본 상태: 총알에는 맞지만(collision_layer 128) 플레이어는 통과 + 정지
##   • 페인트가 칠해지면: 충돌 활성화(layer 256), 물리 풀림 → 플레이어가 밀 수 있음
##   • 리스폰 시: player.gd 가 "paint_activated" 그룹에 reset_paint_state() 호출 → 초기 위치/상태 복귀
##
## ◆ 사용법(에디터)
##   1) BoxObject.tscn 을 스테이지에 인스턴스
##   2) 인스펙터의 box_size 로 크기 조절 (기본 64×64)
##   3) Sprite2D 의 Texture 에 원하는 박스 이미지 지정

@export var box_size: Vector2 = Vector2(64.0, 64.0):
	set(v):
		box_size = v
		_resize_shapes()

# ── 물리 레이어 ───────────────────────────────────────────────────────
## layer 128 = 총알 마스크(398)에 포함 / 플레이어 마스크(266·268)에 미포함
## → 페인트 전에는 총알이 맞고 PaintMark 를 생성하지만, 플레이어는 그냥 통과
const LAYER_PAINTABLE: int = 1 << 7   # 128
## layer 256 = 플레이어가 색과 무관하게 항상 충돌하는 장애물 레이어
const LAYER_OBSTACLE:  int = 1 << 8   # 256
## 지형 레이어(검정2 + 흰색4 + 회색8)
const MASK_TERRAIN:    int = 14

var _is_painted: bool = false
var _spawn_pos:  Vector2

@onready var _paint_sensor: Area2D = $PaintSensor


func _ready() -> void:
	add_to_group("paint_activated")   # 리스폰 시 player.gd 가 reset_paint_state() 호출
	_spawn_pos      = global_position
	collision_layer = LAYER_PAINTABLE
	collision_mask  = 0
	freeze          = true
	lock_rotation   = true

	_paint_sensor.area_entered.connect(_on_paint_entered)
	_update_visual()


func _on_paint_entered(area: Area2D) -> void:
	if not _is_painted and area.is_in_group("paint_marks"):
		_activate()


# ── 활성화 ────────────────────────────────────────────────────────────
func _activate() -> void:
	_is_painted     = true
	collision_layer = LAYER_OBSTACLE
	collision_mask  = MASK_TERRAIN
	freeze          = false
	_update_visual()


# ── 리스폰 리셋 (player.gd 가 호출) ──────────────────────────────────
func reset_paint_state() -> void:
	_is_painted      = false
	collision_layer  = LAYER_PAINTABLE
	collision_mask   = 0
	freeze           = true
	linear_velocity  = Vector2.ZERO
	angular_velocity = 0.0
	global_position  = _spawn_pos
	_update_visual()


# ── 비주얼 ───────────────────────────────────────────────────────────
func _update_visual() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate.a = 1.0 if _is_painted else 0.45
	var rect := get_node_or_null("ColorRect") as ColorRect
	if rect:
		rect.modulate.a = 1.0 if _is_painted else 0.45


# ── 크기 변경 헬퍼 ────────────────────────────────────────────────────
func _resize_shapes() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = box_size

	var sensor := get_node_or_null("PaintSensor/CollisionShape2D") as CollisionShape2D
	if sensor and sensor.shape is RectangleShape2D:
		(sensor.shape as RectangleShape2D).size = box_size + Vector2(16.0, 16.0)

	var rect := get_node_or_null("ColorRect") as ColorRect
	if rect:
		rect.offset_left   = -box_size.x * 0.5
		rect.offset_top    = -box_size.y * 0.5
		rect.offset_right  =  box_size.x * 0.5
		rect.offset_bottom =  box_size.y * 0.5
