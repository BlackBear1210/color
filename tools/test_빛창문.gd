extends SceneTree
## ============================================================================
## [2026-08-18 신규] 빛기둥 · 창문커튼 전수 검사 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_빛창문.gd
##
## ▣ 왜 합성 씬을 쓰나 (스마트월드_5.tscn 을 안 열고)
##   실제 스테이지는 지형·장식이 60 개가 넘어 "왜 죽었는지"를 특정할 수 없다.
##   여기서는 **빛 하나 · 창 하나 · 플레이어 하나**만 놓고 좌표를 손으로 정해서
##   정확히 그 상황에서만 죽는지/굳는지 본다. (`test_사망판정.gd` 와 같은 방식)
##
## ▣ 검사하는 것
##   A. 빛기둥 색 계약     — 무색·회색은 아무도 안 죽인다 / 흑·백은 반대색을 죽인다
##   B. 빛기둥 발판 모드   — 무색이면 **통과**(레이어 0), 색이 들면 **굳는다**(레이어 1)
##   C. 빛기둥 경계 모드   — 그룹 `빛경계` 등록 + `위험한가()` 가 겹침으로만 참
##   D. 창문커튼 페인트    — painted / wasted / mixed_gray / blocked / 되돌리기
##   E. 색섞임_회색=false  — 길을 막는 창이 회색으로 죽지 않는다(소프트락 방지)
##   F. 창 → 빛 연동      — 창을 칠하면 자식 빛의 색·굳음이 같이 바뀐다
##   G. ★월드 통합        — `월드.gd _사망_판정()` 이 경계 빛과 굳은 빛을 둘 다 잡는다
##      이게 이 검사의 핵심이다. A~F 가 다 통과해도 월드가 안 물어보면 게임에서는
##      아무 일도 안 일어난다(2026-08-07 에 "규칙은 맞는데 안 죽는다"가 그 모양이었다).
## ============================================================================

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 빛기둥_S := preload("res://scripts/스마트월드/빛기둥.gd")
const 창문_S := preload("res://scripts/스마트월드/창문커튼.gd")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool, 덧말: String = "") -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름 + ("   " + 덧말 if 덧말 != "" else ""))
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 빛기둥 · 창문커튼 검사 ===")
	await _빛_색계약()
	await _빛_발판()
	await _빛_경계()
	await _창문_페인트()
	await _창문_빛연동()
	await _월드_통합()
	await _실제_스테이지()

	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	quit(1 if 실패 > 0 else 0)


# ============================================================================
# 공통
# ============================================================================
## 월드.gd 가 요구하는 최소 구성(Player + 페인트코어)을 갖춘 스테이지.
## ⚠ `_physics_process` 를 끈다 — 켜두면 스스로 리스폰해서 세워둔 좌표가 사라진다
##   (test_사망판정.gd 가 같은 함정에 빠진 적이 있다).
func _스테이지() -> Node2D:
	var 월드 := Node2D.new()
	월드.set_script(월드_S)
	월드.name = "빛검사월드"
	월드.set("치명_낙하거리", 0.0)
	월드.set("낙사_y", 100000.0)
	월드.set("안전지점_자동저장", false)
	월드.set("시작_위치", Vector2.ZERO)

	var 코어 := Node.new()
	코어.set_script(코어_S)
	코어.name = "페인트코어"
	코어.add_to_group("페인트코어")
	월드.add_child(코어)

	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	월드.add_child(p)

	root.add_child(월드)
	월드.set_physics_process(false)
	return 월드


func _빛(부모: Node, 모드: int, 색: int, 위치: Vector2 = Vector2.ZERO) -> Node2D:
	var b: Node2D = 빛기둥_S.new()
	b.name = "빛_%d" % 부모.get_child_count()
	b.set("모드", 모드)
	b.set("각도", 90.0)              # 아래로
	b.set("시작폭", 200.0)
	b.set("끝폭", 200.0)
	b.set("길이", 600.0)
	b.set("물드는시간", 0.0)         # 검사에서는 즉시 물들게 한다
	b.position = 위치
	부모.add_child(b)
	b.set("색", 색)                  # ★트리에 넣은 뒤에 색을 준다(_재구성 이 돌아야 한다)
	return b


