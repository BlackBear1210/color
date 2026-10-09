extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 새 쳅터1 스테이지·기믹 엔진 시험
##   16 썩은 마루 복도(부서지는판) · 17 응접실(레버 퍼즐 · 샹들리에 · 비추기 · 양초 시계 · 잠긴 문) ·
##   18 숨은 서재(주인 있는 열쇠 조각 · 그을음 · 촛불 안전지대) · 13 복도 G(촛불등을 켜면 그을음이 탄다)
## 실행(헤드리스 가능 · 60fps 고정): Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_새스테이지.gd [-- 16 17 18 13]
##   창 모드면 화면도 남긴다: tools/_진단/새스테이지/
## ⚠ user://진행.cfg 는 떠 두고 끝에 되돌린다.
## ============================================================================
const OUT := "res://tools/_진단/새스테이지/"
const 폴더 := "res://scenes/쳅터1/스테이지/"
const 저장 := "user://진행.cfg"

var failures := 0
var _원본 := PackedByteArray()
var _있었나 := false
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


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + label + ".png")


func 열기(이름: String) -> void:
	for c in root.get_children():
		if c.get_node_or_null("Player") != null:
			c.queue_free()
	await process_frame
	_씬 = (load(폴더 + 이름 + ".tscn") as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_죽음 = 0
	_씬.connect("사망함", func(): _죽음 += 1)
	await wait(30)


func 놓기(위치: Vector2, 색: int = ColorDefs.BLACK) -> void:
	_p.global_position = 위치
	_p.velocity = Vector2.ZERO
	_p.set("player_color", 색)


func E() -> void:
	# 월드._unhandled_input 이 받도록 진짜 입력 이벤트로 — "상호작용" 그룹 경로까지 시험한다
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(2)
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)
	await wait(1)


func 진행_비우기() -> void:
	_있었나 = FileAccess.file_exists(저장)
	if _있었나:
		_원본 = FileAccess.get_file_as_bytes(저장)
	var cfg := ConfigFile.new()
	cfg.load(저장)
	if cfg.has_section("열쇠"):
		for k in cfg.get_section_keys("열쇠"):
			if String(k).contains("쳅터1_17_응접실"):
				cfg.erase_section_key("열쇠", k)
	cfg.save(저장)
	게임진행._cfg = null


func 진행_복원() -> void:
	if _있었나:
		var f := FileAccess.open(저장, FileAccess.WRITE)
		f.store_buffer(_원본)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(저장))
	게임진행._cfg = null


