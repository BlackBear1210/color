extends SceneTree
## [2026-08-25 신규] **구운 결과**(baked)의 primary 무늬 주기와 검정 수준을 잰다.
## 원본이 아니라 baker 산출물을 재서, 굽기가 scale/orientation 을 망가뜨리지 않았는지 본다.
##   엣지: 1024x256  (u=1024px=358.4월드 / v=256px=89.6월드)
##   필  : 1024x1024 (358.4월드)
## 측정 원칙은 원본과 동일 — primary(구조 이음매)만 센다.

func _init(): call_deferred("_go")

func _im(p: String) -> Image:
	var b := FileAccess.get_file_as_bytes(p)
	if b.is_empty(): return null
	var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8); return im

## 알파가 있는 곳만 모아 1D 프로파일. 열=true 면 열평균(가로로 훑음).
func _프로파일(im: Image, 열: bool, v0: float, v1: float) -> PackedFloat64Array:
	var W := im.get_width(); var H := im.get_height()
	var a := int(float(H) * v0); var b := int(float(H) * v1)
	var n: int = W if 열 else (b - a)
	var out := PackedFloat64Array(); out.resize(n)
	for i in n:
		var s := 0.0; var w := 0.0
		if 열:
			for y in range(a, b):
				var c := im.get_pixel(i, y)
				s += c.r * c.a; w += c.a
		else:
			for x in W:
				var c := im.get_pixel(x, a + i)
				s += c.r * c.a; w += c.a
		out[i] = s / maxf(w, 0.001)
	return out

func _간격(p: PackedFloat64Array, 간격분모: int, 깊이비: float) -> float:
	var n := p.size()
	if n < 24: return -1.0
	var r: int = maxi(1, n / 300)
	var sm := PackedFloat64Array(); sm.resize(n)
	for i in n:
		var s := 0.0; var c := 0
		for k in range(maxi(0, i - r), mini(n, i + r + 1)): s += p[k]; c += 1
		sm[i] = s / float(c)
	var 정렬 := PackedFloat64Array(sm); 정렬.sort()
	var lo5: float = 정렬[int(float(n) * 0.05)]
	var hi95: float = 정렬[int(float(n) * 0.95)]
	var 범위: float = hi95 - lo5
	if 범위 < 1e-6: return -1.0
	var 문턱: float = lo5 + 범위 * 깊이비
	var 후보 := []
	for i in range(1, n - 1):
		if sm[i] <= sm[i-1] and sm[i] <= sm[i+1] and sm[i] < 문턱:
			후보.append([sm[i], i])
	후보.sort_custom(func(a, b): return a[0] < b[0])
	var 최소: int = maxi(3, n / 간격분모)
	var 채택: Array[int] = []
	for c in 후보:
		var i: int = c[1]
		var ok := true
		for j in 채택:
			if absi(j - i) < 최소: ok = false; break
		if ok: 채택.append(i)
	if 채택.size() < 2: return -1.0
	return float(n) / float(채택.size())

## 최소 간격 분모를 밖에서 준다.
## ★ 엣지(v축 256px)는 주기가 3~5개뿐이라 표본이 작다. n/25 를 쓰면 최소 간격이
##   10px 밖에 안 돼서 벽돌 **면 안의 음영**까지 이음매로 잡힌다 (실제로 18.4 를 7 로 쟀다).
##   기대 주기 수에 맞춰 분모를 골라야 한다.
func _primary(p: PackedFloat64Array, 분모: int = 25) -> float:
	var v := _간격(p, 분모, 0.35)
	if v < 0.0: v = _간격(p, 분모, 0.22)
	if v < 0.0: v = _간격(p, 분모 * 2, 0.14)
	return v

## 필의 디테일이 감마로 눌렸는지 — 표준편차와 실제로 쓰이는 8비트 계단 수.
## 감마를 올리면 검정에 가까워지면서 계단이 줄어든다. 나뭇결이 사라지는지를 이걸로 본다.
func _디테일(im: Image) -> Array:
	var 합 := 0.0; var 제곱 := 0.0; var n := 0
	var 레벨 := {}
	for y in im.get_height():
		for x in im.get_width():
			var v := im.get_pixel(x, y).r
			합 += v; 제곱 += v * v; n += 1
			레벨[int(round(v * 255.0))] = true
	var m: float = 합 / float(n)
	var sd: float = sqrt(maxf(제곱 / float(n) - m * m, 0.0))
	return [sd * 255.0, 레벨.size()]


## 알파>0.5 인 픽셀의 평균 휘도 = 실제로 보이는 '검정 수준'
func _검정(im: Image) -> float:
	var s := 0.0; var c := 0
	for y in im.get_height():
		for x in im.get_width():
			var p := im.get_pixel(x, y)
			if p.a > 0.5: s += p.r; c += 1
	return s / maxf(c, 1) * 255.0

func _go():
	var 폴더 := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--폴더="): 폴더.append(a.substr("--폴더=".length()).rstrip("/"))
	for f in 폴더:
		print("\n[%s]" % f.get_file())
		# TOP: 켜가 깊이(v)로 쌓인다 -> 행 프로파일, 축 = 256px = 89.6 월드
		var t := _im("%s/black/edge_top.png" % f)
		if t != null:
			# v축 256px = 89.6 월드px. 프로파일 표본은 잘라 쓴 행 수 그대로다.
			var g := _primary(_프로파일(t, false, 0.08, 0.80), 8)
			print("  edge_top    primary %5.1f 월드px   검정 %.1f" % [g / float(t.get_height()) * 89.6, _검정(t)])
		# BOTTOM
		var bm := _im("%s/black/edge_bottom.png" % f)
		if bm != null:
			var g := _primary(_프로파일(bm, false, 0.08, 0.80), 8)
			print("  edge_bottom primary %5.1f 월드px   검정 %.1f" % [g / float(bm.get_height()) * 89.6, _검정(bm)])
		# SIDE(left): 이음매가 u 를 따라 간다 -> 열 프로파일, 축 = 1024px = 358.4 월드
		var l := _im("%s/black/edge_left.png" % f)
		if l != null:
			var g := _primary(_프로파일(l, true, 0.15, 0.80), 25)
			print("  edge_left   primary %5.1f 월드px   검정 %.1f" % [g / float(l.get_width()) * 358.4, _검정(l)])
		# FILL
		var fi := _im("%s/black/fill_detail.png" % f)
		if fi != null:
			var g := _primary(_프로파일(fi, false, 0.0, 1.0), 25)
			print("  fill        primary %5.1f 월드px   검정 %.1f" % [g / float(fi.get_height()) * 358.4, _검정(fi)])
		# WHITE 짝 (반전이 제대로 됐는지)
		if fi != null:
			var d := _디테일(fi)
			print("  fill 디테일  표준편차 %.1f   계단 %d 단계" % [d[0], d[1]])
		var fw := _im("%s/white/fill_detail.png" % f)
		if fw != null:
			print("  fill(white) 흰색 %.1f" % _검정(fw))
	quit()
