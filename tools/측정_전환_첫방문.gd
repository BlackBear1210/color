extends SceneTree
## [2026-10-15 Claude] 스테이지 전환 프레임 측정 — "새 스테이지가 밝아진 뒤 3 초 동안 60 FPS 아래가 있나" (화면준비 확인용)
##
## ★창 모드로 돌린다(--headless 금지 · 그리기를 안 하면 처음 그릴 때의 비용이 안 보인다). 동기화·상한은 게임 설정 그대로.
##   G -s res://tools/측정_전환_첫방문.gd -- <출발 씬> <도착 씬> [--방식=하수도|쳅터1] [--스냅] [--예열=400] [--가만히=초] [--자세히]
##   --가만히=초 : 전환 전에 그 자리에서 그냥 재는 대조군(PC 가 바쁘면 여기서도 튄다 — 10-15 ChatGPT·Codex 켜 둔 채 15 초에 59~579 개)
##   --자세히 : 19 ms 넘는 프레임마다 판 투명도·대기 여부·처리/물리 시간·노드 수를 찍는다
##
## 방법: 출발 씬을 현재 씬으로 띄우고, 게임과 같은 전환 함수(장면전환.통로로_이동 / 전경전환.씬으로_들어가기)로 도착 씬에 들어간다.
##   매 프레임 간격을 재서 "가려진 동안(암전 대기 중)" 과 "보이는 동안(대기가 끝난 뒤 3 초)" 으로 나눠 센다.
##   같은 실행에서 출발 → 도착을 한 번 더 해서 재방문(대기 없음)도 잰다.
## --스냅 : 출발 씬에서 출구 사진을 그려 두고(스테이지_스냅._출구에서_그려두기) 그 프레임 비용과, 암전 중 저장되는지 확인한다.
##   사진은 user://스냅/_측정_스냅.png 로 저장되었다가 확인 뒤 지운다(진행 기록 파일은 건드리지 않는다).

const 예산_ms := 1000.0 / 60.0
const 볼_초 := 3.0
const 시험_사진 := "user://스냅/_측정_스냅.png"


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 씬들: Array = []
	var 방식 := "하수도"
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--방식="):
			방식 = s.trim_prefix("--방식=")
		elif not s.begins_with("--"):
			씬들.append(s)
	if 씬들.size() < 2:
		print("사용법: -- <출발 씬> <도착 씬> [--방식=하수도|쳅터1] [--스냅]")
		quit(2)
		return
	print("TRANSITION_MEASURE 동기 %s · 상한 %d · %s" % [DisplayServer.window_get_vsync_mode(), Engine.max_fps, RenderingServer.get_video_adapter_name()])
	var 출발 := String(씬들[0])
	var 도착 := String(씬들[1])
	var 시작씬 := (load(출발) as PackedScene).instantiate()
	root.add_child(시작씬)
	current_scene = 시작씬
	var 예열 := 400
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--예열="):
			예열 = int(String(a).trim_prefix("--예열="))
	for i in 예열:          # 출발 씬은 충분히 데운다(게임에서는 화면준비가 데워 둔 채로 들어온다 · 90 이면 출발 씬 첫 그리기 튐이 섞였다)
		await process_frame
	var 실패 := 0
	# --가만히=초 : 전환 없이 출발 씬에 그대로 있으며 같은 방식으로 잰다(대조군 — PC 상태 흔들림이 얼마나 되나)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--가만히="):
			var 초 := float(String(a).trim_prefix("--가만히="))
			var 넘음: Array = []
			var n := 0
			var 끝 := Time.get_ticks_msec() + int(초 * 1000.0)
			var t := Time.get_ticks_usec()
			while Time.get_ticks_msec() < 끝:
				await process_frame
				var u := Time.get_ticks_usec()
				n += 1
				if float(u - t) / 1000.0 > 예산_ms:
					넘음.append(snappedf(float(u - t) / 1000.0, 0.1))
				t = u
			print("  가만히 %.0f 초 : %d 프레임 · 16.7ms 초과 %d %s" % [초, n, 넘음.size(), str(넘음)])
	if OS.get_cmdline_user_args().has("--스냅"):
		실패 += await _스냅_그리기(시작씬)
	실패 += await _한번(방식, 도착, 출발, "첫 방문")
	실패 += await _한번(방식, 출발, 도착, "되돌아감")
	실패 += await _한번(방식, 도착, 출발, "재방문")
	if OS.get_cmdline_user_args().has("--스냅"):
		var 있음 := FileAccess.file_exists(시험_사진)
		print("  스냅: 암전 중 저장 %s" % ("됨 ✔" if 있음 else "안 됨 ✘"))
		if 있음:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(시험_사진))
		else:
			실패 += 1
	print("TRANSITION 합계: 실패 %d" % 실패)
	quit(1 if 실패 > 0 else 0)


