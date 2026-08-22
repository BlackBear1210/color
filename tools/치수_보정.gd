extends SceneTree
## ============================================================================
## [2026-08-07 도형] 장애물 치수 자동 보정기
##   "거리나 플레이어의 크기에 안 맞거나 점프거리" 를 실제 물리로 재서 고친다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/치수_보정.gd -- <씬경로> [--적용]
##     (--적용 이 없으면 **보고만 하고 파일은 안 건드린다** — 먼저 이걸로 확인할 것)
##
## ▣ 왜 필요했나 (실제로 잡힌 문제)
##   `스마트월드_테스트.tscn` 의 첫 구덩이 발판이 지면에서 **152px** 위에 있었다.
##   플레이어 점프 높이는 160px 이라 "이론상 가능"하지만 여유가 8px 뿐이라
##   사실상 못 넘는다. 그리고 그 발판을 못 넘으면 **스테이지 전체가 막힌다**
##   (레벨검사기: 밟는 지형 26 개 중 도달 6 개).
##   눈으로는 절대 안 보인다 — 씬을 열면 발판이 멀쩡히 그려져 있다.
##
## ▣ 어떻게 고치나
##   1. 씬을 진짜로 띄우고 물리로 지형 표면을 훑는다 (레벨검사기와 같은 방식)
##   2. 시작 지점에서 도달 가능한 곳을 넓혀 나간다
##   3. **못 닿는 유령 발판**을 찾아, 가장 가까운 도달 가능 지형에서
##      `점프 높이 × 0.80` 안에 들어오도록 **아래로 내린다**
##   4. 1~3 을 반복한다 (하나를 내리면 다음 발판이 닿게 되므로 연쇄로 풀린다)
##
## ▣ 안전장치 — 자동 보정이 판을 망치지 않게
##   · **유령 발판(`무색일때_통과`)만** 건드린다. 바닥·천장·구조물은 절대 안 움직인다.
##   · 한 발판당 최대 `최대_이동` px 까지만 내린다.
##   · 내린 결과가 **다른 지형 속으로 파묻히면** 되돌린다.
##   · `--적용` 없이는 파일을 저장하지 않는다.
##
## ▣ 판정 기준 (플레이어 실제 물리에서 역산 — 하드코딩 아님)
##   올라갈 수 있는 단차 = 점프 높이 × 0.80   (조작 오차 여유 20%)
##   건널 수 있는 거리   = 점프 거리 × 0.85
## ============================================================================

const 표본간격 := 32.0
const 최대층 := 12
const 여유_세로 := 0.80
const 여유_가로 := 0.85
const 묶기_허용높이 := 26.0
## ★한 발판을 자동으로 내릴 수 있는 최대치(px).
##
## [2026-08-07] 처음엔 220 으로 뒀는데, 실제로 돌려 보니 발판_5 를 **216px** 내리려 했다.
## 그 정도면 "치수 보정" 이 아니라 **레벨 디자인을 바꾸는 것**이다
## (수직으로 쌓아 둔 상단 루트가 통째로 사라진다).
## → 자동으로는 **130px 까지만** 손대고, 그보다 큰 건 손대지 않고 **사람에게 보고**한다.
##   130 = 점프 판정선(128) 한 칸 분량. "한 칸 낮추면 되는 정도" 까지만 자동으로 고친다.
const 최대_이동 := 130.0
## 반복 횟수 — 발판이 사슬처럼 이어져 있어도 풀리도록
const 반복 := 6
## 목표 여유(px) — 판정선에 딱 맞추면 또 아슬아슬하다. 이만큼 더 내린다.
const 목표_여유 := 18.0

var _씬경로 := ""
var _적용 := false
var _루트: Node2D = null
var _n := 0

var _점프높이 := 160.0
var _점프거리 := 320.0
var _도약높이 := 0.0
var _치명낙하 := 520.0
var _시작위치 := Vector2.ZERO

