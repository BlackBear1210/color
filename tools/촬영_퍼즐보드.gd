extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 스테이지 선택(사진 지도) 화면 촬영 — 저장 파일은 읽기만 한다
##   도형님 10-09 "스테이지 선택을 하려는데 안 보여" → 제목 붓칠이 원화 크기(2172×724)로 커져 카드를 덮던 것 확인용.
##   `기록_허용 = 0` 이라 진행.cfg · completed_runs.cfg 를 절대 쓰지 않는다(10-09 덮어쓰기 사고 재발 방지).
## 실행(창 모드여야 찍힌다): Godot_console --fixed-fps 60 --path . -s res://tools/촬영_퍼즐보드.gd -- [--쳅터=2] [--예시]
##   → tools/_진단/퍼즐보드/보드_쳅터N.png
##   --예시 [10-10]: 열쇠 표시 상태를 보려고 **메모리에만** 진행을 꾸민다(01~04·06 클리어 · 04 문 열림 · 05 검정 조각만 · 08 열림 0/2).
##     기록_허용 = 0 이라 파일에는 절대 안 써진다.
## ============================================================================
const OUT := "res://tools/_진단/퍼즐보드/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	게임진행.기록_허용 = 0
	var 쳅터 := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--쳅터="):
			쳅터 = int(a.split("=")[1])
	게임진행.선택_쳅터 = 쳅터
	var 예시 := OS.get_cmdline_user_args().has("--예시")
	if 예시:
		var 폴 := "res://scenes/쳅터1/스테이지/"
		var cfg: ConfigFile = 게임진행._설정()
		for n in ["쳅터1_01_방_시작방", "쳅터1_02_복도_A", "쳅터1_03_방_서재", "쳅터1_16_복도_썩은마루", "쳅터1_04_복도_B", "쳅터1_06_복도_C"]:
			cfg.set_value("쳅터1클리어", 폴 + n + ".tscn", true)
			cfg.set_value("보드", "본_" + 폴 + n + ".tscn", true)   # 채움 연출 건너뛰기(메모리만)
		for k in ["#왼쪽", "#오른쪽", "#문"]:
			cfg.set_value("열쇠", 폴 + "쳅터1_04_복도_B.tscn" + k, true)
		cfg.set_value("열쇠", 폴 + "쳅터1_05_방_침실.tscn#왼쪽", true)
		게임진행.마지막_조각 = "08"
	root.size = Vector2i(1920, 1080)
	var s := (load(게임진행.보드_씬) as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	for i in 90:                      # 1.5 초 — 돌아옴 연출(채움·도장)이 끝나게
		await process_frame
	# 덮개 점검: 카드보다 앞에 그려지는 큰 그림이 있으면 이름과 크기를 찍는다
	var 캔버스: Control = s.get_node("화면")
	var 첫카드 := -1
	for c in 캔버스.get_children():
		if String(c.name).begins_with("조각_"):
			첫카드 = c.get_index()
			break
	for c in 캔버스.get_children():
		if c is TextureRect and c.get_index() > 첫카드 and (c.size.x > 700 or c.size.y > 300):
			print("FAIL 카드를 덮는 그림: ", c.name, " ", c.size)
	print("카드 수 ", s.get("_조각들").size())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		var 파일 := "보드_쳅터%d%s.png" % [쳅터, "_열쇠예시" if 예시 else ""]
		root.get_texture().get_image().save_png(OUT + 파일)
		print("저장 ", OUT + 파일)
	quit()
