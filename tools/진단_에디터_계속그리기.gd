extends SceneTree
## [2026-09-30 Claude] "에디터가 가만히 있어도 GPU 를 쓰나" 를 게임 창에서 재현한다.
##
## 에디터는 저전력 모드(low_processor_usage_mode)라 **무언가 바뀔 때만** 화면을 다시 그린다.
## 그런데 TIME 을 쓰는 셰이더가 화면에 있거나 _process 에서 매 프레임 queue_redraw 하면
## 에디터가 쉬지 않고 다시 그리고, F5 로 켠 게임과 GPU 를 나눠 쓰게 된다(2026-09-30 실측: 에디터 혼자 3D 엔진 41%).
##
## 여기서는 같은 저전력 모드를 켜고 씬의 **스크립트를 전부 멈춘 채**(= 에디터에서 @tool 이 아닌 스크립트가 쉬는 것과 비슷)
## 2 초 동안 실제로 그린 프레임 수를 센다. 0 에 가까워야 정상이다.
##   G -s res://tools/진단_에디터_계속그리기.gd -- [씬경로...]
## ⚠ @tool 스크립트의 에디터 경로(_process 안 editor_hint 분기)는 여기서 안 돈다 — 그건 정적으로 본다
##   (tools/test_에디터_계속그리기.py).

## 주석을 뺀 코드에 TIME 이라는 낱말이 있나(주석 속 설명 글은 엔진이 안 본다).
static func _시간_씀(코드: String) -> bool:
	var 정규 := RegEx.create_from_string("(?s)/\\*.*?\\*/|//[^\\n]*")
	var 본문 := 정규.sub(코드, "", true)
	return RegEx.create_from_string("\\bTIME\\b").search(본문) != null


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 대상: Array = []
	for a in OS.get_cmdline_user_args():
		if not String(a).begins_with("--"):
			대상.append(String(a))
	if 대상.is_empty():
		for i in range(1, 12):
			대상.append("res://scenes/world_2_클로드/stage_2-%d.tscn" % i)
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	for 경로 in 대상:
		var 씬: Node = (load(경로) as PackedScene).instantiate()
		root.add_child(씬)
		# 스크립트 쪽 갱신을 전부 멈춘다 — 남는 다시그리기는 셰이더(TIME)나 엔진 쪽이다.
		for i in 10:
			await process_frame
		# 게임 중에만 붙는 HUD(월드.gd 가 만드는 CanvasLayer)는 에디터 씬에 없다 → 떼고 잰다.
		for c in 씬.get_children():
			if c is CanvasLayer and c.owner == null:
				c.queue_free()
		# 아직 TIME 을 읽는 그림이 있으면 이름을 찍는다 — 다시 계속 그리게 되면 여기서 범인이 보인다.
		var 쌓기: Array[Node] = [씬]
		while not 쌓기.is_empty():
			var n: Node = 쌓기.pop_back()
			쌓기.append_array(n.get_children())
			var m: Material = (n as CanvasItem).material if n is CanvasItem else null
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null \
					and _시간_씀((m as ShaderMaterial).shader.code) and (n as CanvasItem).is_visible_in_tree():
				print("    TIME 셰이더: %s (%s)" % [씬.get_path_to(n), (m as ShaderMaterial).shader.resource_path.get_file()])
		씬.process_mode = Node.PROCESS_MODE_DISABLED
		for i in 10:
			await process_frame
		var 시작 := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2000:
			await process_frame
		var 그림 := Engine.get_frames_drawn() - 시작
		print("REDRAW %-14s 2초 동안 그린 프레임 %4d  (%s)" % [
			경로.get_file().get_basename(), 그림, "계속 그림 ✖" if 그림 > 10 else "쉼 ✔"])
		씬.queue_free()
		await process_frame
	quit(0)
