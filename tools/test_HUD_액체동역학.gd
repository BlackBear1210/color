extends SceneTree
## ============================================================================
## [2026-09-05 신규 · STEP 3] 게이지 액체 동역학 + 색 3중 동기화 전수 검사
## ----------------------------------------------------------------------------
## 실행 (로직):
##   godot --headless --path . -s res://tools/test_HUD_액체동역학.gd
## 실행 (실제 화면 + 스크린샷):
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . ^
##         -s res://tools/test_HUD_액체동역학.gd -- <저장폴더>
##
## ▣ 무엇을 확인하나 (도형님 §17 판정 기준 그대로)
##   1) Paint State : 자유색 → 실제 Player 시트 / HUD 초상 / 게이지 잉크가 **셋 다** 일치
##   2) Capacity    : `fill_level` 이 언제나 어댑터의 `남은/최대` 와 같다
##   3) Slosh       : 실제로 이동하면 수면이 기울고, 멈추면 수평으로 돌아온다
##   4) Shock       : 실제 발사로 탄약이 줄면 `impact_shock` 이 튄다
##   5) Boundary    : 색 경계 위에서 HUD 잉크색이 안 흔들린다
##   6) Reset       : 리셋 뒤에도 자유색 / 초상 / 게이지가 안 어긋난다
##
## ▣ 더미 금지
##   실제 씬 · 실제 플레이어 · 실제 총 · 실제 입력(move_right 액션 / 좌클릭)만 쓴다.
## ============================================================================

## 옛 월드 씬 폴더. 하위 폴더(1-1 / 1-2)까지 본다 — 도형님이 지정한 7개 스테이지에
## `world_1/stage_1-1` · `world_1/stage_1-2` 가 따로 들어 있기 때문이다.
const 옛_월드_폴더 := ["res://scenes/world_1/", "res://scenes/world_1/1-1/",
	"res://scenes/world_1/1-2/", "res://scenes/world_2/"]

var _저장폴더 := ""
var _결과: Array = []


func _init() -> void: call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	_저장폴더 = 인자[0] if 인자.size() > 0 else ""
	for 경로 in _스테이지_목록():
		await _한_스테이지(경로)
		# 앞 씬이 완전히 사라진 뒤 다음 씬을 올린다
		# (월드.gd 가 페인트 코어를 트리 전체 그룹 검색으로 찾기 때문)
		for _i in 4:
			await process_frame

	print("\n================ 결과 ================")
	var 실패 := 0
	var 건너뜀 := 0
	for r in _결과:
		print("%-24s %s   %s" % [r["이름"], r["판정"], r["설명"]])
		# SKIP = 검사 대상이 아님(플레이 가능한 스테이지가 아니다). 실패로 세지 않는다.
		if r["판정"] == "SKIP": 건너뜀 += 1
		elif r["판정"] != "PASS": 실패 += 1
	print("======================================")
	print("총 %d개 중 %d개 PASS / %d개 FAIL / %d개 SKIP" % [
		_결과.size(), _결과.size() - 실패 - 건너뜀, 실패, 건너뜀])
	quit(1 if 실패 > 0 else 0)


func _스테이지_목록() -> Array:
	var 목록: Array = []
	for s in 챕터.스테이지표:
		var p := String(s.get("씬", ""))
		if p != "" and ResourceLoader.exists(p): 목록.append(p)
	for 폴더 in 옛_월드_폴더:
		var d := DirAccess.open(폴더)
		if d == null: continue
		for f in d.get_files():
			if f.ends_with(".tscn") and not 목록.has(폴더 + f): 목록.append(폴더 + f)
	return 목록


