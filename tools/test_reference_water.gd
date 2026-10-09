extends SceneTree
## 적용 범위·삼색 전환·꺼짐과 재시작을 실제 인스턴스에서 확인하고 48장 움직임을 촬영한다.
var errors := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value:
		errors += 1
		push_error(label)
	else:
		print("PASS ", label)
func _run() -> void:
	for number in range(1,5):
		var stage := (load("res://scenes/world_2_클로드/stage_2-%d.tscn" % number) as PackedScene).instantiate()
		root.add_child(stage)
		for i in 40:
			await process_frame
		var waters := []
		for node in stage.get_node("장치").get_children():
			if "힉스필드_삼색프레임" in node and node.get("힉스필드_삼색프레임"):
				waters.append(node)
		check(waters.size() > 0, "stage %d frames connected" % number)
		for water in waters:
			var visual: Node = water.get_node_or_null("WhiteWaterV2")
			check(visual != null and visual.get_script().resource_path.ends_with("물_힉스필드_삼색프레임.gd"), water.name + " visual loaded")
			var size_before: Vector2 = water.get("크기")
			check(not size_before.is_zero_approx(), water.name + " size retained")
		# 호퍼에 영향을 주지 않는 독립 물 하나로 삼색·흘러내림만 검사한다.
		if number == 1:
			var water := stage.get_node("장치/W2_흰물")
			for tone in [0,1,2]:
				water.set("색",tone)
				await process_frame
				var mat := water.get_node("WhiteWaterV2").material as ShaderMaterial
				check(int(mat.get_shader_parameter("water_tone"))==tone,"color %d shader updated" % tone)
			water.set("켜짐",false)
			await process_frame
			check(not water.get("켜짐"),"water off")
			water.set("켜짐",true)
			await process_frame
			check(float(water.get("_머리")) >= 0.0,"water restart head animation")
			for i in 60:
				await process_frame
			water.set("색",1)
			var camera := stage.get("_카메라") as Camera2D
			camera.set("target",null)
			camera.zoom=Vector2.ONE
			camera.global_position=Vector2(1200,560)
			camera.reset_smoothing()
			var dir := "res://docs/visual_review/water_reference_20261008/motion/"
			DirAccess.make_dir_recursive_absolute(dir)
			for f in 48:
				for visual in stage.find_children("WhiteWaterV2","",true,false):
					visual.set("애니메이션",false)
					visual.set("위상",f/24.0)
				for i in 2:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().get_region(Rect2i(640,150,570,640)).save_png(dir+"%02d.png" % f)
		stage.queue_free()
		for i in 5:
			await process_frame
	print("REFERENCE_CHECK_ERRORS ",errors)
	quit(0 if errors==0 else 1)