func _세우기(월드: Node2D, 좌표: Vector2, 색: int) -> void:
	var p: Node2D = 월드.get_node("Player")
	p.set("velocity", Vector2.ZERO)
	p.global_position = 좌표
	p.set("player_color", 색)
	await physics_frame
	await physics_frame


## ★씬을 **즉시** 치운다.
##
## ⚠[2026-08-20] queue_free() 는 지연 삭제라, 다음 절이 시작될 때까지 낡은 월드가
##   트리에 남아 있을 수 있다. 그러면 그 안의 **낡은 Player 도 그룹 player 에 남는다.**
##   빛기둥._경계_물듦_갱신() 은 그룹에서 첫 번째 플레이어를 집으므로,
##   **엉뚱한(이미 죽은 씬의) 플레이어를 붙잡고** 물듦을 계산해
##   진짜 플레이어는 영원히 안 물든다 — 검사가 이유 없이 실패한다.
##   → 부모에서 떼고 ree() 로 그 자리에서 없앤다.
func _치우기(노드: Node) -> void:
	if 노드 == null or not is_instance_valid(노드):
		return
	if 노드.get_parent():
		노드.get_parent().remove_child(노드)
	노드.free()


func _굳음레이어(빛: Node2D) -> int:
	var b := 빛.get_node_or_null("굳은빛") as StaticBody2D
	return -1 if b == null else b.collision_layer


# ============================================================================
# A. 색 계약
# ============================================================================
func _빛_색계약() -> void:
	print("\n[A] 빛기둥 색 계약")
	var 월드 := _스테이지()
	var 빛 := _빛(월드, 빛기둥_S.모드_.경계, 빛기둥_S.무색)
	await physics_frame

	확인("무색 빛은 아무도 안 죽인다(검정)", not 빛.반대색인가(ColorDefs.BLACK))
	확인("무색 빛은 아무도 안 죽인다(흰색)", not 빛.반대색인가(ColorDefs.WHITE))
	빛.색_지정(ColorDefs.GRAY)
	확인("회색 빛은 아무도 안 죽인다", not 빛.반대색인가(ColorDefs.BLACK))
	빛.색_지정(ColorDefs.WHITE)
	확인("★흰 빛 + 검정 플레이어 = 반대색이다", 빛.반대색인가(ColorDefs.BLACK))
	확인("흰 빛 + 흰 플레이어 = 안전하다", not 빛.반대색인가(ColorDefs.WHITE))
	확인("현재색()이 지정한 색을 돌려준다", 빛.현재색() == ColorDefs.WHITE)
	_치우기(월드)
	await process_frame


# ============================================================================
# B. 발판 모드 — 굳음/풀림이 물리 레이어로 나타나는가
# ============================================================================
func _빛_발판() -> void:
	print("\n[B] 빛기둥 발판 모드")
	var 월드 := _스테이지()
	var 빛 := _빛(월드, 빛기둥_S.모드_.발판, 빛기둥_S.무색)
	await physics_frame

	확인("무색 빛은 안 굳는다 (레이어 0 = 통과)", _굳음레이어(빛) == 0,
		"레이어 %d" % _굳음레이어(빛))
	빛.색_지정(ColorDefs.BLACK)
	await physics_frame
	확인("★검정으로 물들면 굳는다 (레이어 1 = 밟는 지형)", _굳음레이어(빛) == 1,
		"레이어 %d" % _굳음레이어(빛))
	빛.색_지정(ColorDefs.GRAY)
	await physics_frame
	확인("회색이 되면 다시 풀린다 (레이어 0)", _굳음레이어(빛) == 0)
	빛.색_지정(빛기둥_S.무색)
	await physics_frame
	확인("무색으로 되돌리면 풀린다 (레이어 0)", _굳음레이어(빛) == 0)

	# 콜리전 폴리곤이 실제로 만들어져 있는가 — 레이어만 맞고 모양이 없으면 안 밟힌다
	var cp := 빛.get_node_or_null("굳은빛/모양") as CollisionPolygon2D
	확인("굳은빛에 콜리전 폴리곤이 있다 (점 4개)", cp != null and cp.polygon.size() == 4)
	_치우기(월드)
	await process_frame


