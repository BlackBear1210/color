extends SceneTree
## ============================================================================
## [2026-09-06 STEP 12] STAGE 2 — 대형 복도·계단 스테이지 실제 제작
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/patch_STAGE2_STEP12.gd -- --검증
##   godot --headless --path . -s res://tools/patch_STAGE2_STEP12.gd
##
## STEP 11 에서 확정한 레이아웃을 그대로 짓는다.
##   Bounding Box  x −2000…6200 · y −1300…3400   (8200 × 4700)
##   1 층          y 770 → **3000**
##   실제 플레이 경로 목표 ≈ 27,000px
##
## ▣ 방식 — 현재 씬을 로드해서 **지형만 통째로 갈아 끼운다**
##   조명 8종 · 카메라공간 4 · 반딧불 2조 · 입구/출구통로 · Player 는 보존하고
##   좌표만 새 레이아웃에 맞춘다. 빌더(`build_집_복도계단.gd`)는 돌리지 않는다.
##
## ══════════════════════════════════════════════════════════════════════════
## ▣ ★★STEP 10 에서 실측으로 얻은 규칙 — 이번 레이아웃은 전부 여기에 맞췄다
## ══════════════════════════════════════════════════════════════════════════
## ① 뿌리내린 블록의 **아래 끝은 바닥 윗면(y 0)** 이다. 밑면(300)까지 내리면
##    바닥 슬래브 속에 380px 박힌다 — STEP 11 겹침 감사가 잡은 3 건이 전부 이것이다.
## ② x 가 겹치는 두 발판의 윗면 간격은 **≥352**. 아니면 아래 발판이 설 수 없는 면이 된다.
## ③ **바로 밑에 같은 x 로 깐 발판에는 내려갈 수 없다.** 가장자리에서 걸어 나가면
##    그 발판을 지나쳐 버린다. 폴드 착지면은 반드시 **x 를 어긋나게** 놓는다.
## ④ 유령 발판은 `전체_색칠_최대긴변`(576) 을 0 으로 풀어야 실체가 된다.
##    안 그러면 `부분칠만` 으로 강등돼 아무리 쏴도 안 굳는다.
## ⑤ ★색 전환은 **중립(BRICK · 칠 불가) 발판 위** 아니면 **긴 낙하 중**에만 시킨다.
##    단차 110 · 틈 40 짜리 자리에서 흑백을 번갈아 놓으면 체공 0.4 초 안에
##    "일찍 바꾸면 출발 발판과, 늦게 바꾸면 도착 발판과" 색이 어긋나 죽는다.
##    → 이 파일의 모든 인접 발판은 **같은 색이거나 사이에 중립**이 있다.
## ⑥ 바닥에 박힌 블록 사이에 틈을 두면 **우물**(소프트락)이 된다 → 맞붙인다.
##
## ▣ 재질 규칙 (도형님 §G)
##   WOOD  = 밟는 지형 — 바닥 · 계단 tread · 발판 · 유령 · 단방향
##   BRICK = 건축 구조 — 벽 · 천장 · **중립 안전 발판 / Landing**
## ============================================================================

const 씬경로 := "res://scenes/집/스테이지_2_복도계단.tscn"
const 검증경로 := "res://.godot/_patch12_왕복검사.tscn"

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const T_나무 := 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"
const T_나무_흰 := 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID_WHITE.tscn"
const T_유령 := 키트 + "GHOST_투명발판/TEMPLATE_GHOST_WOOD.tscn"
const T_벽돌 := 키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn"
const T_가시 := "res://scenes/장애물/가시.tscn"
const T_도약대 := "res://scenes/집/스마트월드_장애물/도약대.tscn"

const 단방향지형_S := preload("res://scripts/스마트월드/단방향지형.gd")
const 실내배경_S := preload("res://scripts/스마트월드/실내배경.gd")
const 카메라공간_S := preload("res://scripts/proto/카메라_공간.gd")
const 공통 := preload("res://tools/지형공통.gd")

const 두께 := 160.0        ## 발판
const 구조 := 300.0        ## 바닥·벽
const 일층 := 3000.0
const 리밋 := Rect2(-2000.0, -1300.0, 8200.0, 4700.0)

