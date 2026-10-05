@tool
extends "res://scripts/스마트월드/지형.gd"
## 쳅터1 목재. 발 딛는 면에만 상판을 놓고 옆·아랫면은 어두운 목재 단면으로 남긴다.
## [2026-10-05] 기존 앞면 명도를 윗면으로 옮기고 앞면을 낮춰 발이 닿는 면을 구분한다.
## 셰이더는 ASCII만 허용하므로 wood_deck.gdshaderinc 변경 이유도 이곳에 기록한다.
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
	# 사방에 윗면을 두르면 액자처럼 보이므로 위를 향한 거의 수평인 변에만 상판을 붙인다.
	# 실제 외곽의 모따기·부서진 밑면은 채우기 메시가 그대로 보여 준다.
	엣지.uniform_width = true
	엣지.use_corner_texture = false
	엣지.use_taper_texture = false
	var 메타 := SS2D_Material_Edge_Metadata.new()
	메타.edge_material = 엣지
	메타.normal_range = SS2D_NormalRange.new(80.0, 20.0)
	메타.weld = true
	# 바깥으로 돌출한 그림 위에 발이 묻히지 않도록 마감판 전체를 충돌선 안에 둔다.
	메타.offset = -1.0
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