# ============================================================================
# C. 경계 모드 — 그룹 등록 + 겹침으로만 위험
# ============================================================================
func _빛_경계() -> void:
	print("\n[C] 빛기둥 경계 모드")
	var 월드 := _스테이지()
	# 빛은 (0,0) 에서 아래로 600px, 폭 200px → x −100~100 · y 0~600
	var 빛 := _빛(월드, 빛기둥_S.모드_.경계, ColorDefs.WHITE)
	await physics_frame
	await physics_frame

	확인("경계 모드는 그룹 `빛경계` 에 등록된다", 빛.is_in_group("빛경계"))
	확인("경계 모드는 안 굳는다 (통과된다)", _굳음레이어(빛) == 0)

	# ★[2026-08-20] 경계는 **죽이지 않는다.** 색을 강제한다.
	#   `강제색()` 은 "이 경계가 지금 강제하는 색" 을 돌려주고, 강제 안 하면 −1 이다.
	빛.set("물듦_시간", 0.0)          # 검사에서는 즉시 물들게 한다
	var p: Node = 월드.get_node("Player")
	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)
	for i in 6:
		await process_frame
	확인("★흰 경계 안 + 검정 플레이어 → 흰색을 강제한다", 빛.강제색(p.global_position) == ColorDefs.WHITE)
	# ⚠ 빠져나온 뒤에는 **물듦이 빠질 시간**이 필요하다(0.3초쯤). 한 프레임만 기다리면
	#   아직 가득 찬 상태라 여전히 강제한다 — 검사가 아니라 대기가 모자란 것이다.
	await _세우기(월드, Vector2(2000, 300), ColorDefs.BLACK)
	for i in 30:
		await process_frame
	확인("빛 밖이면 아무 색도 강제하지 않는다 (−1)", 빛.강제색(p.global_position) == -1)

	빛.색_지정(빛기둥_S.무색)
	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)
	for i in 6:
		await process_frame
	확인("무색 빛은 아무 색도 강제하지 않는다", 빛.강제색(p.global_position) == -1)

	# ── 물듦 연출 ── 가까이 갈수록 몸이 차오른다 (도형님 요청)
	빛.색_지정(ColorDefs.WHITE)
	빛.set("물듦_반경", 200.0)
	await _세우기(월드, Vector2(2000, 300), ColorDefs.BLACK)   # 아주 멀리
	for i in 8:
		await process_frame
	확인("멀리 있으면 물듦 0", 빛.물듦_진행도() < 0.02, "%.2f" % 빛.물듦_진행도())
	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)      # 빛 한가운데
	# ⚠[2026-08-23] **최대값**으로 잰다. 차오름은 경고 연출이라, 색을 다 빼앗기고 나면
	#   `_경계_물듦_갱신()` 이 곧바로 다시 뺀다("이미 같은 색이면 물들 것이 없다").
	#   예전에는 색 강제를 테스트가 손으로 불러야 해서 이 구간에서 플레이어가 검정인 채로
	#   남아 있었고, 10프레임 뒤에도 1.0 이 유지됐다. 지금은 플레이어가 스스로 색을
	#   당겨가므로 몇 프레임 만에 흰색이 되고 연출이 빠진다 — 정상이다.
	#   확인해야 할 것은 "지금 가득 차 있나" 가 아니라 "끝까지 차오른 적이 있나" 다.
	#   그런데 샘플링으로 최고점을 잡는 것도 불안정하다 — 1.0 에 닿는 프레임과
	#   `await process_frame` 이 돌아오는 시점이 어긋나면 0.93 쯤에서 놓친다.
	#   → **`강제색()` 이 걸렸는지**로 확인한다. `_강제_걸림` 은 `_물듦_진행` 이 1.0 에
	#     도달해야만 켜지므로(빛기둥.gd `_경계_물듦_갱신`), 이게 곧 "끝까지 찼다"의 증거다.
	var 최대_물듦 := 0.0
	for i in 10:
		await process_frame
		최대_물듦 = maxf(최대_물듦, 빛.물듦_진행도())
	확인("★빛 안에서는 몸이 끝까지 차오른다 (강제가 걸렸다 = 진행도가 1.0 에 닿았다)",
		빛.강제색(Vector2(0, 300)) == ColorDefs.WHITE, "최고 %.2f" % 최대_물듦)
	확인("차오르는 동안 연출이 눈에 보인다", 최대_물듦 > 0.5, "최고 %.2f" % 최대_물듦)
	확인("차오름 오버레이가 생긴다", 빛.get_node_or_null("차오름") != null)
	확인("오버레이는 씬에 저장되지 않는다 (owner 없음)",
		빛.get_node_or_null("차오름") == null or 빛.get_node("차오름").owner == null)
	_치우기(월드)
	await process_frame


