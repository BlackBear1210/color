extends SceneTree
## [2026-08-25] 발판이 얼마나 얇아지면 TOP/BOTTOM 띠가 겹쳐서 FILL 이 사라지는지.
## 엣지 띠 한 장의 월드 폭 = 256 텍셀 x texture_scale 0.35 = 89.6px.
## 위아래 둘이면 179.2px 이므로 그보다 얇은 발판은 이론상 전부 띠다.
const 지형_S := preload("res://scripts/스마트월드/지형.gd")
var _머티 := ""
var _출력 := "res://tools/_shots/두께시험.png"
func _init():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--머티="): _머티 = a.substr("--머티=".length())
		elif a.begins_with("--출력="): _출력 = a.substr("--출력=".length())
	call_deferred("_go")
func _go():
	var 두께들 := [90.0, 140.0, 180.0, 260.0, 400.0]
	var 폭 := 520.0
	var 여백 := 90.0
	var W := int(폭 + 여백 * 2.0)
	var H := 0.0
	for t in 두께들: H += t + 70.0
	H += 120.0
	root.content_scale_size = Vector2i(W, int(H))
	DisplayServer.window_set_size(Vector2i(W, int(H)))
	var r := Node2D.new(); root.add_child(r)
	var bg := ColorRect.new(); bg.position = Vector2(-2000,-2000); bg.size = Vector2(8000,8000)
	bg.color = Color(0.72,0.72,0.72); bg.z_index = -100; r.add_child(bg)
	var m: Resource = load(_머티)
	var y := 60.0
	for t in 두께들:
		var s = 지형_S.new()
		s.shape_material = m
		s.position = Vector2(여백, y)
		r.add_child(s)
		var pa: SS2D_Point_Array = s.get_point_array()
		pa.begin_update()
		pa.add_points(PackedVector2Array([Vector2(0,0), Vector2(폭,0), Vector2(폭,t), Vector2(0,t)]))
		pa.end_update(); pa.close_shape(); s.force_update()
		var l := Label.new()
		l.position = Vector2(6.0, y + t * 0.5 - 14.0)
		l.text = "%.0f" % t
		l.add_theme_color_override("font_color", Color(0.85,0.08,0.08))
		l.add_theme_font_size_override("font_size", 26); r.add_child(l)
		y += t + 70.0
	var cam := Camera2D.new()
	cam.position = Vector2(float(W) * 0.5, H * 0.5); cam.zoom = Vector2(1.0, 1.0)
	r.add_child(cam); cam.make_current()
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_출력))
	print("[두께시험] %s  %dx%d" % [_출력, W, int(H)]); quit()
