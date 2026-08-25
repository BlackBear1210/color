extends SceneTree
## ============================================================================
## [2026-08-19 신규] 지형 진단기 — "발이 뜬다 / 못 지나간다" 를 숫자로 잡는다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/지형_진단.gd -- <씬경로>
##   Godot --headless --path . -s res://tools/지형_진단.gd -- --전부
##
## ▣ 왜 `레벨검사.gd` 로는 안 되나 (둘은 보는 것이 다르다)
##   `레벨검사.gd` 는 **"갈 수 있나"** 를 본다. 그래서 머리 위가 막힌 자리는
##   애초에 발판 목록에서 **빼 버린다**(`_머리공간()`). 다른 길이 있으면 조용히 통과한다.
##   → 도형님이 말한 **"플랫폼이 땅에 충분히 떠 있지 않아서 못 지나간다"** 가
##     검사에 안 잡히는 이유가 바로 이것이다. 빠진 자리는 보고되지 않는다.
##   이 도구는 반대로 **"빠진 자리"만** 본다.
##
## ▣ 무엇을 재나 (전부 실측 — 물리 엔진으로 진짜 쏴 본다)
##   [끼임]   걸어 다니는 바닥 위에 **플레이어 키가 안 들어가는** 구간
##            → 여기가 "지나가지 못하는 부분" 이다. x 범위와 실제 높이를 찍는다.
##   [발뜸]   플레이어를 각 발판에 세우고 물리를 굴린 뒤,
##            **발바닥 y** 와 **그 자리 지형의 그려진 윗면 y** 를 비교한다.
##            콜리전은 SS2D 의 테셀레이션 점을 그대로 쓰므로 원래는 0 이어야 한다.
##   [공중]   아래에 아무 받침도 없는 지형 (뿌리 없는 덩어리)
##   [급경사] 걸을 수 없는 경사(> floor_max_angle)인데 발판처럼 생긴 면
##
## ▣ 보고서를 그대로 고칠 수 있게 쓴다
##   "x 3200~3460 에서 머리 위가 74px (키 97px) — 186px 짜리 발판이 너무 낮다"
##   처럼 **어디를 몇 px 올리면 되는지**까지 적는다. 숫자를 보고 바로 손대라고.
## ============================================================================

const 표본간격 := 24.0          ## x 훑는 간격. 레벨검사(32)보다 촘촘히 — 좁은 틈을 놓치지 않게.
const 최대층 := 12
## 키 + 이만큼은 비어 있어야 "지나갈 수 있다"고 본다.
##
## ▣ 왜 6 인가 (2026-08-19 · 한 번 10 으로 뒀다가 되돌렸다)
##   플레이어 몸통은 정확히 97px 이다. 물리적으로는 98px 만 있어도 지나간다.
##   그런데 지형 윗면은 일부러 ±2.5px 물결지게 만들므로(`평바닥_점들` 거칠기),
##   실효 여유가 3px 쯤 깎인다. 6 이면 최악의 물결에서도 100px 이 남는다.
##   ★10 으로 두면 **레벨 수치가 성립하지 않는다**: 안전 단차 128px 안에서
##     선반을 놓아야 하는데 `단차 − 선반두께 ≥ 107` 이면 선반이 21px 보다 얇아야 한다.
##     기준을 실제보다 빡빡하게 잡으면 고칠 수 없는 경고만 쌓인다.
const 머리_여유 := 6.0

## 이름이 이걸로 시작하는 것이 막고 있으면 **의도된 벽**으로 본다(오류가 아니다).
## 가로막이·천장·굴뚝벽은 "막으라고 만든 것" 이라 끼임으로 세면 진짜 문제가 묻힌다.
const 구조물_접두 := ["천장", "벽", "굴뚝벽", "다락왼벽", "거실왼벽", "받침", "가로막이", "지붕가로막이", "뒷벽"]
## 끼임 구간이 이보다 좁으면 보고하지 않는다. 지형 모서리 한두 점은 노이즈다.
const 최소_끼임폭 := 48.0
## 발뜸을 문제로 볼 기준(px). 물리 엔진의 안전 여백(safe margin)이 보통 0.08px 이라
## 2px 를 넘으면 눈에 보이기 시작한다.
const 발뜸_기준 := 2.0

