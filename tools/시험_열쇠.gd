extends SceneTree
## ============================================================================
## [2026-10-08 Claude] 반반 열쇠 · 잠긴 문 엔진 시험 — 기획 §4-A · §4-B 규칙을 실제 스테이지(05 침실)에서 확인한다.
##
## 실행(헤드리스 가능 · 60fps 고정):
##   Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_열쇠.gd
## 창 모드로 돌리면 화면도 남긴다: tools/_진단/열쇠/
## ⚠ user://진행.cfg 는 시작 때 떠 두고 끝에 되돌린다(시험이 도형님 진행을 바꾸지 않게).
## ============================================================================
const OUT := "res://tools/_진단/열쇠/"
const 씬경로 := "res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn"
const 전경전환 := preload("res://scripts/쳅터1/전경전환.gd")
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


func 진행_백업() -> void:
	_있었나 = FileAccess.file_exists(저장)
	if _있었나:
		_원본 = FileAccess.get_file_as_bytes(저장)
	# 이 스테이지의 열쇠 기록만 지운 채로 시작(다른 진행은 그대로 둔다)
	var cfg := ConfigFile.new()
	cfg.load(저장)
	for 키 in ["#왼쪽", "#오른쪽", "#문"]:
		if cfg.has_section_key("열쇠", 씬경로 + 키):
			cfg.erase_section_key("열쇠", 씬경로 + 키)
	cfg.save(저장)
	게임진행._cfg = null          # 정적 캐시를 버려 위 파일을 다시 읽게


func 진행_복원() -> void:
	if _있었나:
		var f := FileAccess.open(저장, FileAccess.WRITE)
		f.store_buffer(_원본)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(저장))
	게임진행._cfg = null


func 열기() -> void:
	if _씬:
		_씬.queue_free()
		await process_frame
	_씬 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_씬.connect("사망함", func(): _죽음 += 1)
	await wait(20)


func 놓기(위치: Vector2, 색: int) -> void:
	_p.global_position = 위치
	_p.velocity = Vector2.ZERO
	_p.set("player_color", 색)


func 관리() -> Node:
	return _씬.get_node_or_null("반반열쇠")


## [2026-10-09] 05 의 조각·문은 도안 JSON → 씬 "추가기믹" 묶음에 있다(예전: 관리자 표가 실행 때 만듦). 그룹으로 찾는다.
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