var _선반: Array[Dictionary] = []
var _고친것: Array[String] = []
## 자동으로 고치기엔 변경 폭이 큰 것 — 사람이 판단해야 한다
var _사람이_봐야함: Array[String] = []


func _init() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a == "--적용":
			_적용 = true
		elif not a.begins_with("--"):
			_씬경로 = a
	if _씬경로.is_empty():
		print("사용법: -s res://tools/치수_보정.gd -- <씬경로> [--적용]")
		quit(2)
		return
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
		return
	if _n < 5:
		return
	# ⚠ `_돌리기()` 안에 `await` 가 있으므로 **반드시 await 로 불러야 한다.**
	#   그냥 부르면 코루틴만 만들어 놓고 바로 다음 줄 quit(0) 이 실행돼
	#   보정이 한 줄도 안 돌고 프로그램이 끝난다(실제로 겪음 — 출력이 2 줄에서 멈췄다).
	await _돌리기()
	quit(0)


func _돌리기() -> void:
	print("")
	print("════════════════════════════════════════════════")
	print(" 치수 보정 — %s" % _씬경로)
	print("════════════════════════════════════════════════")
	_성능_계측()
	var 판정선 := _점프높이 * 여유_세로
	print("  올라갈 수 있는 단차 한계 = %.0fpx (점프 %.0f × %.2f)"
		% [판정선, _점프높이, 여유_세로])

	for 회차 in 반복:
		_선반.clear()
		var 표면 := _표면_훑기()
		_선반_묶기(표면)
		if _선반.is_empty():
			print("  ⚠ 지형을 못 찾았다 — 콜리전이 안 구워졌을 수 있다")
			return
		var 이웃 := _그래프()
		var 시작 := _시작_선반()
		if 시작 < 0:
			시작 = 0
		var 도달 := _도달집합(이웃, 시작)

		var 고침 := 0
		for i in _선반.size():
			if 도달.has(i):
				continue
			var seg: Dictionary = _선반[i]
			if not seg["유령"]:
				continue                       # ★유령 발판만 건드린다
			var 노드 := _노드_찾기(String(seg["주인"]))
			if 노드 == null:
				continue

			# ── 전략 ① 먼저 "올라갈 길"을 만든다 ────────────────────────
			# ★[2026-08-07] 발판을 내리는 건 최후의 수단이다.
			#   레벨 디자이너가 발판을 높이 둔 데는 이유가 있다(수직 구성·전망·긴장).
			#   무작정 내리면 스테이지가 납작해진다 — 실제로 첫 시도에서
			#   발판_5 가 216px 내려가 수직 루트가 통째로 사라질 뻔했다.
			#   → 점프로는 안 되지만 **도약대(상승 %.0fpx)로는 닿는** 높이라면
			#     발판을 내리는 대신 아래쪽 지형에 도약대를 놓는다.
			var 받침 := _도약대_놓을_자리(seg, 도달, 판정선)
			if 받침 >= 0:
				var 발판_y: float = _선반[받침]["y"]
				var 발판_x: float = clampf((seg["x0"] + seg["x1"]) * 0.5,
					_선반[받침]["x0"] + 40.0, _선반[받침]["x1"] - 40.0)
				if _도약대_설치(Vector2(발판_x, 발판_y - 6.0)):
					_고친것.append("도약대 신설  (%.0f, %.0f)  ← %s 로 올라가는 길"
						% [발판_x, 발판_y, seg["주인"]])
					고침 += 1
					continue

			# ── 전략 ② 그래도 안 되면 발판을 내린다 ─────────────────────
			var 필요 := _필요_하강(seg, 도달, 판정선)
			if 필요 <= 0.0:
				continue
			if 필요 > 최대_이동:
				# ★자동으로 고치기엔 너무 큰 변경 — 레벨 디자인 판단이 필요하다.
				#   조용히 넘기면 "검사 통과했는데 실제로는 못 가는" 최악이 되므로
				#   반드시 사람에게 보고한다.
				var 표기 := "%s  (x %.0f~%.0f, y %.0f)  — %.0fpx 내려야 닿음" \
					% [seg["주인"], seg["x0"], seg["x1"], seg["y"], 필요]
				if not _사람이_봐야함.has(표기):
					_사람이_봐야함.append(표기)
				continue
			var 옛y: float = 노드.position.y
			노드.position.y += 필요
			# 내린 자리가 다른 지형 속이면 되돌린다
			if _파묻혔나(노드):
				노드.position.y = 옛y
				continue
			_고친것.append("%s  y %.0f → %.0f  (%+.0fpx)"
				% [seg["주인"], 옛y, 노드.position.y, 필요])
			고침 += 1
		# ── 전략 ③ 소프트락 해소 — "들어갈 순 있는데 못 나오는 곳" ────────────
		# ★[2026-08-07] 전략 ①②는 **못 가는 곳**만 본다. 그런데 더 고약한 건
		#   **갈 수는 있는데 못 나오는 곳**이다(플레이어가 영영 갇힌다).
		#   실제 사례: 스마트월드1 갱도의 통과플랫폼 — 떨어져 들어가면
		#   지면까지 146px 를 올라야 하는데 한계가 128px 이라 18px 가 모자랐다.
		#   18px 때문에 스테이지를 처음부터 다시 해야 하는 건 말이 안 된다.
		#   → **살짝(≤40px) 올려서** 탈출구를 열어 준다. 그 이상 필요하면 사람에게 보고.
		고침 += _소프트락_풀기(도달, 이웃, 판정선)

		if 고침 == 0:
			break
		# 물리 서버가 새 위치를 반영하도록 한 프레임 흘린다
		await physics_frame
		await physics_frame

	print("")
	if _고친것.is_empty():
		print("  ✔ 손볼 발판 없음 — 모든 유령 발판이 점프 사거리 안에 있다")
	else:
		print("  ▣ 보정한 발판 %d 개" % _고친것.size())
		for s in _고친것:
			print("      %s" % s)

	if not _사람이_봐야함.is_empty():
		print("")
		print("  ⚠ 자동으로 못 고침 — 레벨 디자인 판단이 필요하다 (%d 곳)"
			% _사람이_봐야함.size())
		for s2 in _사람이_봐야함:
			print("      %s" % s2)
		print("      → 발판을 내리거나 / 아래에 도약대·선반을 놓거나 / 그 루트를 없애거나")

	if _적용 and not _고친것.is_empty():
		_저장()
	elif not _고친것.is_empty():
		print("")
		print("  (미리보기만 했다. 실제로 반영하려면 끝에 --적용 을 붙일 것)")
	print("════════════════════════════════════════════════")


