extends TileMapLayer

const BREAK_DELAY: float = 0.4

var _pending: Dictionary = {}  # Vector2i -> float (남은 시간)


func _physics_process(delta: float) -> void:
	if tile_set == null:
		return

	var space := get_world_2d().direct_space_state
	var tile_size := tile_set.tile_size

	var shape := RectangleShape2D.new()
	shape.size = Vector2(tile_size.x - 2.0, 2.0)

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 1  # layer 1 (플레이어)
	params.collide_with_bodies = true
	params.collide_with_areas = false

	for cell in get_used_cells():
		if _pending.has(cell):
			continue
		var tile_top := to_global(map_to_local(cell)) + Vector2(0, -tile_size.y / 2.0)
		params.transform = Transform2D(0, tile_top)
		if space.intersect_shape(params, 1).size() > 0:
			_pending[cell] = BREAK_DELAY

	var to_erase: Array[Vector2i] = []

	for cell in _pending.keys():
		_pending[cell] -= delta
		if _pending[cell] <= 0.0:
			to_erase.append(cell)

	for cell in to_erase:
		_pending.erase(cell)
		erase_cell(cell)
