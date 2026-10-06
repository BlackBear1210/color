extends SceneTree
## ============================================================================
## [2026-10-05 Claude] 시뮬 경로 엔진 재생 시험 — 도형님 "시뮬도 돌려서 색반전 기믹이나 막히는 구간이 있는지 확인"
##
## ▣ 무엇을 하나
##   python 검사기(tools/쳅터1/검사.py)는 player.gd 물리를 **흉내** 낸다. 흉내가 맞는지는 진짜로 뛰어 봐야 안다.
##   검사기가 남긴 경로(tools/_진단/경로/<스테이지>.json — 시작 → 각 길목의 비행 목록)를 읽어
##   비행마다 플레이어를 출발점에 세우고 **같은 입력**(점프·방향·점프 떼기·Shift 색 전환)을 진짜 Input 으로 넣는다.
##   → 죽었나(색·가시·낙하) · 예상 바닥에 내렸나 · 도약대에서 튀었나 를 적는다.
##
## ▣ 시험용으로 바꾸는 것 (게임 규칙을 바꾸는 게 아니다)
##   · 유령판: 검사기는 "칠했다고 친다" → 비행 시작 때 플레이어 색으로 전부 칠해 둔다(Shift 로 바꾸면 다시 칠함).
##   · 주기·점멸 빛줄기: 검사기도 "기다리면 된다" 고 막지 않으므로 재생 중엔 끈다(그룹에서 뺀다).
##   · 움직이는 발판을 타거나 내리는 비행은 위상(타이밍) 때문에 건너뛴다 — "건너뜀" 으로 따로 센다.
##
## 실행(헤드리스 가능, 60fps 고정):
##   Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_경로재생.gd
##   특정 스테이지만: … -s res://tools/시험_경로재생.gd -- 쳅터1_06_복도_C
## 결과: res://tools/_진단/경로/재생결과.txt
## ============================================================================

const 경로폴더 := "res://tools/_진단/경로/"
const 착지_허용_x := 56.0      # 검사기는 32px 격자 근사 — 가로로 이 정도는 어긋날 수 있다
const 착지_허용_y := 10.0
const 도약_판정_속도 := -700.0  # 이보다 빠르게 솟으면 '도약대에서 튀었다' (보통 점프 초속은 642)

var _줄: PackedStringArray = []
var _스테이지들: Array = []      # [{이름, 씬, 비행들:[...]}]
var _si := -1
var _씬: Node = null
var _p: CharacterBody2D = null
var _비행들: Array = []
var _bi := -1
var _단계 := "씬준비"
var _f := 0
var _죽음 := false
var _죽은자리 := Vector2.ZERO
var _공중 := false
var _튐 := false
var _바닥프레임 := 0
var _합계 := {"성공": 0, "실패": 0, "건너뜀": 0}
var _스테이지_합계 := {}


func _initialize() -> void:
	var 고른 := []
	for a in OS.get_cmdline_user_args():
		고른.append(a)
	var d := DirAccess.open(경로폴더)
	if d == null:
		push_error("경로 폴더 없음 — python tools/쳅터1/검사.py 를 먼저 돌릴 것")
		quit(1)
		return
	var 파일들 := Array(d.get_files())
	파일들.sort()
	for f in 파일들:
		if not f.ends_with(".json") or not f.begins_with("쳅터1_"):
			continue
		var 자료: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(경로폴더 + f))
		if 고른.size() > 0 and not 고른.has(자료["이름"]):
			continue
		var 비행들 := []
		for 길이름 in 자료["경로"].keys():
			if not String(길이름).begins_with("시작→"):
				continue          # 시작에서 각 길목까지만 재생(길목끼리는 같은 비행이 겹친다)
			var 단계 := 0
			for s in 자료["경로"][길이름]:
				단계 += 1
				if s["종류"] != "비행":
					continue
				s["길"] = 길이름
				s["단계"] = 단계
				비행들.append(s)
		_스테이지들.append({"이름": 자료["이름"], "씬": 자료["씬"], "비행들": 비행들,
			"구간": 자료["구간"], "노드수": 자료["노드수"]})
	_기록("재생할 스테이지 %d 개" % _스테이지들.size())
	_다음_스테이지()


func _기록(s: String) -> void:
	_줄.append(s)
	print(s)


