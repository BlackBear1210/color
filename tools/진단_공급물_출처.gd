extends SceneTree
## ============================================================================
## [2026-09-29] 공급 물 출처 진단 — 읽기만 한다(씬 저장 안 함).
## ----------------------------------------------------------------------------
## 실행:  Godot --headless --path . -s res://tools/진단_공급물_출처.gd -- <씬> [<씬> ...]
##
## ▣ 왜
##   작은 호퍼 위 공급 물(호퍼_유입)이 48×60 처럼 짧아 "호퍼 위 흰 컵" 으로 보였다.
##   도형님 결정: 위쪽 출처(배관)까지 늘려서 물이 떨어져 들어오게 한다.
##   늘릴 길이를 눈대중으로 정하지 않으려고, 물 윗끝 위에서 **가장 가까운 배관 끝 포트**와
##   **지형(레이어 1) 밑면**을 실제 좌표로 잰다.
##
## ▣ 출력(공급 물마다)
##   물 윗끝 y · 배관 끝(같은 x ±24 안, 물 윗끝보다 위) · 위쪽 지형 밑면 · 제안 윗끝
## ============================================================================

func _init() -> void:
	call_deferred("_go")

func _go() -> void:
	for 경로 in OS.get_cmdline_user_args():
		await _하나(경로)
	quit(0)

func _모두(n: Node, r: Array = []) -> Array:
	r.append(n)
	for c in n.get_children():
		_모두(c, r)
	return r

func _하나(경로: String) -> void:
	var 루트: Node2D = (load(경로) as PackedScene).instantiate()
	root.add_child(루트)
	for _i in 4:
		await physics_frame
	var 공간 := 루트.get_world_2d().direct_space_state
	var 포트들: Array = []
	for n in _모두(루트):
		if n is Marker2D and String(n.name).ends_with("물_포트"):
			포트들.append(n)
	print("\n=== ", 경로.get_file())
	for n in _모두(루트):
		if not (n.get("호퍼_유입") == true and n.get("크기") is Vector2):
			continue
		var 물 := n as Node2D
		var 크기: Vector2 = 물.get("크기")
		var 윗끝 := 물.global_position
		# 같은 x 에 있는 배관 끝 포트 중 물 윗끝보다 위에서 가장 가까운 것
		var 포트_y := -INF
		var 포트_이름 := "-"
		for p in 포트들:
			var g: Vector2 = (p as Marker2D).global_position
			if absf(g.x - 윗끝.x) <= 24.0 and g.y <= 윗끝.y + 1.0 and g.y > 포트_y:
				포트_y = g.y
				포트_이름 = String(p.get_parent().name) + "/" + String(p.name)
		# 위쪽 지형 밑면
		var q := PhysicsPointQueryParameters2D.new()
		q.collision_mask = 1
		var 지형_y := -INF
		var d := 2.0
		while d < 3000.0:
			q.position = 윗끝 - Vector2(0, d)
			if not 공간.intersect_point(q, 1).is_empty():
				지형_y = 윗끝.y - d
				break
			d += 2.0
		var 제안 := 포트_y if 포트_y > -INF else 지형_y
		print("  %-16s 색=%s 켜짐=%s 크기=%s 윗끝=(%d,%d) | 배관끝 %s y=%s | 지형밑면 y=%s | → 새 윗끝 y=%s (늘릴 길이 %s)" % [
			물.name, 물.get("색"), 물.get("켜짐"), 크기, int(윗끝.x), int(윗끝.y),
			포트_이름, ("-" if 포트_y == -INF else str(int(포트_y))),
			("-" if 지형_y == -INF else str(int(지형_y))),
			("-" if 제안 == -INF else str(int(제안))), ("-" if 제안 == -INF else str(int(윗끝.y - 제안)))])
	루트.queue_free()
	await process_frame
