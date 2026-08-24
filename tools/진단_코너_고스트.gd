extends SceneTree
## ============================================================================
## [2026-08-25 신규] 코너 고스트(후광) 진단 — 추측 금지, 알파를 직접 센다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/진단_코너_고스트.gd -- \
##       --폴더=res://assets/textures/smartshape/brick_v1 [--테마=black]
##   여러 폴더를 --폴더= 로 반복해서 주면 나란히 비교한다.
##
## ▣ 재는 것
##   A. 코너 PNG 알파 분포 (0 / 반투명 구간별 / 255)
##   B. '실루엣 밖' 잔여 알파의 바운딩 박스 — 반지름 정규화 r/S 기준
##   C. 반지름 구간별 평균 알파 + 반투명(0<a<128) 픽셀 비율
##   D. OUTER / INNER 따로
##   E. 엣지 텍스처의 행별 알파 프로파일 (코너는 여기서 만들어진다)
##
## ▣ 판정 기준
##   grass_v4 는 실제로 눈으로 승인된 LOCK 에셋이다. 그래서 '절대 수치'가 아니라
##   **grass_v4 대비 얼마나 반투명이 더 많은가** 를 본다.
## ============================================================================

var _폴더들: PackedStringArray = PackedStringArray()
var _테마 := "black"
var _접두어 := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--폴더="):
			_폴더들.push_back(a.substr("--폴더=".length()).rstrip("/"))
		elif a.begins_with("--테마="):
			_테마 = a.substr("--테마=".length())
		elif a.begins_with("--접두어="):
			_접두어 = a.substr("--접두어=".length())
	call_deferred("_실행")


func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## 알파 히스토그램 (백분율)
func _히스토(im: Image) -> String:
	var n := im.get_width() * im.get_height()
	var b := [0, 0, 0, 0, 0, 0]   # 0 / 1-31 / 32-95 / 96-159 / 160-247 / 248-255
	for y in im.get_height():
		for x in im.get_width():
			var a: int = int(round(im.get_pixel(x, y).a * 255.0))
			if a == 0: b[0] += 1
			elif a < 32: b[1] += 1
			elif a < 96: b[2] += 1
			elif a < 160: b[3] += 1
			elif a < 248: b[4] += 1
			else: b[5] += 1
	var p := PackedStringArray()
	for v in b:
		p.push_back("%5.2f%%" % (100.0 * float(v) / float(n)))
	return "a=0 %s | 1-31 %s | 32-95 %s | 96-159 %s | 160-247 %s | 248+ %s" % [
		p[0], p[1], p[2], p[3], p[4], p[5]]


## 코너의 극좌표 원점: OUTER = 좌하단(0,S), INNER = 우상단(S,0)
func _반지름(im: Image, x: int, y: int, 바깥: bool) -> float:
	var S := float(im.get_width())
	var dx: float
	var dy: float
	if 바깥:
		dx = float(x) + 0.5
		dy = S - (float(y) + 0.5)
	else:
		dx = S - (float(x) + 0.5)
		dy = float(y) + 0.5
	return sqrt(dx * dx + dy * dy) / S


## 반지름 구간별 평균 알파 / 반투명 비율
func _반지름프로파일(im: Image, 바깥: bool) -> void:
	var 구간 := 20
	var 합 := PackedFloat64Array(); 합.resize(구간)
	var 수 := PackedInt32Array(); 수.resize(구간)
	var 반투명 := PackedInt32Array(); 반투명.resize(구간)
	for y in im.get_height():
		for x in im.get_width():
			var rn := _반지름(im, x, y, 바깥)
			var i: int = clampi(int(rn * float(구간) / 1.45), 0, 구간 - 1)
			var a := im.get_pixel(x, y).a
			합[i] += a
			수[i] += 1
			if a > 0.004 and a < 0.502:
				반투명[i] += 1
	print("      r/S      평균알파   반투명(0<a<128) 비율")
	for i in 구간:
		if 수[i] == 0:
			continue
		var r0 := float(i) * 1.45 / float(구간)
		var r1 := float(i + 1) * 1.45 / float(구간)
		print("      %.3f~%.3f  %6.1f    %6.2f%%  (%d px)" % [
			r0, r1, 합[i] / float(수[i]) * 255.0, 100.0 * float(반투명[i]) / float(수[i]), 수[i]])


