extends SceneTree
## [2026-10-05 Claude] 목재 끝 마감(왼 계단 끝·상자 오른 위 모서리) 확인 촬영 — 창 모드로 실행(--headless 금지)
##   Godot_console --path . -s res://tools/촬영_목재마감.gd
## 플레이어 시작 자리 둘레를 찍는다. 결과: res://tools/_진단/목재마감/<자리>.png (1280×720)

const 폴더 := "res://tools/_진단/목재마감/"
## [씬, 카메라 가운데(월드 px, ZERO 면 플레이어 자리), 줌, 이름]
const 자리들 := [
	["res://scenes/쳅터1/스테이지/쳅터1_04_복도_B.tscn", Vector2(880, 1080), 2.0, "04_흰맞물림"],
	["res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn", Vector2(2000, 1660), 2.0, "05_흰맞물림"],
	["res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn", Vector2(1600, 1640), 2.0, "01_흰맞물림"],
]

var _i := -1
var _씬: Node = null
var _f := 0


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
	_씬 = (load(자리들[_i][0]) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_f = 0


func _카메라() -> void:
	var 자리: Array = 자리들[_i]
	var 가운데: Vector2 = 자리[1]
	if 가운데 == Vector2.ZERO:
		var 플 := _씬.find_child("Player", true, false)
		if 플 is Node2D:
			가운데 = (플 as Node2D).global_position + Vector2(260, -40) * (1.0 / 자리[2])
	for c in _씬.find_children("*", "Camera2D", true, false):
		(c as Camera2D).process_mode = Node.PROCESS_MODE_DISABLED
		(c as Camera2D).enabled = false
	var cam := Camera2D.new()
	cam.position = 가운데
	cam.zoom = Vector2(자리[2], 자리[2])
	_씬.add_child(cam)
	cam.make_current()
	for n in _씬.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	print("CAM ", 자리[3], " ", 가운데)


func _process(_d: float) -> bool:
	if _씬 == null:
		return false
	_f += 1
	if _f == 30:
		_카메라()
	if _f == 40:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(폴더 + 자리들[_i][3] + ".png"))
		print("SHOT ", 자리들[_i][3])
		_다음()
	return false
