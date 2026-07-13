extends SceneTree
## [2026-07-13 도형 · 신규] zone_01 테스트 맵 생성기 (헤드리스 1회 실행용).
## 실행: Godot --headless --path . -s res://tools/build_zone01.gd
## 산출: scenes/world_1/zone_01/zone_01.tscn — 물감 게이지·회수·회색 혼합 검증용 맵.

const TILESET := "res://assets/tilesets/terrain_tileset.tres"
const OUT     := "res://scenes/world_1/zone_01/zone_01.tscn"

const BLACK     := Vector2i(0, 0)
const WHITE     := Vector2i(1, 0)
const UNPAINTED := Vector2i(3, 0)

func _init() -> void:
	var root := Node2D.new()
	root.name = "Zone01"
	root.set_script(load("res://scripts/proto/zone01_lab.gd"))

	# ── 지형 ────────────────────────────────────────────────────────────
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET)
	root.add_child(layer)
	layer.owner = root

	for x in range(-2, 45):                       # 바닥 (고정 검정)
		layer.set_cell(Vector2i(x, 14), 0, BLACK)
	for y in range(8, 14):                        # 좌우 벽 (고정 검정)
		layer.set_cell(Vector2i(-2, y), 0, BLACK)
		layer.set_cell(Vector2i(44, y), 0, BLACK)
	for x in range(5, 8):                         # 낮은 검정 단상
		layer.set_cell(Vector2i(x, 11), 0, BLACK)
	for x in range(10, 13):                       # 무색 발판 ① (칠하기 표적)
		layer.set_cell(Vector2i(x, 10), 0, UNPAINTED)
	for x in range(16, 19):                       # 무색 발판 ② (높음)
		layer.set_cell(Vector2i(x, 8), 0, UNPAINTED)
	for x in range(22, 25):                       # 무색 발판 ③ — 회색 혼합 실험용
		layer.set_cell(Vector2i(x, 10), 0, UNPAINTED)
	for x in range(28, 31):                       # 고정 흰색 발판 (혼합 실험: 여기에 검정을 쏘면 회색)
		layer.set_cell(Vector2i(x, 12), 0, WHITE)
	for y in range(9, 14):                        # 무색 기둥 (세로 표적)
		layer.set_cell(Vector2i(34, y), 0, UNPAINTED)

	# ── 프로토 시스템 노드 ───────────────────────────────────────────────
	var ps := Node.new()
	ps.name = "PaintSystem"
	ps.set_script(load("res://scripts/proto/paint_system.gd"))
	root.add_child(ps)
	ps.owner = root

	# ── 플레이어 (기존 씬 그대로 인스턴스 — 무수정) ──────────────────────
	var player: Node2D = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector2(96, 445)            # 바닥(y=448) 바로 위
	root.add_child(player)
	player.owner = root

	# ── UI ──────────────────────────────────────────────────────────────
	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	ui.owner = root
	var gauge := Control.new()
	gauge.name = "PaintGaugeUI"
	gauge.set_script(load("res://scripts/proto/paint_gauge_ui.gd"))
	gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 클릭이 게임으로 통과되도록
	ui.add_child(gauge)
	gauge.owner = root

	# ── 저장 ────────────────────────────────────────────────────────────
	DirAccess.make_dir_recursive_absolute("res://scenes/world_1/zone_01")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_zone01: save=", error_string(err))
	root.free()
	quit(0 if err == OK else 1)
