extends Node2D

@onready var floor_black: TileMapLayer = $FloorLayer_black
@onready var floor_white: TileMapLayer = $FloorLayer_white

var _black_data: Dictionary = {}
var _white_data: Dictionary = {}

func _ready() -> void:
	add_to_group("stage")
	_store_tile_data(floor_black, _black_data)
	_store_tile_data(floor_white, _white_data)
	floor_white.clear()
	print("stage_base 실행됨, black 타일 수: ", _black_data.size(), " white 타일 수: ", _white_data.size())

func _store_tile_data(layer: TileMapLayer, data: Dictionary) -> void:
	for pos in layer.get_used_cells():
		data[pos] = [
			layer.get_cell_source_id(pos),
			layer.get_cell_atlas_coords(pos),
			layer.get_cell_alternative_tile(pos)
		]

func flip_tiles(world_pos: Vector2, radius: int = 1) -> void:
	print("flip_tiles 호출됨: ", world_pos)
	var center = floor_black.local_to_map(floor_black.to_local(world_pos))
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			_flip_one(center + Vector2i(dx, dy))
	floor_black.notify_runtime_tile_data_update()
	floor_white.notify_runtime_tile_data_update()

func _flip_one(pos: Vector2i) -> void:
	if floor_black.get_cell_source_id(pos) != -1:
		floor_black.erase_cell(pos)
		if _white_data.has(pos):
			var d = _white_data[pos]
			floor_white.set_cell(pos, d[0], d[1], d[2])
	elif floor_white.get_cell_source_id(pos) != -1:
		floor_white.erase_cell(pos)
		if _black_data.has(pos):
			var d = _black_data[pos]
			floor_black.set_cell(pos, d[0], d[1], d[2])

func _rebuild_physics(layer: TileMapLayer) -> void:
	var snapshot: Dictionary = {}
	for pos in layer.get_used_cells():
		snapshot[pos] = [
			layer.get_cell_source_id(pos),
			layer.get_cell_atlas_coords(pos),
			layer.get_cell_alternative_tile(pos)
		]
	layer.clear()
	for pos in snapshot:
		var d = snapshot[pos]
		layer.set_cell(pos, d[0], d[1], d[2])
