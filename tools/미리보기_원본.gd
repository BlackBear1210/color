extends SceneTree
## [2026-08-25 신규] master_*.png 4장을 한 장으로 붙여 보여준다 (원본 디자인 검토용).
## 마젠타 배경은 체크무늬로 바꿔 실루엣 경계가 눈에 보이게 한다.
var _재질 := "brick_v1"
var _출력 := ""
var _폭 := 900

func _init():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--재질="): _재질 = a.substr("--재질=".length())
		elif a.begins_with("--출력="): _출력 = a.substr("--출력=".length())
		elif a.begins_with("--폭="): _폭 = a.substr("--폭=".length()).to_int()
	call_deferred("_go")

func _im(p: String) -> Image:
	var b := FileAccess.get_file_as_bytes(p)
	if b.is_empty(): return null
	var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8); return im

## 마젠타를 체크무늬로 치환 + 그레이스케일(G 채널)로 표시
func _준비(im: Image, w: int) -> Image:
	var h: int = int(round(float(im.get_height()) * float(w) / float(im.get_width())))
	var s: Image = im.duplicate()
	s.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var o := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := s.get_pixel(x, y)
			var m: float = minf(c.r, c.b) - c.g
			if m > 0.15:
				var chk: float = 0.30 if ((x / 16 + y / 16) % 2 == 0) else 0.38
				o.set_pixel(x, y, Color(chk, chk * 0.9, chk * 1.15, 1.0))   # 푸른 체크 = 배경
			else:
				o.set_pixel(x, y, Color(c.g, c.g, c.g, 1.0))
	return o

func _go():
	var 이름 := ["top", "side", "bottom", "fill"]
	var 판들 := []
	var 총높이 := 0
	for n in 이름:
		var im := _im("res://tools/%s_pipeline/src/master_%s.png" % [_재질, n])
		if im == null:
			print("없음: master_%s" % n); continue
		var p := _준비(im, _폭)
		판들.append([n, p])
		총높이 += p.get_height() + 26
	var 판 := Image.create(_폭, 총높이, false, Image.FORMAT_RGBA8)
	판.fill(Color(0.08, 0.08, 0.10))
	var y := 0
	for it in 판들:
		var p: Image = it[1]
		# 라벨 자리 대신 왼쪽에 밝기 막대로 구분선
		판.blit_rect(p, Rect2i(0, 0, p.get_width(), p.get_height()), Vector2i(0, y + 26))
		y += p.get_height() + 26
		print("  %-7s %d x %d" % [it[0], p.get_width(), p.get_height()])
	var out := _출력 if not _출력.is_empty() else "res://tools/_shots/원본_%s.png" % _재질
	var 절대 := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	판.save_png(절대)
	print("저장 %s  (%dx%d) — 위에서부터 top / side / bottom / fill" % [out, 판.get_width(), 판.get_height()])
	quit()
