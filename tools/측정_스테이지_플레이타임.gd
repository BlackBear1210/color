extends SceneTree
## ============================================================================
## [2026-08-29 신규] 스테이지 **직진 관통 시간**과 규모를 잰다
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/측정_스테이지_플레이타임.gd
##   godot --headless --path . -s res://tools/측정_스테이지_플레이타임.gd -- <씬경로> [<씬경로>...]
##   (인자가 없으면 집 챕터 4 방을 잰다)
##
## ▣ 왜 필요한가
##   "새 스테이지를 기존보다 3 배 길게" 를 정하려면 **기존이 얼마인지**를 먼저
##   숫자로 알아야 한다. `레벨검사.gd` 는 넓이(x 범위)와 선반 수를 주지만
##   **시간**은 안 준다. 넓이가 같아도 수직 이동이 많으면 체감 시간이 완전히 다르다.
##
## ▣ 무엇을 재나 — "직진 봇" 의 관통 시간
##   플레이어를 오른쪽으로 계속 밀고, 벽에 막히면 점프한다. 그것뿐이다.
##   즉 **탐색·퍼즐·실수·되돌아가기가 0 인 하한값**이다.
##   실제 플레이 타임은 여기에 탐색과 퍼즐이 얹혀 보통 2~4 배가 된다.
##   → 스테이지끼리 **같은 잣대로 비교**하는 것이 목적이지, 절대 시간이 목적이 아니다.
##
## ▣ 입력 흉내의 함정 (측정_플레이어_능력 · test_집_체인 과 같은 규칙)
##   `Input.action_press()` 는 약 2 프레임 뒤에야 `is_action_just_pressed` 로 보인다.
##   상승 중에 떼면 `JUMP_CUT_MULTIPLIER(0.4)` 가 점프를 잘라 167px → 40px 이 된다.
##   → **공중에 뜬 뒤 정점을 지난 뒤에만** 뗀다.
##
## ▣ ★★이 도구로 **통행 가능 여부를 판정하지 말 것** — 그건 `레벨검사.gd` 의 일이다
##   봇은 "오른쪽으로 밀고 막히면 뛴다" 가 전부다. 그래서 아래 두 경우에 **레벨이 멀쩡한데도**
##   못 간다:
##     ① 점프를 놓쳤을 때 **되돌아가서 다시 시도해야** 하는 구조
##        (예: 스테이지_1 의 되돌이 디딤단. 봇은 그 위에서 오른쪽 벽만 밀며 60 초를 보낸다.
##         디딤단을 빼고 재보면 **같은 지형이 12.2 초에 관통**된다 = 지형은 정상이다)
##     ② 색을 골라 칠해야 열리는 퍼즐 (총을 못 쏜다 — `--칠하기` 로 유령만 열어 줄 수 있다)
##   → **통행성 판정은 `레벨검사.gd`**(레이캐스트 + 실측 점프 포물선)가 한다.
##     이 도구는 **규모(폭·높이)와 "대략 이 정도 걸린다" 를 스테이지끼리 비교**하는 용도다.
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 오직 재서 보고만 한다.
## ============================================================================

const 기본대상 := [
	"res://scenes/집/집_2층방.tscn",
	"res://scenes/집/집_복도계단.tscn",
	"res://scenes/집/집_거실.tscn",
	"res://scenes/집/집_부엌.tscn",
]

const 최대프레임 := 3600          ## 60 초. 이걸 넘으면 봇이 못 가는 것이다.
const 재시도_한계 := 45          ## 0.75 초 동안 x 가 안 늘면 "막혔다" 로 본다
const 물러나기_프레임 := 34      ## 뒤로 물러나는 시간 (약 220px)
const 최대재시도 := 14           ## 이만큼 재시도해도 못 가면 진짜 막힌 것이다
const 물리틱 := 60.0

var _미리칠하기 := false


func _initialize() -> void:
	Engine.max_fps = 0
	_실행()


