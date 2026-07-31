extends SceneTree
## [2026-07-19 도형 · 신규] 로비 → world_1 진입 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_lobby_flow.gd
##
## "로비에서 시작을 누르면 막힘 없이 인게임으로 들어가는가"를 사람 손 없이 확인:
##  1. lobby.tscn 로드 + 디오라마 조립에 스크립트 오류가 없다
##  2. 시작 버튼 press → StageTransition(잉크 와이프)이 뜬다
##  3. 와이프가 끝나면 현재 씬 = World1 (world_1.tscn) + Player/카메라 조립 완료
##  4. world_1 시작 구역 = 1 (로비에서 들어온 직후 상태 정상)

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
			check("3) 현재 씬 = World1", current_scene != null and current_scene.name == "World1")
			check("3) Player·ProtoCamera 조립 완료",
				current_scene.get_node_or_null("Player") != null
				and current_scene.get_node_or_null("ProtoCamera") != null)
			check("4) 시작 구역 = 1", current_scene.get("_region") == 1)
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			quit(1 if fails > 0 else 0)
