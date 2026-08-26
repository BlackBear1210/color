extends SceneTree
## ============================================================================
## [2026-08-26 신규] 플레이어 이동 능력 **실측** 도구
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   레벨을 설계할 때 쓰는 숫자(점프 높이·건널 거리·오를 단차·통로 폭)가
##   지금까지는 `지형규칙.gd` 의 **상수**와 `player.gd` 의 **역산 공식**에서 왔다.
##   둘 다 "이론값"이다. 실제로는 아래 것들이 이론값을 깎는다:
##     · 물리 틱(60Hz) 이산화        — 정점을 정확히 못 짚는다
##     · move_and_slide 의 벽 미끄러짐 · floor_snap_length(32)
##     · 낙하 중력 비대칭(2.4배)     — 상승보다 하강이 훨씬 빠르다
##     · 몸 폭 44px                  — 건널 거리는 발 끝이 아니라 몸으로 잰다
##   → **진짜 물리 엔진 위에서 플레이어를 실제로 움직여** 잰다. 이분 탐색으로
##     "되는 최대값 / 안 되는 최소값" 을 좁힌다.
##
## 실행:
##   Godot --headless --path . -s res://tools/측정_플레이어_능력.gd
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 오직 재서 보고만 한다.
## ============================================================================

const 플레이어씬 := "res://scenes/player/Player.tscn"

## ⚠ **스테이지가 Player.tscn 기본값을 덮어쓴다.** 집 챕터 4 방(2층방·거실·부엌·굴뚝)은
##   전부 `점프_거리_칸 = 15`(기본 10) 로 인스턴스 오버라이드가 걸려 있다.
##   그래서 Player.tscn 만 재면 중력 5148 / 거리 174px 이 나오지만, 실제 집 안에서는
##   중력 2288 / 훨씬 긴 포물선이다. 스테이지를 설계할 때 쓸 숫자는 **후자**다.
##   → 잴 설정을 인자로 받는다.
##      -- --거리칸 15   (집 챕터)   /   -- --거리칸 10   (Player.tscn 기본)
var _거리칸: float = -1.0
var _높이칸: float = -1.0

var _루트: Node2D = null
var _플레이어: CharacterBody2D = null
var _결과 := {}


func _initialize() -> void:
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	var 다음 := ""
	for a in args:
		if 다음 == "거리":
			_거리칸 = float(a); 다음 = ""
		elif 다음 == "높이":
			_높이칸 = float(a); 다음 = ""
		elif a == "--거리칸":
			다음 = "거리"
		elif a == "--높이칸":
			다음 = "높이"
	_실행()


func _실행() -> void:
	_루트 = Node2D.new()
	_루트.name = "측정장"
	root.add_child(_루트)
	await process_frame
	await _본체()
	quit(0)


# ── 무대 만들기 ─────────────────────────────────────────────────────────────

## 사각형 정적 지형 하나. (왼쪽 x, 윗면 y, 폭, 두께)
func _블록(x: float, 윗면y: float, 폭: float, 두께: float = 400.0) -> StaticBody2D:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(폭, 두께)
	cs.shape = sh
	b.add_child(cs)
	b.position = Vector2(x + 폭 * 0.5, 윗면y + 두께 * 0.5)
	_루트.add_child(b)
	return b


## 무대를 비우고 플레이어를 새로 놓는다. 매 시행마다 상태를 완전히 초기화한다.
func _무대_초기화(스폰: Vector2) -> void:
	for c in _루트.get_children():
		_루트.remove_child(c)
		c.queue_free()
	await process_frame
	var 씬: PackedScene = load(플레이어씬)
	_플레이어 = 씬.instantiate() as CharacterBody2D
	_플레이어.position = 스폰
	# 스테이지 인스턴스가 하는 것과 **같은 순서**로 오버라이드한다
	# (트리에 들어가기 전에 넣어야 `_ready()` 의 `_점프_재계산()` 이 최종값을 쓴다).
	if _높이칸 > 0.0:
		_플레이어.점프_높이_칸 = _높이칸
	if _거리칸 > 0.0:
		_플레이어.점프_거리_칸 = _거리칸
	_루트.add_child(_플레이어)
	# 사망 판정을 하는 월드는 일부러 안 만든다 — 여기서 재는 것은 순수 이동 성능이다.
	await physics_frame


