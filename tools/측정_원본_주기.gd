extends SceneTree
## ============================================================================
## [2026-08-25] 원본의 '무늬 주기'를 자기상관(autocorrelation)으로 잰다.
## ----------------------------------------------------------------------------
## ▣ 왜 골(trough) 세기를 버렸나
##   처음엔 밝기 프로파일에서 어두운 골의 개수를 셌는데, 나무의 **나뭇결**이나
##   벽돌의 실금까지 골로 잡혀 개수가 부풀었다 (wood side: 눈으로 11칸인데 16개로 셈).
##   주기를 잘못 재면 재생성 목표치가 통째로 틀어지므로 자기상관으로 바꿨다.
##   자기상관은 '몇 픽셀 밀었을 때 자기 자신과 가장 닮는가' 를 보므로
##   잔털 같은 고주파에 흔들리지 않는다.
##
## ▣ 배음(harmonic) 처리
##   주기 T 인 신호는 2T, 3T 에서도 상관이 높다. 그래서 최대 피크의 60% 이상인
##   가장 **작은** 지연을 기본 주기로 잡는다 (2배음을 주기로 착각하지 않게).
##
## ▣ 월드 환산
##   원본 전체 폭(또는 필의 한 변) -> 1024 텍셀 -> x0.35 = 358.4 월드px
## ============================================================================
const 월드 := 358.4

func _init(): call_deferred("_go")

func _im(p: String) -> Image:
	var b := FileAccess.get_file_as_bytes(p)
	if b.is_empty(): return null
	var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8); return im

## 1D 밝기 프로파일. 세로줄=true 면 열평균(가로로 훑는다), false 면 행평균.
func _프로파일(im: Image, 세로줄: bool, y0f: float, y1f: float) -> PackedFloat64Array:
	var W := im.get_width(); var H := im.get_height()
	var a := int(float(H) * y0f); var b := int(float(H) * y1f)
	var n: int = W if 세로줄 else (b - a)
	var out := PackedFloat64Array(); out.resize(n)
	for i in n:
		var s := 0.0; var c := 0
		if 세로줄:
			for y in range(a, b):
				var px := im.get_pixel(i, y)
				if minf(px.r, px.b) - px.g > 0.15: continue
				s += px.g; c += 1
		else:
			for x in W:
				var px := im.get_pixel(x, a + i)
				if minf(px.r, px.b) - px.g > 0.15: continue
				s += px.g; c += 1
		out[i] = s / maxf(c, 1)
	return out

## 자기상관으로 기본 주기(픽셀)를 찾는다. 못 찾으면 -1.
func _주기(p: PackedFloat64Array) -> float:
	var n := p.size()
	if n < 40: return -1.0
	var 평균 := 0.0
	for v in p: 평균 += v
	평균 /= float(n)
	var q := PackedFloat64Array(); q.resize(n)
	var 분산 := 0.0
	for i in n:
		q[i] = p[i] - 평균
		분산 += q[i] * q[i]
	if 분산 < 1e-9: return -1.0
	# ★ 하한을 n/40 으로 올린다. 나무의 나뭇결처럼 아주 촘촘한 성분이
	#   기본 주기로 잡히는 것을 막는다 (실제로 wood TOP 이 1.4 월드px 로 나왔었다).
	var lo: int = maxi(8, n / 40)
	var hi: int = n / 3
	var r := PackedFloat64Array(); r.resize(hi + 1)
	for L in range(lo, hi + 1):
		var s := 0.0
		for i in range(0, n - L):
			s += q[i] * q[i + L]
		r[L] = s / float(n - L) * float(n) / 분산
	var best := lo
	for L in range(lo, hi + 1):
		if r[L] > r[best]: best = L
	# ★ 배음 방지는 **정수 약수만** 본다.
	#   예전엔 "최대의 60% 이상인 가장 작은 지연" 을 골랐는데, 그러면 주기와
	#   아무 관계 없는 고주파 잡음(나뭇결)이 기본 주기로 뽑혔다.
	#   주기 T 인 신호는 T/2, T/3 에서 상관이 높을 이유가 없다.
	#   반대로 진짜 기본이 T 이고 최대가 2T 에 잡힌 경우만 되돌리면 된다.
	var 기본 := best
	for k in [4, 3, 2]:
		var cand: int = int(round(float(best) / float(k)))
		if cand < lo:
			continue
		if r[cand] >= r[best] * 0.85:
			기본 = cand
			break
	if r[best] < 0.12: return -1.0
	return float(기본)

