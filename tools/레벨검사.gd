extends SceneTree
## ============================================================================
## [2026-08-06 신규] 레벨 검사기 — 맵 레벨디자인 보조 도구
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/레벨검사.gd -- <씬경로> [--지도]
## 예:
##   Godot --headless --path . -s res://tools/레벨검사.gd -- res://scenes/스마트월드/_원본/원본_폐수로.tscn --지도
##
## ============================================================================
## ▣ 왜 필요한가
##   레벨을 코드로 짓다 보면 **눈으로는 절대 안 보이는 사고**가 난다.
##     · 발판을 놓긴 놨는데 점프로 못 닿는다 (죽은 콘텐츠)
##     · 내려갈 순 있는데 올라올 방법이 없다 (소프트락)
##     · 낙차가 치명 거리를 아슬아슬하게 넘어 "왜 죽었는지 모르겠는" 구간이 생긴다
##   지금까지는 실행해서 걸어 다녀 봐야 알 수 있었고, 그래서 아무도 안 봤다.
##   이 도구는 **실제 물리 엔진으로** 지형을 훑어 위 3 가지를 숫자로 보고한다.
##
## ▣ 어떻게 재나 (추정이 아니라 실측이다)
##   1. 씬을 진짜로 띄우고 물리 프레임을 한 번 돌린다
##   2. 32px 마다 세로로 레이캐스트를 반복해 **모든 층의 발판 윗면**을 찾는다
##      (한 x 에 여러 층이 있는 레인월드식 지형을 다루려면 이 방식뿐이다)
##   3. 이웃한 표면점을 이어 **선반(segment)** 으로 묶는다
##   4. 플레이어의 실제 점프 수치(`player.gd` 의 export 값에서 역산)로
##      선반 사이 도달 가능성 그래프를 만들고, 시작 지점에서 BFS 한다
##
## ▣ 무엇을 보고하나
##   [도달불가]  시작 지점에서 갈 수 없는 선반 — 죽은 콘텐츠거나 배치 실수
##   [소프트락]  들어갈 수는 있는데 나올 수 없는 선반
##   [치명낙하]  가장자리에서 걸어 나가면 치명 거리를 넘게 떨어지는 곳
##               → **이건 오류가 아니라 정보다.** 의도한 구멍이면 그대로 두면 된다.
##                  다만 "여기가 죽는 자리" 목록을 알고 설계하는 것과 모르는 건 다르다.
##   [지도]      --지도 를 붙이면 스테이지 단면을 ASCII 로 그린다
##
## ▣ 판정 기준 (플레이어 실제 물리에서 역산 — 하드코딩 아님)
##   올라갈 수 있는 높이 = 점프 높이 × 0.80   (조작 오차 여유 20%)
##   건널 수 있는 거리   = 점프 거리 × 0.85
##   도약대 상승        = 도약속도² / (2 × gravity × 상승_배수)
## ============================================================================

const 표본간격 := 32.0        ## x 를 이 간격으로 훑는다. 작을수록 정확하고 느리다.
const 최대층 := 12            ## 한 x 에서 찾을 최대 층수 (무한 루프 방지)
const 여유_세로 := 0.80       ## 점프 높이의 이만큼까지만 "올라갈 수 있다"고 본다
const 여유_가로 := 0.85       ## 점프 거리의 이만큼까지만 "건널 수 있다"고 본다
## 표면점을 하나의 선반으로 묶을 때 허용하는 높이 차 (경사면을 끊지 않기 위해)
const 묶기_허용높이 := 26.0

var _씬경로 := ""
var _지도출력 := false
var _상세출력 := false        ## --상세 : 선반 하나하나와 그 이웃을 전부 찍는다
var _루트: Node2D = null
var _n := 0

# 계측된 플레이어 성능
var _점프높이 := 160.0
var _점프거리 := 320.0
var _도약높이 := 0.0
var _치명낙하 := 520.0
var _시작위치 := Vector2.ZERO

# 선반 = { "x0":float, "x1":float, "y":float, "유령":bool, "주인":String }
var _선반: Array[Dictionary] = []
var _이웃: Array = []          ## 인접 리스트 (선반 index → Array[int])

## "주인" 이름이 이걸로 시작하면 **구조물**로 본다 — 밟으라고 만든 게 아니다.
## 천장 매스의 윗면 같은 건 도달 불가가 당연하므로 보고에서 뺀다.
## (안 빼면 "도달 불가 94 개" 같은 쓸모없는 경고가 쏟아져 진짜 문제가 묻힌다)
## ★[2026-08-17] "받침" 추가 — `tools/지형_다듬기.gd` 가 만드는 뿌리(기둥·꼬리·버팀대)다.
##   기본값은 콜리전이 없어서 이 검사기(레이캐스트 기반)에 애초에 안 잡힌다.
##   하지만 `--콜리전` 으로 단단하게 만들면 잡히기 시작하는데, 받침의 **윗면**은
##   밟으라고 만든 면이 아니다(발판 아랫면에 붙은 옆구리다). 빼지 않으면
##   도달률이 실제보다 낮게 나와 "레벨이 망가졌다" 는 오판을 하게 된다.
const 구조물_접두 := ["천장", "굴뚝벽", "벽", "받침"]