func _입력_모두_해제() -> void:
	for a in ["move_left", "move_right", "jump"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


## 바닥에 안착할 때까지 기다린다.
func _착지_대기() -> void:
	for i in 180:
		await physics_frame
		if _플레이어.is_on_floor():
			return


# ── 개별 측정 ───────────────────────────────────────────────────────────────

## 1) 몸 치수 + 물리 파라미터
func _잰다_몸() -> void:
	await _무대_초기화(Vector2(0, -300))
	_블록(-2000, 0, 4000)
	await _착지_대기()

	var 몸 := 플레이어몸.재기(_플레이어)
	_결과["PLAYER_COLLISION_WIDTH"] = (몸["크기"] as Vector2).x
	_결과["PLAYER_COLLISION_HEIGHT"] = (몸["크기"] as Vector2).y
	_결과["몸_중심오프셋_y"] = (몸["중심오프셋"] as Vector2).y
	_결과["착지_원점y"] = _플레이어.global_position.y

	# 스프라이트 실크기 = 프레임 텍스처 × (스프라이트 스케일 × 플레이어 스케일)
	var 스: AnimatedSprite2D = _플레이어.get_node_or_null("CharacterSprite")
	if 스 and 스.sprite_frames:
		var 애: String = String(스.animation)
		if 스.sprite_frames.get_frame_count(애) > 0:
			var tex: Texture2D = 스.sprite_frames.get_frame_texture(애, 0)
			var 배 := 스.scale.abs() * _플레이어.scale.abs()
			_결과["PLAYER_WIDTH"] = tex.get_width() * 배.x
			_결과["PLAYER_HEIGHT"] = tex.get_height() * 배.y

	_결과["MOVE_SPEED"] = float(_플레이어.move_speed)
	_결과["JUMP_VELOCITY"] = float(_플레이어.jump_velocity)
	_결과["GRAVITY"] = float(_플레이어.gravity)
	_결과["타일_크기"] = float(_플레이어.타일_크기)
	_결과["점프_높이_칸"] = float(_플레이어.점프_높이_칸)
	_결과["점프_거리_칸"] = float(_플레이어.점프_거리_칸)
	_결과["상승_배수"] = float(_플레이어.상승_배수)
	_결과["floor_snap_length"] = float(_플레이어.floor_snap_length)
	_결과["floor_max_angle_도"] = rad_to_deg(_플레이어.floor_max_angle)
	_결과["물리틱"] = float(Engine.physics_ticks_per_second)


## 2) 제자리 최대 점프 — 높이 · 체공시간
func _잰다_점프() -> void:
	await _무대_초기화(Vector2(0, -300))
	_블록(-2000, 0, 4000)
	await _착지_대기()
	var 시작y := _플레이어.global_position.y
	var 최고 := 시작y
	var 틱 := 0

	Input.action_press("jump")          # 최대 높이를 위해 계속 누른다
	await physics_frame
	await physics_frame
	while 틱 < 400:
		await physics_frame
		틱 += 1
		최고 = minf(최고, _플레이어.global_position.y)
		if 틱 > 6 and _플레이어.is_on_floor():
			break
	_입력_모두_해제()

	_결과["MAX_JUMP_HEIGHT"] = 시작y - 최고
	_결과["체공시간_초"] = 틱 / float(Engine.physics_ticks_per_second)


## 3) 달리며 점프했을 때 넘는 **몸 기준** 최대 수평 간격.
##    두 발판 사이에 폭 G 의 구멍을 두고 실제로 건너게 해 본다.
func _건널까(간격: float) -> bool:
	await _무대_초기화(Vector2(-600, -300))
	_블록(-1200, 0, 1200)                        # 왼쪽 발판 (윗면 y=0, 오른끝 x=0)
	_블록(간격, 0, 2000)                          # 오른쪽 발판
	await _착지_대기()

	Input.action_press("move_right")
	var 뛰었나 := false
	for i in 400:
		await physics_frame
		var p := _플레이어.global_position
		# 발판 끝(원점 x=0)에 닿기 직전에 점프한다. 사람이 하는 최적 타이밍.
		if not 뛰었나 and p.x >= -14.0:
			Input.action_press("jump")
			뛰었나 = true
		if p.y > 600.0:
			_입력_모두_해제()
			return false                          # 구멍으로 떨어졌다
		if 뛰었나 and _플레이어.is_on_floor() and p.x > 간격:
			_입력_모두_해제()
			return true                           # 건너편에 섰다
	_입력_모두_해제()
	return false


## 4) 달려가서 점프로 오를 수 있는 최대 단차.
func _오를까(단차: float) -> bool:
	await _무대_초기화(Vector2(-600, -300))
	_블록(-1200, 0, 1200)                        # 낮은 쪽 (윗면 y=0, 오른끝 x=0)
	_블록(0, -단차, 2000)                         # 높은 쪽 (윗면 y=−단차)
	await _착지_대기()

	Input.action_press("move_right")
	# ⚠ 한 번만 뛰면 안 된다. 단차가 낮을 때는 점프가 너무 일찍 끝나 벽 앞에 처박히고,
	#   그 뒤로는 영영 못 올라간다(CharacterBody2D 는 걸어서 턱을 못 넘는다).
	#   사람이 하듯 **벽에 붙은 채 계속 점프를 시도**한다.
	# ⚠⚠ 그런데 "일정 주기로 눌렀다 뗀다" 로 하면 안 된다. `player.gd` 의 가변 점프
	#   (`JUMP_CUT_MULTIPLIER 0.4`)가 **상승 중에 떼면 속도를 0.4 배로 깎는다**.
	#   집 챕터 세팅(중력 2288)은 상승이 느려서, 0.05 초 만에 떼면 점프 높이가
	#   167px → 59px 로 잘린다. 실제로 처음 측정에서 이 함정에 빠졌다.
	#   → **상승 중에는 절대 떼지 않는다.** 정점을 지났거나 바닥일 때만 뗀다.
	var 누름 := false
	for i in 400:
		await physics_frame
		# ⚠⚠⚠ `Input.action_press()` 는 **약 2 프레임 뒤**에야 player.gd 의
		#   `is_action_just_pressed` 로 보인다(헤드리스 입력 플러시). 그래서 "바닥이고
		#   vy==0 이니 아직 안 뛰었네" 하고 떼면, 그 뗌이 **막 시작된 상승 중**에
		#   도착해 JUMP_CUT(×0.4)을 때린다. 점프가 167px → 40px 로 잘렸다.
		#   → **공중에 뜬 뒤, 정점을 지난 뒤에만** 뗀다.
		if not 누름 and _플레이어.is_on_floor():
			Input.action_press("jump")
			누름 = true
		elif 누름 and not _플레이어.is_on_floor() and _플레이어.velocity.y >= 0.0:
			Input.action_release("jump")
			누름 = false
		var p := _플레이어.global_position
		if _플레이어.is_on_floor() and p.y < -단차 + 8.0 and p.x > 8.0:
			_입력_모두_해제()
			return true
		if p.y > 600.0:
			break
	_입력_모두_해제()
	return false


## 5) 천장 아래 통로를 걸어서 지나갈 수 있는 최소 높이.
func _지날까_통로높이(높이: float) -> bool:
	await _무대_초기화(Vector2(-500, -300))
	_블록(-1200, 0, 3200)                        # 바닥
	_블록(0, -높이 - 400.0, 900, 400.0)           # 천장 (아랫면 y = −높이)
	await _착지_대기()

	Input.action_press("move_right")
	for i in 400:
		await physics_frame
		if _플레이어.global_position.x > 1000.0:
			_입력_모두_해제()
			return true
	_입력_모두_해제()
	return false


## 6) 좌우 벽 사이 **수직 통로(구멍)** 를 떨어져 내려갈 수 있는 최소 폭.
##    ⚠ 지면에 붙은 좌우 벽 사이를 "걸어서" 지나가는 시험은 성립하지 않는다
##      (걷는 길은 벽이 아니라 천장이 좁히는 것이라 5번이 이미 잰다).
##      좁은 폭이 실제로 문제가 되는 곳은 **아래로 내려가는 구멍**이다.
func _내려갈까_구멍폭(폭: float) -> bool:
	await _무대_초기화(Vector2(폭 * 0.5, -900))
	# 위층 바닥: x −1200~0 과 폭~+1600 (그 사이 폭 만큼이 구멍)
	_블록(-1200, -600, 1200, 300.0)
	_블록(폭, -600, 1600, 300.0)
	# 아래층 바닥
	_블록(-1200, 0, 3200)
	# 구멍 옆면을 더 두껍게 — 실제 지형처럼 아래층까지 벽이 이어진다
	_벽(-300.0, 0.0, -600.0, 0.0)
	_벽(폭, 폭 + 300.0, -600.0, 0.0)

	for i in 400:
		await physics_frame
		var p := _플레이어.global_position
		if _플레이어.is_on_floor() and p.y > -60.0:
			_입력_모두_해제()
			return true                       # 아래층 바닥에 닿았다
	_입력_모두_해제()
	return false


## (x0,x1,y0,y1) 사각 벽
func _벽(x0: float, x1: float, y0: float, y1: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(x1 - x0, y1 - y0)
	cs.shape = sh
	b.add_child(cs)
	b.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	_루트.add_child(b)
	return b


## 이분 탐색 — `되나` 가 참인 **최대값**(값이 작을수록 쉬운 경우).
func _최대값(되나: Callable, 하한: float, 상한: float, 정밀도: float) -> float:
	var lo := 하한
	var hi := 상한
	if not await 되나.call(lo):
		return -1.0                       # 하한조차 안 된다 → 측정 실패
	if await 되나.call(hi):
		return hi                         # 상한도 된다 → 상한을 올려야 한다
	while hi - lo > 정밀도:
		var m := (lo + hi) * 0.5
		if await 되나.call(m):
			lo = m
		else:
			hi = m
	return lo


## 이분 탐색 — `되나` 가 참인 **최소값**(값이 클수록 쉬운 경우).
func _최소값(되나: Callable, 하한: float, 상한: float, 정밀도: float) -> float:
	var lo := 하한
	var hi := 상한
	if not await 되나.call(hi):
		return -1.0
	if await 되나.call(lo):
		return lo
	while hi - lo > 정밀도:
		var m := (lo + hi) * 0.5
		if await 되나.call(m):
			hi = m
		else:
			lo = m
	return hi


# ── 본체 ────────────────────────────────────────────────────────────────────

func _본체() -> void:
	print("════════ 플레이어 능력 실측 (물리 엔진 위에서 실제로 움직여 잼) ════════")
	await _잰다_몸()
	await _잰다_점프()

	_결과["MAX_HORIZONTAL_JUMP_DISTANCE"] = await _최대값(_건널까, 32.0, 560.0, 4.0)
	_결과["MAX_CLIMBABLE_STEP_HEIGHT"] = await _최대값(_오를까, 16.0, 340.0, 4.0)
	_결과["MIN_CORRIDOR_HEIGHT"] = await _최소값(_지날까_통로높이, 60.0, 280.0, 2.0)
	_결과["MIN_HOLE_WIDTH"] = await _최소값(_내려갈까_구멍폭, 46.0, 260.0, 2.0)

	# 파생 안전값 — 프로젝트 관례(레벨검사.gd 의 여유율)를 그대로 쓴다
	var 건널: float = _결과["MAX_HORIZONTAL_JUMP_DISTANCE"]
	var 오름: float = _결과["MAX_CLIMBABLE_STEP_HEIGHT"]
	_결과["SAFE_HORIZONTAL_JUMP_DISTANCE"] = 건널 * 0.85
	_결과["SAFE_STEP_HEIGHT"] = 오름 * 0.80
	_결과["MAX_SAFE_DROP_HEIGHT"] = 520.0        # 낙하_감시.치명_낙하거리 기본값
	_결과["SAFE_DROP_HEIGHT"] = 520.0 * 0.75

	print("")
	print("┌────────────────────── 실측 결과 ──────────────────────┐")
	var 순서 := [
		"PLAYER_WIDTH", "PLAYER_HEIGHT",
		"PLAYER_COLLISION_WIDTH", "PLAYER_COLLISION_HEIGHT",
		"몸_중심오프셋_y",
		"MOVE_SPEED", "JUMP_VELOCITY", "GRAVITY",
		"물리틱", "타일_크기", "점프_높이_칸", "점프_거리_칸", "상승_배수",
		"floor_snap_length", "floor_max_angle_도",
		"MAX_JUMP_HEIGHT", "체공시간_초",
		"MAX_HORIZONTAL_JUMP_DISTANCE", "SAFE_HORIZONTAL_JUMP_DISTANCE",
		"MAX_CLIMBABLE_STEP_HEIGHT", "SAFE_STEP_HEIGHT",
		"MIN_CORRIDOR_HEIGHT", "MIN_HOLE_WIDTH",
		"SAFE_DROP_HEIGHT", "MAX_SAFE_DROP_HEIGHT",
	]
	for k in 순서:
		if _결과.has(k):
			print("  %-32s %10.2f" % [k, float(_결과[k])])
	print("└───────────────────────────────────────────────────────┘")
