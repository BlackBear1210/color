extends SceneTree
## ============================================================================
## [2026-10-08 Claude] 신규 기믹 실제 게임 화면 촬영 — 스프링 점프대 · 점프 이펙트(약/강/점프대)
##   (반반 열쇠 · 잠긴 문 · 부서지는 발판은 단계가 생기는 대로 같은 도구에 붙인다)
##
## 실행(창 모드 · 60fps 고정 — 프레임 번호가 시간과 같아진다):
##   Godot_console --path . --fixed-fps 60 -s res://tools/촬영_신규기믹.gd [-- 스프링 점프 ...]
## 결과: tools/_진단/신규기믹/<주제>_<장면>.png (전체 화면) + _확대.png(관심 영역 2배)
##
## 왜 실제 스테이지인가: AGENTS.md "시각 작업 완료 기준" — 같은 스테이지·줌·해상도의 엔진 캡처로 판정한다.
## ============================================================================
const OUT := "res://tools/_진단/신규기믹/"

var _씬: Node = null
var _p: CharacterBody2D = null


func _initialize() -> void:
	call_deferred("run")


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func shot(label: String, 관심_월드: Rect2 = Rect2()) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := root.get_texture().get_image()
	img.save_png(OUT + label + ".png")
	if 관심_월드.size != Vector2.ZERO:
		# 월드 사각형 → 화면 사각형(카메라 변환) → 잘라서 2배로(가까이 보기)
		var xf := root.get_canvas_transform()
		var a := xf * 관심_월드.position
		var b := xf * (관심_월드.position + 관심_월드.size)
		var r := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 4 and r.size.y > 4:
			var 조각 := img.get_region(r)
			조각.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
			조각.save_png(OUT + label + "_확대.png")


