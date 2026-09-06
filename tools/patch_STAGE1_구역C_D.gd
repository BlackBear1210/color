extends SceneTree
## ============================================================================
## [2026-09-06 STEP 8] STAGE 1 — 중앙 공백에 구역 C(책장 상승로) · D(상부 능선)를 심는다
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/patch_STAGE1_구역C_D.gd -- --검증
##       → 아무것도 안 바꾸고 **로드 → pack → 임시 저장**만 해서 왕복 손실을 검사한다
##   godot --headless --path . -s res://tools/patch_STAGE1_구역C_D.gd
##       → 실제로 노드를 심고 씬을 덮어쓴다
##
## ▣ ★★왜 `build_스테이지_1_2층방.gd` 를 안 쓰는가
##   그 빌더는 씬을 **처음부터 다시 짓는다.** STEP 4~6 에서 에디터로 넣은 조명·노멀맵·
##   Light2D·LightOccluder2D 편집분이 전부 날아간다(AGENTS.md §4).
##   → 이 도구는 **현재 씬을 로드해서 노드를 더하기만** 한다. 기존 노드는 한 개도 안 건드린다.
##
## ▣ 무엇을 더하나 — 전부 원화 `room.png` 에 이미 그려져 있는 가구 위다
##   구역 C(책장 상승로) : 책상 윗면 → 책장 보드 → 책장 윗면 (도약대 3 개로 오른다)
##   구역 D(상부 능선)   : 옷장 몰딩 2 장 → 협탁 → (기존)매트리스 → 바닥
##
## ▣ ★★왜 "지그재그 점프" 가 아니라 "도약대 사슬" 인가 (설계상 어쩔 수 없다)
##   `레벨검사` 의 실측 규칙:  점프로 오를 수 있는 단차 = 점프높이 160 × 0.80 = **128**
##   SS2D 기하 규칙:          같은 x 를 공유하는 두 발판의 윗면 간격 ≥ **352**
##                            (아니면 아래 발판이 "설 수 없는 면" 이 된다 — v4 에서 실증)
##   두 줄 지그재그는 같은 열의 두 발판이 **2 × 상승** 만큼 떨어진다.
##     352 ≤ 2 × 상승  →  상승 ≥ 176  >  128.  ★수학적으로 성립하지 않는다.
##   세 줄·네 줄로 늘리면 열 사이를 건너뛰는 가로거리가 점프거리(204)를 넘는다.
##   → 이 축척(배율 2.90)에서 **점프만으로 올라가는 사다리는 만들 수 없다.**
##     `도약대` 는 상승 450 을 주므로 착지면 간격이 저절로 ≥352 가 된다. 유일한 해답이다.
##     (기존 1-4 의 `도약대_침대밑` 이 이미 같은 문법으로 매트리스에 올라간다)
##
## ▣ ★새 발판이 전부 OneWay 인 이유
##   도약대는 발판 **아래**에서 쏘아 올린다. 발판이 단단하면 밑면에 부딪혀 못 올라간다.
##   `단방향지형.gd` = 아래에서 위로 통과 · 위에서는 착지. 매트리스가 쓰는 그 스크립트다.
##   덤으로 1-3(바닥 통행)이 새 발판 밑을 그대로 지나간다 — 기존 동선 회귀 0.
##
## ▣ 검산 (전부 `레벨검사` 의 실측 한계로)
##     한계: 위로 128 (도약대 위면 450) · 가로 204 · 아래로 520
##     바닥0   ─도약─→ 책상 −403     : 상승 403 ≤450 · 가로 0   ✔
##     책상    ─도약─→ 보드 −810     : 상승 407 ≤450 · 가로 50  ✔
##     보드    ─도약─→ 책장윗면 −1183: 상승 373 ≤450 · 가로 0   ✔
##     책장윗면 ──────→ 능선1 −1000  : 하강 183        · 가로 50  ✔
##     능선1   ──────→ 능선2 −830    : 하강 170        · 가로 50  ✔
##     능선2   ──────→ 협탁 −450     : 하강 380 ≤520  · 가로 37  ✔
##     협탁    ──────→ 매트리스 −435 : 상승  15 ≤128  · 가로 43  ✔
##
## ▣ 규칙 3 검산 (x 가 겹치는 두 발판의 윗면 간격 ≥ 352)
##     책상[300,1000]  · 보드[1050,1450]   → x 안 겹침                 ✔
##     보드[1050,1450] · 책장윗면[850,1550] → 겹침 · 간격 373 ≥ 352    ✔
##     책상[300,1000]  · 책장윗면[850,1550] → 겹침 · 간격 780          ✔
##     능선1[1600,1900]· 옷장[1566,2297]    → 겹침 · 간격 522          ✔
##     능선2[1950,2300]· 옷장[1566,2297]    → 겹침 · 간격 692          ✔
##     협탁[2337,2648] · 매트리스[2691,3825]→ x 안 겹침                 ✔
##
## ⚠ 이 씬이 에디터에 열려 있으면 실행 뒤 **"씬 → 저장된 씬 다시 불러오기"** 를 할 것.
## ============================================================================

