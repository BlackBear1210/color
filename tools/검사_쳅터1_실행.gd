extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 쳅터1 모든 스테이지 "돌려 보기" — 오류 없이 도는지(스모크 시험)
##   스테이지마다 씬을 진짜로 띄우고(current_scene) 약 12초 동안 플레이어를 시작 → 체크포인트들 → 길목 앞으로
##   차례로 옮겨 가며 그 둘레의 기믹(반딧불·거미·레버·양초·빛받이·누름계단 …)이 실제로 돌게 한다.
##   Godot 가 찍는 오류(SCRIPT ERROR · ERROR)는 스테이지 머리줄 "== <이름>" 아래에 찍히므로 그 사이를 세면 된다.
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/검사_쳅터1_실행.gd 2>&1 | python tools/쳅터1/오류_세기.py
##   (또는 그냥 출력에서 "== " 머리줄 사이의 ERROR 를 본다)
## ============================================================================
const C := 32.0


func _initialize() -> void:
	call_deferred("run")


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func run() -> void:
	var d := DirAccess.open("res://scenes/쳅터1/스테이지/")
	var 파일들 := Array(d.get_files()).filter(func(f): return f.ends_with(".tscn"))
	파일들.sort()
	for f in 파일들:
		print("== ", f.get_basename())
		var s := (load("res://scenes/쳅터1/스테이지/" + f) as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		await wait(30)
		var p := s.get_node_or_null("Player") as CharacterBody2D
		var 자리들: Array = []
		if p:
			자리들.append(p.global_position)
		for c in s.find_children("체크*", "", true, false):
			if c is Node2D:
				자리들.append((c as Node2D).global_position + Vector2(0, -4))
		var 연결 := s.get_node_or_null("연결")
		if 연결:
			연결.process_mode = Node.PROCESS_MODE_DISABLED       # 길목 전환은 시험_연결전환 이 따로 본다
			for g in 연결.get_children():
				if g is Node2D:
					자리들.append((g as Node2D).global_position + Vector2(-float(g.get("방향")) * 160.0, -4))
		var 한자리 := maxi(int(720.0 / maxf(자리들.size(), 1.0)), 30)
		for 자리 in 자리들:
			if p and is_instance_valid(p):
				p.global_position = 자리
				p.velocity = Vector2.ZERO
			await wait(한자리)
		print("   끝 ", f.get_basename(), " · 자리 ", 자리들.size())
		s.queue_free()
		await process_frame
		await process_frame
	print("== 끝")
	quit()
