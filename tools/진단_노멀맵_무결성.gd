extends SceneTree
## [2026-09-05 임시] 노멀맵 테스트가 기존 구조를 안 깼는지 헤드리스로 확인한다.
##   ① 원본 재질이 그대로인가  ② 흑↔백 짝 찾기가 살아 있나  ③ 콜리전이 원본과 같은가
const 테스트씬 := "res://scenes/집/테스트_2층방_노멀맵.tscn"
const 원본씬 := "res://scenes/집/스테이지_1_2층방.tscn"
const 원본재질 := "res://assets/textures/smartshape/brick_v2_opaque/tres/지형_벽돌v2_opaque_black_사방.tres"

func _init() -> void: call_deferred("_go")

func _go() -> void:
	var 원 := load(원본재질)
	var of: Texture2D = 원.fill_textures[0]
	print("① 원본 재질 fill_textures[0] = %s (%s) → %s" % [of.get_class(),
		of.resource_path.get_file(),
		("원본 그대로 ✔" if not (of is CanvasTexture) else "★바뀌었다 ✗")])

	var 테 := (load(테스트씬) as PackedScene).instantiate()
	root.add_child(테); current_scene = 테
	for _i in 40: await process_frame
	var 지형들 := _모두(테).filter(func(n): return n.get("shape_material") != null)
	var 노멀_물린것 := 0
	var 짝_성공 := 0
	var 짝_폴백 := 0
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty(): continue
		if not (sm.fill_textures[0] is CanvasTexture): continue
		노멀_물린것 += 1
		var mm = sm.fill_mesh_material
		if mm == null: continue
		# alt_invert 가 켜져 있으면 = 흰색 짝을 못 찾아 밝기 반전으로 때우는 중
		if mm.get_shader_parameter("alt_invert") == true: 짝_폴백 += 1
		else: 짝_성공 += 1
	print("② 노멀맵(CanvasTexture) 물린 지형 = %d개 / 흑백짝 성공 %d · 폴백 %d → %s" % [
		노멀_물린것, 짝_성공, 짝_폴백,
		("진짜 흰색 아트를 물었다 ✔" if 짝_폴백 == 0 else "★밝기반전 폴백 ✗")])
	var 테콜 := _콜(테)
	테.queue_free(); current_scene = null
	for _i in 8: await process_frame

	var 원노 := (load(원본씬) as PackedScene).instantiate()
	root.add_child(원노); current_scene = 원노
	for _i in 40: await process_frame
	var 원콜 := _콜(원노)
	print("③ 콜리전 폴리곤: 테스트 %d개 / 원본 %d개 → %s" % [테콜.size(), 원콜.size(),
		("완전히 동일 ✔" if 테콜 == 원콜 else "★달라졌다 ✗")])
	quit()

func _콜(뿌리: Node) -> Array:
	var r: Array = []
	for n in _모두(뿌리):
		if not (n is CollisionPolygon2D): continue
		var cp := n as CollisionPolygon2D
		var s := Vector2.ZERO
		for p in cp.polygon: s += p
		r.append("%d|%.1f,%.1f|%.1f,%.1f" % [cp.polygon.size(), s.x, s.y,
			cp.global_position.x, cp.global_position.y])
	r.sort()
	return r

func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children(): r.append_array(_모두(c))
	return r
