extends SceneTree
## [2026-07-14 도형 · v2 갱신] 테스트 존 화면 캡처 도구 (창모드 실행 필요 — 헤드리스는 렌더 안 됨).
## 실행: Godot --path . -s res://tools/screenshot_zone01.gd -- <저장경로.png> [zone_02]
## 두 번째 인자에 zone_02 를 주면 zone_02 를 캡처한다 (기본 zone_01).
## 프레임 20에서 칠하기/혼합을 시뮬레이션한 뒤 프레임 45에 PNG 저장하고 종료.

var _n := 0
var _scene: Node
var _is_zone02 := false

func _init() -> void:
	process_frame.connect(_tick)

func _tick() -> void:
	_n += 1
	if _n == 1:
		var args := OS.get_cmdline_user_args()
		_is_zone02 = args.size() > 1 and args[1] == "zone_02"
		var path := "res://scenes/world_1/zone_02/zone_02.tscn" if _is_zone02 \
			else "res://scenes/world_1/zone_01/zone_01.tscn"
		_scene = (load(path) as PackedScene).instantiate()
		root.add_child(_scene)
	elif _n == 20 and not _is_zone02:
		# 시각 확인용 시뮬레이션 (v2 API — consume 없음, 무제한 발사):
		var ps: Node = _scene.get_node("PaintSystem")
		var layer: TileMapLayer = _scene.get_node("TileMapLayer")
		ps.on_hit(layer, Vector2i(11, 10), 0)   # 1발 발판① → 흑 완성
		ps.on_hit(layer, Vector2i(17, 8), 1)    # 2발 발판② → 백 1/2 (progress, 아직 무색)
		ps.on_hit(layer, Vector2i(23, 10), 0)   # 3발 발판③ → 흑 1/3
		ps.on_hit(layer, Vector2i(31, 12), 0)   # 고정 흰 발판에 흑 → 회색!
	elif _n == 45:
		var img := root.get_viewport().get_texture().get_image()
		var args := OS.get_cmdline_user_args()
		var path := args[0] if args.size() > 0 else "user://zone.png"
		var err := img.save_png(path)
		print("screenshot: ", error_string(err), " -> ", path)
		quit(0 if err == OK else 1)
