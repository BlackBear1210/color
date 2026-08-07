extends SceneTree
## [2026-07-19 도형 · 신규] 로비 진입 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_lobby_flow.gd
##
## "로비에서 버튼을 누르면 막힘 없이 인게임으로 들어가는가"를 사람 손 없이 확인:
##  1. lobby.tscn 로드 + 디오라마 조립에 스크립트 오류가 없다
##  2. 시작 버튼 press → StageTransition(잉크 와이프)이 뜬다
##  3. 와이프가 끝나면 시작 목적지 씬으로 실제로 바뀐다 + Player 조립 완료
##  4. ★로비 메뉴에 4 개 진입구가 모두 있다 (시작 / 스마트월드 / 테스트월드 / 기타)
##
## ★[2026-08-07 도형] 로비 메뉴가 재구성되면서 이 테스트도 같이 고쳤다.
##   예전에는 "시작 = world_1" 이 고정이라 씬 이름(World1)을 직접 비교했는데,
##   이제 시작 목적지가 `lobby.gd` 의 `MAIN_SCENE` 상수다. 테스트가 그 상수를
##   **직접 읽어서** 비교하도록 바꿨다 — 목적지를 또 바꿔도 테스트는 안 깨진다.

var n := 0
var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _init() -> void:
	Engine.max_fps = 60   # 프레임 수 = 시간 (와이프 0.45s+0.55s 를 프레임으로 기다리므로)
	process_frame.connect(_tick)

func _tick() -> void:
	n += 1
	match n:
		1:
			var lobby: Node = (load("res://scenes/lobby/lobby.tscn") as PackedScene).instantiate()
			root.add_child(lobby)
			# change_scene_to_file 이 이전 씬을 정리할 수 있도록 정식 현재 씬으로 등록
			current_scene = lobby
		10:
			check("1) 로비 로드 + 디오라마 조립 (Backdrop 자식 존재)",
				current_scene.get_node("Backdrop").get_child_count() > 3)

			# ★[2026-08-08] 메뉴가 **챕터표에서 자동 생성**되도록 바뀌었다.
			#   고정 버튼(시작·원본 타일맵·테스트월드·기타) + 스테이지 2 편부터의 바로가기.
			#   버튼이 하나라도 빠지면 그 라인은 게임에서 아예 갈 수 없게 된다
			#   (가장 조용히 망가지는 종류라 반드시 검사한다).
			var 메뉴 := current_scene.get_node("UILayer/Menu")
			for 버튼이름 in ["StartButton", "TileMapButton",
					"TestWorldButton", "ChapterButton"]:
				check("1-2) 메뉴에 %s 가 있다" % 버튼이름,
					메뉴.get_node_or_null(버튼이름) != null)
			# 스테이지 바로가기 — 챕터표를 읽어 기대치를 만든다(표가 늘어도 테스트가 안 깨진다)
			for 정보 in 챕터.스테이지표:
				var 번호: int = int(정보["번호"])
				if 번호 == 1:
					continue                  # 1 편은 "시작" 버튼이 담당한다
				check("1-2) 메뉴에 스마트월드_%d 바로가기가 있다" % 번호,
					메뉴.get_node_or_null("Stage%dButton" % 번호) != null)

			# 각 버튼의 목적지 씬이 실제로 존재하는지 (경로 오타 방지)
			var 로비스크립트 := (load("res://scenes/lobby/lobby.gd") as GDScript)
			for 키 in ["MAIN_SCENE", "스마트월드_SCENE", "테스트월드_SCENE", "CHAPTER_SCENE"]:
				var 경로: String = 로비스크립트.get(키)
				check("1-3) %s 목적지 씬이 존재한다 (%s)" % [키, 경로.get_file()],
					ResourceLoader.exists(경로))
			for 정보2 in 챕터.스테이지표:
				var 경로2 := 챕터.씬경로(int(정보2["번호"]))
				check("1-3) 챕터표 목적지가 존재한다 (%s)" % 경로2.get_file(),
					ResourceLoader.exists(경로2))

			# 시작 버튼을 코드로 누른다 (마우스 시뮬레이션 대신 시그널 직접 발신)
			var btn := current_scene.get_node("UILayer/Menu/StartButton") as BaseButton
			btn.pressed.emit()
		15:
			var wipe_found := false
			for c in root.get_children():
				if c is StageTransition:
					wipe_found = true
			check("2) 시작 press → 잉크 와이프(StageTransition) 발동", wipe_found)
		110:
			# 덮기 0.45s(27f) + 씬 교체 + 걷히기 0.55s(33f) ≈ 65f — 여유를 두고 110f 에 검사
			# 목적지를 lobby.gd 의 상수에서 직접 읽어 비교한다 (하드코딩하지 않는다)
			# ★[2026-08-08] 시작 목적지가 타일맵 씬 → **스마트월드 1 편**으로 바뀌었다.
			#   (같은 레벨이 두 군데서 굴러가지 않도록 타일맵은 "원본 대조용" 으로 내렸다)
			var 기대경로: String = (load("res://scenes/lobby/lobby.gd") as GDScript).get("스마트월드_SCENE")
			check("3) 시작 목적지 씬으로 바뀌었다 (%s)" % 기대경로.get_file(),
				current_scene != null and current_scene.scene_file_path == 기대경로)
			# 스마트월드는 카메라를 런타임에 "카메라" 라는 이름으로 붙인다(월드.gd).
			# 예전 타일맵 스테이지는 "ProtoCamera" 였다 — 둘 중 하나면 통과로 본다.
			var 캠 := current_scene.get_node_or_null("카메라")
			if 캠 == null:
				캠 = current_scene.get_node_or_null("ProtoCamera")
			check("3-2) Player·카메라 조립 완료",
				current_scene.get_node_or_null("Player") != null and 캠 != null)
			# ★[2026-08-07] 시작 스테이지에 카메라 구역 연출이 살아 있는지.
			#   구역이 0 개면 씬 저장 때 owner 를 안 준 것이다(실제로 한 번 겪음).
			var 연출 := current_scene.get_node_or_null("카메라연출")
			if 연출:
				check("4) 카메라 구역이 2 개 이상 살아 있다 (현재 %d)" % 연출.구역수(),
					연출.구역수() >= 2)
			else:
				print("SKIP  4) 이 스테이지에는 카메라 구역 연출이 없다")
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			quit(1 if fails > 0 else 0)
