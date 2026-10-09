extends SceneTree
## ============================================================================
## [2026-10-09 재제작] stage_2-6 「번갈아 쏟아지는 수갱」 v3 — 도형님 uvtt 도면(map_242x120 · 242×120 칸)
## ----------------------------------------------------------------------------
## ▣ 무엇을 했나
##   도형님이 Dungeon Scrawl 로 그린 도면 `map_242x120.uvtt` 를 2-6 으로 쓴다(2026-10-09).
##   옛 2-6(2026-09-21 「무거운 것」 · 양동이 3)은 `stage_2-6.tscn.bak_2026-10-09_uvtt전` 과 git 기록에 있다.
##   ★외관은 **도형님이 10-09 에 고친 새 디자인**을 처음부터 켠다(2-1~2-5 에 Codex 가 나중에 붙인 것과 같다):
##     · 기본 지형 `챕터1_원근`(하수도_자연발판 · 돌 윗면 원근 + 줄눈 접합) · 격자발판 `챕터1_원근`(격자_원근그림)
##     · 떨어지는 물 `힉스필드_삼색프레임` + **정면 배관 출수구**(`물_힉스필드_출수구` · 160 이상은 물받이) — 앞끝이 배관 안에서 출발해 내려온다
##
## ▣ 축척 — 2-1 ~ 2-5 와 **같다**. 도면 한 칸 = 32px. 월드 x = 칸x × 32 + 16 · y = 칸y × 32 + 32.
## ▣ 지형은 손으로 옮겨 적지 않는다 — `tools/도면_2-6_지형추출.py` → `tools/도면_2-6_지형.json` → 이 빌더.
##
## ▣ 흐름 (도면 주석 그대로)
##   ① 시작 복도(칸 17~36 · 바닥 34.5) → **격자 수갱** — 물_1~4(각 160 폭)가 천장에서 낙사존까지 쏟아진다.
##      물_1·물_3 이 한 묶음, 물_2·물_4 가 한 묶음 — 한 묶음이 검정이면 다른 묶음은 흰색 · **3 초마다 바뀐다**.
##      격자는 물을 통과시킨다(물 속 격자 위에 서려면 그 물과 같은 색이어야 한다). 격자발판 26 장(검정/흰색 고정).
##   ② 수갱 위쪽 격자로 오른쪽 **L 바위**(칸 76.5~108 · 윗면 33) → **벨브_1** 로 흰물_1 을 끈다
##      (흰물_1 → 호퍼 → 흰물_2 가 아래 블록의 양동이 길을 막는다).
##   ③ (곁길) 호퍼 위를 걸어 건너 → 오른쪽 바위 → **양옆 세로 가시** 블록 → **흰물_3**(2 초 켜짐 · 2 초 꺼짐) 너머
##      → 블록 → **흰 공중발판**(흰 몸) → 블록 → 열쇠 복도(천장 톱 좌우) → **검정 열쇠** → 도착 문이 열린다.
##      돌아올 때는 흰물_3 받이 블록(윗면 50.5)으로 내려서 아래 블록(92.5)으로 떨어진다(1344 < 치명 1500).
##   ④ 수갱을 내려가 긴 흰 격자 → **아래 블록**(CP) → **양동이_1** 에 페인트를 쏴 채우고 **발판_1** 홈에 민다(홀드)
##      → **움직이는 발판**이 오른쪽(칸 171)에서 왼쪽(칸 136)으로 다가온다. 올라타 E 로 양동이 페인트를 회수하면
##      발판이 풀려 원래 자리로 돌아간다(도면: "활성화시켜야 다가오고 비활성화시키면 원래 위치로").
##   ⑤ 기둥 → **투명 발판 3**(칠해야 밟힌다) → 도착 지점 → 출구(2-7).
##
## ▣ 기준값 — `tools/하수도_빌더_공통.gd` (줌 1.0 · 점프 20칸 · 치명낙하 1500) · 외관 = 2-3·2-4·2-5 v3 헬퍼(2-9 기준)
## ▣ 돌리는 법
##   python tools/도면_2-6_지형추출.py
##   "C:/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe" --headless --path . -s res://tools/build_하수도_2-6.gd
##   ⚠ CLAUDE.md §4 — build_*.gd 는 평소에 돌리지 않는다. 에디터에서 손본 값이 전부 날아간다.
## ============================================================================