# ============================================================================
# D·E. 창문커튼 페인트 규칙
# ============================================================================
func _창문_페인트() -> void:
	print("\n[D] 창문커튼 페인트 규칙")
	var 월드 := _스테이지()
	var 창: Node2D = 창문_S.new()
	창.name = "창"
	창.set("빛_모드", 2)
	월드.add_child(창)
	await physics_frame

	확인("처음에는 무색이다", 창.현재색() == 빛기둥_S.무색)
	확인("★한 발에 칠해진다", 창.명중(ColorDefs.BLACK, Vector2.ZERO) == "painted")
	확인("칠한 색이 남는다", 창.현재색() == ColorDefs.BLACK)
	# ★[2026-08-20] 커튼은 **좌·우가 따로** 닫힌다. 같은 색이라도 **아직 안 닫힌 쪽**을
	#   쏘면 그쪽이 닫히므로 "painted" 다. 낭비는 **이미 닫힌 쪽**을 또 쏠 때만.
	확인("★같은 색으로 반대쪽을 쏘면 그쪽이 닫힌다",
		창.명중(ColorDefs.BLACK, 창.global_position - Vector2(60, 0)) == "painted")
	확인("이미 닫힌 쪽을 또 쏘면 낭비다",
		창.명중(ColorDefs.BLACK, 창.global_position - Vector2(60, 0)) == "wasted")
	확인("★다른 색을 덮으면 회색이 된다", 창.명중(ColorDefs.WHITE, Vector2.ZERO) == "mixed_gray")
	확인("회색이 남는다", 창.현재색() == ColorDefs.GRAY)
	확인("회색이 되면 더는 못 칠한다", 창.명중(ColorDefs.BLACK, Vector2.ZERO) == "blocked")
	확인("회색은 회수해도 안 열린다", not 창.되돌리기())
	확인("창틀 자체는 아무도 안 죽인다", not 창.반대색인가(ColorDefs.BLACK))

	# ── 회수(E) ──
	var 창2: Node2D = 창문_S.new()
	창2.name = "창2"
	월드.add_child(창2)
	await physics_frame
	창2.명중(ColorDefs.WHITE, Vector2.ZERO)
	확인("★E 회수하면 커튼이 열리고 무색으로 돌아온다",
		창2.되돌리기() and 창2.현재색() == 빛기둥_S.무색)
	확인("무색이면 회수할 게 없다", not 창2.되돌리기())

	print("\n[E] 색섞임_회색 = false (길을 막는 창의 소프트락 방지)")
	var 창3: Node2D = 창문_S.new()
	창3.name = "창3"
	창3.set("색섞임_회색", false)
	월드.add_child(창3)
	await physics_frame
	창3.명중(ColorDefs.BLACK, Vector2.ZERO)
	확인("★덮어 쏘면 회색이 아니라 다시 칠해진다",
		창3.명중(ColorDefs.WHITE, Vector2.ZERO) == "painted")
	확인("덮어 쓴 색이 남는다", 창3.현재색() == ColorDefs.WHITE)
	확인("회색이 되지 않는다 = 영구 소프트락이 없다", 창3.현재색() != ColorDefs.GRAY)
	_치우기(월드)
	await process_frame