const 전체스테이지 := [
	"res://scenes/스마트월드/스마트월드_5.tscn",
	"res://scenes/스마트월드/스마트월드_6.tscn",
	"res://scenes/스마트월드/스마트월드_7.tscn",
	"res://scenes/스마트월드/스마트월드_1.tscn",
	"res://scenes/스마트월드/스마트월드_2.tscn",
	"res://scenes/스마트월드/스마트월드_3.tscn",
	"res://scenes/스마트월드/스마트월드_4.tscn",
]

var _경로들: Array[String] = []
var _n := 0
var _루트: Node2D = null
var _키 := 97.0
var _폭 := 44.0
var _총_끼임 := 0
var _총_발뜸 := 0
var _총_공중 := 0


func _init() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--전부":
			for s in 전체스테이지:
				_경로들.append(s)
		elif not a.begins_with("--"):
			_경로들.append(a)
	if _경로들.is_empty():
		print("사용법: -s res://tools/지형_진단.gd -- <씬경로> | --전부")
		quit(2)
		return
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	# 씬 하나당 6 프레임: 1 로드 → 4 부터 검사(SS2D 콜리전이 다 구워지는 데 3 프레임)
	var 주기 := 8
	var 안 := _n % 주기
	var 순번 := (_n - 1) / 주기
	if 순번 >= _경로들.size():
		print("\n════════════════════════════════════════════════")
		print(" 합계 — 끼임 %d · 발뜸 %d · 공중지형 %d" % [_총_끼임, _총_발뜸, _총_공중])
		print("════════════════════════════════════════════════")
		quit(0)
		return

	if 안 == 1:
		if _루트:
			_루트.queue_free()
			_루트 = null
		var 경로: String = _경로들[순번]
		if not ResourceLoader.exists(경로):
			push_error("씬이 없다: %s" % 경로)
			return
		_루트 = (load(경로) as PackedScene).instantiate() as Node2D
		root.add_child(_루트)
		# ★월드의 자동 리스폰을 끈다 — 안 그러면 우리가 세운 좌표가 다음 프레임에 사라진다
		#   (test_사망판정.gd 가 같은 함정에 빠진 적이 있다)
		_루트.set_physics_process(false)
	elif 안 == 5 and _루트:
		_검사(_경로들[순번])


# ============================================================================
func _검사(경로: String) -> void:
	print("\n════════════════════════════════════════════════")
	print(" 지형 진단 — %s" % 경로.get_file())
	print("════════════════════════════════════════════════")
	_플레이어_재기()
	var 범위 := _범위()
	print("  훑는 범위 x %.0f~%.0f · y %.0f~%.0f" % [범위.position.x, 범위.end.x, 범위.position.y, 범위.end.y])

	var 표면 := _표면_훑기(범위)
	print("  표면점 %d 개" % 표면.size())

	_끼임_보고(표면)
	_발뜸_보고(표면)
	_공중지형_보고()


func _플레이어_재기() -> void:
	var p := _루트.get_node_or_null("Player") as Node2D
	if p == null:
		return
	# ★[2026-08-25] `플레이어몸.재기()` 로 통일. 모양·개수에 상관없이 재고,
	#   못 재면 조용히 넘어가지 않고 알린다(예전엔 기본값으로 계속 진단해 결과가 거짓이 됐다).
	var 잰것 := 플레이어몸.재기(p)
	if not 잰것["찾음"]:
		print("  ⚠ 플레이어 콜리전을 못 찾음 → 진단 수치를 믿지 말 것")
		return
	_폭 = (잰것["크기"] as Vector2).x
	_키 = (잰것["크기"] as Vector2).y
	print("  플레이어 — 키 %.0fpx · 폭 %.0fpx" % [_키, _폭])


func _범위() -> Rect2:
	var r: Variant = _루트.get("카메라_리밋")
	if r is Rect2 and (r as Rect2).size.length() > 1.0:
		return r as Rect2
	return Rect2(-2000, -3000, 30000, 6000)


