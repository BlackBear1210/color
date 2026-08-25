@tool
extends Resource
class_name SS2D_Material_Edge

## This material represents the set of textures used for a single edge.
##
## This consists of: [br]
## - textures [br]
## - corner_textures [br]
## - taper_textures [br]

## All variations of the main edge texture.[br]
## _textures[0] is considered the "main" texture for the EdgeMaterial.[br][br]
## [b]Note:[/b] Will be used to generate an icon representing an edge texture.[br]
@export var textures: Array[Texture2D] = [] : set = _set_textures

# Textures for the final left and right quad of the edge when the angle is steep
@export var textures_corner_outer: Array[Texture2D] = [] : set = _set_textures_corner_outer
@export var textures_corner_inner: Array[Texture2D] = [] : set = _set_textures_corner_inner

# Textures for the final left and right quad of the edge when the angle is shallow
# Named as such because the desired look is that the texture "tapers-off"
@export var textures_taper_left: Array[Texture2D] = [] : set = _set_textures_taper_left
@export var textures_taper_right: Array[Texture2D] = [] : set = _set_textures_taper_right

## Textures that will be used for the sharp_corner_tapering feature
@export var textures_taper_corner_left: Array[Texture2D] = [] : set = _set_textures_taper_corner_left
@export var textures_taper_corner_right: Array[Texture2D] = [] : set = _set_textures_taper_corner_right

## If the texture choice should be randomized instead of the choice by point setup
@export var randomize_texture: bool = false : set = _set_randomize_texture
## If corner textures should be used
@export var use_corner_texture: bool = true : set = _set_use_corner
## If taper textures should be used
@export var use_taper_texture: bool = true : set = _set_use_taper

## Whether squishing can occur when texture doesn't fit nicely into total length.
enum FITMODE {SQUISH_AND_STRETCH, CROP}
@export var fit_mode: FITMODE = FITMODE.SQUISH_AND_STRETCH : set = _set_fit_texture

## [P0-1] 텍스처의 픽셀 크기와 월드 크기를 분리하는 배율.[br]
## [br]
## 원래 이 애드온은 "텍스처 1픽셀 = 월드 1픽셀" 로 고정되어 있었다.
## 즉 엣지 띠의 월드 두께가 텍스처의 픽셀 높이와 같고, 반복 주기가 텍스처의 픽셀 폭과 같았다.
## 그래서 해상도를 올리면 지형이 물리적으로 커져 버려서 고해상도 일러스트 텍스처를 쓸 수 없었다.[br]
## [br]
## 이 값을 곱하면 가로/세로 양쪽에 동일하게 적용되어 종횡비가 유지된다.[br]
## 예) 1024x256 텍스처 + texture_scale 0.35 -> 월드에서 358x90 (grass_v3 의 256x90 과 같은 두께).[br]
## [br]
## [b]기본값 1.0 은 기존 동작과 완전히 동일하다.[/b] 기존 .tres 는 이 키가 없으므로
## 로드 시 1.0 이 들어가고, 따라서 기존 지형은 픽셀 단위로 똑같이 렌더된다.
@export_range(0.05, 4.0, 0.005, "or_greater") var texture_scale: float = 1.0 : set = _set_texture_scale

## [P0-3] 모서리에서 테두리의 **수직 두께**를 일정하게 유지한다.[br]
## [br]
## 끄면(기본) SS2D 원래 동작 — 이음매 선분 길이만 맞추므로 수직 두께가
## sin(θ/2) 배로 줄고, 모서리 각이 다른 도형에서는 변마다 두께가 달라진다.[br]
## 켜면 이음매를 미터(miter) 로 늘려 어떤 모양에서도 두께가 같다.
## 액자 테두리처럼 균일한 띠가 필요할 때 쓴다.
@export var uniform_width: bool = false : set = _set_uniform_width

@export var material: Material = null : set = _set_material


###########
# SETTERS #
###########
func _set_textures(ta: Array[Texture2D]) -> void:
	textures = ta
	emit_changed()


func _set_textures_corner_outer(a: Array[Texture2D]) -> void:
	textures_corner_outer = a
	emit_changed()


func _set_textures_corner_inner(a: Array[Texture2D]) -> void:
	textures_corner_inner = a
	emit_changed()


func _set_textures_taper_left(a: Array[Texture2D]) -> void:
	textures_taper_left = a
	emit_changed()


func _set_textures_taper_right(a: Array[Texture2D]) -> void:
	textures_taper_right = a
	emit_changed()

func _set_textures_taper_corner_left(a: Array[Texture2D]) -> void:
	textures_taper_corner_left = a
	emit_changed()

func _set_textures_taper_corner_right(a: Array[Texture2D]) -> void:
	textures_taper_corner_right = a
	emit_changed()

func _set_randomize_texture(b: bool) -> void:
	randomize_texture = b
	emit_changed()


func _set_use_corner(b: bool) -> void:
	use_corner_texture = b
	emit_changed()


func _set_use_taper(b: bool) -> void:
	use_taper_texture = b
	emit_changed()


func _set_fit_texture(fitmode: FITMODE) -> void:
	fit_mode = fitmode
	emit_changed()


# [P0-1] 다른 setter 들과 동일한 규약: 값이 바뀌면 emit_changed() 로 셰이프를 다시 굽게 한다.
func _set_texture_scale(f: float) -> void:
	texture_scale = f
	emit_changed()


func _set_material(m: Material) -> void:
	material = m
	emit_changed()


###########
# GETTERS #
###########
func get_texture(idx: int) -> Texture2D:
	return _get_element(idx, textures)


func get_texture_corner_inner(idx: int) -> Texture2D:
	return _get_element(idx, textures_corner_inner)


func get_texture_corner_outer(idx: int) -> Texture2D:
	return _get_element(idx, textures_corner_outer)


func get_texture_taper_left(idx: int) -> Texture2D:
	return _get_element(idx, textures_taper_left)


func get_texture_taper_right(idx: int) -> Texture2D:
	return _get_element(idx, textures_taper_right)


func get_texture_taper_corner_left(idx: int) -> Texture2D:
	return _get_element(idx, textures_taper_corner_left)


func get_texture_taper_corner_right(idx: int) -> Texture2D:
	return _get_element(idx, textures_taper_corner_right)


#########
# USAGE #
#########

## Returns main texture used to visually identify this edge material
func get_icon_texture() -> Texture2D:
	if not textures.is_empty():
		return textures[0]
	return null


############
# INTERNAL #
############
func _get_element(idx: int, a: Array) -> Variant:
	if a.is_empty():
		return null
	return a[_adjust_idx(idx, a)]


func _adjust_idx(idx: int, a: Array) -> int:
	return idx % a.size()


func _set_uniform_width(b: bool) -> void:
	uniform_width = b
	emit_changed()
