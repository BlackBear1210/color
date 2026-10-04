@tool
extends "res://scripts/스마트월드/지형.gd"
## 2층방 전용 시안. 점·충돌·색 판정은 상속하고 윗면만 얕은 데크로 나눈다.
const 결 := preload("res://assets/textures/smartshape/wood_deck_v3/grain.png")

func _ready() -> void:
	# 원본 공용 템플릿을 바꾸지 않고 이 파생 템플릿의 재질만 복제한다.
	var 흰색기본 := 시작상태 == 상태.흰색
	var 색폴더 := "white" if 흰색기본 else "black"
	var 재질 := SS2D_Material_Shape.new()
	재질.fill_textures = [load("res://assets/textures/smartshape/wood_deck_v3/%s/fill.tres" % 색폴더)]
	재질.fill_texture_scale = 0.18
	재질.fill_texture_z_index = -1
	재질.fill_texture_absolute_position = true
	var 엣지 := SS2D_Material_Edge.new()
	엣지.textures = [load("res://assets/textures/smartshape/wood_deck_v3/%s/edge.tres" % 색폴더)]
	엣지.texture_scale = 0.18
	엣지.fit_mode = 1
	엣지.use_corner_texture = false
	엣지.use_taper_texture = false
	var 메타 := SS2D_Material_Edge_Metadata.new()
	메타.edge_material = 엣지
	메타.normal_range = SS2D_NormalRange.new(40.0, 100.0)
	메타.offset = -0.72
	재질.set_edge_meta_materials([메타])
	shape_material = 재질
	# 편집기에서도 런타임과 같은 색을 보이며 기존 페인트 설치가 이를 이어받는다.
	재질.fill_mesh_material = _셰이더_만들기(재질.fill_textures[0], true, false)
	엣지.material = _셰이더_만들기(엣지.textures[0], true, true)
	super()

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var mat := super._셰이더_만들기(source, quiet, edge)
	if mat != null:
		mat.set_shader_parameter("wood_mode", 2 if edge else 1)
		mat.set_shader_parameter("wood_grain", 결)
	return mat
