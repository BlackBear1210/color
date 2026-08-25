extends SceneTree
## [2026-08-25] 씬을 실제로 인스턴스해서 오류/경고가 나는지 본다.
## 리소스 누락(머티리얼·텍스처)은 로드 단계에서 push_error 로 나오므로 여기서 걸린다.
func _init(): call_deferred("_go")
func _go():
	var 목록 := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--씬="): 목록.append(a.substr("--씬=".length()))
	for p in 목록:
		if not ResourceLoader.exists(p):
			print("  ✗ 없음 %s" % p); continue
		var ps: PackedScene = load(p)
		if ps == null:
			print("  ✗ 로드 실패 %s" % p); continue
		var n: Node = ps.instantiate()
		root.add_child(n)
		# 지형 노드마다 머티리얼/텍스처가 실제로 물렸는지
		var 지형수 := 0
		var 문제 := 0
		for c in _모두(n):
			if c.has_method("get_point_array") and c.get("shape_material") != null:
				지형수 += 1
				var m = c.get("shape_material")
				if m.fill_textures.is_empty() and not String(c.name).contains("HOLLOW"):
					pass   # 속빔이 아닌데 필이 비면 아래 메타 검사에서 잡힌다
				for meta in m.get_all_edge_meta_materials():
					var e = meta.edge_material
					if e == null:
						문제 += 1; continue
					if e.use_corner_texture:
						if e.textures_corner_outer.is_empty() or e.textures_corner_outer[0] == null:
							문제 += 1
					else:
						if e.textures.is_empty() or e.textures[0] == null:
							문제 += 1
		print("  %s  지형 %d개 · 머티/텍스처 문제 %d" % [p.get_file(), 지형수, 문제])
		n.queue_free()
		root.remove_child(n)
	quit()
func _모두(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_모두(c))
	return out