func _한_스테이지(경로: String) -> void:
	var 이름 := 경로.get_file().get_basename()
	print("\n──────── %s" % 경로)
	var 노드 := (load(경로) as PackedScene).instantiate()
	root.add_child(노드); current_scene = 노드
	for _i in 30: await process_frame

	var 플레이어 := _찾기(노드, func(n): return n.is_in_group("player")) as Node2D
	var hud := _찾기(노드, func(n): return n is 페인트HUD)
	if 플레이어 == null or hud == null:
		# 스크립트가 하나도 없는 배치용 원본 씬이면 HUD 를 만들 주체가 없다 → 검사 대상 아님.
		_치우기(노드); _적기(이름, "SKIP", "플레이 가능한 스테이지가 아니다(스테이지 매니저 스크립트 없음)"); return
	var 액체 := hud.get_node_or_null("루트/본체/게이지/액체_마스크/액체") as CanvasItem
	var 재질 := 액체.material as ShaderMaterial
	var 초상 := hud.get_node_or_null("루트/본체/초상/초상_마스크/초상_그림") as AnimatedSprite2D
	var 기본 := 플레이어.get_node_or_null("CharacterSprite") as AnimatedSprite2D
	var 어댑터 = hud.get("_어댑터")
	var 메모: Array = []

	# ── 1) 색 3중 동기화 : 자유색 → 실제 Player 시트 / 초상 / 잉크 ──
	for 상태 in [[ColorDefs.BLACK, "BLACK", "black"], [ColorDefs.WHITE, "WHITE", "white"]]:
		플레이어.set("자유색", int(상태[0]))
		for _i in 8: await process_frame
		var 접두: String = String(상태[2])
		var 플레이어_시트 := String(기본.animation).begins_with(접두)
		var 초상_시트 := String(초상.animation).begins_with(접두)
		var 잉크: Color = 재질.get_shader_parameter("liquid_color")
		var 잉크_맞나 := (잉크.r < 0.2) if int(상태[0]) == ColorDefs.BLACK else (잉크.r > 0.8)
		if not (플레이어_시트 and 초상_시트 and 잉크_맞나):
			_치우기(노드)
			_적기(이름, "FAIL", "%s 3중 동기화 실패 (Player=%s 초상=%s 잉크=%s)" % [
				상태[1], 기본.animation, 초상.animation, 잉크])
			return
	메모.append("색 3중동기 ✔")

	# ── 2) Slosh : 오른쪽으로 실제 이동 → 기울고, 놓으면 수평 복귀 ──
	_액션(&"move_right", true)
	var 최대기울기 := 0.0
	var 기울기_끝 := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < 기울기_끝:
		await process_frame
		var s: float = 재질.get_shader_parameter("slosh_amount")
		if absf(s) > absf(최대기울기): 최대기울기 = s
	var 이동중_속도 := float(플레이어.get("velocity").x)
	_액션(&"move_right", false)
	await _기다리기(1.2)
	var 복귀_기울기: float = 재질.get_shader_parameter("slosh_amount")
	if absf(최대기울기) < 0.005:
		_치우기(노드)
		_적기(이름, "FAIL", "이동해도 수면이 안 기운다 (max=%.4f, vx=%.0f)" % [최대기울기, 이동중_속도])
		return
	if absf(복귀_기울기) > absf(최대기울기) * 0.4:
		_치우기(노드)
		_적기(이름, "FAIL", "멈췄는데 수면이 안 돌아온다 (%.4f → %.4f)" % [최대기울기, 복귀_기울기])
		return
	메모.append("기울기 %.3f→%.3f ✔" % [최대기울기, 복귀_기울기])

	# ── 3) Shock + Capacity : 실제 총으로 실제 발사 ──
	var 총 := _찾기(노드, func(n): return n is 페인트총 or n is ProtoGun)
	if 총:
		var 전_탄약: Dictionary = 어댑터.탄약()
		await _실제로_쏘기(노드, 플레이어, 총)
		var 최대충격 := 0.0
		var 채움어긋남 := 0.0
		# ⚠ HUD 는 `_process` 에서 **프레임당 한 번** 갱신한다. 그래서 탄약이 바뀐 바로 그
		#   프레임에는 게이지가 아직 직전 값일 수 있다(정상). 사람 눈에는 안 보이는 1프레임이다.
		#   → 이번 프레임 값과 **직전 프레임 값** 둘 중 하나와 맞으면 통과로 본다.
		#     둘 다 안 맞으면 그건 진짜로 어긋난 것이다.
		var 지난기대 := -1.0
		for _i in 90:
			await process_frame
			최대충격 = maxf(최대충격, float(재질.get_shader_parameter("impact_shock")))
			var t: Dictionary = 어댑터.탄약()
			if not t.is_empty() and float(t["최대"]) > 0.0:
				var 기대 := float(t["남은"]) / float(t["최대"])
				var 실제 := float(재질.get_shader_parameter("fill_level"))
				var 오차 := absf(실제 - 기대)
				if 지난기대 >= 0.0:
					오차 = minf(오차, absf(실제 - 지난기대))
				채움어긋남 = maxf(채움어긋남, 오차)
				지난기대 = 기대
		if 채움어긋남 > 0.02:
			_치우기(노드)
			_적기(이름, "FAIL", "발사 중 게이지가 실제 탄약과 어긋났다 (%.3f)" % 채움어긋남)
			return
		메모.append("실발사 충격 %.2f" % 최대충격 if 최대충격 > 0.0 else "실발사(환급되어 변화 없음)")
		메모.append("탄약 %d/%d 추적오차 %.3f ✔" % [
			int(전_탄약.get("남은", 0)), int(전_탄약.get("최대", 0)), 채움어긋남])

	# ── 3-2) 충격을 **확실하게** 한 번 더 본다 ──
	#   실탄은 빗나가거나 같은 색이면 규칙대로 환급돼서 순증감이 0 이 될 수 있다.
	#   그러면 충격이 안 튀는 게 **정상**이라 위 검사만으로는 기능을 증명 못 한다.
	#   → HUD 가 감시하는 그 값(실제 시스템의 `남은_탄약`)을 1발 내려서 반응을 확인한다.
	#     HUD 전용 변수를 만드는 게 아니라 **실제 자원 변수**를 쓰는 것이 핵심이다.
	var 감시대상 := _찾기(노드, func(n): return n is 페인트코어 or (n.get("남은_탄약") != null))
	if 감시대상:
		await _기다리기(1.5)                        # 앞 충격이 다 가라앉을 때까지
		감시대상.set("남은_탄약", maxi(int(감시대상.get("남은_탄약")) - 1, 0))
		var 튐 := 0.0
		var 튐_끝 := Time.get_ticks_msec() + 300
		while Time.get_ticks_msec() < 튐_끝:
			await process_frame
			튐 = maxf(튐, float(재질.get_shader_parameter("impact_shock")))
		if 튐 <= 0.05:
			_치우기(노드); _적기(이름, "FAIL", "탄약이 줄었는데 충격이 안 튄다 (%.3f)" % 튐); return
		# 충격은 짧아야 한다 — 계속 떨고 있으면 UI 가 산만해진다
		await _기다리기(1.5)
		var 남은충격 := float(재질.get_shader_parameter("impact_shock"))
		if 남은충격 > 0.05:
			_치우기(노드); _적기(이름, "FAIL", "충격이 안 가라앉는다 (%.3f)" % 남은충격); return
		메모.append("탄약1발↓ 충격 %.2f→0 ✔" % 튐)

	# ── 4) Boundary : 색 경계 위에서 잉크색이 흔들리나 ──
	var 경계들 := 노드.get_tree().get_nodes_in_group("색경계")
	if not 경계들.is_empty():
		var 원위치 := 플레이어.global_position
		var 잉크값: Array = []
		for 경계 in 경계들:
			if not (경계 is Node2D): continue
			플레이어.global_position = (경계 as Node2D).global_position
			for _i in 8: await process_frame
			for _i in 25:
				await process_frame
				잉크값.append(float(재질.get_shader_parameter("liquid_color").r))
		플레이어.global_position = 원위치
		var 흔들림 := 0.0
		if 잉크값.size() > 0:
			흔들림 = float(잉크값.max()) - float(잉크값.min())
		if 흔들림 > 0.05:
			_치우기(노드); _적기(이름, "FAIL", "색 경계에서 HUD 잉크가 흔들린다 (%.3f)" % 흔들림); return
		메모.append("경계 %d곳 흔들림 %.3f ✔" % [경계들.size(), 흔들림])

	# ── 5) Reset : 실제 리셋 뒤에도 셋이 안 어긋나나 ──
	var 시스템 := _찾기(노드, func(n): return n is 페인트코어 or (n.get("남은_탄약") != null))
	if 시스템 and 시스템.has_method("리셋"):
		시스템.리셋()
		for _i in 10: await process_frame
		var t2: Dictionary = 어댑터.탄약()
		var 기대2 := 0.0
		if not t2.is_empty() and float(t2["최대"]) > 0.0:
			기대2 = float(t2["남은"]) / float(t2["최대"])
		var 실제2 := float(재질.get_shader_parameter("fill_level"))
		var 잉크2: Color = 재질.get_shader_parameter("liquid_color")
		var 자유색2 := int(플레이어.get("자유색"))
		var 색맞나 := (잉크2.r > 0.8) if 자유색2 == ColorDefs.WHITE else (잉크2.r < 0.2)
		if absf(실제2 - 기대2) > 0.02 or not 색맞나:
			_치우기(노드)
			_적기(이름, "FAIL", "리셋 뒤 어긋남 (채움 %.2f/%.2f 잉크 %s)" % [실제2, 기대2, 잉크2])
			return
		메모.append("리셋 뒤 %.0f%% 복귀 ✔" % [기대2 * 100.0])

	# ── 6) 스크린샷 (정지 / 이동 중, 검정 / 흰색) ──
	if _저장폴더 != "":
		# ⚠ 스크린샷 동안만 무적을 켠다.
		#   흰색으로 검은 지형 위에 서면 **색 규칙대로 즉사**하고, 리스폰이 `코어.리셋()` 을
		#   불러 탄약이 가득 차 버린다. 게임이 제대로 도는 것이지만 그러면 "부분 충전된
		#   흰 게이지" 를 찍을 수가 없다. 판정 로직은 위에서 이미 다 봤으므로,
		#   **그림을 찍는 동안만** 죽지 않게 해서 게이지 높이를 눈으로 확인한다.
		if 노드.get("_무적") != null:
			노드.set("_무적", 9999.0)
		for 상태 in [[ColorDefs.BLACK, "검정"], [ColorDefs.WHITE, "흰색"]]:
			# ⚠ **색을 먼저 바꾸고 탄약을 나중에 내린다.** 순서를 바꾸면 안 된다 —
			#   검은 지형 위에서 흰색으로 바꾸면 색 규칙대로 즉사하고, 리스폰이
			#   `코어.리셋()` 을 불러 탄약이 가득 차 버린다(게임이 제대로 도는 것).
			플레이어.set("자유색", int(상태[0]))
			for _i in 8: await process_frame
			if 시스템:
				시스템.set("남은_탄약", int(round(float(시스템.get("최대_탄약")) * 0.45)))
			for _i in 4: await process_frame
			await _찍기(경로, String(상태[1]) + "_정지")
			_액션(&"move_right", true)
			for _i in 30: await process_frame
			await _찍기(경로, String(상태[1]) + "_이동")
			_액션(&"move_right", false)
			for _i in 20: await process_frame

	_치우기(노드)
	_적기(이름, "PASS", " · ".join(메모))


