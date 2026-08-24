extends SceneTree
## ============================================================================
## [2026-08-01 신규] 페인트 시스템 v4 규칙 자동 검증
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/test_페인트v4.gd
##
## ▣ 무엇을 검사하나 (2026-08-24 변경 규칙)
##   1. 완성된 지형의 반대색 명중은 회색 없이 마지막 색으로 덮어쓴다
##   2. 덮어쓴 페인트도 한 대상의 같은 FIFO 항목으로 회수된다
##   3. 빗나감 / 같은 색 덧칠 / 칠할 수 없는 대상 → 페인트는 즉시 환급
##   4. 흑·백 부분칠이 함께 있으면 어느 쪽도 전체칠이 되지 않는다
##   5. 부분칠은 4초 유지 + 1초 감쇠 뒤 색별로 자동 회수된다
##
## ▣ 왜 실제 씬이 아니라 가짜 대상으로 검사하나
##   규칙은 페인트_코어.gd 안에만 있다. 지형·식물은 "무슨 색인지"만 답하면 되므로,
##   최소한의 가짜 대상으로 규칙만 떼어 검사하는 게 빠르고 실패 원인도 명확하다.
##   (지형 렌더링까지 묶어 검사하면 셰이더 문제인지 규칙 문제인지 구분이 안 된다)
## ============================================================================

var 통과 := 0
var 실패 := 0


## 규칙 검사용 최소 대상 — 지형과 똑같은 상태 전이만 흉내낸다.
class 가짜대상 extends Node:
	var 필요: int = 1
	var 색: int = -1
	var _진행 = preload("res://scripts/페인트_진행.gd").new()
	var 칠가능: bool = true

	func 명중(c: int, _p: Vector2) -> String:
		if not 칠가능:
			return "blocked"
		if 색 >= 0:
			if c == 색:
				return "wasted"
			# 플레이어가 쏜 반대색은 혼합하지 않고 바로 마지막 색으로 덮어쓴다.
			색 = c
			return "painted"
		if _진행.명중(c, 필요):
			색 = c
			_진행.비우기()
			return "painted"
		return "progress"

	func 되돌리기() -> bool:
		if not 칠가능:
			return false
		색 = -1
		_진행.비우기()
		return true

	func 현재색() -> int:
		return 색

	func 시간진행(delta: float) -> Dictionary:
		var 결과: Dictionary = _진행.진행(delta, 필요)
		if int(결과["완성색"]) >= 0:
			색 = int(결과["완성색"])
			_진행.비우기()
		return 결과

	func 부분횟수(c: int) -> int:
		return _진행.횟수(c)


func _init() -> void:
	_검사_덮어쓰기()
	_검사_덮어쓰기_발수()
	_검사_FIFO()
	_검사_리셋()
	_검사_환급()
	_검사_부분누적과_양색차단()
	_검사_실제_발판()
	print("\n[test_페인트v4] 통과 %d / 실패 %d" % [통과, 실패])
	quit(1 if 실패 > 0 else 0)


func 확인(이름: String, 실제, 기대) -> void:
	if 실제 == 기대:
		통과 += 1
		print("  ✔ %s" % 이름)
	else:
		실패 += 1
		print("  ✘ %s — 기대 %s, 실제 %s" % [이름, str(기대), str(실제)])


func _코어(최대: int = 10) -> 페인트코어:
	var c := 페인트코어.new()
	c.최대_탄약 = 최대
	root.add_child(c)          # _ready() 가 돌아야 리셋()으로 잔량이 채워진다
	return c


func _쏘기(코어: 페인트코어, 대상: Node, 색: int) -> String:
	코어.발사_소모()
	return 코어.명중_처리(대상, 색, Vector2.ZERO)


# ── 규칙 1 ─────────────────────────────────────────────────────────────────
func _검사_덮어쓰기() -> void:
	print("\n[규칙 1] 반대색은 회색 없이 마지막 색으로 덮어쓰기")
	var 코어 := _코어()
	var t := 가짜대상.new()
	확인("검정으로 칠하면 painted", _쏘기(코어, t, ColorDefs.BLACK), "painted")
	확인("그 위에 흰색 → painted", _쏘기(코어, t, ColorDefs.WHITE), "painted")
	확인("상태가 흰색", t.현재색(), ColorDefs.WHITE)
	확인("다시 검정을 쏘면 또 덮어쓴다", _쏘기(코어, t, ColorDefs.BLACK), "painted")
	확인("어느 단계에서도 회색이 아니다", t.현재색() != ColorDefs.GRAY, true)
	코어.queue_free()


