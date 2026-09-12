extends SceneTree
## ============================================================================
## [2026-09-06 STEP 10] STAGE 2 — 「대형 복도 + 장거리 계단」 전면 재구축
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/patch_STAGE2_대형화.gd -- --검증
##       → 아무것도 안 바꾸고 로드→pack→임시저장. 왕복 손실 검사.
##   godot --headless --path . -s res://tools/patch_STAGE2_대형화.gd
##       → 실제로 씬을 고쳐 쓴다.
##
## ▣ ★왜 빌더(`build_집_복도계단.gd`)를 안 쓰나
##   STAGE 1 STEP 8 과 같은 이유다. 빌더는 씬을 처음부터 다시 짓는다 →
##   에디터로 넣은 조명·카메라공간·반딧불 편집분이 날아간다.
##   이 도구는 **현재 씬을 로드해서 지우고 더하기만** 한다.
##
## ══════════════════════════════════════════════════════════════════════════
## ▣ ★★설계의 출발점 — "긴 계단"은 산수로 막혀 있었다 (STEP 9 실측)
## ══════════════════════════════════════════════════════════════════════════
##   층고 770 고정(거실 원화 바닥선) · 단차 ≤128(레벨검사 게이트) → 최소 7 단
##   가용 x 는 520…3160 = 2,640  →  직선이면 tread 2640/7 = **377 이 한계**
##   접으려 해도 겹치는 두 층의 간격이 ≥352 여야 하는데 770 으로는 안 나온다.
##
##   ★그래서 **복도를 오르막으로 만들었다.**
##     복도가 0 → −880 으로 오르면 계단 낙차가 770 → **1,650** 이 된다.
##     그러면 낙하 폴드(690)를 한 번 끼울 수 있고, 같은 x 를 **두 번** 쓰게 되어
##     tread 를 470~550 (기존 180 의 **2.6~3.1 배**) 로 뽑을 수 있다.
##     낙하 690 은 이 스테이지 `치명_낙하거리 900` 아래라 안전하다.
##
## ▣ ★★배경 — room.png 의 **아직 안 쓴 오른쪽 절반**을 쓴다
##   현재: crop(0,0,880,1200) ×2.90 한 장이 x −2000…552 만 덮는다.
##         → **x 552…1240 은 배경이 아예 없다**(계단 캡처의 평평한 회색 = 이것).
##   추가: crop(880,0,880,1200) ×2.90 → x 552…3104.
##         같은 그림의 **다른 부분**이다. 타일링도 반전도 늘이기도 아니다
##         (STAGE 1 v4 의 "구역 분할" 과 같은 논리). 원화는 한 픽셀도 안 변형한다.
##
## ▣ 규칙 3 검산 — x 가 겹치는 두 발판의 윗면 간격 ≥ 352
##     CB4(−440) · 바닥(0)                     440  ✔
##     CB5(−550) · 바닥(0)                     550  ✔
##     CB7(−770) · 바닥연장(0)                 770  ✔
##     ENTRY(−880) · B2(250)                  1130  ✔
##     A1(−770) · B1(140)                      910  ✔
##     A2(−660) · B0(30)                       690  ✔
##     B0(30) · 유령(660)                      630  ✔
##     B0(30) · 출구선반(580)                  550  ✔
##     B1(140) · 1F바닥(770)                   630  ✔
##     B2(250) · 1F바닥(770)                   520  ✔
##     B2(250) · 1층천장 아랫면(−30)           280 머리공간 ✔ (몸 96)
##
## ▣ 도달 검산 — 레벨검사 한계: 위 128 · 가로 204 · 아래 900(이 씬)
##     바닥 → CB1..CB3 : 상승 110 · 가로 0(뿌리내린 덩어리)      ✔
##     CB3 → CB4 → CB5 → CB6 → CB7 → ENTRY : 상승 110 · 가로 50 ✔
##     ENTRY → A1 : 하강 110 · 가로 50                           ✔
##     A1 → A2    : 하강 110 · 가로 50                           ✔
##     A2 → B0    : **낙하 690** (< 900)                          ✔
##     B0 → B1 → B2 : 하강 110 · 가로 50                          ✔
##     B2 → 1F바닥 : **낙하 520** (< 900)                         ✔
##     1F → 유령(660) → 출구선반(580) : 기존 그대로               ✔
##
## ⚠ 씬이 에디터에 열려 있으면 실행 뒤 "씬 → 저장된 씬 다시 불러오기".
## ============================================================================

