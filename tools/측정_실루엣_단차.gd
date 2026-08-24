extends SceneTree
## ============================================================================
## [2026-08-24 신규] 렌더된 화면에서 "축정렬 직선 단차" 를 찾아내는 도구 (읽기 전용)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/측정_실루엣_단차.gd -- \
##       --그림=<절대경로.png> --줌=2.5 [--이름=라벨]
##   (--그림 을 여러 번 줄 수 있다)
##
## ▣ 왜 필요한가
##   코너 자리에 사각 타일 경계가 보인다는 걸 눈으로는 알겠는데, 그건 근거가 약하다.
##   손으로 그린 잔디 실루엣에는 **완벽하게 수평/수직인 긴 구간이 존재하지 않는다.**
##   그러니 실루엣에서 축정렬 직선 구간의 길이를 재면, 사람 눈의 인상이 아니라
##   수치로 "여기 인공적인 직선 단차가 있다" 를 말할 수 있다.
##
## ▣ 재는 법
##   배경색과 다른 픽셀 = 지형. 지형이면서 위쪽 이웃이 배경이면 '윗 실루엣'.
##   윗 실루엣이 같은 y 로 연속되는 최대 구간 = 수평 직선 단차.
##   오른쪽 이웃이 배경인 '오른 실루엣' 이 같은 x 로 연속되는 최대 구간 = 수직 직선 단차.
##   화면 px 를 줌으로 나누면 월드 px 가 된다.
## ============================================================================

var _그림들: Array[String] = []
var _이름들: Array[String] = []
var _줌 := 1.0
## --평범창=x0,x1  --관심창=x0,x1 (화면 px). 둘 다 주면 디테일 비교를 한다.
var _평범창: PackedInt32Array = PackedInt32Array()
var _관심창: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--그림="):
			_그림들.push_back(a.substr("--그림=".length()))
		elif a.begins_with("--이름="):
			_이름들.push_back(a.substr("--이름=".length()))
		elif a.begins_with("--줌="):
			_줌 = a.substr("--줌=".length()).to_float()
		elif a.begins_with("--평범창="):
			_평범창 = _두수(a.substr("--평범창=".length()))
		elif a.begins_with("--관심창="):
			_관심창 = _두수(a.substr("--관심창=".length()))
	call_deferred("_실행")


func _두수(s: String) -> PackedInt32Array:
	var p := s.split(",")
	if p.size() != 2:
		return PackedInt32Array()
	return PackedInt32Array([p[0].to_int(), p[1].to_int()])


func _png(경로: String) -> Image:
	var f := FileAccess.open(경로, FileAccess.READ)
	if f == null:
		push_error("열기 실패: %s" % 경로)
		return null
	var b := f.get_buffer(f.get_length())
	f.close()
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		push_error("디코드 실패: %s" % 경로)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


## 배경색은 화면 네 귀퉁이에서 자동으로 잡는다 (테스트 씬은 단색 배경이다).
func _배경색(im: Image) -> Color:
	return im.get_pixel(2, 2)


func _배경인가(c: Color, bg: Color) -> bool:
	return absf(c.r - bg.r) < 0.02 and absf(c.g - bg.g) < 0.02 and absf(c.b - bg.b) < 0.02