## 소프트락(들어가면 못 나오는 곳)을 살짝 올려서 푼다. 고친 개수를 돌려준다.
##
## 판정: 도달 가능한 선반 중 **위로 나가는 이웃이 하나도 없는** 것.
##   (아래로만 갈 수 있는 곳 = 더 깊이 빠지기만 하는 함정)
## 조치: 가장 가까운 "조금만 더 높으면 닿을" 선반 쪽으로 필요한 만큼 **올린다**.
##   올릴 수 있는 한계는 `소프트락_최대올림`. 그 이상은 레벨 디자인 문제다.
## [2026-08-07] 40 으로 뒀더니 갱도 통과플랫폼이 "40px 더 필요" 로 딱 걸려 못 고쳤다.
## 60 이면 "한 뼘 올리는" 수준이라 레벨 의도를 안 해치면서 감옥은 확실히 푼다.
const 소프트락_최대올림 := 60.0

func _소프트락_풀기(도달: Dictionary, 이웃: Array, 판정선: float) -> int:
	# ★판정 기준은 "위로 나가는 이웃이 있나" 가 아니라 **"출구까지 갈 수 있나"** 다.
	#   [2026-08-07] 처음엔 전자로 짰다가 놓쳤다: 갱도의 통과플랫폼과 발판_물아래는
	#   서로가 서로의 "위쪽 이웃"이라(16px 차이) 둘 다 "나갈 길 있음" 으로 통과해 버렸다.
	#   실제로는 둘이서 서로만 오갈 뿐 지면으로는 못 올라간다 = 완벽한 감옥.
	var 목표 := _출구_선반()
	if 목표 < 0:
		return 0
	var 고침 := 0
	for i in 도달.keys():
		var idx := int(i)
		var seg: Dictionary = _선반[idx]
		if _구조물인가(String(seg["주인"])):
			continue
		# 통로 자체는 막다른 게 정상이다(걸어 들어가면 씬이 바뀐다)
		if String(seg["주인"]).ends_with("통로"):
			continue
		if _도달집합(이웃, idx).has(목표):
			continue                                # 출구까지 갈 수 있다 = 문제 없음

		# 조금만 올리면 닿는 후보를 찾는다
		var 최소필요 := 1e20
		for j in _선반.size():
			if j == idx:
				continue
			var 위: Dictionary = _선반[j]
			if 위["y"] >= seg["y"] - 4.0:
				continue                                # 위에 있는 것만
			var 가로 := 0.0
			if 위["x0"] > seg["x1"]:
				가로 = 위["x0"] - seg["x1"]
			elif seg["x0"] > 위["x1"]:
				가로 = seg["x0"] - 위["x1"]
			if 가로 > _점프거리 * 여유_가로:
				continue
			var 올라감: float = seg["y"] - 위["y"]
			if 올라감 <= 판정선:
				continue                                # 이미 닿는다
			최소필요 = minf(최소필요, 올라감 - 판정선 + 6.0)
		if 최소필요 > 1e19:
			continue

		var 노드 := _노드_찾기(String(seg["주인"]))
		if 노드 == null:
			continue
		if 최소필요 > 소프트락_최대올림:
			var 표기 := "%s  (x %.0f~%.0f, y %.0f)  — 갇힘. 나가려면 %.0fpx 더 필요" \
				% [seg["주인"], seg["x0"], seg["x1"], seg["y"], 최소필요]
			if not _사람이_봐야함.has(표기):
				_사람이_봐야함.append(표기)
			continue

		var 옛y: float = 노드.position.y
		노드.position.y -= 최소필요
		if _파묻혔나(노드):
			노드.position.y = 옛y
			continue
		_고친것.append("%s  y %.0f → %.0f  (−%.0fpx · 갇힘 해소)"
			% [seg["주인"], 옛y, 노드.position.y, 최소필요])
		고침 += 1
	return 고침


