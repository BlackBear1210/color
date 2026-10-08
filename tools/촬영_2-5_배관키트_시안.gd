extends SceneTree
## [2026-09-30 Claude] 2-5 밸브 연결선(배관_안내 Line2D 5 개)을 회색 배관 SS2D 키트로 바꿨을 때를 찍는다.
##   게임 파일은 안 바꾼다 — 실행 중에만 Line2D 를 숨기고 같은 경로에 키트를 놓는다.
##   굵기 두 벌: 키트 기본(texture_scale 0.22 ≈ 69px) · 얇게(0.10 ≈ 31px, 밸브 축 18px 에 가깝게).
##   G --path . -s res://tools/촬영_2-5_배관키트_시안.gd      (창 모드)
## 결과: user://2-5_배관키트_시안/*.png

const 씬 := "res://scenes/world_2_클로드/stage_2-5.tscn"
const 키트 := "res://scenes/집/스마트 매쉬 assets/PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn"
const 폴더 := "user://2-5_배관키트_시안"
const 자리들 := [["첫밸브", Vector2(1080, 690)], ["갈래", Vector2(2560, 560)]]


func _initialize() -> void:
	call_deferred("_실행")


func _배관들(스테이지: Node, 배율: float) -> Node2D:
	var 묶음 := Node2D.new()
	묶음.z_index = -1
	스테이지.add_child(묶음)
	for 선 in 스테이지.get_node("배관_안내").get_children():
		var 관 := (load(키트) as PackedScene).instantiate() as Node2D
		관.set("끝마개_배율", 배율)
		묶음.add_child(관)
		var 경로 := 관.get_node("경로")
		var 재질: Resource = 경로.get("shape_material").duplicate(true)
		for meta in 재질.get("_edge_meta_materials"):
			meta.edge_material.texture_scale = 배율
		경로.set("shape_material", 재질)
		경로.call("clear_points")
		for p in (선 as Line2D).points:
			경로.call("add_point", p)
	return 묶음


## [2026-09-30] 새 주철 배관(하수도_주철배관.gd) 판 — 같은 경로를 그대로 준다.
func _주철관들(스테이지: Node) -> Node2D:
	var 묶음 := Node2D.new()
	묶음.z_index = -1
	스테이지.add_child(묶음)
	for 선 in 스테이지.get_node("배관_안내").get_children():
		var 관 := Node2D.new()
		관.set_script(load("res://scripts/스마트월드/하수도_주철배관.gd"))
		# Line2D 는 밸브 중심 56 위(1000)에서 끝나 밸브 축(중심 −32)과 24 틈이 났다 → 세로로 올라가는 관은 축 끝까지 내린다
		var 점 := (선 as Line2D).points
		if 점.size() > 1 and is_equal_approx(점[0].x, 점[1].x) and 점[0].y > 점[1].y and is_equal_approx(fmod(점[0].y, 8.0), 0.0) and int(점[0].y) % 1000 == 0:
			점[0].y += 24.0
		관.set("점들", 점)
		묶음.add_child(관)
	return 묶음


## [2026-09-30] 연결 판 — 관 양끝을 장치 포트(레버·밸브)와 물 윗면에 붙인다(`시작_장치`/`끝_장치`).
##   B분기는 A분기 위의 분기점에서 시작하므로 장치가 없다 → 분기점 y 만 레버 포트 줄에 맞추고 플랜지 없이.
const 연결표 := {
	"첫밸브": ["L1_원형_첫밸브", "F1_첫길막_흰물"],
	"상부출구연결": ["L3_원형_양자택일", "F3_두번째길막"],
	"A분기": ["L2_직선_갈래선택", "F2A_흰길막"],
	"B분기": ["", "F2B_검정배수"],
	"사격수문": ["L4_원형_반대색건너", "F4_레버앞_흰물"],
}

func _연결관들(스테이지: Node) -> Node2D:
	var 묶음 := Node2D.new()
	묶음.z_index = -1
	스테이지.add_child(묶음)
	var 레버포트y := 0.0
	var 레버 := 스테이지.get_node("장치/L2_직선_갈래선택")
	레버포트y = (레버.call("배관_포트")["위치"] as Vector2).y
	for 선 in 스테이지.get_node("배관_안내").get_children():
		var 관 := Node2D.new()
		관.set_script(load("res://scripts/스마트월드/하수도_주철배관.gd"))
		묶음.add_child(관)
		var 점 := (선 as Line2D).points
		var 짝: Array = 연결표[String(선.name)]
		if 짝[0] == "":
			점[0].y = 레버포트y
			관.set("시작_플랜지", false)
		관.set("점들", 점)
		if 짝[0] != "":
			관.set("시작_장치", NodePath("../../장치/" + 짝[0]))
		관.set("끝_장치", NodePath("../../장치/" + 짝[1]))
	return 묶음


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute(폴더)
	var 스테이지: Node = (load(씬) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	(스테이지.get_node("Player") as Node2D).global_position = Vector2(760, 1050)
	for 판 in [["주철", -1.0], ["주철_연결", -2.0]]:
		var 묶음: Node2D = null
		(스테이지.get_node("배관_안내") as Node2D).visible = 판[1] == 0.0
		for 레 in 스테이지.get_node("장치").get_children():
			if "배관_연결됨" in 레:
				레.set("배관_연결됨", false)
		if 판[1] > 0.0:
			묶음 = _배관들(스테이지, 판[1])
		elif 판[1] == -1.0:
			묶음 = _주철관들(스테이지)
		else:
			묶음 = _연결관들(스테이지)
		for i in 10:
			await process_frame
		for 자리 in 자리들:
			카메라.zoom = Vector2.ONE
			카메라.global_position = 자리[1]
			카메라.reset_smoothing()
			for i in 8:
				await process_frame
			var 파일 := "%s/%s_%s.png" % [폴더, 자리[0], 판[0]]
			root.get_texture().get_image().save_png(파일)
			print("SHOT ", ProjectSettings.globalize_path(파일))
		if 묶음:
			묶음.queue_free()
	quit(0)
