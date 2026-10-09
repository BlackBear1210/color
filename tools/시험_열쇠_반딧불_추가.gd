extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 쳅터1 열쇠 스테이지 4곳(04·08·11·14) · 반딧불 3곳(02·10·12) 엔진 시험
##   도형님 10-09: "반딧불 기믹을 다른 스테이지에 가끔 · 열쇠 스테이지를 쳅터1 기존 스테이지 4개 정도에 넣어 난이도를 올리자"
##
## ▣ 열쇠 — 조각마다 '사람이 할 공략'을 진짜 입력(점프·방향키)과 공중 색 전환으로 해 본다(조각에 몸을 갖다 대지 않는다).
##   → 주웠나 · 죽지 않았나 · 바닥에 내렸나. 두 조각을 다 모으면 출구로 걸어가 잠긴 문이 열리는지까지.
## ▣ 반딧불 — ① 시작·체크포인트·길목 도착점이 모든 정지점의 빛 반경 밖인가(되살아나자마자 죽는 고리 방지)
##   ② 그 자리들에 **검정 몸**으로 한 바퀴 동안 서 있어도 안 죽나 ③ 첫 정지점 바로 아래 바닥에선 검정 몸이 정말 죽나(빛이 바닥에 닿나).
##
## ⚠ 진행 파일을 쓰지 않는다(`게임진행.기록_허용 = 0` · 주운 조각은 메모리에만). 도형님 진행.cfg 무수정.
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_열쇠_반딧불_추가.gd
## ============================================================================
const C := 32.0
const 폴더 := "res://scenes/쳅터1/스테이지/"
const 전경전환 := preload("res://scripts/쳅터1/전경전환.gd")

var failures := 0
var _씬: Node = null
var _p: CharacterBody2D = null
var _죽음 := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func 놓기(위치: Vector2, 색: int) -> void:
	_p.global_position = 위치
	_p.velocity = Vector2.ZERO
	_p.set("player_color", 색)


func 손떼기() -> void:
	for a in ["jump", "move_left", "move_right"]:
		Input.action_release(a)