func 씬_열기(경로: String) -> void:
	if _씬:
		_씬.queue_free()
		await process_frame
	_씬 = (load(경로) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	await wait(30)


func 첫_도약대() -> Node2D:
	for n in _씬.find_children("*", "Area2D", true, false):
		if n.is_in_group("도약대"):
			return n
	return null


func 놓기(위치: Vector2, 색: int) -> void:
	_p.global_position = 위치
	_p.velocity = Vector2.ZERO
	_p.set("player_color", 색)


func run() -> void:
	root.size = Vector2i(1920, 1080)
	var 고른: Array = Array(OS.get_cmdline_user_args())
	if 고른.is_empty() or 고른.has("스프링"):
		await 스프링("res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn", "집")
		await 스프링("res://scenes/world_2_클로드/stage_2-2.tscn", "하수도")
	if 고른.is_empty() or 고른.has("점프"):
		await 점프이펙트()
	if 고른.is_empty() or 고른.has("열쇠"):
		await 열쇠문()
	if 고른.is_empty() or 고른.has("하수도문"):
		await 하수도문()
	if 고른.is_empty() or 고른.has("지도"):
		await 지도표식()
	if 고른.has("정렬"):
		await 정렬()
	quit(0)


## 도약대 위 300px 에서 떨어뜨려 → 대기 · 눌림 · 튕김 · 솟구침 · 출렁임을 프레임 번호로 찍는다.
func 스프링(경로: String, 이름: String) -> void:
	await 씬_열기(경로)
	var 대 := 첫_도약대()
	if 대 == null:
		print("[촬영] %s: 도약대 없음" % 이름)
		return
	var 위 := 대.global_position
	var 관심 := Rect2(위 + Vector2(-220, -330), Vector2(440, 380))
	# 대기 — 플레이어를 옆으로 치워 두고 판만 본다
	놓기(위 + Vector2(-400, -40), ColorDefs.BLACK)
	await wait(40)
	await shot("스프링_%s_0대기" % 이름, 관심)
	for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
		var 색이름 := "검" if 색 == ColorDefs.BLACK else "흰"
		놓기(위 + Vector2(0, -260), 색)
		# 판에 닿을 때까지 떨어진다 → 닿는 프레임을 잡는다
		var f := 0
		# 튕겨 오르는(속도가 위로 바뀐) 프레임까지 떨어진다
		while f < 120 and _p.velocity.y >= -10.0:
			await wait(1)
			f += 1
		print("[촬영] %s %s: 닿기까지 %d 프레임 · 속도 %.0f · 코일 %.2f" % [이름, 색이름, f, _p.velocity.y, 대.call("코일_길이")])
		await wait(1)
		await shot("스프링_%s_%s_1눌림" % [이름, 색이름], 관심)
		await wait(5)
		await shot("스프링_%s_%s_2튕김" % [이름, 색이름], Rect2(위 + Vector2(-220, -520), Vector2(440, 580)))
		await wait(8)
		await shot("스프링_%s_%s_3솟구침" % [이름, 색이름], Rect2(위 + Vector2(-220, -520), Vector2(440, 580)))
		await wait(10)
		await shot("스프링_%s_%s_4출렁임" % [이름, 색이름], 관심)
		var 최고 := _p.global_position.y
		for i in 90:
			await wait(1)
			최고 = minf(최고, _p.global_position.y)
		print("[촬영] %s %s: 꼭대기 %.0f px 위(판 윗면 기준 %.0f)" % [이름, 색이름, 위.y - 최고, (위.y - 32.0) - 최고])
		# 다음 색 촬영 전에 판에서 비켜 서게 옆으로 치운다
		놓기(위 + Vector2(-400, -40), 색)
		await wait(60)


## 평지에서 약(버튼 3프레임) / 강(끝까지) 점프 — 검정·흰 각각. 이륙 뒤 프레임별로 발 자리를 찍는다.
func 점프이펙트() -> void:
	await 씬_열기("res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn")
	# 체크01(272, 1568) 근처 평지
	var 자리 := Vector2(520, 1560)
	for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
		var 색이름 := "검" if 색 == ColorDefs.BLACK else "흰"
		for 세기 in ["약", "강"]:
			놓기(자리, 색)
			await wait(30)
			var 관심 := Rect2(자리 + Vector2(-120, -200), Vector2(240, 230))
			Input.action_press("jump")
			await wait(1)
			if 세기 == "약":
				await wait(2)
				Input.action_release("jump")
			await wait(3)
			await shot("점프_%s_%s_1" % [색이름, 세기], 관심)
			await wait(6)
			await shot("점프_%s_%s_2" % [색이름, 세기], 관심)
			await wait(5)
			await shot("점프_%s_%s_3" % [색이름, 세기], 관심)
			Input.action_release("jump")
			await wait(60)


## 열쇠 조각 보임(검/흰 몸) · 획득빛 · 잠긴 문 열림 과정을 가까이 찍는다. ⚠ 진행.cfg 를 떠 두고 되돌린다.
func 열쇠문() -> void:
	var 저장 := "user://진행.cfg"
	var 있었나 := FileAccess.file_exists(저장)
	var 원본 := FileAccess.get_file_as_bytes(저장) if 있었나 else PackedByteArray()
	var 경로 := "res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn"
	var cfg := ConfigFile.new()
	cfg.load(저장)
	for 키 in ["#왼쪽", "#오른쪽", "#문"]:
		if cfg.has_section_key("열쇠", 경로 + 키):
			cfg.erase_section_key("열쇠", 경로 + 키)
	cfg.save(저장)
	게임진행._cfg = null
	await 씬_열기(경로)
	var 오 := _씬.get_node("열쇠조각_오른쪽") as Node2D
	var 왼 := _씬.get_node("열쇠조각_왼쪽") as Node2D
	# 흰 조각 — 검정 몸(안 보임) / 흰 몸(보임). 바닥 위 허공이라 몸은 옆에 세운다.
	for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
		놓기(오.global_position + Vector2(-150, 160), 색)
		await wait(25)
		await shot("열쇠_흰조각_%s몸" % ("검" if 색 == ColorDefs.BLACK else "흰"), Rect2(오.global_position + Vector2(-240, -150), Vector2(400, 330)))
	# 검정 조각 — 검정 몸에서 보임
	놓기(Vector2(2280, 700), ColorDefs.BLACK)
	await wait(25)
	await shot("열쇠_검정조각_검몸", Rect2(왼.global_position + Vector2(-260, -120), Vector2(400, 300)))
	# 문 — 두 조각을 저장에 넣고 다시 열어 완성 열쇠로 다가간다
	게임진행.열쇠_조각_기록(경로, "왼쪽")
	게임진행.열쇠_조각_기록(경로, "오른쪽")
	await 씬_열기(경로)
	var 길목 := _씬.get_node("연결/왼쪽위") as Node2D
	var 관심 := Rect2(길목.global_position + Vector2(-140, -260), Vector2(520, 300))
	놓기(길목.global_position + Vector2(420, -4), ColorDefs.BLACK)
	await wait(20)
	await shot("문_0잠김", 관심)
	_p.set("자동_걷기", -1.0)
	var 문 := _씬.get_node("잠긴문_왼쪽위")
	var 시작 := -1
	for f in 150:
		await wait(1)
		if 시작 < 0 and 문.get("_진행중"):
			시작 = f
		if 시작 >= 0 and (f - 시작) in [6, 20, 28, 36, 46, 60]:
			await shot("문_%02d" % (f - 시작), 관심)
		if 시작 >= 0 and f - 시작 > 60:
			break
	_p.set("자동_걷기", 0.0)
	if 있었나:
		var fw := FileAccess.open(저장, FileAccess.WRITE)
		fw.store_buffer(원본)
		fw.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(저장))
	게임진행._cfg = null