func _측정(경로: String, 이름: String) -> void:
	var im := _png(경로)
	if im == null:
		return
	var W := im.get_width()
	var H := im.get_height()
	var bg := _배경색(im)

	# 윗 실루엣: 지형이면서 바로 위가 배경인 픽셀. 열마다 y 를 기록한다.
	var 윗 := PackedInt32Array()
	윗.resize(W)
	for x in W:
		윗[x] = -1
		for y in range(1, H):
			if not _배경인가(im.get_pixel(x, y), bg) and _배경인가(im.get_pixel(x, y - 1), bg):
				윗[x] = y
				break

	# 오른 실루엣: 지형이면서 바로 오른쪽이 배경인 픽셀. 행마다 x 를 기록한다.
	var 오른 := PackedInt32Array()
	오른.resize(H)
	for y in H:
		오른[y] = -1
		for x in range(W - 2, 0, -1):
			if not _배경인가(im.get_pixel(x, y), bg) and _배경인가(im.get_pixel(x + 1, y), bg):
				오른[y] = x
				break

	var h최대 := _최대연속(윗)
	var v최대 := _최대연속(오른)
	var 내부 := _내부이음매(im, bg)
	print("  %-18s 실루엣: 수평 %4d px(월드 %5.1f) 수직 %4d px(월드 %5.1f)"
		% [이름, h최대[0], float(h최대[0]) / _줌, v최대[0], float(v최대[0]) / _줌])
	print("  %-18s 내부이음매: 가로선 z %5.1f @y=%4d (기울기 %4.1f/255)   세로선 z %5.1f @x=%4d (기울기 %4.1f/255)"
		% ["", 내부[0], 내부[1], 내부[2], 내부[3], 내부[4], 내부[5]])
	var 단 := _열단차(im, bg)
	print("  %-18s ★열평균 단차: 최대 %5.2f/255 @x=%4d   (중앙값 %4.2f, 배수 %4.1fx)  %s"
		% ["", 단[0], 단[1], 단[2], 단[0] / maxf(단[2], 0.001),
			"PASS" if 단[0] < 6.0 else "FAIL"])
	# 창을 인자로 받았을 때만 디테일 비교를 한다 (창이 없으면 의미 없는 수치가 나온다)
	if _평범창.size() == 2 and _관심창.size() == 2:
		var 평 := _디테일(im, bg, _평범창[0], _평범창[1])
		var 관 := _디테일(im, bg, _관심창[0], _관심창[1])
		var 비: float = 관 / maxf(평, 0.001)
		print("  %-18s ★디테일: 평범한 띠 %5.2f  코너/taper 구간 %5.2f  (비율 %4.2f)  %s"
			% ["", 평, 관, 비, "PASS" if 비 > 0.60 else "FAIL(뭉갬)"])


## 불투명한 지형 **안쪽**에서 축정렬 직선 이음매를 찾는다.
##
## 실루엣(바깥 윤곽)이 깨끗해도 쿼드 경계는 안쪽 톤 단차로 드러날 수 있다.
##
## ★ '임계를 넘는 픽셀이 연속되는가' 로 재면 안 된다 — 잔디 잎사귀 한 획이
##   50px 씩 이어지기 때문에 대조군(그냥 직선 엣지)이 코너보다 더 큰 값이 나온다.
##   (실제로 그렇게 재서 한 번 헛짚었다)
##
## 대신 **행 전체의 평균 세로 기울기** 를 본다.
## 쿼드 경계는 그 행에 있는 거의 모든 픽셀이 동시에 튀는 자리다.
## 그림의 붓질은 한 행 전체를 동시에 밝히지 못한다.
## 판정은 중앙값 대비 MAD z점수로 한다 (밝기 절대값에 안 휘둘리게).
func _z점수(g: PackedFloat64Array, n: PackedInt32Array, 최소표본: int) -> Array:
	var 유효 := PackedFloat64Array()
	for i in g.size():
		if n[i] >= 최소표본:
			유효.push_back(g[i])
	if 유효.size() < 8:
		return [0.0, 0, 0.0]
	var 정렬 := 유효.duplicate()
	정렬.sort()
	var 중앙 := 정렬[정렬.size() / 2]
	var 편차 := PackedFloat64Array()
	for v in 유효:
		편차.push_back(absf(v - 중앙))
	편차.sort()
	var mad: float = maxf(편차[편차.size() / 2], 1e-6)
	var 최대z := 0.0
	var 최대i := 0
	for i in g.size():
		if n[i] < 최소표본:
			continue
		var z: float = (g[i] - 중앙) / (1.4826 * mad)
		if z > 최대z:
			최대z = z
			최대i = i
	return [최대z, 최대i, g[최대i] * 255.0]


