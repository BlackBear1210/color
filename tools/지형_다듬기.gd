extends SceneTree
## ============================================================================
## [2026-08-17 도형 · 신규] 지형 다듬기 — **공중에 뜬 지형에 뿌리를 내린다**
## ----------------------------------------------------------------------------
## 실행 (기본은 조사만 — 씬을 고치지 않는다):
##   Godot --headless --path . -s res://tools/지형_다듬기.gd
##   Godot --headless --path . -s res://tools/지형_다듬기.gd -- --적용
##   Godot --headless --path . -s res://tools/지형_다듬기.gd -- --적용 --콜리전
##   Godot --headless --path . -s res://tools/지형_다듬기.gd -- --씬 res://scenes/스마트월드/스마트월드_3.tscn
##
## ============================================================================
## ▣ 왜 만들었나 (도형님 지시)
##   "너무 지형 오브젝트를 계속 공중에 붙이지 말고 게임에 어울리게 만들어줘.
##    또는 찾아서 변환을 해."
##   레벨 디자인 원칙 1 번(시각적 입체감)과 같은 이야기다:
##     "얇고 단조로운 1차원적 플랫폼 지양. 바닥까지 길게 박혀 있는 묵직하고
##      큼직한 덩어리감 있는 지형."
##
##   지금 스마트월드의 지형은 **타일맵에서 변환**된 것이라(스마트월드_1·2),
##   원본에서 공중에 떠 있던 한 줄짜리 발판이 그대로 떠 있다.
##   림보·리틀 나이트메어·레인월드가 묵직해 보이는 이유는 지형이 전부
##   "덩어리에서 파낸 것" 이라서다. 허공의 막대기는 **레벨 에디터처럼** 보인다.
##
## ▣ 이 도구가 하는 일 — 레벨 디자인은 1px 도 안 바꾼다
##   1. 조사 : 씬의 모든 지형을 훑어 **아래에도 옆에도 아무것도 없는 것**을 찾는다
##   2. 변환 : 그 발판 아래에 **받침(기둥/버팀벽)** 을 만들어 지면에 박아 넣는다
##            → 발판의 윗면(=플레이가 닿는 면)은 그대로다. 점프 거리·단차 전부 불변.
##
## ▣ ★★받침에 콜리전을 안 주는 것이 기본이다 (중요한 설계 판단)
##   기둥을 단단하게 만들면 **레벨 통행성이 바뀐다.** 발판 아래를 지나가는 길이
##   막히거나, 벽점프 같은 의도치 않은 지름길이 생긴다. 지금 스마트월드_1·2 는
##   이미 도달률이 낮은 상태라(86중 11 · 44중 19 · docs/다음작업_프롬프트.md 작업 A)
##   여기서 물리를 건드리면 원인이 섞여 아무것도 판단할 수 없게 된다.
##   → 기본은 **그림만** 있는 배경 덩어리(z_index −2, 콜리전 없음)다.
##     발판은 여전히 "덩어리에서 자란 선반" 으로 보이지만 물리는 완전히 그대로다.
##   → 단단하게 원하면 `--콜리전` 을 붙인다. 그 뒤에는 반드시 `레벨검사.gd` 로
##     도달률이 떨어지지 않았는지 확인할 것.
##
## ▣ 멱등 (2026-08-08 지뢰밭 §5-2 규칙)
##   받침 노드 이름은 전부 `받침_` 으로 시작한다. 도구는 **먼저 그 노드들을 다 지우고**
##   내용물에서 다시 계산한다. 몇 번 돌려도 결과가 같다.
##
## ▣ owner 규칙 (2026-08-07 세그폴트)
##   읽어온 씬의 기존 노드는 owner 를 절대 건드리지 않는다.
##   **우리가 새로 만든 받침 노드에만** owner 를 준다.
## ============================================================================

const 공통 := preload("res://tools/지형공통.gd")