const 씬경로 := "res://scenes/집/스테이지_1_2층방.tscn"
const 검증경로 := "res://.godot/_patch_왕복검사.tscn"

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const T_나무 := 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"
const T_도약대 := "res://scenes/집/스마트월드_장애물/도약대.tscn"

const 단방향지형_S := preload("res://scripts/스마트월드/단방향지형.gd")
const 발광체_S := preload("res://scripts/스마트월드/발광체.gd")
const 공통 := preload("res://tools/지형공통.gd")

# ── 게임플레이 절대 치수 (빌더와 같은 값) ────────────────────────────────
const 발판두께 := 160.0
## 도약대 — 기존 `도약대_침대밑` 과 **완전히 같은 값**을 쓴다.
##   상승 = 167.24 × (1435/855.66)² ≈ 470.  치명 낙하 520 아래라 빗맞아도 안 죽는다.
const 도약대_폭 := 220.0
const 도약대_높이 := 60.0
const 도약대_속도 := -1435.0
const 도약대_묻힘 := 도약대_높이 * 0.5      ## 30 — 발판 윗면을 딛는 면과 flush 로

# ══════════════════════════════════════════════════════════════════════════
# 구역 C — 책장 상승로 (원화 책상 · 책장)
# ══════════════════════════════════════════════════════════════════════════
## 원화 실측(배율 2.90): 책상 윗면 py 811 → −403 · 책장 윗면 py 542 → −1183
##   책장 선반칸 py 582/702/800/897 → −1067 / −719 / −435 / −154
##   보드는 py 674 자리(−800) 로 잡았다. 원화 선반칸 702(−719)를 그대로 쓰면
##   거기서 쏜 도약(상승 470)이 책장 윗면 −1183 을 **6px 차로** 스쳐 못 올라탄다.
##   −810 이면 여유 97 이 생긴다. (같은 함정을 1-4 매트리스에서 이미 겪었다)
const C_책상 := [300.0, 1000.0, -403.0]
const C_보드 := [1050.0, 1450.0, -810.0]
const C_책장윗 := [850.0, 1550.0, -1183.0]
const C_도약1 := 620.0      ## 바닥. 책장밑 크롤 천장(x 1015…1436) 밖이라 천장에 안 막힌다
const C_도약2 := 900.0      ## 책상 위. 드리프트 ±310 → 590 / 1210 둘 다 안전 착지
const C_도약3 := 1200.0     ## 보드 위. 드리프트 → 890 / 1510 둘 다 책장윗면[850,1550] 안

# ══════════════════════════════════════════════════════════════════════════
# 구역 D — 상부 능선 (옷장 앞 몰딩 → 협탁 → 기존 매트리스)
# ══════════════════════════════════════════════════════════════════════════
## 옷장(원화 x 540…792 → world 1566…2297)의 **앞면**에 붙은 몰딩 두 장.
## 옷장 윗면(−1522)에는 절대 안 닿는다 — 닿으면 1-1 로 되돌아가는 지름길이 생긴다.
const D_능선1 := [1600.0, 1900.0, -1000.0]
const D_능선2 := [1950.0, 2300.0, -830.0]
## 협탁 — 원화 x 806…913 → world 2337…2648 · 윗면 py 795 → −450
const D_협탁 := [2337.0, 2648.0, -450.0]

