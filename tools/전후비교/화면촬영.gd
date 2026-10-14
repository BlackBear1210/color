extends SceneTree
## [2026-10-14 Claude] 전후비교 ② — F5 에서 닿는 씬을 하나씩 실제로 띄워 (가) 오류를 모으고 (나) 화면을 찍는다.
## 실행은 `python -X utf8 tools/전후비교/전후비교.py` 가 한다.
##   직접: Godot --path . --fixed-fps 60 --resolution 1920x1080 --audio-driver Dummy \
##         -s res://tools/전후비교/화면촬영.gd -- --list=<씬목록.txt> --out=<폴더> [--frames=90] [--no-shot]
##
## 왜: 기능 검사로는 "디자인이 바뀌었다" 를 못 잡는다. 정리 전후에 **같은 프레임 수만큼 돌린 같은 화면** 을 찍어
##   픽셀로 비교한다. `--fixed-fps 60` 이라 delta 가 매번 같아서 셰이더 anim_time·트윈·이동이 같은 자리에 온다.
## ★ 씬 파일은 절대 저장하지 않는다. 시험 실행이라 진행·기록 파일도 안 쓴다(게임진행.기록해도_되나 = 시험이면 거짓).
## ⚠ --headless 로 돌리면 그림이 안 그려진다 → 그때는 --no-shot 으로 오류만 모은다.
##
## ★[2026-10-14] 찍을 때마다 달라지던 두 가지를 고정한다(코드 정리 2 단계 ②)
##   ① 물결 시간 — 연출시계.프레임_시계 를 켜서 실제 시계 대신 "씬을 띄운 뒤 프레임 수" 로 흐르게 한다.
##   ② 마우스 — 얼굴 방향(player.gd)·총 조준(gun.gd)·버튼 강조가 **운영체제의 실제 커서**를 읽는다
##      (Godot 메인 창은 get_global_mouse_position 이 OS 커서를 직접 읽어서 가짜 입력으로는 못 바꾼다).
##      → 촬영하는 동안 매 프레임 커서를 창 안 `마우스_자리` 로 옮긴다. **촬영 중에는 마우스가 그 자리에 묶인다.**
##      SubViewport 안에 띄우면 커서와 떨어지지만 current_scene 을 못 정해서(루트 자식만 가능)
##      창문빛 위치 맞추기·총알 붙이기 등 29 곳이 실제 게임과 다르게 돈다 → 쓰지 않는다.
var 목록: Array = []
var 출력 := ""
var 프레임 := 90
var 찍기 := true
var 격자 := true          # --no-grid 로 끈다 (스테이지 맵 전체 격자 촬영)
var 격자_대기 := 8        # 카메라를 옮긴 뒤 몇 프레임 기다렸다 찍나 (배경 시차·조명이 자리 잡게)
const 마우스_자리 := Vector2(1500, 400)   # 창 안 좌표 — 플레이어 오른쪽 위를 겨누는 자연스러운 자리
var 결과 := {}


func _initialize() -> void:
	var 목록파일 := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--list="):
			목록파일 = a.substr(7)
		elif a.begins_with("--out="):
			출력 = a.substr(6)
		elif a.begins_with("--frames="):
			프레임 = int(a.substr(9))
		elif a == "--no-shot":
			찍기 = false
		elif a == "--no-grid":
			격자 = false
	var f := FileAccess.open(목록파일, FileAccess.READ)
	while not f.eof_reached():
		var 줄 := f.get_line().strip_edges()
		if 줄 != "":
			목록.append(줄)
	DirAccess.make_dir_recursive_absolute(출력)
	# 물결이 실제 시계 대신 프레임 수로 흐르게(씬마다 0 에서 시작 — _한_씬)
	연출시계.프레임_시계 = true
	_돌기.call_deferred()


## 실제 커서를 창 안 한 점으로 — 매 프레임 부른다(촬영 중 사람이 마우스를 움직여도 다음 프레임에 되돌린다).
func _마우스_고정() -> void:
	if 찍기:
		Input.warp_mouse(마우스_자리)


