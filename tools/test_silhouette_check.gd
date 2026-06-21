extends SceneTree
## ▼ 2026-06-22 (실루엣 도구 검증용) 조각분리+흑백자동 결과 검사.
##   기대: _test_sheet_01.png(검정 조각), _02.png(흰 조각) 2개만. 노이즈 점은 없음.
const OUT := "res://scenes/지형파일셋/실루엣/"
func _initialize() -> void:
	var d := DirAccess.open(OUT)
	var pieces := []
	for f in d.get_files():
		if f.begins_with("_test_sheet_") and f.ends_with(".png"):
			pieces.append(f)
	pieces.sort()
	print("생성된 조각 = ", pieces)
	var fail := 0
	if pieces.size() != 2:
		fail += 1
		print("조각 수 = ", pieces.size(), " (기대 2 — 노이즈 점은 버려져야)")
	var colors := []
	for f in pieces:
		var img := Image.load_from_file(OUT + f)
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var c := img.get_pixel(img.get_width()/2, img.get_height()/2)
		var kind := "WHITE" if c.r > 0.9 else ("BLACK" if c.r < 0.1 else "?")
		colors.append(kind)
		print(f, " 중심색 = ", c, " => ", kind, " (a≈1 기대)")
		if c.a < 0.9:
			fail += 1
	# 어두운 조각(좌측, 먼저 스캔)=BLACK, 밝은 조각=WHITE 여야
	if colors.size() == 2 and not (colors.has("BLACK") and colors.has("WHITE")):
		fail += 1
		print("흑백 자동판정 실패: ", colors, " (BLACK,WHITE 각 1개 기대)")
	print("SILHOUETTE_CHECK => ", "OK" if fail == 0 else "FAIL")
	quit(0 if fail == 0 else 1)
