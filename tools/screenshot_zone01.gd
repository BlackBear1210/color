extends SceneTree
## [2026-07-13 도형 · 신규] zone_01 화면 캡처 도구 (창모드 실행 필요 — 헤드리스는 렌더 안 됨).
## 실행: Godot --path . -s res://tools/screenshot_zone01.gd -- <저장경로.png>
## 프레임 20에서 칠하기/혼합을 시뮬레이션한 뒤 프레임 45에 PNG 저장하고 종료.

var _n := 0
var _scene: Node

func _init() -> void:
	process_frame.connect(_tick)

func _tick() -> void:
	_n += 1
	if _n == 1:
		_scene = (load("res://scenes/world_1/zone_01/zone_01.tscn") as PackedScene).instantiate()
		root.add_child(_scene)
	elif _n == 20:
		# 시각 확인용 시뮬레이션: 발판① 검정, 발판② 흰색, 발판③은 흑+백 → 회색
		var ps: Node = _scene.get_node("PaintSystem")
		var layer: TileMapLayer = _scene.get_node("TileMapLayer")
		ps.consume(0); ps.on_hit(layer, Vector2i(11, 10), 0)   # 흑 1발 (발판① 가운데)
		ps.consume(1); ps.on_hit(layer, Vector2i(16, 8), 1)    # 백 1발 (발판②)
		ps.consume(0); ps.on_hit(layer, Vector2i(10, 10), 0)   # 흑 1발 (발판① 왼쪽)
		ps.consume(1); ps.on_hit(layer, Vector2i(10, 10), 1)   # 백 덧칠 → 회색! (시야 안)
	elif _n == 45:
		var img := root.get_viewport().get_texture().get_image()
		var args := OS.get_cmdline_user_args()
		var path := args[0] if args.size() > 0 else "user://zone01.png"
		var err := img.save_png(path)
		print("screenshot: ", error_string(err), " -> ", path)
		quit(0 if err == OK else 1)