## ★ 이음매를 재는 가장 정직한 지표 — 열 평균 밝기의 단차.
##
## 지금까지 쓰던 "픽셀 기울기의 평균" 은 잔디 잎사귀(세로 획)가 그대로 섞여 들어와서
## 대조군(그냥 직선 엣지)에서도 9.6/255 이 나온다. 즉 분해능이 없다.
##
## 열마다 밝기를 **평균내면** 고주파 붓질은 서로 상쇄되고
## "이 열과 다음 열 사이에 체계적인 톤 단차가 있는가" 만 남는다.
## 타일 경계는 한 열에서 다음 열로 넘어갈 때 그림이 통째로 바뀌므로 여기서 튄다.
## 잔디 그림은 아무리 복잡해도 열 평균이 한 칸에 확 뛰지 않는다.
##
## 반환: [최대단차/255, 그 x, 단차 중앙값/255]
## ★ 배경을 포함해서 열 평균을 내면 안 된다.
##   지형이 끝나는 자리(볼록 코너 바깥 등)에서는 열의 지형 면적 자체가 확 줄어서
##   '텍스처 이음매' 가 아니라 '도형이 끝난 것' 을 재게 된다.
##   잔디는 실루엣이 부드러워 티가 안 났지만, 벽돌은 실루엣이 직선이라
##   이 오염이 20~35/255 로 나와서 이음매 판정을 통째로 망친다 (실제로 겪음).
##
##   그래서 **양쪽 열 모두 지형인 행만** 골라 평균을 낸다.
##   표본이 너무 적은 열 쌍은 아예 판정에서 뺀다.
func _열단차(im: Image, bg: Color) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	var 단차 := PackedFloat64Array()
	var 최대 := 0.0
	var 최대x := 0
	var 최소표본: int = maxi(8, H / 12)
	for x in range(W - 1):
		var s0 := 0.0
		var s1 := 0.0
		var n := 0
		for y in H:
			var a := im.get_pixel(x, y)
			var b := im.get_pixel(x + 1, y)
			if _배경인가(a, bg) or _배경인가(b, bg):
				continue
			s0 += a.r
			s1 += b.r
			n += 1
		if n < 최소표본:
			continue
		var d: float = absf(s1 - s0) / float(n) * 255.0
		단차.push_back(d)
		if d > 최대:
			최대 = d
			최대x = x
	if 단차.is_empty():
		return [0.0, 0, 0.0]
	단차.sort()
	return [최대, 최대x, 단차[단차.size() / 2]]


## 지정한 x 구간에서 지형 픽셀의 고주파 에너지(세로 이웃 차) 평균.
## 같은 그림 안의 '평범한 띠 구간' 과 '코너/taper 구간' 을 비교해야 의미가 있다.
## (그림 전체에서 최저 구간을 찾는 방식은 화면 가장자리를 집어서 못 쓴다 — 한 번 겪음)
func _디테일(im: Image, bg: Color, x0: int, x1: int) -> float:
	var H := im.get_height()
	var s := 0.0
	var c := 0
	for x in range(maxi(0, x0), mini(im.get_width(), x1)):
		for y in range(1, H - 1):
			var a := im.get_pixel(x, y)
			var b := im.get_pixel(x, y + 1)
			if _배경인가(a, bg) or _배경인가(b, bg):
				continue
			s += absf(a.r - b.r) * 255.0
			c += 1
	return s / maxf(1.0, float(c))