# ── 판정 기준 ───────────────────────────────────────────────────────────────
## 발판 아래 이 거리 안에 지형이 있으면 "떠 있지 않다"(= 이미 붙어 있다) 로 본다.
## ★[2026-08-17 스크린샷 보고 150 → 64 로 줄임]
##   150px 로 뒀더니 **위층 발판만 뿌리 없이 남았다.** 아래층 발판이 170px 아래에
##   있어서 "붙어 있다" 로 판정됐지만, 화면에서는 둘 사이가 훤히 비어 있어
##   덩어리가 된 아래층과 막대로 남은 위층이 나란히 보였다 — 더 이상해 보인다.
##   64px(= 최소 발판 폭 · 타일 4 칸)은 "거의 닿았다" 고 부를 수 있는 거리다.
##   이보다 멀면 짧은 기둥으로 이어 붙여 **한 덩어리**로 만든다.
const 아래_허용: float = 64.0
## 발판 좌우 이 거리 안에 지형이 있으면 "벽에 붙은 선반" 이다 → 받침이 필요 없다.
## (레인월드식 선반은 벽에서 자라난 것이라 이미 뿌리가 있다)
const 옆_허용: float = 56.0
## 이 크기보다 큰 지형은 그 자체가 덩어리다 — 받침을 붙일 대상이 아니다.
const 덩어리_최소폭: float = 900.0
const 덩어리_최소높이: float = 420.0
## 이 폭보다 좁은 것은 장식·파편이다. 받침을 붙이면 오히려 지저분해진다.
const 무시_최소폭: float = 40.0
## 옆으로 이 거리 안에 **큰 덩어리**가 있으면 기둥이 아니라 버팀대로 이어 붙인다.
## 굴뚝/갱도 선반이 벽에서 40~60px 떨어져 있는 경우가 이것이다
## (빌더가 선반을 벽 안쪽 40px 지점에 놓는데, 콜리전 부풀림 때문에 실측은 60px 이 된다).
const 브래킷_한계: float = 260.0
## 버팀대를 걸어도 되는 "큰 덩어리" 의 최소 높이(px).
## ★이 조건이 없으면 **선반과 선반을 서로 이어버린다.** 갱도의 좌우 엇갈린 선반은
##   260px 간격이라 서로 사정거리 안에 있는데, 그걸 이으면 있지도 않은 다리가 생긴다.
const 브래킷_상대_최소높이: float = 300.0
## 받침이 내려갈 최대 깊이. 이보다 깊으면 "바닥 없는 허공" 이라 기둥이 아니라
## 천장에서 내려오는 버팀대(현수)로 처리한다.
const 최대_기둥길이: float = 1600.0

var _시나리오: Array[String] = []
var _적용 := false
var _콜리전 := false
var _총_지형 := 0
var _총_뜬것 := 0
var _총_받침 := 0
var _재질_덩어리 := ""


func _init() -> void:
	Engine.max_fps = 60
	_인자_읽기()
	call_deferred("_실행")


func _인자_읽기() -> void:
	var 씬들: Array[String] = []
	var 인자 := OS.get_cmdline_user_args()
	var i := 0
	while i < 인자.size():
		var a: String = 인자[i]
		match a:
			"--적용": _적용 = true
			"--콜리전": _콜리전 = true
			"--씬":
				if i + 1 < 인자.size():
					i += 1
					씬들.append(인자[i])
		i += 1
	if 씬들.is_empty():
		# 기본 대상 = 챕터표에 등재된 실제 플레이 씬 전부
		for s in 챕터.스테이지표:
			씬들.append(챕터.씬경로(int(s["번호"])))
	_시나리오 = 씬들