# ── 규칙 2 ─────────────────────────────────────────────────────────────────
func _검사_덮어쓰기_발수() -> void:
	print("\n[규칙 2] 덮어쓴 발수도 같은 대상의 회수줄에 누적")
	var 코어 := _코어(10)
	var t := 가짜대상.new()
	_쏘기(코어, t, ColorDefs.BLACK)
	확인("첫 칠 후 잔량 9", 코어.남은_탄약, 9)
	_쏘기(코어, t, ColorDefs.WHITE)
	확인("덮어쓰기 후 잔량 8", 코어.남은_탄약, 8)
	확인("회색 잠긴 발수는 0", 코어.잠긴_발수(), 0)
	확인("회수줄에는 같은 대상 하나", 코어.회수_대기수(), 1)
	확인("한 번 회수하면 두 발 모두 환급", 코어.수동_회수(), true)
	확인("회수 뒤 잔량 10", 코어.남은_탄약, 10)
	코어.queue_free()


# ── FIFO 회수 ──────────────────────────────────────────────────────────────
func _검사_FIFO() -> void:
	print("\n[FIFO] 덮어써도 최초 등록 순서를 유지")
	var 코어 := _코어(20)
	var 대상 := []
	for i in 6:
		대상.append(가짜대상.new())
	_쏘기(코어, 대상[0], ColorDefs.BLACK)
	_쏘기(코어, 대상[1], ColorDefs.WHITE)
	_쏘기(코어, 대상[2], ColorDefs.BLACK)
	_쏘기(코어, 대상[3], ColorDefs.BLACK)
	# 5번은 검정으로 칠한 뒤 흰색으로 덮어도 같은 FIFO 자리에 남아야 한다.
	_쏘기(코어, 대상[4], ColorDefs.BLACK)
	_쏘기(코어, 대상[4], ColorDefs.WHITE)
	_쏘기(코어, 대상[5], ColorDefs.WHITE)

	확인("회수줄에 대상 6개", 코어.회수_대기수(), 6)
	var 순서 := []
	while 코어.회수_대기수() > 0:
		var 다음 := 코어.다음_회수대상()
		순서.append(대상.find(다음))
		코어.수동_회수()
	확인("회수 순서 = 0,1,2,3,4,5", str(순서), str([0, 1, 2, 3, 4, 5]))
	확인("덮어쓴 대상도 무색으로 회수", 대상[4].현재색(), -1)
	코어.queue_free()


# ── 스테이지 리셋 ──────────────────────────────────────────────────────────
func _검사_리셋() -> void:
	print("\n[리셋] 스테이지 이동 = 덮어쓴 페인트 포함 전량 회수")
	var 코어 := _코어(10)
	var 덮은대상 := 가짜대상.new()
	var 보통대상 := 가짜대상.new()
	_쏘기(코어, 덮은대상, ColorDefs.BLACK)
	_쏘기(코어, 덮은대상, ColorDefs.WHITE)
	_쏘기(코어, 보통대상, ColorDefs.BLACK)
	확인("리셋 전 잔량 7", 코어.남은_탄약, 7)
	코어.리셋()
	확인("리셋 후 잔량 최대", 코어.남은_탄약, 10)
	확인("리셋 후 회수줄 비었다", 코어.회수_대기수(), 0)
	확인("리셋 후 잠긴 발수 0", 코어.잠긴_발수(), 0)
	확인("덮어쓴 대상도 무색으로", 덮은대상.현재색(), -1)
	확인("보통 대상은 무색으로", 보통대상.현재색(), -1)
	코어.queue_free()


# ── 규칙 6 ─────────────────────────────────────────────────────────────────
func _검사_환급() -> void:
	print("\n[규칙 6] 빗나감 / 같은 색 / 칠 불가 → 즉시 환급")
	var 코어 := _코어(10)
	코어.발사_소모()
	확인("빗나감 결과", 코어.명중_처리(null, ColorDefs.BLACK, Vector2.ZERO), "miss")
	확인("빗나가면 잔량 그대로", 코어.남은_탄약, 10)

	var t := 가짜대상.new()
	_쏘기(코어, t, ColorDefs.BLACK)
	확인("칠하면 9", 코어.남은_탄약, 9)
	확인("같은 색 덧칠 = wasted", _쏘기(코어, t, ColorDefs.BLACK), "wasted")
	확인("wasted 는 환급되어 9 유지", 코어.남은_탄약, 9)

	var 못칠함 := 가짜대상.new()
	못칠함.칠가능 = false
	확인("칠 불가 대상 = blocked", _쏘기(코어, 못칠함, ColorDefs.WHITE), "blocked")
	확인("blocked 도 환급되어 9 유지", 코어.남은_탄약, 9)
	코어.queue_free()


