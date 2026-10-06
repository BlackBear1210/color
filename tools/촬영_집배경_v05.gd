extends SceneTree
## ============================================================================
## [2026-09-28 신규] 집 배경 v05 촬영 — 방 스테이지를 **왼쪽 끝부터 오른쪽 끝까지** 걸으며 찍는다
## ----------------------------------------------------------------------------
## 실행 (★--headless 금지 — 그리지 않으면 못 찍는다):
##   Godot --path . -s res://tools/촬영_집배경_v05.gd -- [--씬=res://...tscn] [--간격=1400] [--y=-192]
##
## ▣ `촬영_집배경.gd`(v03)와 다른 점
##   v03 도구는 배경 노드를 **스스로 붙여서** 찍었다. 이건 스테이지 씬에 **이미 붙어 있는**
##   `집_배경` 을 그대로 찍는다 → 도형님이 에디터에서 여는 것과 같은 화면이다.
##   플레이어는 멈춰 두고(process 끔) 카메라만 옮긴다. 아무것도 저장·수정하지 않는다.
## ============================================================================

var 씬 := "res://scenes/집/테스트_집배경_방_v05.tscn"
const 저장폴더 := "res://artifacts/집배경_v05_촬영/"
var 간격 := 1400.0
var 촬영_y := -192.0
var 시작_x := 960.0
var 끝_x := -1.0
var 머리 := "방"


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--씬="): 씬 = a.trim_prefix("--씬=")
		elif a.begins_with("--간격="): 간격 = float(a.trim_prefix("--간격="))
		elif a.begins_with("--y="): 촬영_y = float(a.trim_prefix("--y="))
		elif a.begins_with("--시작="): 시작_x = float(a.trim_prefix("--시작="))
		elif a.begins_with("--끝="): 끝_x = float(a.trim_prefix("--끝="))
		elif a.begins_with("--머리="): 머리 = a.trim_prefix("--머리=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(저장폴더))

	var ps := load(씬) as PackedScene
	if ps == null:
		push_error("씬을 못 읽었다: " + 씬)
		quit(1)
		return
	var 뿌리 := ps.instantiate()
	root.add_child(뿌리)
	current_scene = 뿌리
	for _f in 3:
		await process_frame

	var 배경 := 뿌리.get_node_or_null("집_배경")
	var 맵폭: float = float(배경.get("맵_폭")) if 배경 else 21120.0
	if 끝_x < 0.0:
		끝_x = 맵폭 - 960.0

	# 플레이어가 떨어지거나 카메라를 끌고 가지 않게 멈춘다(보이는 것은 그대로)
	var pl := 뿌리.get_node_or_null("Player")
	if pl:
		pl.process_mode = Node.PROCESS_MODE_DISABLED

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	뿌리.add_child(cam)
	cam.make_current()

	var n := 0
	var x := 시작_x
	while x <= 끝_x + 1.0:
		cam.global_position = Vector2(x, 촬영_y)
		if pl:
			pl.global_position = Vector2(x, 촬영_y)
		for _f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var im := root.get_texture().get_image()
		var 이름 := "%s_%02d_x%05d.png" % [머리, n, int(x)]
		im.save_png(ProjectSettings.globalize_path(저장폴더 + 이름))
		print("찍음: ", 이름)
		n += 1
		x += 간격
	print("끝 — %d 장 · %s" % [n, 저장폴더])
	quit(0)