func _구조물인가(주인: String) -> bool:
	for p in ["천장", "굴뚝벽", "벽"]:
		if 주인.begins_with(p):
			return true
	return false


## 출구 통로 앞 선반 — 소프트락 판정의 목표 지점. (레벨검사.gd 와 같은 규칙)
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
		if _구조물인가(String(seg["주인"])):
			continue
		if 출구위치.x - seg["x1"] > 400.0 or seg["x0"] > 출구위치.x + 100.0:
			continue
		var d: float = absf(seg["y"] - 출구위치.y)
		if d < 최소:
			최소 = d
			최적 = i
	return 최적


## 이 유령 발판으로 올라갈 도약대를 놓을 만한 **도달 가능한 선반**을 찾는다.
## 조건: 가로로 점프 사거리 안이고, 높이 차가 점프로는 안 되지만 도약대로는 되는 범위.
## 없으면 −1.
func _도약대_놓을_자리(seg: Dictionary, 도달: Dictionary, 판정선: float) -> int:
	var 도약 := _도약_상승높이()
	if 도약 <= 판정선:
		return -1
	var 최적 := -1
	var 최소차 := 1e20
	for j in 도달.keys():
		var 기준: Dictionary = _선반[int(j)]
		# 도약대는 발판이 어느 정도 넓어야 놓을 수 있다 (폭 150px)
		if 기준["x1"] - 기준["x0"] < 160.0:
			continue
		if _도약대_있나(기준):
			continue                                  # 이미 있다
		var 가로 := 0.0
		if seg["x0"] > 기준["x1"]:
			가로 = seg["x0"] - 기준["x1"]
		elif 기준["x0"] > seg["x1"]:
			가로 = 기준["x0"] - seg["x1"]
		# 도약대는 수직 상승이라 가로 여유를 점프보다 좁게 본다
		if 가로 > _점프거리 * 0.5:
			continue
		var 올라감: float = 기준["y"] - seg["y"]
		# 점프로 되는 높이면 도약대가 필요 없고, 도약대로도 안 되는 높이면 소용없다
		if 올라감 <= 판정선 or 올라감 > 도약 * 0.92:
			continue
		if 올라감 < 최소차:
			최소차 = 올라감
			최적 = int(j)
	return 최적