const 공 := preload("res://tools/하수도_빌더_공통.gd")
const 내씬 := "res://scenes/world_2_클로드/stage_2-6.tscn"
const 다음씬 := "res://scenes/world_2_클로드/stage_2-7.tscn"
# ── 2-9 기준 외관 — 2-3·2-4·2-5 v3 와 같은 자산 ──
#   ⚠ 공통 빌더 b.유체 를 그대로 쓰면 옛 유체.gd 가 되어 외관이 다르고 스크립트가 튄다(2-4 작업기록 §6).
const S_배경 := "res://scenes/배경/하수도_벽돌배경_2_9_조정.tscn"
const S_화면효과 := "res://scenes/배경/하수도_화면효과_v2.tscn"
const G_물 := "res://scripts/스마트월드/유체_흰물v2.gd"
const G_호퍼 := "res://scripts/스마트월드/호퍼_주철_기존배치.gd"
const G_번갈이 := "res://scripts/스마트월드/번갈이_물.gd"
const G_출수구 := "res://scripts/스마트월드/물_힉스필드_출수구.gd"
const 도면 := "res://tools/도면_2-6_지형.json"
const S_양동이 := "res://scenes/집/스마트월드_장애물/양동이.tscn"
const S_움직발판 := "res://scenes/집/스마트월드_장애물/움직이는발판.tscn"
const 버튼_S := preload("res://scripts/스마트월드/압력버튼.gd")
const 열쇠_S := preload("res://scripts/스마트월드/열쇠.gd")

const 검 := 공.검정
const 흰 := 공.흰색

## 수갱 물 번갈이 주기(초) — 도면 "3초마다 바뀜". 흰물_3 깜빡이 — 도면 "2초동안 켜지고 2초 동안 꺼지는 것을 반복".
const 수갱_주기 := 3.0
const 흰물3_주기 := 2.0

var b: RefCounted
var 자료: Dictionary = {}

## 도면 조각 이름 → 씬에 남길 한글 이름(추출 도구 출력 순서 · 2026-10-09)
const 이름표 := {
	"덩01_0": "시작_천장바위", "덩01_1": "수갱_천장", "덩01_2": "L바위_위_천장", "덩01_3": "호퍼_위_천장",
	"덩01_4": "열쇠복도_바위", "덩02": "공중발판_오른블록", "덩03": "가시블록", "덩04": "흰물3_오른블록",
	"덩05": "L바위", "덩06": "호퍼_오른바위", "덩07": "시작_바위기둥", "덩08": "흰물3_받이블록",
	"덩09": "아래블록", "덩10": "끝기둥", "덩11": "도착_지점",
	"흰01": "공중발판_흰",
}


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


## 도면 칸 → 월드
func kx(g: float) -> float: return g * 32.0 + 16.0
func ky(g: float) -> float: return g * 32.0 + 32.0


func _실행() -> void:
	print("\n=== STAGE 2-6 · 번갈아 쏟아지는 수갱 v3 (uvtt 도면 242×120 · 한 칸 32px) ===")
	var f := FileAccess.open(도면, FileAccess.READ)
	if f == null:
		push_error("2-6: 도면 json 이 없다 — 먼저 `python tools/도면_2-6_지형추출.py` 를 돌릴 것")
		quit(1)
		return
	자료 = JSON.parse_string(f.get_as_text()) as Dictionary
	f.close()
	if 자료.is_empty():
		push_error("2-6: 도면 json 파싱 실패")
		quit(1)
		return

	b = 공.new()
	b.재질_검 = load("res://assets/textures/smartshape/sewer_masonry_v02/땅_2-3_black.tres")
	b.재질_흰 = load("res://assets/textures/smartshape/sewer_masonry_v02/땅_2-3_white.tres")
	b.재질_선반_검 = load("res://assets/textures/smartshape/sewer_masonry_v02/선반_black.tres")
	b.재질_선반_흰 = load("res://assets/textures/smartshape/sewer_masonry_v02/선반_white.tres")

	var 프레임 := _프레임()
	var 루트 := _짓기(프레임)
	var ok: bool = b.검산(프레임, _빈공간들())
	b.색비율_보고()
	if not ok or b.오류 > 0:
		push_error("2-6: 검산 실패 %d — 저장하지 않는다" % b.오류)
		quit(1)
		return
	_새_디자인_켜기(루트)
	if not b.저장(루트, 내씬):
		quit(1)
		return
	print("=== 끝 ===\n")
	quit(0)