func _실행() -> void:
	print("\n=== 지형 다듬기 (%s%s) ==="
		% ["적용" if _적용 else "조사만", " · 콜리전" if _콜리전 else ""])
	_재질_덩어리 = 공통.재질_준비("덩어리")
	if _재질_덩어리.is_empty():
		push_error("재질 준비 실패")
		quit(1)
		return

	for 경로 in _시나리오:
		await _씬_하나(경로)

	print("---")
	print("[지형다듬기] 지형 %d개 · 공중에 뜬 것 %d개 · 받침 %d개 %s"
		% [_총_지형, _총_뜬것, _총_받침, "생성·저장" if _적용 else "(조사만)"])
	quit(0)


# ============================================================================
func _씬_하나(경로: String) -> void:
	if not ResourceLoader.exists(경로):
		push_warning("씬이 없다 → %s" % 경로)
		return
	print("\n── %s" % 경로.get_file())
	var 루트 := (load(경로) as PackedScene).instantiate() as Node2D
	root.add_child(루트)
	# 콜리전이 물리 공간에 등록될 때까지 기다린다 (레이캐스트로 재기 때문에 필수)
	await physics_frame
	await physics_frame

	var 지형층 := 루트.get_node_or_null("지형")
	if 지형층 == null:
		print("   지형 레이어가 없다 — 건너뜀")
		루트.queue_free()
		await process_frame
		return

	# ── 멱등 ── 지난번에 만든 받침을 먼저 전부 지운다
	var 지운수 := 0
	for c in 지형층.get_children():
		if String(c.name).begins_with("받침_"):
			지형층.remove_child(c)
			c.queue_free()
			지운수 += 1
	if 지운수 > 0:
		print("   이전 받침 %d개 제거(재계산)" % 지운수)
		await physics_frame

	# ── 조사 ──
	var 후보 := _지형_모으기(지형층)
	_총_지형 += 후보.size()
	var 뜬것: Array[Dictionary] = []
	for 정보 in 후보:
		if _떠있나(루트, 정보):
			뜬것.append(정보)
	_총_뜬것 += 뜬것.size()

	print("   지형 %d개 중 공중에 뜬 것 %d개" % [후보.size(), 뜬것.size()])
	# 상위 12 개만 좌표를 찍는다 (전부 찍으면 로그가 수천 줄이 된다)
	var 보임 := 0
	for 정보 in 뜬것:
		보임 += 1
		if 보임 > 12:
			print("     … 외 %d개" % (뜬것.size() - 12))
			break
		var b: Rect2 = 정보["범위"]
		print("     · %-18s x %7.0f~%-7.0f y %7.0f  (%.0f×%.0f)"
			% [정보["노드"].name, b.position.x, b.end.x, b.position.y, b.size.x, b.size.y])

	if not _적용 or 뜬것.is_empty():
		루트.queue_free()
		await process_frame
		return

	# ── 변환 ──
	var 만든수 := 0
	for 정보 in 뜬것:
		if _받침_만들기(루트, 지형층, 정보):
			만든수 += 1
	_총_받침 += 만든수
	print("   받침 %d개 생성" % 만든수)

	# ★새로 만든 받침에만 owner 를 준다 (읽어온 씬의 나머지는 손대지 않는다)
	for c in 지형층.get_children():
		if String(c.name).begins_with("받침_"):
			c.owner = 루트
			공통.주인_지정(c, 루트)

	_저장(루트, 경로)
	루트.queue_free()
	await process_frame


# ============================================================================
# 조사
# ============================================================================
## 지형 레이어에서 "받침을 붙일 수 있는 지형" 목록을 만든다.
## 반환 항목: { 노드, 범위(월드 Rect2), 리드(자기 콜리전 RID 배열) }
func _지형_모으기(지형층: Node) -> Array[Dictionary]:
	var 결과: Array[Dictionary] = []
	for c in 지형층.get_children():
		var n2 := c as Node2D
		if n2 == null:
			continue
		var 범위 := _범위(n2)
		if 범위.size == Vector2.ZERO:
			continue
		# 통짜 바닥·천장·벽은 그 자체가 덩어리다 — 대상이 아니다
		if 범위.size.x >= 덩어리_최소폭 or 범위.size.y >= 덩어리_최소높이:
			continue
		if 범위.size.x < 무시_최소폭:
			continue
		결과.append({"노드": n2, "범위": 범위, "리드": _리드들(n2)})
	return 결과


