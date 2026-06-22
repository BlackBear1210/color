extends SceneTree
## ▼ 2026-06-22 (임시 측정도구): stage_2 의 '실제 지형 충돌 영역' 글로벌 AABB 를 계산해 출력한다.
## 카메라 한계(camera_limit_*), 좌/우 벽, 배경 커버 범위를 '정확히 지형에만' 맞추기 위한 수치 산출용.
## 실행: <godot> --headless --path <proj> -s res://tools/measure_stage2_bounds.gd

func _init() -> void:
	var packed: PackedScene = load("res://scenes/world_1/stage_2/stage_2.tscn")
	var root: Node = packed.instantiate()

	var has_any := false
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	# MapPhysics 와 Obstacles 아래의 모든 CollisionPolygon2D / CollisionShape2D 를 훑어 글로벌 AABB 누적
	for n in _all_nodes(root):
		# 좌우 벽(MapBounds)·KillZone 은 '지형'이 아니므로 제외
		var path := str(root.get_path_to(n))
		if path.find("MapBounds") != -1 or path.find("KillZone") != -1:
			continue
		if n is CollisionPolygon2D:
			var xf := (n as CollisionPolygon2D).get_global_transform()
			for p in (n as CollisionPolygon2D).polygon:
				var g: Vector2 = xf * p
				min_x = min(min_x, g.x); min_y = min(min_y, g.y)
				max_x = max(max_x, g.x); max_y = max(max_y, g.y)
				has_any = true

	print("=== stage_2 지형 충돌 AABB (글로벌) ===")
	if has_any:
		print("min_x=", roundi(min_x), " max_x=", roundi(max_x), " width=", roundi(max_x - min_x))
		print("min_y=", roundi(min_y), " max_y=", roundi(max_y), " height=", roundi(max_y - min_y))
	else:
		print("폴리곤을 찾지 못했습니다.")

	# 참고: 플레이어 시작/포탈 위치도 출력
	var player := root.find_child("Player", true, false)
	if player:
		print("Player.position=", player.position)

	root.free()
	quit()

func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out
