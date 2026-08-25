extends SceneTree
## ============================================================================
## [2026-08-25 신규] 렌더 결과에서 **저주파 톤 단차(seam)** 를 잰다.
## ----------------------------------------------------------------------------
## ▣ 왜 기울기 최대값을 쓰면 안 되나
##   벽돌 줄눈·판자 이음매는 그 자체가 아주 강한 기울기다. 그래서 "가장 가파른 곳"
##   을 seam 이라고 부르면 정상적인 무늬가 전부 걸린다.
##   우리가 찾는 것은 **엣지 띠와 FILL 사이의 밝기 단차** — 즉 저주파 성분이다.
##   그래서 가로로 넓게 평활해 무늬를 지운 뒤, 남은 계단만 본다.
##
## 실행: --im=... --x0= --x1= --y0= --y1= [--평활=25]
## 출력: 평활 프로파일의 |기울기| 중앙값 대비 상위 단차 위치/크기

var _im := ""
var _x0 := 0
var _x1 := 0
var _y0 := 0
var _y1 := 0
var _평활 := 25

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--im="): _im = a.substr("--im=".length())
		elif a.begins_with("--x0="): _x0 = a.substr("--x0=".length()).to_int()
		elif a.begins_with("--x1="): _x1 = a.substr("--x1=".length()).to_int()
		elif a.begins_with("--y0="): _y0 = a.substr("--y0=".length()).to_int()
		elif a.begins_with("--y1="): _y1 = a.substr("--y1=".length()).to_int()
		elif a.begins_with("--평활="): _평활 = a.substr("--평활=".length()).to_int()
	call_deferred("_go")

func _go() -> void:
	var b := FileAccess.get_file_as_bytes(_im)
	if b.is_empty():
		push_error("없음 %s" % _im); quit(1); return
	var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8)
	if _x1 <= 0: _x1 = im.get_width()
	if _y1 <= 0: _y1 = im.get_height()
	var n := _x1 - _x0
	var p := PackedFloat64Array(); p.resize(n)
	for i in n:
		var s := 0.0
		for y in range(_y0, _y1):
			s += im.get_pixel(_x0 + i, y).r
		p[i] = s / float(_y1 - _y0)
	# 가로 평활 — 무늬(고주파)를 지운다
	var sm := PackedFloat64Array(); sm.resize(n)
	for i in n:
		var s := 0.0; var c := 0
		for k in range(maxi(0, i - _평활), mini(n, i + _평활 + 1)): s += p[k]; c += 1
		sm[i] = s / float(c)
	var g := PackedFloat64Array(); g.resize(n)
	for i in n:
		var a: int = maxi(0, i - 1)
		var c: int = mini(n - 1, i + 1)
		g[i] = absf(sm[c] - sm[a]) * 255.0
	var 정렬 := PackedFloat64Array(g); 정렬.sort()
	var 중앙: float = 정렬[n / 2]
	print("%s  x[%d..%d] y[%d..%d]  평활 %d" % [_im.get_file(), _x0, _x1, _y0, _y1, _평활])
	print("  평활 |기울기| 중앙값 %.3f /255" % 중앙)
	# 상위 단차 (서로 20px 이상 떨어진 국소 최대만)
	var 후보 := []
	for i in range(2, n - 2):
		if g[i] >= g[i-1] and g[i] >= g[i+1]: 후보.append([g[i], i])
	후보.sort_custom(func(a, c): return a[0] > c[0])
	var 채택 := []
	for c in 후보:
		var ok := true
		for j in 채택:
			if absi(int(j[1]) - int(c[1])) < 20: ok = false; break
		if ok: 채택.append(c)
		if 채택.size() >= 5: break
	for c in 채택:
		print("    x=%4d  단차 %.3f /255  (중앙값의 %.1f배)"
			% [_x0 + int(c[1]), c[0], c[0] / maxf(중앙, 0.0001)])
	quit()