## ★ 눈에 보이는 '이음매' 만 골라 세서 평균 간격을 낸다.
##
## ▣ 왜 자기상관만으로는 부족했나
##   벽돌처럼 간격이 규칙적이면 자기상관이 잘 맞는다. 그런데 나무는
##   판자 폭이 제각각이라 주기성이 약하고, 대신 **나뭇결**이 강한 고주파로 들어온다.
##   그래서 자기상관이 나뭇결(2.2 월드px)을 기본 주기로 뽑아 버렸다.
##   실제로 필요한 값은 "무늬가 몇 픽셀마다 반복되는가" 가 아니라
##   "눈에 보이는 이음매가 평균 몇 픽셀 간격인가" 이므로 그것을 직접 센다.
##
## ▣ 방법
##   깊은 골부터 욕심내어 고르되 (1) 최소 간격 n/40 이상 떨어져 있고
##   (2) 프로파일 동적 범위의 18% 이상 깊은 것만 이음매로 인정한다.
##   나뭇결은 얕아서 (2) 에서 걸러지고, 촘촘한 잔금은 (1) 에서 걸러진다.
## ★ [2026-08-25] primary 구조 / secondary 디테일을 나눠서 잰다.
##
## ▣ 왜 나눠야 하나 (실제로 두 번 틀렸다)
##   나무의 **나뭇결**, 철판의 **리벳 열** 은 벽돌 줄눈보다 훨씬 촘촘하다.
##   "가장 많이 반복되는 무늬" 를 재면 그 고주파가 잡혀서
##   wood TOP 이 2.2 월드px, iron TOP 이 18.4 월드px 로 나왔다 — 둘 다 헛것이다.
##   재야 하는 것은 **구조를 정의하는 가장 큰 반복 단위** 다:
##     brick 줄눈 · wood 판자 이음매 · metal 패널 seam.
##
## ▣ 어떻게 나누나
##   구조 이음매는 깊고 드물다. 디테일은 얕고 촘촘하다.
##   그래서 같은 검출기를 **문턱과 최소간격만 바꿔** 두 번 돌린다.
##     primary   : 동적범위의 35% 이상 깊고, 서로 n/25 이상 떨어진 것
##     secondary : 동적범위의 10% 이상, 서로 n/100 이상
##   primary 가 2개 미만이면 (BOTTOM 처럼 구간이 짧은 경우) 한 단계 완화한다.
func _이음매간격(p: PackedFloat64Array) -> float:
	var v := _이음매간격_코어(p, 25, 0.35)
	if v < 0.0:
		v = _이음매간격_코어(p, 40, 0.22)
	if v < 0.0:
		v = _이음매간격_코어(p, 60, 0.14)
	return v


## 얕고 촘촘한 것까지 전부 — 나뭇결/리벳이 여기 잡힌다
func _디테일간격(p: PackedFloat64Array) -> float:
	return _이음매간격_코어(p, 100, 0.10)


## primary 로 인정된 이음매가 몇 개인지 (구간이 짧은 BOTTOM 판단용)
func _이음매개수(p: PackedFloat64Array) -> int:
	var g := _이음매간격(p)
	if g < 0.0:
		return 0
	return int(round(float(p.size()) / g))