# ── 배경 ───────────────────────────────────────────────────────────────────
const 원화_거실 := "res://assets/background/livingroom.png"
const 거실_배율 := 0.9
## 거실 원화 바닥선 py 963 이 1층 바닥(3000)에 오도록 역산. **배율은 0.9 그대로** —
## 확대도 반복도 블러도 없다. 평행이동만 한다.
const 거실_위 := 일층 - 963.0 * 거실_배율          ## 2133.3
const 거실_왼 := 3900.0
const 거실_크기 := Vector2(1921.5, 1080.0)
const 원화_밝기 := 1.05

## ★계단실은 원화가 없다. `실내배경.gd` 의 `방_.복도` **코드 벽지**를 쓴다 —
##   허리 몰딩 · 벽 패널 · 늘어선 문 · 벽등을 영역 크기에 맞춰 절차적으로 그린다.
##   픽셀 확대가 아니라 벡터 드로잉이라 아무리 커도 흐려지지 않는다.
const 계단실_영역 := Rect2(1400.0, -1300.0, 4800.0, 4700.0)

# ══════════════════════════════════════════════════════════════════════════
# ★지형표 — [이름, x0, 윗면y, x1, 아랫면y, 종류, 옵션]
#   종류: "검" WOOD BLACK · "흰" WOOD WHITE · "유령" GHOST · "중립" BRICK(칠 불가)
#         "구조" BRICK/WOOD 구조물(칠 불가 · 벽/천장/바닥)
#   옵션: "1way" 단방향 · "ghost3" 유령 3발
# ══════════════════════════════════════════════════════════════════════════
const 지형표 := [
	# ── 껍데기 (BRICK 구조) ────────────────────────────────────────────
	["벽_왼위_SS_BRICK", -2000, -1300, -1700, -170, "구조B", ""],
	["벽_왼아래_SS_BRICK", -2000, 0, -1700, 300, "구조B", ""],
	["벽_오른위_SS_BRICK", 6000, -1300, 6200, 2830, "구조B", ""],
	["벽_오른아래_SS_BRICK", 6000, 3000, 6200, 3300, "구조B", ""],
	["천장_2층복도_SS_BRICK", -1700, -1300, 1450, -1150, "구조B", ""],
	["천장_1층_SS_BRICK", 2400, 2150, 4600, 2300, "구조B", ""],

	# ── 바닥 (WOOD 구조물 · 색 규칙 밖 = 중립이라 여기서 색을 바꿀 수 있다) ──
	["바닥_2층_SS_WOOD", -1700, 0, 900, 300, "구조W", ""],
	["바닥_1층_SS_WOOD", 2400, 일층, 6000, 일층 + 구조, "구조W", ""],

	# ══ CORRIDOR A — 긴 진입 (y 0 · x −1700…900) ══════════════════════
	# 뿌리내린 블록. ★아래 끝은 바닥 **윗면 0** 이다(규칙 ①).
	["A_W1_SS_WOOD", -1550, -110, -1200, 0, "흰", ""],
	["A_B1_SS_WOOD", -1000, -110, -650, 0, "검", ""],
	["A_W2_SS_WOOD", -450, -110, -100, 0, "흰", ""],
	["A_B2_SS_WOOD", 100, -110, 400, 0, "검", ""],

	# ══ CORRIDOR B — 상승 플랫포밍 (y −480 / −590 · 오른→왼) ═══════════
	["B_LAND_SS_BRICK", 350, -480, 1200, -480 + 두께, "중립", "1way"],
	["B_P1_SS_WOOD", 30, -590, 320, -590 + 두께, "검", ""],
	["B_N1_SS_BRICK", -310, -480, -10, -480 + 두께, "중립", ""],
	["B_P2_SS_WOOD", -660, -590, -360, -590 + 두께, "흰", ""],
	["B_N2_SS_BRICK", -1010, -480, -710, -480 + 두께, "중립", ""],
	["B_P3_SS_WOOD", -1400, -590, -1060, -590 + 두께, "검", ""],

	# ══ CORRIDOR C — 긴 Paint 구간 (y −950 · 왼→오른) ═════════════════
	["C_LAND_SS_BRICK", -1680, -950, -950, -950 + 두께, "중립", "1way"],
	["C_P1_SS_WOOD", -900, -950, -600, -950 + 두께, "검", ""],
	["C_N1_SS_BRICK", -550, -950, -250, -950 + 두께, "중립", ""],
	["C_P2_SS_WOOD", -200, -950, 150, -950 + 두께, "흰", ""],
	["C_GHOST_SS_WOOD", 200, -950, 800, -950 + 두께, "유령", "ghost3"],
	["C_N2_SS_BRICK", 850, -950, 1150, -950 + 두께, "중립", ""],
	["C_P3_SS_WOOD", 1200, -950, 1550, -950 + 두께, "검", ""],

	# ══ CORRIDOR D — 하강 · 위험 (y −950 → −510) ══════════════════════
	["CD1_SS_WOOD", 1600, -840, 1950, -840 + 두께, "검", ""],
	["CD_N_SS_BRICK", 2000, -730, 2300, -730 + 두께, "중립", ""],
	["CD2_SS_WOOD", 2350, -620, 2700, -620 + 두께, "검", ""],
	["STAIR_ENTRY_SS_BRICK", 2750, -510, 3250, -510 + 두께, "중립", ""],

	# ══ LONG STAIR A — 기본 (오른쪽 · tread 550) ═══════════════════════
	["STAIR_A1_SS_WOOD", 3300, -400, 3850, -400 + 두께, "검", ""],
	["STAIR_A2_SS_WOOD", 3850, -290, 4400, -290 + 두께, "검", ""],
	["STAIR_A3_SS_BRICK", 4400, -180, 4950, -180 + 두께, "중립", ""],
	["STAIR_A4_SS_WOOD", 4950, -70, 5500, -70 + 두께, "흰", ""],
	["LANDING_A_SS_BRICK", 5550, 430, 6000, 430 + 두께, "중립", ""],

	# ══ LONG STAIR B — Paint (왼쪽) ═══════════════════════════════════
	["STAIR_B1_SS_WOOD", 4950, 540, 5500, 540 + 두께, "흰", ""],
	["STAIR_B2_GHOST_SS_WOOD", 4400, 650, 4950, 650 + 두께, "유령", "ghost3"],
	["STAIR_B3_SS_BRICK", 3850, 760, 4400, 760 + 두께, "중립", ""],
	["STAIR_B4_SS_WOOD", 3300, 870, 3850, 870 + 두께, "검", ""],
	["PB1_SS_WOOD", 2900, 980, 3250, 980 + 두께, "검", ""],
	["LANDING_B_SS_BRICK", 2200, 1480, 3000, 1480 + 두께, "중립", ""],

	# ══ LONG STAIR C — 위험 (오른쪽) ══════════════════════════════════
	["STAIR_C1_SS_WOOD", 3050, 1590, 3600, 1590 + 두께, "검", ""],
	["STAIR_C2_SS_WOOD", 3600, 1700, 4150, 1700 + 두께, "검", ""],
	["STAIR_C3_SS_BRICK", 4150, 1810, 4700, 1810 + 두께, "중립", ""],
	["STAIR_C4_SS_WOOD", 4700, 1920, 5250, 1920 + 두께, "흰", ""],
	["LANDING_C_SS_BRICK", 5350, 2310, 6000, 2310 + 두께, "중립", ""],

	# ══ LONG STAIR D — 종합 (왼쪽) ════════════════════════════════════
	["STAIR_D1_SS_WOOD", 4800, 2420, 5350, 2420 + 두께, "흰", ""],
	["STAIR_D2_GHOST_SS_WOOD", 4250, 2530, 4800, 2530 + 두께, "유령", "ghost3"],
	["STAIR_D3_SS_WOOD", 3700, 2640, 4250, 2640 + 두께, "흰", ""],
]