## 진행 신호(반딧불). 캄캄한 방에서 "이리 와" 를 말하는 유일한 수단.
const 신호_자리 := [
	Vector2(620.0, -180.0),     ## 1-3 끝 · 첫 도약대 바로 위
	Vector2(1200.0, -1300.0),   ## 책장 꼭대기 — 올라갈 목표
	Vector2(2490.0, -600.0),    ## 협탁 위 — 능선의 끝
]

var _검증만 := false
var _정리만 := false


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--검증":
			_검증만 = true
		if a == "--정리만":
			_정리만 = true

	var 씬 := load(씬경로) as PackedScene
	if 씬 == null:
		push_error("PATCH: 씬을 못 읽었다 → %s" % 씬경로)
		quit(1)
		return
	var 루트 := 씬.instantiate() as Node2D
	print("\n=== STAGE 1 · 구역 C/D 심기 %s===" % ("(검증 왕복만) " if _검증만 else ""))
	var 전_지형 := 루트.get_node("지형").get_child_count()
	print("   기존 지형 노드 %d 개 · 전체 노드 %d 개" % [전_지형, _노드수(루트)])

	if not _검증만:
		if not _정리만:
			_구역_C(루트)
			_구역_D(루트)
			_신호등들(루트)
		_빛가림_전부(루트)
		_고아_컬러존_정리(루트)
		print("   신규 후 지형 노드 %d 개 · 전체 노드 %d 개"
			% [루트.get_node("지형").get_child_count(), _노드수(루트)])

	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("PATCH: pack 실패 %s" % error_string(e))
		quit(1)
		return
	var 저장 := 검증경로 if _검증만 else 씬경로
	e = ResourceSaver.save(팩, 저장)
	if e != OK:
		push_error("PATCH: 저장 실패 %s" % error_string(e))
		quit(1)
		return
	print("   저장 → %s" % 저장)
	print("=== 끝 ===\n")
	quit(0)