## 이 노드(자손 포함)의 콜리전을 감싸는 월드 사각형.
func _범위(노드: Node) -> Rect2:
	var 결과 := Rect2()
	var 처음 := true
	var 대기: Array[Node] = [노드]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			대기.append(c)
		if not (n is CollisionPolygon2D):
			continue
		var poly := (n as CollisionPolygon2D).polygon
		if poly.size() < 3:
			continue
		var mn := poly[0]
		var mx := poly[0]
		for p in poly:
			mn = mn.min(p)
			mx = mx.max(p)
		var g := (n as Node2D).global_transform
		var r := Rect2(g * mn, Vector2.ZERO).expand(g * mx)
		결과 = r if 처음 else 결과.merge(r)
		처음 = false
	return 결과


## 자기 자신의 콜리전 RID 들 — 레이캐스트에서 제외해야 자기를 맞고 끝나지 않는다.
func _리드들(노드: Node) -> Array[RID]:
	var 결과: Array[RID] = []
	var 대기: Array[Node] = [노드]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			대기.append(c)
		if n is PhysicsBody2D:
			결과.append((n as PhysicsBody2D).get_rid())
	return 결과


## 아래에도 옆에도 아무것도 없는가 = 허공의 막대기인가.
func _떠있나(루트: Node2D, 정보: Dictionary) -> bool:
	var b: Rect2 = 정보["범위"]
	var 제외: Array[RID] = 정보["리드"]
	var 공간 := 루트.get_viewport().world_2d.direct_space_state

	# 1) 아래 — 폭의 25/50/75% 세 지점에서 내려본다
	for u: float in [0.25, 0.5, 0.75]:
		var x: float = b.position.x + b.size.x * u
		if _맞나(공간, Vector2(x, b.end.y - 2.0), Vector2(x, b.end.y + 아래_허용), 제외):
			return false

	# 2) 옆 — 높이의 25/50/75% 세 지점에서 좌우로 본다
	#    (벽에서 자라난 선반은 이미 뿌리가 있다)
	for u: float in [0.25, 0.5, 0.75]:
		var y: float = b.position.y + b.size.y * u
		if _맞나(공간, Vector2(b.position.x + 2.0, y),
				Vector2(b.position.x - 옆_허용, y), 제외):
			return false
		if _맞나(공간, Vector2(b.end.x - 2.0, y),
				Vector2(b.end.x + 옆_허용, y), 제외):
			return false

	# 3) 위 — 천장에서 내려온 돌출부(고드름·매달린 덩어리)도 뿌리가 있는 것이다
	for u: float in [0.35, 0.65]:
		var x2: float = b.position.x + b.size.x * u
		if _맞나(공간, Vector2(x2, b.position.y + 2.0),
				Vector2(x2, b.position.y - 옆_허용), 제외):
			return false
	return true


