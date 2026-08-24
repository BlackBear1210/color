extends SceneTree
func _init(): call_deferred("_go")
func _go():
	var files := []
	var out := "res://tools/_shots/stitch.png"
	var 열 := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--입력="): files.append(a.substr("--입력=".length()))
		elif a.begins_with("--출력="): out = a.substr("--출력=".length())
		elif a.begins_with("--열="): 열 = a.substr("--열=".length()).to_int()
	var ims := []
	for f in files:
		var b := FileAccess.get_file_as_bytes(f)
		var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8)
		ims.append(im)
	var w: int = ims[0].get_width(); var h: int = ims[0].get_height()
	var 행: int = int(ceil(float(ims.size()) / float(열)))
	var 판 := Image.create(w * 열, h * 행, false, Image.FORMAT_RGBA8)
	for i in ims.size():
		판.blit_rect(ims[i], Rect2i(0,0,w,h), Vector2i((i % 열) * w, (i / 열) * h))
	판.save_png(ProjectSettings.globalize_path(out))
	print("stitch %s %dx%d" % [out, 판.get_width(), 판.get_height()])
	quit()