func run() -> void:
	root.size = Vector2i(1920, 1080)
	var 고른: Array = Array(OS.get_cmdline_user_args())
	진행_비우기()
	if 고른.is_empty() or 고른.has("16"):
		await 시험16()
	if 고른.is_empty() or 고른.has("17"):
		await 시험17()
	if 고른.is_empty() or 고른.has("18"):
		await 시험18()
	if 고른.is_empty() or 고른.has("13"):
		await 시험13()
	진행_복원()
	print("\n시험_새스테이지: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)


# ── 16 썩은 마루 복도 ─────────────────────────────────────────────────────────
func 시험16() -> void:
	print("\n== 16 썩은 마루 복도")
	await 열기("쳅터1_16_복도_썩은마루")
	var 판들 := get_nodes_in_group("붕괴발판").filter(func(n): return _씬.is_ancestor_of(n))
	check(판들.size() == 7, "부서지는판 7 장(1+1+1+1+3)")
	var 첫 := 판들[0] as Node2D
	# ① 그냥 걸어서 지나간다 → 등 뒤에서 무너진다 · 플레이어는 산다
	놓기(첫.global_position + Vector2(-260, -4))
	await wait(10)
	_p.set("자동_걷기", 1.0)
	var 지남 := -1
	for f in 120:
		await wait(1)
		if 지남 < 0 and _p.global_position.x > 첫.global_position.x + 70:
			지남 = f
		if f == 18:
			await shot("16_1_판_건너는중")
		if bool(첫.call("부서졌나")):
			break
	_p.set("자동_걷기", 0.0)
	check(bool(첫.call("부서졌나")) and 지남 >= 0 and _죽음 == 0, "① 걸어서 지나가면 등 뒤에서 무너진다 · 생존")
	await shot("16_2_등뒤_무너짐")
	# ② 판 위에 서 있으면 0.9초 뒤 떨어져 가시에 죽는다 → 부활하면 판이 돌아온다
	var 둘 := 판들[1] as Node2D
	놓기(둘.global_position + Vector2(0, -2))
	var 시작 := -1
	for f in 150:
		await wait(1)
		if 시작 < 0 and int(둘.get("_단계")) >= 1:
			시작 = f
		if _죽음 > 0:
			break
	check(시작 >= 0 and _죽음 >= 1, "② 판 위에 머물면 떨어져 죽는다(%d 프레임에 밟힘)" % 시작)
	await wait(120)
	check(not bool(둘.call("부서졌나")) and not bool(첫.call("부서졌나")), "부활하면 부서진 판 전부 복구")


# ── 17 응접실 ────────────────────────────────────────────────────────────────
func 시험17() -> void:
	print("\n== 17 응접실")
	await 열기("쳅터1_17_응접실")
	var 퍼즐 := _씬.get_node_or_null("추가기믹/레버퍼즐01")
	check(퍼즐 != null, "레버퍼즐 묶음 생성")
	if 퍼즐 == null:
		return
	var 레버들 := [퍼즐.get_node("레버1"), 퍼즐.get_node("레버2"), 퍼즐.get_node("레버3")]
	var 손잡이 := 퍼즐.get_node("손잡이") as Node2D
	var 샹 := 퍼즐.get_node("샹들리에")
	var 책장 := 퍼즐.get_node("비밀문")
	var 양초 := 퍼즐.get_node("양초")
	await shot("17_0_시작")
	# 1) 틀린 패턴(전부 끔) → 손잡이 → 샹들리에가 떨어져 죽는다 → 부활하면 매달리고 레버가 풀린다
	놓기(손잡이.global_position + Vector2(0, -4))
	await wait(10)
	await E()
	check(not bool(샹.call("매달려있나")), "틀린 패턴 → 샹들리에 떨어지기 시작")
	check(bool(레버들[0].get("잠김")), "틀리면 레버가 잠긴다(함정이 움직이는 동안)")
	var 죽음전 := _죽음
	for f in 120:
		await wait(1)
		if f == 30:
			await shot("17_1_샹들리에_예고")
		if _죽음 > 죽음전:
			break
	check(_죽음 > 죽음전, "샹들리에에 맞아 죽는다(색 무관 즉사)")
	await shot("17_2_샹들리에_떨어짐")
	await wait(150)
	check(bool(샹.call("매달려있나")), "부활하면 샹들리에가 다시 매달린다")
	check(not bool(레버들[0].get("잠김")) and not bool(레버들[0].get("켜짐")), "레버가 모두 꺼진 채 풀린다")
	# 2) 맞는 패턴(켬·끔·켬) — 레버마다 그 앞에 서서 E
	var 답 := [true, false, true]
	for i in 3:
		if 답[i]:
			놓기((레버들[i] as Node2D).global_position + Vector2(0, -4))
			await wait(6)
			await E()
	check(bool(레버들[0].get("켜짐")) and not bool(레버들[1].get("켜짐")) and bool(레버들[2].get("켜짐")), "E 로 레버 켬·끔·켬")
	놓기(손잡이.global_position + Vector2(0, -4))
	await wait(6)
	var 카메라 := get_first_node_in_group("주카메라")
	await E()
	var 비췄나 := false
	var 멈췄나 := false
	for f in 200:
		await wait(1)
		if float(카메라.get("_비춤")) > 0.5:
			비췄나 = true
		if not _p.is_physics_processing():
			멈췄나 = true
		if f == 55:
			await shot("17_3_카메라_책장비춤")
		if bool(책장.call("열렸나")) and f > 60 and float(카메라.get("_비춤")) <= 0.01:
			break
	await wait(20)          # 조작은 카메라가 돌아온 직후 풀린다 — 몇 프레임 더 본다
	check(비췄나, "맞으면 카메라가 책장(비밀문)을 비춘다")
	check(멈췄나 and _p.is_physics_processing(), "비추는 동안 조작을 묶었다가 돌려준다")
	check(bool(책장.call("열렸나")), "책장이 옆으로 밀려 길이 열린다")
	check(bool(양초.get("켜짐")), "단 위 양초 시계가 켜진다(30초)")
	await shot("17_4_책장열림")
	# 3) 양초가 다 타면(지나가지 않았으면) 다시 닫히고 퍼즐이 처음으로
	양초.set("_남은", 0.05)
	await wait(100)
	check(not bool(책장.call("열렸나")) and not bool(퍼즐.get("풀었나")), "양초가 다 타면 책장이 닫히고 퍼즐이 처음으로")
	# 4) 잠긴 출구 — 열쇠는 18 에 있다. 조각 둘을 17 주인으로 적어 두면 문이 열린다
	var 문 := _씬.get_node_or_null("추가기믹/잠긴문01")
	check(문 != null, "출구에 잠긴 문")
	var 길 := _씬.get_node("연결/오른쪽") as Node2D
	놓기(길.global_position + Vector2(-300, -4))
	await wait(6)
	_p.set("자동_걷기", 1.0)
	await wait(80)
	_p.set("자동_걷기", 0.0)
	check(_p.global_position.x < 길.global_position.x - 4.0, "열쇠 없으면 출구 문 앞에서 막힌다")


# ── 18 숨은 서재 ─────────────────────────────────────────────────────────────
func 시험18() -> void:
	print("\n== 18 숨은 서재")
	await 열기("쳅터1_18_숨은서재")
	var 조각들 := get_nodes_in_group("반반열쇠_조각").filter(func(n): return _씬.is_ancestor_of(n))
	check(조각들.size() == 2, "열쇠 조각 둘")
	var 관 := _씬.get_node_or_null("반반열쇠")
	check(관 != null and String(관.get("씬경로")).ends_with("쳅터1_17_응접실.tscn"), "조각의 주인 = 17 응접실(저장·HUD 를 17 기준으로)")
	check(_씬.get_node_or_null("페인트HUD/루트/열쇠칸") != null, "숨은 서재에서도 17 열쇠 HUD 칸")
	# 검정 조각을 줍는다 → 17 진행으로 저장
	var 검 = 조각들.filter(func(n): return n.call("쪽_이름") == "왼쪽")[0]
	for i in 4:
		놓기((검 as Node2D).global_position + Vector2(0, 40))
		await wait(1)
	check(게임진행.열쇠_조각_있나("res://scenes/쳅터1/스테이지/쳅터1_17_응접실.tscn", "왼쪽"), "검정 조각 → 17 응접실 진행으로 저장")
	# 그을음 — 착지 자리 촛불(16) 빛 안은 안전 · 빛 밖으로 나가면 깨어나 쫓아온다
	var 그 := get_nodes_in_group("그을음").filter(func(n): return _씬.is_ancestor_of(n))
	check(그.size() == 1, "그을음 하나")
	if 그.is_empty():
		return
	var g := 그[0] as CharacterBody2D
	var 촛불 := _씬.get_node("추가기믹/촛불01") as Node2D
	놓기(촛불.global_position + Vector2(0, -4))
	await wait(30)
	check(String(g.call("상태_이름")) == "잠복", "멀리 촛불 빛 안에 있으면 잠복 그대로")
	# 둥지 가까이(빛 밖)로 → 깨어나 쫓아온다
	놓기(g.global_position + Vector2(-200, -4))
	await wait(50)
	check(String(g.call("상태_이름")) in ["추적", "웅크림", "덮침"], "가까이 가면 0.5초 뒤 깨어나 쫓아온다(%s)" % g.call("상태_이름"))
	await shot("18_1_그을음_추적")
	# 촛불 빛 안으로 달아나면 — 빛 경계 앞에서 멈춘다(안 들어온다) · 플레이어는 산다
	놓기(촛불.global_position + Vector2(40, -4))
	var 죽음전 := _죽음
	await wait(150)
	var 거리 := (g.global_position - 촛불.global_position).length()
	check(_죽음 == 죽음전, "촛불 빛 안은 안전지대(사망 %d)" % (_죽음 - 죽음전))
	check(거리 > 130.0, "그을음은 빛 안으로 들어오지 않는다(촛불까지 %.0fpx)" % 거리)
	await shot("18_2_빛경계_머뭇")


# ── 13 복도 G ────────────────────────────────────────────────────────────────
func 시험13() -> void:
	print("\n== 13 복도 G")
	await 열기("쳅터1_13_복도_G")
	var 그 := get_nodes_in_group("그을음").filter(func(n): return _씬.is_ancestor_of(n))
	check(그.size() == 1, "그을음 하나(첫 구덩이 건너 둥지)")
	if 그.is_empty():
		return
	var g := 그[0] as CharacterBody2D
	# 구덩이 건넌 자리에서 촛불등(체크 96)으로 걸어간다 → 둥지(99)의 그을음이 깨어나 마주 온다 → 촛불등을 켜면 빛 안의 그을음이 탄다
	놓기(Vector2(86.5 * 32, 31 * 32 - 2))
	await wait(10)
	check(String(g.call("상태_이름")) == "잠복", "멀리서는 잠복(둥지 99)")
	_p.set("자동_걷기", 1.0)
	var 탔나 := false
	for f in 160:
		await wait(1)
		if _p.global_position.x > 96.5 * 32 - 4:
			_p.set("자동_걷기", 0.0)       # 촛불등 앞에 멈춰 선다(안전 착지 → 등이 켜진다)
		if String(g.call("상태_이름")) in ["탐", "재"]:
			탔나 = true
			await shot("13_1_촛불켜자_그을음탐")
			break
	_p.set("자동_걷기", 0.0)
	check(탔나, "촛불등을 켜자 빛 안의 그을음이 탄다(빛으로 태우기)")
	check(_죽음 == 0, "달아나는 동안 생존(사망 %d)" % _죽음)