func _프레임() -> Rect2:
	var a: Array = 자료["프레임"]
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func _빈공간들() -> Array:
	var r: Array = []
	for v in 자료["빈공간"]:
		r.append(Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3])))
	return r


func _점들(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.append(Vector2(float(v[0]), float(v[1])))
	return p


## [x0, y0, x1, y1] (월드) → Rect2
func _사각(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))


## ★[2026-10-09] 도형님 새 디자인 — 하수도 지형·격자의 `챕터1_원근` 을 씬 전체에서 켠다.
##   2-1~2-5 는 Codex 가 씬 파일에 나중에 붙였다(`tools/apply_sewer_chapter_perspective.py` — 하수도 지형 인스턴스 전부).
##   2-6 은 처음부터 같은 값으로 짓는다. 속성이 있는 노드(하수도_자연발판 · 통과플랫폼)만 바뀐다.
func _새_디자인_켜기(n: Node) -> void:
	if "챕터1_원근" in n:
		n.set("챕터1_원근", true)
	for c in n.get_children():
		_새_디자인_켜기(c)


## 지형 + 2-9 기준 명도 조율(2-3·2-4·2-5 `_땅` 과 같다).
func _땅(부모: Node, 이름: String, 점들: PackedVector2Array, 색: int, 역할: String = "플랫폼") -> Node2D:
	var n: Node2D = b.지형(부모, 이름, 점들, 색, 역할)
	if n != null:
		n.set("시안_명도조율", true)
		n.set("앞지형_깊이", true)
	return n


