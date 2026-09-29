extends SceneTree
## [2026-09-30 Claude] 하수도 스테이지 프레임 측정 — "어느 스테이지 · 어느 화면에서 16.7ms 를 넘나".
##
## ★창 모드로 돌린다(--headless 금지). headless 는 그리기를 안 해서 GPU 비용이 0 으로 나온다.
##   G -s res://tools/측정_하수도_프레임.gd -- [씬경로...] [--칸=60] [--끔=스크립트조각]
##
## 방법: 카메라를 플레이어에서 떼어 맵 전체를 **한 화면 크기 격자**로 옮겨 다니며,
##   칸마다 20 프레임 예열 뒤 60 프레임을 잰다. 플레이어는 멈춰 둔다(죽지 않게).
##   VSync·max_fps 를 끄므로 프레임 시간 = 실제 비용이다(60FPS 예산 16.67ms).
## 출력: 스테이지별 중앙값/p99/최대 · 가장 무거운 칸 5 개 · 그 칸의 process/physics/GPU/그리기 호출.
## --끔=조각 : 스크립트 경로에 조각이 들어간 노드의 process 를 끈다(원인 대조용). 여러 번 줄 수 있다.
## --숨김=조각 : 같은 조건의 노드를 숨긴다(그리기 비용 대조용).

const 기본대상 := [
	"res://scenes/world_2_클로드/stage_2-1.tscn",
	"res://scenes/world_2_클로드/stage_2-2.tscn",
	"res://scenes/world_2_클로드/stage_2-3.tscn",
	"res://scenes/world_2_클로드/stage_2-4.tscn",
	"res://scenes/world_2_클로드/stage_2-5.tscn",
	"res://scenes/world_2_클로드/stage_2-6.tscn",
	"res://scenes/world_2_클로드/stage_2-7.tscn",
	"res://scenes/world_2_클로드/stage_2-8.tscn",
	"res://scenes/world_2_클로드/stage_2-9.tscn",
	"res://scenes/world_2_클로드/stage_2-10.tscn",
	"res://scenes/world_2_클로드/stage_2-11.tscn",
]
const 예산_ms := 1000.0 / 60.0

var _칸프레임 := 60
var _끔: Array = []
var _숨김: Array = []
var _셰이더치환: Array = []


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	# 측정 중에는 화면 동기화·상한을 끈다 — 켜 두면 모든 프레임이 16.7ms 로 눌려 비용이 안 보인다.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var 대상: Array = []
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--칸="):
			_칸프레임 = int(s.trim_prefix("--칸="))
		elif s.begins_with("--끔="):
			_끔.append(s.trim_prefix("--끔="))
		elif s.begins_with("--숨김="):
			_숨김.append(s.trim_prefix("--숨김="))
		elif s.begins_with("--치환="):
			# --치환=셰이더경로|찾을글|바꿀글 : 메모리 안의 셰이더 코드만 바꾼다(파일은 그대로). 비용 쪼개기 실험용.
			_셰이더치환.append(s.trim_prefix("--치환=").split("|"))
		elif not s.begins_with("--"):
			대상.append(s)
	if 대상.is_empty():
		대상 = 기본대상.duplicate()
	for 치환 in _셰이더치환:
		var sh := load(치환[0]) as Shader
		var 전 := sh.code
		sh.code = 전.replace(치환[1], 치환[2])
		print("치환 %s : %s" % [치환[0].get_file(), "적용" if sh.code != 전 else "못 찾음"])
	print("FRAME_MEASURE window=%s driver=%s gpu=%s 끔=%s 숨김=%s" % [
		str(root.size), RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), str(_끔), str(_숨김)])
	for 경로 in 대상:
		await _한판(String(경로))
	quit(0)