func _맞나(공간: PhysicsDirectSpaceState2D, 부터: Vector2, 까지: Vector2,
		제외: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters2D.create(부터, 까지, 1)
	q.collide_with_areas = false
	q.exclude = 제외
	return not 공간.intersect_ray(q).is_empty()


# ============================================================================
# 변환 — 받침 만들기
# ============================================================================
## 떠 있는 발판 하나에 받침을 붙인다. 만들었으면 true.
##
## ▣ ★두 가지 상황을 다르게 다룬다 (스크린샷을 보고 나눈 것)
##
##   ① 아래에 지면이 있다 → **기둥(pillar)** 을 세워 지면에 박는다.
##      폭은 발판의 55% 정도. 아래로 갈수록 넓어져 무게가 흐르는 방향이 보인다.
##
##   ② 아래가 끝없는 허공이다 → **덩어리 꼬리(mass tail)** 를 단다.
##      스마트월드_1 의 실제 화면이 이 경우다. 회색 허공에 검은 **직사각형 슬래브**
##      수십 개가 떠 있어서 게임이 아니라 레벨 에디터처럼 보였다.
##      허공이라 기둥을 내릴 곳이 없으므로, 발판 **자체를 덩어리로 만든다**:
##      발판 폭 그대로 시작해 아래로 좁아지는 암반 꼬리를 붙이면
##      "떠 있는 막대" 가 "떠 있는 암반 덩어리" 로 바뀐다(리틀 나이트메어의 부유 구조물).
##      → 윗면(밟는 면)은 1px 도 안 건드리므로 플레이는 완전히 그대로다.
func _받침_만들기(루트: Node2D, 지형층: Node, 정보: Dictionary) -> bool:
	var 대상 := 정보["노드"] as Node2D
	var b: Rect2 = 정보["범위"]
	var 제외: Array[RID] = 정보["리드"]
	var 공간 := 루트.get_viewport().world_2d.direct_space_state

	# 지면 찾기 — 발판 가운데에서 아래로 길게 쏜다
	var 중심x := b.get_center().x
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(중심x, b.end.y + 2.0),
		Vector2(중심x, b.end.y + 최대_기둥길이), 1)
	q.collide_with_areas = false
	q.exclude = 제외
	var 히트 := 공간.intersect_ray(q)

	# ★③ 먼저 "옆에 벽이 있나" 를 본다. 벽이 가까우면 기둥보다 **버팀대**가 맞다.
	#    (굴뚝·갱도 선반은 벽에서 60px 떨어져 있다 — 밑으로 기둥을 내리면
	#     벽에서 자란 선반이 아니라 허공의 종유석처럼 보인다)
	var 브래킷 := _가까운_벽(루트, b, 제외)
	if not 브래킷.is_empty():
		var 이름B := "받침_%s" % 대상.name
		var 점들B := _브래킷_점들(float(브래킷["거리"]), b.size.y, float(브래킷["방향"]))
		var 시작x: float = (b.end.x - 4.0) if float(브래킷["방향"]) > 0.0 else (b.position.x + 4.0)
		var 재질B := _재질_경로(대상)
		var 받침B: 스마트지형
		if _콜리전:
			받침B = 공통.지형_노드(이름B, Vector2(시작x, b.end.y - 6.0), 점들B,
				재질B, false, false, 0, 20.0)
		else:
			받침B = _그림만_지형(이름B, Vector2(시작x, b.end.y - 6.0), 점들B, 재질B)
		지형층.add_child(받침B)
		return true

	var 점들: PackedVector2Array
	if not 히트.is_empty():
		# ① 기둥 — 지면 안으로 40px 박아 넣는다. 딱 맞추면 이가 안 맞아 틈이 보인다.
		var 길이: float = (히트["position"].y - b.end.y) + 40.0
		if 길이 < 60.0:
			return false                # 이미 거의 붙어 있다 — 만들 의미가 없다
		var 윗폭: float = clampf(b.size.x * 0.55, 96.0, 340.0)
		점들 = _기둥_점들(윗폭, 길이)
	else:
		# ② 덩어리 꼬리 — 길이는 폭에 비례. 폭보다 길면 고드름처럼 보여 어색하다.
		#   420px 상한: 화면 높이(1080)의 40% 를 넘으면 발판보다 꼬리가 주인공이 된다.
		var 꼬리 := clampf(b.size.x * 0.85, 130.0, 420.0)
		점들 = _꼬리_점들(b.size.x, 꼬리, int(중심x))

	# 재질은 **대상 발판과 같은 것**을 쓴다. 같은 암반에서 자란 것으로 보여야 한다.
	var 재질경로 := _재질_경로(대상)

	var 이름 := "받침_%s" % 대상.name
	var 받침: 스마트지형
	if _콜리전:
		# 단단한 기둥 — 통행성이 바뀔 수 있다(§머리말 경고). 반드시 레벨검사로 확인할 것.
		받침 = 공통.지형_노드(이름, Vector2(중심x, b.end.y - 6.0), 점들,
			재질경로, false, false, 0, 20.0)
	else:
		# ★기본 — 그림만 있는 배경 덩어리. 물리에 손을 대지 않는다.
		받침 = _그림만_지형(이름, Vector2(중심x, b.end.y - 6.0), 점들, 재질경로)
	지형층.add_child(받침)
	return true


