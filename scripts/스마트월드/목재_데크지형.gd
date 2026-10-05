@tool
extends "res://scripts/스마트월드/지형.gd"
## 목재 앞면은 SS2D 채우기, 상판과 옆 단면은 독립된 덮개 메시로 그린다.
## 외곽 엣지의 UV를 돌려 쓰지 않으므로 계단 옆면에 상판이 내려가지 않는다.
const 결 := preload("res://assets/textures/smartshape/wood_deck_v3/grain.png")
const 상판결 := preload("res://assets/textures/smartshape/wood_deck_v4/top_grain.png")
const 덮개 := preload("res://scripts/스마트월드/목재_상판메시.gd")
var _덮개재질: ShaderMaterial
var _상판초기화완료: bool = false
var 덮개_생성횟수: int = 0

func _재질준비() -> void:
	# 공용 원본과 이웃 지형의 재질은 바꾸지 않는다. 저장된 이전 테두리도 확실히 끈다.
	var 색폴더 := "white" if 시작상태 == 상태.흰색 else "black"
	var 재질 := SS2D_Material_Shape.new()
	재질.fill_textures = [load("res://assets/textures/smartshape/wood_deck_v3/%s/fill.tres" % 색폴더)]
	# 한 가로 판자 높이를 32px 칸과 맞춰 흰색 맞물림 경계가 나무결 중간을 자르지 않게 한다.
	재질.fill_texture_scale = 0.28125
	재질.fill_texture_z_index = -1
	재질.fill_texture_absolute_position = true
	재질.set_edge_meta_materials([])
	재질.fill_mesh_material = _셰이더_만들기(재질.fill_textures[0], true, false)
	render_edges = false
	shape_material = 재질
	_상판초기화완료 = true

func _ready() -> void:
	_재질준비()
	super()
	# 점 편집과 형제 추가에만 반응한다. 고정 지형의 메시를 매 프레임 만들지 않는다.
	if get_parent() != null and not get_parent().child_order_changed.is_connected(_이웃연결):
		get_parent().child_order_changed.connect(_이웃연결)
	_이웃연결()

func _이웃연결() -> void:
	if get_parent() == null:
		return
	for node in get_parent().get_children():
		if node == self or not node.has_method("get_point_array"):
			continue
		if not node.points_modified.is_connected(set_as_dirty):
			node.points_modified.connect(set_as_dirty)
	set_as_dirty()

func _process(delta: float) -> void:
	# 열린 편집기에서 스크립트가 교체되어도 _ready 재호출 없이 이전 액자 메시를 지운다.
	if not _상판초기화완료:
		_재질준비()
		_meshes.clear()
		force_update()
	super(delta)

func _build_meshes() -> void:
	if _덮개재질 != null:
		_셰이더들.erase(_덮개재질)
	_덮개재질 = null
	if render_edges:
		render_edges = false
	super()
	if shape_material == null or _points == null:
		return
	var points: PackedVector2Array = _points.get_tessellated_points()
	if points.size() < 3:
		return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var others: Array[PackedVector2Array] = []
	if get_parent() != null:
		for node in get_parent().get_children():
			if node == self or not node is Node2D or not node.has_method("get_point_array"):
				continue
			if not node.is_visible_in_tree():
				continue
			var array: Resource = node.call("get_point_array")
			var poly := PackedVector2Array()
			var other_points: PackedVector2Array = array.call("get_tessellated_points")
			for p in other_points:
				poly.append(to_local(node.to_global(p)))
			if poly.size() < 3:
				continue
			var other_bounds := Rect2(poly[0],Vector2.ZERO)
			for p in poly:
				other_bounds = other_bounds.expand(p)
			if bounds.grow(30.0).intersects(other_bounds,true):
				others.append(덮개.정리(poly))
	var mesh := 덮개.생성(points,others,global_position)
	if mesh.get_surface_count() == 0:
		return
	var piece := SS2D_Mesh.new()
	piece.mesh = mesh
	piece.texture = shape_material.fill_textures[0]
	piece.z_index = 0
	_덮개재질 = _셰이더_만들기(piece.texture,true,false)
	_덮개재질.set_shader_parameter("wood_mode",2)
	piece.material = _덮개재질
	_meshes.append(piece)
	# 같은 로컬 원점과 페인트 목록을 공유해 칠하기·유령 효과가 앞면/상판에서 함께 바뀐다.
	if not Engine.is_editor_hint():
		_셰이더들.append(_덮개재질)
		_유니폼_갱신.call_deferred()
	덮개_생성횟수 += 1

## ★[2026-10-05 Claude] 2.5D 명암 안 — 도형님이 엔진 캡처(docs 작업기록 · tools/쳅터1/목재_v04_검토/)를 보고 고른다.
##   0 = 판자 맞춤만(명암은 v03 그대로) · 1 = 안 A 은은한 명암 · 2 = 안 B 깊은 명암(기본) · 3 = 안 C 먹선(검은 이음새 테두리)
##   셰이더(wood_deck.gdshaderinc)의 wood_style 로 넘어간다. 바꾸려면 이 숫자 하나만 고친다.
const 명암_안 := 2

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var mat := super._셰이더_만들기(source, quiet, edge)
	if mat != null:
		mat.set_shader_parameter("wood_mode",1)
		mat.set_shader_parameter("wood_grain",결)
		mat.set_shader_parameter("wood_top_grain",상판결)
		mat.set_shader_parameter("wood_style",명암_안)
		# 셰이더는 노드-로컬 좌표만 안다 → 지형 노드 위치를 넘겨 월드 32px 판자 줄(앞면 원화)과 맞춘다.
		#   지형은 움직이지 않으므로 만들 때 한 번이면 된다.
		mat.set_shader_parameter("wood_origin",global_position if is_inside_tree() else position)
	return mat
