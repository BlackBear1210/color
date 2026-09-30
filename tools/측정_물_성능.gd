extends SceneTree
## ============================================================================
## [2026-09-29] 물 셰이더 성능 측정 — 읽기만 한다(씬 저장 안 함).
## ----------------------------------------------------------------------------
## 실행(렌더링을 켜야 한다 · --headless 금지):
##   Godot --rendering-method gl_compatibility --audio-driver Dummy --resolution 1920x1080 \
##         --path . -s res://tools/측정_물_성능.gd -- <씬> <x> <y> [표본프레임=300]
##
## ▣ 왜
##   하수도 낙수 셰이더(water_stream_reference)는 화면 텍스처를 읽고(굴절), 착수부 픽셀마다
##   물방울 42 + 잎 물보라 20 번 반복한다. 물이 많은 화면에서 프레임이 떨어지는지 숫자로 본다.
##   같은 자리에서 **물 켬 / 물 그림 끔** 두 번 재서 물이 차지하는 비용을 뺄셈으로 준다.
## ============================================================================

func _init() -> void:
	call_deferred("_go")

func _모두(n: Node, r: Array = []) -> Array:
	r.append(n)
	for c in n.get_children():
		_모두(c, r)
	return r

func _재기(표본: int) -> Dictionary:
	var 시간들: Array = []
	var 앞 := Time.get_ticks_usec()
	var 그리기 := 0.0
	for _i in 표본:
		await process_frame
		var 지금 := Time.get_ticks_usec()
		시간들.append(float(지금 - 앞) / 1000.0)
		앞 = 지금
		그리기 += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	시간들.sort()
	var 합 := 0.0
	for t in 시간들:
		합 += t
	return {"평균": 합 / 표본, "p95": 시간들[int(표본 * 0.95)], "최대": 시간들[-1], "그리기": 그리기 / 표본}

func _go() -> void:
	Engine.max_fps = 0
	var a := OS.get_cmdline_user_args()
	var 표본 := int(a[3]) if a.size() > 3 else 300
	var 루트: Node = (load(a[0]) as PackedScene).instantiate()
	root.add_child(루트)
	for _i in 20:
		await process_frame
	var 플: CharacterBody2D = null
	for n in _모두(루트):
		if String(n.name).ends_with("Player"):
			플 = n
		if n is Camera2D:
			(n as Camera2D).position_smoothing_enabled = false
	플.global_position = Vector2(float(a[1]), float(a[2]))
	플.set_physics_process(false)
	for _i in 90:
		await process_frame
	var 켬: Dictionary = await _재기(표본)
	# 물 그림만 끈다(판정·로직은 그대로) — 낙수·웅덩이 외관 노드
	for n in _모두(루트):
		if String(n.name) in ["WhiteWaterV2", "WhitePoolV2"]:
			(n as CanvasItem).visible = false
	for _i in 30:
		await process_frame
	var 끔: Dictionary = await _재기(표본)
	print("PERF %s | 물 켬 평균 %.2fms(%.0ffps) p95 %.2f 최대 %.2f 그리기 %.0f | 물 끔 평균 %.2fms p95 %.2f 그리기 %.0f | 물 비용 %.2fms" % [
		a[0].get_file(), 켬["평균"], 1000.0 / 켬["평균"], 켬["p95"], 켬["최대"], 켬["그리기"],
		끔["평균"], 끔["p95"], 끔["그리기"], 켬["평균"] - 끔["평균"]])
	quit(0)
