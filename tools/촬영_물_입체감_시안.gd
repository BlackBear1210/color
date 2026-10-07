extends SceneTree
## [2026-10-01 Claude] 물 "입체감" 시안을 지금/시안 두 벌로 찍는다. 게임 파일은 안 바꾼다(실행 중에만 켠다).
##   G --path . -s res://tools/촬영_물_입체감_시안.gd      (창 모드 — 그리기가 필요하다)
## 결과: user://물_입체감_시안/<자리>_<검정|흰색|회색>_<지금|시안>.png
## 같은 자리의 물을 세 색으로 바꿔 가며 찍는다(판정·색 규칙은 건드리지 않는다 — 그림 비교용).
## 애니메이션은 멈추고 위상을 고정한다 → 지금/시안 두 장이 같은 순간이라 차이가 외관 차이뿐이다.
## 시안 구현: 흰물_디자인.gd 의 `입체감` · shaders/water_stream_reference.gdshader · sewer_pool_shallow.gdshader

const 자리들 := [
	# 이름, 씬, 카메라 중심, 바꿀 물(유체·웅덩이 노드 이름), 플레이어 자리
	["2-5_넓은물막", "res://scenes/world_2_클로드/stage_2-5.tscn", Vector2(2800, 760),
		["장치/F2A_흰길막", "장치/F2B_검정배수"], Vector2(3260, 1180)],
	["2-1_물줄기", "res://scenes/world_2_클로드/stage_2-1.tscn", Vector2(1340, 700),
		["장치/W1_회색물", "장치/W2_검정물"], Vector2(1340, 1010)],
	["2-9_웅덩이", "res://scenes/world_2_클로드/stage_2-9.tscn", Vector2(1216, 4060),
		["장치/A_낙하물받이"], Vector2(900, 4280)],
]
const 색들 := [["검정", 0], ["흰색", 1], ["회색", 2]]


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://물_입체감_시안")
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
	# HUD 는 사진에서 뺀다.
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	for 색 in 색들:
		for 경로 in 자리[3]:
			var 물 := 스테이지.get_node_or_null(경로)
			if 물 == null:
				push_warning("물 노드 없음: " + 경로)
				continue
			물.set("색", 색[1])
			# 레버로 꺼져 있는 물도 비교를 위해 켠다(실행 중에만 — 씬은 저장하지 않는다).
			물.set("켜짐", true)
		# 벽등은 카메라를 따라 0.1 초마다 생긴다. 색 바꾼 뒤 그림이 따라올 때까지 넉넉히.
		for i in 40:
			await process_frame
		for 판 in ["지금", "시안"]:
			for 그림 in _물그림들(스테이지):
				그림.set("애니메이션", false)
				그림.set("위상", 7.3)
				그림.set("입체감", 판 == "시안")
			for i in 8:
				await process_frame
			var 파일 := "user://물_입체감_시안/%s_%s_%s.png" % [자리[0], 색[0], 판]
			root.get_texture().get_image().save_png(파일)
			print("SHOT ", ProjectSettings.globalize_path(파일))
	스테이지.queue_free()
	for i in 5:
		await process_frame


## 스테이지 안의 모든 물 그림(흰물_디자인) — 유체는 WhiteWaterV2, 웅덩이는 WhitePoolV2 자식.
func _물그림들(스테이지: Node) -> Array:
	var 결과: Array = []
	for 이름 in ["WhiteWaterV2", "WhitePoolV2"]:
		결과.append_array(스테이지.find_children(이름, "", true, false))
	return 결과