## 도약대의 상승 높이(px). 씬에 도약대가 없으면 **기본 세기(−1500)** 로 계산한다.
## (원본 스마트월드 테스트에는 도약대가 하나도 없어서, 씬에서 읽으면 항상 0 이 된다)
func _도약_상승높이() -> float:
	if _도약높이 > 0.0:
		return _도약높이
	var p := _루트.get_node_or_null("Player")
	if p == null:
		return 0.0
	var 상승중력: float = float(p.get("gravity")) * float(p.get("상승_배수"))
	if 상승중력 <= 0.0:
		return 0.0
	const 기본_도약속도 := 1500.0        # 도약대.gd 의 기본값
	return 기본_도약속도 * 기본_도약속도 / (2.0 * 상승중력)


## 도약대 씬을 그 자리에 심는다. 성공하면 true.
## ★씬(`scenes/집/스마트월드_장애물/도약대.tscn`)을 인스턴스한다 —
##   코드로 `.new()` 하면 디자이너가 그림을 꽂을 `그림` 슬롯이 없다.
func _도약대_설치(위치: Vector2) -> bool:
	const 도약대_씬 := "res://scenes/집/스마트월드_장애물/도약대.tscn"
	if not ResourceLoader.exists(도약대_씬):
		push_warning("도약대 씬이 없다: %s" % 도약대_씬)
		return false
	var 부모: Node = _루트.get_node_or_null("오브젝트")
	if 부모 == null:
		부모 = _루트
	var n: Node2D = (load(도약대_씬) as PackedScene).instantiate()
	n.name = "도약대_보정_%d" % 부모.get_child_count()
	n.position = 위치
	부모.add_child(n)
	n.owner = _루트
	return true


## 이 선반이 닿으려면 얼마나 내려가야 하는가. 0 이면 손댈 필요 없음.
func _필요_하강(seg: Dictionary, 도달: Dictionary, 판정선: float) -> float:
	var 최소필요 := 1e20
	for j in 도달.keys():
		var 기준: Dictionary = _선반[int(j)]
		# 가로로 못 닿으면 높이를 낮춰도 소용없다
		var 가로 := 0.0
		if seg["x0"] > 기준["x1"]:
			가로 = seg["x0"] - 기준["x1"]
		elif 기준["x0"] > seg["x1"]:
			가로 = 기준["x0"] - seg["x1"]
		if 가로 > _점프거리 * 여유_가로:
			continue
		var 올라감: float = 기준["y"] - seg["y"]     # 양수면 seg 가 위에 있다
		if 올라감 <= 판정선:
			continue                                 # 이미 닿는다(다른 이유로 못 온 것)
		var 한계 := 판정선
		if _도약대_있나(기준):
			한계 = maxf(한계, _도약높이)
		if 올라감 <= 한계:
			continue
		최소필요 = minf(최소필요, 올라감 - 한계 + 목표_여유)
	return 0.0 if 최소필요 > 1e19 else 최소필요


## 내려간 발판이 다른 지형 속에 파묻혔는지 — 발판 중심이 solid 면 되돌린다.
func _파묻혔나(노드: Node2D) -> bool:
	var 공간 := _루트.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = 노드.global_position
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1                # 유령(8)은 제외 — 자기 자신에 걸리면 안 된다
	return not 공간.intersect_point(q, 1).is_empty()


