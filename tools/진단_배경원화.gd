extends SceneTree
## [2026-08-30 임시] 실내배경 노드가 런타임에 원화를 실제로 들고 있는지 찍어 본다.
## 실행: godot --headless --path . -s res://tools/진단_배경원화.gd -- <씬경로>
func _init() -> void: call_deferred("_go")
func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var 경로: String = a[0] if a.size() > 0 else "res://scenes/집/스테이지_1_2층방.tscn"
	var n: Node = (load(경로) as PackedScene).instantiate()
	root.add_child(n)
	await process_frame
	for c in _모두(n):
		if c.get_script() == null: continue
		if not String(c.get_script().resource_path).ends_with("실내배경.gd"): continue
		var t = c.get("그림_아래")
		print("  %-22s 그림_아래=%s  맞춤=%s  원본영역=%s  영역=%s  밝기=%s  깊이=%s  z=%d" % [
			c.name, ("null ✗" if t == null else "%s %s ✔" % [t.resource_path.get_file(), t.get_size()]),
			c.get("그림_맞춤"), c.get("그림_원본영역"), c.get("영역"),
			c.get("그림_밝기"), c.get("깊이"), c.z_index])
	quit()
func _모두(n: Node) -> Array:
	var r := [n]
	for c in n.get_children(): r.append_array(_모두(c))
	return r
