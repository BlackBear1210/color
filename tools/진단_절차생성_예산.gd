extends SceneTree
## ============================================================================
## [2026-09-20 신규] 절차 생성 예산 진단 — "이 맵이 자동 생성기의 한계 안에 있나"
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/진단_절차생성_예산.gd -- <씬경로> [<씬경로> ...]
##   (인자가 없으면 대표 대형 스테이지 3 개를 잰다)
##
## ▣ 왜 만들었나
##   1만 px 짜리 맵을 **자동으로 찍어내자**는 이야기가 나왔다(2026-09-20 도형님).
##   그런데 이 저장소의 지형은 TileMap 이 아니라 SS2D 라서, "맵이 크다" 가 곧바로
##   **엔진 한계**와 **게임 규칙 한계**에 걸린다. 눈으로는 절대 안 보이는 것들이다.
##
##     ① 광원 개수 한계 : Godot 4 의 2D 라이트는 **캔버스 아이템 하나당 15~16 개**까지만
##        먹는다(엔진에 하드코딩). SS2D 지형 한 덩어리 = 캔버스 아이템 **하나**다.
##        → 지형을 길게 뽑을수록 그 한 덩어리에 겹치는 광원이 늘어나 어느 순간
##          "특정 지형만 빛을 안 받는" 증상이 난다. 맵 크기가 아니라 **분할**의 문제다.
##     ② 페인트 시드 한계 : `지형.gd 최대_시드 = 24` = 셰이더 MAX_SEEDS.
##        한 지형 노드에 25 번째 얼룩이 생기면 **가장 오래된 얼룩이 조용히 사라진다.**
##        ※ 탄창이 12 발이라 사람이 혼자 쏴서는 잘 안 넘는다. 넘는 경우는
##          **페인트 분사기·호퍼·연결 페인트가 같은 노드를 계속 찍을 때**다.
##          긴 바닥을 노드 하나로 뽑아 두면 그 한 노드가 시드 24 개를 다 쓴다.
##     ③ 탄약 한계 : `필요횟수() = ceil(월드긴변 / 96)`(최대 8) · 탄창 12 발 ·
##        `전체_색칠_최대긴변 = 576`. 생성기가 600 px 짜리 발판을 뽑는 순간
##        그 발판은 **영원히 전체 색칠이 안 되는 벽**이 된다.
##     ④ 매 프레임 그룹 순회 : `월드.gd _사망_판정()` 이 hazard·색레이저 그룹을
##        **맵 전체에 대해** 훑는다. 맵이 커지면 화면 밖 함정까지 매 물리 프레임 돈다.
##
##   이 도구는 위 네 가지를 **씬을 진짜로 띄워서** 숫자로 찍는다. 아무것도 고치지 않는다.
##
## ▣ 판정 기준(권고값 · docs/프롬프트_절차생성_1만px_맵_2026-09-20.md 의 규칙표와 같은 값)
##   ✖ (고쳐야 함) 지형 한 덩어리에 겹치는 광원 > 12 개 — 엔진 한계 15~16 코앞
##   ⚠ (봐야 함)   한 화면(1920)보다 큰 덩어리가 광원을 6 개 이상 물고 있다 → 쪼갤 후보
##   ⚠ (봐야 함)   `전체칠 가능` 인데 긴변 > 576 → 아무리 쏴도 안 굳는 지형
##   ⚠ (봐야 함)   hazard + 색레이저 합계 > 60 개 — 매 물리 프레임 전부 순회한다
##
##   ★외곽 벽·천장·바닥(`meta role = 채움/외곽`)과 `장식_전용` 은 판정에서 뺀다.
##     그건 원래 맵만큼 길고, 플레이어가 칠하지도 밟지도 않는다.
## ============================================================================

## 인자가 없을 때 재는 대표 스테이지(전부 1만 px 급이다).
const 기본대상 := [
	"res://scenes/world_2_클로드/stage_2-4.tscn",   # 9,600 × 4,096
	"res://scenes/world_2_클로드/stage_2-11.tscn",  # 17,664 × 8,704 (저장소 최대)
	"res://scenes/집/스테이지_2_복도계단.tscn",      # 19,600 × 5,400 (집 챕터 최대)
]