func _노드_찾기(이름: String) -> Node2D:
	var 대기: Array[Node] = [_루트]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			if c.name == 이름 and c is Node2D:
				return c
			대기.append(c)
	return null


# ============================================================================
# 아래는 레벨검사.gd 와 같은 측정 로직 (같은 답을 내야 하므로 문법을 맞췄다)
# ============================================================================
func _성능_계측() -> void:
	_플레이어_크기_재기()
	var p := _루트.get_node_or_null("Player")
	if p == null:
		return
	var 타일: float = float(p.get("타일_크기"))
	_점프높이 = float(p.get("점프_높이_칸")) * 타일
	_점프거리 = float(p.get("점프_거리_칸")) * 타일
	var 상승중력: float = float(p.get("gravity")) * float(p.get("상승_배수"))
	var 최대속도 := 0.0
	for n in _루트.get_tree().get_nodes_in_group("도약대"):
		최대속도 = maxf(최대속도, absf(float(n.get("도약속도"))))
	if 최대속도 > 0.0 and 상승중력 > 0.0:
		_도약높이 = 최대속도 * 최대속도 / (2.0 * 상승중력)
	_치명낙하 = float(_루트.get("치명_낙하거리"))
	_시작위치 = _루트.get("시작_위치")


func _표면_훑기() -> Array:
	var 리밋: Rect2 = _루트.get("카메라_리밋")
	if 리밋.size.length() < 1.0:
		리밋 = Rect2(-500, -1000, 6000, 4000)
	var 범위 := Rect2(리밋.position.x, 리밋.position.y - 200.0,
		리밋.size.x, 리밋.size.y + 400.0)
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
			var hy: float = r["position"].y
			var 유령 := int(r["collider"].collision_layer) == 8
			var 주인 := _주인이름(r["collider"])
			if 주인 != "Player" and _머리공간(공간, x, hy):
				결과.append([x, hy, 유령, 주인])
			y = hy + 4.0
			var 안전 := 0
			while 안전 < 800 and y < 범위.end.y and _속인가(공간, x, y):
				y += 8.0
				안전 += 1
			y += 2.0
			층 += 1
		x += 표본간격
	return 결과


func _속인가(공간: PhysicsDirectSpaceState2D, x: float, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, y)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return not 공간.intersect_point(q, 1).is_empty()