# ── 부분칠 규칙 ─────────────────────────────────────────────────────────────
func _검사_부분누적과_양색차단() -> void:
	print("\n[부분칠] 크기별 누적 · 양색 완성 차단 · 색별 자동 회수")
	var 코어 := _코어(10)
	var t := 가짜대상.new()
	t.필요 = 3
	확인("1발째 progress", _쏘기(코어, t, ColorDefs.BLACK), "progress")
	확인("2발째 progress", _쏘기(코어, t, ColorDefs.BLACK), "progress")
	확인("3발째 painted", _쏘기(코어, t, ColorDefs.BLACK), "painted")
	확인("잔량 7", 코어.남은_탄약, 7)
	확인("회수줄 1개", 코어.회수_대기수(), 1)
	코어.수동_회수()
	확인("회수하면 3발 전부 환급", 코어.남은_탄약, 10)

	# 완성 전에 같은 색 부분칠이 모두 흐려져 자동 회수되는 경우.
	var t2 := 가짜대상.new()
	t2.필요 = 3
	_쏘기(코어, t2, ColorDefs.BLACK)
	_쏘기(코어, t2, ColorDefs.BLACK)
	확인("부분 2발 소모 → 8", 코어.남은_탄약, 8)
	var 만료2: Dictionary = t2.시간진행(5.1)["만료"]
	코어.부분_자동회수(t2, int(만료2.get(ColorDefs.BLACK, 0)))
	확인("자동 회수 후 10", 코어.남은_탄약, 10)

	# 흑·백이 동시에 부분칠이면 횟수를 채워도 완성되지 않는다. 먼저 묻은 검정만
	# 5초를 채워 사라지면, 아직 살아 있는 흰색 3발이 그 순간 전체칠로 승격한다.
	var t3 := 가짜대상.new()
	t3.필요 = 3
	_쏘기(코어, t3, ColorDefs.BLACK)
	_쏘기(코어, t3, ColorDefs.BLACK)
	t3.시간진행(2.0)
	_쏘기(코어, t3, ColorDefs.WHITE)
	_쏘기(코어, t3, ColorDefs.WHITE)
	확인("백 3발째도 검정 부분칠이 남아 progress",
		_쏘기(코어, t3, ColorDefs.WHITE), "progress")
	확인("양색이 함께 있으면 아직 무색", t3.현재색(), -1)
	확인("검정 2발과 흰색 3발이 따로 남는다",
		[t3.부분횟수(ColorDefs.BLACK), t3.부분횟수(ColorDefs.WHITE)], [2, 3])
	var 만료3: Dictionary = t3.시간진행(3.1)["만료"]
	코어.부분_자동회수(t3, int(만료3.get(ColorDefs.BLACK, 0)))
	확인("검정만 사라지면 흰색으로 자동 완성", t3.현재색(), ColorDefs.WHITE)
	확인("만료된 검정 2발만 환급", 코어.남은_탄약, 7)
	코어.수동_회수()
	확인("완성된 흰색 3발 회수 후 10", 코어.남은_탄약, 10)
	코어.queue_free()


## 가짜 규칙 객체만 맞고 실제 발판 연결이 빠지는 회귀를 막기 위해 실제 클래스로도 한 번 검증한다.
func _검사_실제_발판() -> void:
	print("\n[실제 발판] PaintPlatform 연결 검증")
	var 발판 := PaintPlatform.new()
	발판.필요횟수_수동 = 3
	root.add_child(발판)
	확인("실제 발판 검정 1발은 부분칠", 발판.명중(ColorDefs.BLACK, Vector2.ZERO), "progress")
	확인("실제 발판 검정 2발도 부분칠", 발판.명중(ColorDefs.BLACK, Vector2.ZERO), "progress")
	발판._process(2.0)
	발판.명중(ColorDefs.WHITE, Vector2.ZERO)
	발판.명중(ColorDefs.WHITE, Vector2.ZERO)
	확인("실제 발판도 양색이면 백 3발째 완성 차단",
		발판.명중(ColorDefs.WHITE, Vector2.ZERO), "progress")
	발판._process(3.1)
	확인("검정 부분칠 만료 뒤 실제 발판은 흰색 완성",
		발판.현재상태, PaintPlatform.상태.흰색)
	확인("완성 발판에 검정을 쏘면 회색 없이 덮어쓰기",
		발판.명중(ColorDefs.BLACK, Vector2.ZERO), "painted")
	확인("실제 발판 최종색은 검정", 발판.현재상태, PaintPlatform.상태.검정)
	root.remove_child(발판)
	발판.free()
