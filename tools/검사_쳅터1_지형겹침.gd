extends SceneTree
## [2026-10-09 Claude] 쳅터1 씬마다 지형(SS2D) 다각형끼리 겹치는 넓이를 잰다 — "지형이 겹쳐 보인다" 확인용
func _initialize() -> void:
	call_deferred("run")
func _다각형(n: Node2D) -> PackedVector2Array:
	var pa = n.call("get_point_array")
	var out := PackedVector2Array()
	if pa == null:
		return out
	for k in pa.get_all_point_keys():
		out.append(n.to_global(pa.get_point_position(k)))
	return out
func run() -> void:
	# 검사에서 로드한 방을 현재 씬으로 지정해야 거울·반사빛길이 Player를 정상적으로 찾는다.
	# 사용자 진행 파일도 지형 검사 중에는 쓰지 않는다.
	게임진행.기록_허용 = 0
	var d := DirAccess.open("res://scenes/쳅터1/스테이지/")
	var 파일들 := Array(d.get_files()).filter(func(f): return f.ends_with(".tscn"))
	파일들.sort()
	for f in 파일들:
		var s = (load("res://scenes/쳅터1/스테이지/" + f) as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		await process_frame
		await physics_frame
		var 지형들: Array = []
		for n in s.find_children("*", "Node2D", true, false):
			if n.has_method("get_point_array") and n.get_parent().name in ["지형", "추가지형"]:
				지형들.append(n)
		var 겹침 := []
		for i in 지형들.size():
			var a := _다각형(지형들[i])
			if a.size() < 3: continue
			for j in range(i + 1, 지형들.size()):
				var b := _다각형(지형들[j])
				if b.size() < 3: continue
				var 넓이 := 0.0
				for poly in Geometry2D.intersect_polygons(a, b):
					var ar := 0.0
					for k in poly.size():
						ar += poly[k].x * poly[(k + 1) % poly.size()].y - poly[(k + 1) % poly.size()].x * poly[k].y
					넓이 += absf(ar) * 0.5
				if 넓이 > 256.0:
					겹침.append("%s/%s×%s/%s %.0f" % [지형들[i].get_parent().name, 지형들[i].name, 지형들[j].get_parent().name, 지형들[j].name, 넓이])
		print(f.get_basename(), " 지형 ", 지형들.size(), " 겹침 ", 겹침.size(), " ", 겹침.slice(0, 6))
		# 렌더·물리 서버가 참조 중인 SS2D를 즉시 지우지 않고 프레임 끝에서 해제해 검사 종료 충돌을 피한다.
		s.queue_free()
		await process_frame
		await physics_frame
	quit()
