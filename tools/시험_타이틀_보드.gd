extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 새 타이틀 · 퍼즐 보드 엔진 시험
##   타이틀 메뉴 · 보드 조각 상태(잠김/빈칸/클리어) · 숨은 조각 발견(점선) · 채워지는 연출 · 길 완료 창 ·
##   조각 눌러 스테이지 들어가기(보드 모드) → 출구로 나가면 클리어 기록 + 다음 스테이지로 이어짐 · 18 열쇠 조건 · 스냅 사진(창 모드).
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_타이틀_보드.gd   (창 모드면 화면: tools/_진단/타이틀보드/)
## ⚠ user://진행.cfg · user://completed_runs.cfg · user://스냅/ 은 떠 두고 끝에 되돌린다.
## ============================================================================
const OUT := "res://tools/_진단/타이틀보드/"
const 보드표 := preload("res://scripts/진행/쳅터1_보드표.gd")
const 진행 := "user://진행.cfg"
const 기록 := "user://completed_runs.cfg"

var failures := 0
var _백업 := {}
var _스냅_있었음 := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func wait(n: int) -> void:
	for i in n:
		await process_frame


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + label + ".png")


func 백업() -> void:
	for p in [진행, 기록]:
		_백업[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	게임진행._cfg = null


func 복원() -> void:
	for p in _백업:
		if _백업[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_백업[p])
			f.close()
	게임진행._cfg = null
	게임진행.보드_모드 = false


func 열기(경로: String) -> Node:
	for c in root.get_children():
		if c is Control or c.get_node_or_null("Player"):
			c.queue_free()
	await wait(2)
	var s := (load(경로) as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	await wait(8)
	return s


func 가짜_기록(씬: String, 초: float, 사망: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(기록)
	var 이번 := {"초": 초, "사망": 사망, "완료시각": "시험"}
	cfg.set_value(씬, "최단시간", 이번)
	cfg.set_value(씬, "최소사망", 이번)
	cfg.set_value(씬, "완료횟수", 1)
	cfg.save(기록)


func run() -> void:
	root.size = Vector2i(1920, 1080)
	백업()
	_스냅_있었음 = FileAccess.file_exists("user://스냅/" + String(보드표.찾기("09")["씬"]) + ".png")
	게임진행.기록_허용 = 1          # 이 시험은 진행 기록을 일부러 본다(저장 파일은 백업 · 복원)

	# ── 1) 타이틀 ────────────────────────────────────────────────────────
	var t := await 열기(게임진행.타이틀_씬)
	var 메뉴 := t.get_node_or_null("화면/메뉴")
	check(메뉴 != null and t.get_node_or_null("화면/로고") != null, "타이틀: 로고 · 메뉴")
	var 이름들 := []
	for b in 메뉴.get_children():
		이름들.append(String(b.name))
	check(이름들 == ["처음부터", "스테이지", "설정", "나가기"], "진행 없을 때 메뉴 %s (이어하기 없음)" % [이름들])
	await wait(80)
	await shot("01_타이틀")

	# ── 2) 빈 진행의 보드 ────────────────────────────────────────────────
	var 보 := await 열기(게임진행.보드_씬)
	var 조각수 := 보.find_children("조각_*", "", true, false).size()
	check(조각수 == 18, "보드: 조각 18(숨은 18 은 아직 없음) · %d" % 조각수)
	check(int(보.get_node("화면/조각_01").get("지금")) == 1 and int(보.get_node("화면/조각_02").get("지금")) == 0, "첫 조각 빈칸 · 둘째 잠김")
	await shot("02_보드_처음")

	# ── 3) 진행을 만들어 다시 연다: 01·02 클리어(기록 · 사진) + 18 발견 ──────────
	for c in [보드표.찾기("01"), 보드표.찾기("02")]:
		게임진행.쳅터1_클리어_기록(보드표.씬경로(c))
		가짜_기록(보드표.씬경로(c), 41.5 + randf() * 30.0, randi_range(0, 6))
	게임진행.방문_기록(보드표.씬경로(보드표.찾기("18")))
	게임진행.마지막_조각 = "02"
	보 = await 열기(게임진행.보드_씬)
	check(보.get_node_or_null("화면/조각_18") != null and int(보.get_node("화면/조각_18").get("지금")) == 1, "18 발견 → 조각이 나타나고(점선 실) 열림")
	check(int(보.get_node("화면/조각_03").get("지금")) == 1, "02 클리어 → 03 열림")
	await wait(30)
	check(float(보.get_node("화면/조각_01").get("채움")) > 0.0, "막 깬 조각이 채워지는 중(01 부터 차례로)")
	await shot("03_채워지는중")
	await wait(240)
	check(float(보.get_node("화면/조각_01").get("채움")) >= 0.999 and float(보.get_node("화면/조각_02").get("도장")) >= 0.999, "채움 · 도장 연출 끝")
	check(게임진행.보드_본("본_" + 보드표.씬경로(보드표.찾기("02"))), "연출은 한 번만(본 기록)")
	await shot("04_보드_클리어둘")

	# ── 4) 2층 길 전부 클리어 → 완료 창 → 확인 → 다시 열면 창 없음 ──────────
	for id in ["03", "16", "04", "05", "06", "07", "08"]:
		게임진행.쳅터1_클리어_기록(보드표.씬경로(보드표.찾기(id)))
		게임진행.보드_봄_기록("본_" + 보드표.씬경로(보드표.찾기(id)))
		가짜_기록(보드표.씬경로(보드표.찾기(id)), 30.0 + randf() * 60.0, randi_range(0, 9))
	보 = await 열기(게임진행.보드_씬)
	await wait(30)
	var 창 := 보.get_node_or_null("화면/길완료창")
	check(창 != null, "2층 길 완료 창이 뜬다")
	await shot("05_길완료창")
	if 창:
		var 확인 := 창.find_children("*", "Button", true, false)[0] as Button
		확인.pressed.emit()
		await wait(5)
		check(보.get_node_or_null("화면/길완료창") == null, "확인 → 창 닫힘")
	보 = await 열기(게임진행.보드_씬)
	await wait(30)
	check(보.get_node_or_null("화면/길완료창") == null, "다시 열어도 창은 한 번만")

	# ── 5) 18 열쇠 조건 ──────────────────────────────────────────────────
	var 경18 := 보드표.씬경로(보드표.찾기("18"))
	var 경17 := 보드표.씬경로(보드표.찾기("17"))
	check(not 보드표.출구인가(경18, "왼쪽"), "18: 열쇠 없이 나가면 클리어 아님")
	게임진행.열쇠_조각_기록(경17, "왼쪽")
	게임진행.열쇠_조각_기록(경17, "오른쪽")
	check(보드표.출구인가(경18, "왼쪽"), "18: 열쇠 두 조각 들고 나가면 클리어")
	check(not 보드표.출구인가(경17, "비밀"), "17 비밀 길목은 출구가 아님")

	# ── 6) 사진 눌러 09 로 → 출구로 나가면 클리어 + 10으로 이어짐 ──────────────
	var 조각09 := 보.get_node("화면/조각_09")
	check(int(조각09.get("지금")) == 1, "08 클리어 → 09 열림")
	조각09.emit_signal("눌림", 조각09)
	var 들어감 := false
	for i in 400:
		await process_frame
		if current_scene and current_scene.scene_file_path == 보드표.씬경로(보드표.찾기("09")):
			들어감 = true
			break
	check(들어감 and not 게임진행.보드_모드, "조각 누름 → 09 로 들어감(자연스럽게 이어지는 플레이)")
	var 전경 = load("res://scripts/쳅터1/전경전환.gd")
	for i in 400:
		await process_frame
		if not 전경.진행중인가():
			break
	await wait(60)
	var 무대 := current_scene
	var 출구 := 무대.get_node("연결/오른쪽")
	전경.연결로_이동(출구, 무대.get_node("Player"))
	var 돌아옴 := false
	for i in 900:
		await process_frame
		if current_scene and current_scene.scene_file_path == 보드표.씬경로(보드표.찾기("10")) and not 전경.진행중인가():
			돌아옴 = true
			break
	check(돌아옴, "09 출구 → 10으로 이어짐(지도 자동 팝업 없음)")
	check(게임진행.쳅터1_클리어함(보드표.씬경로(보드표.찾기("09"))), "09 클리어 기록")
	var cfg := ConfigFile.new()
	cfg.load(기록)
	check(cfg.has_section(보드표.씬경로(보드표.찾기("09"))), "09 시간·사망 기록(실행_기록 · 월드.스테이지_완료)")
	await wait(200)
	await shot("06_자연전환_10")
	# 클리어 도장은 사용자가 선택창을 열었을 때만 나온다.
	보 = await 열기(게임진행.보드_씬)
	await wait(100)
	check(float(보.get_node("화면/조각_09").get("도장")) > 0.99, "직접 선택창을 열면 09 도장 표시")

	# ── 7) 이어하기 ──────────────────────────────────────────────────────
	t = await 열기(게임진행.타이틀_씬)
	check(t.get_node("화면/메뉴").get_child(0).name == "이어하기", "진행이 있으면 첫 메뉴 = 이어하기")
	check(String(보드표.이어할_조각().get("id", "")) == "10", "이어할 조각 = 10(열렸고 아직 안 깸)")

	복원()
	# 이 시험이 만든 스냅 사진(09)도 지운다 — 도형님 보드에 시험 사진이 남지 않게
	var 스냅 := "user://스냅/" + String(보드표.찾기("09")["씬"]) + ".png"
	if not _스냅_있었음 and FileAccess.file_exists(스냅):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(스냅))
	게임진행.기록_허용 = -1
	print("\n시험_타이틀_보드: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
