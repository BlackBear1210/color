extends SceneTree
## ============================================================================
## [2026-10-08 재제작] stage_2-5 「계단을 꺼내라」 v3 — 도형님 uvtt 도면(stage_2-5 · 176×107 칸)
## ----------------------------------------------------------------------------
## ▣ 무엇을 했나
##   도형님이 Dungeon Scrawl 로 그린 도면 `stage_2-5_176x107.uvtt` 를 2-5 로 쓴다(2026-10-08).
##   옛 2-5(2026-09-21 · 밸브 4 · 갈래)는 `stage_2-5.tscn.bak_2026-10-08_uvtt전` 과 git 기록에 있다.
##
## ▣ 축척 — 2-1 ~ 2-4 와 **같다**. 도면 한 칸 = 32px. 월드 x = 칸x × 32 + 16 · y = 칸y × 32 + 32.
##   (도면은 70px/칸으로 내보냈다 — 그림 해상도일 뿐이다. 지형은 `line_of_sight` 칸 좌표에서 뽑는다.)
##
## ▣ 지형은 손으로 옮겨 적지 않는다 — `tools/도면_2-5_지형추출.py` → `tools/도면_2-5_지형.json` → 이 빌더.
##
## ▣ 흐름 (도면 주석 그대로 · 아래 → 위)
##   ① 시작 방(칸 33~83.5 · 바닥 95.5) — 격자발판 5 장을 밟고 오른다. 오른쪽 벽에서 **흰색물_2** 가 쏟아진다(검은 몸이면 피한다).
##   ② 긴 격자(칸 45~77.5 · 81.5)를 밑에서 뚫고 가운데 방으로. 왼쪽 바닥은 가시.
##      격자 2 장 → **투명발판 2 장**(칠해야 밟힌다) → 블록(칸 49~66.5 · 71.5) · CP.
##   ③ 블록 위 **양동이**에 페인트를 쏴 채우고(무게) **발판_1** 에 밀어 올린다 → 홀드(누르는 동안만)
##      → 왼벽에서 **검은지형_1~5** 가 아래부터 하나씩 튀어나와 큰 계단. 양동이 페인트를 E 로 회수하면 가벼워져 풀린다.
##   ④ 계단 꼭대기 → 왼쪽 턱 → **격자 배관**(밑에서 뚫고) → 복도. 땅에 박힌 **톱이 좌우로** 오간다.
##   ⑤ 가시 바닥 위 **검·흰·검·흰 공중 지형** — 칸마다 공중 색 전환 → 흰 격자 2 장 → **흰색 지형**.
##   ⑥ (곁길) 흰색 지형 오른쪽 낙사 존 위 발판 2 + **상하로 움직이는 톱** 2 → **검은 열쇠**(도착 문을 연다).
##   ⑦ 흰색 지형 → 윗방 바닥 → 왼쪽 끝 **벨브_1**·CP — 벨브로 **흰색물_1**(너비 192 — 공중 전환으로 못 지나간다)을 끈다.
##   ⑧ 격자 검·흰·검·흰·검 번갈아 오르기 → 디딤돌 → 바위 윗면 → 도착 지점(문은 열쇠로 열림) → 출구(2-6).
##
## ▣ 기준값 — `tools/하수도_빌더_공통.gd` (줌 1.0 · 점프 20칸 · 치명낙하 1500) · 외관 = 2-3·2-4 v3 헬퍼(2-9 기준)
## ▣ 돌리는 법
##   python tools/도면_2-5_지형추출.py
##   "C:/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe" --headless --path . -s res://tools/build_하수도_2-5.gd
##   ⚠ CLAUDE.md §4 — build_*.gd 는 평소에 돌리지 않는다. 에디터에서 손본 값이 전부 날아간다.
## ============================================================================

const 공 := preload("res://tools/하수도_빌더_공통.gd")
const 내씬 := "res://scenes/world_2_클로드/stage_2-5.tscn"
const 다음씬 := "res://scenes/world_2_클로드/stage_2-6.tscn"
# ── 2-9 기준 외관 — 2-3·2-4 v3 와 같은 자산 ──
#   ⚠ 공통 빌더 b.유체 를 그대로 쓰면 옛 유체.gd 가 되어 외관이 다르고 스크립트가 튄다(2-4 작업기록 §6).
const S_배경 := "res://scenes/배경/하수도_벽돌배경_2_9_조정.tscn"
const S_화면효과 := "res://scenes/배경/하수도_화면효과_v2.tscn"
const G_물 := "res://scripts/스마트월드/유체_흰물v2.gd"
const 도면 := "res://tools/도면_2-5_지형.json"
const S_양동이 := "res://scenes/집/스마트월드_장애물/양동이.tscn"
const 버튼_S := preload("res://scripts/스마트월드/압력버튼.gd")
const 열쇠_S := preload("res://scripts/스마트월드/열쇠.gd")