func 열기(이름: String) -> void:
	for c in root.get_children():
		if c.get_node_or_null("Player") != null:
			c.queue_free()
	await process_frame
	await process_frame
	_씬 = (load(폴더 + 이름 + ".tscn") as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_죽음 = 0
	_씬.connect("사망함", func():
		_죽음 += 1
		print("    (사망 @ %s · 칸 %.1f, %.1f · 몸색 %d)" % [_p.global_position, _p.global_position.x / C, _p.global_position.y / C, int(_p.get("player_color"))]))
	await wait(20)


func 조각(쪽: String) -> Node:
	for n in get_nodes_in_group("반반열쇠_조각"):
		if _씬.is_ancestor_of(n) and n.call("쪽_이름") == 쪽 and not n.is_queued_for_deletion():
			return n
	return null


func 문찾기() -> Node:
	for n in get_nodes_in_group("잠긴문"):
		if _씬.is_ancestor_of(n):
			return n
	return null


# ── 열쇠 공략 ─────────────────────────────────────────────────────────────────
## 출발 = [칸 x(실수), 발 밑 바닥 칸 y] · 입력 = [[프레임, "누름"|"뗌", 동작]] · 색바꿈 = [[프레임, 색]]
## 주운뒤 = [k프레임, 색] — 주운 뒤 k프레임에 그 색으로(착지 전 원래 색으로 돌아가기)
func 공략들() -> Array:
	var B := ColorDefs.BLACK
	var W := ColorDefs.WHITE
	return [
		{"씬": "쳅터1_04_복도_B", "쪽": "오른쪽", "설명": "윗 갈래 흰 판 → 검정 판 점프 꼭대기에서 흰 조각(늦게 검정으로)",
			"출발": [116.2, 21], "색": W, "입력": [[0, "누름", "move_right"], [0, "누름", "jump"]], "주운뒤": [4, B]},
		{"씬": "쳅터1_04_복도_B", "쪽": "왼쪽", "설명": "아래 갈래 검정 움직이는 발판을 검정으로 타고 지나가며 줍기", "발판": "장애물/움직이는발판01", "색": B},
		{"씬": "쳅터1_08_복도_D", "쪽": "오른쪽", "설명": "구조 덩어리(61~68)에서 흰 선반으로 뛰어 오르며 흰색 → 선반 위에서 뛰어 줍기",
			"출발": [66.0, 27], "색": B, "입력": [[0, "누름", "move_right"], [0, "누름", "jump"], [40, "뗌", "move_right"], [80, "뗌", "jump"], [90, "누름", "jump"]],
			"색바꿈": [[10, W]]},
		{"씬": "쳅터1_08_복도_D", "쪽": "왼쪽", "설명": "흰 판에서 제자리 높이뛰기 → 공중에서 검정으로 줍고 착지 전 흰색",
			"출발": [112.5, 25], "색": W, "입력": [[0, "누름", "jump"]], "색바꿈": [[14, B]], "주운뒤": [4, W]},
		{"씬": "쳅터1_11_거실", "쪽": "왼쪽", "설명": "왼쪽 샹들리에 길 구조 덩어리 끝에서 오른쪽 위로 뛰어 검정 조각",
			"출발": [75.6, 49], "색": B, "입력": [[0, "누름", "move_right"], [0, "누름", "jump"]],
			"발판비킴": ["장애물/움직이는발판01", 2750.0]},
		{"씬": "쳅터1_11_거실", "쪽": "오른쪽", "설명": "발코니 꼭대기 흰 판에서 흰 몸으로 뛰어 흰 조각",
			"출발": [212.5, 34], "색": W, "입력": [[0, "누름", "jump"]]},
		{"씬": "쳅터1_14_굴뚝", "쪽": "오른쪽", "설명": "검정 판(22~27)에서 흰 판으로 뛰며 일찍 흰색 → 흰 조각",
			"출발": [23.5, 116], "색": B, "입력": [[0, "누름", "move_right"], [0, "누름", "jump"]], "색바꿈": [[8, W]]},
		{"씬": "쳅터1_14_굴뚝", "쪽": "왼쪽", "설명": "흰 판(체크포인트)에서 제자리 높이뛰기 → 공중 검정으로 줍고 착지 전 흰색",
			"출발": [33.0, 64], "색": W, "입력": [[0, "누름", "jump"]], "색바꿈": [[14, B]], "주운뒤": [4, W]},
	]


func 공략(g: Dictionary) -> void:
	var 조 := 조각(g["쪽"])
	if 조 == null:
		check(false, "%s %s 조각 없음" % [g["씬"], g["쪽"]])
		return
	_죽음 = 0
	손떼기()
	if g.has("발판"):
		# 발판이 왼쪽 끝 근처에서 오른쪽으로 갈 때 그 위에 검정 몸으로 올려 둔다
		var 판 := _씬.get_node(g["발판"]) as Node2D
		var 이전 := 판.global_position.x
		for i in 600:
			await wait(1)
			if 판.global_position.x > 이전 and 판.global_position.x < 이전 + 4.0 and 판.global_position.x < 조.global_position.x - 500.0:
				break
			이전 = 판.global_position.x
		var 크기: Vector2 = 판.get("크기")
		놓기(Vector2(판.global_position.x + 크기.x * 0.5, 판.global_position.y - 크기.y * 0.5 - 2.0), g["색"])
		for f in 360:
			await wait(1)
			if bool(조.get("주움")) or _죽음 > 0:
				break
		await wait(10)
		check(bool(조.get("주움")) and _죽음 == 0, "%s · %s → 주움 %s · 사망 %d" % [g["씬"], g["설명"], 조.get("주움"), _죽음])
		return
	if g.has("발판비킴"):
		# 뛰는 길을 움직이는 발판이 막지 않을 때(발판 왼끝이 이 x 보다 오른쪽)까지 기다린다 — 사람도 그렇게 기다린다
		var 판2 := _씬.get_node(g["발판비킴"][0]) as Node2D
		for i in 600:
			if 판2.global_position.x > float(g["발판비킴"][1]):
				break
			await wait(1)
	var 출발: Array = g["출발"]
	놓기(Vector2(float(출발[0]) * C, float(출발[1]) * C - 1.0), g["색"])
	await wait(12)
	var 입력: Array = g.get("입력", [])
	var 색바꿈: Array = g.get("색바꿈", [])
	var 주운뒤: Array = g.get("주운뒤", [])
	var 주운프레임 := -1
	var 내림 := 0
	for f in 260:
		for e in 입력:
			if int(e[0]) == f:
				if e[1] == "누름":
					Input.action_press(e[2])
				else:
					Input.action_release(e[2])
		for e in 색바꿈:
			if int(e[0]) == f:
				_p.set("player_color", e[1])
		await wait(1)
		if 주운프레임 < 0 and bool(조.get("주움")):
			주운프레임 = f
		if not 주운뒤.is_empty() and 주운프레임 >= 0 and f == 주운프레임 + int(주운뒤[0]):
			_p.set("player_color", 주운뒤[1])
		if _죽음 > 0:
			break
		if 주운프레임 >= 0 and f > 20 and _p.is_on_floor():
			내림 += 1
			if 내림 > 8:
				break
	손떼기()
	await wait(10)
	check(주운프레임 >= 0 and _죽음 == 0 and _p.is_on_floor(),
		"%s · %s → 주움 %s(%d f) · 사망 %d · 착지 %s" % [g["씬"], g["설명"], 주운프레임 >= 0, 주운프레임, _죽음, _p.is_on_floor()])


func 문_열기(이름: String) -> void:
	var 문 := 문찾기()
	var hud := _씬.get_node_or_null("페인트HUD/루트/열쇠칸")
	await wait(80)          # HUD 채움 0.4초 + 맞물림 0.6초가 끝나야 '완성'(시험_열쇠 와 같이 기다린다)
	check(hud != null and bool(hud.call("완성됨")), "%s 두 조각 → HUD 완성" % 이름)
	var 길목 := _씬.get_node("연결/오른쪽") as Node2D
	_죽음 = 0
	놓기(길목.global_position + Vector2(-260, -4), ColorDefs.BLACK)
	await wait(10)
	_p.set("자동_걷기", 1.0)
	var 열림 := false
	for f in 240:
		await wait(1)
		if bool(문.get("열림")):
			열림 = true
			break
	_p.set("자동_걷기", 0.0)
	check(열림 and _죽음 == 0, "%s 완성 열쇠로 출구 잠긴 문 열림(사망 %d)" % [이름, _죽음])
	# 문이 열리면 그대로 전환이 시작될 수 있다 — 끝날 때까지 기다려 다음 스테이지 시험과 안 섞이게
	for i in 600:
		await physics_frame
		if not 전경전환.진행중인가():
			break


func 열쇠_시험() -> void:
	var 공략표 := 공략들()
	var 씬들: Array = []
	for g in 공략표:
		if not 씬들.has(g["씬"]):
			씬들.append(g["씬"])
	for 이름 in 씬들:
		print("== 열쇠 ", 이름)
		await 열기(이름)
		var 관 := _씬.get_node_or_null("반반열쇠")
		var 문 := 문찾기()
		check(관 != null, "%s 열쇠 관리자 생성" % 이름)
		check(조각("왼쪽") != null and 조각("오른쪽") != null, "%s 조각 두 개(검정 · 흰)" % 이름)
		check(문 != null and not bool(문.get("열림")), "%s 출구(오른쪽)에 잠긴 문" % 이름)
		check(_씬.get_node_or_null("페인트HUD/루트/열쇠칸") != null, "%s HUD 열쇠 칸" % 이름)
		if 관 == null or 문 == null:
			continue
		# 열쇠 없이 출구로 → 막힌다
		var 길목 := _씬.get_node("연결/오른쪽") as Node2D
		놓기(길목.global_position + Vector2(-260, -4), ColorDefs.BLACK)
		await wait(10)
		_p.set("자동_걷기", 1.0)
		await wait(90)
		_p.set("자동_걷기", 0.0)
		check(not 전경전환.진행중인가() and _p.global_position.x < 길목.global_position.x - 4.0, "%s 열쇠 없음 → 문 앞에서 막힘" % 이름)
		for g in 공략표:
			if g["씬"] == 이름:
				await 공략(g)
		await 문_열기(이름)


# ── 반딧불 ───────────────────────────────────────────────────────────────────
func 반딧불들() -> Array:
	return get_nodes_in_group("광원몹").filter(func(n): return _씬.is_ancestor_of(n) and n.get("멈춤들") != null)


func 정지점들(몹: Node) -> Array:
	var out: Array = []
	var 기준: Vector2 = 몹.get("_기준")
	for m in 몹.get("멈춤들"):
		out.append(기준 + m)
	return out


## 안전해야 하는 자리 — 시작 · 체크포인트 · 길목 도착점(벽 안쪽 면에서 방 안으로 2칸)
func 안전자리들(시작: Vector2) -> Array:
	var out: Array = [["시작", 시작]]
	var 체 := _씬.get_node_or_null("체크포인트")
	if 체:
		for c in 체.get_children():
			out.append([String(c.name), (c as Node2D).global_position])
	var 연 := _씬.get_node_or_null("연결")
	if 연:
		for c in 연.get_children():
			var g := (c as Node2D).global_position
			var 안쪽 := 1.0 if String(c.name).begins_with("왼") else -1.0
			out.append(["도착_" + String(c.name), g + Vector2(안쪽 * 2.0 * C, 0)])
	return out


func 반딧불_시험(이름: String) -> void:
	print("== 반딧불 ", 이름)
	await 열기(이름)
	var 시작 := _p.global_position
	var 몹들 := 반딧불들()
	check(몹들.size() == 1, "%s 반딧불 1마리(%d)" % [이름, 몹들.size()])
	if 몹들.is_empty():
		return
	var 몹: Node = 몹들[0]
	var 반경: float = 몹.get("반경")
	var 점들 := 정지점들(몹)
	# ① 기하: 몸 세 점(발 · 허리 · 머리)이 모든 정지점에서 반경 + 16 밖
	var 자리들 := 안전자리들(시작)
	for 자 in 자리들:
		var 최소 := INF
		for s in 점들:
			for dy in [-8.0, -48.0, -88.0]:
				최소 = minf(최소, (자[1] + Vector2(0, dy)).distance_to(s))
		check(최소 > 반경 + 16.0, "%s %s 은 빛 반경 밖(가장 가까운 거리 %.0f > %.0f)" % [이름, 자[0], 최소, 반경 + 16.0])
	# ③ 첫 정지점 바로 아래 바닥 — 검정 몸이면 정말 죽는가(빛이 바닥에 닿는가)
	var 첫: Vector2 = 점들[0]
	var 바닥 := _바닥_찾기(첫)
	if 바닥 == Vector2.INF:
		check(false, "%s 첫 정지점 아래 바닥 없음" % 이름)
	else:
		_죽음 = 0
		for f in 150:
			놓기(바닥 + Vector2(0, -1), ColorDefs.BLACK)
			await wait(1)
			if _죽음 > 0:
				break
		check(_죽음 > 0, "%s 첫 정지점 아래 검정 몸 → 사망(빛이 바닥까지 닿는다)" % 이름)
		await wait(120)
	# ② 한 바퀴 동안 안전 자리에 검정으로 서 있기
	var 속도: float = 몹.get("속도")
	var 머묾: float = 몹.get("머묾")
	var 바퀴 := 0.0
	for i in 점들.size():
		바퀴 += (점들[i] as Vector2).distance_to(점들[(i + 1) % 점들.size()]) / 속도 + 머묾 + 0.8
	var 프레임 := int(ceil((바퀴 + 2.0) * 60.0))
	for 자 in 자리들:
		_죽음 = 0
		놓기(자[1] + Vector2(0, -2), ColorDefs.BLACK)
		await wait(프레임)
		check(_죽음 == 0, "%s %s 에 검정 몸으로 %.0f초(한 바퀴) 서 있어도 안 죽음" % [이름, 자[0], 프레임 / 60.0])


func _바닥_찾기(위: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(위, 위 + Vector2(0, 1200), 1)
	q.exclude = [_p.get_rid()]
	var r := _p.get_world_2d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else Vector2.INF


func run() -> void:
	게임진행.기록_허용 = 0
	# [10-10] 도형님이 실제로 플레이해 주운 조각·연 문(진행.cfg)이 시험을 흐리지 않게 — 시험 스테이지 열쇠 기록을
	#   **메모리에서만** 지운다(기록_허용 0 이라 파일엔 안 쓴다). 14 를 깬 뒤 돌렸더니 "조각 없음 · 문 열림" 으로 실패했다.
	var cfg: ConfigFile = 게임진행._설정()
	for 이름 in ["쳅터1_04_복도_B", "쳅터1_08_복도_D", "쳅터1_11_거실", "쳅터1_14_굴뚝"]:
		for k in ["#왼쪽", "#오른쪽", "#문"]:
			if cfg.has_section_key("열쇠", 폴더 + 이름 + ".tscn" + k):
				cfg.erase_section_key("열쇠", 폴더 + 이름 + ".tscn" + k)
	root.size = Vector2i(1920, 1080)
	var 고른 := OS.get_cmdline_user_args()
	if 고른.is_empty() or 고른.has("열쇠"):
		await 열쇠_시험()
	if 고른.is_empty() or 고른.has("반딧불"):
		for 이름 in ["쳅터1_02_복도_A", "쳅터1_10_복도_E", "쳅터1_12_복도_F"]:
			await 반딧불_시험(이름)
	print("\n시험_열쇠_반딧불_추가: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
