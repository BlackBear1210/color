extends SceneTree
## [2026-09-05 신규] 스크린샷 여러 장에서 같은 영역을 잘라 한 장으로 이어 붙인다.
## 비주얼 판단은 "옆에 놓고 보는 것"이 전부라, 눈으로 비교할 판을 만드는 도구.
##
## 실행:
##   godot --headless --path . -s res://tools/이미지_비교판.gd -- \
##          <저장.png> <x> <y> <w> <h> <가로|세로> <입력1.png> <입력2.png> ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 8:
		push_error("사용법: -- <저장> <x> <y> <w> <h> <가로|세로> <입력...>")
		quit(1); return
	var 저장 := a[0]
	var r := Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
	var 가로 := a[5] == "가로"
	var 조각: Array[Image] = []
	for i in range(6, a.size()):
		var img := Image.load_from_file(a[i])
		if img == null:
			push_error("못 읽음: %s" % a[i]); continue
		var cr := r
		cr.size.x = mini(cr.size.x, img.get_width() - cr.position.x)
		cr.size.y = mini(cr.size.y, img.get_height() - cr.position.y)
		조각.append(img.get_region(cr))
	if 조각.is_empty():
		quit(1); return
	var 간격 := 8
	var w := 0
	var h := 0
	for im in 조각:
		if 가로:
			w += im.get_width() + 간격
			h = maxi(h, im.get_height())
		else:
			w = maxi(w, im.get_width())
			h += im.get_height() + 간격
	var 판 := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	판.fill(Color(0.85, 0.2, 0.2))   # 경계가 눈에 띄게 빨강
	var p := 0
	for im in 조각:
		if 가로:
			판.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(p, 0))
			p += im.get_width() + 간격
		else:
			판.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(0, p))
			p += im.get_height() + 간격
	print("비교판: ", error_string(판.save_png(저장)), " -> ", 저장)
	quit()