# ============================================================================
# F. 창 → 빛 연동
# ============================================================================
func _창문_빛연동() -> void:
	print("\n[F] 창 → 빛 연동")
	var 월드 := _스테이지()
	var 창: Node2D = 창문_S.new()
	창.name = "창"
	창.set("빛_모드", 2)                 # 발판
	창.set("커튼_시간", 0.05)
	월드.add_child(창)
	await physics_frame

	var 빛 := 창.get_node_or_null("빛") as Node2D
	확인("창이 자식 빛을 만든다", 빛 != null)
	if 빛 == null:
		월드.queue_free()
		return
	확인("빛이 씬에 저장되지 않는다 (owner 없음 — §5-1 세그폴트 방지)", 빛.owner == null)
	확인("처음에는 빛이 무색이라 안 굳는다", _굳음레이어(빛) == 0)

	창.명중(ColorDefs.WHITE, Vector2.ZERO)
	await physics_frame
	확인("★창을 칠하면 빛이 같은 색이 된다", 빛.현재색() == ColorDefs.WHITE)
	확인("★창을 칠하면 빛이 굳는다 (레이어 1)", _굳음레이어(빛) == 1,
		"레이어 %d" % _굳음레이어(빛))

	# 커튼이 실제로 닫히는가 — 0.05 초짜리라 4 프레임이면 충분하다
	for i in 6:
		await process_frame
	확인("커튼이 닫힌다", float(창.get("_닫힘")) > 0.99,
		"닫힘 %.2f" % float(창.get("_닫힘")))

	창.되돌리기()
	await physics_frame
	확인("회수하면 빛도 무색으로 풀린다",
		빛.현재색() == 빛기둥_S.무색 and _굳음레이어(빛) == 0)
	_치우기(월드)
	await process_frame