## ★ 열평균 단차만 보면 안 된다 — 그 지표는 "톤이 이어지는가" 만 본다.
##
## taper 를 u 방향으로 평균낸 단면으로 만들면 톤은 완벽하게 이어지지만
## 그림이 통째로 사라져서 뭉갠 자국이 된다. 열평균 단차는 그걸 못 잡는다.
## (실제로 이 함정에 한 번 빠졌다: 단차 3.53 PASS 인데 화면은 더 나빴다)
##
## 그래서 열마다 **고주파 에너지**(세로 이웃 픽셀 차의 평균)를 따로 잰다.
## 잔디 그림이 살아 있으면 높고, 뭉개지면 떨어진다.
## 지형이 있는 열만 세고, 32열 창으로 이동평균해서 최저 구간을 찾는다.
func _디테일붕괴(im: Image, bg: Color) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	var e := PackedFloat64Array(); e.resize(W)
	var 유효 := PackedInt32Array(); 유효.resize(W)
	for x in W:
		var s := 0.0
		var c := 0
		for y in range(1, H - 1):
			var a := im.get_pixel(x, y)
			var b := im.get_pixel(x, y + 1)
			if _배경인가(a, bg) or _배경인가(b, bg):
				continue
			s += absf(a.r - b.r) * 255.0
			c += 1
		e[x] = s / maxf(1.0, float(c))
		유효[x] = c
	# 지형이 충분히 있는 열만 대상으로 한다
	var 최소 := int(H / 6)
	var 값 := PackedFloat64Array()
	for x in W:
		if 유효[x] >= 최소:
			값.push_back(e[x])
	if 값.size() < 40:
		return [0.0, 0.0, 0]
	var 정렬 := 값.duplicate()
	정렬.sort()
	var 중앙 := 정렬[정렬.size() / 2]
	# 32열 이동평균의 최저 구간 = 가장 뭉개진 자리
	var 창 := 32
	var 최저 := 1e9
	var 최저x := 0
	for x in range(W - 창):
		var s2 := 0.0
		var c2 := 0
		for k in 창:
			if 유효[x + k] >= 최소:
				s2 += e[x + k]
				c2 += 1
		if c2 < 창 / 2:
			continue
		var m := s2 / float(c2)
		if m < 최저:
			최저 = m
			최저x = x + 창 / 2
	if 최저 > 1e8:
		최저 = 중앙
	return [중앙, 최저, 최저x]


func _내부이음매(im: Image, bg: Color) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	# 행별 세로 기울기 평균
	var grow := PackedFloat64Array(); grow.resize(H)
	var nrow := PackedInt32Array(); nrow.resize(H)
	for y in range(1, H - 2):
		var s := 0.0
		var c := 0
		for x in range(1, W - 1):
			var a := im.get_pixel(x, y)
			var b := im.get_pixel(x, y + 1)
			if _배경인가(a, bg) or _배경인가(b, bg):
				continue
			s += absf(a.r - b.r)
			c += 1
		grow[y] = s / maxf(1.0, float(c))
		nrow[y] = c
	# 열별 가로 기울기 평균
	var gcol := PackedFloat64Array(); gcol.resize(W)
	var ncol := PackedInt32Array(); ncol.resize(W)
	for x in range(1, W - 2):
		var s2 := 0.0
		var c2 := 0
		for y in range(1, H - 1):
			var a2 := im.get_pixel(x, y)
			var b2 := im.get_pixel(x + 1, y)
			if _배경인가(a2, bg) or _배경인가(b2, bg):
				continue
			s2 += absf(a2.r - b2.r)
			c2 += 1
		gcol[x] = s2 / maxf(1.0, float(c2))
		ncol[x] = c2
	var 최소표본: int = int(maxi(W, H) / 8)
	var r := _z점수(grow, nrow, 최소표본)
	var cc := _z점수(gcol, ncol, 최소표본)
	return [r[0], r[1], r[2], cc[0], cc[1], cc[2]]


## 같은 값이 연속으로 이어지는 최대 길이와 시작 위치.
## -1(실루엣 없음) 은 끊는다.
func _최대연속(a: PackedInt32Array) -> Array:
	var 최대 := 0
	var 최대시작 := 0
	var i := 0
	while i < a.size():
		if a[i] < 0:
			i += 1
			continue
		var j := i
		while j + 1 < a.size() and a[j + 1] == a[i]:
			j += 1
		var 길이 := j - i + 1
		if 길이 > 최대:
			최대 = 길이
			최대시작 = i
		i = j + 1
	return [최대, 최대시작]


func _실행() -> void:
	print("=".repeat(96))
	print("실루엣 축정렬 직선 구간 측정 (줌 %.2f)" % _줌)
	print("  손으로 그린 잔디 실루엣이면 직선 구간이 몇 px 를 넘지 못한다.")
	print("  길게 나오면 그건 그림이 아니라 쿼드/타일 경계다.")
	print("=".repeat(96))
	for i in _그림들.size():
		var 이름: String = _이름들[i] if i < _이름들.size() else _그림들[i].get_file()
		_측정(_그림들[i], 이름)
	print("=".repeat(96))
	quit(0)
