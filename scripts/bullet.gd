extends Area2D
## 직선으로 날아가는 총알. 벽에 닿거나 일정 시간이 지나면 사라짐.
## 원본 color 프로젝트의 "총알이 지형에 색을 묻히는" 로직을 이식.
## 단, 검정→흰색 / 흰색→검정으로 뒤집던 기존 방식 대신, 맞은 타일을 항상 회색으로 칠한다.

@export var speed: float = 900.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var color: int = ColorDefs.BLACK   # gun.gd 가 add_child 전에 세팅 (플레이어 색과 동일)

# 지형에 페인트가 묻었을 때 쓸 회색 및, TileSet 에 새로 만들 "칠해진" 대체 타일 ID
const PAINT_GRAY_COLOR: Color = Color(0.5, 0.5, 0.5)
const PAINT_ALT_ID: int = 1000

@onready var placeholder: Polygon2D = $Placeholder

func _ready() -> void:
	placeholder.color = Color(0.05, 0.05, 0.05) if color == ColorDefs.BLACK else Color(0.95, 0.95, 0.95)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if body is TileMapLayer:
		_paint_gray(body as TileMapLayer)
	# 기존 TileMap 씬도 총구가 아닌 실제 지형 충돌점에서 물감 조각을 낸다.
	var 플레이어 := get_tree().get_first_node_in_group("player")
	var 행동효과 := 플레이어.get_node_or_null("ActionFX") if 플레이어 else null
	if 행동효과 and 행동효과.has_method("명중"):
		행동효과.명중(global_position, direction * speed, color)
	queue_free()

## 총알이 맞은 셀만 회색으로 칠한다. 같은 (source, atlas 좌표)에 대해 회색 대체 타일을
## 처음 한 번만 만들어두고(모듈레이트 적용), 이후에는 그 대체 타일로 셀을 바꿔치기만 한다.
func _paint_gray(layer: TileMapLayer) -> void:
	var cell: Vector2i = layer.local_to_map(layer.to_local(global_position))
	var source_id := layer.get_cell_source_id(cell)
	if source_id == -1:
		return   # 빈 셀 (안전장치)

	var atlas_coords := layer.get_cell_atlas_coords(cell)
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return

	if not source.has_alternative_tile(atlas_coords, PAINT_ALT_ID):
		source.create_alternative_tile(atlas_coords, PAINT_ALT_ID)
		source.get_tile_data(atlas_coords, PAINT_ALT_ID).modulate = PAINT_GRAY_COLOR

	layer.set_cell(cell, source_id, atlas_coords, PAINT_ALT_ID)
