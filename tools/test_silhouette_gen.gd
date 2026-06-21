extends SceneTree
## ▼ 2026-06-22 (실루엣 도구 검증용) 테스트 '시트' 생성:
##   흰 배경 + 어두운 사각형(→BLACK) + 밝은 사각형(→WHITE) + 작은 점(노이즈, 버려져야).
##   실행: godot --headless --path . -s res://tools/test_silhouette_gen.gd
const IN_DIR := "res://scenes/지형파일셋/원본이미지/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IN_DIR))
	var img := Image.create(240, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))                     # 흰 배경
	_rect(img, 20, 40, 40, 40, Color(0.2,0.2,0.2))  # 어두운 조각 → BLACK
	_rect(img, 150, 40, 40, 40, Color(0.8,0.8,0.8)) # 밝은 조각 → WHITE
	_rect(img, 110, 10, 4, 4, Color(0.3,0.3,0.3))   # 작은 점(노이즈)
	print("테스트 시트 저장: ", img.save_png(IN_DIR + "_test_sheet.png"))
	quit(0)
func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			img.set_pixel(x + i, y + j, c)