func _돌기() -> void:
	for p in 목록:
		# 오류 로그에서 어느 씬에서 난 오류인지 알 수 있게 구분 줄을 찍는다
		print("=== 씬 ", p)
		결과[p] = await _한_씬(p)
	var f := FileAccess.open(출력.path_join("결과.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(결과, "", true))
	f.close()
	print("화면촬영 끝: ", 결과.size())
	quit()


func _한_씬(p: String) -> String:
	var s = load(p)
	if s == null or not (s is PackedScene) or not s.can_instantiate():
		return "불러오기 실패"
	# 매 씬 같은 난수에서 시작 — randf() 를 쓰는 연출이 실행마다 달라지지 않게
	seed(20261014)
	연출시계.프레임_기준 = Engine.get_process_frames()
	_마우스_고정()
	var 노드: Node = s.instantiate()
	root.add_child(노드)
	current_scene = 노드
	for i in 프레임:
		await process_frame
		_마우스_고정()
		# 부품 씬(체크포인트 등)은 카메라가 없다 → 원점이 화면 가운데 오도록 임시 카메라를 단다
		if i == 2 and root.get_viewport().get_camera_2d() == null and 노드 is Node2D:
			var 카메라 := Camera2D.new()
			노드.add_child(카메라)
			카메라.make_current()
	var 상태 := "ok"
	var 이름 := p.trim_prefix("res://").replace("/", "__").get_basename()
	if 찍기:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(출력.path_join(이름 + ".png"))
		if 격자:
			await _격자_촬영(노드, 이름)
	# 씬이 스스로 다른 씬으로 넘겼어도(장면전환) 지금 올라온 것을 내린다
	var 지금 := current_scene if current_scene != null else 노드
	if is_instance_valid(노드) and 노드 != 지금:
		상태 = "다른 씬으로 넘어감"
		노드.queue_free()
	if is_instance_valid(지금):
		지금.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	return 상태


## 스테이지(월드.gd · `_카메라` 가 있는 씬)는 시작 화면 한 장으로는 맵 대부분을 못 본다.
## tools/측정_하수도_프레임.gd 와 같은 방법으로 카메라를 플레이어에서 떼고 플레이어를 멈춘 뒤,
## 카메라 리밋 안을 **한 화면 크기 격자**로 옮겨 다니며 찍는다(용량 때문에 절반 크기로 저장).
## 플레이어를 멈추므로 사망·이동이 끼어들지 않는다. 씬은 저장하지 않는다.
func _격자_촬영(노드: Node, 이름: String) -> void:
	var 카메라 = 노드.get("_카메라") if "_카메라" in 노드 else null
	if not (카메라 is Camera2D):
		return
	카메라.set("target", null)
	var 플레이어 := 노드.get_node_or_null("Player")
	if 플레이어:
		플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	var 리밋: Rect2 = 카메라.get("_limits") if "_limits" in 카메라 else Rect2()
	if not ("_has_limits" in 카메라 and 카메라.get("_has_limits")) or 리밋.size.x <= 0.0:
		리밋 = Rect2(카메라.limit_left, 카메라.limit_top,
			카메라.limit_right - 카메라.limit_left, 카메라.limit_bottom - 카메라.limit_top)
	var 시야 := Vector2(root.size) / (카메라 as Camera2D).zoom
	# 리밋이 없거나 터무니없이 크면(엔진 기본 ±10000000) 격자를 만들지 않는다
	if 리밋.size.x <= 0.0 or 리밋.size.x > 200000.0 or 리밋.size.y > 200000.0:
		return
	var 열 := maxi(1, ceili(리밋.size.x / 시야.x))
	var 행 := maxi(1, ceili(리밋.size.y / 시야.y))
	for r in 행:
		for c in 열:
			(카메라 as Camera2D).global_position = Vector2(
				리밋.position.x + minf((c + 0.5) * 시야.x, 리밋.size.x - 시야.x * 0.5),
				리밋.position.y + minf((r + 0.5) * 시야.y, 리밋.size.y - 시야.y * 0.5))
			(카메라 as Camera2D).reset_smoothing()
			for i in 격자_대기:
				await process_frame
				_마우스_고정()
			await RenderingServer.frame_post_draw
			var 그림 := root.get_texture().get_image()
			그림.resize(그림.get_width() / 2, 그림.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			그림.save_png(출력.path_join("%s__격자_%02d_%02d.png" % [이름, r, c]))
