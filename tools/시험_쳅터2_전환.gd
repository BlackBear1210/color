extends SceneTree
## [2026-10-08 Claude] 쳅터2(하수도) 스테이지 전환을 쳅터1 방식(전경전환)으로 바꾼 것을 실제로 걸어서 확인한다.
##   ① 쳅터1 15 → 하수도 2-1 → 다시 15(같은 인스턴스) → 다시 2-1(같은 인스턴스)
##   ② 2-1 → 2-2 → 2-2 입구로 되돌아가 2-1 출구 통로에서 걸어 나옴
##   ③ 카메라가 통로 굴 속을 비추지 않는다(쳅터1 처럼 화면 끝 = 입구 + 160)
##   ④ 지도 모드: 출구 → 지도(클리어) · 지도 → 2-3 · 2-3 입구로 되돌아가면 지도(클리어 아님) · 입구 없는 2-9
##   화면은 tools/_진단/쳅터2_전환/ 에 남긴다(창 모드에서만). ⚠ user://진행.cfg 는 시작 때 떠 두고 끝에 되돌린다.
const OUT := "res://tools/_진단/쳅터2_전환/"
const 전경전환 := preload("res://scripts/쳅터1/전경전환.gd")
const 집밖 := "res://scenes/쳅터1/스테이지/쳅터1_15_집밖_하수도길.tscn"
var failures := 0
var _저장_원본: PackedByteArray = PackedByteArray()
var _저장_있었나 := false


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


func 통로(씬: Node, 이름: String) -> Node2D:
	return 씬.find_child(이름, true, false) as Node2D


func 방향(n: Node) -> float:
	return float(n.call("방향")) if n.has_method("방향") else float(n.get("방향"))


## 길목/통로 입구 앞(방 쪽 160px)에 세워 그쪽으로 걷게 한다.
func 걸어_들어가기(씬: Node, 길목: Node2D) -> void:
	var p := 씬.get_node("Player") as CharacterBody2D
	var d := 방향(길목)
	p.global_position = 길목.global_position + Vector2(-d * 160.0, -4.0)
	p.velocity = Vector2.ZERO
	p.set("자동_걷기", d)


func 씬_바뀔때까지(옛: Node, 최대: int) -> void:
	for i in 최대:
		await physics_frame
		if current_scene != 옛:
			return


func 전환_끝날때까지(최대: int) -> void:
	for i in 최대:
		await physics_frame
		if not 전경전환.진행중인가():
			return


## 걸어 들어가 다음 씬에 도착하고 전환이 끝날 때까지.
func 넘어가기(씬: Node, 길목: Node2D) -> Node:
	걸어_들어가기(씬, 길목)
	await 씬_바뀔때까지(씬, 360)
	await 전환_끝날때까지(240)
	await wait(4)
	return current_scene


func 걸어나옴_확인(씬: Node, 길목이름: String, 라벨: String) -> void:
	var 길목 := 통로(씬, 길목이름)
	var p := 씬.get_node_or_null("Player") as CharacterBody2D
	if 길목 == null or p == null:
		check(false, 라벨 + " (길목/플레이어 없음)")
		return
	var 안쪽: Vector2 = 길목.call("안쪽_위치")
	check(absf(p.global_position.x - 안쪽.x) < 96.0, "%s (%.0f vs %.0f)" % [라벨, p.global_position.x, 안쪽.x])