func _init() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--지도":
			_지도출력 = true
		elif a == "--상세":
			_상세출력 = true
		elif not a.begins_with("--"):
			_씬경로 = a
	if _씬경로.is_empty():
		print("사용법: Godot --headless --path . -s res://tools/레벨검사.gd -- <씬경로> [--지도]")
		quit(2)
		return
	# ★_init() 안에서 add_child 하면 그 노드의 _ready 가 안 돈다.
	#   물리 프레임을 기다렸다가 진행해야 콜리전이 실제로 등록된다.
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	if _n == 1:
		if not ResourceLoader.exists(_씬경로):
			push_error("씬이 없다: %s" % _씬경로)
			quit(2)
			return
		_루트 = (load(_씬경로) as PackedScene).instantiate() as Node2D
		root.add_child(_루트)
	elif _n == 4:
		# 3 프레임쯤 지나야 SS2D 콜리전이 다 구워지고 유령 발판 레이어도 확정된다
		# 색 경계의 면 겹침은 판정 자체를 모순으로 만든다. 정보성 경고가 아니라
		# 레벨을 통과시키면 안 되는 오류라, _검사() 결과로 종료 코드를 나눈다.
		quit(0 if _검사() else 1)


# ============================================================================
# 1. 플레이어 성능 계측
# ============================================================================
## `player.gd` 의 export 값에서 실제 점프 높이/거리와 도약대 상승 높이를 역산한다.
## 하드코딩하지 않는 이유: 스테이지마다 점프 세팅이 다를 수 있고,
## 누가 값을 바꿨을 때 검사기가 조용히 틀린 답을 내면 안 되기 때문이다.
func _성능_계측() -> void:
	_플레이어_크기_재기()
	var p := _루트.get_node_or_null("Player")
	if p == null:
		push_warning("레벨검사: Player 노드를 못 찾음 — 기본 수치로 검사한다")
		return
	var 타일: float = float(p.get("타일_크기"))
	_점프높이 = float(p.get("점프_높이_칸")) * 타일
	_점프거리 = float(p.get("점프_거리_칸")) * 타일
	var 중력: float = float(p.get("gravity"))
	var 상승배수: float = float(p.get("상승_배수"))
	var 상승중력 := 중력 * 상승배수

	# 도약대 — 이 씬에서 가장 센 것 기준
	var 최대속도 := 0.0
	for n in _루트.get_tree().get_nodes_in_group("도약대"):
		최대속도 = maxf(최대속도, absf(float(n.get("도약속도"))))
	if 최대속도 > 0.0 and 상승중력 > 0.0:
		_도약높이 = 최대속도 * 최대속도 / (2.0 * 상승중력)

	_치명낙하 = float(_루트.get("치명_낙하거리"))
	_시작위치 = _루트.get("시작_위치")

	print("── 플레이어 실측 ──────────────────────────────")
	print("  점프 높이 %.0fpx / 점프 거리 %.0fpx" % [_점프높이, _점프거리])
	print("  상승 중력 %.0f  (gravity %.1f × 상승_배수 %.3f)" % [상승중력, 중력, 상승배수])
	if _도약높이 > 0.0:
		print("  도약대 상승 %.0fpx" % _도약높이)
	print("  치명 낙하 거리 %.0fpx" % _치명낙하)


