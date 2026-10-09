extends SceneTree
## [2026-10-09 Claude] 15(집 밖) 씬을 여러 번 열고 지운다 — 실행 중 만든 목재 판(튀어나오는판)이 해제 때 엔진을 죽이지 않나
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for i in 8:
		var s = (load("res://scenes/쳅터1/스테이지/쳅터1_15_집밖_하수도길.tscn") as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		for k in 20: await physics_frame
		s.queue_free()
		for k in 3: await process_frame
		print("반복 ", i)
	print("끝 — 지우기 8번 무사")
	quit()
