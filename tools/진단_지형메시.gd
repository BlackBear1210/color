extends SceneTree
## [2026-08-26 임시] 스마트지형이 **실제로 무엇을 굽고 있는지** 런타임에서 캔다.
## "화면에 안 보인다" 가 (a) 메시가 아예 없다 (b) 점이 틀렸다 (c) 그냥 어둡다
## 중 어느 것인지 숫자로 가른다.
## 실행: Godot --headless --path . -s res://tools/진단_지형메시.gd -- <씬>

var _n := 0
var _루트: Node = null


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		_루트 = (load(args[0]) as PackedScene).instantiate()
		root.add_child(_루트)
	elif _n == 8:
		_찍기()
		quit(0)


func _찍기() -> void:
	var 지 := _루트.get_node_or_null("지형")
	if 지 == null:
		print("지형 노드 없음")
		return
	print("%-34s %5s %5s %6s %-26s %s" \
		% ["이름", "점", "메시", "콜점", "점 로컬범위", "가시"])
	for n in 지.get_children():
		if not n.has_method("get_point_array"):
			continue
		var pa: Object = n.get_point_array()
		var 점들: Array = []
		if pa != null:
			for k in pa.get_all_point_keys():
				점들.append(pa.get_point_position(k))
		var mn := Vector2.ZERO
		var mx := Vector2.ZERO
		if 점들.size() > 0:
			mn = 점들[0]
			mx = 점들[0]
			for p in 점들:
				mn = mn.min(p)
				mx = mx.max(p)
		var 메시수 := 0
		var m = n.get("_meshes")
		if m != null:
			메시수 = (m as Array).size()
		var 콜점 := 0
		var 폴리 := n.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
		if 폴리 != null:
			콜점 = 폴리.polygon.size()
		print("%-34s %5d %5d %6d %-26s %s" % [
			String(n.name), 점들.size(), 메시수, 콜점,
			"%.0f,%.0f ~ %.0f,%.0f" % [mn.x, mn.y, mx.x, mx.y],
			str((n as CanvasItem).visible),
		])
		# ★렌더되는 메시의 실제 크기 — 점과 다르면 그것이 곧 버그다
		if 메시수 > 0:
			var amn := Vector2(1e9, 1e9)
			var amx := Vector2(-1e9, -1e9)
			for mm in (m as Array):
				var am: Mesh = mm.get("mesh") as Mesh
				if am == null:
					continue
				var bb := am.get_aabb()
				amn = amn.min(Vector2(bb.position.x, bb.position.y))
				amx = amx.max(Vector2(bb.end.x, bb.end.y))
			print("        메시 실크기 %.0f x %.0f   (%.0f,%.0f ~ %.0f,%.0f)" % [amx.x - amn.x, amx.y - amn.y, amn.x, amn.y, amx.x, amx.y])