## 모든 층의 표면을 찾는다. `레벨검사.gd` 와 같은 방식이되
## **머리 공간이 없는 자리도 버리지 않고** 같이 들고 온다 — 그게 우리가 찾는 것이다.
## 반환: [{x, y, 주인, 머리:float}]  머리 = 그 자리에서 위로 비어 있는 높이(px)
func _표면_훑기(범위: Rect2) -> Array:
	var 공간 := _루트.get_world_2d().direct_space_state
	var 결과: Array = []
	var x := 범위.position.x
	while x <= 범위.end.x:
		var y := 범위.position.y
		var 층 := 0
		while 층 < 최대층 and y < 범위.end.y:
			var q := PhysicsRayQueryParameters2D.create(
				Vector2(x, y), Vector2(x, 범위.end.y), 1 | 8)
			var r := 공간.intersect_ray(q)
			if r.is_empty():
				break
			var 맞은y: float = r["position"].y
			var 법선: Vector2 = r["normal"]
			var 주인 := _주인이름(r["collider"])
			# 윗면만 본다(법선이 위를 향함). 아랫면·옆면은 발판이 아니다.
			if 주인 != "Player" and 법선.y < -0.55:
				var 머리 := _머리높이(공간, x, 맞은y)
				# ★판정은 **플레이어의 진짜 몸통 사각형**으로 한다(아래 `_몸통_들어가나`).
				#   점 몇 개로 재는 `머리` 는 "몇 px 모자라나" 를 알려 주는 참고값일 뿐이다.
				#   실제로 막히는지는 몸통을 세워 봐야 안다 — 폭 44px 이 걸리는 경우도 있다.
				var 통과 := _몸통_들어가나(공간, x, 맞은y)
				결과.append({
					"x": x, "y": 맞은y, "주인": 주인, "머리": 머리, "통과": 통과,
					"막는것": _막는것(공간, x, 맞은y, 머리) if not 통과 else "",
					"경사": rad_to_deg(acos(clampf(-법선.y, -1.0, 1.0))),
				})
			# 맞은 물체 아래로 완전히 빠져나간 뒤 다음 층을 찾는다
			y = 맞은y + 4.0
			var 안전 := 0
			while 안전 < 900 and y < 범위.end.y and _속인가(공간, x, y):
				y += 8.0
				안전 += 1
			y += 2.0
			층 += 1
		x += 표본간격
	return 결과


## 이 표면점 위로 몇 px 이 비어 있나. 최대 `키 + 여유 + 40` 까지만 재고 끊는다.
func _머리높이(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> float:
	var 최대 := _키 + 머리_여유 + 40.0
	var d := 6.0
	while d < 최대:
		if _속인가(공간, x, 표면y - d):
			return d
		d += 6.0
	return 최대


## 머리를 막고 있는 것의 이름. **이게 있어야 보고서가 바로 고칠 수 있는 말이 된다**
## ("여기가 낮다" 만으로는 무엇을 올려야 하는지 모른다).
func _막는것(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float, 머리: float) -> String:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, 표면y - 머리 - 2.0)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	var r := 공간.intersect_point(q, 1)
	if r.is_empty():
		return "?"
	return _주인이름(r[0].get("collider"))


## ★이 표면 위에 **플레이어 몸통이 실제로 들어가나.**
##
## ▣ 왜 점 검사가 아니라 도형 검사인가
##   `_머리높이()` 는 세로 한 줄만 본다. 그런데 플레이어는 **폭 44px** 짜리 상자다.
##   비스듬한 천장 밑이나 좁은 틈에서는 머리 한가운데는 비어 있어도 어깨가 걸린다.
##   물리 엔진이 실제로 쓰는 것과 같은 사각형을 같은 자리에 놓고 물어보는 것이
##   유일하게 거짓말을 안 하는 방법이다.
## ▣ ⚠발치 `발치_무시` px 를 빼고 재는 이유 (2026-08-19 에 오탐이 쏟아졌다)
##   처음엔 발바닥부터 머리끝까지 통째로 넣어 봤더니 **평지에서도 전부 "막힘"** 이 났다.
##   지형 윗면은 일부러 ±2.5px 물결지게 만든다(`평바닥_점들` 의 거칠기). 바닥이 평평한
##   사각형을 그 위에 놓으면 옆쪽 물결에 반드시 걸린다 — 실제 플레이에서는 아무 문제가
##   없는데도. 물리 엔진은 그런 미세 요철을 경사로 처리하고 넘어간다.
##   → **발치 16px 을 빼고 몸통·머리만** 본다. 우리가 찾는 건 "머리가 걸리나" 지
##     "발끝이 자갈에 닿나" 가 아니다.
const 발치_무시 := 16.0

