extends Area2D

@export var speed: float = 600.0

var direction: Vector2 = Vector2.RIGHT
var player_color
var black_tilemap: TileMapLayer
var white_tilemap: TileMapLayer

func _ready() -> void:
	rotation = direction.angle()

	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 10.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.start()

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is TileMapLayer:
		if player_color == 1 and body == black_tilemap:
			paint_tiles(black_tilemap, white_tilemap, Vector2i(9, 11))
		elif player_color == 0 and body == white_tilemap:
			paint_tiles(white_tilemap, black_tilemap, Vector2i(22, 13))
	queue_free()

func paint_tiles(source: TileMapLayer, target: TileMapLayer, atlas_coords: Vector2i) -> void:
	var local_pos = source.to_local(global_position)
	var center = source.local_to_map(local_pos)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var tile_pos = center + Vector2i(dx, dy)
			if tile_pos in source.get_used_cells():
				source.erase_cell(tile_pos)
				target.set_cell(tile_pos, 0, atlas_coords)
	rebuild_physics(source)
	rebuild_physics(target)

func rebuild_physics(tilemap: TileMapLayer) -> void:
	var cells: Dictionary = {}
	for cell in tilemap.get_used_cells():
		cells[cell] = tilemap.get_cell_atlas_coords(cell)
	tilemap.clear()
	for cell in cells:
		tilemap.set_cell(cell, 0, cells[cell])
