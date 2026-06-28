extends StaticBody2D
## 투명 블록
##
## ◆ 동작
##   • 기본: 반투명 외관 (뒷배경 비침), 플레이어/총알 모두 통과 가능
##   • 페인트가 칠해지는 순간: 충돌 활성화 (발판 or 벽으로 기능)
##       - 발판으로 배치: 페인트 후 플레이어가 위로 점프해 올라갈 수 있음
##       - 벽으로 배치:   페인트 전에는 통과, 페인트 후 이동 차단
##   • 리스폰 시: PaintMark 일괄 제거 → PaintSensor 가 area_exited 감지 → 자동 비활성화
##
## ◆ 사용법(에디터)
##   1) TransparentBlock.tscn 을 스테이지에 인스턴스
##   2) block_size 로 크기 조절 (기본 128×32 발판 / 수직 회전하면 벽)
##   3) Sprite2D 의 Texture 에 반투명 이미지 지정 (없으면 기본 ColorRect 표시)
##
## ◆ 인스펙터 설정 항목
##   • block_size : 블록 크기 (px)

@export var block_size: Vector2 = Vector2(128.0, 32.0):
	set(v):
		block_size = v
		_resize_shapes()

# ── 물리 레이어 ───────────────────────────────────────────────────────
## layer 256 = 플레이어가 색과 무관하게 항상 충돌
const LAYER_OBSTACLE: int = 1 << 8   # 256

var _is_painted: bool = false

@onready var _paint_sensor: Area2D = $PaintSensor


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 0
	_paint_sensor.area_entered.connect(_on_paint_entered)
	_paint_sensor.area_exited.connect(_on_paint_exited)
	_update_visual()


func _on_paint_entered(area: Area2D) -> void:
	if not _is_painted and area.is_in_group("paint_marks"):
		_activate()


func _on_paint_exited(_area: Area2D) -> void:
	# 겹친 paint_marks 가 하나도 없으면 비활성화 (리스폰 시 PaintMark 제거 연동)
	if _is_painted and not _has_paint():
		_deactivate()


func _has_paint() -> bool:
	for a in _paint_sensor.get_overlapping_areas():
		if a.is_in_group("paint_marks"):
			return true
	return false


# ── 활성화 / 비활성화 ─────────────────────────────────────────────────
func _activate() -> void:
	_is_painted     = true
	collision_layer = LAYER_OBSTACLE
	_update_visual()


func _deactivate() -> void:
	_is_painted     = false
	collision_layer = 0
	_update_visual()


# ── 비주얼 ───────────────────────────────────────────────────────────
func _update_visual() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate.a = 0.85 if _is_painted else 0.25
	var rect := get_node_or_null("ColorRect") as ColorRect
	if rect:
		rect.modulate.a = 0.85 if _is_painted else 0.25


# ── 크기 변경 헬퍼 ────────────────────────────────────────────────────
func _resize_shapes() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = block_size

	var sensor := get_node_or_null("PaintSensor/CollisionShape2D") as CollisionShape2D
	if sensor and sensor.shape is RectangleShape2D:
		(sensor.shape as RectangleShape2D).size = block_size + Vector2(16.0, 16.0)

	var rect := get_node_or_null("ColorRect") as ColorRect
	if rect:
		rect.offset_left   = -block_size.x * 0.5
		rect.offset_top    = -block_size.y * 0.5
		rect.offset_right  =  block_size.x * 0.5
		rect.offset_bottom =  block_size.y * 0.5