const 씬경로 := "res://scenes/집/스테이지_2_복도계단.tscn"
const 검증경로 := "res://.godot/_patch2_왕복검사.tscn"

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const T_나무 := 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"
const T_나무_흰 := 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID_WHITE.tscn"
const T_유령 := 키트 + "GHOST_투명발판/TEMPLATE_GHOST_WOOD.tscn"
const T_벽돌 := 키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn"
const T_가시 := "res://scenes/장애물/가시.tscn"
const T_도약대 := "res://scenes/집/스마트월드_장애물/도약대.tscn"

const 단방향지형_S := preload("res://scripts/스마트월드/단방향지형.gd")
const 실내배경_S := preload("res://scripts/스마트월드/실내배경.gd")
const 발광체_S := preload("res://scripts/스마트월드/발광체.gd")
const 공통 := preload("res://tools/지형공통.gd")

const 발판두께 := 160.0
const 구조두께 := 300.0

## 새 카메라 리밋 — 복도가 −880 까지 오르므로 위를 −1300 까지 연다.
##   room.png 패널이 y −2755 까지 덮으므로 배경 밖이 안 보인다.
const 리밋 := Rect2(-2000.0, -1300.0, 5460.0, 2440.0)

## ── 배경 패널 2 (room.png 오른쪽 크롭) ──────────────────────────────────
const 원화_방 := "res://assets/background/room.png"
const 방_배율 := 2.90
const 방2_크롭 := Rect2(880.0, 0.0, 880.0, 1200.0)
const 방2_왼 := 552.0                       ## = 패널 1 의 오른쪽 끝. 그림이 그대로 이어진다
const 방2_위 := -2755.0
const 방2_크기 := Vector2(2552.0, 3480.0)   ## 880×1200 × 2.90 — 왜곡 0
const 원화_밝기 := 1.05

# ══════════════════════════════════════════════════════════════════════════
# 레이아웃 — [x0, x1, 윗면y]
# ══════════════════════════════════════════════════════════════════════════
## ▣ 복도 (오르막) — 흑백이 한 단씩 번갈아 나온다. 색이 곧 "Shift 를 눌러라" 다.
const CB1 := [-1490.0, -1110.0, -110.0]     ## WHITE · 뿌리  ★스폰(-1560) 을 안 덮는다
const CB2 := [-1110.0, -730.0, -220.0]      ## BLACK · 뿌리  ★★CB1 과 **맞붙인다**
const CB3 := [-730.0, -350.0, -330.0]       ## WHITE · 뿌리  ★★틈을 두면 바닥까지 뚫린 "우물" 이 되어 갇힌다(실측)
const CB4 := [-310.0, 420.0, -440.0]        ## ★유령 · 단방향 (730) — 복귀 도약대 드리프트 ±310 을 양쪽 다 받는다
const CB5 := [460.0, 860.0, -550.0]          ## BLACK + 가시 3칸
const CB6 := [900.0, 1300.0, -660.0]         ## WHITE · 단방향
const CB7 := [1340.0, 1740.0, -770.0]        ## BLACK
const ENTRY := [1780.0, 2090.0, -880.0]      ## WHITE · 계단 진입 landing
## ★[보정] 복도 바닥 "연장" 은 넣지 않는다.
##   넣어 봤더니 두 가지가 한꺼번에 터졌다(레벨검사 실측):
##     ① 1층 천장(아랫면 −30)과 이 바닥(0) 사이가 **30px** — 몸 96 이 안 들어간다.
##     ② 떨어진 플레이어가 그 바닥에 갇힌다(소프트락 2 곳).
##   → 대신 **기존 2층 바닥 위에 복귀 도약대**를 놓아 오르막으로 되돌려 보낸다.
const 복귀도약대_x := 55.0        ## CB4(−380…350) 한가운데 — 드리프트 ±310 이 −310/310 로 둘 다 CB4 안이다
const 복귀도약대_속도 := -1500.0   ## 상승 약 514 → CB4(−440) 를 74 넘긴다 · 되떨어져도 514 < 900

