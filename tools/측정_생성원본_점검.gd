extends SceneTree
func _init(): call_deferred("_go")
func _go():
	var 목록 := []
	var out := "res://tools/_shots/raw.png"
	var 폭 := 820
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--im="): 목록.append(a.substr("--im=".length()))
		elif a.begins_with("--출력="): out = a.substr("--출력=".length())
	var 판들 := []
	var H := 0
	for p in 목록:
		var b := FileAccess.get_file_as_bytes(p)
		if b.is_empty(): print("없음 %s" % p); continue
		var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8)
		var W0 := im.get_width(); var H0 := im.get_height()
		# 마젠타 비율 · 실루엣 중앙값 · 그림 평균휘도
		var 키 := 0; var 휘도 := 0.0; var 그림 := 0
		var 첫 := PackedInt32Array()
		for x in W0:
			var f := false
			for y in H0:
				var c := im.get_pixel(x, y)
				if minf(c.r, c.b) - c.g > 0.15: 키 += 1
				else:
					그림 += 1; 휘도 += c.g
					if not f: 첫.push_back(y); f = true
		첫.sort()
		var 중 := 첫[첫.size()/2] if not 첫.is_empty() else -1
		# 채도(무채색인가) — 최대채널-최소채널 평균
		var 채도 := 0.0
		for y in range(0, H0, 7):
			for x in range(0, W0, 7):
				var c := im.get_pixel(x, y)
				if minf(c.r, c.b) - c.g > 0.15: continue
				채도 += maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
		채도 = 채도 / maxf(float((H0/7)*(W0/7)), 1.0) * 255.0
		print("%s\n   %dx%d 비율 %.2f | 마젠타 %.1f%% | 실루엣 중앙 y=%d (%.0f%%) | 그림휘도 %.0f | 채도 %.1f"
			% [p.get_file(), W0, H0, float(W0)/float(H0), 100.0*float(키)/float(W0*H0),
				중, 100.0*float(중)/float(H0), 휘도/maxf(그림,1)*255.0, 채도])
		var h: int = int(round(float(H0) * float(폭) / float(W0)))
		var s: Image = im.duplicate(); s.resize(폭, h, Image.INTERPOLATE_LANCZOS)
		var o := Image.create(폭, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in 폭:
				var c := s.get_pixel(x, y)
				if minf(c.r, c.b) - c.g > 0.15:
					var k: float = 0.30 if ((x/14 + y/14) % 2 == 0) else 0.40
					o.set_pixel(x, y, Color(k, k*0.85, k*1.2, 1.0))
				else:
					o.set_pixel(x, y, Color(c.g, c.g, c.g, 1.0))
		판들.append(o); H += h + 20
	if 판들.is_empty(): quit(); return
	var 판 := Image.create(폭, H, false, Image.FORMAT_RGBA8)
	판.fill(Color(0.06,0.06,0.08))
	var y0 := 0
	for p in 판들:
		판.blit_rect(p, Rect2i(0,0,p.get_width(),p.get_height()), Vector2i(0, y0))
		y0 += p.get_height() + 20
	판.save_png(ProjectSettings.globalize_path(out))
	print("\n저장 %s %dx%d" % [out, 판.get_width(), 판.get_height()])
	quit()
