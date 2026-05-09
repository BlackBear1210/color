extends ParallaxBackground

@export var target: Node2D
@export var spawn_range: int = 3

const IMAGE_WIDTH: float = 1377.0
const IMAGE_CENTER_Y: float = 328.0
const IMAGE_SCALE: Vector2 = Vector2(0.7169271, 0.73333335)
const SCROLL_SCALE_X: float = 0.8

var _parallax: Parallax2D
var _texture: Texture2D
var _chunks: Dictionary = {}


func _ready() -> void:
	_parallax = $Parallax2D
	_texture = $Parallax2D/Sprite2D.texture
	_parallax.repeat_size = Vector2.ZERO
	$Parallax2D/Sprite2D.visible = false
	_update_chunks()


func _process(_delta: float) -> void:
	if target == null:
		return
	_update_chunks()


func _update_chunks() -> void:
	# 카메라 로컬 x = 카메라 x * (1 - scroll_scale) → 어느 청크가 보일지 판단
	var cam_x: float = target.global_position.x
	var local_x: float = cam_x * (1.0 - SCROLL_SCALE_X)
	var center: int = int(floor(local_x / IMAGE_WIDTH))

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
	sprite.position = Vector2(index * IMAGE_WIDTH + IMAGE_WIDTH / 2.0, IMAGE_CENTER_Y)
	sprite.scale = IMAGE_SCALE
	_parallax.add_child(sprite)
	_chunks[index] = sprite
