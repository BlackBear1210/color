extends SceneTree
## 실제 게임 렌더러로 같은 위치·1920×1080·줌 1.0의 전후 PNG를 남긴다.
## 진행 파일을 바꾸지 않고 모든 방의 입구와 수정한 퍼즐 구간을 별도로 확인한다.
const STAGES := "res://scenes/쳅터1/스테이지/"
const PLANS := "res://scenes/쳅터1/도안/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	게임진행.기록_허용 = 0
	var phase := "after"
	var only_stage := ""
	var source_prefix := STAGES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--stage="):
			only_stage = arg.trim_prefix("--stage=")
		# 백업 씬을 직접 읽어 현재 작업을 되돌리지 않고 동일한 구간의 수정 전 화면을 재확인한다.
		if arg.begins_with("--source-prefix="):
			source_prefix = arg.trim_prefix("--source-prefix=")
	var out := "res://tools/_진단/챕터1_재검토_20261010/%s/화면/" % phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1920, 1080)
	var entries: Array = []
	for file in DirAccess.get_files_at(PLANS):
		if file.ends_with(".json") and file.begins_with("쳅터1_"):
			var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLANS + file))
			var start: Array = plan["시작"]
			entries.append([file.get_basename(), "입구", Vector2(float(start[0]) + 0.5, float(start[1]))])
	entries.append_array([
		["쳅터1_01_방_시작방", "첫흰빛", Vector2(56, 49)],
		["쳅터1_01_방_시작방", "회복마루", Vector2(80, 49)],
		["쳅터1_03_방_서재", "달빛선반", Vector2(75, 56)],
		["쳅터1_07_방_수납실", "유령다리", Vector2(24, 22)],
		["쳅터1_09_계단_중앙", "층계참", Vector2(44, 61)],
		["쳅터1_11_거실", "첫거미", Vector2(143, 65)],
		["쳅터1_13_복도_G", "색도약대", Vector2(106, 31)],
		["쳅터1_14_굴뚝", "도약착지", Vector2(25, 100)],
	])
	for entry in entries:
		if not only_stage.is_empty() and String(entry[0]) != only_stage:
			continue
		var scene := (load(source_prefix + String(entry[0]) + ".tscn") as PackedScene).instantiate()
		root.add_child(scene)
		current_scene = scene
		# 사망·부활로 촬영 위치가 달라지지 않게 판정과 입력만 멈추고 기믹은 그대로 그린다.
		scene.set_physics_process(false)
		var player := scene.get_node("Player") as CharacterBody2D
		player.set_physics_process(false)
		player.global_position = entry[2] * 32.0
		player.set("player_color", ColorDefs.BLACK)
		for frame in 80:
			await physics_frame
		for node in scene.find_children("*", "Camera2D", true, false):
			var camera := node as Camera2D
			camera.zoom = Vector2.ONE
			camera.reset_smoothing()
			camera.force_update_scroll()
			# 새 층계참 위에 생존 가능한 흰 몸을 놓되 카메라 비교 위치는 수정 전과 동일하게 유지한다.
			if phase == "after" and String(entry[1]) == "층계참":
				camera.set_process(false)
				camera.set_physics_process(false)
		if phase == "after" and String(entry[1]) == "층계참":
			player.global_position.y = 58 * 32.0
			player.set("player_color", ColorDefs.WHITE)
		await RenderingServer.frame_post_draw
		var path := out + "%s_%s.png" % [entry[0], entry[1]]
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
		scene.queue_free()
		await process_frame
	quit()