func run() -> void:
	root.size = Vector2i(1920, 1080)
	_저장_있었나 = FileAccess.file_exists(게임진행.저장경로)
	if _저장_있었나:
		_저장_원본 = FileAccess.get_file_as_bytes(게임진행.저장경로)
	게임진행.지도_모드 = 0

	# ── ① 쳅터1 15 ↔ 하수도 2-1 왕복 ──
	var s15: Node = load(집밖).instantiate()
	root.add_child(s15)
	current_scene = s15
	await wait(30)
	var 길목15: Node2D = null
	for n in s15.find_children("*", "", true, false):
		if n.is_in_group("연결구") and String(n.get("다음_씬")).ends_with("stage_2-1.tscn"):
			길목15 = n
	check(길목15 != null, "15 의 하수도 길목 찾음")
	var s21 := await 넘어가기(s15, 길목15)
	check(s21.scene_file_path.ends_with("stage_2-1.tscn"), "15 → 2-1")
	걸어나옴_확인(s21, "입구통로", "2-1 입구 통로에서 걸어 나옴")
	var 입구21 := 통로(s21, "입구통로")
	check(bool(입구21.call("열림")), "2-1 입구 통로가 15 로 되돌아가는 길로 열림")
	check(입구21.get_node_or_null("반딧불이") != null, "되돌아가는 입구에도 반딧불이(쳅터1 연결구처럼)")
	await wait(90)
	await shot("01_2-1_입구_도착")
	var 다시15 := await 넘어가기(s21, 입구21)
	check(다시15 == s15, "2-1 → 15 되돌아감(떠날 때 그 인스턴스)")
	걸어나옴_확인(다시15, String(길목15.name), "15 하수도 길목에서 걸어 나옴")
	await wait(60)
	await shot("02_15로_되돌아옴")
	var 다시21 := await 넘어가기(다시15, 길목15)
	check(다시21 == s21, "15 → 2-1 다시(보관된 그 인스턴스)")

	# ── ③ 카메라: 2-1 출구 앞에서 굴 속이 화면에 안 보인다 ──
	var 출구21 := 통로(s21, "출구통로")
	var p21 := s21.get_node("Player") as CharacterBody2D
	p21.global_position = 출구21.global_position + Vector2(-120.0, -4.0)
	p21.velocity = Vector2.ZERO
	p21.set("자동_걷기", 0.0)
	await wait(150)
	var 캠 := s21.get_node("카메라") as Camera2D
	var 화면끝 := 캠.global_position.x + 960.0 / 캠.zoom.x
	var 선 := 출구21.global_position.x + 160.0
	check(화면끝 <= 선 + 4.0, "2-1 출구 앞: 화면 오른쪽 끝 %.0f ≤ 입구+160 %.0f (굴 끝 %.0f 안 보임)" % [화면끝, 선, 출구21.global_position.x + 448.0])
	await shot("03_2-1_출구앞_굴가림")

	# ── ② 2-1 → 2-2 → 2-1(출구 통로로 되돌아옴) ──
	var s22 := await 넘어가기(s21, 출구21)
	check(s22.scene_file_path.ends_with("stage_2-2.tscn"), "2-1 → 2-2")
	걸어나옴_확인(s22, "입구통로", "2-2 입구 통로에서 걸어 나옴")
	await wait(90)
	await shot("04_2-2_도착_줌아웃끝")
	var 뒤21 := await 넘어가기(s22, 통로(s22, "입구통로"))
	check(뒤21 == s21, "2-2 → 2-1 되돌아감(같은 인스턴스)")
	걸어나옴_확인(뒤21, "출구통로", "2-1 출구 통로에서 방 쪽으로 걸어 나옴")
	check(not bool(뒤21.call("_사망_판정")), "되돌아온 뒤 생존")
	await wait(60)
	await shot("05_2-1로_되돌아옴")
	var 앞22 := await 넘어가기(뒤21, 출구21)
	check(앞22 == s22, "2-1 → 2-2 다시(같은 인스턴스)")

	# ── ④ 지도 모드 ──
	게임진행.지도_모드 = 2
	게임진행.마지막_칸 = "2-2"
	var 지도 := await 넘어가기(앞22, 통로(앞22, "출구통로"))
	check(지도.scene_file_path == 게임진행.지도_씬, "지도 모드 출구 → 지도")
	check(게임진행.클리어함("2-2"), "2-2 클리어 기록")
	await shot("06_지도로_돌아옴")
	var 이전_2_3 := 게임진행.클리어함("2-3")
	전경전환.씬으로_들어가기(지도, 게임진행.씬경로(게임진행.칸_찾기("2-3")), "입구통로")
	await 씬_바뀔때까지(지도, 120)
	await 전환_끝날때까지(240)
	var s23 := current_scene
	check(s23.scene_file_path.ends_with("stage_2-3.tscn"), "지도 → 2-3")
	걸어나옴_확인(s23, "입구통로", "2-3 입구 통로에서 걸어 나옴")
	await wait(60)
	await shot("07_지도에서_2-3")
	var 지도2 := await 넘어가기(s23, 통로(s23, "입구통로"))
	check(지도2.scene_file_path == 게임진행.지도_씬, "2-3 입구로 되돌아가면 지도")
	check(게임진행.클리어함("2-3") == 이전_2_3, "되돌아가기는 클리어로 치지 않음")
	전경전환.씬으로_들어가기(지도2, 게임진행.씬경로(게임진행.칸_찾기("2-9")), "입구통로")
	await 씬_바뀔때까지(지도2, 120)
	await 전환_끝날때까지(150)
	check(current_scene.scene_file_path.ends_with("stage_2-9.tscn") and not 전경전환.진행중인가(), "입구 없는 2-9 도 전환이 멈추지 않음")

	print("CHAPTER2 TRANSITION FAILURES ", failures)
	게임진행.지도_모드 = 0
	if _저장_있었나:
		var f := FileAccess.open(게임진행.저장경로, FileAccess.WRITE)
		f.store_buffer(_저장_원본)
		f.close()
	elif FileAccess.file_exists(게임진행.저장경로):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(게임진행.저장경로))
	전경전환.보관_비우기()
	current_scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
