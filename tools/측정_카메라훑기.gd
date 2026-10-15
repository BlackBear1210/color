extends SceneTree
## [2026-10-15 Claude] 카메라 훑기 프레임 측정 — "플레이어가 걸어가며 새 구역이 화면에 들어올 때 끊기나".
##
## 왜: tools/측정_하수도_프레임.gd 는 카메라를 칸마다 순간이동시킨 뒤 20 프레임 쉬고 잰다.
##   그래서 "새 구역이 처음 화면에 들어오는 순간"(셰이더 첫 컴파일 · 벽등 새로 만들기 등)의 끊김을 거의 못 잡는다.
##   10-15 에 2-1 첫 칸에서 같은 프레임 번호(#5 #11 #13 #16 #25)에 매번 똑같이 튀는 것을 보고 만들었다.
## 방법: 스테이지를 띄우고 플레이어를 멈춘 뒤, 카메라를 리밋 안에서 지그재그(한 줄 = 화면 높이)로
##   **사람이 걷는 속도(기본 480 px/s)** 로 움직이며 모든 프레임 간격을 잰다. 창 모드로 돌린다(그림을 그려야 한다).
## 실행: G --path . --resolution 1920x1080 --audio-driver Dummy -s res://tools/측정_카메라훑기.gd -- <씬...> [--속도=480] [--끔=조각]
## 출력: 스테이지별 중앙 · p99 · 최대 · 16.7초과 · 18초과 + 18 ms 넘은 프레임의 카메라 자리(처음 10 개).
## ⚠ 씬을 저장하지 않는다 · 진행 기록을 쓰지 않는다(시험 실행).

var _속도 := 480.0
var _끔: Array = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var 대상: Array = []
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--속도="):
			_속도 = float(s.trim_prefix("--속도="))
		elif s.begins_with("--끔="):
			_끔.append(s.trim_prefix("--끔="))
		elif s.begins_with("res://"):
			대상.append(s)
	_실행.call_deferred(대상)


func _실행(대상: Array) -> void:
	for 경로 in 대상:
		await _한판(String(경로))
	quit()


func _한판(경로: String) -> void:
	var 씬: Node = (load(경로) as PackedScene).instantiate()
	root.add_child(씬)
	current_scene = 씬
	for i in 30:
		await process_frame
	var 카메라: Camera2D = 씬.get("_카메라")
	if 카메라 == null:
		print("%s 카메라 없음" % 경로.get_file())
		씬.queue_free()
		current_scene = null
		return
	카메라.set("target", null)
	var 플레이어 := 씬.get_node_or_null("Player")
	if 플레이어:
		플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	_대조(씬)
	var 리밋: Rect2 = 카메라.get("_limits")
	if not 카메라.get("_has_limits") or 리밋.size.x <= 0.0:
		리밋 = Rect2(카메라.limit_left, 카메라.limit_top, 카메라.limit_right - 카메라.limit_left, 카메라.limit_bottom - 카메라.limit_top)
	var 시야 := Vector2(root.size) / 카메라.zoom
	var 왼 := 리밋.position.x + 시야.x * 0.5
	var 오른 := 리밋.end.x - 시야.x * 0.5
	var 줄수 := maxi(1, ceili(리밋.size.y / 시야.y))
	var 간격: Array[float] = []
	var 튐: Array[String] = []
	var 이전 := Time.get_ticks_usec()
	for r in 줄수:
		var y := 리밋.position.y + minf((r + 0.5) * 시야.y, 리밋.size.y - 시야.y * 0.5)
		var 시작 := 왼 if r % 2 == 0 else 오른
		var 끝 := 오른 if r % 2 == 0 else 왼
		var x := 시작
		카메라.global_position = Vector2(x, y)
		카메라.reset_smoothing()
		await process_frame
		이전 = Time.get_ticks_usec()       # 줄 바꿈 순간이동 프레임은 세지 않는다
		var 방향 := signf(끝 - 시작)
		while (끝 - x) * 방향 > 0.0:
			await process_frame
			var 지금 := Time.get_ticks_usec()
			var ms := (지금 - 이전) / 1000.0
			이전 = 지금
			간격.append(ms)
			if ms > 18.0 and 튐.size() < 10:
				튐.append("(%5.0f,%5.0f) %5.1fms" % [x, y, ms])
			# 실제 걸음처럼 시간에 비례해 움직인다(프레임이 느리면 그만큼 더 간다)
			x += 방향 * _속도 * minf(ms, 50.0) / 1000.0
			카메라.global_position = Vector2(clampf(x, minf(왼, 오른), maxf(왼, 오른)), y)
	간격.sort()
	var n := 간격.size()
	if n == 0:
		print("%s 프레임 없음" % 경로.get_file())
	else:
		print("훑기 %-22s 줄 %d  프레임 %d  중앙 %5.2f  p99 %5.2f  최대 %6.2f ms  16.7초과 %d  18초과 %d" % [
			경로.get_file().get_basename(), 줄수, n, 간격[n / 2], 간격[int(n * 0.99)], 간격[n - 1],
			간격.filter(func(v): return v > 1000.0 / 60.0).size(), 간격.filter(func(v): return v > 18.0).size()])
		for t in 튐:
			print("    튐 ", t)
	씬.queue_free()
	current_scene = null
	await process_frame
	await process_frame


## --끔=조각 : 스크립트 경로에 조각이 든 노드의 처리를 끈다(원인 대조용)
func _대조(뿌리: Node) -> void:
	if _끔.is_empty():
		return
	var 쌓기: Array[Node] = [뿌리]
	var 수 := 0
	while not 쌓기.is_empty():
		var n: Node = 쌓기.pop_back()
		쌓기.append_array(n.get_children())
		var sc: Script = n.get_script()
		var 이름 := (sc.resource_path if sc else "") + "|" + String(n.name)
		for 조각 in _끔:
			if 이름.contains(조각):
				n.set_process(false)
				n.set_physics_process(false)
				수 += 1
				break
	print("    대조: 처리 끔 %d" % 수)
