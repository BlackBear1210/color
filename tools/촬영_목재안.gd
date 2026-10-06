extends SceneTree
## ============================================================================
## [2026-10-05 Claude] 쳅터1 목재 2.5D 명암 안 비교 촬영 — 창 모드로 실행(--headless 금지)
##   Godot_console --path . -s res://tools/촬영_목재안.gd
## 같은 자리를 명암 안 0(판자 맞춤만)·1(A 은은)·2(B 깊게)·3(C 먹선)으로 바꿔 가며 찍는다.
##   안은 셰이더 uniform wood_style 하나라서, 씬을 다시 만들지 않고 재질 값만 바꿔 찍는다.
## 결과: res://tools/쳅터1/목재_v04_검토/<자리>_안<번호>.png (1280×720) → 비교판은 python 이 묶는다.
## ============================================================================

const 폴더 := "res://tools/쳅터1/목재_v04_검토/"
## [씬, 카메라 가운데(월드 px), 줌, 자리 이름]
const 자리들 := [
	["res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn", Vector2(820, 1420), 1.35, "1_시작방_블록"],
	["res://scenes/쳅터1/스테이지/쳅터1_04_복도_B.tscn", Vector2(880, 1040), 2.4, "2_복도B_흰맞물림_확대"],
	["res://scenes/쳅터1/스테이지/쳅터1_02_복도_A.tscn", Vector2(4030, 860), 1.25, "3_복도A_공중발판"],
	["res://scenes/쳅터1/스테이지/쳅터1_02_복도_A.tscn", Vector2(3830, 880), 2.6, "4_복도A_흰발판_확대"],
	["res://scenes/쳅터1/스테이지/쳅터1_08_복도_D.tscn", Vector2(3640, 840), 1.25, "5_복도D_색징검다리"],
]

var _i := -1
var _씬: Node = null
var _f := 0
var _안 := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	root.size = Vector2i(1280, 720)
	_다음()


func _다음() -> void:
	if _씬:
		_씬.queue_free()
		_씬 = null
	_i += 1
	if _i >= 자리들.size():
		print("DONE")
		quit()
		return
	var 자리: Array = 자리들[_i]
	_씬 = (load(자리[0]) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_f = 0
	_안 = 0


func _카메라() -> void:
	var 자리: Array = 자리들[_i]
	for c in _씬.find_children("*", "Camera2D", true, false):
		(c as Camera2D).process_mode = Node.PROCESS_MODE_DISABLED
		(c as Camera2D).enabled = false
	var cam := Camera2D.new()
	cam.position = 자리[1]
	cam.zoom = Vector2(자리[2], 자리[2])
	_씬.add_child(cam)
	cam.make_current()
	# HUD 는 가린다(나무만 비교)
	for n in _씬.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false


## 이 씬의 모든 목재 재질(앞면 채우기 + 상판 덮개)에 명암 안을 넣는다.
func _안_적용(안: int) -> void:
	for n in _씬.get_node("지형").get_children():
		var 재질들: Array = []
		var 목록 = n.get("_셰이더들")
		if 목록 is Array:
			재질들.append_array(목록)
		var 메시들 = n.get("_meshes")
		if 메시들 is Array:
			for m in 메시들:
				if m != null and m.get("material") is ShaderMaterial:
					재질들.append(m.material)
		var 모양재질 = n.get("shape_material")
		if 모양재질 != null and 모양재질.get("fill_mesh_material") is ShaderMaterial:
			재질들.append(모양재질.fill_mesh_material)
		for mat in 재질들:
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("wood_style", 안)
		if n.has_method("queue_redraw"):
			n.queue_redraw()


func _process(_d: float) -> bool:
	if _씬 == null:
		return false
	_f += 1
	if _f == 30:
		_카메라()
	if _f >= 40 and (_f - 40) % 6 == 0:
		var 단계 := int((_f - 40) / 6)
		# 짝수 단계: 안 적용 / 홀수 단계: 촬영 (한 프레임 이상 그린 뒤 찍는다)
		if 단계 % 2 == 0:
			_안 = 단계 / 2
			if _안 > 3:
				_다음()
				return false
			_안_적용(_안)
		else:
			var img := root.get_texture().get_image()
			var 이름 := "%s_안%d.png" % [자리들[_i][3], _안]
			img.save_png(ProjectSettings.globalize_path(폴더 + 이름))
			print("SHOT ", 이름)
	return false
