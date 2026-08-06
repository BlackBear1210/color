extends SceneTree
## [2026-07-18 도형 · 신규] 범용 씬 캡처 도구 (창모드 실행 필요 — 헤드리스는 렌더 안 됨).
## 실행: Godot --path . -s res://tools/screenshot_scene.gd -- <씬경로> <저장.png> [플레이어x] [플레이어y]
## 예: ... -- res://scenes/world_1/world_1.tscn shot.png 1700 440
## 플레이어 좌표를 주면 캡처 전에 그 위치로 옮긴다 (구역별 화면 확인용).
## 씬 로드 후 40프레임 안정화(카메라 스냅·라이트·배경 로드)를 기다렸다가 저장한다.

var _n := 0
var _scene: Node

func _init() -> void:
	# 프레임 수 = 시간 이 되도록 고정 (창모드가 vsync 를 안 타면 수백 fps 로 돌아서
	# "100프레임 대기"가 실제로는 0.2초밖에 안 되는 문제 방지 — test_color_death 와 동일)
	Engine.max_fps = 60
	process_frame.connect(_tick)

func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		if args.size() < 2:
			push_error("사용법: -- <씬경로> <저장.png> [x] [y]")
			quit(1)
			return
		_scene = (load(args[0]) as PackedScene).instantiate()
		root.add_child(_scene)
	elif _n == 10:
		# 플레이어 위치 지정 (있을 때만) — 카메라도 스냅시켜 그 구역이 바로 보이게
		if args.size() >= 4:
			var player := _scene.get_node_or_null("Player")
			if player:
				player.set("velocity", Vector2.ZERO)
				player.set("global_position", Vector2(float(args[2]), float(args[3])))
				# [2026-08-06] 카메라 노드 이름이 씬마다 다르다.
				#   v3 스테이지 = "ProtoCamera" / 스마트월드 = "카메라"
				#   하나만 찾으면 스마트월드에서 카메라가 안 따라와 엉뚱한 곳이 찍힌다.
				var cam := _scene.get_node_or_null("ProtoCamera")
				if cam == null:
					cam = _scene.get_node_or_null("카메라")
				if cam == null:
					for c in _scene.get_children():
						if c is Camera2D and c.has_method("setup"):
							cam = c
							break
				if cam:
					cam.call("setup", player)
	elif _n == 100:
		# 100프레임 대기: 카메라 리밋 트윈(1.1초=66프레임)과 착지가 끝난 안정 화면을 찍는다
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[1])
		print("screenshot: ", error_string(err), " -> ", args[1])
		quit(0 if err == OK else 1)