## ③ 옆에 "이어 붙일 만한 큰 덩어리(벽)" 가 있나.
## 반환: 비었으면 없음 / { "방향": +1(오른쪽) 또는 −1(왼쪽), "거리": px }
##
## ⚠ 작은 선반을 벽으로 착각하면 **선반끼리 이어진 가짜 다리**가 생긴다.
##   그래서 맞은 상대의 세로 크기를 재서 `브래킷_상대_최소높이` 이상만 벽으로 인정한다.
func _가까운_벽(루트: Node2D, b: Rect2, 제외: Array[RID]) -> Dictionary:
	var 공간 := 루트.get_viewport().world_2d.direct_space_state
	# 발판 세로 중앙에서 좌우로 쏜다 (윗면/아랫면 근처는 발판 자신의 모서리에 걸린다)
	var y := b.get_center().y
	for 방향: float in [1.0, -1.0]:
		var 시작 := Vector2(b.end.x - 2.0 if 방향 > 0.0 else b.position.x + 2.0, y)
		var 끝 := 시작 + Vector2(방향 * 브래킷_한계, 0.0)
		var q := PhysicsRayQueryParameters2D.create(시작, 끝, 1)
		q.collide_with_areas = false
		q.exclude = 제외
		var r := 공간.intersect_ray(q)
		if r.is_empty():
			continue
		# 맞은 상대가 벽만큼 큰가
		var 상대 := _지형_뿌리(r.get("collider"), 루트)
		if 상대 == null:
			continue
		var 상대범위 := _범위(상대)
		if 상대범위.size.y < 브래킷_상대_최소높이:
			continue
		var 거리: float = absf(r["position"].x - 시작.x)
		# 이미 닿아 있으면(=`_떠있나` 의 옆_허용 안쪽) 여기 올 일이 없지만, 안전하게 건너뛴다
		if 거리 < 8.0:
			continue
		return {"방향": 방향, "거리": 거리}
	return {}


## 콜리전 바디에서 지형 노드(지형 레이어의 직계 자식)까지 거슬러 올라간다.
func _지형_뿌리(맞은것: Object, 루트: Node) -> Node:
	var n := 맞은것 as Node
	var 지형층 := 루트.get_node_or_null("지형")
	while n != null and n != 루트:
		if n.get_parent() == 지형층:
			return n
		n = n.get_parent()
	return null