func _노드수(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _노드수(ch)
	return c


# ============================================================================
# 구역 C
# ============================================================================
func _구역_C(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	var 기믹 := 루트.get_node("기믹") as Node2D

	# ① 책상 윗면 — 원화 책상(py 811) 그대로. OneWay 라 밑에서 도약해 뚫고 올라선다.
	#    1-3 은 이 밑(바닥 ~ −243)을 그대로 지나간다: 여유 243 > 몸 96 ✔
	_지형(지, "SS_WOOD_DESK_TOP_01", C_책상, true, false)

	# ② 책장 보드 — ★이 스테이지의 첫 **유령 발판**(칠해야 실체가 된다).
	#    책상 위 도약대의 착지면이라, 안 칠하면 도약해도 책상으로 되돌아 떨어진다
	#    (낙차 470 < 치명 520 → 죽지 않는다. 몇 번이든 다시 시도할 수 있다).
	#    ★색 안전: 안 칠한 지형은 검정으로 판정되고 플레이어 기본색도 검정이라
	#      검정 물감으로 칠하면 그대로 밟을 수 있다(색 퍼즐은 STAGE 3 부터라는 규칙 유지).
	_지형(지, "SS_WOOD_SHELF_BOARD_01", C_보드, true, true)

	# ③ 책장 윗면 — 원화 py 542 그대로. 구역 C 의 꼭대기이자 D 의 출발점.
	_지형(지, "SS_WOOD_BOOKCASE_TOP_01", C_책장윗, true, false)

	# ④ 도약대 3 개 — 사슬. 각 단은 상승 470 으로 다음 면을 47~97 넘긴다.
	_도약대(기믹, "도약대_책상밑", Vector2(C_도약1, 0.0 + 도약대_묻힘))
	_도약대(기믹, "도약대_책상위", Vector2(C_도약2, C_책상[2] + 도약대_묻힘))
	_도약대(기믹, "도약대_책장보드", Vector2(C_도약3, C_보드[2] + 도약대_묻힘))


# ============================================================================
# 구역 D
# ============================================================================
func _구역_D(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D

	# ① 옷장 상단 몰딩 — 책장 윗면에서 오른쪽으로 건너뛰는 첫 발판(하강 183 · 가로 50)
	_지형(지, "SS_WOOD_RIDGE_01", D_능선1, true, false)
	# ② 옷장 문 몰딩 — ★두 번째 유령 발판. 여기가 능선의 관문이다.
	#    못 칠하면 −1000 에서 협탁(−450)까지 550 = 치명 520 초과 → 갈 수 없다.
	_지형(지, "SS_WOOD_RIDGE_02", D_능선2, true, true)
	# ③ 협탁 — 원화 py 795 그대로. 여기서 기존 매트리스(−435)로 15 만 올라선다.
	_지형(지, "SS_WOOD_NIGHTSTAND_01", D_협탁, true, false)

	_빛가림_전부(루트)


## §13 — 빛가림은 **큰 구조물에만**. 작은 발판마다 만들지 않는다.
##   창문 주광이 책장·책상·협탁을 관통하는 것만 막는다.
func _빛가림_전부(루트: Node2D) -> void:
	var 지 := 루트.get_node("지형") as Node2D
	for 이름 in ["SS_WOOD_BOOKCASE_TOP_01", "SS_WOOD_DESK_TOP_01", "SS_WOOD_NIGHTSTAND_01"]:
		_빛가림(지.get_node_or_null(이름) as Node2D, 루트)


# ============================================================================
# 신호 · 정리
# ============================================================================
func _신호등들(루트: Node2D) -> void:
	var 오브젝트 := 루트.get_node("오브젝트") as Node2D
	for i in 신호_자리.size():
		var f: Node2D = 발광체_S.new()
		f.name = "신호_구역CD_%02d" % (i + 1)
		f.position = 신호_자리[i]
		f.set("종류", 발광체_S.종류_.구슬)
		f.set("빛색", Color(1.0, 0.97, 0.90))
		f.set("반경", 240.0)
		f.set("밝기", 1.30)
		f.set("깜빡임", 0.28)
		f.set("크기_흔들림", 0.30)
		오브젝트.add_child(f)


## §15 — 방 **밖**(x −1358…−284)에 떠 있는 테스트 잔재 ColorZone 을 뺀다.
##   ColorZone2 는 방 안(창가)에 있으므로 판단을 미루고 그대로 둔다.
func _고아_컬러존_정리(루트: Node2D) -> void:
	## ⚠ 노드 `position` 으로 판단하면 안 된다 — ColorZone 은 자식 CollisionPolygon2D 가
	##   오프셋을 크게 물고 있어서(에디터에서 폴리곤만 끌어 옮긴 흔적), 노드 자리는
	##   (2428, −916) 로 **방 안**인데 실제 영역은 x −1358…−284 로 방 밖이다.
	##   → 폴리곤의 **월드 경계**로 판단한다.
	for 이름 in ["ColorZone", "ColorZone2"]:
		var z := 루트.get_node_or_null(이름) as Node2D
		if z == null:
			continue
		var 폴리 := z.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if 폴리 == null or 폴리.polygon.size() < 3:
			continue
		var 최소 := 폴리.to_global(폴리.polygon[0])
		var 최대 := 최소
		for pt in 폴리.polygon:
			var w := 폴리.to_global(pt)
			최소 = 최소.min(w)
			최대 = 최대.max(w)
		if 최대.x < 300.0 or 최소.x > 5891.5:
			루트.remove_child(z)
			z.queue_free()
			print("   고아 %s 제거 — 영역 x %.0f…%.0f 는 방(300…5891) 밖이다"
				% [이름, 최소.x, 최대.x])
		else:
			print("   %s 유지 — 영역 x %.0f…%.0f · y %.0f…%.0f (방 안)"
				% [이름, 최소.x, 최대.x, 최소.y, 최대.y])


# ============================================================================
# 부품 — 빌더 `build_스테이지_1_2층방.gd` 의 것을 그대로 옮겨 왔다
# ============================================================================
## 축 정렬 사각형 (왼, 윗면, 오른, 아랫면) — 시계 방향.
func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])


## SS2D 발판 하나. 전부 **WOOD · OneWay · 칠할 수 있음**이다(방 안에서 밟는 것 = WOOD).
##   판: [x0, x1, 윗면y]
##   유령: 무색일 때 통과(= 칠해야 실체가 된다)
func _지형(층: Node2D, 이름: String, 판: Array, 칠가능: bool, 유령: bool) -> void:
	var 씬 := load(T_나무) as PackedScene
	var 지형: Node2D = _모양노드(씬.instantiate())
	_스크립트_갈아끼우기(지형, 단방향지형_S)
	지형.name = 이름

	var 점들 := _사각(float(판[0]), float(판[2]), float(판[1]), float(판[2]) + 발판두께)
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	var 중심 := (최소 + 최대) * 0.5
	지형.position = 중심

	지형.set("칠하기_허용", 칠가능)
	지형.set("무색일때_통과", 유령)
	지형.set("위치별_판정", 칠가능)

	var 점배열 := SS2D_Point_Array.new()
	var 로컬 := PackedVector2Array()
	for p in 점들:
		로컬.append(p - 중심)
	점배열.add_points(로컬)
	점배열.close_shape()
	지형.set_point_array(점배열)

	var 폴리 := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		var 생성기 := SS2D_CollisionGen.new()
		생성기.collision_size = 지형.collision_size
		생성기.collision_offset = 지형.collision_offset
		var 구운것 := 생성기.generate_filled(점배열.get_tessellated_points())
		if 구운것.size() < 3:
			push_warning("PATCH(%s): 콜리전 오프셋 실패 → 원본 점을 그대로 쓴다" % 이름)
			구운것 = 점배열.get_tessellated_points()
		폴리.polygon = 구운것
		폴리.one_way_collision = true

	층.add_child(지형)
	print("   + %-28s x %.0f…%.0f · 윗면 %.0f%s"
		% [이름, 판[0], 판[1], 판[2], "  ★유령(칠해야 실체)" if 유령 else ""])


## ★`set_script()` 은 SS2D 재질을 날린다 — 5 개 속성을 백업·복원해야 한다.
##   (빌더 머리말 참고. 안 하면 메시 0 장 = 지형이 화면에서 사라진다)
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
	push_error("PATCH: Template 안에서 SS2D 지형 노드를 못 찾았다")
	return 인스턴스


func _도약대(층: Node2D, 이름: String, 자리: Vector2) -> void:
	var t: Node2D = (load(T_도약대) as PackedScene).instantiate()
	t.name = 이름
	t.position = 자리
	t.set("폭", 도약대_폭)
	t.set("높이", 도약대_높이)
	t.set("도약속도", 도약대_속도)
	t.set("색_제한", false)
	층.add_child(t)
	print("   + %-28s (%.0f, %.0f)" % [이름, 자리.x, 자리.y])


## 기존 지형이 쓰는 것과 같은 문법 — 자식 `빛가림` LightOccluder2D.
##
## ★★[2026-09-06 실측으로 걸린 함정] **owner 를 여기서 직접 박아야 한다.**
##   SS2D 지형은 `TEMPLATE_WOOD_SOLID.tscn` **인스턴스**라 `scene_file_path` 가 차 있고,
##   `지형공통.주인_지정()` 은 인스턴스 경계에서 멈춘다(2026-08-02 Player 복제 버그 때문).
##   그래서 여기서 만든 자식은 owner 가 없는 채로 남고 `PackedScene.pack()` 이
##   **통째로 버린다** — 씬을 다시 열면 빛가림이 하나도 없다(실제로 그렇게 됐다).
##   `단방향지형.gd` 머리말이 경고하는 것과 정확히 같은 함정이다.
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
	oc.owner = 루트          # ★이 한 줄이 없으면 pack() 이 버린다
	print("   + 빛가림 → %s" % 지형.name)