func _다음_스테이지() -> void:
	if _씬:
		_씬.queue_free()
		_씬 = null
	_si += 1
	if _si >= _스테이지들.size():
		_끝()
		return
	var st: Dictionary = _스테이지들[_si]
	_씬 = (load(st["씬"]) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	if _씬.has_signal("사망함"):
		# 사망함 은 리스폰 이동 **전에** 울린다 → 이 순간의 위치가 실제로 죽은 자리
		_씬.connect("사망함", func():
			_죽음 = true
			_죽은자리 = _p.global_position)
	_비행들 = st["비행들"]
	_bi = -1
	_스테이지_합계 = {"성공": 0, "실패": 0, "건너뜀": 0}
	_단계 = "씬준비"
	_f = 0
	_기록("\n== %s · 비행 %d" % [st["이름"], _비행들.size()])


func _끝() -> void:
	_기록("\n합계: 성공 %d · 실패 %d · 건너뜀 %d" % [_합계["성공"], _합계["실패"], _합계["건너뜀"]])
	var f := FileAccess.open(경로폴더 + "재생결과.txt", FileAccess.WRITE)
	f.store_string("\n".join(_줄))
	f.close()
	quit(0 if _합계["실패"] == 0 else 2)


# ── 시험용 손질 ─────────────────────────────────────────────────────────────
func _주기빛_끄기() -> void:
	for n in get_nodes_in_group("색레이저"):
		if float(n.get("주기")) > 0.0 or bool(n.get("점멸")):
			n.remove_from_group("색레이저")


func _유령_칠하기(색: int) -> void:
	# 지형.gd enum 상태 { 무색, 검정, 흰색, 회색 } — 검정 1 · 흰색 2
	var 상태값 := 1 if 색 == ColorDefs.BLACK else 2
	for n in _씬.get_node("지형").get_children():
		if n.get_meta("design_kind", "") == "유령":
			n.call("_전체_즉시", 상태값, true)
			n.call("_충돌레이어_갱신")


func _놓기(위치: Vector2) -> void:
	_p.velocity = Vector2.ZERO
	_p.global_position = 위치
	var 낙하 = _씬.get("_낙하")
	if 낙하:
		낙하.call("초기화")


func _입력_모두_떼기() -> void:
	for a in ["jump", "move_left", "move_right", "toggle_color"]:
		Input.action_release(a)


func _방향(s: int) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if s < 0:
		Input.action_press("move_left")
	elif s > 0:
		Input.action_press("move_right")


func _색(c) -> int:
	return ColorDefs.BLACK if int(c) == 2 else ColorDefs.WHITE


# ── 진행 ───────────────────────────────────────────────────────────────────
func _physics_process(_d: float) -> bool:
	if _씬 == null:
		return false
	_f += 1
	match _단계:
		"씬준비":
			if _f >= 30:          # SS2D 지형이 구워지고 페인트 코어가 붙을 시간
				_주기빛_끄기()
				# 길목(연결구) 판정을 끈다 — 길목 앞에 내리는 비행이 스테이지 전환을 일으키면 재생이 끊긴다
				var 연결 := _씬.get_node_or_null("연결")
				if 연결:
					연결.process_mode = Node.PROCESS_MODE_DISABLED
				_다음_비행()
		"놓임":
			# 3프레임 가만히 — 바닥에 붙는지 본다(점프는 바닥에서만 된다)
			if _f >= 4:
				_출발()
		"도약대기":
			if _p.velocity.y < 도약_판정_속도:
				_단계 = "비행"
				_f = 0
				_공중 = true
				_입력_적용(0)
			elif _f > 30 or _죽음:
				_결과(false, "도약대에서 안 튐")
		"비행":
			_입력_적용(_f)
			_판정()
	return false


func _다음_비행() -> void:
	_입력_모두_떼기()
	_bi += 1
	if _bi >= _비행들.size():
		var st: Dictionary = _스테이지들[_si]
		_기록("  → 성공 %d · 실패 %d · 건너뜀 %d" % [_스테이지_합계["성공"], _스테이지_합계["실패"], _스테이지_합계["건너뜀"]])
		_다음_스테이지()
		return
	var s: Dictionary = _비행들[_bi]
	var 노드수: Array = _스테이지들[_si]["노드수"]
	var n := int(노드수[0])
	var P := int(노드수[1])
	var 출발노드 := int(s["from"])
	# 움직이는 발판에서 출발하거나 거기에 내리는 비행은 위상 때문에 건너뛴다
	if 출발노드 >= n + P or s["끝노드"] == "발판":
		_합계["건너뜀"] += 1
		_스테이지_합계["건너뜀"] += 1
		_다음_비행()
		return
	_죽음 = false
	_공중 = false
	_튐 = false
	_바닥프레임 = 0
	var 첫색 = s["첫색"]
	if 첫색 != null:
		_p.set("자유색", _색(첫색))
	_유령_칠하기(int(_p.get("자유색")))
	var x := float(s["출발"][0])
	var y := float(s["출발"][1])
	if 출발노드 >= n:
		# 도약대 출발: 검사기는 격자 윗면(바닥-1칸)에서 쏘지만 실제 발판 윗면은 바닥에서 23px 위
		var 바닥 := y + 32.0
		_놓기(Vector2(x, 바닥 - 23.0 - 2.0))
		_단계 = "도약대기"
		_f = 0
		# 점프 떼기(뗌)가 있는 도약 비행은 재생할 수 없다(점프를 누르면 바닥 점프가 먼저 나간다)
		if int(s["입력"][3]) < 999:
			_합계["건너뜀"] += 1
			_스테이지_합계["건너뜀"] += 1
			_다음_비행()
		return
	_놓기(Vector2(x, y - 1.0))
	_단계 = "놓임"
	_f = 0


func _출발() -> void:
	var s: Dictionary = _비행들[_bi]
	if not s["점프"]:
		_단계 = "비행"
		_f = 0
		_입력_적용(0)
		return
	if not _p.is_on_floor():
		_결과(false, "출발점에서 바닥에 안 섬 @%s" % _p.global_position)
		return
	_단계 = "비행"
	_f = 0
	Input.action_press("jump")
	_입력_적용(0)


func _입력_적용(f: int) -> void:
	var s: Dictionary = _비행들[_bi]
	var 입력: Array = s["입력"]
	var 바꿈 := int(입력[1])
	_방향(int(입력[0]) if f < 바꿈 else int(입력[2]))
	if f == int(입력[3]):
		Input.action_release("jump")
	Input.action_release("toggle_color")
	for t in s["전환"]:
		if int(t) == f:
			Input.action_press("toggle_color")
			# 다음 프레임에 몸 색이 바뀌므로, 유령판도 새 색으로 미리 칠해 둔다(공중이라 닿아 있지 않다)
			var 새색 := ColorDefs.WHITE if int(_p.get("자유색")) == ColorDefs.BLACK else ColorDefs.BLACK
			_유령_칠하기(새색)


func _판정() -> void:
	var s: Dictionary = _비행들[_bi]
	if _죽음:
		_결과(false, "죽음 @%s 프레임 %d" % [_죽은자리.round(), _f])
		return
	if not _p.is_on_floor():
		_공중 = true
	if s["끝노드"] == "도약":
		if _f > 2 and _p.velocity.y < 도약_판정_속도:
			_결과(true, "도약대 튐")
		elif _공중 and _p.is_on_floor():
			# 도약대는 발판에 한 프레임 선 **다음** 프레임에 튄다 → 10프레임 넘게 서 있으면 그때 실패
			_바닥프레임 += 1
			if _바닥프레임 > 10:
				_결과(false, "도약대가 아닌 곳에 내림 @%s" % _p.global_position.round())
		elif _f > 360:
			_결과(false, "시간 초과")
		return
	if _공중 and _p.is_on_floor() and _f > 2:
		var 끝: Array = s["끝"]
		var dx := absf(_p.global_position.x - float(끝[0]))
		var dy := absf(_p.global_position.y - float(끝[1]))
		if dy <= 착지_허용_y and dx <= 착지_허용_x:
			_결과(true, "")
		elif dy <= 착지_허용_y and _같은_구간(_p.global_position, int(s["to"])):
			_결과(true, "같은 바닥(가로 %.0fpx 어긋남)" % dx)
		else:
			_결과(false, "다른 곳에 내림 @%s · 예상 (%.0f, %.0f)" % [_p.global_position.round(), float(끝[0]), float(끝[1])])
		return
	if _f > 360:
		_결과(false, "시간 초과(안 내림) @%s" % _p.global_position.round())


func _같은_구간(위치: Vector2, 노드: int) -> bool:
	var 구간: Array = _스테이지들[_si]["구간"]
	if 노드 >= 구간.size():
		return false
	var g: Array = 구간[노드]
	return absf(위치.y - float(g[0]) * 32.0) <= 착지_허용_y and 위치.x >= float(g[1]) - 24.0 and 위치.x <= float(g[2]) + 24.0


func _결과(ok: bool, 메모: String) -> void:
	var s: Dictionary = _비행들[_bi]
	var 키 := "성공" if ok else "실패"
	_합계[키] += 1
	_스테이지_합계[키] += 1
	if not ok:
		_기록("  × [%s %d단계] %s→%s · 출발 %s · 입력 %s · 색전환 %s · %s" % [s["길"], int(s["단계"]), int(s["from"]), int(s["to"]), s["출발"], s["입력"], s["전환"], 메모])
	_입력_모두_떼기()
	_다음_비행()
