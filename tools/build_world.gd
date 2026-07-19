extends SceneTree
## [2026-07-19 도형 · v2] world_1 통합 씬 생성기 (헤드리스 1회 실행용).
## 실행: Godot --headless --path . -s res://tools/build_world.gd
## 산출: scenes/world_1/world_1.tscn
##
## v2 변경 (2026-07-19):
##  1. ★zone2 경계 시스템 재구축 — 수동 SwitchZone(전환 존) 방식을 폐기하고
##     docs/경계_색구역_시스템.md 의 ColorZone(다각형 색 강제 구역)으로 교체.
##     경계선 위 = 백 구역(자동 白) / 아래 = 흑 구역(자동 黑).
##     ⚠ 두 구역 사이에 28px "중립 틈"을 둔다 — 플레이어 키(47px)보다 좁아서
##       경계를 넘는 도중엔 반드시 한쪽 구역에 걸치고(색 공백 없음),
##       발판 위에 가만히 서 있을 때는 반대편 구역에 닿지 않는다(히스테리시스).
##  2. ★ZONE 3 신설 — "수직 도시" (기획 스테이지3: 판자촌 → 고층, 위로 상승).
##     회색 다리(y6)로 zone2 상층과 연결 → 탑 내부를 지그재그로 등반.
##     흑/백 ColorZone 밴드가 높이에 따라 번갈아 깔려 "올라갈수록 색이 뒤집힌다".
##     밴드 전환 지점마다 회색(중립) 발판 = 안전 전환 지대 (레벨 문법 유지).
##  3. ★일러스트 프롭 + 라이팅 — 타일 지형 위에 SVG 일러스트(풀·발판 캡·가로등·
##     판잣집·고층 실루엣)를 겹치고, 가로등/창문/구슬에 PointLight2D 를 얹는다.
##     프롭 노멀맵은 generate_normal_maps.gd 가 만들고 zone_visuals.gd 가
##     런타임에 CanvasTexture 로 감싸 주입 → 빛 방향에 따라 음영이 실시간 변화
##     (레인월드의 "레이어 즉석 계산"을 Godot 식으로 옮긴 것 = Light2D+노멀맵).
##     복도에는 물웅덩이(셰이더) — 가로등 빛이 수면에 반사되는 연출.
##
## ⚠ build_zones.gd 와 헬퍼가 중복되는 것은 의도된 것 — 테스트 존 빌더를 건드리지
##   않고 월드 빌더를 독립적으로 굴리기 위함 (수정 시 두 파일을 같이 볼 것).

const TILESET := "res://assets/tilesets/terrain_tileset.tres"
const COLOR_ZONE_SCRIPT := "res://scenes/경계/color_zone.gd"
const FLICKER_SCRIPT := "res://scripts/proto/light_flicker.gd"
const PROPS := "res://assets/textures/props/"

const BLACK       := Vector2i(0, 0)
const WHITE       := Vector2i(1, 0)
const GRAY        := Vector2i(2, 0)
const UNPAINTED_1 := Vector2i(3, 0)
const UNPAINTED_2 := Vector2i(4, 0)
const UNPAINTED_3 := Vector2i(5, 0)

## zone2 를 오른쪽으로 미는 칸 수 (64칸 = 2048px). 복도가 그 사이를 잇는다.
const DX := 64
const PX := 2048.0