## ▣ 계단 — tread 470~550 (기존 180 의 2.6~3.1 배)
const A1 := [2140.0, 2690.0, -770.0]        ## BLACK  (550)
const A2 := [2740.0, 3160.0, -660.0]        ## WHITE  (420) ← LANDING A
const B0 := [2300.0, 2800.0, 30.0]           ## WHITE (500) ← LANDING B
##   ★★A2 와 **x 를 어긋나게** 놓아야 한다. 처음엔 A2 와 같은 2740…3160 에 뒀는데,
##   바로 밑이라 A2 가장자리에서 걸어 나가면 B0 을 **지나쳐** 1층 바닥까지 1430 을
##   떨어져 죽었다(런타임 실측). 레벨검사는 "가로 0 · 낙차 690" 으로 통과시킨다 —
##   모델이 못 보는 종류의 함정이다. 지금은 A2 왼끝(2740)에서 걸어 나가면
##   체공 0.6 초 × 390 = 드리프트 약 234 로 B0(2300…2800) 한복판에 떨어진다.
const B1 := [1700.0, 2250.0, 140.0]          ## ★유령 (550) 페인트 퍼즐 2
const B2 := [1150.0, 1650.0, 470.0]          ## 중립 BRICK (500) ← LANDING C
##   ★★250 에 뒀더니 B2 오른끝에서 1층으로 뛰어내릴 수가 없었다 — B1 슬래브(140…300)의
##   왼쪽 면이 딱 그 높이에서 벽이 된다(런타임 실측: x 1647 에서 막힘).
##   470 으로 내리면 B1 밑면(300)과 170 이 벌어져 몸 96 이 지나간다.

## 오른쪽 외벽 위쪽 보강 — A2 높이에서 방 밖으로 걸어 나가지 않게.
const 벽_오른_위쪽 := [3160.0, 3400.0, -1300.0]

## 가시 자리 (칸 3 = 폭 96)
const 가시_복도_x := 660.0                   ## CB5 한가운데
const 가시_계단_x := 1975.0                  ## B1 한가운데 — 유령 위라 칠한 뒤에만 만난다

