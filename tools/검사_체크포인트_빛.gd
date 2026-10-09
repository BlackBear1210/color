extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 쳅터1 체크포인트가 빛(창문빛·색레이저 · 반딧불) 안에 있지 않은가
##   체크포인트 자리에서 되살아났는데 그 자리가 빛 안이면, 빛과 다른 색 몸은 되살아나자마자 또 죽는다(부활 고리).
##   10-09 Codex 가 체크포인트를 90 → 34 개로 옮긴 뒤 02 체크(81.5칸)가 깜빡이는 창문빛 안에 들어간 것을 잡았다.
##   스테이지마다 체크포인트에 검정 · 흰 몸을 각각 세워 8초 동안 "위험한가" 를 묻는다(월드 사망 판정과 같은 그룹).
##   반딧불은 정지점 반경 안이면(언젠가 비출 수 있으면) 실패로 친다.
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/검사_체크포인트_빛.gd
## ⚠ 진행 파일을 쓰지 않는다(기록_허용 = 0).
## ============================================================================
const 폴더 := "res://scenes/쳅터1/스테이지/"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	게임진행.기록_허용 = 0
	var d := DirAccess.open(폴더)
	var 파일들 := Array(d.get_files()).filter(func(f): return f.ends_with(".tscn"))
	파일들.sort()
	for f in 파일들:
		var s := (load(폴더 + f) as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		s.set_physics_process(false)          # 월드 사망 판정을 멈춰 몸이 그 자리에 그대로 있게
		var p := s.get_node("Player") as CharacterBody2D
		for i in 10:
			await physics_frame
		var 체 := s.get_node_or_null("체크포인트")
		var 자리들: Array = []
		if 체:
			for c in 체.get_children():
				자리들.append([String(c.name), (c as Node2D).global_position])
		for 자 in 자리들:
			for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
				var 위험 := {}
				for fr in 480:
					p.global_position = 자[1] + Vector2(0, -1)
					p.velocity = Vector2.ZERO
					p.set("player_color", 색)
					await physics_frame
					for n in get_nodes_in_group("색레이저") + get_nodes_in_group("색빛"):
						if s.is_ancestor_of(n) and n.has_method("위험한가") and n.call("위험한가", p):
							var k := String(s.get_path_to(n))
							위험[k] = int(위험.get(k, 0)) + 1
				# 반딧불: 지금 안 비춰도 언젠가 비출 수 있는 자리면 실패
				for n in get_nodes_in_group("광원몹"):
					if s.is_ancestor_of(n) and n.has_method("빛_닿을_수_있나"):
						for dy in [-8.0, -48.0, -88.0]:
							if n.call("빛_닿을_수_있나", 자[1] + Vector2(0, dy)):
								위험[String(s.get_path_to(n)) + "(정지점 반경)"] = 1
				if not 위험.is_empty():
					failures += 1
					print("FAIL %s %s %s 몸: 빛 안 %s" % [f.get_basename(), 자[0], "검정" if 색 == ColorDefs.BLACK else "흰", 위험])
		print("== %s 체크포인트 %d" % [f.get_basename(), 자리들.size()])
		s.queue_free()
		await process_frame
	print("\n검사_체크포인트_빛: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
