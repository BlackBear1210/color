extends SceneTree
## [2026-07-18 도형 · 신규] world_1 통합 씬 생성기 (헤드리스 1회 실행용).
## 실행: Godot --headless --path . -s res://tools/build_world.gd
## 산출: scenes/world_1/world_1.tscn
##
## zone_01 지형과 zone_02 지형을 ★한 씬 안에★ 복도로 이어 배치한다.
## (배치 좌표는 build_zones.gd 의 두 존과 동일 — zone2 만 오른쪽으로 +64칸 이동)
## 씬 교체 없이 카메라 리밋 트윈만으로 구역이 넘어가는 "바인(Vane)식" 연결의 지형 부분.
## 로직은 scripts/proto/world_lab.gd (ZoneLab 상속) 이 담당한다.
##
## ⚠ build_zones.gd 와 헬퍼가 중복되는 것은 의도된 것 — 테스트 존 빌더를 건드리지
##   않고 월드 빌더를 독립적으로 굴리기 위함 (수정 시 두 파일을 같이 볼 것).

const TILESET := "res://assets/tilesets/terrain_tileset.tres"

const BLACK       := Vector2i(0, 0)
const WHITE       := Vector2i(1, 0)
const GRAY        := Vector2i(2, 0)
const UNPAINTED_1 := Vector2i(3, 0)
const UNPAINTED_2 := Vector2i(4, 0)
const UNPAINTED_3 := Vector2i(5, 0)

## zone2 를 오른쪽으로 미는 칸 수 (64칸 = 2048px). 복도가 그 사이를 잇는다.
const DX := 64
const PX := 2048.0

func _init() -> void:
	var err := _build_world()
	print("build_world: world_1=", error_string(err))
	quit(0 if err == OK else 1)

