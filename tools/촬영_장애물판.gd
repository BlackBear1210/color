extends SceneTree
## ============================================================================
## [2026-10-04 Claude] 장애물 현황판 — scenes/집/스마트월드_장애물 + scenes/장애물 을 한 화면에 늘어놓고 찍는다
##   Godot_console --path . -s res://tools/촬영_장애물판.gd      (창 모드 — 촬영)
## 결과: res://tools/_진단/장애물판.png   (도형님이 "어느 장애물을 고도화할지" 고르는 판)
## ============================================================================

const 폴더들 := ["res://scenes/집/스마트월드_장애물/", "res://scenes/장애물/"]
const 칸 := Vector2(520, 420)
const 열 := 8

var _판: Node2D
var _f := 0


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	_판 = Node2D.new()
	root.add_child(_판)
	current_scene = _판
	var 배경 := ColorRect.new()
	배경.color = Color(0.42, 0.42, 0.42)
	배경.position = Vector2(-200, -300)
	배경.size = Vector2(열 * 칸.x + 400, 6 * 칸.y + 600)
	배경.z_index = -100
	_판.add_child(배경)
	var 목록: Array[String] = []
	for d in 폴더들:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".tscn"):
				목록.append(d + f)
	목록.sort()
	var i := 0
	for p in 목록:
		var 팩 := load(p) as PackedScene
		if 팩 == null:
			continue
		var n := 팩.instantiate()
		if not (n is Node2D):
			n.free()
			continue
		var 자리 := Vector2((i % 열) * 칸.x, (i / 열) * 칸.y)
		(n as Node2D).position = 자리 + Vector2(칸.x * 0.5, 칸.y * 0.62)
		n.process_mode = Node.PROCESS_MODE_DISABLED       # 물리·스크립트 동작은 멈추고 모양만
		_판.add_child(n)
		var 글 := Label.new()
		글.text = p.get_file().get_basename()
		글.position = 자리 + Vector2(12, 8)
		글.add_theme_font_size_override("font_size", 30)
		글.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		글.z_index = 50
		_판.add_child(글)
		i += 1
	var cam := Camera2D.new()
	var 줄수 := ceili(float(i) / 열)
	var 크기 := Vector2(열 * 칸.x, 줄수 * 칸.y)
	cam.position = 크기 * 0.5
	var z := minf(1920.0 / 크기.x, 1080.0 / 크기.y)
	cam.zoom = Vector2(z, z)
	_판.add_child(cam)
	cam.make_current()
	print("장애물 ", i)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 20:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/_진단/장애물판.png"))
		print("SHOT")
		quit()
	return false