## ③ 버팀대(코벨) 실루엣 — 발판 안쪽 끝에서 벽까지 밑을 받친다.
## 원점 = 발판의 벽쪽 끝 · 아랫면. 방향 +1 이면 오른쪽 벽으로 뻗는다.
##
## ▣ 왜 벽쪽이 더 두꺼운가
##   무게는 벽으로 흐른다. 벽쪽이 두껍고 발판 끝이 얇아야 "벽에서 자라난 선반" 이 된다.
##   반대로 만들면 벽에 겨우 걸쳐 놓은 판자처럼 보여 불안하다.
func _브래킷_점들(거리: float, 발판높이: float, 방향: float) -> PackedVector2Array:
	var d: float = signf(방향)
	var L := 거리 + 12.0                       # 벽 안으로 12px 파고들어 이가 맞는다
	var h: float = maxf(발판높이 * 1.6, 90.0)   # 벽에 닿는 쪽의 깊이
	var 점들 := PackedVector2Array([
		Vector2(0.0, 0.0),                     # 발판 끝 · 위
		Vector2(d * L, 0.0),                   # 벽 · 위
		Vector2(d * L, h),                     # 벽 · 아래 (여기가 가장 깊다)
		Vector2(d * L * 0.45, h * 0.52),       # 중간에서 한 번 꺾인다 (곡선처럼 보인다)
		Vector2(0.0, h * 0.22),                # 발판 끝 · 아래 (얇다)
	])
	# 왼쪽으로 뻗을 때는 위 순서가 반시계가 된다 → 뒤집어 시계 방향으로 맞춘다
	# (감김 방향이 섞이면 콜리전 볼록 분해가 조용히 실패한다 — 지형공통 §벽_점들)
	if d < 0.0:
		점들.reverse()
	return 점들


## ① 받침 기둥의 실루엣. 원점 = 발판 아랫면 중앙, +y 가 아래.
##
## ▣ 왜 아래로 갈수록 넓히는가
##   위아래 같은 폭이면 "붙여 놓은 막대" 로 보인다. 아래가 넓으면 무게가 흐르는
##   방향이 보여서 **구조물** 로 읽힌다(고딕 건축의 버팀벽과 같은 이유).
##   ⚠ 감김 방향은 지형공통.gd 의 다른 함수들과 같은 **시계 방향**이어야 한다.
##     방향이 섞이면 SS2D 콜리전 볼록 분해가 조용히 실패한다(지형공통 §벽_점들 주석).
func _기둥_점들(윗폭: float, 길이: float) -> PackedVector2Array:
	var w := 윗폭 * 0.5
	var wb := w * 1.34                # 밑동이 더 넓다
	var h := 길이
	return PackedVector2Array([
		# 윗면 (왼 → 오) — 발판 안으로 6px 파고들어 이가 맞는다
		Vector2(-w, 0.0),
		Vector2(w, 0.0),
		# 오른쪽 면 (위 → 아래) — 가운데를 살짝 안으로 넣어 허리가 잡힌 실루엣
		Vector2(w * 0.90, h * 0.28),
		Vector2(w * 0.82, h * 0.58),
		Vector2(wb * 0.95, h * 0.86),
		# 아랫면 (오 → 왼)
		Vector2(wb, h),
		Vector2(-wb, h),
		# 왼쪽 면 (아래 → 위)
		Vector2(-wb * 0.95, h * 0.86),
		Vector2(-w * 0.82, h * 0.58),
		Vector2(-w * 0.90, h * 0.28),
	])


