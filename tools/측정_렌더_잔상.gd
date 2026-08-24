extends SceneTree
## 렌더 결과에서 '배경보다 어두워진 정도'를 증폭해 보여준다.
## 완전 불투명한 지형(어두움)은 흰색으로 포화되므로, 관심은 **회색 영역**이다.
## 회색 = 반투명 잔상(후광). 동시에 수치도 낸다.
func _init(): call_deferred("_go")
func _go():
	var out := "res://tools/_shots/고스트맵.png"
	var 목록 := []
	var 배경 := 0.72
	var 증폭 := 6.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--im="): 목록.append(a.substr("--im=".length()))
		elif a.begins_with("--출력="): out = a.substr("--출력=".length())
		elif a.begins_with("--증폭="): 증폭 = a.substr("--증폭=".length()).to_float()
	var ims := []
	for f in 목록:
		var b := FileAccess.get_file_as_bytes(f)
		var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8)
		var W := im.get_width(); var H := im.get_height()
		var o := Image.create(W, H, false, Image.FORMAT_RGBA8)
		var 반투명 := 0
		var 합 := 0.0
		for y in H:
			for x in W:
				var d: float = 배경 - im.get_pixel(x, y).r
				# 반투명 잔상 = 배경보다 어둡지만 완전한 지형은 아닌 구간
				if d > 0.02 and d < 0.45:
					반투명 += 1
					합 += d
				var v: float = clampf(d * 증폭 / 배경, 0.0, 1.0)
				o.set_pixel(x, y, Color(v, v, v, 1.0))
		print("%-34s 반투명 픽셀 %6d (%.2f%%)  평균 어두워짐 %.3f"
			% [f.get_file(), 반투명, 100.0*float(반투명)/float(W*H), 합/maxf(반투명,1)])
		ims.append(o)
	if ims.is_empty(): quit(); return
	var w: int = ims[0].get_width(); var h: int = ims[0].get_height()
	var 열: int = 2
	var 행: int = int(ceil(float(ims.size())/float(열)))
	var 판 := Image.create(w*열, h*행, false, Image.FORMAT_RGBA8)
	for i in ims.size():
		판.blit_rect(ims[i], Rect2i(0,0,w,h), Vector2i((i%열)*w, (i/열)*h))
	판.save_png(ProjectSettings.globalize_path(out))
	print("%s %dx%d" % [out, 판.get_width(), 판.get_height()])
	quit()