# ============================================================================
# 2. 지형 훑기 — 모든 층의 발판 윗면 찾기
# ============================================================================
## 한 x 에서 위→아래로 레이를 반복 발사해 층을 전부 찾는다.
## 레이가 한 번 맞으면 **그 물체 아래로 조금 내려간 지점**에서 다시 쏜다.
## 그래야 겹쳐 있는 여러 층을 하나도 안 놓친다.
func _표면_훑기(범위: Rect2) -> Array:
	var 공간 := _루트.get_world_2d().direct_space_state
	var 결과: Array = []                   # [x, y, 유령여부, 주인이름]
	var x := 범위.position.x
	while x <=범위.end.x:
		var y := 범위.position.y
		var 층 := 0
		while 층 < 최대층 and y < 범위.end.y:
			var q := PhysicsRayQueryParameters2D.create(
				Vector2(x, y), Vector2(x, 범위.end.y), 1 | 8)   # 1=지형, 8=유령 발판
			var r := 공간.intersect_ray(q)
			if r.is_empty():
				break
			var 맞은y: float = r["position"].y
			var 유령 := int(r["collider"].collision_layer) == 8
			var 주인 := _주인이름(r["collider"])
			# ★머리 공간 검사 — 위가 막혀 있으면 설 수 없는 자리다.
			#   이걸 안 하면 두꺼운 암반 **속**의 조각 경계까지 "발판"으로 잡힌다.
			if 주인 != "Player" and _머리공간(공간, x, 맞은y):
				결과.append([x, 맞은y, 유령, 주인])

			# 맞은 물체 **아래로 완전히 빠져나간 뒤** 다음 층을 찾는다.
			# ⚠[2026-08-06 함정] 처음엔 짧은 레이를 반복해 "안이 비었나"를 봤는데,
			#   Godot 의 레이는 기본적으로 **도형 안에서 시작하면 아무것도 안 맞는다**
			#   (hit_from_inside = false). 그래서 두꺼운 바닥 속을 통과하지 못하고,
			#   볼록 분해된 조각의 경계마다 가짜 발판이 생겼다(바닥_1 안에서만 4 개).
			#   → 레이가 아니라 **점 검사(intersect_point)** 로 "여기가 속인가"를 본다.
			y = 맞은y + 4.0
			var 안전 := 0
			while 안전 < 800 and y < 범위.end.y and _속인가(공간, x, y):
				y += 8.0
				안전 += 1
			y += 2.0
			층 += 1
		x += 표본간격
	return 결과


## 이 점이 지형 안쪽인가. (레이와 달리 점 검사는 도형 내부를 제대로 잡는다)
func _속인가(공간: PhysicsDirectSpaceState2D, x: float, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, y)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return not 공간.intersect_point(q, 1).is_empty()