## 출구 사진을 그려 두는 프레임 — 그 프레임과 다음 2 프레임 간격을 잰다.
func _스냅_그리기(씬: Node) -> int:
	var 스냅 := 씬.get_node_or_null("스테이지스냅")
	if 스냅 == null:
		print("  스냅: 이 씬에는 스테이지스냅이 없다")
		return 1
	스냅.set("_씬이름", "_측정_스냅")
	게임진행.기록_허용 = 1        # 이 한 줄 동안만 — 사진 그려 두기는 기록 허용을 본다
	스냅.call("_출구에서_그려두기")
	게임진행.기록_허용 = -1
	var 간격: Array = []
	var t := Time.get_ticks_usec()
	for i in 3:
		await process_frame
		var u := Time.get_ticks_usec()
		간격.append(float(u - t) / 1000.0)
		t = u
	print("  스냅 그려 두기 뒤 프레임: %s ms" % str(간격.map(func(x): return snappedf(x, 0.1))))
	return 1 if 간격.max() > 예산_ms else 0


func _한번(방식: String, 목적지: String, 왔던곳: String, 이름: String) -> int:
	var t0 := Time.get_ticks_msec()
	if 방식 == "쳅터1":
		var 전경전환 = load("res://scripts/쳅터1/전경전환.gd")
		전경전환.씬으로_들어가기(current_scene, 목적지, "")
	else:
		장면전환.통로로_이동(current_scene, 목적지, "입구통로", 왔던곳)
	# 보이나 = 전환 판(암전판)의 투명도로 판단한다 — 판이 0.98 이상 덮고 있으면 화면이 까맣다.
	var 가림: Array = []
	var 보임: Array = []          # [ms, 판 투명도]
	var 대기_봄 := false
	var 판_사라짐 := -1
	var t := Time.get_ticks_usec()
	while true:
		await process_frame
		var u := Time.get_ticks_usec()
		var ms := float(u - t) / 1000.0
		t = u
		대기_봄 = 대기_봄 or 화면준비.대기중
		var 덮음 := _판_투명도()
		if ms > 19.0 and OS.get_cmdline_user_args().has("--자세히"):
			print("    튐 %.1fms · %dms · 판 %.2f · 대기 %s · 처리 %.1f · 물리 %.1f · 노드 %d · 그리기 %d · %s" % [ms, Time.get_ticks_msec() - t0, 덮음, 화면준비.대기중,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				current_scene.scene_file_path.get_file() if current_scene else "-"])
		if 덮음 >= 0.98:
			가림.append(ms)
		else:
			보임.append([ms, 덮음, Time.get_ticks_msec() - t0, current_scene.scene_file_path.get_file().get_basename() if current_scene else "-"])
		if 덮음 < 0.0 and 판_사라짐 < 0:
			판_사라짐 = Time.get_ticks_msec()
		if 판_사라짐 >= 0 and Time.get_ticks_msec() - 판_사라짐 > int(볼_초 * 1000.0):
			break
		if Time.get_ticks_msec() - t0 > 30000:
			break
	# 전환 판이 다 사라질 때까지 기다린다(다음 전환이 _진행중 으로 막히지 않게)
	while 장면전환.진행중인가() or (load("res://scripts/쳅터1/전경전환.gd")).진행중인가():
		await process_frame
	for i in 30:
		await process_frame
	var 넘음 := 보임.filter(func(x): return x[0] > 예산_ms)
	var 시간들 := 보임.map(func(x): return x[0])
	시간들.sort()
	print("  %s → %s : 대기 %s · 까만 프레임 %d · 보인 프레임 %d(전환 중 + 판 사라진 뒤 3 초) · 16.7ms 초과 %d · 중앙 %.1f · 최대 %.1f ms %s" % [
		이름, 목적지.get_file(), "함" if 대기_봄 else "안 함", 가림.size(), 보임.size(), 넘음.size(),
		시간들[시간들.size() / 2] if 시간들.size() > 0 else 0.0, 시간들.max() if 시간들.size() > 0 else 0.0,
		str(넘음.map(func(x): return "%.1fms@판%.2f·%dms·%s" % [x[0], x[1], x[2], x[3]]))])
	return 1 if 넘음.size() > 0 else 0


## 지금 화면을 덮은 전환 판의 투명도(판이 없으면 −1).
func _판_투명도() -> float:
	for n in root.get_children():
		if n is CanvasLayer and "_판" in n:
			var 판 = n.get("_판")
			if 판 is ColorRect:
				return (판 as ColorRect).color.a
	return -1.0
