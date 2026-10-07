extends SceneTree
## [2026-09-30 Claude] 하수도 전 스테이지의 호퍼 입구 수면 확인 — 어떤 입구 스크립트가 붙었나 · 입구색 · 사진.
##   G --path . -s res://tools/검사_호퍼입구_전스테이지.gd      (창 모드 — 사진을 찍는다)
## 결과: 콘솔 표 + user://호퍼입구_전스테이지/<스테이지>_<호퍼>.png
## 판정: 하수도 호퍼마다 InletWaterSurface 가 호퍼_입구수면_시안.gd 면 통과(입구_시안_사용 을 끈 호퍼는 예외로 표시).

const 시안_파일 := "호퍼_입구수면_시안.gd"


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://호퍼입구_전스테이지")
	var 실패 := 0
	var 합계 := 0
	for i in range(1, 12):
		var 경로 := "res://scenes/world_2_클로드/stage_2-%d.tscn" % i
		var 씬: Node = (load(경로) as PackedScene).instantiate()
		root.add_child(씬)
		for k in 150:
			await process_frame
		var 카메라: Camera2D = 씬.get("_카메라")
		if 카메라:
			카메라.set("target", null)
			카메라.zoom = Vector2(2, 2)
		var 플레이어 := 씬.get_node_or_null("Player")
		if 플레이어:
			플레이어.process_mode = Node.PROCESS_MODE_DISABLED
		for c in 씬.get_children():
			if c is CanvasLayer and c.owner == null:
				c.visible = false
		var 호퍼들: Array = []
		var 쌓기: Array[Node] = [씬]
		while not 쌓기.is_empty():
			var n: Node = 쌓기.pop_back()
			쌓기.append_array(n.get_children())
			if n.has_signal("입구_상태_갱신"):
				호퍼들.append(n)
		for 호퍼 in 호퍼들:
			합계 += 1
			var 입구: Node = (호퍼 as Node).get_node_or_null("InletWaterSurface")
			var 스크립트 := String(입구.get_script().resource_path.get_file()) if 입구 else "(없음)"
			var 켬: Variant = 호퍼.get("입구_시안_사용")
			var 통과: bool = 스크립트 == 시안_파일 or 켬 == false
			if not 통과:
				실패 += 1
			print("HOPPER %s %-24s %-8s 입구=%-26s 입구색=%s 유입=%d  %s" % [
				경로.get_file().get_basename(), 호퍼.name, String(호퍼.get_script().resource_path.get_file()).trim_suffix(".gd"),
				스크립트, str(입구.get("_색")) if 입구 else "-",
				(입구.get("_접점들") as Array).size() if 입구 else 0,
				"✔" if 통과 else "✖"])
			if 카메라 and 입구 and int(입구.get("_색")) >= 0:
				카메라.global_position = (호퍼 as Node2D).global_position + Vector2(0, -float(호퍼.get("높이")))
				카메라.reset_smoothing()
				for k in 8:
					await process_frame
				root.get_texture().get_image().save_png("user://호퍼입구_전스테이지/%s_%s.png" % [경로.get_file().get_basename(), 호퍼.name])
		씬.queue_free()
		await process_frame
	print("HOPPER 합계 %d 개 · 실패 %d" % [합계, 실패])
	quit(1 if 실패 else 0)
