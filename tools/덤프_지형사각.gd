extends SceneTree
## [2026-10-08 Claude] 씬의 지형·기믹 위치를 월드 사각형으로 찍는다(열쇠 조각·잠긴 문 자리를 정할 때 썼다).
##   실행: Godot_console --headless --path . -s res://tools/덤프_지형사각.gd -- res://scenes/…/씬.tscn
##   출력: 이름 · 종류 · 월드 AABB(x0, y0 → x1, y1) · 시작상태(지형이면)
##   읽기만 한다 — 씬을 저장하지 않는다.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var 경로: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var 씬: Node = (load(경로) as PackedScene).instantiate()
	root.add_child(씬)
	for i in 10:
		await physics_frame
	for n in 씬.find_children("*", "CollisionPolygon2D", true, false):
		var cp := n as CollisionPolygon2D
		if cp.polygon.is_empty():
			continue
		var r := Rect2(cp.global_transform * cp.polygon[0], Vector2.ZERO)
		for p in cp.polygon:
			r = r.expand(cp.global_transform * p)
		var 주인 := cp.get_parent()
		while 주인 and 주인 != 씬 and 주인.get("시작상태") == null:
			주인 = 주인.get_parent()
		var 이름 := String(주인.name) if 주인 and 주인 != 씬 else String(cp.get_parent().name)
		var 상태 = 주인.get("시작상태") if 주인 and 주인 != 씬 else null
		print("지형 %-22s  %6.0f,%6.0f → %6.0f,%6.0f  시작상태=%s 칠=%s" % [이름, r.position.x, r.position.y, r.end.x, r.end.y,
			str(상태), str(주인.get("칠하기_허용") if 주인 and 주인 != 씬 else "")])
	for n in 씬.find_children("*", "Node2D", true, false):
		var s: Script = n.get_script()
		if s and (n.is_in_group("도약대") or s.resource_path.contains("연결") or s.resource_path.contains("체크포인트")
				or s.resource_path.contains("도약대")):
			print("기믹 %-22s  %s  %s" % [n.name, str((n as Node2D).global_position), s.resource_path.get_file()])
	quit(0)
