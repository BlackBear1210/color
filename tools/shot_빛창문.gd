extends SceneTree
## ============================================================================
## [2026-08-18 신규] 빛창문 연출 확인용 캡처 (창모드 실행 필요 — 헤드리스는 렌더 안 됨)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --path . -s res://tools/shot_빛창문.gd
##
## ▣ 왜 `screenshot_scene.gd` 로 안 되나
##   그 도구는 씬을 열고 플레이어만 옮긴다. 그런데 이 장치의 핵심 그림은
##   **창을 칠한 뒤**의 모습(커튼이 쳐지고 빛이 물들어 굳은 상태)이다.
##   플레이 없이 그 상태를 만들려면 `명중()` 을 코드로 불러야 한다.
##   ★2026-08-18 에 `screenshot_scene.gd` 로 지붕을 찍었더니 플레이어가 흰 빛에 닿아
##     죽고 입구로 리스폰돼 엉뚱한 곳이 찍혔다. 여기서는 플레이어 색도 같이 맞춘다.
##
## ▣ 남기는 그림 (tools/_shots/)
##   거실_창_전.png  / 거실_창_후.png   — 칠하기 전후 (빛이 굳어 다리가 되는 순간)
##   지붕_흰빛.png   / 지붕_검은빛.png  — 경계 빛 두 종류
## ============================================================================

const 저장폴더 := "tools/_shots/"

var _n := 0
var _단계 := 0
var _씬: Node = null
var _할일: Array = []


func _init() -> void:
	Engine.max_fps = 60
	_할일 = [
		# [씬, 파일명, 플레이어 위치, 플레이어 색, 칠할 창 이름, 칠할 색]
		["스마트월드_5", "거실_창_전", Vector2(2600, 640), ColorDefs.BLACK, "", -1],
		["스마트월드_5", "거실_창_후", Vector2(3200, 620), ColorDefs.BLACK, "창문_거실", ColorDefs.BLACK],
		# ★[2026-08-19] 굴뚝 — 은은한 안개빛(꼭대기)과 벽 구멍 경계 빛 확인용
		["스마트월드_6", "굴뚝_꼭대기빛", Vector2(490, -3200), ColorDefs.BLACK, "", -1],
		["스마트월드_6", "굴뚝_벽구멍", Vector2(490, -700), ColorDefs.BLACK, "", -1],
		["스마트월드_7", "지붕_흰빛", Vector2(900, 640), ColorDefs.WHITE, "", -1],
		["스마트월드_7", "지붕_검은빛", Vector2(2200, 640), ColorDefs.BLACK, "", -1],
		["스마트월드_7", "지붕_창_후", Vector2(4500, 60), ColorDefs.WHITE, "창문_지붕", ColorDefs.WHITE],
	]
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	# 한 장당 90 프레임(=1.5초). 카메라 리밋 트윈(1.1초)과 커튼 닫힘(0.65초)이 끝난 뒤 찍는다.
	var 주기 := 90
	var 안 := _n % 주기

	if 안 == 1:
		if _단계 >= _할일.size():
			quit(0)
			return
		var 일: Array = _할일[_단계]
		if _씬:
			_씬.queue_free()
			_씬 = null
		_씬 = (load("res://scenes/스마트월드/%s.tscn" % 일[0]) as PackedScene).instantiate()
		root.add_child(_씬)
	elif 안 == 12:
		var 일: Array = _할일[_단계]
		# ★월드의 자동 리스폰을 끈다 — 안 그러면 경계 빛에 닿아 죽고 입구로 되돌아간다.
		_씬.set_physics_process(false)
		var p := _씬.get_node_or_null("Player") as Node2D
		if p:
			p.set("velocity", Vector2.ZERO)
			p.global_position = 일[2]
			p.set("player_color", 일[3])
			var cam := _씬.get_node_or_null("카메라")
			if cam and cam.has_method("setup"):
				cam.call("setup", p)
		# 창 칠하기 — 실제 총알 대신 `명중()` 을 직접 부른다(결과는 완전히 같다).
		if String(일[4]) != "":
			var 창 := _찾기(_씬, String(일[4]))
			if 창 and 창.has_method("명중"):
				창.명중(int(일[5]), (창 as Node2D).global_position)
			else:
				push_warning("창을 못 찾음: %s" % 일[4])
	elif 안 == 0:
		var 일: Array = _할일[_단계]
		var 경로 := "%s2026-08-18_%s.png" % [저장폴더, 일[1]]
		var err := root.get_viewport().get_texture().get_image().save_png(경로)
		print("shot: %s -> %s" % [error_string(err), 경로])
		_단계 += 1


func _찾기(노드: Node, 이름: String) -> Node:
	if 노드.name == 이름:
		return 노드
	for c in 노드.get_children():
		var r := _찾기(c, 이름)
		if r:
			return r
	return null
