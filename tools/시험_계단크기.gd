extends SceneTree
## [2026-08-25] 폴리곤 자체를 계단으로 만들 때, 계단 한 칸이 얼마나 작아지면
## SS2D 코너 쿼드(월드 89.6px)가 서로 겹쳐 깨지는지 본다.
## 코너가 겹치면 "부드러운 계단" 이 아니라 뭉갠 자국이 된다.
const 지형_S := preload("res://scripts/스마트월드/지형.gd")
var _머티 := ""
var _출력 := "res://tools/_shots/계단시험.png"
func _init():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--머티="): _머티 = a.substr("--머티=".length())
		elif a.begins_with("--출력="): _출력 = a.substr("--출력=".length())
	call_deferred("_go")
func _계단(단폭: float, 단높이: float, 수: int, 바닥: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x := 0.0
	var y := 0.0
	p.push_back(Vector2(x, y))
	for i in 수:
		x += 단폭
		p.push_back(Vector2(x, y))
		y += 단높이
		p.push_back(Vector2(x, y))
	p.push_back(Vector2(x, 바닥))
	p.push_back(Vector2(0, 바닥))
	return p
func _go():
	var 칸 := 560.0
	var 줌 := 1.0
	var 사례 := [["40px 계단", 40.0], ["90px 계단", 90.0], ["180px 계단", 180.0]]
	root.content_scale_size = Vector2i(int(칸 * 줌) * 3, int(칸 * 줌))
	DisplayServer.window_set_size(Vector2i(int(칸 * 줌) * 3, int(칸 * 줌)))
	var r := Node2D.new(); root.add_child(r)
	var bg := ColorRect.new(); bg.position = Vector2(-2000,-2000); bg.size = Vector2(8000,8000)
	bg.color = Color(0.72,0.72,0.72); bg.z_index = -100; r.add_child(bg)
	var m: Resource = load(_머티)
	for i in 사례.size():
		var cx: float = float(i) * 칸
		var s = 지형_S.new()
		s.shape_material = m
		s.position = Vector2(cx + 60.0, 150.0)
		r.add_child(s)
		var pa: SS2D_Point_Array = s.get_point_array()
		pa.begin_update()
		pa.add_points(_계단(사례[i][1], 사례[i][1] * 0.6, 5, 400.0))
		pa.end_update(); pa.close_shape(); s.force_update()
		var l := Label.new()
		l.position = Vector2(cx + 12.0, 8.0); l.text = 사례[i][0]
		l.add_theme_color_override("font_color", Color(0.85,0.08,0.08))
		l.add_theme_font_size_override("font_size", 24); r.add_child(l)
	var cam := Camera2D.new()
	cam.position = Vector2(칸 * 1.5, 칸 * 0.5); cam.zoom = Vector2(줌, 줌)
	r.add_child(cam); cam.make_current()
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_출력))
	print("[계단시험] %s" % _출력); quit()
