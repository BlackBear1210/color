extends SceneTree
## [2026-07-14 도형 · v2.1] 테스트 존 생성기 (헤드리스 1회 실행용).
## 실행: Godot --headless --path . -s res://tools/build_zones.gd
## 산출:
##  - scenes/world_1/zone_01/zone_01.tscn : 횟수제(1~3발) 칠하기 + 회색 혼합 + FIFO 회수 + 색 사망 검증
##  - scenes/world_1/zone_02/zone_02.tscn : 색 전환 잠금 검증 맵
##      (경계선 위 = 백 지형만 / 아래 = 흑 지형만, 전환은 SwitchZone 안에서만)
##
## v2.1 수정 (2026-07-14 실기 피드백 반영):
##  - ★배경이 플레이어·지형을 가리던 버그: Parallax2D 에 z_index(-10/-9/-8)를 줘서
##    트리 순서와 무관하게 항상 맨 뒤에 그리도록 수정 (이전엔 z=0 이라 나중에 추가된 배경이 위에 그려짐)
##  - zone_01 에도 같은 배경 3층 적용
##  - 경계선 = 이중선(어두운 굵은 선 + 밝은 가는 선)이라 어떤 배경 위에서도 보임
##  - 위/아래 구역 틴트(위 밝게·아래 어둡게)로 "백 구역/흑 구역"이 화면 전체로 읽힘
##  - SwitchZone 안 경계선 위에 회색(중립) 발판 — 회색은 흑백 모두 안전(v1.3)하므로 전환 발판 역할

const TILESET := "res://assets/tilesets/terrain_tileset.tres"

const BLACK       := Vector2i(0, 0)
const WHITE       := Vector2i(1, 0)
const GRAY        := Vector2i(2, 0)
const UNPAINTED_1 := Vector2i(3, 0)   # 1발이면 칠해짐
const UNPAINTED_2 := Vector2i(4, 0)   # 2발 필요
const UNPAINTED_3 := Vector2i(5, 0)   # 3발 필요

func _init() -> void:
	var err1 := _build_zone01()
	var err2 := _build_zone02()
	print("build_zones: zone_01=", error_string(err1), " zone_02=", error_string(err2))
	quit(0 if (err1 == OK and err2 == OK) else 1)

# ── 공용 조립 ───────────────────────────────────────────────────────────
func _make_zone_base(root_name: String, script_path: String, spawn: Vector2) -> Dictionary:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load(script_path))

	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET)
	root.add_child(layer)
	layer.owner = root

	var ps := Node.new()
	ps.name = "PaintSystem"
	ps.set_script(load("res://scripts/proto/paint_system.gd"))
	root.add_child(ps)
	ps.owner = root

	var player: Node2D = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = spawn
	root.add_child(player)
	player.owner = root

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	ui.owner = root
	var brush := Control.new()
	brush.name = "BrushCursorUI"
	brush.set_script(load("res://scripts/proto/brush_cursor_ui.gd"))
	brush.set_anchors_preset(Control.PRESET_FULL_RECT)
	brush.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 클릭이 게임으로 통과되도록
	ui.add_child(brush)
	brush.owner = root

	# 패럴랙스 배경 3층 — z_index 음수라 항상 지형·플레이어 뒤 (명도 규칙표 준수)
	_add_parallax(root, "BgFar",  "res://assets/textures/bg/bg_far.svg",  0.2, Vector2(-200, -260), -10)
	_add_parallax(root, "BgMid",  "res://assets/textures/bg/bg_mid.svg",  0.5, Vector2(-200, -140), -9)
	_add_parallax(root, "BgNear", "res://assets/textures/bg/bg_near.svg", 0.8, Vector2(-200, 120),  -8)

	return { "root": root, "layer": layer }

func _save(root: Node, dir: String, path: String) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	root.free()
	return err

func _row(layer: TileMapLayer, x0: int, x1: int, y: int, atlas: Vector2i) -> void:
	for x in range(x0, x1 + 1):
		layer.set_cell(Vector2i(x, y), 0, atlas)

func _col(layer: TileMapLayer, x: int, y0: int, y1: int, atlas: Vector2i) -> void:
	for y in range(y0, y1 + 1):
		layer.set_cell(Vector2i(x, y), 0, atlas)