# ── 권고 한계 ───────────────────────────────────────────────────────────────
const 한계_지형긴변 := 1920.0   ## 한 화면 폭. 캔버스 아이템 하나가 이보다 크면 경고
const 한계_겹친광원 := 12       ## 엔진 하드 한계 15~16 에 여유를 둔 값
const 한계_발판긴변 := 576.0    ## 지형.gd 의 `전체_색칠_최대긴변` 기본값과 같은 값
const 한계_위험물 := 60         ## 매 물리 프레임 순회하는 hazard + 색레이저 합계

var _대상: Array = []


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_대상.append(a)
	if _대상.is_empty():
		_대상 = 기본대상.duplicate()

	var 나쁜 := 0
	for 경로: String in _대상:
		var 좋은: bool = await _한판(경로)
		if not 좋은:
			나쁜 += 1
	print("")
	print("════════ 전체 결과: %d / %d 예산 안 ════════" % [_대상.size() - 나쁜, _대상.size()])
	quit(0 if 나쁜 == 0 else 1)


func _한판(경로: String) -> bool:
	var ps := load(경로) as PackedScene
	if ps == null:
		print("✗ 씬을 못 읽었다: %s" % 경로)
		return false

	# ── 1. 로드 비용(CPU) — 인스턴스 + SS2D 메시·콜리전 굽기까지 ──────────────
	var t0 := Time.get_ticks_msec()
	var 뿌리 := ps.instantiate()
	var t_인스턴스 := Time.get_ticks_msec() - t0
	root.add_child(뿌리)
	current_scene = 뿌리
	# SS2D 가 메시를 굽고 월드.gd 가 카메라·플레이어를 붙이는 데 몇 프레임 걸린다.
	# 90 프레임(약 1.5 초)을 기다린다. 그래도 점 배열이 비어 있는 노드가 있어서
	# 크기는 **콜리전 폴리곤으로도** 잰다(`_지형_사각()`).
	for _i in 90:
		await process_frame
	var t_준비 := Time.get_ticks_msec() - t0

	# ── 2. "실시간을 유지하나" (맵 전체를 켜 둔 채 물리 60 틱) ───────────────
	#   ▣ 왜 세는 것보다 **먼저** 돌리나 — 광원은 노드가 아니라 `발광체`·`빛기둥` 이
	#     실행 중에 만든다. 씬을 띄우자마자 세면 아직 안 생긴 광원이 있어서 같은 씬인데
	#     겹침이 12 → 13 으로 흔들렸다(2026-09-20 실측: 같은 씬 두 번에 판정이 갈렸다).
	#     물리 60 틱(= 약 1 초)을 먼저 돌려 씬을 안정시킨 뒤에 센다.
	#   ▣ 왜 벽시계를 쓰나 — `Performance.TIME_PHYSICS_PROCESS` 는 헤드리스(그리기 없음)에서
	#     값이 망가진다(1,296 ms/틱 같은 수가 나왔다). 물리 60 틱은 엔진이 실시간에 맞춰
	#     돌리므로 CPU 가 여유로우면 정확히 1,000 ms 다. 크게 넘기면 **60 Hz 를 못 따라간다**.
	#   ⚠ 헤드리스는 그리지 않으므로 GPU(드로우콜·오버드로·광원)는 **여기서 안 나온다.**
	#     GPU 는 사람이 게임을 켜고 봐야 한다(문서 §5 참고).
	var t1 := Time.get_ticks_msec()
	for _i in 60:
		await physics_frame
	var t_물리 := Time.get_ticks_msec() - t1
	var 충돌쌍 := int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	var 활성체 := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))

	# ── 3. 노드 수집 ────────────────────────────────────────────────────────
	var 지형들: Array = []
	var 광원들: Array = []
	_모으기(뿌리, 지형들, 광원들)
	var 노드수 := _센다(뿌리)

	# ── 4. 지형 통계 ────────────────────────────────────────────────────────
	var 점합 := 0
	var 콜점합 := 0
	var 최장긴변 := 0.0
	var 큰덩어리: Array = []       # 긴변 > 한 화면 · **플레이어가 만지는 지형만**
	var 큰발판: Array = []         # "전체칠 가능" 인데 크기 때문에 전체칠이 안 되는 것
	var 사각들: Array[Rect2] = []  # 지형별 월드 AABB (광원 겹침 계산용)
	var 관심: Array[bool] = []     # 위 판정 대상인가(채움·외곽·장식은 뺀다)
	var 못잰것 := 0                # 점 배열도 콜리전도 못 읽은 노드 — 이 수가 크면 결과를 믿지 말 것
	for n in 지형들:
		var r := _지형_사각(n)
		사각들.append(r)
		if r.size.x <= 0.0 and r.size.y <= 0.0:
			못잰것 += 1
		var 긴변: float = maxf(r.size.x, r.size.y)
		최장긴변 = maxf(최장긴변, 긴변)
		# ▣ 무엇을 "문제" 로 볼 것인가 — 여기가 이 도구의 핵심이다.
		#   외곽 벽·천장·바닥 채움은 원래 맵만큼 길다(2-4 의 `외곽_바닥` 은 11,648 px).
		#   그걸 전부 ✖ 로 찍으면 **지금 있는 모든 스테이지가 실패**로 나와서
		#   아무도 이 도구를 안 보게 된다. 그래서 판정 대상을 좁힌다:
		#     · 빌더가 `meta role` 에 "채움"/"외곽" 이라고 적어 둔 것은 뺀다
		#     · `장식_전용`(콜리전 없음) 은 뺀다
		#     · `칠하기_방식 = 안칠해짐`(색 규칙 밖 구조물) 은 뺀다
		#   남는 것 = **플레이어가 밟거나 칠하는 지형**. 여기만 한계가 진짜로 아프다.
		var 역할: String = String(n.get_meta("role", ""))
		var 장식: bool = bool(n.get("장식_전용")) if n.get("장식_전용") != null else false
		var 칠방식: int = int(n.get("칠하기_방식")) if n.get("칠하기_방식") != null else 0
		var 본다: bool = not 장식 and 칠방식 != 2 and 역할 != "채움" and 역할 != "외곽"
		관심.append(본다)

		# 점·정점 수는 **모든 지형**을 센다 — 메시와 물리 비용은 역할과 상관없이 드는 값이다.
		# (판정 대상만 세면 집 챕터처럼 구조물이 많은 씬에서 수가 실제의 1/4 로 나온다)
		# ⚠ `get_point_count()` 는 믿지 않는다 — 0 을 돌려주는 노드가 있어 키 목록을 센다.
		var pa = n.get_point_array()
		if pa != null:
			점합 += (pa.get_all_point_keys() as Array).size()
		var 폴리 := _콜리전(n)
		if 폴리 != null:
			콜점합 += 폴리.polygon.size()

		if not 본다:
			continue
		if 긴변 > 한계_지형긴변:
			큰덩어리.append([String(n.name), 긴변])
		# 전체칠을 허용해 놓고 크기가 한계를 넘으면 **설계 의도와 실제가 다르다** —
		# `전체_색칠_가능()` 이 false 를 돌려주므로 아무리 쏴도 안 굳는다. 사고는 이쪽이다.
		# (`부분칠만` 이라고 적어 둔 것은 의도한 것이므로 조용히 넘어간다)
		if 칠방식 == 0 and 긴변 > 한계_발판긴변:
			큰발판.append([String(n.name), 긴변, int(ceil(긴변 / 96.0))])

	# ── 5. 광원 × 지형 겹침 (엔진의 캔버스 아이템당 라이트 한계) ─────────────
	#   PointLight2D 의 사정거리 = texture_scale × 텍스처 반지름(256/2 = 128).
	#   조명표준.반경() 이 그 규칙으로 값을 넣으므로 여기서 거꾸로 읽어도 된다.
	var 겹침수: Array[int] = []
	겹침수.resize(지형들.size())
	겹침수.fill(0)
	var 그림자광원 := 0
	for L in 광원들:
		var 빛 := L as PointLight2D
		if 빛.shadow_enabled:
			그림자광원 += 1
		var 반경: float = 빛.texture_scale * 128.0 * maxf(absf(빛.global_scale.x), absf(빛.global_scale.y))
		var 자리 := 빛.global_position
		for i in 사각들.size():
			if _원_사각_겹치나(자리, 반경, 사각들[i]):
				겹침수[i] += 1
	var 최대겹침 := 0
	var 최대겹침_이름 := "-"
	var 쪼갤것: Array = []   # 큰 덩어리인데 광원까지 여럿 물고 있는 것 = 진짜 위험
	for i in 겹침수.size():
		if 겹침수[i] > 최대겹침:
			최대겹침 = 겹침수[i]
			최대겹침_이름 = String(지형들[i].name)
		var 긴변: float = maxf(사각들[i].size.x, 사각들[i].size.y)
		if 긴변 > 한계_지형긴변 and 겹침수[i] >= 6:
			쪼갤것.append([String(지형들[i].name), 긴변, 겹침수[i]])

	# ── 6. 매 프레임 순회 대상 ──────────────────────────────────────────────
	var g_hazard := get_nodes_in_group("hazard").size()
	var g_레이저 := get_nodes_in_group("색레이저").size()
	var g_유체 := get_nodes_in_group("유체").size()
	var g_경계 := get_nodes_in_group("빛경계").size()

	# ── 7. 맵 크기 ──────────────────────────────────────────────────────────
	var 리밋: Rect2 = 뿌리.get("카메라_리밋") if 뿌리.get("카메라_리밋") != null else Rect2()
	var 화면수 := (리밋.size.x * 리밋.size.y) / (1920.0 * 1080.0)

	# ── 출력 ────────────────────────────────────────────────────────────────
	print("")
	print("════════════════════════════════════════════════════════════════")
	print(" 절차 생성 예산 — %s" % 경로.get_file())
	print("════════════════════════════════════════════════════════════════")
	print("  맵          : %.0f × %.0f px  (= 화면 %.1f 장)" % [리밋.size.x, 리밋.size.y, 화면수])
	print("  노드        : 전체 %d · 지형(SS2D) %d · 광원 %d (그림자 %d)"
		% [노드수, 지형들.size(), 광원들.size(), 그림자광원])
	print("  지형 점     : 모양 %d 점 · 콜리전 %d 정점  (평균 %.1f / %.1f 점)%s"
		% [점합, 콜점합, float(점합) / maxf(지형들.size(), 1), float(콜점합) / maxf(지형들.size(), 1),
			"" if 못잰것 == 0 else "  ★크기를 못 잰 지형 %d 개(아래 판정에서 빠짐)" % 못잰것])
	print("  로드 비용   : 인스턴스 %d ms · SS2D 메시·콜리전까지 %d ms" % [t_인스턴스, t_준비])
	print("  실시간 유지 : 물리 60틱에 %d ms  (%s · 1000 ms 가 정상)"
		% [t_물리, "여유" if t_물리 < 1200 else "★CPU 가 못 따라간다"])
	print("  물리 부하   : 활성체 %d · 충돌쌍 %d   ※ 그리기(GPU)는 헤드리스라 안 잡힌다"
		% [활성체, 충돌쌍])
	print("  매 프레임   : hazard %d · 색레이저 %d · 유체 %d · 빛경계 %d  (사망판정 순회 %d)"
		% [g_hazard, g_레이저, g_유체, g_경계, g_hazard + g_레이저])
	print("")

	var 나쁨 := 0
	# ── ✖ 진짜 사고: 캔버스 아이템 하나가 엔진의 광원 한계에 다가간다 ──────────
	if 최대겹침 > 한계_겹친광원:
		print("  ✖ 한 지형에 광원이 %d 개 겹친다 (%s) — 엔진 한계 15~16 (하드코딩)"
			% [최대겹침, 최대겹침_이름])
		print("      → 넘는 순간 **그 지형만** 빛을 안 받거나 광원이 깜빡인다. 지형을 쪼개거나")
		print("        광원을 줄인다. 광원 쪽은 `tools/조명_배치.gd` 의 배치표에서 지운다.")
		나쁨 += 1
	else:
		print("  ✔ 한 지형에 겹치는 광원 최대 %d 개 ≤ %d (엔진 한계 15~16)"
			% [최대겹침, 한계_겹친광원])

	# ── ⚠ 쪼갤 후보: 한 화면보다 큰데 광원까지 여럿 물고 있다 ─────────────────
	if not 쪼갤것.is_empty():
		print("  ⚠ 쪼갤 후보 %d 개 — 한 화면보다 큰 덩어리가 광원을 6 개 이상 물고 있다"
			% 쪼갤것.size())
		for e in 쪼갤것.slice(0, 5):
			print("      · %s  긴변 %.0f · 광원 %d" % [e[0], e[1], e[2]])
		print("      → **색 경계나 층 경계에서만** 자른다(가이드라인 §11 \"불필요한 조각 분할 없음\").")
		print("        자를 때 꼭짓점을 공유하면 `검산()` 의 겹침 0 · 틈 0 이 그대로 유지된다.")
	elif not 큰덩어리.is_empty():
		print("  · 참고: 한 화면보다 큰 지형 %d 개(최장 %.0f) — 광원이 적어 지금은 문제 없다"
			% [큰덩어리.size(), 최장긴변])

	if not 큰발판.is_empty():
		print("  ⚠ \"전체칠 가능\" 이라고 해 놓고 크기 때문에 전체칠이 안 되는 지형 %d 개 (긴변 > %.0f)"
			% [큰발판.size(), 한계_발판긴변])
		for e in 큰발판.slice(0, 5):
			print("      · %s  긴변 %.0f → 필요 %d 발(탄창 12)" % [e[0], e[1], mini(int(e[2]), 8)])
		print("      → 아무리 쏴도 안 굳는다(`전체_색칠_가능()` 이 false). 둘 중 하나로 고친다:")
		print("        ① 576 px 이하로 나눈다   ② 의도한 것이면 `칠하기_방식 = 부분칠만` 이라고 적는다")

	if g_hazard + g_레이저 > 한계_위험물:
		print("  ⚠ 매 물리 프레임 순회 대상이 %d 개 (권고 %d) — 화면 밖 함정까지 매 틱 돈다"
			% [g_hazard + g_레이저, 한계_위험물])

	print("")
	print("  %s" % ("판정: 예산 안" if 나쁨 == 0 else "판정: 예산 초과 %d 건" % 나쁨))

	# 다음 씬을 위해 치운다(한 번에 여러 씬을 재므로 반드시 지운다).
	뿌리.queue_free()
	await process_frame
	return 나쁨 == 0


