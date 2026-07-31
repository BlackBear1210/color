extends SceneTree
## [2026-07-24 도형 · 신규] 색칠 상태 캡처 도구 (창모드 전용)
## 실행: Godot --path . -s res://tools/screenshot_paint.gd -- <씬> <저장.png> [x] [y] [단계]
##   단계 = 0 전부 무색 / 1 절반쯤 칠함 / 2 전부 칠함 / 3 회색 혼합 포함
## 실제로 PaintPlatform.명중() 을 호출하므로 **셰이더 번짐·물감 흐름·스플래시가 전부
## 실전과 동일하게 작동**한다 (그림만 흉내내지 않는다).

var _n := 0
var _scene: Node

func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)

func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		if args.size() < 2:
			push_error("사용법: -- <씬> <저장.png> [x] [y] [단계]")
			quit(1)
			return
		_scene = (load(args[0]) as PackedScene).instantiate()
		root.add_child(_scene)
	elif _n == 12:
		if args.size() >= 4:
			var player := _scene.get_node_or_null("Player")
			if player:
				player.set("velocity", Vector2.ZERO)
				player.set("global_position", Vector2(float(args[2]), float(args[3])))
				var cam := _scene.get_node_or_null("ProtoCamera")
				if cam:
					cam.call("setup", player)
	elif _n == 20:
		var 단계 := int(args[4]) if args.size() >= 5 else 1
		_칠하기(단계)
	elif _n == 60:
		# 20프레임(≈0.33초) 뒤 = 잉크가 번지는 중 + 물감이 흐르는 중인 순간을 잡는다
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[1])
		print("screenshot: ", error_string(err), " -> ", args[1])
		quit(0 if err == OK else 1)

func _칠하기(단계: int) -> void:
	if 단계 <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260724
	var i := 0
	for n in _scene.get_tree().get_nodes_in_group("paint_platform"):
		var p: PaintPlatform = n
		if p == null or not p.칠하기_허용:
			continue
		i += 1
		var 총 := p.필요횟수()
		var 발수 := 총
		if 단계 == 1:
			발수 = maxi(int(ceil(총 * 0.5)), 1)      # 절반쯤 칠해진 "번지는 중" 상태
		var 색 := ColorDefs.BLACK if (i % 2 == 0) else ColorDefs.WHITE
		var 크기 := p.크기_px()
		var 세로벽 := 크기.y > 크기.x            # 벽(기둥)이면 옆면을 맞혀 물감 흐름을 확인
		for k in 발수:
			var t := (float(k) + 0.5) / float(maxi(발수, 1))
			var 지점: Vector2
			if 세로벽:
				# 벽 오른쪽 면 — "벽에 색칠하면 물감이 아래로 흐른다" 검증용
				지점 = p.global_position + Vector2(
					크기.x * 0.5 - 2.0,
					(t - 0.5) * 크기.y * 0.8 + rng.randf_range(-6.0, 6.0))
			else:
				# 발판 윗면에 흩뿌린다 (실제 사격과 비슷하게)
				지점 = p.global_position + Vector2(
					(t - 0.5) * 크기.x * 0.8 + rng.randf_range(-8.0, 8.0),
					-크기.y * 0.5 + rng.randf_range(0.0, 6.0))
			p.명중(색, 지점)
		# 단계 3 = 다 칠한 뒤 반대색을 한 발 더 → 영구 회색 (되돌릴 수 없는 상태 확인용)
		if 단계 >= 3 and i % 3 == 0:
			var 반대 := ColorDefs.WHITE if 색 == ColorDefs.BLACK else ColorDefs.BLACK
			p.명중(반대, p.global_position)