func _이음매간격_코어(p: PackedFloat64Array, 간격분모: int, 깊이비: float) -> float:
	var n := p.size()
	if n < 40:
		return -1.0
	# 이동평균 (아주 얇은 선 제거)
	var r: int = maxi(1, n / 300)
	var sm := PackedFloat64Array(); sm.resize(n)
	for i in n:
		var s := 0.0; var c := 0
		for k in range(maxi(0, i - r), mini(n, i + r + 1)):
			s += p[k]; c += 1
		sm[i] = s / float(c)
	# 동적 범위 (극단값에 안 흔들리게 정렬해서 5%~95%)
	var 정렬 := PackedFloat64Array(sm)
	정렬.sort()
	var lo5: float = 정렬[int(float(n) * 0.05)]
	var hi95: float = 정렬[int(float(n) * 0.95)]
	var 범위: float = hi95 - lo5
	if 범위 < 1e-6:
		return -1.0
	var 문턱: float = lo5 + 범위 * 깊이비
	# 국소 최소 후보를 깊은 순으로
	var 후보 := []
	for i in range(1, n - 1):
		if sm[i] <= sm[i-1] and sm[i] <= sm[i+1] and sm[i] < 문턱:
			후보.append([sm[i], i])
	후보.sort_custom(func(a, b): return a[0] < b[0])
	var 최소간격: int = maxi(4, n / 간격분모)
	var 채택: Array[int] = []
	for c in 후보:
		var i: int = c[1]
		var ok := true
		for j in 채택:
			if absi(j - i) < 최소간격:
				ok = false
				break
		if ok:
			채택.append(i)
	if 채택.size() < 2:
		return -1.0
	return float(n) / float(채택.size())


func _재기(이름: String, 경로: String, 세로줄: bool, y0f: float, y1f: float) -> void:
	var im := _im(경로)
	if im == null:
		print("  %-30s 없음" % 이름); return
	var p := _프로파일(im, 세로줄, y0f, y1f)
	var T := _이음매간격(p)
	var Ta := _주기(p)
	if T < 0.0:
		print("  %-30s 이음매 못 찾음 (표본 %d)" % [이름, p.size()]); return
	# 프로파일 축의 픽셀 -> 월드. 세로줄이면 축이 이미지 폭, 아니면 이미지 높이지만
	# 어느 쪽이든 '원본 폭 = 358.4 월드px' 스케일을 쓴다 (엣지는 폭이 1024텍셀이 된다).
	var 축길이: float = float(im.get_width())
	var 월드주기: float = T / 축길이 * 월드
	var D := _디테일간격(p)
	var 디테일: String = "%.1f" % (D / 축길이 * 월드) if D > 0.0 else "-"
	print("  %-26s primary %5.1f 월드px   secondary %s   (구조 이음매 %d개 / 표본 %d)"
		% [이름, 월드주기, 디테일, _이음매개수(p), p.size()])

func _go():
	var 목록 := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--재질="): 목록.append(a.substr("--재질=".length()))
	if 목록.is_empty(): 목록 = ["brick_v2", "wood_v2"]
	print("무늬 주기 — 자기상관 (원본 전체 폭 = 월드 %.1fpx)\n" % 월드)
	for m in 목록:
		print("[%s]" % m)
		var s := "res://tools/%s_pipeline/src" % m
		# TOP/BOTTOM: 켜가 v 방향으로 쌓인다 -> 행평균 (실제 쓰이는 띠 구간만)
		_재기("TOP  가로 켜 간격", "%s/master_top.png" % s, false, 0.32, 0.78)
		_재기("BOTTOM 가로 켜 간격", "%s/master_bottom.png" % s, false, 0.10, 0.60)
		# SIDE: 90도 회전 -> 세로 이음매가 벽에서 가로 켜가 된다 -> 열평균
		_재기("SIDE 세로 이음매 간격", "%s/master_side.png" % s, true, 0.32, 0.78)
		# FILL: 가로 켜 -> 행평균 / 가로 반복 -> 열평균
		_재기("FILL 가로 켜 간격", "%s/master_fill.png" % s, false, 0.0, 1.0)
		_재기("FILL 세로 반복 간격", "%s/master_fill.png" % s, true, 0.0, 1.0)
		print("")
	quit()