## ② 덩어리 꼬리의 실루엣. 발판 폭 그대로 시작해 아래로 좁아진다.
##
## ▣ 왜 좌우를 **비대칭**으로 흔드나
##   완전한 좌우 대칭 도형은 눈에 즉시 "생성된 것" 으로 읽힌다. 같은 발판이
##   수십 개 있는 스테이지에서 전부 대칭이면 반복이 그대로 드러난다.
##   → 중심 x 좌표를 씨앗으로 써서 **자리마다 다른 모양**을 만든다.
##     씨앗이 좌표라서 도구를 몇 번 돌려도 같은 모양이 나온다(멱등).
##   ⚠ 여기도 감김 방향은 시계 방향이다.
func _꼬리_점들(발판폭: float, 길이: float, 씨앗: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗
	var w := 발판폭 * 0.5 * 0.96       # 발판보다 4% 안쪽에서 시작 (테두리 타일이 보이게)
	var h := 길이
	# 아래 끝 폭은 22~34% — 뾰족하게 만들면 고드름이 되고, 넓으면 상자가 된다
	var 끝배: float = rng.randf_range(0.22, 0.34)
	# 꼬리 끝이 한쪽으로 살짝 밀린다 (중력에 눌린 암반의 결)
	var 밀림 := rng.randf_range(-0.12, 0.12) * 발판폭

	# ★한 변을 4 단으로 나누고 단마다 흔든다.
	#   2 단(직선 두 개)으로 만들었더니 전부 **똑같은 사다리꼴**로 보였다(첫 시도 스크린샷).
	#   4 단 + 단별 흔들림이면 같은 코드로 만든 것들이 서로 다른 암반처럼 보인다.
	var 단수 := 4
	var 오른쪽: Array[Vector2] = []
	var 왼쪽: Array[Vector2] = []
	for i in range(1, 단수 + 1):
		var t := float(i) / float(단수)
		# 폭은 위→아래로 좁아진다. t² 를 섞어 위쪽은 완만하고 아래쪽에서 급히 좁아진다
		#   → 발판 바로 밑이 두꺼워서 "무게를 받치는" 그림이 된다.
		var 기본 := lerpf(w, w * 끝배, t * t * 0.65 + t * 0.35)
		var 흔들 := rng.randf_range(0.86, 1.06)
		var y := h * t
		var dx := 밀림 * t
		오른쪽.append(Vector2(기본 * 흔들 + dx, y))
		왼쪽.append(Vector2(-기본 * rng.randf_range(0.86, 1.06) + dx, y))

	# 감김 방향 = 시계 방향 (윗면 왼→오 · 오른쪽 면 위→아래 · 왼쪽 면 아래→위)
	var 점들 := PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0)])
	for p in 오른쪽:
		점들.append(p)
	왼쪽.reverse()
	for p in 왼쪽:
		점들.append(p)
	return 점들


## 대상 지형이 쓰는 재질 경로. 못 알아내면 덩어리 재질로 떨어진다.
func _재질_경로(대상: Node2D) -> String:
	var m: Variant = 대상.get("shape_material")
	if m is Resource and not (m as Resource).resource_path.is_empty():
		return (m as Resource).resource_path
	return _재질_덩어리


## 콜리전이 없는 "그림만" 지형. 배경 평면에 놓아 발판 뒤에서 받치는 것으로 보인다.
##
## ⚠ `지형공통.지형_노드()` 를 쓰지 않는 이유: 그 함수는 StaticBody2D +
##   CollisionPolygon2D 를 반드시 만든다. 여기서는 **물리를 절대 만들지 않는 것**이
##   목적이라(§머리말) 직접 조립한다.
func _그림만_지형(이름: String, 위치: Vector2, 점들: PackedVector2Array,
		재질경로: String) -> 스마트지형:
	var 지형: 스마트지형 = preload("res://scripts/스마트월드/지형.gd").new()
	지형.name = 이름
	지형.position = 위치
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 픽셀아트라 필수
	# 구조물이다 — 칠할 수 없고(색 규칙에서 제외) 항상 무색이라 안전하다.
	지형.칠하기_허용 = false
	지형.무색일때_통과 = false
	# 발판보다 **뒤에** 그린다. 앞에 그리면 발판 윗면을 가려 밟을 자리가 안 보인다.
	지형.z_index = -2
	# 콜리전 대상 노드가 아예 없으므로 SS2D 의 `bake_collision()` 은 첫 줄에서 되돌아간다.
	# 그래도 모드를 `Editor` 로 못박아 둔다 — 런타임에서는 다시 굽지 않는다는 뜻이라
	# 나중에 누가 이 노드에 콜리전 노드를 달아도 게임 중에 물리가 생기지 않는다.
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.Editor
	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()
	return 지형


# ============================================================================
func _저장(루트: Node2D, 경로: String) -> void:
	var 팩 := PackedScene.new()
	var err := 팩.pack(루트)
	if err != OK:
		push_error("  pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, 경로)
	print("   저장 %s → %s" % [error_string(err), 경로.get_file()])