## '실루엣 밖' 잔여 알파: 각도별로 가장 바깥의 a>=128 반지름을 실루엣으로 보고,
## 그보다 밖에 있는 0<a<128 픽셀의 개수와 r/S 최대값을 잰다.
func _실루엣밖(im: Image, 바깥: bool) -> void:
	var S := im.get_width()
	var 각도수 := 90
	var 실루엣 := PackedFloat64Array(); 실루엣.resize(각도수)
	# 1차: 각도별 실루엣 반지름
	for y in S:
		for x in S:
			if im.get_pixel(x, y).a < 0.502:
				continue
			var rn := _반지름(im, x, y, 바깥)
			var phi := _각도(im, x, y, 바깥)
			var ai: int = clampi(int(phi / (PI * 0.5) * float(각도수)), 0, 각도수 - 1)
			if rn > 실루엣[ai]:
				실루엣[ai] = rn
	# 2차: 실루엣 밖 잔여
	var 밖수 := 0
	var 밖합 := 0.0
	var 최대r := 0.0
	var minx := S; var miny := S; var maxx := -1; var maxy := -1
	for y in S:
		for x in S:
			var a := im.get_pixel(x, y).a
			if a <= 0.004:
				continue
			var rn := _반지름(im, x, y, 바깥)
			var phi := _각도(im, x, y, 바깥)
			var ai: int = clampi(int(phi / (PI * 0.5) * float(각도수)), 0, 각도수 - 1)
			if rn <= 실루엣[ai] + 0.004:
				continue
			밖수 += 1
			밖합 += a
			최대r = maxf(최대r, rn)
			minx = mini(minx, x); maxx = maxi(maxx, x)
			miny = mini(miny, y); maxy = maxi(maxy, y)
	var 실합 := 0.0
	for v in 실루엣:
		실합 += v
	print("      실루엣 평균 r/S %.3f   실루엣 밖 잔여 알파 픽셀 %d (%.3f%%)"
		% [실합 / float(각도수), 밖수, 100.0 * float(밖수) / float(S * S)])
	if 밖수 > 0:
		print("        평균 알파 %.1f/255  최대 r/S %.3f  bbox (%d,%d)-(%d,%d) = %dx%d px"
			% [밖합 / float(밖수) * 255.0, 최대r, minx, miny, maxx, maxy,
				maxx - minx + 1, maxy - miny + 1])


func _각도(im: Image, x: int, y: int, 바깥: bool) -> float:
	var S := float(im.get_width())
	if 바깥:
		return atan2(S - (float(y) + 0.5), maxf(float(x) + 0.5, 1e-6))
	return atan2(maxf(S - (float(x) + 0.5), 1e-6), maxf(float(y) + 0.5, 1e-6))


## 엣지 행별 알파 프로파일 — 코너의 재료가 어떤 상태인지 본다
func _엣지프로파일(im: Image, 이름: String) -> void:
	var W := im.get_width()
	var H := im.get_height()
	var 구간 := 16
	var 줄 := PackedStringArray()
	for i in 구간:
		var y0: int = int(float(i) * float(H) / float(구간))
		var y1: int = int(float(i + 1) * float(H) / float(구간))
		var s := 0.0
		var n := 0
		for y in range(y0, y1):
			for x in W:
				s += im.get_pixel(x, y).a
				n += 1
		줄.push_back("%3.0f" % (s / float(n) * 255.0))
	# 완전투명/반투명 총비율
	var z := 0; var h := 0
	for y in H:
		for x in W:
			var a := im.get_pixel(x, y).a
			if a <= 0.004: z += 1
			elif a < 0.502: h += 1
	print("    %-12s %dx%d  행평균알파(바깥→안쪽): %s"
		% [이름, W, H, " ".join(줄)])
	print("                 완전투명 %.1f%%  반투명 %.1f%%"
		% [100.0 * float(z) / float(W * H), 100.0 * float(h) / float(W * H)])


func _실행() -> void:
	if _폴더들.is_empty():
		push_error("--폴더= 가 필요하다")
		quit(1)
		return
	for f in _폴더들:
		print("\n================ %s  (%s) ================" % [f, _테마])
		for 이름 in ["edge_top", "edge_right"]:
			var e := _png("%s/%s/%s%s.png" % [f, _테마, _접두어, 이름])
			if e != null:
				_엣지프로파일(e, 이름)
		for 쌍 in [["corner_outer", true], ["corner_inner", false]]:
			var c := _png("%s/%s/%s%s.png" % [f, _테마, _접두어, 쌍[0]])
			if c == null:
				print("  %s 없음" % 쌍[0])
				continue
			print("\n  --- %s  %dx%d ---" % [쌍[0], c.get_width(), c.get_height()])
			print("    %s" % _히스토(c))
			_실루엣밖(c, 쌍[1])
			_반지름프로파일(c, 쌍[1])
	quit(0)