func _한판(경로: String) -> void:
	var ps := load(경로) as PackedScene
	if ps == null:
		print("  %s 로드 실패" % 경로)
		return
	var t0 := Time.get_ticks_usec()
	var 씬 := ps.instantiate()
	root.add_child(씬)
	var 로드_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	for i in 30:
		await process_frame
	var 카메라: Camera2D = 씬.get("_카메라")
	var 플레이어 := 씬.get_node_or_null("Player") as Node2D
	if 카메라 == null:
		print("  %s 카메라 없음" % 경로.get_file())
		씬.queue_free()
		return
	# 카메라를 떼고 플레이어를 멈춘다. 월드 사망 판정은 멈춘 플레이어 자리 그대로라 죽지 않는다.
	카메라.set("target", null)
	if 플레이어:
		플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	_대조_적용(씬)
	# 스크립트 시간 탐침 — 처음/끝 우선순위 노드 두 개로 이 프레임의 _process·_physics_process 합을 잰다.
	var 탐침: Node = load("res://tools/측정_프레임_탐침.gd").new()
	var 탐침끝: Node = load("res://tools/측정_프레임_탐침.gd").new()
	탐침끝.set("끝쪽", true)
	탐침끝.set("짝", 탐침)
	root.add_child(탐침)
	root.add_child(탐침끝)
	var 리밋: Rect2 = 카메라.get("_limits")
	if not 카메라.get("_has_limits") or 리밋.size.x <= 0.0:
		리밋 = Rect2(카메라.limit_left, 카메라.limit_top,
			카메라.limit_right - 카메라.limit_left, 카메라.limit_bottom - 카메라.limit_top)
	var 시야 := Vector2(root.size) / 카메라.zoom
	var 열 := maxi(1, ceili(리밋.size.x / 시야.x))
	var 행 := maxi(1, ceili(리밋.size.y / 시야.y))
	var 전체: Array[float] = []
	var 칸들: Array = []
	# 평균(합) — 최대만 보면 한 번 튄 값에 끌려간다. 무엇이 평소에 시간을 먹는지는 평균으로 본다.
	var 합 := {"gpu": 0.0, "렌더cpu": 0.0, "처리": 0.0, "물리": 0.0, "스크립트": 0.0, "스크립트최대": 0.0}
	for r in 행:
		for c in 열:
			var 중심 := Vector2(
				리밋.position.x + minf((c + 0.5) * 시야.x, 리밋.size.x - 시야.x * 0.5),
				리밋.position.y + minf((r + 0.5) * 시야.y, 리밋.size.y - 시야.y * 0.5))
			카메라.global_position = 중심
			카메라.reset_smoothing()
			for i in 20:
				await process_frame
			var 칸: Array[float] = []
			var 이전 := Time.get_ticks_usec()
			var 처리 := 0.0
			var 물리 := 0.0
			var 그리기 := 0.0
			var gpu := 0.0
			var cpu := 0.0
			for i in _칸프레임:
				탐침.set("물리_ms", 0.0)
				await process_frame
				var 지금 := Time.get_ticks_usec()
				칸.append(float(지금 - 이전) / 1000.0)
				이전 = 지금
				처리 = maxf(처리, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				물리 = maxf(물리, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				그리기 = maxf(그리기, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var g := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				var rc := RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
				gpu = maxf(gpu, g)
				cpu = maxf(cpu, rc)
				합["gpu"] += g
				합["렌더cpu"] += rc
				합["처리"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				합["물리"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
				합["스크립트"] += float(탐침.get("처리_ms")) + float(탐침.get("물리_ms"))
				합["스크립트최대"] = maxf(합["스크립트최대"], float(탐침.get("처리_ms")) + float(탐침.get("물리_ms")))
				# 예산을 넘은 프레임은 그 순간의 내역을 바로 찍는다 — GPU 가 낮은데 튀면 CPU/OS 쪽이다.
				if 칸[-1] > 예산_ms:
					print("    SPIKE (%5.0f,%5.0f) #%2d %6.2fms | gpu %5.2f 렌더cpu %5.2f | 스크립트 process %5.2f physics %5.2f" % [
						중심.x, 중심.y, i, 칸[-1], g, rc, 탐침.get("처리_ms"), 탐침.get("물리_ms")])
			전체.append_array(칸)
			칸.sort()
			칸들.append({"중심": 중심, "중앙": 칸[칸.size() / 2], "최대": 칸[-1],
				"처리": 처리, "물리": 물리, "그리기": 그리기, "gpu": gpu, "렌더cpu": cpu})
	전체.sort()
	var n := 전체.size()
	var 넘음 := 전체.filter(func(v): return v > 예산_ms).size()
	print("%-16s 로드 %6.0fms  칸 %2d  중앙 %5.2f  p95 %5.2f  p99 %5.2f  최대 %6.2f ms  16.7초과 %d/%d" % [
		경로.get_file().get_basename(), 로드_ms, 칸들.size(),
		전체[n / 2], 전체[int(n * 0.95)], 전체[int(n * 0.99)], 전체[n - 1], 넘음, n])
	print("    평균: gpu %5.2f · 렌더 cpu %5.2f · 스크립트(process+physics) %5.2f 최대 %5.2f ms" % [
		합["gpu"] / n, 합["렌더cpu"] / n, 합["스크립트"] / n, 합["스크립트최대"]])
	칸들.sort_custom(func(a, b): return a["최대"] > b["최대"])
	for i in mini(5, 칸들.size()):
		var k: Dictionary = 칸들[i]
		print("    (%5.0f,%5.0f) 중앙 %5.2f 최대 %6.2f | process %5.2f physics %5.2f | 렌더 cpu %5.2f gpu %5.2f | draw %4.0f" % [
			k["중심"].x, k["중심"].y, k["중앙"], k["최대"], k["처리"], k["물리"], k["렌더cpu"], k["gpu"], k["그리기"]])
	씬.queue_free()
	탐침.queue_free()
	탐침끝.queue_free()
	await process_frame
	await process_frame


## 원인 대조용: 스크립트 경로에 조각이 들어간 노드의 process 를 끄거나 숨긴다.
func _대조_적용(뿌리: Node) -> void:
	if _끔.is_empty() and _숨김.is_empty():
		return
	var 끈수 := 0
	var 숨긴수 := 0
	var 쌓기: Array[Node] = [뿌리]
	while not 쌓기.is_empty():
		var n: Node = 쌓기.pop_back()
		쌓기.append_array(n.get_children())
		var s: Script = n.get_script()
		var 이름 := (s.resource_path if s else "") + "|" + n.get_class() + "|" + String(n.name)
		for 조각 in _끔:
			if 이름.contains(조각):
				n.set_process(false)
				n.set_physics_process(false)
				끈수 += 1
				break
		for 조각 in _숨김:
			# "메시:" 로 시작하면 노드는 둔 채 SS2D 가 그리는 메시만 끈다(자식·충돌·빛가림은 그대로).
			# "재질:" = SS2D 메시는 그리되 재질을 빼고(기본 캔버스 셰이더) 그린다.
			if 조각.begins_with("재질:") and 이름.contains(조각.trim_prefix("재질:")) and n.get("_renderer") != null:
				for rid in n.get("_renderer").get("_render_nodes"):
					RenderingServer.canvas_item_set_material(rid, RID())
				숨긴수 += 1
				break
			# "빛끔:" = SS2D 메시의 light_mask 를 0 으로(광원 패스에서 빠진다).
			if 조각.begins_with("빛끔:") and 이름.contains(조각.trim_prefix("빛끔:")) and n.get("_renderer") != null:
				for rid in n.get("_renderer").get("_render_nodes"):
					RenderingServer.canvas_item_set_light_mask(rid, 0)
				숨긴수 += 1
				break
			if 조각.begins_with("메시:") and 이름.contains(조각.trim_prefix("메시:")) and n.get("_renderer") != null:
				RenderingServer.canvas_item_set_visible(n.get("_renderer").get("_render_parent"), false)
				숨긴수 += 1
				break
			if 이름.contains(조각) and n is CanvasItem:
				(n as CanvasItem).visible = false
				숨긴수 += 1
				break
	print("    대조: process 끔 %d · 숨김 %d" % [끈수, 숨긴수])