## 지울 것 — 옛 계단·옛 천장·막다른 가구·복도를 막는 색 경계
const 지울것 := [
	"지형/SS_WOOD_STAIRS_01",          ## 옛 7 단(폭 180) — 새 계단으로 대체
	"지형/천장_계단실_SS_BRICK_01",     ## 옛 계단실 천장 — 계단이 옮겨갔다
	"지형/천장_좁은통로_SS_BRICK_01",   ## 아랫면 −200 이 새 오르막(−440~)을 막는다
	"지형/SS_WOOD_CHEST_01",           ## 궤짝 — 자리가 CB3 와 겹친다(Δ220 < 352)
	"지형/SS_WOOD_UNDERSTAIR_01",      ## STEP 9 실측 = 막다른 오르막
	"지형/SS_WOOD_TABLE_01",           ## 〃
	"오브젝트/경계_복도등",             ## 흰색 강제 구역이 BLACK 발판 CB2 를 덮어 즉사한다
	"오브젝트/ColorZone",              ## 테스트 잔재(폴리곤 기본값 그대로)
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
		push_error("PATCH2: 씬을 못 읽었다"); quit(1); return
	var 루트 := 씬.instantiate() as Node2D
	print("\n=== STAGE 2 대형화 %s===" % ("(검증 왕복만) " if _검증만 else ""))
	print("   기존 지형 %d · 전체 노드 %d"
		% [루트.get_node("지형").get_child_count(), _노드수(루트)])

	if not _검증만:
		_지우기(루트)
		_배경_패널2(루트)
		_복도(루트)
		_계단(루트)
		_구조물(루트)
		_신호(루트)
		_루트값(루트)
		print("   신규 후 지형 %d · 전체 노드 %d"
			% [루트.get_node("지형").get_child_count(), _노드수(루트)])

	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("PATCH2: pack 실패 %s" % error_string(e)); quit(1); return
	var 저장 := 검증경로 if _검증만 else 씬경로
	e = ResourceSaver.save(팩, 저장)
	if e != OK:
		push_error("PATCH2: 저장 실패 %s" % error_string(e)); quit(1); return
	print("   저장 → %s\n=== 끝 ===\n" % 저장)
	quit(0)


func _노드수(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _노드수(ch)
	return c


# ============================================================================
func _지우기(루트: Node2D) -> void:
	for 경로 in 지울것:
		var n := 루트.get_node_or_null(NodePath(경로))
		if n == null:
			print("   (없음) %s" % 경로)
			continue
		n.get_parent().remove_child(n)
		n.queue_free()
		print("   − %s" % 경로)


## ★1층 천장을 계단이 내려오는 자리만큼 잘라 낸다(x 2000 까지).
##   안 자르면 새 계단 B0/B1 이 천장 슬래브(−330…−30) 속에 박힌다.
func _구조물(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var 천장 := 지.get_node_or_null("천장_1층_SS_BRICK_01") as Node2D
	if 천장 != null:
		_점_다시(천장, _사각(1240.0, -330.0, 2000.0, -30.0))
		print("   ~ 천장_1층 을 x 1240…2000 으로 줄였다 (계단이 내려올 구멍)")

	# 오른쪽 외벽 위쪽 — A2(−660) 높이에서 방 밖으로 못 나가게 막는다.
	_지형(지, T_벽돌, "벽_오른위위_SS_BRICK_01",
		_사각(벽_오른_위쪽[0], 벽_오른_위쪽[2], 벽_오른_위쪽[1], -330.0), false, "구조")
	# 왼쪽 외벽 위쪽 — 복도가 −880 까지 오르므로 벽도 같이 올린다.
	_지형(지, T_벽돌, "벽_왼위위_SS_BRICK_01",
		_사각(-1940.0, -1300.0, -1700.0, -900.0), false, "구조")
	for 이름 in ["벽_오른위위_SS_BRICK_01", "벽_왼위위_SS_BRICK_01"]:
		_빛가림(지.get_node_or_null(이름) as Node2D, 루트)


# ============================================================================
func _복도(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var 위험 := _층(루트, "위험물")

	# ── ★복귀 도약대 — 오르막에서 떨어진 플레이어를 CB4 로 되돌려 보낸다 ──
	#   이게 없으면 CB3(뿌리내린 330 벽) 오른쪽 바닥이 **소프트락**이 된다
	#   (레벨검사가 실제로 2 곳을 잡았다).
	_도약대(_층(루트, "기믹"), "도약대_복귀", Vector2(복귀도약대_x, 30.0), 복귀도약대_속도)

	# ── 흑백 계단식 3 단. 바닥에 뿌리내린 덩어리라 규칙 3 과 무관하다 ──
	_지형(지, T_나무_흰, "CB1_WHITE_SS_WOOD", _사각(CB1[0], CB1[2], CB1[1], 300.0), true, "흰")
	_지형(지, T_나무_흰, "CB2_WHITE_SS_WOOD", _사각(CB2[0], CB2[2], CB2[1], 300.0), true, "검")
	# ★★[실측 정정] CB3 은 **중립(BRICK · 칠하기 불가)** 이다.
	#   처음에는 W→B→W 를 붙은 발판 사이에서 번갈아 놨는데, 런타임 시험에서
	#   16 구간 중 8 개가 죽었다. 이유: 단차 110 · 틈 40 이면 체공이 0.4 초뿐이라
	#   **너무 일찍 바꾸면 아직 닿아 있는 출발 발판과 색이 어긋나 죽고,**
	#   **늦게 바꾸면 도착 발판 색과 어긋나 죽는다.** 안전한 창이 사실상 없다.
	#   → 색 전환은 ①중립 발판 위(서서 천천히) ②긴 낙하 중(690/520) 에서만 하게 했다.
	#   중립은 **벽돌**로 만든다 — "나무 = 색 규칙 · 벽돌 = 구조물이라 안전" 이
	#   이 스테이지의 시각 언어가 된다(도형님 §10 재질 규칙과 같은 방향).
	_지형(지, T_벽돌, "CB3_NEUTRAL_SS_BRICK", _사각(CB3[0], CB3[2], CB3[1], 300.0), false, "중립")

	# ── ★페인트 퍼즐 1 — 유령 발판. 칠해야 실체가 된다 ──
	# ★OneWay — 복귀 도약대가 밑에서 뚫고 올라와 이 위에 선다(매트리스와 같은 문법).
	_지형(지, T_유령, "CB4_GHOST_SS_WOOD", _슬래브(CB4), true, "유령", 3, true)

	# ── 가시 발판 ──
	_지형(지, T_나무, "CB5_BLACK_SS_WOOD", _슬래브(CB5), true, "검")
	_가시(위험, "가시_복도", Vector2(가시_복도_x, CB5[2]), 3)

	# ── 단방향(밑에서 뚫고 올라간다) ──
	_지형(지, T_벽돌, "CB6_NEUTRAL_SS_BRICK", _슬래브(CB6), false, "중립", 0, true)
	_지형(지, T_나무_흰, "CB7_WHITE_SS_WOOD", _슬래브(CB7), true, "흰")
	_지형(지, T_벽돌, "ENTRY_NEUTRAL_SS_BRICK", _슬래브(ENTRY), false, "중립")


func _계단(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var 위험 := _층(루트, "위험물")

	_지형(지, T_나무, "STAIR_A1_BLACK_SS_WOOD", _슬래브(A1), true, "검")
	# LANDING A — A1 과 **같은 검정**. 여기서 색을 바꿀 필요가 없다.
	_지형(지, T_나무, "STAIR_A2_BLACK_SS_WOOD", _슬래브(A2), true, "검")
	# LANDING B — ★낙하 690 중에 검정→흰색으로 바꾼다. 체공 0.6 초라 여유가 있다.
	_지형(지, T_나무_흰, "STAIR_B0_WHITE_SS_WOOD", _슬래브(B0), true, "흰")
	# ★페인트 퍼즐 2 — 긴 단(550) 위의 유령. 칠해야 아래로 이어진다.
	_지형(지, T_유령, "STAIR_B1_GHOST_SS_WOOD", _슬래브(B1), true, "유령", 3)
	_가시(위험, "가시_계단", Vector2(가시_계단_x, B1[2]), 3)
	# LANDING C — 중립. 1층으로 뛰어내리기 전에 색을 고를 수 있다.
	_지형(지, T_벽돌, "STAIR_B2_NEUTRAL_SS_BRICK", _슬래브(B2), false, "중립")


func _루트값(루트: Node2D) -> void:
	루트.set("카메라_리밋", 리밋)
	print("   ~ 카메라 리밋 → %s" % 리밋)


func _신호(루트: Node2D) -> void:
	var 오 := 루트.get_node("오브젝트") as Node2D
	# §16 시각 유도 — 새로 생긴 상부 공간과 폴드 지점에만 최소로.
	var 자리 := [
		["신호_오르막", Vector2(-180.0, -560.0)],
		["신호_계단진입", Vector2(1790.0, -1000.0)],
		["신호_폴드", Vector2(2925.0, -300.0)],
	]
	for s in 자리:
		var f: Node2D = 발광체_S.new()
		f.name = String(s[0])
		f.position = s[1]
		f.set("종류", 발광체_S.종류_.구슬)
		f.set("빛색", Color(1.0, 0.97, 0.90))
		f.set("반경", 240.0)
		f.set("밝기", 1.30)
		f.set("깜빡임", 0.28)
		f.set("크기_흔들림", 0.30)
		오.add_child(f)


## ★배경 패널 2 — room.png 의 오른쪽 크롭. 패널 1 의 끝(552)에서 그림이 이어진다.
func _배경_패널2(루트: Node2D) -> void:
	if 루트.has_node("배경_2층_복도_오른쪽"):
		return
	var 판: Node2D = 실내배경_S.new()
	판.name = "배경_2층_복도_오른쪽"
	판.set("영역", Rect2(방2_왼, 방2_위, 방2_크기.x, 방2_크기.y))
	판.set("아래_방", 실내배경_S.방_.이층방)
	판.set("위_방", 실내배경_S.방_.이층방)
	판.set("그림_아래", load(원화_방))
	판.set("그림_원본영역", 방2_크롭)
	판.set("그림_맞춤", 실내배경_S.맞춤_.늘이기)
	판.set("그림_밝기", 원화_밝기)
	판.set("좌우반전", false)
	# ★`실내배경.gd` 는 전환_시작y·전환_끝y 가 기본값이면 코드 벽지가 원화를 덮는다.
	판.set("전환_시작y", 0.0)
	판.set("전환_끝y", 0.0)
	판.z_index = -60
	판.z_as_relative = false
	# 기존 1층 거실 패널(z −59)보다 뒤 → 겹치는 구간은 거실이 이긴다.
	루트.add_child(판)
	print("   + 배경_2층_복도_오른쪽  x %.0f…%.0f (room.png crop %s)"
		% [방2_왼, 방2_왼 + 방2_크기.x, 방2_크롭])


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


## [x0, x1, 윗면y] → 두께 160 슬래브
func _슬래브(판: Array) -> PackedVector2Array:
	return _사각(float(판[0]), float(판[2]), float(판[1]), float(판[2]) + 발판두께)


## SS2D 지형 하나.
##   종류: "검"=BLACK WOOD · "흰"=WHITE WOOD(시작상태 흰색) · "유령" · "구조"(칠 불가)
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
	var 중심 := (최소 + 최대) * 0.5
	지형.position = 중심

	지형.set("칠하기_허용", 칠가능)
	지형.set("위치별_판정", 칠가능)
	if 필요횟수 > 0:
		지형.set("필요횟수_수동", 필요횟수)
	# ★★유령 발판은 `전체_색칠_최대긴변`(기본 576) 을 반드시 풀어야 한다.
	#   긴 변이 576 을 넘으면 `부분칠만` 으로 강등돼 **아무리 쏴도 실체가 안 된다**
	#   (CB4 는 730 이라 실제로 3 발 뒤에도 layer 8 · 밟을수있나 false 였다 — 실측).
	#   0 = 크기 제한 없음. 발수는 위 `필요횟수_수동` 이 이미 3 으로 묶어 둔다.
	if 종류 == "유령":
		지형.set("전체_색칠_최대긴변", 0.0)
	# ⚠ 흰색·유령은 템플릿이 이미 `시작상태`/`무색일때_통과` 를 들고 있다. 건드리지 않는다.

	_점_다시(지형, 점들)
	if 단방향:
		var 폴 := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
		if 폴 != null:
			폴.one_way_collision = true
	층.add_child(지형)
	print("   + %-28s x %.0f…%.0f y %.0f  [%s]%s"
		% [이름, 최소.x, 최대.x, 최소.y, 종류, "  단방향" if 단방향 else ""])


## SS2D 점 배열 + 콜리전 폴리곤을 다시 굽는다.
func _점_다시(지형: Node2D, 월드점들: PackedVector2Array) -> void:
	var 최소 := 월드점들[0]
	var 최대 := 월드점들[0]
	for p in 월드점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	지형.position = (최소 + 최대) * 0.5

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
		push_warning("PATCH2(%s): 콜리전 오프셋 실패 → 원본 점 사용" % 지형.name)
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
	push_error("PATCH2: Template 안에서 SS2D 지형 노드를 못 찾았다")
	return 인스턴스


func _가시(층: Node2D, 이름: String, 발판윗면: Vector2, 칸수: int) -> void:
	var t: Node2D = (load(T_가시) as PackedScene).instantiate()
	t.name = 이름
	t.position = 발판윗면
	t.set("방향", 0)          # 위를 향한다
	t.set("칸수", 칸수)
	t.set("가시높이", 60.0)   # STAGE 1 과 같은 값 — 윗면 위로 30 만 솟는다
	층.add_child(t)
	print("   + %-28s (%.0f, %.0f) %d 칸" % [이름, 발판윗면.x, 발판윗면.y, 칸수])


## ★owner 를 직접 박는다 — SS2D 는 Template **인스턴스**라
##   `주인_지정()` 이 경계에서 멈춰 owner 없는 자식은 pack() 이 버린다(STEP 8 실측).
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


## 도약대 하나. 기존 `도약대.tscn` 을 그대로 쓴다(새 기믹을 만들지 않는다).
##   ⚠ 원점을 높이의 절반만큼 내려 **발판 윗면을 딛는 면과 flush** 로 만든다.
##     안 그러면 30px 턱이 생겨 벽이 된다(STAGE 1 실측).
func _도약대(층: Node2D, 이름: String, 자리: Vector2, 속도: float) -> void:
	var t: Node2D = (load(T_도약대) as PackedScene).instantiate()
	t.name = 이름
	t.position = 자리
	t.set("폭", 220.0)
	t.set("높이", 60.0)
	t.set("도약속도", 속도)
	t.set("색_제한", false)
	층.add_child(t)
	print("   + %-28s (%.0f, %.0f) 속도 %.0f" % [이름, 자리.x, 자리.y, 속도])
