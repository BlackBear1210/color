extends SceneTree
## [2026-10-01 Claude] 하수도 물줄기 "자연물"(세 색)을 지금/시안으로 찍는다. 게임 파일은 안 바꾼다.
##   G --path . -s res://tools/촬영_흰물_자연_시안.gd -- --색=0,2 --지금은한장
##   G --path . -s res://tools/촬영_흰물_자연_시안.gd      (창 모드)
## 결과: user://흰물_자연_시안/<자리>_<지금|시안>_f<번호>.png — 60fps · 2 초(움직임 비교용)
## 시간은 애니메이션을 끄고 위상을 1/60 초씩 넘겨 만든다 → 찍는 속도와 상관없이 실제 재생 속도와 같다.

const 자리들 := [
	["2-1_물줄기", "res://scenes/world_2_클로드/stage_2-1.tscn", Vector2(1340, 700),
		["장치/W1_회색물", "장치/W2_검정물"], Vector2(1340, 1010)],
	["2-5_넓은물막", "res://scenes/world_2_클로드/stage_2-5.tscn", Vector2(2800, 760),
		["장치/F2A_흰길막"], Vector2(3260, 1180)],
]
## 60fps · 2 초. 30fps 로는 빠른 낙하가 프레임 사이에서 끊겨 보였다(도형님 지적).
const 프레임 := 120
const 초당 := 60.0


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://흰물_자연_시안")
	for 자리 in 자리들:
		await _자리_찍기(자리)
	quit(0)


func _자리_찍기(자리: Array) -> void:
	var 스테이지: Node = (load(자리[1]) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	플레이어.global_position = 자리[4]
	카메라.zoom = Vector2.ONE
	카메라.global_position = 자리[2]
	카메라.reset_smoothing()
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	# `-- --색=0,2` 처럼 색을 고른다(0 검정 · 1 흰 · 2 회색). 없으면 흰색만(예전 결과 파일 이름 유지).
	var 색들 := [1]
	for 인자 in OS.get_cmdline_user_args():
		if 인자.begins_with("--색="):
			색들 = []
			for 조각 in 인자.trim_prefix("--색=").split(","):
				색들.append(int(조각))
	var 색이름 := {0: "검정", 1: "흰색", 2: "회색"}
	for 색 in 색들:
		for 경로 in 자리[3]:
			var 물 := 스테이지.get_node_or_null(경로)
			if 물 == null:
				push_warning("물 노드 없음: " + 경로)
				continue
			물.set("색", 색)
			물.set("켜짐", true)
		for i in 40:
			await process_frame
		# 흰색만 찍을 때는 예전 이름 그대로, 색을 고르면 이름에 색이 붙는다.
		var 이름: String = 자리[0] if 색들 == [1] else "%s_%s" % [자리[0], 색이름[색]]
		for 판 in ["지금", "시안"]:
			# `-- --빠르게` 면 4 장만(셰이더 다듬을 때). `-- --지금은한장` 이면 지금 판은 정지 1 장만.
			var 장수 := 4 if "--빠르게" in OS.get_cmdline_user_args() else 프레임
			if 판 == "지금" and "--지금은한장" in OS.get_cmdline_user_args():
				장수 = 1
			for f in 장수:
				for 그림 in 스테이지.find_children("WhiteWaterV2", "", true, false):
					그림.set("애니메이션", false)
					그림.set("위상", 7.3 + f / 초당)
					그림.set("자연물", 판 == "시안")
				for i in 3:
					await process_frame
				var 파일 := "user://흰물_자연_시안/%s_%s_f%02d.png" % [이름, 판, f]
				root.get_texture().get_image().save_png(파일)
			print("SHOT ", 이름, " ", 판)
	스테이지.queue_free()
	for i in 5:
		await process_frame