## 표면 바로 위에 플레이어가 설 만한 공간이 있는가.
## 플레이어 콜리전 높이가 약 47px 이라 여유를 포함해 56px 를 본다.
func _머리공간(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> bool:
	# 플레이어 키 + 여유 8px 만큼 위가 비어 있어야 그 자리에 설 수 있다.
	# 3 지점만 찍는다(발치·중간·머리끝) — 촘촘히 볼수록 느려지는데 이 정도면 충분하다.
	var 키 := _플레이어_높이 + 8.0
	for 비율 in [0.15, 0.55, 1.0]:
		if _속인가(공간, x, 표면y - 키 * 비율):
			return false
	return true


## 맞은 콜리전 바디에서 "누구의 지형인가" 를 알아낸다.
## StaticBody2D 는 대개 스마트지형/도약대/무너지는바위의 자식이므로 부모로 올라간다.
## 이름을 알면 보고서가 "발판_7 이 도달 불가" 처럼 **바로 고칠 수 있는 말**이 된다.
func _주인이름(맞은것: Object) -> String:
	var n := 맞은것 as Node
	# 연결통로가 스스로 만드는 바닥/천장/뒷벽은 이름이 고정돼 있다.
	# 천장·뒷벽의 **바깥면**은 밟으라고 만든 게 아니므로 구조물로 표시해 보고에서 뺀다.
	# (통로 '바닥' 은 실제로 걸어 다니는 면이라 그대로 둔다)
	if n and (n.name == "천장" or n.name == "뒷벽"):
		var 통로 := n.get_parent()
		return "천장_%s" % (통로.name if 통로 else "통로")
	while n != null:
		if n == _루트:
			break
		# 지형층/오브젝트층 바로 아래 노드가 우리가 이름 붙인 그 노드다
		var 부모 := n.get_parent()
		if 부모 and (부모.name == "지형" or 부모.name == "오브젝트"):
			return n.name
		n = 부모
	return (맞은것 as Node).name if 맞은것 is Node else "?"


## 주인 이름이 구조물(천장·벽)인가 — 밟으라고 만든 지형이 아니다.
func _구조물인가(주인: String) -> bool:
	for p in 구조물_접두:
		if 주인.begins_with(p):
			return true
	return false


## 이웃한 표면점을 하나의 선반으로 묶는다.
## x 가 바로 옆이고 높이 차가 `묶기_허용높이` 이내면 같은 선반으로 본다.
func _선반_묶기(표면: Array) -> void:
	# x → 그 x 의 층 목록
	var 열: Dictionary = {}
	for s in 표면:
		var kx: float = s[0]
		if not 열.has(kx):
			열[kx] = []
		열[kx].append(s)

	var 열키: Array = 열.keys()
	열키.sort()

	# 진행 중인 선반들: { "x0","x1","y","유령" }
	var 진행: Array[Dictionary] = []
	for kx in 열키:
		var 이번: Array = 열[kx]
		var 이어짐: Array[Dictionary] = []
		for s in 이번:
			var y: float = s[1]
			var 유령: bool = s[2]
			var 주인: String = s[3]
			var 붙일: Dictionary = {}
			for seg in 진행:
				# 바로 앞 열에서 끝났고 · 높이가 비슷하고 · 같은 노드의 면이면 이어 붙인다.
				# 주인까지 봐야 서로 다른 발판이 우연히 같은 높이일 때 하나로 뭉치지 않는다.
				if absf(seg["x1"] - (kx - 표본간격)) < 0.5 \
						and absf(seg["y"] - y) <= 묶기_허용높이 \
						and seg["유령"] == 유령 and seg["주인"] == 주인:
					붙일 = seg
					break
			if 붙일.is_empty():
				붙일 = { "x0": kx, "x1": kx, "y": y, "유령": 유령, "주인": 주인 }
				_선반.append(붙일)
			붙일["x1"] = kx
			붙일["y"] = y
			이어짐.append(붙일)
		진행 = 이어짐

	# 한 표본(32px)짜리 티끌은 버린다 — 지형 요철에서 생기는 잡음이다
	var 걸러진: Array[Dictionary] = []
	for seg in _선반:
		if seg["x1"] - seg["x0"] >= 표본간격 * 0.5:
			걸러진.append(seg)
	_선반 = 걸러진


# ============================================================================
# 3. 도달 가능성 그래프
# ============================================================================
## a 에서 b 로 갈 수 있는가.
##   · 위로 : 높이 차 ≤ 점프 높이 × 0.80  (도약대가 a 위에 있으면 도약 높이까지)
##   · 아래 : 낙차 ≤ 치명 낙하 거리  (그보다 깊으면 떨어지는 순간 죽는다)
##   · 가로 : 두 선반의 가장 가까운 끝 사이 거리 ≤ 점프 거리 × 0.85
func _갈수있나(a: Dictionary, b: Dictionary, a_도약: bool) -> bool:
	var 가로 := 0.0
	if b["x0"] > a["x1"]:
		가로 = b["x0"] - a["x1"]
	elif a["x0"] > b["x1"]:
		가로 = a["x0"] - b["x1"]
	if 가로 > _점프거리 * 여유_가로:
		return false

	var 올라감: float = a["y"] - b["y"]        # 양수면 b 가 위에 있다
	if 올라감 > 0.0:
		var 한계 := _점프높이 * 여유_세로
		if a_도약:
			한계 = maxf(한계, _도약높이)
		return 올라감 <= 한계
	# 내려가는 경우 — 치명 거리를 넘으면 그 길은 "죽는 길" 이라 연결로 치지 않는다
	return -올라감 <= _치명낙하


## "조금만 손보면 닿았을" 이웃을 찾아 알려준다.
## 세로 단차가 판정선을 30px 이내로 넘었거나, 가로 간격이 60px 이내로 넘은 경우.
## → 레벨을 다시 열어 보지 않아도 **몇 px 를 어느 쪽으로 옮기면 되는지** 바로 나온다.
func _아쉬운_후보(i: int) -> String:
	var a: Dictionary = _선반[i]
	var 세로한계 := _점프높이 * 여유_세로
	var 가로한계 := _점프거리 * 여유_가로
	var 최고 := ""
	var 최소초과 := 1e20
	for j in _선반.size():
		if i == j or _이웃[i].has(j):
			continue
		var b: Dictionary = _선반[j]
		var 가로 := 0.0
		if b["x0"] > a["x1"]:
			가로 = b["x0"] - a["x1"]
		elif a["x0"] > b["x1"]:
			가로 = a["x0"] - b["x1"]
		var 올라감: float = a["y"] - b["y"]
		if 올라감 <= 0.0:
			continue                                  # 내려가는 건 아쉬울 게 없다
		var 세로초과 := 올라감 - 세로한계
		var 가로초과 := 가로 - 가로한계
		if 세로초과 > 30.0 or 가로초과 > 60.0:
			continue
		var 점수 := maxf(세로초과, 0.0) + maxf(가로초과, 0.0)
		if 점수 < 최소초과:
			최소초과 = 점수
			var 조각: Array[String] = []
			if 세로초과 > 0.0:
				조각.append("단차 %.0fpx (한계 %.0f · %.0f 초과)" % [올라감, 세로한계, 세로초과])
			if 가로초과 > 0.0:
				조각.append("가로 %.0fpx (한계 %.0f · %.0f 초과)" % [가로, 가로한계, 가로초과])
			최고 = "%s 로 갈 뻔했다 — %s" % [b["주인"], " / ".join(조각)]
	return 최고


## 이 선반 위에 도약대가 서 있는가.
func _도약대_있나(seg: Dictionary) -> bool:
	# ⚠[2026-08-07 함정] 여유를 40px 로 잡았더니 **도약대가 있는데도 없다고 나왔다.**
	#   도약대(폭 150px)가 지면 위에 서면 그 자리에 새 표면이 생겨
	#   **지면 선반이 둘로 갈린다.** 그러면 도약대 중심은 양쪽 조각 끝에서
	#   각각 75px 씩 떨어져 40px 판정을 벗어난다.
	#   → 결과: 보정기가 "아직 못 올라간다" 며 도약대를 8 개나 더 깔았다.
	#   여유를 도약대 반폭(75) + 여유(55) = 130px 로 잡아 양쪽 조각을 모두 인정한다.
	const 여유_x := 130.0
	for n in _루트.get_tree().get_nodes_in_group("도약대"):
		var p: Vector2 = (n as Node2D).global_position
		if p.x >= seg["x0"] - 여유_x and p.x <= seg["x1"] + 여유_x \
				and absf(p.y - seg["y"]) < 90.0:
			return true
	return false


func _그래프_만들기() -> void:
	var 도약: Array[bool] = []
	for seg in _선반:
		도약.append(_도약대_있나(seg))
	_이웃 = []
	for i in _선반.size():
		var 목록: Array[int] = []
		for j in _선반.size():
			if i == j:
				continue
			if _갈수있나(_선반[i], _선반[j], 도약[i]):
				목록.append(j)
		_이웃.append(목록)


## 시작 위치에서 BFS. 반환: 도달 가능한 선반 index 집합
func _도달_집합(시작: int) -> Dictionary:
	var 본것 := { 시작: true }
	var 큐: Array[int] = [시작]
	while not 큐.is_empty():
		var cur: int = 큐.pop_front()
		for nb in _이웃[cur]:
			if not 본것.has(nb):
				본것[nb] = true
				큐.append(nb)
	return 본것


## 시작 위치 바로 아래의 선반을 찾는다.
func _시작_선반() -> int:
	var 최적 := -1
	var 최소 := 1e20
	for i in _선반.size():
		var seg: Dictionary = _선반[i]
		if _시작위치.x < seg["x0"] - 60.0 or _시작위치.x > seg["x1"] + 60.0:
			continue
		var d: float = seg["y"] - _시작위치.y
		if d < -40.0:          # 시작 위치보다 위에 있는 발판은 후보가 아니다
			continue
		if d < 최소:
			최소 = d
			최적 = i
	return 최적


## 출구 통로 바로 앞의 선반 — 소프트락 판정의 목표 지점.
func _출구_선반() -> int:
	var 출구위치 := Vector2.INF
	for n in _루트.get_tree().get_nodes_in_group("연결통로"):
		if int(n.get("역할")) == 0:        # 0 = 출구
			출구위치 = (n as Node2D).global_position
			break
	if 출구위치 == Vector2.INF:
		return -1
	var 최적 := -1
	var 최소 := 1e20
	for i in _선반.size():
		var seg: Dictionary = _선반[i]
		if _구조물인가(seg["주인"]):
			continue
		# 통로 입구에서 왼쪽으로 400px 안쪽에 있는 선반 중 높이가 가장 가까운 것
		if 출구위치.x - seg["x1"] > 400.0 or seg["x0"] > 출구위치.x + 100.0:
			continue
		var d: float = absf(seg["y"] - 출구위치.y)
		if d < 최소:
			최소 = d
			최적 = i
	return 최적


# ============================================================================
# 4. 치명 낙하 지점
# ============================================================================
## 선반 가장자리에서 한 발 걸어 나갔을 때 어디에 떨어지는지 본다.
## 착지점까지의 낙차가 치명 거리를 넘으면 "여기서 발을 헛디디면 죽는다".
func _치명가장자리() -> Array:
	var 공간 := _루트.get_world_2d().direct_space_state
	var 결과: Array = []
	for seg in _선반:
		# 천장 윗면·벽 꼭대기에서 떨어지는 건 애초에 플레이어가 갈 일이 없다.
		# 보고에 섞이면 진짜 위험 지점이 묻힌다.
		if _구조물인가(seg["주인"]):
			continue
		for 쪽 in [-1.0, 1.0]:
			var x: float = (seg["x0"] - 30.0) if 쪽 < 0 else (seg["x1"] + 30.0)
			var 시작y: float = seg["y"] - 10.0
			var q := PhysicsRayQueryParameters2D.create(
				Vector2(x, 시작y), Vector2(x, 시작y + 6000.0), 1 | 8)
			var r := 공간.intersect_ray(q)
			var 낙차 := 6000.0
			if not r.is_empty():
				낙차 = float(r["position"].y) - seg["y"]
			if 낙차 > _치명낙하:
				결과.append({
					"x": x, "y": seg["y"],
					"낙차": (INF if 낙차 >= 5999.0 else 낙차),
				})
	return 결과


# ============================================================================
# 5. 본체
# ============================================================================
## 모든 색 경계끼리 면적으로 겹치는지 검사한다.
## 변·꼭짓점 접촉은 의도된 경계 연결이므로 `색경계.양의_교집합들()`이 0px²로 걸러 준다.
## ColorZone은 편집 중 즉시 되돌리고, 식물B·빛기둥처럼 런타임에 만들어지는 경계는
## 이 검사에서 최종 배치를 감사한다. 경계 종류에 따라 규칙이 달라지면 판정이 흔들리기 때문이다.
func _색경계_검사() -> bool:
	var 구역들: Array[Node] = []
	for n in _루트.get_tree().get_nodes_in_group(색경계.그룹):
		if n != null and is_instance_valid(n) and n.has_method("경계_폴리곤들"):
			구역들.append(n)
	print("")
	print("── 색 경계 면 겹침 ───────────────────────────")
	if 구역들.size() < 2:
		print("  ✔ 색 경계 %d개 — 서로 겹칠 쌍 없음" % 구역들.size())
		return false

	var 오류 := false
	var 검사쌍 := 0
	for i in range(구역들.size() - 1):
		var a: Node = 구역들[i]
		for j in range(i + 1, 구역들.size()):
			var b: Node = 구역들[j]
			for pa in a.경계_폴리곤들():
				for pb in b.경계_폴리곤들():
					검사쌍 += 1
					var 교집합들 := 색경계.양의_교집합들(pa, pb)
					if 교집합들.is_empty():
						continue
					오류 = true
					var 면적 := 0.0
					for poly in 교집합들:
						# 색경계 내부 함수와 같은 신발끈 공식 — 보고용 합계다.
						for k in poly.size():
							var p: Vector2 = poly[k]
							var q: Vector2 = poly[(k + 1) % poly.size()]
							면적 += p.x * q.y - q.x * p.y
					면적 = absf(면적) * 0.5
					print("  ✖ %s ↔ %s 가 %.1fpx² 겹친다 — 변을 맞닿게 하거나 떼어 놓을 것"
						% [a.name, b.name, 면적])
	if 오류:
		print("  ✖ 색 경계 면 겹침 오류 — 종료 코드 1")
	else:
		print("  ✔ 색 경계 %d개 · 비교 %d쌍 — 면 겹침 없음" % [구역들.size(), 검사쌍])
	return 오류


func _검사() -> bool:
	print("")
	print("════════════════════════════════════════════════")
	print(" 레벨 검사 — %s" % _씬경로)
	print("════════════════════════════════════════════════")
	_성능_계측()
	var 색경계오류 := _색경계_검사()

	var 리밋: Rect2 = _루트.get("카메라_리밋")
	if 리밋.size.length() < 1.0:
		리밋 = Rect2(-500, -1000, 6000, 4000)
	# 카메라 리밋을 그대로 쓰면 통로 안쪽까지 훑느라 느려진다. 위아래만 조금 넓힌다.
	var 범위 := Rect2(리밋.position.x, 리밋.position.y - 200.0,
		리밋.size.x, 리밋.size.y + 400.0)

	var 표면 := _표면_훑기(범위)
	_선반_묶기(표면)
	print("")
	print("── 지형 ───────────────────────────────────────")
	print("  훑은 범위 x %.0f~%.0f · y %.0f~%.0f"
		% [범위.position.x, 범위.end.x, 범위.position.y, 범위.end.y])
	print("  표면점 %d 개 → 선반 %d 개" % [표면.size(), _선반.size()])

	if _선반.is_empty():
		print("  ⚠ 밟을 수 있는 지형을 하나도 못 찾았다. 콜리전이 안 구워졌을 수 있다.")
		return not 색경계오류

	_그래프_만들기()
	var 시작 := _시작_선반()
	if 시작 < 0:
		print("  ⚠ 시작 위치 %s 아래에서 발판을 못 찾았다 — 공중에서 시작한다는 뜻이다."
			% str(_시작위치))
		시작 = 0
	var 도달 := _도달_집합(시작)

	# ── 도달 불가 ──
	# ★구조물(천장 윗면·벽 꼭대기)은 애초에 밟으라고 만든 게 아니라 보고에서 뺀다.
	#   안 그러면 진짜 문제(못 밟는 발판)가 수십 줄의 노이즈에 묻힌다.
	print("")
	print("── 도달 가능성 ────────────────────────────────")
	print("  시작 선반 #%d  (%s · x %.0f~%.0f, y %.0f)"
		% [시작, _선반[시작]["주인"], _선반[시작]["x0"], _선반[시작]["x1"], _선반[시작]["y"]])
	var 놀이터 := 0
	var 못감: Array = []
	for i in _선반.size():
		if _구조물인가(_선반[i]["주인"]):
			continue
		놀이터 += 1
		if not 도달.has(i):
			못감.append(i)
	print("  밟는 지형 %d 개 (구조물 %d 개 제외)  ·  그중 도달 %d 개"
		% [놀이터, _선반.size() - 놀이터, 놀이터 - 못감.size()])
	if 못감.is_empty():
		print("  ✔ 밟는 지형 전부에 갈 수 있다")
	else:
		print("  ✖ 도달 불가 %d 개:" % 못감.size())
		for i in 못감.slice(0, 20):
			var s: Dictionary = _선반[i]
			print("      %-18s x %.0f~%.0f  y %.0f  %s"
				% [s["주인"], s["x0"], s["x1"], s["y"],
					"(유령발판 — 칠해야 실체)" if s["유령"] else ""])
		if 못감.size() > 20:
			print("      … 외 %d 개" % (못감.size() - 20))

	# ── 소프트락 ──
	# "나갈 곳이 아예 없는 선반" 만 보면 부족하다. 진짜 소프트락은
	# **출구 통로까지 갈 수 없게 되는 것**이다. 그래서 출구를 목표로 두고 역으로 판단한다.
	var 목표 := _출구_선반()
	print("")
	print("── 소프트락 ───────────────────────────────────")
	var 막힘: Array = []
	for i in 도달.keys():
		if _구조물인가(_선반[i]["주인"]):
			continue
		if 목표 >= 0:
			# 거기서 출발했을 때 출구에 닿는가
			if not _도달_집합(int(i)).has(목표):
				막힘.append(i)
		else:
			var 나갈곳 := 0
			for nb in _이웃[i]:
				if nb != i:
					나갈곳 += 1
			if 나갈곳 == 0:
				막힘.append(i)
	if 목표 >= 0:
		print("  목표 = 출구 통로 앞 선반 #%d (x %.0f, y %.0f)"
			% [목표, _선반[목표]["x0"], _선반[목표]["y"]])
	else:
		print("  출구 통로를 못 찾아 '나갈 곳이 없는 선반' 기준으로 검사한다")
	if 막힘.is_empty():
		print("  ✔ 갇히는 곳 없음")
	else:
		print("  ✖ 여기 들어가면 출구까지 못 간다 — %d 개:" % 막힘.size())
		for i in 막힘.slice(0, 12):
			var s: Dictionary = _선반[i]
			print("      %-18s x %.0f~%.0f  y %.0f" % [s["주인"], s["x0"], s["x1"], s["y"]])
			# ★어디로 갈 수 있는지 같이 보여준다. "왜 갇혔는지" 를 바로 알 수 있어야
			#   고칠 수 있다 — 목록만 주면 결국 다시 씬을 열어 봐야 한다.
			if _이웃[i].is_empty():
				print("           → 갈 수 있는 곳이 하나도 없다")
			else:
				var 설명: Array[String] = []
				for nb in _이웃[i].slice(0, 4):
					var t: Dictionary = _선반[nb]
					설명.append("%s(y%.0f, %+.0f)" % [t["주인"], t["y"], s["y"] - t["y"]])
				print("           → %s" % ", ".join(설명))
			# 가장 아까운 것: **조금만 낮췄으면 닿았을** 이웃 후보
			var 아쉬움 := _아쉬운_후보(i)
			if not 아쉬움.is_empty():
				print("           ⓘ %s" % 아쉬움)
		if 막힘.size() > 12:
			print("      … 외 %d 개" % (막힘.size() - 12))

	# ── 치명 낙하 지점 ──
	var 치명 := _치명가장자리()
	print("")
	print("── 치명 낙하 가장자리 (정보) ──────────────────")
	print("  치명 거리 %.0fpx 를 넘는 낙차가 있는 가장자리 %d 곳" % [_치명낙하, 치명.size()])
	print("  ※ 오류가 아니다. 의도한 구멍이면 그대로 두면 된다.")
	var 보인개수 := 0
	for c in 치명:
		if 보인개수 >= 12:
			break
		var 낙차표기 := "밑이 없음" if is_inf(c["낙차"]) else "%.0fpx" % c["낙차"]
		print("      x %.0f  y %.0f  낙차 %s" % [c["x"], c["y"], 낙차표기])
		보인개수 += 1
	if 치명.size() > 12:
		print("      … 외 %d 곳" % (치명.size() - 12))

	# ── 선반 전체 목록 (--상세) ──
	# 숫자가 안 맞을 때 "내가 생각한 y 와 실측 y 가 다르다"를 확인하는 용도.
	# 지형은 콜리전 오프셋(24px)과 표본 간격 때문에 **의도한 좌표와 실측이 늘 조금 다르다.**
	if _상세출력:
		print("")
		print("── 선반 전체 (%d) ─────────────────────────────" % _선반.size())
		for i in _선반.size():
			var s: Dictionary = _선반[i]
			var 표시 := "#%-3d %-18s x %7.0f~%-7.0f y %7.0f %s %s" % [
				i, s["주인"], s["x0"], s["x1"], s["y"],
				"유령" if s["유령"] else "    ",
				"[도달]" if 도달.has(i) else "[불가]"]
			print("  " + 표시)
			var 목록: Array[String] = []
			for nb in _이웃[i]:
				목록.append("#%d %s(%+.0f)" % [nb, _선반[nb]["주인"], s["y"] - _선반[nb]["y"]])
			print("        → %s" % ("없음" if 목록.is_empty() else ", ".join(목록)))

	if _지도출력:
		_지도_그리기(범위)

	print("")
	print("════════════════════════════════════════════════")
	return not 색경계오류


# ============================================================================
# 6. ASCII 지도 — 스테이지 단면을 한눈에
# ============================================================================
## 터미널에서 스테이지 전체 모양을 보는 용도. 스크린샷보다 빠르고,
## "여기 발판이 비어 있네" 같은 건 오히려 이게 더 잘 보인다.
##   # = 지형(밟을 수 있음)   · = 유령 발판(칠해야 실체)   S = 시작 위치
func _지도_그리기(범위: Rect2) -> void:
	var 가로칸 := 150
	var 세로칸 := 40
	var sx := 범위.size.x / float(가로칸)
	var sy := 범위.size.y / float(세로칸)

	var 격자: Array = []
	for r in 세로칸:
		격자.append(" ".repeat(가로칸).split(""))

	for seg in _선반:
		var r := int((seg["y"] - 범위.position.y) / sy)
		if r < 0 or r >= 세로칸:
			continue
		var c0 := int((seg["x0"] - 범위.position.x) / sx)
		var c1 := int((seg["x1"] - 범위.position.x) / sx)
		for c in range(maxi(c0, 0), mini(c1 + 1, 가로칸)):
			격자[r][c] = "·" if seg["유령"] else "#"

	var sr := int((_시작위치.y - 범위.position.y) / sy)
	var sc := int((_시작위치.x - 범위.position.x) / sx)
	if sr >= 0 and sr < 세로칸 and sc >= 0 and sc < 가로칸:
		격자[sr][sc] = "S"

	print("")
	print("── 지도 (1칸 = %.0f × %.0f px) ──" % [sx, sy])
	for r in 세로칸:
		var 줄 := ""
		for c in 가로칸:
			줄 += 격자[r][c]
		if 줄.strip_edges().is_empty():
			continue                      # 완전히 빈 줄은 건너뛴다 (세로로 길어서)
		print("%6.0f |%s|" % [범위.position.y + float(r) * sy, 줄])

# ============================================================================
# 플레이어 실측 크기
# ----------------------------------------------------------------------------
# ★[2026-08-07] 예전에는 "머리 공간 52px" 를 상수로 박아 뒀다. 그런데 신우님이
#   Player.tscn 의 콜리전을 바꾸면서 **플레이어 키가 47px → 97px 로 두 배가 됐다.**
#   상수를 그대로 뒀다면 검사기는 **머리가 천장에 박히는 자리를 "설 수 있다"** 고
#   보고했을 것이다. 사람 눈으로는 절대 못 잡는 종류의 오류다.
#   → 씬에서 직접 재서 쓴다. 캐릭터를 또 바꿔도 검사기가 저절로 따라온다.
# ============================================================================
var _플레이어_높이 := 97.0
var _플레이어_폭 := 44.0

func _플레이어_크기_재기() -> void:
	var p := _루트.get_node_or_null("Player") as Node2D
	if p == null:
		return
	var cs := p.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null:
		return
	var 배율: Vector2 = p.scale
	if cs.shape is RectangleShape2D:
		var r := (cs.shape as RectangleShape2D).size
		_플레이어_높이 = absf(r.y * 배율.y)
		_플레이어_폭 = absf(r.x * 배율.x)
	elif cs.shape is CapsuleShape2D:
		var c := cs.shape as CapsuleShape2D
		_플레이어_높이 = absf(c.height * 배율.y)
		_플레이어_폭 = absf(c.radius * 2.0 * 배율.x)
	print("  플레이어 실측 — 키 %.0fpx · 폭 %.0fpx" % [_플레이어_높이, _플레이어_폭])
