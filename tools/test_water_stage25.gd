extends SceneTree
## 2-5 추가 적용은 물 크기와 밸브 연결을 보존하고 삼색·켜짐을 확인한다.
var errors := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if value:
		print("PASS ",label)
	else:
		errors += 1
		push_error(label)
func _run() -> void:
	var stage := (load("res://scenes/world_2_클로드/stage_2-5.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	for i in 40:
		await process_frame
	for n in [1,2]:
		var water: Node2D = stage.get_node("장치/흰색물_%d" % n)
		var size: Vector2 = water.get("크기")
		check(size == Vector2(192 if n==1 else 160,1024), "water %d original size" % n)
		var visual: CanvasItem = water.get_node_or_null("WhiteWaterV2")
		check(visual != null and visual.get_script().resource_path.ends_with("물_힉스필드_삼색프레임.gd"),"water %d new frames" % n)
		var outlet: Node2D = stage.get_node("장치/출수_흰색물_%d" % n)
		# 깊은 수조를 지형 안의 배수구로 교체했으므로 실제 접점과 지형 내부 범위를 검사한다.
		check(bool(outlet.get("_support_valid")),"water %d terrain contact" % n)
		var support: Rect2 = outlet.get("_support")
		check(support.size.x >= size.x and support.end.y <= 0.0,"water %d inset outlet" % n)
		for tone in [0,1,2]:
			water.set("색",tone)
			for i in 3:
				await process_frame
			var mat := visual.material as ShaderMaterial
			check(int(mat.get_shader_parameter("water_tone"))==tone,"water %d tone %d" % [n,tone])
			var inlet: CanvasItem = visual.get_node_or_null("_PipeMouth")
			check(inlet != null and inlet.material == mat,"water %d shared inlet tone %d" % [n,tone])
		water.set("색",1)
		water.set("켜짐",false)
		await process_frame
		check(not bool((visual.get_node("_PipeMouth") as CanvasItem).visible),"water %d inlet off" % n)
		water.set("켜짐",true)
		await process_frame
		check(bool((visual.get_node("_PipeMouth") as CanvasItem).visible),"water %d inlet restart" % n)
	var valve: Node = stage.get_node("장치/벨브_1")
	check(valve.get("대상_유체")==NodePath("../흰색물_1"),"valve target preserved")
	print("STAGE25_ERRORS ",errors)
	quit(0 if errors==0 else 1)
