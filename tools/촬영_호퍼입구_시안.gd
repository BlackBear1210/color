extends SceneTree
## [2026-09-30 Claude] 2-9 C_혼합호퍼 입구를 "지금" 과 "시안" 으로 찍는다. 게임 파일은 안 바꾼다.
##   G --path . -s res://tools/촬영_호퍼입구_시안.gd      (창 모드 — 그리기가 필요하다)
## 결과: user://호퍼입구_시안/<상태>_<지금|시안>_<배율>.png  (상태 = 검정만 · 흰색만 · 둘다)
## 시안 스크립트: scripts/스마트월드/호퍼_입구수면_시안.gd

const 씬 := "res://scenes/world_2_클로드/stage_2-9.tscn"
const 시안 := preload("res://scripts/스마트월드/호퍼_입구수면_시안.gd")
const 상태들 := [["검정만", true, false], ["흰색만", false, true], ["둘다", true, true]]


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://호퍼입구_시안")
	var 스테이지: Node = (load(씬) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	플레이어.global_position = Vector2(1900, 3150)   # 호퍼 오른쪽 통로(사진 속 자리)
	var 호퍼 := 스테이지.get_node("장치/C_혼합호퍼") as Node2D
	var 검정 := 스테이지.get_node("장치/C_검정공급")
	var 흰 := 스테이지.get_node("장치/C_흰공급")
	var 지금 := 호퍼.get_node("InletWaterSurface") as Node2D
	# 시안 노드: 같은 신호를 받는다. 찍을 때 둘 중 하나만 보인다.
	var 새것: Node2D = 시안.new()
	새것.name = "InletWaterSurface_시안"
	호퍼.add_child(새것)
	호퍼.connect("입구_상태_갱신", 새것.상태_받기)
	# HUD 는 사진에서 뺀다.
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	for 상태 in 상태들:
		검정.set("켜짐", 상태[1])
		흰.set("켜짐", 상태[2])
		# 흘러내림 연출(약 0.7 초)과 호퍼 끊김 유예(0.3 초)가 끝날 때까지 기다린다.
		for i in 150:
			await process_frame
		for 배율 in [1.0, 2.5]:
			카메라.zoom = Vector2(배율, 배율)
			카메라.global_position = Vector2(1536, 3200 if 배율 > 1.0 else 3180)
			카메라.reset_smoothing()
			for 판 in ["지금", "시안"]:
				# visible 은 호퍼가 매 틱 다시 켠다(상태_받기) → 투명도로 숨긴다.
				지금.modulate.a = 1.0 if 판 == "지금" else 0.0
				새것.modulate.a = 1.0 if 판 == "시안" else 0.0
				새것.set("물줄기_늘리기", 판 == "시안")   # 시안은 물줄기 그림을 수면까지 늘린다
				for i in 6:
					await process_frame
				var 파일 := "user://호퍼입구_시안/%s_%s_x%s.png" % [상태[0], 판, str(배율)]
				root.get_texture().get_image().save_png(파일)
				print("SHOT ", ProjectSettings.globalize_path(파일), " 입구색=", 새것.get("_색"))
	quit(0)
