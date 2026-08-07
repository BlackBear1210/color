extends SceneTree
## ============================================================================
## [2026-08-02 신규] ESC 일시정지 메뉴 확인
## ----------------------------------------------------------------------------
## 실행:
##   Godot --path . -s res://tools/shot_메뉴_확인.gd -- <저장.png> [밝기]
##
## ▣ 검사 내용
##   1. ESC(ui_cancel) 입력으로 메뉴가 열리는가
##   2. 열리면 트리가 실제로 멈추는가(get_tree().paused)
##   3. 설정 패널이 펼쳐지고 밝기 슬라이더가 CanvasModulate 에 반영되는가
##   4. 로비 씬 경로가 실제로 존재하는가 (없으면 "로비로 돌아가기"가 죽는다)
## ============================================================================

const 씬 := "res://scenes/스마트월드/_원본/원본_숲_코드생성.tscn"

var _n := 0
var _루트: Node
var _메뉴: Node


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		_루트 = (load(씬) as PackedScene).instantiate()
		root.add_child(_루트)
	elif _n == 6:
		_메뉴 = _루트.get_node_or_null("일시정지메뉴")
		if _메뉴 == null:
			push_error("일시정지메뉴 노드가 없다 — 월드.gd 의 _메뉴_만들기() 확인")
			quit(1)
			return
		# 실제 입력과 같은 경로로 연다 (ESC 키 이벤트를 만들어 넣는다)
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
	elif _n == 10:
		print("메뉴 열림 = %s (기대 true)" % str(_메뉴.visible))
		print("트리 일시정지 = %s (기대 true)" % str(paused))
		print("로비 씬 존재 = %s (기대 true)" % str(ResourceLoader.exists(일시정지메뉴.로비_경로)))
		# 설정 패널을 펼치고 밝기를 바꿔본다
		_메뉴._설정_토글()
		var 밝기 := float(args[1]) if args.size() >= 2 else 0.55
		_메뉴._밝기_바뀜(밝기)
		var 어둠 := _루트.get_node_or_null("어둠") as CanvasModulate
		print("밝기 %.2f 적용 → CanvasModulate = %s" % [밝기, str(어둠.color) if 어둠 else "없음"])
	elif _n == 26:
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[0])
		print("shot: %s -> %s" % [error_string(err), args[0]])
		# 다음 실행에 영향이 없도록 밝기를 100% 로 되돌려 저장한다
		게임설정.밝기_저장(1.0)
		quit(0 if err == OK else 1)
