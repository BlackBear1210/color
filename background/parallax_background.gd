extends ParallaxBackground

@export var target: Node2D
@export var spawn_range: int = 3

const IMAGE_CENTER_Y: float = 200.0
const IMAGE_SCALE: Vector2 = Vector2(0.7169271, 0.73333335)
const SCROLL_SCALE_X: float = 0.8

var _parallax: Parallax2D
var _texture: Texture2D
var _chunks: Dictionary = {}
var _image_width: float = 1377.0  # _ready()에서 실제 텍스처 크기로 재계산


func _ready() -> void:
	_parallax = $Parallax2D
	_texture = $Parallax2D/Sprite2D.texture
	_image_width = _texture.get_width() * IMAGE_SCALE.x  # 실제 너비로 계산
	_parallax.repeat_size = Vector2.ZERO
	$Parallax2D/Sprite2D.visible = false


func _process(_delta: float) -> void:
	if target == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
	if target == null:
		return
	_update_chunks()


func _update_chunks() -> void:
	var cam_x: float = target.global_position.x
	var local_x: float = cam_x * (1.0 - SCROLL_SCALE_X)
	var center: int = int(floor(local_x / _image_width))

	for i in range(center - spawn_range, center + spawn_range + 1):
		if not _chunks.has(i):
			_spawn_chunk(i)

	for key in _chunks.keys():
		if abs(key - center) > spawn_range + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)


func _spawn_chunk(index: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _texture
	sprite.position = Vector2(
		round(index * _image_width + _image_width / 2.0),  # round()로 소수점 제거
		IMAGE_CENTER_Y
	)
	sprite.scale = IMAGE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 필터링으로 인한 번짐 방지
	_parallax.add_child(sprite)
	_chunks[index] = sprite