# ── 도우미 ──────────────────────────────────────────────────────────────────
## 지형(스마트지형 계열)과 PointLight2D 를 모은다.
## ⚠ `is 스마트지형` 을 쓰지 않는다 — 헤드리스에서 전역 클래스 등록 순서에 걸린 적이 있다
##   (지형.gd 머리 주석 참고). 대신 **계약(메서드)** 으로 알아본다.
func _모으기(n: Node, 지형들: Array, 광원들: Array) -> void:
	if n is PointLight2D:
		광원들.append(n)
	elif n.has_method("전체_색칠_가능") and n.has_method("get_point_array"):
		지형들.append(n)
	for c in n.get_children():
		_모으기(c, 지형들, 광원들)


func _센다(n: Node) -> int:
	var s := 1
	for c in n.get_children():
		s += _센다(c)
	return s


## 지형 노드의 월드 AABB. 점 배열을 글로벌 변환해서 잰다(축척해서 꽂은 인스턴스가 있다).
## 점 배열이 아직 안 올라왔으면 **콜리전 폴리곤**으로 대신 잰다 — 게임이 실제로 쓰는 모양은
## 어차피 그쪽이고, 이게 있어야 스테이지마다 결과가 흔들리지 않는다.
func _지형_사각(n: Node) -> Rect2:
	var tf: Transform2D = (n as Node2D).global_transform
	var pa = n.get_point_array()
	if pa != null and pa.get_point_count() > 0:
		var 키들: Array = pa.get_all_point_keys()
		var r := Rect2(tf * pa.get_point_position(키들[0]), Vector2.ZERO)
		for k in 키들:
			r = r.expand(tf * pa.get_point_position(k))
		return r
	var 폴리 := _콜리전(n)
	if 폴리 != null and 폴리.polygon.size() > 0:
		var ptf: Transform2D = 폴리.global_transform
		var r2 := Rect2(ptf * 폴리.polygon[0], Vector2.ZERO)
		for p in 폴리.polygon:
			r2 = r2.expand(ptf * p)
		return r2
	return Rect2((n as Node2D).global_position, Vector2.ZERO)


func _콜리전(n: Node) -> CollisionPolygon2D:
	for c in n.get_children():
		if c is CollisionPolygon2D:
			return c
		for g in c.get_children():
			if g is CollisionPolygon2D:
				return g
	return null


## 원(광원 사정거리)과 사각(지형 AABB)이 겹치나 — 사각에서 가장 가까운 점까지의 거리로 본다.
func _원_사각_겹치나(중심: Vector2, 반경: float, r: Rect2) -> bool:
	var 가까운 := Vector2(
		clampf(중심.x, r.position.x, r.end.x),
		clampf(중심.y, r.position.y, r.end.y))
	return 중심.distance_to(가까운) <= 반경