func _몸통_들어가나(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> bool:
	var 높이 := _키 - 발치_무시
	var 모양 := RectangleShape2D.new()
	# 좌우로 2px 씩 줄인다 — 벽에 딱 붙어 걷는 것까지 막힘으로 세면 오탐이 쏟아진다.
	모양.size = Vector2(maxf(_폭 - 4.0, 8.0), 높이)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = 모양
	q.transform = Transform2D(0.0, Vector2(x, 표면y - 발치_무시 - 높이 * 0.5))
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return 공간.intersect_shape(q, 1).is_empty()


func _속인가(공간: PhysicsDirectSpaceState2D, x: float, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, y)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return not 공간.intersect_point(q, 1).is_empty()


func _주인이름(맞은것: Object) -> String:
	var n := 맞은것 as Node
	while n != null and n != _루트:
		if n is Node2D and not (n is CollisionPolygon2D) and not (n is CollisionShape2D) \
				and not (n is StaticBody2D):
			return n.name
		n = n.get_parent()
	return "?"


# ============================================================================
# [끼임] 걸어 다니는 바닥 위에 플레이어 키가 안 들어가는 구간
# ============================================================================
## ★이 좁은 자리가 **진짜 길목**인가, 아니면 암반 **속의 금**인가.
##
## ⚠[2026-08-19 함정] 처음엔 "머리가 낮으면 전부 끼임" 으로 보고했다. 그랬더니
##   스테이지 1·2 에서 `지형_1 x 20198~22478 (폭 2304) 머리 36px` 같은 것이 나왔다.
##   `지형_1` 은 폭이 1 만 px 이 넘는 **한 덩어리**라, 그 안쪽에는 볼록 분해된 조각들의
##   경계가 수없이 있다. 그건 **아무도 걸어갈 수 없는 암반 속**이지 길목이 아니다.
##   → 같은 층에서 **좌우 240px 안에 몸통이 들어가는 자리가 있어야** 길목으로 본다.
##     (240px = 점프 거리. 그만큼 안에 열린 데가 없으면 애초에 거기 갈 수가 없다)
##   진단 도구가 노이즈를 쏟아내면 **진짜 문제가 그 안에 묻힌다.** 그게 제일 나쁘다.
func _양옆이_트였나(표면: Array, 기준: Dictionary) -> bool:
	var x0: float = float(기준["x"])
	var y0: float = float(기준["y"])
	for s in 표면:
		if not bool(s["통과"]):
			continue
		if s["주인"] != 기준["주인"]:
			continue
		if absf(float(s["y"]) - y0) > 60.0:
			continue                       # 다른 층이다
		var dx := absf(float(s["x"]) - x0)
		if dx > 0.0 and dx <= 240.0:
			return true
	return false


func _구조물인가(이름: String) -> bool:
	for p in 구조물_접두:
		if 이름.begins_with(String(p)):
			return true
	return false


func _끼임_보고(표면: Array) -> void:
	print("\n── [끼임] 플레이어가 못 지나가는 구간 ──────────")
	var 필요 := _키 + 머리_여유
	# x 오름차순 · 같은 x 안에서는 y 오름차순으로 묶는다
	var 좁은: Array = []
	for s in 표면:
		if not bool(s["통과"]) and _양옆이_트였나(표면, s):
			좁은.append(s)
	if 좁은.is_empty():
		print("  ✔ 없음 (필요 높이 %.0fpx)" % 필요)
		return

	# 같은 층(주인 + y 가 비슷)끼리 x 로 이어 붙여 구간으로 만든다
	좁은.sort_custom(func(a, b): return a["x"] < b["x"] if not is_equal_approx(a["x"], b["x"]) else a["y"] < b["y"])
	var 구간: Array = []
	for s in 좁은:
		var 붙였나 := false
		for g in 구간:
			if g["주인"] == s["주인"] and absf(float(g["y1"]) - float(s["y"])) < 40.0 \
					and float(s["x"]) - float(g["x1"]) <= 표본간격 * 1.5:
				g["x1"] = s["x"]
				g["y1"] = s["y"]
				g["최소머리"] = minf(float(g["최소머리"]), float(s["머리"]))
				붙였나 = true
				break
		if not 붙였나:
			구간.append({"주인": s["주인"], "x0": s["x"], "x1": s["x"],
				"y0": s["y"], "y1": s["y"], "최소머리": s["머리"], "막는것": s["막는것"]})

	var 보고 := 0
	var 구조물 := 0
	for g in 구간:
		var 폭: float = float(g["x1"]) - float(g["x0"]) + 표본간격
		if 폭 < 최소_끼임폭:
			continue                       # 모서리 한두 점은 노이즈다
		if _구조물인가(String(g["막는것"])):
			구조물 += 1
			continue                       # 막으라고 만든 벽이다 — 오류가 아니다
		보고 += 1
		_총_끼임 += 1
		print("  ✖ %-16s x %.0f~%.0f (폭 %.0f)  머리 %.0fpx  → **%s 를 %.0fpx 올리거나 얇게**"
			% [g["주인"], g["x0"], g["x1"], 폭, g["최소머리"],
			   g["막는것"], 필요 - float(g["최소머리"])])
	if 구조물 > 0:
		print("  ⓘ 벽·천장이 막는 자리 %d 곳은 의도된 것이라 뺐다" % 구조물)
	if 보고 == 0:
		print("  ✔ 없음 (폭 %.0fpx 미만의 모서리 노이즈만 있었다)" % 최소_끼임폭)


# ============================================================================
# [발뜸] 그려진 지형 윗면과 실제로 서는 높이의 차이
# ============================================================================
## ▣ 어떻게 재나
##   콜리전 폴리곤은 SS2D 의 **테셀레이션 점**을 그대로 쓴다(collision_offset = 0).
##   그러니 레이캐스트로 맞은 y 와, 같은 x 에서의 테셀레이션 윗면 y 는 **같아야 한다.**
##   다르면 그만큼이 "발이 뜬(또는 파묻힌)" 양이다.
func _발뜸_보고(표면: Array) -> void:
	print("\n── [발뜸] 그려진 윗면 vs 실제로 서는 높이 ──────")
	var 지형들 := _스마트지형_모으기(_루트)
	if 지형들.is_empty():
		print("  (스마트지형 없음 — 건너뜀)")
		return

	var 최대차 := 0.0
	var 최대이름 := ""
	var 문제 := 0
	var 샘플 := 0
	for s in 표면:
		var 대상: Node2D = null
		for t in 지형들:
			if t.name == s["주인"]:
				대상 = t
				break
		if 대상 == null:
			continue
		var 그린y := _테셀_가까운y(대상, float(s["x"]), float(s["y"]))
		if is_inf(그린y):
			continue
		샘플 += 1
		var 차 := float(s["y"]) - 그린y      # +면 콜리전이 그림보다 아래 = 발이 파묻힘
		if absf(차) > absf(최대차):
			최대차 = 차
			최대이름 = String(s["주인"])
		if absf(차) > 발뜸_기준:
			문제 += 1
	if 샘플 == 0:
		print("  (비교할 표본이 없다)")
		return
	_총_발뜸 += 문제
	if 문제 == 0:
		print("  ✔ 콜리전이 그려진 윗면과 일치한다 (표본 %d · 최대 오차 %.2fpx)" % [샘플, 최대차])
	else:
		print("  ✖ %d / %d 표본에서 %.1fpx 이상 어긋난다" % [문제, 샘플, 발뜸_기준])
		print("    최대 %.1fpx (%s)  — %s"
			% [최대차, 최대이름, "콜리전이 그림보다 아래(발이 파묻힘)" if 최대차 > 0 else "콜리전이 그림보다 위(발이 뜸)"])


func _스마트지형_모으기(n: Node, 모음: Array[Node2D] = []) -> Array[Node2D]:
	for c in n.get_children():
		if c.has_method("get_point_array") and c is Node2D:
			모음.append(c as Node2D)
		_스마트지형_모으기(c, 모음)
	return 모음


## 이 지형의 테셀레이션 외곽선에서, 주어진 월드 x 를 지나는 변들 중
## **레이가 맞은 y 에 가장 가까운** y(월드). 못 찾으면 INF.
##
## ⚠[2026-08-19 함정] 처음엔 "그 x 에서 가장 높은 y" 를 썼다가 **1120px 발뜸**이라는
##   말도 안 되는 숫자가 나왔다. 스테이지 1·2 의 `지형_1` 은 폭이 1 만 px 이 넘는
##   거대한 한 덩어리라, 같은 x 에 **위아래로 여러 면**이 있다(천장 겸 바닥).
##   가장 높은 면은 플레이어가 선 면이 아니라 저 위 다른 면이었다.
##   → 실제로 발이 닿은 면과 비교해야 한다. 진단 도구가 거짓말을 하면
##     없는 문제를 고치느라 있는 문제를 놓친다.
func _테셀_가까운y(지형: Node2D, 월드x: float, 기준y: float) -> float:
	var pa = 지형.call("get_point_array")
	if pa == null:
		return INF
	var 점들: PackedVector2Array = pa.get_tessellated_points()
	if 점들.size() < 3:
		return INF
	var xf := 지형.global_transform
	var 가까운 := INF
	var 최소거리 := INF
	for i in 점들.size():
		var a: Vector2 = xf * 점들[i]
		var b: Vector2 = xf * 점들[(i + 1) % 점들.size()]
		if is_equal_approx(a.x, b.x):
			continue
		var lo := minf(a.x, b.x)
		var hi := maxf(a.x, b.x)
		if 월드x < lo or 월드x > hi:
			continue
		var t := (월드x - a.x) / (b.x - a.x)
		var y := a.y + (b.y - a.y) * t
		var d := absf(y - 기준y)
		if d < 최소거리:
			최소거리 = d
			가까운 = y
	return 가까운


# ============================================================================
# [공중] 아래에 받침이 없는 지형
# ============================================================================
func _공중지형_보고() -> void:
	print("\n── [공중] 아래에 아무 받침도 없는 지형 ─────────")
	var 공간 := _루트.get_world_2d().direct_space_state
	var 지형들 := _스마트지형_모으기(_루트)
	var 범위 := _범위()
	var 뜬것: Array = []
	for t in 지형들:
		if String(t.name).begins_with("받침"):
			continue
		var 경계 := _경계(t)
		if 경계.size.length() < 1.0:
			continue
		# 덩어리 아래 3 지점에서 아래로 쏴 본다. 셋 다 허공이면 떠 있는 것이다.
		var 아래 := 0
		for 비율 in [0.2, 0.5, 0.8]:
			var x: float = 경계.position.x + 경계.size.x * float(비율)
			var q := PhysicsRayQueryParameters2D.create(
				Vector2(x, 경계.end.y + 6.0), Vector2(x, 범위.end.y), 1 | 8)
			if not 공간.intersect_ray(q).is_empty():
				아래 += 1
		if 아래 == 0:
			뜬것.append({"이름": t.name, "경계": 경계})
	if 뜬것.is_empty():
		print("  ✔ 없음")
		return
	_총_공중 += 뜬것.size()
	print("  ⚠ %d 개 (오류는 아니다 — 의도한 공중 발판이면 그대로 둔다)" % 뜬것.size())
	for f in 뜬것.slice(0, 12):
		var b: Rect2 = f["경계"]
		print("      %-18s x %.0f~%.0f  y %.0f" % [f["이름"], b.position.x, b.end.x, b.end.y])
	if 뜬것.size() > 12:
		print("      … 외 %d 개" % (뜬것.size() - 12))


func _경계(노드: Node) -> Rect2:
	var 결과 := Rect2()
	var 처음 := true
	var 대기: Array[Node] = [노드]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			대기.append(c)
		if n is CollisionPolygon2D:
			var poly := (n as CollisionPolygon2D).polygon
			if poly.size() >= 3:
				var mn := poly[0]
				var mx := poly[0]
				for p in poly:
					mn = mn.min(p)
					mx = mx.max(p)
				var r := Rect2((n as Node2D).to_global(mn), Vector2.ZERO)
				r = r.expand((n as Node2D).to_global(mx))
				결과 = r if 처음 else 결과.merge(r)
				처음 = false
	return 결과