## 도약대 — [이름, x, 딛는 면 y, 속도]
##   상승 = 167.24 × (v/855.66)².  −1550 → **549**.  치명 900 아래라 빗맞아도 안 죽는다.
const 도약대표 := [
	["도약대_복도A", 700.0, 0.0, -1550.0],      ## 바닥 → B_LAND(−480) · 여유 69
	["도약대_복도B", -1300.0, -590.0, -1550.0], ## B_P3 → C_LAND(−950) · 여유 189
]

## 가시 — [이름, x, 발판 윗면 y, 칸수]
const 가시표 := [
	["가시_복도D", 2525.0, -620.0, 3],
	["가시_계단C", 3875.0, 1700.0, 3],
	["가시_계단D", 3975.0, 2640.0, 3],
]

## 반딧불 신호 — 방향 유도(§L). 새 광원 시스템을 만들지 않는다.
const 신호표 := [
	["신호_상승A", Vector2(700.0, -220.0)],
	["신호_상승B", Vector2(-1300.0, -800.0)],
	["신호_계단입구", Vector2(3000.0, -680.0)],
	["신호_폴드A", Vector2(5700.0, 180.0)],
	["신호_폴드B", Vector2(2600.0, 1240.0)],
	["신호_폴드C", Vector2(5600.0, 2100.0)],
	["신호_1층", Vector2(3500.0, 2820.0)],
]

