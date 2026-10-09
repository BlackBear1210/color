@tool
extends "res://scripts/스마트월드/흰물_디자인.gd"
## 승인된 삼색 시안의 48프레임을 재생한다. 공통 충돌/색 혼합/흘러내림 규칙은 상위 유체가 유지한다.
const FRAME_SHADER = preload("res://shaders/water_reference_frames.gdshader")
const ASSET_DIR = "res://assets/textures/obstacles/liquid/reference_20261008/"
const INLET_SCRIPT = preload("res://scripts/스마트월드/물_배관입구그림.gd")
const INLET_PROFILE = "res://assets/textures/obstacles/liquid/pipe_startup_20261009/inlet_profile.png"
var _입구: Node2D

func 배관입구_설정(depth: float, layer: int, enabled: bool) -> void:
	# 입구와 낙수가 같은 RGB 프레임·시간·속도를 공유해야 위쪽만 다른 재질로 보이지 않는다.
	if not material is ShaderMaterial:
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("inlet_depth", maxf(depth, 0.0))
	# 입구 윤곽을 고정하고 앞끝 위치로만 드러낸다. 작은 모양을 키우는 시작 마스크는 쓰지 않는다.
	mat.set_shader_parameter("inlet_profile", read_texture(INLET_PROFILE))
	if not is_instance_valid(_입구):
		_입구 = Node2D.new()
		_입구.name = "_PipeMouth"
		_입구.set_script(INLET_SCRIPT)
		add_child(_입구)
	_입구.material = mat
	_입구.z_as_relative = false
	_입구.z_index = layer
	_입구.visible = enabled
	_입구.call("설정", 크기.x, depth)
static var texture_cache: Dictionary = {}
static func read_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]
	var tex: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		# 새 에셋이 아직 임포트되지 않아도 실제 PNG를 읽어 물이 사라지지 않게 한다.
		tex = ImageTexture.create_from_image(Image.load_from_file(path))
	texture_cache[path] = tex
	return tex
func _v3_갱신(mat: ShaderMaterial) -> void:
	mat.shader = FRAME_SHADER
	mat.set_shader_parameter("body_frames", read_texture(ASSET_DIR + ("wide_joint_%d_48.png" if 크기.x >= 160.0 else "water_%d_48.png") % 물색))
	mat.set_shader_parameter("impact_frames", read_texture(IMPACT_A_PATH))
	var height := 보이는_높이 if 보이는_높이 > 0.0 else 크기.y
	mat.set_shader_parameter("extent", Vector2(크기.x, minf(height, 크기.y)))
	mat.set_shader_parameter("water_tone", 물색)
	mat.set_shader_parameter("impact", 착수_물보라)
	mat.set_shader_parameter("animate", 애니메이션)
	mat.set_shader_parameter("phase", 위상)
	mat.set_shader_parameter("speed", 흐름속도)
	queue_redraw()