const 검 := 공.검정
const 흰 := 공.흰색

var b: RefCounted
var 자료: Dictionary = {}

## 도면 조각 이름 → 씬에 남길 한글 이름
const 이름표 := {
	"덩01": "아래층_큰바위", "덩02": "도착_천장바위", "덩03": "도착_바위",
	"덩04": "윗방_디딤돌", "덩05": "낙사존_발판1", "덩06": "낙사존_발판2",
	"덩07": "복도_검정공중1", "덩08": "복도_검정공중2", "덩09": "가운데방_블록",
	"흰01": "흰색지형", "흰02": "복도_흰공중2", "흰03": "복도_흰공중1",
	"채움01": "가장자리_채움",
}


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


## 도면 칸 → 월드
func kx(g: float) -> float: return g * 32.0 + 16.0
func ky(g: float) -> float: return g * 32.0 + 32.0


func _실행() -> void:
	print("\n=== STAGE 2-5 · 계단을 꺼내라 v3 (uvtt 도면 176×107 · 한 칸 32px) ===")
	var f := FileAccess.open(도면, FileAccess.READ)
	if f == null:
		push_error("2-5: 도면 json 이 없다 — 먼저 `python tools/도면_2-5_지형추출.py` 를 돌릴 것")
		quit(1)
		return
	자료 = JSON.parse_string(f.get_as_text()) as Dictionary
	f.close()
	if 자료.is_empty():
		push_error("2-5: 도면 json 파싱 실패")
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
		push_error("2-5: 검산 실패 %d — 저장하지 않는다" % b.오류)
		quit(1)
		return
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


## 지형 + 2-9 기준 명도 조율(2-3·2-4 `_땅` 과 같다).
func _땅(부모: Node, 이름: String, 점들: PackedVector2Array, 색: int, 역할: String = "플랫폼") -> Node2D:
	var n: Node2D = b.지형(부모, 이름, 점들, 색, 역할)
	if n != null:
		n.set("시안_명도조율", true)
		n.set("앞지형_깊이", true)
	return n