func _머리공간(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> bool:
	# 플레이어 키 + 여유 8px 만큼 위가 비어 있어야 그 자리에 설 수 있다.
	# 3 지점만 찍는다(발치·중간·머리끝) — 촘촘히 볼수록 느려지는데 이 정도면 충분하다.
	var 키 := _플레이어_높이 + 8.0
	for 비율 in [0.15, 0.55, 1.0]:
		if _속인가(공간, x, 표면y - 키 * 비율):
			return false
	return true


func _주인이름(맞은것: Object) -> String:
	var n := 맞은것 as Node
	if n and (n.name == "천장" or n.name == "뒷벽"):
		return "천장_통로"
	while n != null:
		if n == _루트:
			break
		var 부모 := n.get_parent()
		if 부모 and (부모.name == "지형" or 부모.name == "오브젝트"):
			return n.name
		n = 부모
	return (맞은것 as Node).name if 맞은것 is Node else "?"


func _선반_묶기(표면: Array) -> void:
	var 열: Dictionary = {}
	for s in 표면:
		var kx: float = s[0]
		if not 열.has(kx):
			열[kx] = []
		열[kx].append(s)
	var 열키: Array = 열.keys()
	열키.sort()
	var 진행: Array[Dictionary] = []
	for kx in 열키:
		var 이어짐: Array[Dictionary] = []
		for s in (열[kx] as Array):
			var y: float = s[1]
			var 유령: bool = s[2]
			var 주인: String = s[3]
			var 붙일: Dictionary = {}
			for seg in 진행:
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
	var 걸러진: Array[Dictionary] = []
	for seg in _선반:
		if seg["x1"] - seg["x0"] >= 표본간격 * 0.5:
			걸러진.append(seg)
	_선반 = 걸러진


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


func _그래프() -> Array:
	var 결과: Array = []
	for i in _선반.size():
		var 목록: Array[int] = []
		for j in _선반.size():
			if i != j and _갈수있나(_선반[i], _선반[j], _도약대_있나(_선반[i])):
				목록.append(j)
		결과.append(목록)
	return 결과


func _갈수있나(a: Dictionary, b: Dictionary, a도약: bool) -> bool:
	var 가로 := 0.0
	if b["x0"] > a["x1"]:
		가로 = b["x0"] - a["x1"]
	elif a["x0"] > b["x1"]:
		가로 = a["x0"] - b["x1"]
	if 가로 > _점프거리 * 여유_가로:
		return false
	var 올라감: float = a["y"] - b["y"]
	if 올라감 > 0.0:
		var 한계 := _점프높이 * 여유_세로
		if a도약:
			한계 = maxf(한계, _도약높이)
		return 올라감 <= 한계
	return -올라감 <= _치명낙하


func _도달집합(이웃: Array, 시작: int) -> Dictionary:
	var 본것 := { 시작: true }
	var 큐: Array[int] = [시작]
	while not 큐.is_empty():
		var cur: int = 큐.pop_front()
		for nb in (이웃[cur] as Array):
			if not 본것.has(nb):
				본것[nb] = true
				큐.append(nb)
	return 본것


func _시작_선반() -> int:
	var 최적 := -1
	var 최소 := 1e20
	for i in _선반.size():
		var seg: Dictionary = _선반[i]
		if _시작위치.x < seg["x0"] - 60.0 or _시작위치.x > seg["x1"] + 60.0:
			continue
		var d: float = seg["y"] - _시작위치.y
		if d < -40.0:
			continue
		if d < 최소:
			최소 = d
			최적 = i
	return 최적


func _저장() -> void:
	# ★owner 는 손대지 않는다 — 아래 _주인_지정 주석 참고
	var 팩 := PackedScene.new()
	var err := 팩.pack(_루트)
	if err != OK:
		push_error("pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, _씬경로)
	print("")
	print("  [저장] %s → %s" % [error_string(err), _씬경로])


## ★★[2026-08-07 · 씬을 죽이던 버그. 반드시 읽을 것]
##
## 예전에는 저장 전에 `_주인_지정(루트, 루트)` 로 **트리 전체에 owner 를 박았다.**
## 코드로 처음부터 만드는 씬(build_*.gd)에서는 그게 맞다 — 그래야 저장된다.
##
## 그런데 **이미 있는 씬을 읽어서 손보는 도구**(이 파일 같은)에서는 완전히 틀렸다:
##   · PackedScene 에서 불러온 노드는 **이미 owner 가 올바르게 박혀 있다.** 건드릴 필요 없다.
##   · 스마트월드 오브젝트(호퍼·유체·통과플랫폼·송풍기…)는 `_ready()` 에서
##     판정·모양 노드를 **런타임에** 만든다. 얘들은 owner 가 없어야 정상이다.
##     여기에 owner 를 박으면 **씬 파일에 한 벌 더 저장**되고, 다음에 불러올 때
##     `_ready()` 가 또 만들어 **노드가 두 벌**이 된다.
##   · 그 상태로 씬을 교체하면 이미 해제된 짝을 참조해
##     **엔진이 signal 11(세그폴트)로 죽었다.** (통로를 지날 때 실제로 죽었다)
##
## → 규칙: **우리가 새로 만든 노드에만** owner 를 준다. 나머지는 손대지 않는다.
##   (2026-08-02 의 Gun2/Placeholder2 사고와 같은 계열 — 같은 실수를 다시 했다)
func _주인_지정(_노드: Node, _루트인자: Node) -> void:
	pass    # 의도적으로 아무것도 하지 않는다 (위 주석 참고)
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