func _build_world() -> int:
	var root := Node2D.new()
	root.name = "World1"
	root.set_script(load("res://scripts/proto/world_lab.gd"))

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
	player.position = Vector2(96, 445)
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
	brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(brush)
	brush.owner = root

	# 패럴랙스 배경 3층 (zone_visuals.gd 가 런타임에 노멀맵을 주입한다)
	_add_parallax(root, "BgFar",  "res://assets/textures/bg/bg_far.svg",  0.2, Vector2(-200, -260), -10)
	_add_parallax(root, "BgMid",  "res://assets/textures/bg/bg_mid.svg",  0.5, Vector2(-200, -140), -9)
	_add_parallax(root, "BgNear", "res://assets/textures/bg/bg_near.svg", 0.8, Vector2(-200, 120),  -8)

	# ══ ZONE 1 구역 (build_zones._build_zone01 과 동일 배치) ═══════════════
	_row(layer, -6, 112, 14, BLACK)           # ★공용 바닥: zone1 → 복도 → zone2 한 줄
	_col(layer, -6, 4, 13, BLACK)             # zone1 좌측 벽
	# [2026-07-18 사용자 요청] zone1 우측 벽·복도 터널 천장 삭제 —
	# 벽/터널 대신 ★탁 트인 골짜기★로 두 구역이 이어진다. 하늘이 계속 보이는 채로
	# 카메라 리밋만 트윈되므로 "벽을 통과했다"가 아니라 "걸어서 다음 지역에 들어섰다"는
	# 바인(Vane)식 개방형 전환이 된다.
	_row(layer, 5, 7, 11, BLACK)              # 고정 검정 단상
	_row(layer, 10, 12, 10, UNPAINTED_1)      # 무색 발판 ① 1발
	_row(layer, 16, 18, 8, UNPAINTED_2)       # 무색 발판 ② 2발 (높음)
	_row(layer, 22, 24, 10, UNPAINTED_3)      # 무색 발판 ③ 3발
	_row(layer, 30, 33, 12, WHITE)            # 고정 흰 발판 (백 상태로 밟고 기둥에 오르는 루트)
	_col(layer, 40, 9, 13, UNPAINTED_1)       # 무색 기둥 (밟고 넘어가는 관문 역할)

	# ══ 복도 (zone1 ↔ zone2) — 열린 회색 길 ═══════════════════════════════
	_row(layer, 49, 57, 14, GRAY)             # ★복도 바닥 = 회색(중립) — 어느 색으로도 안전 통과
	                                          #   + "구역과 구역 사이 = 안전 전환 지대" 레벨 문법

	# ══ ZONE 2 구역 (build_zones._build_zone02 배치 + 전부 +64칸 이동) ════
	# [2026-07-18 사용자 요청] zone2 좌측 벽도 삭제 — 위 골짜기 전환과 세트
	_col(layer, 112, -4, 13, BLACK)           # zone2 우측 벽
	_row(layer, 4 + DX, 6 + DX, 11, BLACK)    # 흑 단상 1
	_row(layer, 10 + DX, 12 + DX, 9, BLACK)   # 흑 단상 2 (경계 근처까지 상승)
	_row(layer, 13 + DX, 16 + DX, 8, GRAY)    # 경계선 위 회색(중립) 전환 발판
	_row(layer, 18 + DX, 20 + DX, 6, WHITE)   # 백 발판 1
	_row(layer, 23 + DX, 25 + DX, 4, WHITE)   # 백 발판 2
	_row(layer, 28 + DX, 30 + DX, 2, WHITE)   # 백 발판 3
	_row(layer, 32 + DX, 40 + DX, 6, WHITE)   # 백 상층 바닥 (끝에 골인 지점)

	# ── zone2 구역 틴트: 위(백 구역) 밝게 / 아래(흑 구역) 어둡게 ──────────
	var tint_top := Polygon2D.new()
	tint_top.name = "TintTop"
	tint_top.polygon = PackedVector2Array([Vector2(-192 + PX, -352), Vector2(1568 + PX, -352),
		Vector2(1568 + PX, 256), Vector2(-192 + PX, 256)])
	tint_top.color = Color(1, 1, 1, 0.10)
	tint_top.z_index = -5
	root.add_child(tint_top)
	tint_top.owner = root
	var tint_bottom := Polygon2D.new()
	tint_bottom.name = "TintBottom"
	tint_bottom.polygon = PackedVector2Array([Vector2(-192 + PX, 256), Vector2(1568 + PX, 256),
		Vector2(1568 + PX, 520), Vector2(-192 + PX, 520)])
	tint_bottom.color = Color(0, 0, 0, 0.22)
	tint_bottom.z_index = -5
	root.add_child(tint_bottom)
	tint_bottom.owner = root

	# ── zone2 경계선 (이중선) ─────────────────────────────────────────────
	_double_line(root, "Boundary",
		PackedVector2Array([Vector2(-192 + PX, 256), Vector2(1568 + PX, 256)]), Vector2.ZERO, 10.0, 4.0)

	# ── 전환 허용 구역 (SwitchZone) — zone2 에서만 Shift 가능 (world_lab 감시) ─
	var zone := Area2D.new()
	zone.name = "SwitchZone"
	zone.position = Vector2(432.0 + PX, 208.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8 * 32.0, 8 * 32.0)
	cs.shape = rect
	zone.add_child(cs)
	root.add_child(zone)
	zone.owner = root
	cs.owner = root
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

	# ── 골인 지점 (zone2 백 상층 우측 끝) → world_lab 이 클리어 연출 ──────
	var exit := Area2D.new()
	exit.name = "ExitZone"
	exit.add_to_group("zone_exit")
	exit.position = Vector2((38 + DX) * 32.0 + 16.0, 130.0)   # 백 상층(y=192) 위 공중
	var ecs := CollisionShape2D.new()
	var erect := RectangleShape2D.new()
	erect.size = Vector2(96, 130)
	ecs.shape = erect
	exit.add_child(ecs)
	root.add_child(exit)
	exit.owner = root
	ecs.owner = root
	var evis := Polygon2D.new()
	evis.name = "ExitVisual"
	evis.polygon = PackedVector2Array([Vector2(-48, -65), Vector2(48, -65), Vector2(48, 65), Vector2(-48, 65)])
	evis.color = Color(0.95, 0.95, 0.95, 0.20)
	evis.position = exit.position
	evis.z_index = 3
	root.add_child(evis)
	evis.owner = root

	# ── 안내 라벨 ─────────────────────────────────────────────────────────
	_world_label(root, "붓을 발판에 올리면 필요 횟수(x1~x3) 표시 · E = 먼저 칠한 것부터 회수",
		Vector2(-140, 170), 17, Color(0.95, 0.95, 0.95))
	_world_label(root, "흰 발판: 백 상태로 밟고 기둥을 넘어 오른쪽 통로로 →",
		Vector2(880, 330), 15, Color(0.9, 0.9, 0.9))
	_world_label(root, "ZONE 2 →", Vector2(1560, 372), 20, Color(0.95, 0.95, 0.95))
	_world_label(root, "회색 복도 = 중립 · 어느 색이든 안전", Vector2(1580, 490), 13, Color(0.8, 0.8, 0.8))
	_world_label(root, "▲ 위: 백(白) 지형 — 흑 상태로 밟으면 💀", Vector2(-150 + PX, 206), 18, Color(0.98, 0.98, 0.98))
	_world_label(root, "▼ 아래: 흑(黑) 지형 — 백 상태로 밟으면 💀", Vector2(-150 + PX, 280), 18, Color(0.85, 0.85, 0.85))
	_world_label(root, "전환 존 — 이 안에서만 Shift", Vector2(300 + PX, 128), 17, Color(0.95, 0.95, 0.95))
	_world_label(root, "회색 = 중립(안전) · 여기서 색을 바꿔라", Vector2(340 + PX, 300), 14, Color(0.82, 0.82, 0.82))
	_world_label(root, "🏁 GOAL", Vector2((37 + DX) * 32.0, 60.0), 22, Color(0.98, 0.98, 0.98))

	DirAccess.make_dir_recursive_absolute("res://scenes/world_1")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "res://scenes/world_1/world_1.tscn")
	root.free()
	return err

# ── 헬퍼 (build_zones.gd 와 동일) ───────────────────────────────────────
func _row(layer: TileMapLayer, x0: int, x1: int, y: int, atlas: Vector2i) -> void:
	for x in range(x0, x1 + 1):
		layer.set_cell(Vector2i(x, y), 0, atlas)

func _col(layer: TileMapLayer, x: int, y0: int, y1: int, atlas: Vector2i) -> void:
	for y in range(y0, y1 + 1):
		layer.set_cell(Vector2i(x, y), 0, atlas)

func _add_parallax(root: Node, name_: String, tex_path: String, scale_: float,
		offset: Vector2, z: int) -> void:
	var par := Parallax2D.new()
	par.name = name_
	par.scroll_scale = Vector2(scale_, scale_)
	par.repeat_size = Vector2(1600, 0)
	par.z_index = z
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = load(tex_path)
	spr.centered = false
	spr.position = offset
	par.add_child(spr)
	root.add_child(par)
	spr.owner = root
	par.owner = root

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