## ── 경계(ColorZone) 배치 상수 ───────────────────────────────────────────
## 플레이어 충돌 크기: 64×128 × scale(0.795, 0.368) ≈ 51×47px (Player.tscn 실측).
## 회색 전환 발판 윗면 S 를 기준으로:
##   위쪽 구역 아랫변 = S - 20  (회색 위에 선 몸(S-47~S)의 머리와 27px 겹침 = 강제 발동)
##   아래 구역 윗변   = S + 8   (회색 위에 선 몸과 안 겹침 / 두 칸 아래 발판(S+64)에
##                              선 몸(S+17~)과는 겹침 = 강제 발동)
## → 중립 틈 28px < 키 47px 이므로 낙하/점프 중 색 공백이 생기지 않는다.
const GAP_UP := 20.0
const GAP_DOWN := 8.0

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
	# [2026-07-18 사용자 요청] zone1 우측 벽·복도 터널 천장 없음 — 탁 트인 골짜기 전환
	_row(layer, 5, 7, 11, BLACK)              # 고정 검정 단상
	_row(layer, 10, 12, 10, UNPAINTED_1)      # 무색 발판 ① 1발
	_row(layer, 16, 18, 8, UNPAINTED_2)       # 무색 발판 ② 2발 (높음)
	_row(layer, 22, 24, 10, UNPAINTED_3)      # 무색 발판 ③ 3발
	_row(layer, 30, 33, 12, WHITE)            # 고정 흰 발판 (백 상태로 밟고 기둥에 오르는 루트)
	_col(layer, 40, 9, 13, UNPAINTED_1)       # 무색 기둥 (밟고 넘어가는 관문 역할)

	# ── zone1 프롭: 시골(자연) 분위기 — 풀 포기 + 발판 캡 일러스트 ────────
	for gx: float in [140.0, 420.0, 700.0, 1000.0, 1300.0]:
		_prop(root, "grass_tuft.svg", Vector2(gx, 448), 1)          # 바닥 풀
	_prop(root, "grass_tuft.svg", Vector2(190, 352), 1)             # 흑 단상 위 풀
	_prop(root, "ledge_light.svg", Vector2(160, 352), 1)            # 흑 단상 캡 (밝은 변형)
	_prop(root, "ledge_dark.svg", Vector2(976, 384), 1)             # 흰 발판 캡 (어두운 변형)

	# ══ 복도 (zone1 ↔ zone2) — 열린 회색 길 + ★가로등·물웅덩이★ ═══════════
	_row(layer, 49, 57, 14, GRAY)             # 복도 바닥 = 회색(중립) — 안전 전환 지대
	# 가로등: 프롭 일러스트 + 램프 헤드 위치에 깜빡이는 PointLight2D
	_lamp(root, "CorridorLamp", 1665.0, 448.0, false)
	# 물웅덩이: 가로등 빛이 수면에 반사되는 셰이더 스트립 (streak_x = 전구 월드 x)
	_puddle(root, "CorridorPuddle", 1585.0, 1840.0, 444.0, 452.0, 1681.0)

	# ══ ZONE 2 구역 — ★ColorZone 경계 시스템으로 재구축★ ══════════════════
	# 지형 (기존 배치 유지, 두 가지 변경):
	#  · 우측 벽을 y8~13 으로 낮춤 — 상층 다리(y6)가 벽 위를 지나 zone3 로 이어진다
	#  · 백 발판 3(y2)을 무색 1발로 교체 — 백 구역 안에서 "칠해서 길 만들기" 퍼즐
	_col(layer, 112, 8, 13, BLACK)            # zone2 우측 벽 (낮춤 — 위는 다리 통로)
	_row(layer, 4 + DX, 6 + DX, 11, BLACK)    # 흑 단상 1
	_row(layer, 10 + DX, 12 + DX, 9, BLACK)   # 흑 단상 2 (경계 근처까지 상승)
	_row(layer, 13 + DX, 16 + DX, 8, GRAY)    # ★경계 전환 발판 (회색) — 윗면 S = 256
	_row(layer, 18 + DX, 20 + DX, 6, WHITE)   # 백 발판 1
	_row(layer, 23 + DX, 25 + DX, 4, WHITE)   # 백 발판 2
	_row(layer, 28 + DX, 30 + DX, 2, UNPAINTED_1)  # 무색 1발 (백 구역 → 백으로 칠해야 진행)
	_row(layer, 32 + DX, 40 + DX, 6, WHITE)   # 백 상층 바닥 → 오른쪽 다리로 이어짐

	# ── ColorZone 2개: 경계선 위 = 백 / 아래 = 흑 (중립 틈 236~264) ───────
	# 틴트는 ColorZone 이 스스로 그린다 (기존 TintTop/TintBottom 폴리곤 대체)
	_color_zone(root, "Zone2White", Rect2(1856, -352, 1760, 256.0 - GAP_UP + 352.0), true)
	_color_zone(root, "Zone2Black", Rect2(1856, 256.0 + GAP_DOWN, 1760, 520.0 - 264.0), false)

	# ── zone2 경계선 (이중선) — 중립 틈 한가운데(y=250) ────────────────────
	_double_line(root, "Boundary",
		PackedVector2Array([Vector2(1856, 250), Vector2(3616, 250)]), Vector2.ZERO, 10.0, 4.0)

	# ── zone2 프롭: 발판 캡 + 경계 안내 발광 구슬 ─────────────────────────
	_prop(root, "ledge_light.svg", Vector2(2176, 352), 1)           # 흑 단상 1 캡
	_prop(root, "ledge_light.svg", Vector2(2368, 288), 1)           # 흑 단상 2 캡
	_prop(root, "ledge_dark.svg", Vector2(2784, 128), 1)            # 백 발판 2 캡
	for lx: float in [3090.0, 3200.0, 3310.0]:                      # 백 상층 캡 3장
		_prop(root, "ledge_dark.svg", Vector2(lx, 192), 1)
	_orb(root, "OrbZone2Gray", Vector2(2528, 232))                  # 회색 전환 발판 위 구슬

	# ══ 다리 (zone2 상층 → zone3) — 회색(중립) 고가 통로 ══════════════════
	_row(layer, 105, 117, 6, GRAY)            # 다리 y6 — zone2 백 구역을 빠져나와
	                                          # zone3 흑 밴드(A)로 들어가는 완충 지대
	_orb(root, "OrbBridge", Vector2(3560, 168))                     # 다리 중간 안내 구슬

	# ══ ZONE 3 — 수직 도시 (판자촌 → 고층, 위로 상승) ═════════════════════
	# 탑 구조: 좌벽 x113(위쪽만— 다리 높이는 개방) / 우벽 x152 / 바닥 y13
	_col(layer, 113, -29, 3, BLACK)           # 좌측 벽 (y4~5 = 다리 위 통로 개방)
	_col(layer, 152, -29, 13, BLACK)          # 우측 벽
	_row(layer, 113, 151, 13, BLACK)          # 판자촌 바닥 (다리에서 낙하 진입)

	# ── 등반 발판: 흑 밴드 A (바닥 ~ y3) ──────────────────────────────────
	_row(layer, 118, 120, 11, BLACK)          # A1
	_row(layer, 123, 125, 9, UNPAINTED_1)     # A2 (흑으로 1발)
	_row(layer, 128, 130, 7, BLACK)           # A3
	_row(layer, 134, 136, 5, UNPAINTED_2)     # A4 (흑으로 2발)
	_row(layer, 140, 142, 3, BLACK)           # A5
	_row(layer, 146, 148, 1, GRAY)            # ★전환 발판 G1 — 윗면 S1 = 32
	# ── 백 밴드 B (y0 ~ y-9): 왼쪽으로 지그재그 상승 ──────────────────────
	_row(layer, 141, 143, -1, WHITE)          # B1
	_row(layer, 135, 137, -3, UNPAINTED_1)    # B2 (백으로 1발)
	_row(layer, 129, 131, -5, WHITE)          # B3
	_row(layer, 123, 125, -7, UNPAINTED_2)    # B4 (백으로 2발)
	_row(layer, 117, 119, -9, WHITE)          # B5
	_row(layer, 115, 117, -11, GRAY)          # ★전환 발판 G2 — 윗면 S2 = -352
	# ── 흑 밴드 C (y-12 ~ y-21): 오른쪽으로 지그재그 상승 ─────────────────
	_row(layer, 120, 122, -13, BLACK)         # C1
	_row(layer, 125, 127, -15, UNPAINTED_3)   # C2 (흑으로 3발 — 최고 난도 칠하기)
	_row(layer, 130, 132, -17, BLACK)         # C3
	_row(layer, 136, 138, -19, UNPAINTED_1)   # C4
	_row(layer, 142, 144, -21, BLACK)         # C5
	_row(layer, 147, 149, -23, GRAY)          # ★전환 발판 G3 — 윗면 S3 = -736
	# ── 백 밴드 D (y-24 ~ 옥상): 골인 ─────────────────────────────────────
	_row(layer, 141, 143, -25, WHITE)         # D1
	_row(layer, 132, 138, -27, WHITE)         # 옥상 (골인 지점)

	# ── zone3 ColorZone 밴드 4개 (탑 내부 x 3648~4864) ────────────────────
	# 회색 전환 발판 윗면 S 마다: 아래 밴드는 S+8 에서 끝나고 위 밴드는 S-20 에서 시작.
	_color_zone(root, "Zone3BandA_Black", Rect2(3648, 40, 1216, 430), false)
	_color_zone(root, "Zone3BandB_White", Rect2(3648, -344, 1216, 356), true)
	_color_zone(root, "Zone3BandC_Black", Rect2(3648, -728, 1216, 356), false)
	_color_zone(root, "Zone3BandD_White", Rect2(3648, -960, 1216, 204), true)
	# 밴드 경계선 3개 (중립 틈 중앙: S-6)
	for by: float in [26.0, -358.0, -742.0]:
		_double_line(root, "Boundary3_%d" % int(by),
			PackedVector2Array([Vector2(3648, by), Vector2(4864, by)]), Vector2.ZERO, 8.0, 3.0)

	# ── zone3 배경: 밤하늘 그라데이션 (위로 갈수록 밝음 = 상승의 희망) ────
	_sky(root, Rect2(3520, -1100, 1456, 1620))
	# 판자촌 실루엣 (바닥층 중경) — 창문 하나에 빛
	_prop(root, "shack.svg", Vector2(3660, 416), -6, false, 1.0, Color(0.85, 0.85, 0.85))
	_prop(root, "shack.svg", Vector2(3930, 416), -7, true, 0.75, Color(0.55, 0.55, 0.55))
	_prop(root, "shack.svg", Vector2(4430, 416), -6, false, 0.9, Color(0.75, 0.75, 0.75))
	_light(root, "ShackWindowLight", Vector2(3704, 367), 130.0, 0.5, Color(1.0, 0.93, 0.72), true)
	# 고층 건물 실루엣 (상승 구간 중·원경 — 멀수록 어둡게)
	_prop(root, "tower_block.svg", Vector2(3680, -96), -7, false, 1.0, Color(0.5, 0.5, 0.5))
	_prop(root, "tower_block.svg", Vector2(4560, -64), -7, true, 1.0, Color(0.65, 0.65, 0.65))
	_prop(root, "tower_block.svg", Vector2(3800, -480), -7, false, 1.0, Color(0.6, 0.6, 0.6))
	_prop(root, "tower_block.svg", Vector2(4350, -500), -7, true, 1.0, Color(0.5, 0.5, 0.5))
	_prop(root, "tower_block.svg", Vector2(4050, -790), -7, false, 1.0, Color(0.7, 0.7, 0.7))
	_light(root, "TowerWindowLight", Vector2(3753, -464), 110.0, 0.35, Color(1.0, 0.93, 0.72), true)
	# 가로등: 판자촌 바닥 2개 + 등반 발판 2개 (어두운 수직 등반의 리듬 광원)
	_lamp(root, "ShantyLamp1", 3830.0, 416.0, false)
	_lamp(root, "ShantyLamp2", 4620.0, 416.0, true)
	_lamp(root, "ClimbLampA3", 4144.0, 224.0, false)
	_lamp(root, "ClimbLampC3", 4208.0, -544.0, true)
	# 발광 구슬: 회색 전환 발판마다 (경로 안내 + 안전 지대 표시)
	_orb(root, "OrbG1", Vector2(4720, 12))
	_orb(root, "OrbG2", Vector2(3728, -372))
	_orb(root, "OrbG3", Vector2(4752, -756))
	# 옥상 위 달빛 — 골인 지점을 차갑고 넓은 빛으로 (깜빡임 없음)
	_light(root, "RooftopMoon", Vector2(4330, -1010), 750.0, 0.7, Color(0.82, 0.88, 1.0), false)
	# 발판 캡 일러스트 (고정 발판만 — 무색 발판은 칠 상태가 보여야 하므로 비움)
	_prop(root, "ledge_light.svg", Vector2(3776, 352), 1)           # A1
	_prop(root, "ledge_light.svg", Vector2(4096, 224), 1)           # A3
	_prop(root, "ledge_light.svg", Vector2(4480, 96), 1)            # A5
	_prop(root, "ledge_dark.svg", Vector2(4128, -160), 1)           # B3
	_prop(root, "ledge_dark.svg", Vector2(3744, -288), 1)           # B5
	_prop(root, "ledge_light.svg", Vector2(4160, -544), 1)          # C3
	_prop(root, "ledge_light.svg", Vector2(4544, -672), 1)          # C5
	_prop(root, "ledge_dark.svg", Vector2(4512, -800), 1)           # D1
	_prop(root, "ledge_dark.svg", Vector2(4240, -864), 1)           # 옥상
	_prop(root, "ledge_dark.svg", Vector2(4340, -864), 1)

	# ── 골인 지점 (zone3 옥상) → world_lab 이 클리어 연출 ─────────────────
	var exit := Area2D.new()
	exit.name = "ExitZone"
	exit.add_to_group("zone_exit")
	exit.position = Vector2(4330, -930)       # 옥상(y-27, 윗면 -864) 위 공중
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
	_world_label(root, "▲ 경계 위 = 자동으로 白", Vector2(-150 + PX, 206), 18, Color(0.98, 0.98, 0.98))
	_world_label(root, "▼ 경계 아래 = 자동으로 黑", Vector2(-150 + PX, 280), 18, Color(0.85, 0.85, 0.85))
	_world_label(root, "경계를 넘는 순간 색이 저절로 바뀐다 — 회색 발판에서 넘어라",
		Vector2(2300, 306), 14, Color(0.82, 0.82, 0.82))
	_world_label(root, "무색 발판을 칠해 상층으로", Vector2(2900, 20), 14, Color(0.9, 0.9, 0.9))
	_world_label(root, "다리 건너 ZONE 3 — 도시 ↗", Vector2(3380, 150), 17, Color(0.95, 0.95, 0.95))
	_world_label(root, "판자촌 — 위로 올라가라", Vector2(3700, 372), 17, Color(0.9, 0.9, 0.9))
	_world_label(root, "높이마다 색의 경계가 있다 · 회색 발판 = 안전", Vector2(4260, 60), 13, Color(0.8, 0.8, 0.8))
	_world_label(root, "🏁 GOAL", Vector2(4290, -940), 22, Color(0.98, 0.98, 0.98))

	DirAccess.make_dir_recursive_absolute("res://scenes/world_1")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "res://scenes/world_1/world_1.tscn")
	root.free()
	return err