## Parallax2D + 반복 스프라이트 한 층 추가 (z_index 음수 = 항상 뒤)
func _add_parallax(root: Node, name_: String, tex_path: String, scale_: float,
		offset: Vector2, z: int) -> void:
	var par := Parallax2D.new()
	par.name = name_
	par.scroll_scale = Vector2(scale_, scale_)
	par.repeat_size = Vector2(1600, 0)        # 가로 무한 반복
	par.z_index = z                           # ★핵심: 지형(0)·플레이어보다 뒤
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = load(tex_path)
	spr.centered = false
	spr.position = offset
	par.add_child(spr)
	root.add_child(par)
	spr.owner = root
	par.owner = root

## 세계 좌표 라벨 (안내 텍스트) — 외곽선 포함이라 밝은/어두운 배경 모두에서 읽힘
func _world_label(root: Node, text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var lb := Label.new()
	lb.name = "Label_" + str(root.get_child_count())
	lb.text = text
	lb.position = pos
	lb.z_index = 10
	lb.add_theme_font_size_override("font_size", size_px)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
	lb.add_theme_constant_override("outline_size", 6)
	root.add_child(lb)
	lb.owner = root

## 이중선 (어두운 굵은 선 + 밝은 가는 선) — 어떤 배경에서도 보이는 강조선
func _double_line(root: Node, name_: String, points: PackedVector2Array,
		pos: Vector2, w_dark: float, w_light: float) -> void:
	var dark := Line2D.new()
	dark.name = name_ + "Dark"
	dark.points = points
	dark.width = w_dark
	dark.default_color = Color(0.06, 0.06, 0.06, 0.95)
	dark.position = pos
	dark.z_index = 5
	root.add_child(dark)
	dark.owner = root
	var light := Line2D.new()
	light.name = name_ + "Light"
	light.points = points
	light.width = w_light
	light.default_color = Color(0.97, 0.97, 0.97, 0.95)
	light.position = pos
	light.z_index = 6
	root.add_child(light)
	light.owner = root

# ── zone_01: 횟수제 칠하기·회색·회수·색 사망 검증 ───────────────────────
func _build_zone01() -> int:
	var z := _make_zone_base("Zone01", "res://scripts/proto/zone_lab.gd", Vector2(96, 445))
	var root: Node2D = z["root"]
	var layer: TileMapLayer = z["layer"]

	_row(layer, -6, 48, 14, BLACK)            # 바닥 (고정 검정)
	_col(layer, -6, 4, 13, BLACK)             # 좌측 벽
	_col(layer, 48, 4, 13, BLACK)             # 우측 벽

	_row(layer, 5, 7, 11, BLACK)              # 고정 검정 단상 (흑 군집 — 왼쪽)
	_row(layer, 10, 12, 10, UNPAINTED_1)      # 무색 발판 ① 1발
	_row(layer, 16, 18, 8, UNPAINTED_2)       # 무색 발판 ② 2발 (높음)
	_row(layer, 22, 24, 10, UNPAINTED_3)      # 무색 발판 ③ 3발
	_row(layer, 30, 33, 12, WHITE)            # 고정 흰 발판 (백 군집 — 오른쪽, 흑 군집과 5타일+ 분리)
	                                          #  → 혼합 실험(검정 쏘면 회색) + 색 사망 실험(밟으면 죽음)
	_col(layer, 40, 9, 13, UNPAINTED_1)       # 무색 기둥 (세로 표적)

	# 라벨은 초기 카메라 시야(스폰 x=96 기준 월드 약 -480~672, y 121~769) 안에 배치
	_world_label(root, "붓을 발판에 올리면 필요 횟수(x1~x3) 표시 · E = 먼저 칠한 것부터 회수",
		Vector2(-140, 170), 17, Color(0.95, 0.95, 0.95))
	_world_label(root, "흰 발판: 검정을 쏘면 회색(영구) · 검정 상태로 밟으면 💀사망",
		Vector2(880, 330), 15, Color(0.9, 0.9, 0.9))

	return _save(root, "res://scenes/world_1/zone_01", "res://scenes/world_1/zone_01/zone_01.tscn")

# ── zone_02: 색 전환 잠금 + 흑/백 경계 ──────────────────────────────────
func _build_zone02() -> int:
	var z := _make_zone_base("Zone02", "res://scripts/proto/zone02_lab.gd", Vector2(96, 445))
	var root: Node2D = z["root"]
	var layer: TileMapLayer = z["layer"]

	# ── 아래 = 흑 지형 구역 (경계선 row 8 아래) ─────────────────────────
	_row(layer, -6, 48, 14, BLACK)            # 바닥
	_col(layer, -6, -4, 13, BLACK)            # 좌측 벽 (위 구역까지)
	_col(layer, 48, -4, 13, BLACK)            # 우측 벽
	_row(layer, 4, 6, 11, BLACK)              # 흑 단상 1
	_row(layer, 10, 12, 9, BLACK)             # 흑 단상 2 (경계 근처까지 상승)

	# ── 경계선 위 회색(중립) 발판 — v1.3: 회색은 흑백 모두 안전 ─────────
	# 흑 상태로 올라와 여기서 Shift(전환 존 안) → 백으로 바꿔도 안 죽는 전환 발판
	_row(layer, 13, 16, 8, GRAY)

	# ── 위 = 백 지형 구역 (경계선 row 8 위) ────────────────────────────
	_row(layer, 18, 20, 6, WHITE)             # 백 발판 1 (회색 발판에서 점프)
	_row(layer, 23, 25, 4, WHITE)             # 백 발판 2
	_row(layer, 28, 30, 2, WHITE)             # 백 발판 3
	_row(layer, 32, 40, 6, WHITE)             # 백 상층 바닥

	# ── 구역 틴트: 위(백 구역) 밝게 / 아래(흑 구역) 어둡게 ──────────────
	var tint_top := Polygon2D.new()
	tint_top.name = "TintTop"
	tint_top.polygon = PackedVector2Array([Vector2(-192, -352), Vector2(1568, -352), Vector2(1568, 256), Vector2(-192, 256)])
	tint_top.color = Color(1, 1, 1, 0.10)
	tint_top.z_index = -5
	root.add_child(tint_top)
	tint_top.owner = root
	var tint_bottom := Polygon2D.new()
	tint_bottom.name = "TintBottom"
	tint_bottom.polygon = PackedVector2Array([Vector2(-192, 256), Vector2(1568, 256), Vector2(1568, 520), Vector2(-192, 520)])
	tint_bottom.color = Color(0, 0, 0, 0.22)
	tint_bottom.z_index = -5
	root.add_child(tint_bottom)
	tint_bottom.owner = root

	# ── 경계선 (row 8 상단, y=256) — 이중선으로 어디서든 보이게 ─────────
	_double_line(root, "Boundary",
		PackedVector2Array([Vector2(-192, 256), Vector2(1568, 256)]), Vector2.ZERO, 10.0, 4.0)

	# ── 전환 허용 구역 (SwitchZone) — 이 안에서만 Shift 가능 ────────────
	var zone := Area2D.new()
	zone.name = "SwitchZone"
	zone.position = Vector2((10 + 17) * 0.5 * 32.0, (3 + 10) * 0.5 * 32.0)   # (432, 208)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8 * 32.0, 8 * 32.0)
	cs.shape = rect
	zone.add_child(cs)
	root.add_child(zone)
	zone.owner = root
	cs.owner = root
	# 구역 시각 표시: 반투명 채움 + 이중 테두리
	var hw := 8 * 16.0
	var vis := Polygon2D.new()
	vis.name = "SwitchZoneVisual"
	vis.polygon = PackedVector2Array([Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)])
	vis.color = Color(0.85, 0.85, 0.85, 0.16)
	vis.position = zone.position
	vis.z_index = 3
	root.add_child(vis)
	vis.owner = root
	_double_line(root, "SwitchZoneBorder",
		PackedVector2Array([Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw), Vector2(-hw, -hw)]),
		zone.position, 6.0, 2.5)

	# ── 안내 라벨 ───────────────────────────────────────────────────────
	# 라벨은 초기 카메라 시야(스폰 x=96 기준 월드 약 -480~672, y 121~769) 안에 배치
	_world_label(root, "▲ 위: 백(白) 지형 — 흑 상태로 밟으면 💀", Vector2(-150, 206), 18, Color(0.98, 0.98, 0.98))
	_world_label(root, "▼ 아래: 흑(黑) 지형 — 백 상태로 밟으면 💀", Vector2(-150, 280), 18, Color(0.85, 0.85, 0.85))
	_world_label(root, "전환 존 — 이 안에서만 Shift", Vector2(300, 128), 17, Color(0.95, 0.95, 0.95))
	_world_label(root, "회색 = 중립(안전) · 여기서 색을 바꿔라", Vector2(340, 300), 14, Color(0.82, 0.82, 0.82))

	return _save(root, "res://scenes/world_1/zone_02", "res://scenes/world_1/zone_02/zone_02.tscn")