var _검증만 := false


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--검증":
			_검증만 = true

	var 씬 := load(씬경로) as PackedScene
	if 씬 == null:
		push_error("STEP12: 씬을 못 읽었다"); quit(1); return
	var 루트 := 씬.instantiate() as Node2D
	print("\n=== STAGE 2 STEP 12 %s===" % ("(검증 왕복만) " if _검증만 else ""))
	print("   기존 지형 %d · 전체 노드 %d"
		% [루트.get_node("지형").get_child_count(), _노드수(루트)])

	if not _검증만:
		_지형_전부_지우기(루트)
		_지형_짓기(루트)
		_기믹(루트)
		_배경(루트)
		_오브젝트_이동(루트)
		_카메라공간(루트)
		_루트값(루트)
		print("   신규 지형 %d · 전체 노드 %d"
			% [루트.get_node("지형").get_child_count(), _노드수(루트)])

	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("STEP12: pack 실패 %s" % error_string(e)); quit(1); return
	var 저장 := 검증경로 if _검증만 else 씬경로
	e = ResourceSaver.save(팩, 저장)
	if e != OK:
		push_error("STEP12: 저장 실패 %s" % error_string(e)); quit(1); return
	print("   저장 → %s\n=== 끝 ===\n" % 저장)
	quit(0)


