extends Area2D
## 직선으로 날아가는 총알. 벽에 닿거나 일정 시간이 지나면 사라짐.
## 원본 color 프로젝트의 "총알이 지형에 색을 묻히는" 로직을 이식.
## 구형 TileMap 에 닿아도 플레이어의 현재 색이 그대로 덮어쓰이게 한다.

@export var speed: float = 900.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var color: int = ColorDefs.BLACK   # gun.gd 가 add_child 전에 세팅 (플레이어 색과 동일)

# 흑·백 대체 타일을 분리해야 전에 칠한 색과 섞이지 않고 마지막 색으로 바뀐다.
const PAINT_ALT_BASE: int = 1000

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
		_paint_color(body as TileMapLayer)
	# 기존 TileMap 씬도 총구가 아닌 실제 지형 충돌점에서 물감 조각을 낸다.
	var 플레이어 := get_tree().get_first_node_in_group("player")
	var 행동효과 := 플레이어.get_node_or_null("ActionFX") if 플레이어 else null
	if 행동효과 and 행동효과.has_method("명중"):
		행동효과.명중(global_position, direction * speed, color)
	queue_free()

## 총알이 맞은 셀만 현재 플레이어 색으로 칠한다. 색별 대체 타일을 한 번 만든 뒤 재사용한다.
func _paint_color(layer: TileMapLayer) -> void:
	var cell: Vector2i = layer.local_to_map(layer.to_local(global_position))
	var source_id := layer.get_cell_source_id(cell)
	if source_id == -1:
		return   # 빈 셀 (안전장치)

	var atlas_coords := layer.get_cell_atlas_coords(cell)
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return

	var alternative_id := PAINT_ALT_BASE + color
	if not source.has_alternative_tile(atlas_coords, alternative_id):
		source.create_alternative_tile(atlas_coords, alternative_id)
	var paint_color := Color(0.05, 0.05, 0.05) if color == ColorDefs.BLACK else Color(0.95, 0.95, 0.95)
	source.get_tile_data(atlas_coords, alternative_id).modulate = paint_color

	layer.set_cell(cell, source_id, atlas_coords, alternative_id)