func _실행() -> void:
	var 인자: Array = Array(OS.get_cmdline_user_args())
	# ★--칠하기 : 유령 발판을 미리 다 칠해 놓고 잰다.
	#   직진 봇은 총을 못 쏘므로, 유령 게이트가 있는 스테이지는 그 앞에서 영원히 막힌다
	#   (실제로 스테이지_1 · 집_2층방 둘 다 60 초 시간초과가 났다).
	#   게이트를 열어 두면 "지형만 놓고 봤을 때의 관통 시간" 을 잴 수 있다.
	_미리칠하기 = 인자.has("--칠하기")
	인자 = 인자.filter(func(a): return not String(a).begins_with("--"))
	var 대상: Array = 기본대상.duplicate() if 인자.is_empty() else 인자

	print("\n════════ 스테이지 규모 · 직진 관통 시간 %s ════════" \
		% ("(유령 발판 미리 칠함)" if _미리칠하기 else ""))
	print("※ 직진 봇 = 오른쪽으로만 밀고 막히면 점프. 탐색·퍼즐 0 인 **하한값**이다.\n")
	print("%-18s %8s %7s %8s %6s %8s %8s  %s" \
		% ["스테이지", "폭", "높이", "관통(초)", "점프", "최대x", "이동px", "결과"])
	print("─".repeat(96))

	for 경로 in 대상:
		await _한판(String(경로))

	print("")
	quit(0)


func _한판(경로: String) -> void:
	var ps := load(경로) as PackedScene
	if ps == null:
		print("%-16s  로드 실패" % 경로.get_file())
		return
	var 씬: Node2D = ps.instantiate()
	root.add_child(씬)
	await physics_frame
	await physics_frame

	var p := 씬.get_node_or_null("Player") as CharacterBody2D
	if p == null:
		print("%-16s  Player 없음" % 경로.get_file())
		씬.queue_free()
		await process_frame
		return

	# ★유령 발판을 미리 칠해 게이트를 열어 둔다 (--칠하기 일 때만)
	if _미리칠하기:
		_유령_칠하기(씬)
		await physics_frame

	# ── 공간 규모 ──────────────────────────────────────────────────────────
	# 지형 노드들의 콜리전을 전부 합쳐 실제 **게임플레이 공간**을 잰다.
	# 카메라 리밋은 연출용으로 넉넉히 잡혀 있어 규모 지표로 못 쓴다.
	var 범위 := _지형_범위(씬)

	# ── 출구 위치 ──────────────────────────────────────────────────────────
	var 출구x := 범위.end.x
	for n in _모든노드(씬):
		if String(n.name).begins_with("출구") and n is Node2D:
			출구x = (n as Node2D).global_position.x

	# ── 직진 봇 ────────────────────────────────────────────────────────────
	var 시작 := p.global_position
	var 최우 := 시작.x
	var 이전x := 시작.x
	var 끼임 := 0
	var 재시도 := 0
	var 물러나기 := 0
	var 점프수 := 0
	var 누름 := false
	var 프레임 := 0
	var 결과 := "시간초과"
	var 이동거리 := 0.0
	var 이전위치 := 시작

	Input.action_press("move_right")
	for i in 최대프레임:
		await physics_frame
		프레임 = i + 1

		# 점프 — ① 벽에 막혔을 때  ② **앞에 바닥이 없을 때**(틈을 건너려고)
		#
		# ★[2026-08-29] 처음에는 ①만 있었다. 그러면 봇이 **틈을 절대 못 건넌다** —
		#   낭떠러지에서 그냥 걸어 나가 떨어진다. 그래서 플랫폼 구간이 있는 스테이지는
		#   전부 그 앞에서 멈췄다(스테이지_1 x2754 · 집_복도계단 x2174).
		#   앞을 한 번 짚어 보고 바닥이 없으면 뛰게 하니 비로소 관통이 측정된다.
		if not 누름 and p.is_on_floor() and (p.is_on_wall() or not _앞에_바닥(p)):
			Input.action_press("jump")
			누름 = true
			점프수 += 1
		elif 누름 and not p.is_on_floor() and p.velocity.y >= 0.0:
			Input.action_release("jump")
			누름 = false

		var q := p.global_position
		이동거리 += 이전위치.distance_to(q)
		이전위치 = q
		최우 = maxf(최우, q.x)

		# 사망 리스폰 감지 — 시작점 근처로 순간이동한다
		if q.distance_to(시작) < 40.0 and i > 90:
			결과 = "사망/리스폰"
			break
		if q.x >= 출구x - 60.0:
			결과 = "출구 도달"
			break

		# ── 막혔을 때 물러났다 다시 붙기 ─────────────────────────────────────
		# ★[2026-08-29] 오른쪽으로만 미는 봇은 **점프를 한 번 놓치면 영영 못 간다.**
		#   실제 레벨에는 "놓쳤을 때 걸리는 완충 발판"(스테이지_1 의 되돌이 디딤단)이
		#   일부러 들어가는데, 봇은 거기 올라앉은 채 오른쪽 벽만 밀며 60 초를 보냈다.
		#   (디딤단을 빼고 재보니 같은 지형이 12.2 초에 관통됐다 — 지형이 아니라 봇 문제)
		#   → 사람이 하듯 **잠깐 물러났다 다시 달려든다.** 이게 있어야
		#     "완충 발판이 있는 레벨" 의 관통 시간을 잴 수 있다.
		if 물러나기 > 0:
			물러나기 -= 1
			if 물러나기 == 0:
				Input.action_release("move_left")
				Input.action_press("move_right")
				끼임 = 0
		elif absf(q.x - 이전x) < 1.0:
			끼임 += 1
			if 끼임 > 재시도_한계:
				재시도 += 1
				if 재시도 > 최대재시도:
					결과 = "막힘 x=%.0f (재시도 %d)" % [q.x, 재시도]
					break
				Input.action_release("move_right")
				Input.action_press("move_left")
				물러나기 = 물러나기_프레임
		else:
			끼임 = 0
			이전x = q.x
	_입력_해제()

	print("%-18s %8.0f %7.0f %8.2f %6d %8.0f %8.0f  %s" % [
		경로.get_file().replace(".tscn", ""),
		범위.size.x, 범위.size.y,
		float(프레임) / 물리틱, 점프수, 최우, 이동거리, 결과,
	])

	씬.queue_free()
	await process_frame


