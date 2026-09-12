extends SceneTree
## [2026-09-05 신규] 스크린샷 일부를 잘라 정수배로 확대한다 (UI 디테일 육안 검수용).
## 실행: -- <저장.png> <x> <y> <w> <h> <배율> <입력.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 7:
		push_error("사용법: -- <저장> <x> <y> <w> <h> <배율> <입력>"); quit(1); return
	var img := Image.load_from_file(a[6])
	if img == null: push_error("못 읽음"); quit(1); return
	var r := Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
	r.size.x = mini(r.size.x, img.get_width() - r.position.x)
	r.size.y = mini(r.size.y, img.get_height() - r.position.y)
	var sub := img.get_region(r)
	var m := int(a[5])
	sub.resize(sub.get_width() * m, sub.get_height() * m, Image.INTERPOLATE_NEAREST)
	print("확대: ", error_string(sub.save_png(a[0])), " -> ", a[0])
	quit()
