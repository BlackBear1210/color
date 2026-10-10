extends SceneTree
## 실제 2-8 씬의 몬스터와 투사체로 색 변경·탄약·발사·회수·리스폰을 검증한다.
## 다른 퍼즐 상태가 검사를 방해하지 않게 플레이어와 몬스터 이동만 잠시 정지하며 씬은 저장하지 않는다.
const 탄_S := preload("res://scripts/스마트월드/총알.gd")
const 저장 := "res://docs/visual_review/몬스터_몸색_20261010/"
var 결과: Array[Dictionary] = []
var 씬: Node2D
var 코어: 페인트코어
var 몹: Node2D
var 플레이어: Node2D

func _initialize() -> void:
	call_deferred("검사")

func 확인(이름: String, 성공: bool) -> void:
	결과.append({"name": 이름, "pass": 성공})
	print("MONSTER_CHECK ", "PASS " if 성공 else "FAIL ", 이름)

func 기다림(틱: int) -> void:
	for i in 틱:
		await physics_frame

func 캡처(이름: String) -> void:
	await RenderingServer.frame_post_draw
	var 이미지 := root.get_texture().get_image()
	var 오류 := 이미지.save_png(저장 + 이름 + ".png")
	확인("capture_" + 이름, 오류 == OK)

func 발사(색: int, 장치: bool = false) -> void:
	if not 장치:
		확인("ammo_spend_" + str(색), 코어.발사_소모())
	var 탄 := Area2D.new()
	탄.set_script(탄_S)
	씬.add_child(탄)
	# 실제 빠른 탄을 몸 중앙으로 쏴 한 틱에 64px 몸을 넘기는 상황까지 검사한다.
	탄.call("시작", 몹.global_position + Vector2(-160, -50), Vector2.RIGHT,
		6000.0, 색, 코어, null, 장치, 0.0)
	await 기다림(8)

func 발사색_확인(색: int) -> void:
	플레이어.global_position = 몹.global_position + Vector2(200, 0)
	확인("monster_fire_" + str(색), bool(몹.call("_발사")))
	var 찾음 := false
	for n in 씬.get_children():
		if n.get_script() == 탄_S and bool(n.get("장치발")):
			찾음 = true
			확인("monster_projectile_color_" + str(색), int(n.get("색")) == 색)
			# 다음 탄 검사와 지형 상태가 섞이지 않게 확인한 발은 검사용 씬에서만 지운다.
			n.queue_free()
	확인("monster_projectile_exists_" + str(색), 찾음)
	await 기다림(2)

func 검사() -> void:
	씬 = (load("res://scenes/world_2_클로드/stage_2-8.tscn") as PackedScene).instantiate()
	root.add_child(씬)
	current_scene = 씬
	씬.set_physics_process(false)
	플레이어 = 씬.get_node("Player")
	플레이어.set_physics_process(false)
	플레이어.set("velocity", Vector2.ZERO)
	for n in get_nodes_in_group("몬스터"):
		n.set_physics_process(false)
	코어 = 씬.get_node("페인트코어")
	몹 = 씬.get_node("위험물/사격몬스터_1")
	플레이어.global_position = 몹.global_position + Vector2(-200, 0)
	플레이어.set("player_color", 1)
	var 카메라 := 씬.get_node("카메라") as Camera2D
	카메라.call("setup", 플레이어)
	await 기다림(90)
	# 수정 전후에 같은 실제 게임 카메라·줌·해상도를 유지해 스프라이트 색을 비교한다.
	카메라.set_process(false)
	카메라.set_physics_process(false)
	var 줌 := 카메라.zoom
	var 화면크기 := root.get_visible_rect().size
	확인("initial_black", int(몹.get("색")) == 0)
	await 캡처("before_black")
	await 발사(1)
	확인("black_to_white_real_projectile", int(몹.get("색")) == 1)
	확인("white_contact_safe", not bool(몹.call("반대색인가", 1)))
	확인("black_contact_danger", bool(몹.call("반대색인가", 0)))
	확인("white_sprite", 몹.get_node("그림").sprite_frames == 몹.call("_걷기_프레임", 1))
	확인("ammo_one_used", 코어.남은_탄약 == 코어.최대_탄약 - 1)
	await 캡처("after_white")
	await 발사색_확인(1)
	await 발사(1)
	확인("same_color_refund", 코어.남은_탄약 == 코어.최대_탄약 - 1)
	await 발사(0)
	확인("white_to_black_real_projectile", int(몹.get("색")) == 0)
	await 캡처("after_black")
	await 발사색_확인(0)
	확인("manual_recall", 코어.수동_회수())
	확인("recall_original_color", int(몹.get("색")) == 0)
	확인("recall_ammo_full", 코어.남은_탄약 == 코어.최대_탄약)
	await 발사(1)
	await 발사(0, true)
	확인("device_projectile_passes_monster", int(몹.get("색")) == 1)
	확인("device_does_not_spend_ammo", 코어.남은_탄약 == 코어.최대_탄약 - 1)
	# 직접 색 복원이 아니라 실제 월드 리스폰을 거쳐 코어 리셋 연동을 검사한다.
	await 씬.call("_리스폰")
	확인("respawn_original_color", int(몹.get("색")) == 0)
	확인("respawn_ammo_full", 코어.남은_탄약 == 코어.최대_탄약)
	var 실패 := 0
	for 항목 in 결과:
		if not 항목["pass"]:
			실패 += 1
	var 파일 := FileAccess.open(저장 + "result.json", FileAccess.WRITE)
	파일.store_string(JSON.stringify({"checks": 결과, "failures": 실패,
		"camera_zoom": [줌.x, 줌.y], "resolution": [화면크기.x, 화면크기.y]}, "\t"))
	파일.close()
	print("MONSTER_RESULT checks=", 결과.size(), " failures=", 실패)
	quit(0 if 실패 == 0 else 1)
