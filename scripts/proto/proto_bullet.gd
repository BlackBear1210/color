extends Area2D
## [2026-07-17 도형 · v3] 프로토 총알: 포물선 비행(중력 적용), 지형(TileMapLayer) 명중 시
## PaintSystem.on_hit() 에 셀 좌표와 색을 전달한다. 기존 bullet.gd 무수정.
## v3 변경: 직선(_direction × speed) → 초속 벡터 + 중력. 초속·중력은 ProtoGun 이
## setup() 으로 넘겨주므로 조준 궤적(점선)과 실제 탄도가 항상 일치한다.
class_name ProtoBullet

@export var lifetime: float = 2.0

var _paint_system: PaintSystem
var _color: int = ColorDefs.BLACK
var _velocity: Vector2 = Vector2.RIGHT * 900.0
var _gravity: float = 1400.0

@onready var visual: Polygon2D = $Visual

func setup(ps: PaintSystem, color: int, velocity: Vector2, gravity: float) -> void:
	_paint_system = ps
	_color        = color
	_velocity     = velocity
	_gravity      = gravity

func _ready() -> void:
	visual.color = Color(0.05, 0.05, 0.05) if _color == ColorDefs.BLACK else Color(0.95, 0.95, 0.95)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_velocity.y += _gravity * delta
	position += _velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if body is TileMapLayer:
		var layer := body as TileMapLayer
		# 탄착점이 셀 경계에 걸칠 수 있어 진행 방향으로 살짝 안쪽 지점도 함께 검사
		var dir := _velocity.normalized()
		var cell := layer.local_to_map(layer.to_local(global_position))
		if layer.get_cell_source_id(cell) == -1:
			cell = layer.local_to_map(layer.to_local(global_position + dir * 10.0))
		_paint_system.on_hit(layer, cell, _color)
	queue_free()