## 떨어지는 물(유체_흰물v2 + 힉스필드 삼색 프레임). ★스크립트를 먼저 바꾼다 — set_script 는 그 전에 넣은 값을 지운다.
func _물(부모: Node, 이름: String, x: float, 윗끝: float, 폭: float, 높이: float, 색: int, 켜짐: bool = true) -> Node2D:
	var f := (load(공.S_유체) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	f.name = 이름
	f.set_script(load(G_물))
	f.position = Vector2(x, 윗끝)
	f.set("종류", 0)
	f.set("색", 색)
	f.set("크기", Vector2(폭, 높이))
	f.set("켜짐", 켜짐)
	f.set("힉스필드_삼색프레임", true)
	부모.add_child(f)
	return f


## 정면 배관 출수구(도형님 10-09 새 디자인) — 물 윗끝에 원형 배관(폭 < 160) 또는 물받이(≥ 160)를 그린다.
##   같은 자리에서 번갈아 켜지는 물은 출수구 하나를 같이 쓴다(켜진 쪽 색을 따라간다 · `물_힉스필드_출수구._update`).
func _출수구(부모: Node, 물: Node2D) -> Node2D:
	var o := Node2D.new()
	o.name = "출수_" + String(물.name)
	o.set_script(load(G_출수구))
	부모.add_child(o)
	o.set("대상_유체", o.get_path_to(물))
	return o


## 같은 자리 두 물을 `주기` 초마다 바꿔 켠다. bb 가 null 이면 a 하나를 켰다 껐다(깜빡이).
func _번갈이(부모: Node, 이름: String, a: Node, bb: Node, 주기: float) -> Node2D:
	var n := Node2D.new()
	n.name = 이름
	n.set_script(load(G_번갈이))
	부모.add_child(n)
	n.set("물_A", n.get_path_to(a))
	if bb != null:
		n.set("물_B", n.get_path_to(bb))
	n.set("주기", 주기)
	return n


## 주철 호퍼(2-4 `_호퍼` 와 같다). 원점 = 아랫변 가운데 = 밟는면 + 높이. 출구 물 너비는 주철 호퍼가 정한다(폭 × 0.2).
func _호퍼(부모: Node, 이름: String, x: float, 밟는면: float, 폭: float, 높이: float, 출구유체: Node) -> Node2D:
	var h := (load(공.S_호퍼) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	h.name = 이름
	h.set_script(load(G_호퍼))
	h.position = Vector2(x, 밟는면 + 높이)
	h.set("폭", 폭)
	h.set("높이", 높이)
	h.set("자동_출구_연결", false)
	h.set("주철_명도", 0.88)
	h.z_index = 3
	var c := CollisionShape2D.new()
	c.name = "윗면"
	var r := RectangleShape2D.new()
	r.size = Vector2(폭, 12.0)
	c.shape = r
	c.position = Vector2(0, -높이 + 6.0)
	c.one_way_collision = true
	c.one_way_collision_margin = 4.0
	h.add_child(c)
	b._덮어쓸_노드들.append(c)
	부모.add_child(h)
	if 출구유체 != null:
		h.set("출구_유체", h.get_path_to(출구유체))
	return h


## 격자발판 — 도면의 "격자발판(검정/흰색)". 일방통행 공중 발판이고 색은 고정이다(2-4·2-5 `_격자` 와 같다).
func _격자(장: Node, 이름: String, r: Rect2, 색: int) -> Node2D:
	var g: Node2D = b.통과플랫폼(장, 이름, r.get_center().x, r.position.y, r.size.x, 1)
	g.set("고정색", 0 if 색 == 검 else 1)
	return g


## 움직이는 지형 — Node2D 그릇 + 그 안의 지형(그릇 기준 좌표). 열쇠가 그릇을 옮긴다(2-5 `도착_문` 과 같은 짜임).
func _움직이는_땅(부모: Node, 이름: String, 자리: Vector2, 크기: Vector2) -> Node2D:
	var 그릇 := Node2D.new()
	그릇.name = 이름
	그릇.position = 자리
	그릇.z_index = -1
	부모.add_child(그릇)
	b.짧은변_허용.append(이름 + "_몸")
	_땅(그릇, 이름 + "_몸", 공.사각(0, 0, 크기.x, 크기.y), 검)
	b.지형표.pop_back()
	return 그릇


## 세로 가시 — 블록 옆면에 붙는다. 방향 2 = 왼쪽을 향함(블록 왼면) · 3 = 오른쪽(블록 오른면).
##   가시 판정 폴리곤은 원점 기준 ±높이/2 로 돌려 그린다(장애물_공통.가시_폴리곤들) → 밑동 4px 을 벽에 묻는다(바닥 가시와 같은 묻힘).
func _세로가시(위: Node, 이름: String, 벽x: float, y0: float, y1: float, 방향: int, 높이: float = 22.0) -> Node2D:
	var s := (load(공.S_가시) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	s.name = 이름
	var 밖 := -1.0 if 방향 == 2 else 1.0
	s.position = Vector2(벽x + 밖 * (높이 * 0.5 - 4.0), (y0 + y1) * 0.5)
	s.set("칸수", int(round((y1 - y0) / 32.0)))
	s.set("방향", 방향)
	s.set("가시높이", 높이)
	위.add_child(s)
	return s


## 외곽 — 왼벽·오른벽·천장만. ★바닥은 깔지 않는다: 도면 아래는 "낙사존" 이다(물기둥 아래 · 움직이는 발판 아래).
##   공통 `b.외곽` 은 바닥까지 깔아 떨어진 몸이 프레임 바닥(<1500 낙하)에 서서 살아남는다 → 영영 못 돌아오는 막힘.
##   바닥이 없으면 몸이 카메라 밑으로 빠져 `낙사_y` 에서 죽는다.
func _외곽_바닥없이(부모: Node, 프레임: Rect2, 두께: float = 1024.0) -> void:
	var L := 프레임.position.x
	var T := 프레임.position.y
	var R := 프레임.end.x
	var B := 프레임.end.y
	b.지형(부모, "외곽_왼벽", 공.사각(L - 두께, T, L, B + 두께), 검, "외곽")
	b.지형(부모, "외곽_오른벽", 공.사각(R, T, R + 두께, B + 두께), 검, "외곽")
	b.지형(부모, "외곽_천장", 공.사각(L - 두께, T - 두께, R + 두께, T), 검, "외곽")


func _짓기(프레임: Rect2) -> Node2D:
	var 입구 := Vector2(kx(17), ky(34.5))
	var 시작 := 입구 - Vector2(208.0, 0.0)          # 입구 통로 안(2-4·2-5 와 같은 거리)
	# 낙사_y = 프레임 바닥 + 160 — 바닥 없는 낙사존으로 빠진 몸이 화면 밖에서 바로 죽는다.
	var 루트: Node2D = b.루트("stage_2-6", "2-6 · 번갈아 쏟아지는 수갱", 프레임, 시작, 프레임.end.y + 160.0)
	var 지 := 루트.get_node("지형")
	var 장 := 루트.get_node("장치")
	var 위 := 루트.get_node("위험물")
	var 체 := 루트.get_node("체크포인트")

	var 배경 := (load(S_배경) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	배경.name = "하수도배경"
	루트.add_child(배경)
	루트.move_child(배경, 1)

	_외곽_바닥없이(지, 프레임)

	# ══════════════════════════════════════════════════════════════════════
	# 지형 — 도면에서 뽑은 그대로 (0.5 칸 턱이 많아 전부 짧은변 허용)
	# ══════════════════════════════════════════════════════════════════════
	for 조각 in 자료["지형"]:
		var 이름: String = 이름표.get(조각["이름"], 조각["이름"])
		b.짧은변_허용.append(이름)
		_땅(지, 이름, _점들(조각["점"]), 검)
	# 도면 "공중발판(흰색)" — 흰 몸만 밟는다
	for 조각 in 자료["흰지형"]:
		var 이름w: String = 이름표.get(조각["이름"], 조각["이름"])
		b.짧은변_허용.append(이름w)
		_땅(지, 이름w, _점들(조각["점"]), 흰)
	for 조각 in 자료["채움"]:
		var 이름c: String = "가장자리_" + String(조각["이름"])
		b.짧은변_허용.append(이름c)
		_땅(지, 이름c, _점들(조각["점"]), 검, "채움")

	# ── 격자발판 26 장(일방통행 · 색 고정 · 물을 통과시킨다) ──
	for g in 자료["격자"]:
		_격자(장, String(g["이름"]), _사각(g["사각"]), 검 if String(g["색"]) == "검" else 흰)

	# ── 투명 발판 3 장 — 칠해야 밟힌다(한 발이면 전체칠) ──
	for 이름g in ["투명발판_1", "투명발판_2", "투명발판_3"]:
		var r: Rect2 = _사각(자료["유령"][이름g])
		b.짧은변_허용.append(이름g)
		b.유령(지, 이름g, 공.사각(r.position.x, r.position.y, r.end.x, r.end.y), 검, 1)

	# ══════════════════════════════════════════════════════════════════════
	# ① 격자 수갱 — 물_1~4 (천장 9 → 낙사존 · 160 폭) · 3 초 번갈이
	# ══════════════════════════════════════════════════════════════════════
	# 도면 물기둥 칸: 물_1 39.5~44.5 · 물_2 50~55 · 물_3 60.5~65.5 · 물_4 69.5~74.5 (그림 회색 띠 실측 · 2026-10-09)
	#   아랫끝은 도면(110)보다 프레임 바닥까지 늘렸다 — 낙사존에서 물이 허공에 끊겨 보이지 않게(판정이 닿을 몸도 없다).
	#   물마다 검·흰 두 벌을 같은 자리에 겹쳐 두고 켜짐만 바꾼다(2-2 번갈이와 같은 길).
	#   시작: 물_1·물_3 = 검정 · 물_2·물_4 = 흰색 (도면 첫 줄 "물_1과 물_3이 검은 물일 때 …")
	var 수갱_아래 := 프레임.end.y
	var 기둥 := [[1, 42.0, 검], [2, 52.5, 흰], [3, 63.0, 검], [4, 72.0, 흰]]
	for c in 기둥:
		var 번호: int = int(c[0])
		var 처음색: int = int(c[2])
		var 처음물 := 공.물_검 if 처음색 == 검 else 공.물_흰
		var 다음물 := 공.물_흰 if 처음색 == 검 else 공.물_검
		var a: Node2D = _물(장, "물_%d_%s" % [번호, "검" if 처음색 == 검 else "흰"], kx(float(c[1])), ky(9), 160.0,
				수갱_아래 - ky(9), 처음물, true)
		var bb: Node2D = _물(장, "물_%d_%s" % [번호, "흰" if 처음색 == 검 else "검"], kx(float(c[1])), ky(9), 160.0,
				수갱_아래 - ky(9), 다음물, false)
		_번갈이(장, "번갈이_물_%d" % 번호, a, bb, 수갱_주기)
		_출수구(장, a)

	# ══════════════════════════════════════════════════════════════════════
	# ② 흰물_1 → 호퍼 → 흰물_2 · 벨브_1
	# ══════════════════════════════════════════════════════════════════════
	# 호퍼 — 도면 칸 108.5~120.5 × 33.5~37.5 (384 × 128). 밟고 건넌다(L 바위 33 → 호퍼 33.5 → 오른쪽 바위 33).
	var 호퍼면 := ky(33.5)
	# 흰물_2 — 호퍼 출구 → 아래 블록 윗면(92.5). 처음엔 꺼 두고 호퍼가 들어온 물 색으로 켠다(2-4 와 같다).
	var 물2: Node2D = _물(장, "흰물_2", kx(114.5), 호퍼면 + 128.0, 96.0, ky(92.5) - (호퍼면 + 128.0), 공.물_회, false)
	_호퍼(장, "호퍼_1", kx(114.5), 호퍼면, 384.0, 128.0, 물2)
	# 흰물_1 — 천장(13) → 호퍼. 도면 폭 칸 110~119 = 288. 호퍼로 들어가는 물은 윗면 + 12 까지 늘리고 `호퍼_유입` 을 켠다
	#   (2-3 §4: 안 켜면 바닥찾기와 호퍼 입구 연출이 `보이는_높이` 를 번갈아 덮어써 스크립트가 20ms 튄다).
	var 물1: Node2D = _물(장, "흰물_1", kx(114.5), ky(13), 288.0, 호퍼면 + 12.0 - ky(13), 공.물_흰, true)
	물1.set("호퍼_유입", true)
	# ★출수구 — 호퍼 입구 물이지만 천장에서 바로 떨어진다(2-4 처럼 물탱크에서 오는 관이 없다) → 정면 물받이로 보여 준다.
	#   (Codex 10-08 정책 "호퍼 입구는 기존 관 유지" 는 관이 있는 경우 · 여기엔 관이 없다 — 작업기록 §4)
	_출수구(장, 물1)
	# 벨브_1 — 도면 L 바위 윗면 칸 98(호퍼 왼쪽). "벨브_1를 통해서 흰물_1를 끄고 킬 수 있음".
	var 벨브: Node2D = b.레버(장, "벨브_1", Vector2(kx(98), ky(33)), 0, 물1)
	벨브.set("시작_켜짐", true)

	# ══════════════════════════════════════════════════════════════════════
	# ③ 곁길 — 세로 가시 · 흰물_3(깜빡이) · 흰 공중발판 · 천장 톱 · 검정 열쇠
	# ══════════════════════════════════════════════════════════════════════
	# 가시 블록(칸 140~146.5 × 31~35.5) 양옆 — 도면 선 칸 31.5~35.5
	_세로가시(위, "가시_블록왼", kx(140), ky(31.5), ky(35.5), 2)
	_세로가시(위, "가시_블록오른", kx(146.5), ky(31.5), ky(35.5), 3)
	# 흰물_3 — 칸 147.5~151 (112 폭) · 천장(13) → 받이 블록 윗면(50.5) · 2 초 켜짐 / 2 초 꺼짐
	var 물3: Node2D = _물(장, "흰물_3", kx(149.25), ky(13), 112.0, ky(50.5) - ky(13), 공.물_흰, true)
	_번갈이(장, "깜빡이_흰물_3", 물3, null, 흰물3_주기)
	_출수구(장, 물3)
	# 천장 톱 — 열쇠 복도(바닥 26.5 · 천장 19) 천장에 반쯤 묻혀 좌우로. 도면 선 칸 179.5~209.5 → 원점 = 가운데(194.5).
	#   반지름 64 → 천장 아래 64 만 나온다. 걸어 지나가면 안 닿고(틈 176 > 몸 97) **뛰면** 닿는다 —
	#   복도 입구(블록 28 → 복도 26.5)와 열쇠 홈(25)으로 뛰어 오를 때 톱이 떠난 뒤에 뛴다.
	b.회전톱(위, "톱_복도", Vector2(kx(194.5), ky(19)), 64.0, 30.0 * 32.0, 4.0)
	# 검정 열쇠 — 복도 끝 홈(칸 210~217.5 · 바닥 25) · 도착 문을 연다(2-5 와 같은 규칙 · 색 상관없이 줍는다)
	var 문 := _움직이는_땅(장, "도착_문", Vector2(kx(239), ky(89)), Vector2(96.0, 208.0))
	# 문은 출구 통로 그림(연결통로 _draw) 앞에 보여야 한다 — 2-5 처럼 z 1 · 다 열리면 열쇠가 문을 숨긴다.
	문.z_index = 1
	var 키 := Area2D.new()
	키.set_script(열쇠_S)
	키.name = "검정열쇠"
	키.position = Vector2(kx(213.75), ky(25) - 40.0)
	장.add_child(키)
	var 문들: Array[NodePath] = [키.get_path_to(문)]
	키.set("문들", 문들)
	키.set("문_이동량", Vector2(0, -304.0))

	# ══════════════════════════════════════════════════════════════════════
	# ④ 양동이_1 + 발판_1(홀드) + 움직이는 발판
	# ══════════════════════════════════════════════════════════════════════
	# 움직이는 발판 — 도면 쉬는 자리 칸 171~178.5(윗면 93) · 길 칸 136~179.5. 주철 고정색(검정 · 칠 못 함).
	#   스스로는 안 움직인다(이동거리 0) — 발판_1 이 position 을 물리 프레임에서 옮긴다 → AnimatableBody(sync_to_physics)라 몸을 태운다.
	var 발 := (load(S_움직발판) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	발.name = "움직이는발판"
	발.position = Vector2(kx(174.75), ky(93) + 14.0)
	발.set("크기", Vector2(240.0, 28.0))
	발.set("이동거리", 0.0)
	발.set("칠하기_가능", false)
	발.set("고정색", 0)
	장.add_child(발)

	# 발판_1 — 아래 블록 윗면의 홈(칸 121~127 · 깊이 32)에 앉힌다. 원점 = 홈 바닥 · 밟는면 윗변 = 블록 윗면.
	#   누르는 동안만(2-5 도면 "발판은 원래 토글이 아니라 홀드") · 양동이 전용(페인트로 채웠을 때만 무게).
	var 버튼 := AnimatableBody2D.new()
	버튼.set_script(버튼_S)
	버튼.name = "발판_1"
	버튼.position = Vector2(kx(124), ky(93.5))
	버튼.set("폭", 192.0)
	버튼.set("높이", 32.0)
	버튼.set("작동방식", 0)
	버튼.set("누름_가능_그룹", PackedStringArray(["양동이"]))
	버튼.set("이동속도", 320.0)
	장.add_child(버튼)
	var 대상: Array[NodePath] = [버튼.get_path_to(발)]
	var 이동: Array[Vector2] = [Vector2(-(171.0 - 136.0) * 32.0, 0.0)]     # 왼끝이 칸 136(블록 오른끝 135 옆)까지
	버튼.set("대상들", 대상)
	버튼.set("대상_이동량들", 이동)

	# 양동이_1 — 도면 칸 104~108.5(블록 위). 검정(검은 몸이 민다) · 쏘면 그 색으로 찬다 · 찬 채로도 밀린다(2-5 와 같다).
	#   블록에서 떨어지면(블록 밑면 106 아래) 제자리로.
	var 통 := (load(S_양동이) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	통.name = "양동이_1"
	통.position = Vector2(kx(106.25), ky(92.5))
	통.set("색", ColorDefs.BLACK)
	통.set("채운뒤_밀수없음", false)
	통.set("낙사_y", ky(106))
	통.set("페인트로_채움", true)
	장.add_child(통)

	# ══════════════════════════════════════════════════════════════════════
	# 체크포인트 · 입구 · 출구
	# ══════════════════════════════════════════════════════════════════════
	b.체크포인트(체, "CP_시작", Vector2(kx(21), ky(34.5)))
	b.체크포인트(체, "CP_벨브", Vector2(kx(88), ky(33)))         # 도면에 없음 — 수갱을 두 번 지나므로 벨브 옆에 하나(작업기록 §4)
	b.체크포인트(체, "CP_블록", Vector2(kx(99), ky(92.5)))       # 도면 "체크포인트"(칸 99)

	b.입구(루트, 입구)
	b.출구(루트, Vector2(kx(239), ky(95.5)), 다음씬)
	b.끝점(루트, Vector2(kx(240.5), ky(95.5)))
	b.플레이어(루트, 시작)
	var 효과 := (load(S_화면효과) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	효과.name = "하수도화면효과"
	루트.add_child(효과)
	return 루트