func run() -> void:
	root.size = Vector2i(1920, 1080)
	진행_백업()
	await 열기()
	var 관 := 관리()
	check(관 != null, "05 침실 = 열쇠 스테이지 → 관리자 생성")
	if 관 == null:
		진행_복원()
		quit(1)
		return
	var 왼 := 조각("왼쪽")
	var 오 := 조각("오른쪽")
	var 문 := 문찾기()
	var hud := _씬.get_node_or_null("페인트HUD/루트/열쇠칸")
	check(왼 != null and 오 != null, "조각 두 개 생성(왼쪽 검정 · 오른쪽 흰)")
	check(문 != null, "출구(왼쪽위)에 잠긴 문")
	check(hud != null, "HUD 열쇠 칸(점선) 생성")
	await shot("01_시작_HUD점선")

	# ── 1) 열쇠 없이 문으로 → 막힌다 + HUD 흔들림 ──
	var 길목 := _씬.get_node("연결/왼쪽위") as Node2D
	놓기(길목.global_position + Vector2(260, -4), ColorDefs.BLACK)
	_p.set("자동_걷기", -1.0)
	await wait(90)
	_p.set("자동_걷기", 0.0)
	# 문은 길목 입구 바로 안쪽(통로 쪽)에 선다 → 몸은 문 판(문 가운데 ± 12) 앞에서 멈춰야 한다
	# 문은 길목 입구 바로 안쪽에 서고, 막이는 문의 방 쪽 면 → 몸은 벽 안쪽 면(길목 원점) 앞에서 멈춘다
	check(_p.global_position.x > 길목.global_position.x + 4.0 and not 전경전환.진행중인가(),
		"열쇠 없음 → 문 앞에서 막힌다(몸 x %.0f · 벽 안쪽 면 %.0f)" % [_p.global_position.x, 길목.global_position.x])
	check(float(문.get("_쿨")) > 0.0, "열쇠 없음 → 자물쇠 덜컥 + HUD 흔들림 알림")
	await shot("02_문_잠김_막힘")

	# ── 2) 검정 조각: 흰 몸이면 안 보이고 못 줍는다 → 검정으로 바꾸면 줍는다 ──
	# 허공의 조각과 몸이 겹치게 매 프레임 같은 자리에 다시 세운다(떨어지지 않게 · 물리는 켠 채 — 멈춘 몸은 못 줍는다)
	for i in 12:
		놓기(왼.global_position + Vector2(0, 40), ColorDefs.WHITE)
		await wait(1)
	check(not 왼.get("주움") and float(왼.get("_보임")) < 0.05, "흰 몸 → 검정 조각 안 보임 · 못 줍기")
	for i in 3:
		놓기(왼.global_position + Vector2(0, 40), ColorDefs.BLACK)
		await wait(1)
	check(bool(왼.get("주움")), "검정으로 바꾸자 그 자리에서 줍기(겹친 채 Shift)")
	check(게임진행.열쇠_조각_있나(씬경로, "왼쪽"), "검정 조각 진행 저장")
	await wait(8)
	await shot("03_검정조각_획득빛")
	await wait(40)
	await shot("04_HUD_왼쪽채움")

	# ── 3) 반쪽만 들고 문 → 여전히 막힘 + 빈 반쪽 깜빡 ──
	놓기(길목.global_position + Vector2(260, -4), ColorDefs.BLACK)
	_p.set("자동_걷기", -1.0)
	await wait(70)
	_p.set("자동_걷기", 0.0)
	check(not bool(문.get("열림")), "조각 하나 → 문 안 열림")
	check(float(hud.get("_깜빡_t")) > 0.0, "조각 하나 → HUD 빈 반쪽 깜빡임")
	await wait(4)
	await shot("05_반쪽_빈쪽깜빡")

	# ── 4) 흰 조각 [2026-10-09 옮김]: 윗 회랑 흰 다리(흰판01 · 윗면 512) 위 — 흰 몸으로 다리에 서면 보이고, 뛰면 닿는다 ──
	#   도형님 규칙 "열쇠 근처에는 같은 색 발판" — 같은 색 판 위에서 색을 바꿀 필요 없이 줍는다.
	_죽음 = 0
	놓기(Vector2(오.global_position.x, 508), ColorDefs.WHITE)
	await wait(30)
	check(_p.is_on_floor() and _죽음 == 0, "흰 다리 위에 흰 몸으로 섰다(사망 %d)" % _죽음)
	check(float(오.get("_보임")) > 0.9, "흰 몸 → 흰 조각이 보인다")
	Input.action_press("jump")
	for f in 70:
		await wait(1)
		if bool(오.get("주움")) and _p.is_on_floor():
			break
	Input.action_release("jump")
	await wait(20)
	check(bool(오.get("주움")), "흰 다리에서 뛰어 흰 조각 줍기")
	check(_죽음 == 0, "흰 조각 줍는 동안 생존(사망 %d)" % _죽음)
	await wait(50)
	await shot("06_HUD_맞물림_완성")
	check(bool(hud.call("완성됨")), "두 조각 → HUD 맞물림 완성(실선)")

	# ── 5) 죽어도 조각 유지 ──
	_씬.call("_리스폰")
	await wait(90)
	check(게임진행.열쇠_조각_있나(씬경로, "왼쪽") and 게임진행.열쇠_조각_있나(씬경로, "오른쪽"), "죽어도 주운 조각 유지")

	# ── 6) 완성 열쇠로 문 → 자동으로 열림 → 그대로 걸어 들어가 다음 스테이지 전환 ──
	놓기(길목.global_position + Vector2(300, -4), ColorDefs.BLACK)
	await wait(10)
	_p.set("자동_걷기", -1.0)
	var 열린프레임 := -1
	var 전환 := false
	for f in 240:
		await wait(1)
		if 열린프레임 < 0 and bool(문.get("열림")):
			열린프레임 = f
		if f == 30:
			await shot("07_열쇠_꽂힘")
		if f == 55:
			await shot("08_문_열리는중")
		if 전경전환.진행중인가() or current_scene != _씬:
			전환 = true
			break
	if is_instance_valid(_p):
		_p.set("자동_걷기", 0.0)
	check(열린프레임 >= 0, "완성 열쇠 → 문 자동 열림(%d 프레임)" % 열린프레임)
	check(전환, "열린 문을 지나 연결구 전환 시작")
	check(게임진행.열쇠_문_열림(씬경로), "문 열림 진행 저장")
	# 전환이 끝나 다음 씬으로 넘어가면 여기 씬은 보관된다 — 새로 열어 '이미 연 문' 상태를 본다
	for i in 400:
		await physics_frame
		if not 전경전환.진행중인가():
			break
	await wait(10)
	# 넘어간 씬·보관된 05 를 모두 치우고 05 를 새로 연다(저장된 진행만 보고 만들어지는지).
	#   안 치우면 넘어간 스테이지의 카메라가 화면을 잡아 촬영이 엉뚱한 곳을 찍는다.
	for c in root.get_children():
		if c.get_node_or_null("Player") != null:
			c.queue_free()
	await process_frame
	_씬 = null
	await 열기()
	check(조각("왼쪽") == null and 조각("오른쪽") == null, "다시 들어오면 주운 조각은 없다")
	var 문2 := 문찾기()
	check(문2 != null and bool(문2.get("열림")), "다시 들어오면 문은 열린 채")
	await shot("09_다시들어옴_문열림")

	진행_복원()
	print("\n시험_열쇠: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
