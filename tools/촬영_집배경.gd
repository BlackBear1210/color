extends SceneTree
## ============================================================================
## [2026-09-27 신규] 집 배경 촬영 — 새 배경이 게임 화면에서 어떻게 보이나
## ----------------------------------------------------------------------------
## 실행 (★--headless 를 쓰면 안 된다 — 그리지 않으므로 화면을 못 찍는다):
##   Godot --path . -s res://tools/촬영_집배경.gd -- --변형=0,1,2 --종류=방
##
## ▣ 무엇을 찍나
##   `집_배경` 노드 + **실제 집-1 지형** + 플레이어 크기 사각형을 한 화면에 놓고,
##   카메라를 옮겨 가며 PNG 로 저장한다. 시차가 실제로 어떻게 보이는지 · 검정 발판이
##   배경에 묻히는지 · 방이 반복돼 보이는지를 **사람이 눈으로** 판단할 자료를 만든다.
##
## ▣ 아무것도 안 고친다. 씬을 띄워 찍기만 한다.
## ============================================================================

var 지형_씬 := "res://scenes/집/스테이지_1_2층방.tscn"
const 저장폴더 := "res://artifacts/집배경_v03_촬영/"

## 카메라를 세울 자리(월드 x). 맵 앞쪽 · 중간 세 군데를 본다.
var 촬영_x := [1400.0, 4200.0, 7600.0]
var 촬영_y := 120.0

var _변형: Array[int] = [0, 1, 2]
var _종류 := 0                      # 0 = 방, 1 = 복도
var _맵폭 := 22272.0
var _맵높이 := 5760.0
var _바닥 := 480.0


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--변형="):
			_변형.clear()
			for t in a.trim_prefix("--변형=").split(","):
				_변형.append(int(t))
		elif a.begins_with("--바닥="):
			_바닥 = float(a.trim_prefix("--바닥="))
		elif a.begins_with("--y="):
			촬영_y = float(a.trim_prefix("--y="))
		elif a.begins_with("--지형="):
			지형_씬 = a.trim_prefix("--지형=")
		elif a.begins_with("--맵="):
			var mm := a.trim_prefix("--맵=").split("x")
			_맵폭 = float(mm[0]); _맵높이 = float(mm[1])
		elif a.begins_with("--종류="):
			_종류 = 1 if a.trim_prefix("--종류=") == "복도" else 0

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(저장폴더))

	# ── 무대 ──────────────────────────────────────────────────────────────────
	var 무대 := Node2D.new()
	root.add_child(무대)
	current_scene = 무대

	# 배경 (변형마다 다시 만든다)
	var 배경_스크립트 := load("res://scripts/스마트월드/집_배경.gd")

	# 실제 지형 — 배경만 찍으면 "예쁘다"로 끝난다. 검정 발판이 배경 위에서
	# 읽히는지가 진짜 판단 기준이라 진짜 스테이지를 올린다.
	var 지형뿌리: Node = null
	var ps := load(지형_씬) as PackedScene
	if ps:
		지형뿌리 = ps.instantiate()
		무대.add_child(지형뿌리)
	else:
		push_warning("지형 씬을 못 읽었다 — 배경만 찍는다")

	# 카메라
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	무대.add_child(cam)
	cam.make_current()

	# 플레이어 크기 기준 사각형(44 × 96). 흰 네모 하나가 크기 감각을 준다.
	var 기준 := ColorRect.new()
	기준.color = Color(0.92, 0.92, 0.94)
	기준.size = Vector2(44, 96)
	기준.z_index = 60
	무대.add_child(기준)

	await process_frame
	await process_frame

	for v in _변형:
		# 이전 배경 치우기
		for c in 무대.get_children():
			if c.name.begins_with("배경"):
				무대.remove_child(c)
				c.queue_free()
		await process_frame

		var bg := Node2D.new()
		bg.name = "배경_%d" % v
		bg.set_script(배경_스크립트)
		무대.add_child(bg)
		bg.set("맵_폭", _맵폭)
		bg.set("맵_높이", _맵높이)
		bg.set("바닥_y", _바닥)
		bg.set("종류", _종류)
		bg.set("변형", v)                 # ★setter 가 여기서 층을 짓는다
		# 배경이 지형보다 뒤로 가게 (지형은 z 0)
		await process_frame
		await process_frame

		for i in 촬영_x.size():
			cam.global_position = Vector2(촬영_x[i], 촬영_y)
			기준.global_position = Vector2(촬영_x[i] - 22.0, 촬영_y + 300.0)
			# 시차가 카메라 위치를 따라 갱신될 시간을 준다
			for _f in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var im := get_root().get_texture().get_image()
			var 이름 := "%s_변형%d_자리%d.png" % ["방" if _종류 == 0 else "복도", v, i]
			var err := im.save_png(ProjectSettings.globalize_path(저장폴더 + 이름))
			if err == OK:
				print("찍음: %s  (%d × %d)" % [이름, im.get_width(), im.get_height()])
			else:
				push_error("저장 실패(%d): %s" % [err, 이름])

	print("끝 — %s" % 저장폴더)
	quit(0)
