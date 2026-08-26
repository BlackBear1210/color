extends SceneTree
## [2026-08-26 임시] 스테이지 전체를 한 장에 — 지형이 **어디에 얼마만큼** 렌더되는지 본다.
## 카메라공간(Area2D)을 전부 떼고, 어둠을 끄고, 카메라를 통째로 물린다.
## 실행: Godot --path . -s res://tools/shot_전경.gd -- <씬> <저장.png> <중심x> <중심y> <줌>

var _n := 0
var _scene: Node


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		_scene = (load(args[0]) as PackedScene).instantiate()
		root.add_child(_scene)
	elif _n == 6:
		var 어둠 := _scene.get_node_or_null("어둠") as CanvasModulate
		if 어둠:
			어둠.color = Color(1, 1, 1)
		# 카메라공간·리밋·추적을 전부 무력화하고 고정 카메라를 하나 새로 꽂는다
		var 오 := _scene.get_node_or_null("오브젝트")
		if 오:
			for c in 오.get_children():
				if String(c.name).begins_with("카메라_"):
					c.queue_free()
		var cam := _scene.get_node_or_null("카메라") as Camera2D
		if cam:
			cam.set_process(false)
			cam.set_physics_process(false)
			cam.enabled = false
		var 새 := Camera2D.new()
		새.position = Vector2(float(args[2]), float(args[3]))
		새.zoom = Vector2.ONE * float(args[4])
		새.enabled = true
		_scene.add_child(새)
		새.make_current()
	elif _n == 80:
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[1])
		print("shot: ", error_string(err), " -> ", args[1])
		quit(0 if err == OK else 1)