# ============================================================================
# G. ★월드 통합 — 실제로 게임에서 죽는가
# ============================================================================
func _월드_통합() -> void:
	print("\n[G] 월드 사망 판정 통합")
	var 월드 := _스테이지()
	var p: Node = 월드.get_node("Player")

	# ── ① 경계 빛 ── ★죽이지 않는다. **색을 강제한다.**
	#   `월드._지대_적용()` 이 그룹 `빛경계` 를 훑어 `강제색()` 을 물어본다.
	var 경계빛 := _빛(월드, 빛기둥_S.모드_.경계, ColorDefs.WHITE, Vector2(0, 0))
	경계빛.set("물듦_시간", 0.0)
	await physics_frame
	await physics_frame

	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)
	for i in 6:
		await process_frame
	확인("★흰 경계빛은 사람을 죽이지 않는다 (경계 = 색 강제)",
		not bool(월드.call("_사망_판정")))
	# ⚠[2026-08-19] 물듦(_process)이 다 차오르기까지 몇 프레임 걸린다. 그런데 플레이어는
	#   **중력으로 떨어지는 물체**라, 빔(길이 600) 안 공중에 놓고 그냥 기다리면 물듦이 차기 전에
	#   빔 밖으로 떨어져 버린다(실측: d 가 1000px 넘게 벌어져 강제 실패). 예전 6프레임 고정은
	#   "떨어지기 전에 우연히 채워졌다" 에 기댄 것이라 스크립트가 조금만 바뀌면 흔들렸다.
	#   → 정착하는 동안 **플레이어를 빔 한가운데에 매 프레임 고정**해 빔 안에 머물게 한다.
	#     그러면 물듦이 결정적으로 1.0 에 도달하고 색이 강제된다.
	var _pl: Node2D = 월드.get_node("Player")
	for _i in 10:
		_pl.set("velocity", Vector2.ZERO)
		_pl.global_position = Vector2(0, 300)   # 중력 낙하로 빔을 벗어나지 않게 고정
		await physics_frame
		_pl.call("_대표색_갱신")
		if int(_pl.get("player_color")) == ColorDefs.WHITE:
			break
	확인("★흰 경계빛 안에 있으면 플레이어가 흰색이 된다",
		int(_pl.get("player_color")) == ColorDefs.WHITE)

	# Shift 로 되돌려도 같은 프레임에 다시 강제된다 = 잠금
	월드.get_node("Player").call("_toggle_color")
	_pl.call("_대표색_갱신")
	확인("★Shift 로 바꿔도 경계가 되돌린다 (색 전환 잠금)",
		int(월드.get_node("Player").get("player_color")) == ColorDefs.WHITE)

	경계빛.색_지정(빛기둥_S.무색)
	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)
	_pl.call("_대표색_갱신")
	확인("무색으로 풀면 색을 안 뺏는다",
		int(월드.get_node("Player").get("player_color")) == ColorDefs.BLACK)
	경계빛.queue_free()
	await process_frame

	# ── ② 굳은 빛(발판) ── 레이어 1 이라 **월드를 한 줄도 안 고쳐도** 지형 판정이 잡는다.
	var 발판빛 := _빛(월드, 빛기둥_S.모드_.발판, ColorDefs.BLACK, Vector2(0, 0))
	await physics_frame
	await physics_frame

	await _세우기(월드, Vector2(0, 300), ColorDefs.WHITE)
	확인("★검정으로 굳은 빛 + 흰 플레이어 → 죽는다 (지형과 같은 계약)",
		bool(월드.call("_사망_판정")))
	await _세우기(월드, Vector2(0, 300), ColorDefs.BLACK)
	확인("검정으로 굳은 빛 + 검정 플레이어 → 안 죽는다 (딛고 설 수 있다)",
		not bool(월드.call("_사망_판정")))
	발판빛.색_지정(빛기둥_S.무색)
	await _세우기(월드, Vector2(0, 300), ColorDefs.WHITE)
	확인("무색으로 풀면 몸이 통과한다 → 안 죽는다", not bool(월드.call("_사망_판정")))

	# ── ③ 회귀 방지 ── 빛이 하나도 없는 허공에서 죽으면 안 된다
	발판빛.queue_free()
	await process_frame
	await _세우기(월드, Vector2(4000, 4000), ColorDefs.BLACK)
	확인("빛이 없는 허공에서는 안 죽는다 (회귀 방지)", not bool(월드.call("_사망_판정")))
	_치우기(월드)
	await process_frame