func _노드수(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _노드수(ch)
	return c


# ============================================================================
func _지형_전부_지우기(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var n := 지.get_child_count()
	for c in 지.get_children():
		지.remove_child(c)
		c.queue_free()
	print("   − 기존 지형 %d 개 전부 제거" % n)
	# 옛 기믹·장식도 정리한다(새 계단에 맞지 않는다).
	for 경로 in ["기믹", "위험물", "장식_앞", "장식_뒤",
			"오브젝트/신호_오르막", "오브젝트/신호_계단진입", "오브젝트/신호_폴드"]:
		var x := 루트.get_node_or_null(NodePath(경로))
		if x != null:
			x.get_parent().remove_child(x)
			x.queue_free()
			print("   − %s" % 경로)


func _지형_짓기(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var 수 := {"검": 0, "흰": 0, "유령": 0, "중립": 0, "구조B": 0, "구조W": 0}
	for r in 지형표:
		var 종류: String = r[5]
		var 옵션: String = r[6]
		var 템플릿 := T_나무
		var 칠가능 := true
		match 종류:
			"흰": 템플릿 = T_나무_흰
			"유령": 템플릿 = T_유령
			"중립": 템플릿 = T_벽돌; 칠가능 = false
			"구조B": 템플릿 = T_벽돌; 칠가능 = false
			"구조W": 템플릿 = T_나무; 칠가능 = false
		_지형(지, 템플릿, String(r[0]),
			_사각(float(r[1]), float(r[2]), float(r[3]), float(r[4])),
			칠가능, 종류, 3 if 옵션 == "ghost3" else 0, 옵션 == "1way")
		수[종류] = int(수[종류]) + 1
	print("   재질 — WOOD 검%d 흰%d 유령%d 바닥%d  |  BRICK 중립%d 구조%d"
		% [수["검"], 수["흰"], 수["유령"], 수["구조W"], 수["중립"], 수["구조B"]])

	# 빛가림 — 실제로 빛을 가려야 하는 큰 건축물에만(§M).
	for 이름 in ["벽_왼위_SS_BRICK", "벽_오른위_SS_BRICK",
			"천장_2층복도_SS_BRICK", "천장_1층_SS_BRICK"]:
		_빛가림(지.get_node_or_null(이름) as Node2D, 루트)


func _기믹(루트: Node2D) -> void:
	var 기믹 := _층(루트, "기믹")
	for t in 도약대표:
		_도약대(기믹, String(t[0]), Vector2(float(t[1]), float(t[2]) + 30.0), float(t[3]))
	var 위험 := _층(루트, "위험물")
	for s in 가시표:
		_가시(위험, String(s[0]), Vector2(float(s[1]), float(s[2])), int(s[3]))
	var 오 := 루트.get_node("오브젝트") as Node2D
	# ⚠ 두 번 돌리면 반딧불이 겹쳐 쌓인다 — 먼저 지운다(멱등성).
	for g0 in 신호표:
		var 옛 := 오.get_node_or_null(String(g0[0]))
		if 옛 != null:
			오.remove_child(옛); 옛.queue_free()
	for g in 신호표:
		_신호(오, String(g[0]), g[1])


# ============================================================================
func _배경(루트: Node2D) -> void:
	# ① 1층 거실 원화 — **배율 0.9 그대로 평행이동만**.
	var 거실 := 루트.get_node_or_null("배경_1층_거실원화") as Node2D
	if 거실 != null:
		거실.set("영역", Rect2(거실_왼, 거실_위, 거실_크기.x, 거실_크기.y))
	# ② 1층 앞바닥 띠 — 원화 py 975 아래만. 거실과 같이 내려간다.
	var 앞 := 루트.get_node_or_null("앞바닥_1층") as Node2D
	if 앞 != null:
		앞.set("영역", Rect2(거실_왼, 거실_위 + 975.0 * 거실_배율,
			거실_크기.x, (1200.0 - 975.0) * 거실_배율))
	# ③ ★계단실 — 원화가 없다. `방_.복도` 코드 벽지를 깐다.
	var 판 := 루트.get_node_or_null("배경_계단실") as Node2D
	if 판 == null:
		판 = 실내배경_S.new()
		판.name = "배경_계단실"
		루트.add_child(판)
	if true:
		판.set("영역", 계단실_영역)
		판.set("아래_방", 실내배경_S.방_.복도)
		판.set("위_방", 실내배경_S.방_.복도)
		판.set("그림_아래", null)          # null 이면 코드 벽지를 그린다
		# ★코드 벽지는 0.15~0.40 대역으로 그려진다 — 거기에 CanvasModulate 0.62 가 곱해지면
		#   거의 검정이 된다(실측). 원화용 1.05 가 아니라 2.0 을 준다.
		판.set("그림_밝기", 2.0)
		판.set("전환_시작y", 0.0)          # ⚠ 이 두 값을 안 끄면 위·아래 방이 섞인다
		판.set("전환_끝y", 0.0)
		# ★★z_index 를 직접 쓰면 안 된다 — `실내배경.gd` 의 `깊이`(기본 −60)가
		#   런타임에 z_index 를 덮어쓴다. 그래서 계단실 벽지가 거실 원화(−60)와 같은 z 가 되고
		#   나중에 추가된 쪽이 앞에 그려져 **거실 원화를 가렸다**(실측).
		판.set("깊이", -62)
		판.z_index = -62
		판.z_as_relative = false
		print("   + 배경_계단실 (코드 벽지 · 방_.복도)  %s" % 계단실_영역)


func _오브젝트_이동(루트: Node2D) -> void:
	var 오 := 루트.get_node("오브젝트") as Node2D
	# 출구통로 — 1층과 함께 내려간다.
	var 출구 := 오.get_node_or_null("출구통로") as Node2D
	if 출구 != null:
		출구.position = Vector2(6000.0, 일층)
		print("   ~ 출구통로 → (6000, %.0f)" % 일층)
	# 흰색 강제 구역(경계_반딧불이) — 1층 출구 앞으로.
	var 경계 := 오.get_node_or_null("경계_반딧불이") as Node2D
	if 경계 != null:
		경계.position = Vector2(5400.0, 2760.0)
	# 1층 반딧불 무리도 같이.
	var 홀 := 오.get_node_or_null("반딧불_홀") as Node2D
	if 홀 != null:
		홀.position += Vector2(2600.0, 2230.0)
	# 1층 조명 3종을 새 1층 위치로.
	for 쌍 in [["홀천장등", Vector2(4800.0, 2400.0)],
			["등_홀샹들리에", Vector2(4900.0, 2350.0)],
			["계단창빛", Vector2(4300.0, 700.0)]]:
		var n := 오.get_node_or_null(String(쌍[0])) as Node2D
		if n != null:
			n.position = 쌍[1]


## 카메라 공간 — 새 레이아웃에 맞춰 자리·크기만 다시 잡는다(시스템은 그대로).
func _카메라공간(루트: Node2D) -> void:
	var 오 := 루트.get_node("오브젝트") as Node2D
	var 표 := [
		["카메라_2층복도", Vector2(-400.0, -200.0), Vector2(2600.0, 900.0), 1.15],
		["카메라_좁은통로", Vector2(-100.0, -900.0), Vector2(3200.0, 700.0), 1.05],
		["카메라_계단", Vector2(4300.0, 900.0), Vector2(3000.0, 2600.0), 0.85],
		["카메라_1층홀", Vector2(4200.0, 2800.0), Vector2(3400.0, 900.0), 0.80],
	]
	for r in 표:
		var c := 오.get_node_or_null(String(r[0])) as Node2D
		if c == null:
			continue
		c.position = r[1]
		c.set("크기", r[2])
		c.set("줌_배수", float(r[3]))
		var 모양 := c.get_node_or_null("판정") as CollisionShape2D
		if 모양 != null and 모양.shape is RectangleShape2D:
			(모양.shape as RectangleShape2D).size = r[2]


func _루트값(루트: Node2D) -> void:
	루트.name = "스테이지_2_복도계단"          # 파일 이름과 맞춘다(옛 이름 `집_복도계단`)
	루트.set("스테이지_이름", "2 · 복도와 계단")
	루트.set("카메라_리밋", 리밋)
	루트.set("낙사_y", 3800.0)
	print("   ~ 리밋 %s · 낙사_y 3800 · 루트 이름 정정" % 리밋)


# ============================================================================
# 부품
# ============================================================================
func _층(루트: Node2D, 이름: String) -> Node2D:
	var n := 루트.get_node_or_null(이름) as Node2D
	if n == null:
		n = Node2D.new()
		n.name = 이름
		루트.add_child(n)
	return n


func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])


func _지형(층: Node2D, 템플릿: String, 이름: String, 점들: PackedVector2Array,
		칠가능: bool, 종류: String, 필요횟수: int = 0, 단방향: bool = false) -> void:
	var 씬 := load(템플릿) as PackedScene
	var 지형: Node2D = _모양노드(씬.instantiate())
	if 단방향:
		_스크립트_갈아끼우기(지형, 단방향지형_S)
	지형.name = 이름

	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	지형.position = (최소 + 최대) * 0.5

	지형.set("칠하기_허용", 칠가능)
	지형.set("위치별_판정", 칠가능)
	if 필요횟수 > 0:
		지형.set("필요횟수_수동", 필요횟수)
	# ★규칙 ④ — 유령은 크기 제한을 풀어야 실체가 된다.
	if 종류 == "유령":
		지형.set("전체_색칠_최대긴변", 0.0)

	_점_굽기(지형, 점들)
	if 단방향:
		var 폴 := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
		if 폴 != null:
			폴.one_way_collision = true
	층.add_child(지형)


func _점_굽기(지형: Node2D, 월드점들: PackedVector2Array) -> void:
	var 점배열 := SS2D_Point_Array.new()
	var 로컬 := PackedVector2Array()
	for p in 월드점들:
		로컬.append(p - 지형.position)
	점배열.add_points(로컬)
	점배열.close_shape()
	지형.set_point_array(점배열)

	var 폴리 := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 == null:
		return
	var 생성기 := SS2D_CollisionGen.new()
	생성기.collision_size = 지형.collision_size
	생성기.collision_offset = 지형.collision_offset
	var 구운것 := 생성기.generate_filled(점배열.get_tessellated_points())
	if 구운것.size() < 3:
		push_warning("STEP12(%s): 콜리전 오프셋 실패 → 원본 점 사용" % 지형.name)
		구운것 = 점배열.get_tessellated_points()
	폴리.polygon = 구운것


## ★`set_script()` 은 SS2D 재질을 날린다 — 5 개 속성을 백업·복원한다.
func _스크립트_갈아끼우기(지형: Node2D, 스크립트: Script) -> void:
	var 보관 := {}
	for k in ["shape_material", "collision_size", "collision_offset",
			"collision_update_mode", "collision_polygon_node_path"]:
		보관[k] = 지형.get(k)
	지형.set("shape_material", null)
	지형.set_script(스크립트)
	for k in 보관:
		지형.set(k, 보관[k])


func _모양노드(인스턴스: Node2D) -> Node2D:
	if 인스턴스.has_method("get_point_array"):
		return 인스턴스
	for 자식 in 인스턴스.get_children():
		if 자식 is Node2D and 자식.has_method("get_point_array"):
			var 모양: Node2D = 자식
			인스턴스.remove_child(모양)
			모양.owner = null
			인스턴스.queue_free()
			return 모양
	push_error("STEP12: Template 안에서 SS2D 지형 노드를 못 찾았다")
	return 인스턴스


func _도약대(층: Node2D, 이름: String, 자리: Vector2, 속도: float) -> void:
	var t: Node2D = (load(T_도약대) as PackedScene).instantiate()
	t.name = 이름
	t.position = 자리
	t.set("폭", 220.0)
	t.set("높이", 60.0)
	t.set("도약속도", 속도)
	t.set("색_제한", false)
	층.add_child(t)


func _가시(층: Node2D, 이름: String, 발판윗면: Vector2, 칸수: int) -> void:
	var t: Node2D = (load(T_가시) as PackedScene).instantiate()
	t.name = 이름
	t.position = 발판윗면
	t.set("방향", 0)
	t.set("칸수", 칸수)
	t.set("가시높이", 60.0)
	층.add_child(t)


func _신호(층: Node2D, 이름: String, 자리: Vector2) -> void:
	var 발광체_S := load("res://scripts/스마트월드/발광체.gd") as Script
	var f: Node2D = 발광체_S.new()
	f.name = 이름
	f.position = 자리
	f.set("종류", 0)               # 구슬
	f.set("빛색", Color(1.0, 0.97, 0.90))
	f.set("반경", 260.0)
	f.set("밝기", 1.30)
	f.set("깜빡임", 0.28)
	f.set("크기_흔들림", 0.30)
	층.add_child(f)


## ★owner 를 직접 박는다 — SS2D 는 Template 인스턴스라 `주인_지정()` 이
##   경계에서 멈춰, owner 없는 자식은 `pack()` 이 통째로 버린다(STEP 8 실측).
func _빛가림(지형: Node2D, 루트: Node2D) -> void:
	if 지형 == null or 지형.has_node("빛가림"):
		return
	var 폴리 := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 == null:
		return
	var oc := LightOccluder2D.new()
	oc.name = "빛가림"
	var 모양 := OccluderPolygon2D.new()
	모양.polygon = 폴리.polygon
	모양.closed = true
	oc.occluder = 모양
	지형.add_child(oc)
	oc.owner = 루트