# ── 지형 헬퍼 (build_zones.gd 와 동일) ──────────────────────────────────
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

# ── [v2 신규] ColorZone — 다각형 색 강제 구역 (docs/경계_색구역_시스템.md) ──
## rect(월드 px) 크기의 사각 ColorZone 을 만든다. white=true 면 백 구역.
## color_zone.tscn 을 인스턴스하는 대신 같은 구조(Area2D+CollisionPolygon2D)를
## 직접 조립한다 — 생성기가 폴리곤 좌표를 코드로 확정하기 위함 (로직은 동일 스크립트).
func _color_zone(root: Node, name_: String, rect: Rect2, white: bool) -> void:
	var zone := Area2D.new()
	zone.name = name_
	zone.set_script(load(COLOR_ZONE_SCRIPT))
	zone.set("zone_color", 1 if white else 0)   # ColorZone.ZoneColor { BLACK=0, WHITE=1 }
	var poly := CollisionPolygon2D.new()
	poly.name = "CollisionPolygon2D"            # color_zone.gd 의 _draw 가 이 이름을 찾는다
	poly.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	zone.add_child(poly)
	root.add_child(zone)
	zone.owner = root
	poly.owner = root

# ── [v2 신규] 프롭 일러스트 배치 (아래-왼쪽 기준점) ─────────────────────
## pos = 프롭이 "서 있는" 지면 좌표의 왼쪽 끝 (스프라이트 아랫변을 여기에 맞춘다).
## zone_visuals.gd 가 런타임에 <이름>_n.png 노멀맵을 찾아 CanvasTexture 로 감싼다.
func _prop(root: Node, file: String, pos: Vector2, z: int, flip: bool = false,
		scale_: float = 1.0, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = load(PROPS + file)
	var spr := Sprite2D.new()
	spr.name = "Prop_%s_%d" % [file.get_basename(), root.get_child_count()]
	spr.texture = tex
	spr.centered = false
	spr.position = pos - Vector2(0, tex.get_height() * scale_)
	spr.scale = Vector2(scale_, scale_)
	spr.flip_h = flip
	spr.z_index = z
	spr.modulate = tint                          # 멀리 있는 실루엣일수록 어둡게 (공기원근)
	root.add_child(spr)
	spr.owner = root

# ── [v2 신규] 광원 — zone_visuals.gd 플레이어 광원과 같은 라디얼 텍스처 ──
func _light(root: Node, name_: String, pos: Vector2, radius: float, energy: float,
		col: Color, flicker: bool) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var light := PointLight2D.new()
	light.name = name_
	if flicker:
		light.set_script(load(FLICKER_SCRIPT))   # 촛불식 미세 깜빡임 (light_flicker.gd)
	light.texture = tex
	light.texture_scale = radius * 2.0 / 256.0
	light.energy = energy
	light.color = col
	light.position = pos
	root.add_child(light)
	light.owner = root

# ── [v2 신규] 가로등 = 프롭 일러스트 + 램프 헤드 광원 한 세트 ───────────
## base_x = 받침 중심 x, ground_y = 지면 y. 전구는 SVG 로컬 (44, 31) 에 있다.
func _lamp(root: Node, name_: String, base_x: float, ground_y: float, flip: bool) -> void:
	# z=-1: 기둥이 플레이어 "뒤"에 서야 등반 중 캐릭터를 가리지 않는다
	# (스크린샷 검증에서 z=2 는 기둥이 캐릭터 앞을 지나가는 것을 확인 → 수정)
	_prop(root, "lamp_post.svg", Vector2(base_x - 28.0, ground_y), -1, flip)
	var bulb_x := base_x + (-16.0 if flip else 16.0)   # flip 시 전구가 반대쪽
	_light(root, name_, Vector2(bulb_x, ground_y - 149.0), 260.0, 1.0,
		Color(1.0, 0.95, 0.8), true)

# ── [v2 신규] 발광 구슬 = 작은 일러스트 + 은은한 광원 (중심점 기준) ─────
func _orb(root: Node, name_: String, center: Vector2) -> void:
	var tex: Texture2D = load(PROPS + "glow_orb.svg")
	var spr := Sprite2D.new()
	spr.name = name_ + "Sprite"
	spr.texture = tex
	spr.position = center
	spr.z_index = 2
	root.add_child(spr)
	spr.owner = root
	_light(root, name_ + "Light", center, 150.0, 0.6, Color(1, 1, 1), true)

# ── [v2 신규] 물웅덩이 — 가로등 빛이 수면에 반사되는 셰이더 스트립 ──────
## streak_x 아래가 가장 밝게 빛나고(반사 스트릭), 잔물결 반짝임이 흐른다.
func _puddle(root: Node, name_: String, x0: float, x1: float, y0: float, y1: float,
		streak_x: float) -> void:
	var poly := Polygon2D.new()
	poly.name = name_
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	poly.z_index = 2
	var sh := Shader.new()
	sh.code = "
shader_type canvas_item;
// 폴리곤이 (0,0) 노드에 월드 좌표로 찍혀 있으므로 VERTEX = 월드 좌표
varying vec2 wpos;
uniform float streak_x = 0.0;
void vertex() { wpos = VERTEX; }
void fragment() {
	// 잔물결 반짝임: 주기가 다른 사인파 2개의 곱 — 불규칙해 보이는 흐름
	float shimmer = sin(wpos.x * 0.16 + TIME * 2.1) * sin(wpos.x * 0.055 - TIME * 1.4);
	// 가로등 바로 아래가 가장 밝은 가우시안 반사 스트릭
	float streak = exp(-pow((wpos.x - streak_x) / 55.0, 2.0));
	float a = 0.10 + 0.28 * streak + max(shimmer, 0.0) * (0.05 + 0.22 * streak);
	// 스트릭 중심은 가로등과 같은 따뜻한 색, 주변은 차분한 회색
	vec3 col = mix(vec3(0.82), vec3(1.0, 0.95, 0.80), streak);
	COLOR = vec4(col, a);
}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	# 전구 x 좌표는 유니폼으로 전달 (셰이더 코드에 숫자를 문자열로 박으면
	# GDScript 의 float 출력 형식("1681" vs "1681.0")에 따라 파싱이 깨질 수 있음)
	mat.set_shader_parameter("streak_x", streak_x)
	poly.material = mat
	root.add_child(poly)
	poly.owner = root

# ── [v2 신규] zone3 밤하늘 — 아래(어둠) → 위(옅은 새벽) 세로 그라데이션 ──
func _sky(root: Node, rect: Rect2) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.20, 0.20, 0.24))   # 위 = 옅은 새벽 (상승할수록 밝아짐)
	grad.set_color(1, Color(0.04, 0.04, 0.055))  # 아래 = 판자촌의 어둠
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 16
	tex.height = 512
	var spr := Sprite2D.new()
	spr.name = "Zone3Sky"
	spr.texture = tex
	spr.centered = false
	spr.position = rect.position
	spr.scale = Vector2(rect.size.x / 16.0, rect.size.y / 512.0)
	spr.z_index = -12                            # 패럴랙스(-10~-8)보다도 뒤
	root.add_child(spr)
	spr.owner = root