## 하수도 주철 격자문 — 2-2 출구통로에 촬영용으로만 붙인다(표에 안 넣는다 · 씬 저장 없음).
##   열쇠 없이 다가가 덜컥 → 화면만 본다(하수도 열쇠 스테이지 지정은 도형님 결정 대기 · 기획 §7-11).
func 하수도문() -> void:
	await 씬_열기("res://scenes/world_2_클로드/stage_2-2.tscn")
	var 길목 := _씬.get_node("출구통로") as Node2D
	var 문 := Node2D.new()
	문.set_script(load("res://scripts/장애물/잠긴문.gd"))
	문.call("붙이기", 길목)
	_씬.add_child(문)
	놓기(길목.global_position + Vector2(-260, -4), ColorDefs.BLACK)
	await wait(20)
	var 관심 := Rect2(길목.global_position + Vector2(-300, -260), Vector2(560, 300))
	await shot("하수도문_0잠김", 관심)
	_p.set("자동_걷기", 1.0)
	await wait(50)
	_p.set("자동_걷기", 0.0)
	await shot("하수도문_1막힘", 관심)


## 쳅터2 지도의 열쇠 표식 — 2-2 를 '열쇠 얻음' 으로 잠깐 적어 두고 지도를 찍은 뒤 진행.cfg 를 되돌린다.
func 지도표식() -> void:
	var 저장 := "user://진행.cfg"
	var 있었나 := FileAccess.file_exists(저장)
	var 원본 := FileAccess.get_file_as_bytes(저장) if 있었나 else PackedByteArray()
	var 경로 := "res://scenes/world_2_클로드/stage_2-2.tscn"
	게임진행._cfg = null
	게임진행.열쇠_조각_기록(경로, "왼쪽")
	게임진행.열쇠_조각_기록(경로, "오른쪽")
	if _씬:
		_씬.queue_free()
		_씬 = null
	var 지도: Node = load("res://scenes/lobby/쳅터2_지도.tscn").instantiate()
	root.add_child(지도)
	current_scene = 지도
	await wait(30)
	await shot("지도_열쇠표식")
	지도.queue_free()
	if 있었나:
		var fw := FileAccess.open(저장, FileAccess.WRITE)
		fw.store_buffer(원본)
		fw.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(저장))
	게임진행._cfg = null


## 소품이 목재 윗면(2.5D 상판) 어디에 서 있는지 — 충돌선(빨강)·발 그림 깊이 +7(초록)을 그어 4배로 찍는다.
func 정렬() -> void:
	await 씬_열기("res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn")
	var 대 := 첫_도약대()
	var 촛불 := _씬.get_node("체크포인트/체크03") as Node2D
	놓기(Vector2(3050, 1560), ColorDefs.BLACK)
	var 선 := Node2D.new()
	선.z_index = 200
	_씬.add_child(선)
	선.draw.connect(func():
		for x0 in [대.global_position.x - 140.0, 촛불.global_position.x - 80.0]:
			선.draw_line(Vector2(x0, 1568), Vector2(x0 + 280, 1568), Color(1, 0, 0, 0.8), 1.0)
			선.draw_line(Vector2(x0, 1575), Vector2(x0 + 280, 1575), Color(0, 1, 0, 0.8), 1.0))
	선.queue_redraw()
	await wait(30)
	await shot("정렬_도약대", Rect2(대.global_position + Vector2(-120, -110), Vector2(240, 150)))
	await shot("정렬_촛불", Rect2(촛불.global_position + Vector2(-80, -150), Vector2(160, 190)))
