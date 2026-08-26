extends SceneTree
## [2026-08-26 임시] 원화 PNG 의 한 구간만 잘라 확대 저장 — 좌표를 눈으로 재려고 만들었다.
## 실행: Godot --headless --path . -s res://tools/원화_잘라보기.gd -- <png> <저장.png> <x> <y> <w> <h> [배율]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 6:
		print("사용법: -- <png> <저장> <x> <y> <w> <h> [배율]")
		quit(2)
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(a[0]))
	if img == null:
		print("못 읽음: ", a[0])
		quit(2)
		return
	print("원본 크기 %d x %d" % [img.get_width(), img.get_height()])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var 잘림 := img.get_region(r)
	var 배율 := float(a[6]) if a.size() > 6 else 1.0
	if 배율 != 1.0:
		잘림.resize(int(잘림.get_width() * 배율), int(잘림.get_height() * 배율),
			Image.INTERPOLATE_LANCZOS)
	# 어두운 원화라 그냥 보면 안 보인다 — 감마를 올려 형태만 드러낸다.
	잘림.adjust_bcs(3.4, 1.15, 1.0)
	print("자름 ", r, " → ", 잘림.get_width(), "x", 잘림.get_height(),
		" 저장 ", error_string(잘림.save_png(a[1])))
	quit(0)
