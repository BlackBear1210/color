extends SceneTree
## ============================================================================
## [2026-08-24 신규] assets/tileset/brick.png (768x768 4분할 시트) 구조 측정 (읽기 전용)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/측정_brick_시트.gd
##
## ▣ 왜
##   BRICK 원본이 마스터 템플릿 규격(1024x256 TOP 등)에 못 미친다.
##   그렇다면 이 시트에서 **띠를 뽑아낼 수 있는지**를 수치로 판단해야 한다.
##   "그림이 있으니 되겠지" 로 넘어가면 나중에 해상도에서 터진다.
##
## ▣ 재는 것 (사분면마다)
##   알파 바운딩 박스 / 블록 크기
##   위쪽 '캡'(튀어나온 윗단) 높이 — 행 폭이 급변하는 지점으로 찾는다
##   옆면 벽돌단 두께 — 아래쪽에서 좌우 불투명 두께
##   블록 폭이 1024 띠로 쓰일 때 필요한 확대 배율
## ============================================================================

const 경로 := "res://assets/tileset/brick.png"


func _init() -> void:
	call_deferred("_실행")


func _png(p: String) -> Image:
	var b := FileAccess.get_file_as_bytes(p)
	if b.is_empty():
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## 사분면 안에서 알파>0.5 인 영역의 바운딩 박스
func _박스(im: Image, x0: int, y0: int, w: int, h: int) -> Array:
	var minx := 1 << 30; var maxx := -1
	var miny := 1 << 30; var maxy := -1
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if im.get_pixel(x, y).a > 0.5:
				minx = mini(minx, x); maxx = maxi(maxx, x)
				miny = mini(miny, y); maxy = maxi(maxy, y)
	return [minx, miny, maxx, maxy]


## 행마다 불투명 픽셀 폭. 캡(윗단)은 아래 몸통보다 넓다.
func _행폭(im: Image, 박스: Array) -> PackedInt32Array:
	var r := PackedInt32Array()
	for y in range(박스[1], 박스[3] + 1):
		var c := 0
		for x in range(박스[0], 박스[2] + 1):
			if im.get_pixel(x, y).a > 0.5:
				c += 1
		r.push_back(c)
	return r


func _실행() -> void:
	var im := _png(경로)
	if im == null:
		push_error("읽기 실패")
		quit(1)
		return
	print("=".repeat(96))
	print("brick.png 시트 구조 측정  (%d x %d)" % [im.get_width(), im.get_height()])
	print("=".repeat(96))
	var 이름 := ["좌상 BLACK 꽉참", "우상 WHITE 꽉참", "좌하 BLACK 테두리", "우하 WHITE 테두리"]
	var qi := 0
	for qy in 2:
		for qx in 2:
			var 박스 := _박스(im, qx * 384, qy * 384, 384, 384)
			if 박스[2] < 0:
				print("\n[%s] 비어 있음" % 이름[qi])
				qi += 1
				continue
			var bw: int = 박스[2] - 박스[0] + 1
			var bh: int = 박스[3] - 박스[1] + 1
			var 폭들 := _행폭(im, 박스)
			# 캡 = 위에서부터 폭이 최대폭의 95% 이상인 연속 구간이 끝나는 지점
			var 최대폭 := 0
			for v in 폭들:
				최대폭 = maxi(최대폭, v)
			var 캡 := 0
			for i in 폭들.size():
				if 폭들[i] >= int(float(최대폭) * 0.95):
					캡 = i + 1
				else:
					break
			# 몸통 폭 = 캡 아래 구간의 중앙값 폭
			var 몸통 := 폭들[mini(폭들.size() - 1, 캡 + 20)] if 폭들.size() > 캡 + 20 else 최대폭
			print("\n[%s]" % 이름[qi])
			print("  블록 박스     x %d~%d, y %d~%d   크기 %d x %d" % [박스[0], 박스[2], 박스[1], 박스[3], bw, bh])
			print("  최대 폭       %d px (캡)   캡 높이 %d px" % [최대폭, 캡])
			print("  몸통 폭       %d px" % 몸통)
			print("  -> 1024 폭 TOP 띠로 쓰려면 가로 %.2f 배 확대 필요" % (1024.0 / float(최대폭)))
			print("  -> 256 높이 TOP 띠로 쓰려면 캡을 세로 %.2f 배 확대 필요"
				% (256.0 / maxf(1.0, float(캡))))
			qi += 1
	print("\n" + "=".repeat(96))
	print("판단 기준: 마스터 템플릿 TOP = 1024 x 256 (알파 실루엣 있음)")
	print("           확대 배율이 2배를 넘으면 일러스트 디테일이 아니라 뭉갬이 된다")
	print("=".repeat(96))
	quit(0)