## 떨어지는 물(유체_흰물v2). ★스크립트를 먼저 바꾼다 — set_script 는 그 전에 넣은 값을 지운다.
func _물(부모: Node, 이름: String, x: float, 윗끝: float, 폭: float, 높이: float, 색: int, 켜짐: bool = true) -> Node2D:
	var f := (load(공.S_유체) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	f.name = 이름
	f.set_script(load(G_물))
	f.position = Vector2(x, 윗끝)
	f.set("종류", 0)
	f.set("색", 색)
	f.set("크기", Vector2(폭, 높이))
	f.set("켜짐", 켜짐)
	부모.add_child(f)
	return f


## 격자발판 — 도면의 "격자발판(검정/흰색)". 일방통행 공중 발판이고 색은 고정이다(2-4 `_격자` 와 같다).
func _격자(장: Node, 이름: String, r: Rect2, 색: int) -> Node2D:
	var g: Node2D = b.통과플랫폼(장, 이름, r.get_center().x, r.position.y, r.size.x, 1)
	g.set("고정색", 0 if 색 == 검 else 1)
	return g


## 움직이는 지형 — Node2D 그릇 + 그 안의 지형(그릇 기준 좌표). 버튼·열쇠가 그릇을 옮긴다(2-4 `발판1_덮개` · 2-7 과 같은 짜임).
## 움직이는 조각은 검산·색 비율에서 뺀다(그릇 기준 좌표라 월드 겹침 검사가 어긋난다). 통행은 주행검사가 본다.
## z −1: 숨어 있는 동안(바위 속) 바위 뒤에 그려진다.
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


func _짓기(프레임: Rect2) -> Node2D:
	var 입구 := Vector2(kx(33), ky(95.5))
	var 시작 := 입구 - Vector2(208.0, 0.0)          # 입구 통로 안(2-4 와 같은 거리)
	var 루트: Node2D = b.루트("stage_2-5", "2-5 · 계단을 꺼내라", 프레임, 시작, 프레임.end.y + 400.0)
	var 지 := 루트.get_node("지형")
	var 장 := 루트.get_node("장치")
	var 위 := 루트.get_node("위험물")
	var 체 := 루트.get_node("체크포인트")

	var 배경 := (load(S_배경) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	배경.name = "하수도배경"
	루트.add_child(배경)
	루트.move_child(배경, 1)

	b.외곽(지, 프레임)

	# ══════════════════════════════════════════════════════════════════════
	# 지형 — 도면에서 뽑은 그대로 (0.5 칸 턱이 많아 전부 짧은변 허용)
	# ══════════════════════════════════════════════════════════════════════
	for 조각 in 자료["지형"]:
		var 이름: String = 이름표.get(조각["이름"], 조각["이름"])
		b.짧은변_허용.append(이름)
		_땅(지, 이름, _점들(조각["점"]), 검)
	# 도면 "흰색 지형" · "흰색 공중 지형" — 흰 몸만 밟는다
	for 조각 in 자료["흰지형"]:
		var 이름w: String = 이름표.get(조각["이름"], 조각["이름"])
		b.짧은변_허용.append(이름w)
		_땅(지, 이름w, _점들(조각["점"]), 흰)
	for 조각 in 자료["채움"]:
		var 이름c: String = 이름표.get(조각["이름"], 조각["이름"])
		b.짧은변_허용.append(이름c)
		_땅(지, 이름c, _점들(조각["점"]), 검, "채움")

	# ── 격자발판(일방통행 · 색 고정) ──
	for g in 자료["격자"]:
		_격자(장, String(g["이름"]), _사각(g["사각"]), 검 if String(g["색"]) == "검" else 흰)

	# ── 투명발판 2 장 — 칠해야 밟힌다(한 발이면 전체칠) ──
	for 이름g in 자료["유령"]:
		var r: Rect2 = _사각(자료["유령"][이름g])
		b.짧은변_허용.append(이름g)
		b.유령(지, 이름g, 공.사각(r.position.x, r.position.y, r.end.x, r.end.y), 검, 1)

	# ── 가시 ──
	for 이름s in 자료["가시"]:
		var rs: Rect2 = _사각(자료["가시"][이름s])
		b.가시(위, 이름s, rs.get_center().x, rs.end.y, int(round(rs.size.x / 32.0)))

	# ══════════════════════════════════════════════════════════════════════
	# ③ 양동이 + 발판_1(홀드) + 검은지형_1~5
	# ══════════════════════════════════════════════════════════════════════
	# 검은지형 — 도면 사각형 = **다 나온 자리**. 처음엔 길이만큼 왼쪽(왼벽 바위 속)에 숨어 있다.
	var 계단들: Array[NodePath] = []
	var 이동량: Array[Vector2] = []
	var 지연: Array[float] = []
	var 계단_그릇들: Array[Node2D] = []
	for s in 자료["계단"]:
		var rr: Rect2 = _사각(s["사각"])
		var 그릇 := _움직이는_땅(장, "검은지형_%d" % int(s["번호"]), rr.position - Vector2(rr.size.x, 0.0), rr.size)
		계단_그릇들.append(그릇)
		이동량.append(Vector2(rr.size.x, 0.0))
		지연.append(0.45 * (int(s["번호"]) - 1))      # 아래(_1)부터 0.45 초 간격 — "하나씩 튀어나와"

	# 발판_1 — 블록 윗면의 홈(칸 56~60 · 깊이 32)에 앉힌다. 원점 = 홈 바닥 · 밟는면 윗변 = 블록 윗면.
	#   누르는 동안만(도면: "발판은 원래 토글이 아니라 홀드") · 양동이 전용(물참 = 페인트로 채웠을 때만 무게).
	var 버튼 := AnimatableBody2D.new()
	버튼.set_script(버튼_S)
	버튼.name = "발판_1"
	버튼.position = Vector2(kx(58), ky(72.5))
	버튼.set("폭", 128.0)
	버튼.set("높이", 32.0)
	버튼.set("작동방식", 0)
	버튼.set("누름_가능_그룹", PackedStringArray(["양동이"]))
	버튼.set("이동속도", 600.0)
	장.add_child(버튼)
	for 그릇2 in 계단_그릇들:
		계단들.append(버튼.get_path_to(그릇2))
	버튼.set("대상들", 계단들)
	버튼.set("대상_이동량들", 이동량)
	버튼.set("대상_지연들", 지연)

	# 양동이 — 도면 칸 60.5~63(블록 위). 검정(검은 몸이 민다) · 쏘면 그 색으로 찬다 · 찬 채로도 밀린다.
	#   블록에서 떨어지면(블록 밑면 76.5 아래) 제자리로 — 아래층 격자에 떨어져 못 올리는 막힘을 막는다.
	var 통 := (load(S_양동이) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	통.name = "양동이"
	통.position = Vector2(kx(61.75), ky(71.5))
	통.set("색", ColorDefs.BLACK)
	통.set("채운뒤_밀수없음", false)
	통.set("낙사_y", ky(76.5))
	통.set("페인트로_채움", true)
	장.add_child(통)

	# ══════════════════════════════════════════════════════════════════════
	# 물 · 벨브
	# ══════════════════════════════════════════════════════════════════════
	# 흰색물_1 — 윗방 천장(9) → 바닥(41) · 너비 192(6 칸). 검정 격자(칸 52~60.5)를 지나 바닥까지.
	var 물1: Node2D = _물(장, "흰색물_1", kx(56.5), ky(9), 192.0, ky(41) - ky(9), 공.물_흰)
	# ★벨브 자리를 도면(칸 21.5 · 물 왼쪽)에서 **물 오른쪽(칸 61 · 바닥 41)** 으로 옮겼다 — 도형님 확인 대기(작업기록 §4).
	#   윗방에는 오른쪽(흰색 지형 → 바닥 슬래브)으로만 들어온다. 도면 메모대로 흰색물_1 은 공중 색 전환으로 못 건넌다
	#   (주행검사 실측: 다 뛰면 흰 몸 머리가 바로 위 검정 격자_윗방3 에 닿아 죽고, 짧게 뛰면 물 속에 떨어진다)
	#   → 벨브가 물 왼쪽에 있으면 영영 못 끈다.
	var 벨브: Node2D = b.레버(장, "벨브_1", Vector2(kx(61), ky(41)), 0, 물1)
	벨브.set("시작_켜짐", true)
	# 흰색물_2 — 가운데 방 오른쪽 벽에서 나와 시작 방 바닥까지(도면은 이름이 흰색물_1 로 겹쳐 있어 _2 로 붙였다).
	_물(장, "흰색물_2", kx(81), ky(63.5), 160.0, ky(95.5) - ky(63.5), 공.물_흰)

	# ══════════════════════════════════════════════════════════════════════
	# 톱 — 복도(좌우 · 땅에 박힘) · 낙사 존(상하 2)
	# ══════════════════════════════════════════════════════════════════════
	# ★회전톱은 원점을 **가운데로** 사인 왕복한다(회전톱.gd `_process` · ±이동거리/2) — 공통 빌더 주석 "원점 = 왕복 시작점" 과 다르다.
	#   그래서 원점 = 도면 선의 가운데(uvtt portal 의 position 이 바로 그 가운데다).
	# 복도: 도면 선 칸 25~36 · 바닥 윗면 58 에 반쯤 묻힌다(반지름 40 → 바닥 위 40 만 나온다 · 슬래브 밑으로 안 삐져나온다).
	b.회전톱(위, "톱_복도", Vector2(kx(30.5), ky(58)), 40.0, 11.0 * 32.0, 3.0)
	# 낙사 존: 도면 선 칸 41.5~54 · 41.75~54.25(발판 윗면 46 을 위아래로 지난다)
	b.회전톱(위, "톱_낙사존1", Vector2(kx(109), ky(47.75)), 48.0, 12.5 * 32.0, 3.0, true)
	b.회전톱(위, "톱_낙사존2", Vector2(kx(118), ky(48)), 48.0, 12.5 * 32.0, 3.6, true)

	# ══════════════════════════════════════════════════════════════════════
	# 검은 열쇠 → 도착 문
	# ══════════════════════════════════════════════════════════════════════
	# 문 — 출구 통로 입구(칸 155.5~158.5 · 16~22.5)를 막는다. 열쇠를 주우면 위(천장 바위 4.5~13 속)로 304 올라간다.
	var 문 := _움직이는_땅(장, "도착_문", Vector2(kx(155.5), ky(16)), Vector2(96.0, 208.0))
	# 문은 출구 통로 그림(연결통로 _draw · z 0 · 문보다 뒤에 붙는다) 앞에 보여야 한다 — z −1 이면 통로 그림에 가려
	#   "열린 출구" 로 보였다(2026-10-08 촬영). 다 열리면 열쇠가 문을 숨긴다(바위 앞에 겹쳐 그려지지 않게).
	문.z_index = 1
	var 키 := Area2D.new()
	키.set_script(열쇠_S)
	키.name = "검은열쇠"
	키.position = Vector2(kx(139.5), ky(45.5) - 40.0)    # 열쇠 홈(칸 137.5~141.5 · 바닥 45.5)
	장.add_child(키)
	var 문들: Array[NodePath] = [키.get_path_to(문)]
	키.set("문들", 문들)
	키.set("문_이동량", Vector2(0, -304.0))

	# ══════════════════════════════════════════════════════════════════════
	# 체크포인트 · 입구 · 출구
	# ══════════════════════════════════════════════════════════════════════
	b.체크포인트(체, "CP_시작", Vector2(kx(36), ky(95.5)))
	b.체크포인트(체, "CP_블록", Vector2(kx(52), ky(71.5)))        # 도면 "체크포인트"(칸 52)
	b.체크포인트(체, "CP_윗방", Vector2(kx(27), ky(40)))          # 도면 "체크포인트"(칸 27)

	b.입구(루트, 입구)
	b.출구(루트, Vector2(kx(155.5), ky(22.5)), 다음씬)
	b.끝점(루트, Vector2(kx(157), ky(22.5)))
	b.플레이어(루트, 시작)
	var 효과 := (load(S_화면효과) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	효과.name = "하수도화면효과"
	루트.add_child(효과)
	return 루트