# ============================================================================
# H. ★실제 스테이지 — 합성 씬이 아니라 구운 씬에서 진짜로 작동하는가
# ============================================================================
## ▣ 왜 이게 따로 필요한가
##   G 까지는 **우리가 손으로 조립한** 월드다. 실제 스테이지에는 지형 60 개, 장식 50 개,
##   통로, 카메라 공간이 같이 있고, 빌더가 배치한 좌표가 한 칸만 어긋나도
##   "빛은 있는데 아무 데도 안 닿는" 상태가 된다 — 검사로는 안 잡히고 눈으로만 보인다.
##   ★2026-08-18 에 실제로 이걸로 발견했다: 스크린샷을 찍으려고 플레이어를 지붕 구멍
##     빛(흰색) 한가운데에 놓았더니, 캡처 시점에는 플레이어가 **입구까지 되돌아가 있었다.**
##     빛에 닿아 죽고 리스폰된 것이다 — 사망 판정이 실전에서 도는 증거였다.
##   → 그 우연을 **검사로 고정**한다.
func _실제_스테이지() -> void:
	print("\n[H] 실제 스테이지(스마트월드_7)에서의 사망 판정")
	var 경로 := "res://scenes/스마트월드/스마트월드_7.tscn"
	if not ResourceLoader.exists(경로):
		확인("스마트월드_7 씬이 있다", false)
		return
	var 스테이지 := (load(경로) as PackedScene).instantiate() as Node2D
	root.add_child(스테이지)
	await physics_frame
	await physics_frame

	확인("스마트월드_7 이 열린다", 스테이지 != null)
	var 빛들 := []
	for b in get_nodes_in_group("빛경계"):
		if 스테이지.is_ancestor_of(b):
			빛들.append(b)
	확인("★지붕 구멍 빛 4 개가 경계로 등록돼 있다", 빛들.size() == 4,
		"실제 %d 개" % 빛들.size())
	# ★흑·백이 번갈아 있어야 한다 (도형님 요청: "전부 흰색이 아닌 검정색도 번갈아")
	var 흰 := 0
	var 검 := 0
	for b in 빛들:
		if int(b.현재색()) == ColorDefs.WHITE:
			흰 += 1
		elif int(b.현재색()) == ColorDefs.BLACK:
			검 += 1
	확인("★흰 경계와 검정 경계가 둘 다 있다", 흰 > 0 and 검 > 0, "흰 %d · 검정 %d" % [흰, 검])

	# ⚠ 그룹 전체가 아니라 **이 스테이지 안**의 것만 센다.
	#   검사 중에는 앞 절의 씬이 잠깐 남아 있을 수 있어 그룹 전체를 세면 흔들린다.
	var 창들 := []
	for c in get_nodes_in_group("창문커튼"):
		if 스테이지.is_ancestor_of(c):
			창들.append(c)
	확인("지붕창이 1 개 있다", 창들.size() == 1, "실제 %d 개" % 창들.size())

	# ── 자기 사망 방지를 위해 월드의 자동 리스폰을 끈다(좌표를 우리가 정한다) ──
	스테이지.set_physics_process(false)
	var p: Node2D = 스테이지.get_node_or_null("Player")
	확인("Player 가 있다", p != null)
	if p == null:
		스테이지.queue_free()
		return

	# 빌더가 놓은 좌표 그대로 — 첫 번째 구멍 빛은 x=900 의 **흰** 빛이다.
	# ★경계는 죽이지 않는다. 대신 색을 빼앗는다.
	for b in 빛들:
		b.set("물듦_시간", 0.0)
	p.set("velocity", Vector2.ZERO)
	p.global_position = Vector2(900, 640)          # 빌더가 놓은 첫 구멍(흰색)
	p.set("player_color", ColorDefs.BLACK)
	await physics_frame
	for i in 6:
		await process_frame
	확인("★x=900 의 흰 경계 안 — 죽지 않는다", not bool(스테이지.call("_사망_판정")))
	p.call("_대표색_갱신")
	확인("★x=900 의 흰 경계 안 — 플레이어가 흰색이 된다",
		int(p.get("player_color")) == ColorDefs.WHITE)

	# 두 번째 구멍은 x=2200 의 **검정** 경계 — 색이 뒤집혀야 한다.
	p.global_position = Vector2(2200, 640)
	await physics_frame
	for i in 6:
		await process_frame
	p.call("_대표색_갱신")
	확인("★x=2200 의 검정 경계 안 — 플레이어가 검정이 된다",
		int(p.get("player_color")) == ColorDefs.BLACK)

	# 빛과 빛 사이(안전지대)에서는 아무 색도 안 뺏기고 죽지도 않는다 — 회귀 방지
	p.global_position = Vector2(1550, 640)
	p.set("player_color", ColorDefs.WHITE)
	await physics_frame
	for i in 6:
		await process_frame
	p.call("_대표색_갱신")
	확인("빛 사이(x=1550)에서는 색을 안 뺏는다", int(p.get("player_color")) == ColorDefs.WHITE)
	확인("빛 사이(x=1550)에서는 안 죽는다", not bool(스테이지.call("_사망_판정")))

	_치우기(스테이지)
	await process_frame