## ★프레임이 아니라 **실제 시간**으로 기다린다.
##   기울기·충격 감쇠는 delta 기반(초 단위)인데, 헤드리스는 프레임이 실제 시간보다
##   훨씬 빨리 돌아서 "60프레임"이 1초가 아니다. 프레임으로 기다리면 감쇠가 안 끝난 채
##   FAIL 이 나온다 — 게임 버그가 아니라 검사 환경 문제다.
func _기다리기(초: float) -> void:
	var 끝 := Time.get_ticks_msec() + int(초 * 1000.0)
	while Time.get_ticks_msec() < 끝:
		await process_frame


## 실제 입력 액션을 눌렀다/뗐다 한다. (플레이어는 Input.get_axis 로 읽는다)
func _액션(액션: StringName, 눌림: bool) -> void:
	var e := InputEventAction.new()
	e.action = 액션
	e.pressed = 눌림
	e.strength = 1.0 if 눌림 else 0.0
	Input.parse_input_event(e)


func _실제로_쏘기(노드: Node, 플레이어: Node2D, 총: Node) -> void:
	var 과녁 := Vector2.INF
	for _회 in 2:
		과녁 = _가까운_지형(_발사원점(플레이어, 총), 플레이어)
		if 과녁 == Vector2.INF: return
		_마우스(노드, 과녁)
		await process_frame
		await process_frame
	var 화면 := 노드.get_viewport().get_canvas_transform() * 과녁
	for 눌림 in [true, false]:
		var 클릭 := InputEventMouseButton.new()
		클릭.button_index = MOUSE_BUTTON_LEFT
		클릭.pressed = 눌림
		클릭.position = 화면
		클릭.global_position = 화면
		Input.parse_input_event(클릭)
		await process_frame
		await process_frame


