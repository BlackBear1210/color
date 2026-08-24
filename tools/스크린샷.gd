extends SceneTree
## ============================================================================
## [2026-08-24 신규] 씬 하나를 열어 화면을 PNG 로 저장하는 도구
## ----------------------------------------------------------------------------
## 실행 (⚠ --headless 를 붙이면 안 된다. 더미 렌더러라 그림이 안 나온다):
##   Godot --path . -s res://tools/스크린샷.gd -- \
##       --씬=res://scenes/smartshape_test/grass_v4_stress_test.tscn \
##       --출력=D:/어딘가/shot.png [--줌=0.12] [--중심=5000,2400] [--폭=1920] [--높이=1080]
##
## 왜 필요한가: 지형 렌더링은 "코드가 안 터진다" 로는 검증이 안 된다.
## 코너가 제 방향으로 도는지, 엣지/필 경계가 자연스러운지는 실제 픽셀을 봐야 한다.
## ============================================================================

var 씬경로 := ""
var 출력경로 := ""
var 줌 := 0.0
var 중심 := Vector2.INF
var 폭 := 1920
var 높이 := 1080


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--씬="):
			씬경로 = a.substr("--씬=".length())
		elif a.begins_with("--출력="):
			출력경로 = a.substr("--출력=".length())
		elif a.begins_with("--줌="):
			줌 = a.substr("--줌=".length()).to_float()
		elif a.begins_with("--폭="):
			폭 = a.substr("--폭=".length()).to_int()
		elif a.begins_with("--높이="):
			높이 = a.substr("--높이=".length()).to_int()
		elif a.begins_with("--중심="):
			var xy := a.substr("--중심=".length()).split(",")
			if xy.size() == 2:
				중심 = Vector2(xy[0].to_float(), xy[1].to_float())
	call_deferred("_실행")


func _실행() -> void:
	if 씬경로.is_empty() or 출력경로.is_empty():
		push_error("--씬= 과 --출력= 이 필요하다")
		quit(1)
		return

	var ps: PackedScene = load(씬경로)
	if ps == null:
		push_error("씬 로드 실패: %s" % 씬경로)
		quit(1)
		return

	root.content_scale_size = Vector2i(폭, 높이)
	DisplayServer.window_set_size(Vector2i(폭, 높이))

	var 인스턴스: Node = ps.instantiate()
	root.add_child(인스턴스)

	# 카메라 보정: 씬에 카메라가 있으면 인자로 덮어쓴다
	var cam: Camera2D = _카메라찾기(인스턴스)
	if cam != null:
		if 줌 > 0.0:
			cam.zoom = Vector2(줌, 줌)
		if 중심 != Vector2.INF:
			cam.position = 중심
		cam.make_current()

	# SS2D 는 set_as_dirty() -> call_deferred 로 메시를 굽는다.
	# 여유있게 여러 프레임 돌려야 전부 그려진 상태가 된다.
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = root.get_texture().get_image()
	var err := img.save_png(출력경로)
	if err != OK:
		push_error("PNG 저장 실패(%d): %s" % [err, 출력경로])
		quit(1)
		return
	print("[스크린샷] %s  (%dx%d)" % [출력경로, img.get_width(), img.get_height()])
	quit(0)


func _카메라찾기(n: Node) -> Camera2D:
	if n is Camera2D:
		return n
	for c in n.get_children():
		var r := _카메라찾기(c)
		if r != null:
			return r
	return null