## 진행 방향으로 한 발(앞 40px) 앞을 짚어, 그 아래 60px 안에 밟을 것이 있는지 본다.
##
## 40 은 몸 폭(44)의 절반 + 여유다. ★처음에 70 으로 뒀더니 낭떠러지 70px 앞에서 뛰어
## 도달 거리를 그만큼 낭비했다 — 사람은 가장자리를 밟고 뛴다. 실제 통과 가능한 점프를
## 봇이 못 넘어 "시간초과" 가 났다. 더 멀리 짚으면 아직 멀었는데도 뛰고,
## 더 가까이 짚으면 이미 발이 나간 뒤에 뛰어서 늦는다.
## 60 은 한 계단(110)보다 낮게 잡은 값 — 계단을 내려갈 때는 뛰지 않아야 하기 때문이다.
func _앞에_바닥(p: CharacterBody2D) -> bool:
	var 공간 := p.get_world_2d().direct_space_state
	var 발 := p.global_position + Vector2(40.0, 0.0)
	var q := PhysicsRayQueryParameters2D.create(발, 발 + Vector2(0.0, 60.0))
	q.exclude = [p.get_rid()]
	q.collision_mask = p.collision_mask
	return not 공간.intersect_ray(q).is_empty()


## 유령 발판(`무색일때_통과 = true`)을 전부 검정으로 칠해 단단하게 만든다.
##
## ▣ 왜 이렇게 하나
##   직진 봇은 총을 못 쏜다. 그래서 유령 게이트가 있는 스테이지는 봇이 그 앞에서
##   영원히 튕기고 "시간초과" 만 나온다 — **지형 자체의 길이를 잴 수가 없다.**
##   `명중()` 은 페인트 시스템의 정식 입구이므로, 그걸 `필요횟수()` 만큼 부르면
##   실제 게임에서 총을 쏜 것과 같은 상태가 된다(부분 색칠 → 전체 색칠 승격 포함).
func _유령_칠하기(씬: Node) -> void:
	for n in _모든노드(씬):
		if not n.is_in_group("스마트지형"):
			continue
		if not bool(n.get("무색일때_통과")):
			continue
		var 중심: Vector2 = (n as Node2D).global_position
		# ColorDefs.BLACK = 0. 필요횟수 만큼 맞혀야 전체 색칠로 승격된다.
		for i in int(n.call("필요횟수")):
			n.call("명중", 0, 중심)


## 씬 안의 모든 CollisionPolygon2D / CollisionShape2D 를 합친 실제 지형 범위.
func _지형_범위(씬: Node) -> Rect2:
	var 첫 := true
	var r := Rect2()
	for n in _모든노드(씬):
		if n is CollisionPolygon2D:
			var cp := n as CollisionPolygon2D
			for v in cp.polygon:
				var w := cp.global_transform * v
				if 첫:
					r = Rect2(w, Vector2.ZERO)
					첫 = false
				else:
					r = r.expand(w)
	return r


func _모든노드(뿌리: Node) -> Array[Node]:
	var 결과: Array[Node] = []
	var 대기: Array[Node] = [뿌리]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		결과.append(n)
		for c in n.get_children():
			대기.append(c)
	return 결과


func _입력_해제() -> void:
	for a in ["move_left", "move_right", "jump"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