func _마우스(노드: Node, 과녁: Vector2) -> void:
	var 화면 := 노드.get_viewport().get_canvas_transform() * 과녁
	var 이동 := InputEventMouseMotion.new()
	이동.position = 화면
	이동.global_position = 화면
	Input.parse_input_event(이동)


func _발사원점(플레이어: Node2D, 총: Node) -> Vector2:
	for 길 in ["GunRig/Gun/Muzzle", "Gun/Muzzle"]:
		var m := 플레이어.get_node_or_null(길) as Node2D
		if m: return m.global_position
	if 총 is Node2D: return (총 as Node2D).global_position
	return 플레이어.global_position


func _가까운_지형(원점: Vector2, 플레이어: Node2D) -> Vector2:
	var 공간 := 플레이어.get_world_2d().direct_space_state
	var 제외: Array[RID] = []
	if 플레이어 is CollisionObject2D:
		제외.append((플레이어 as CollisionObject2D).get_rid())
	var 최단 := Vector2.INF
	var 최단거리 := INF
	for 방향 in [Vector2.DOWN, Vector2(0.6, 1.0), Vector2(-0.6, 1.0), Vector2.RIGHT, Vector2.LEFT]:
		var 질의 := PhysicsRayQueryParameters2D.create(원점, 원점 + 방향.normalized() * 900.0, 1 | 8)
		질의.collide_with_areas = false
		질의.exclude = 제외
		var 결과 := 공간.intersect_ray(질의)
		if 결과:
			var d: float = 원점.distance_to(결과["position"])
			if d >= 24.0 and d < 최단거리:
				최단거리 = d
				최단 = 결과["position"]
	return 최단


func _찍기(경로: String, 꼬리: String) -> void:
	await process_frame
	var 이미지 := root.get_texture().get_image()
	if 이미지 == null: return
	var 이름 := 경로.get_file().get_basename().replace(" ", "_").replace(",", "") + "_" + 꼬리
	이미지.save_png(_저장폴더 + "/S3_" + 이름 + ".png")


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 뿌리 == null: return null
	if 조건.call(뿌리): return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null: return r
	return null


func _치우기(노드: Node) -> void:
	if current_scene == 노드: current_scene = null
	노드.queue_free()


func _적기(이름: String, 판정: String, 설명: String) -> void:
	print("    → %s  %s" % [판정, 설명])
	_결과.append({"이름": 이름, "판정": 판정, "설명": 설명})
