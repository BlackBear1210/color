extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 시각 품질 "실측" 도구 (읽기 전용)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/측정_grass_v4_품질.gd
##
## ▣ 왜 만들었나
##   기존 측정은 tools/grass_v4_pipeline/*.py (numpy/PIL) 로 했는데,
##   이 PC 에는 파이썬이 없다 (WindowsApps 스텁만 있음).
##   그래서 같은 수치를 GDScript 로 다시 잰다. 문서 값을 믿지 않고 직접 잰다.
##
## ▣ 무엇을 재나 (전부 원본 PNG 바이트에서 직접 — import 설정 영향 없음)
##   1) 테마별 휘도 통계 (알파 가중) : 평균/최소/최대/p05/p50/p95 + 하이라이트·암부 비율
##   2) 흑백 구조 대응 : |(255-BLACK) - WHITE| 오차와 알파 차이
##   3) 타일링 이음매 : 좌우/상하 끝 픽셀 차이 vs 내부 이웃 픽셀 차이 (비율)
##   4) 반복 모티프 : 열 평균 프로파일의 순환 자기상관 (짧은 lag 제외)
##   5) 코너 <-> 엣지 단면 이음매 : 합성 수식과 같은 지점을 쌍선형 샘플링해 비교
##   6) 필 <-> 엣지 안쪽 톤 차이
##   7) texture_scale 후보별 월드 치수 환산표
##
## ▣ 아무것도 쓰지 않는다. 픽셀도 씬도 건드리지 않는다.
## ============================================================================

const 루트 := "res://assets/textures/smartshape/grass_v4/"

const 엣지들 := ["grass_edge_top", "grass_edge_top_alt", "grass_edge_bottom",
	"grass_edge_left", "grass_edge_right"]
const 톤엣지 := ["grass_edge_top", "grass_edge_bottom", "grass_edge_left", "grass_edge_right"]
const 코너들 := ["grass_corner_outer", "grass_corner_inner"]
const 필들 := ["grass_fill_detail", "grass_fill_solid"]

## 코너 합성 상수 (apply_final.py build_corners 와 동일해야 의미가 있다)
const U_TOP := 0.31
const U_SIDE := 0.62


func _init() -> void:
	call_deferred("_실행")


# ------------------------------------------------------------------ 로딩
## import 를 거치지 않고 원본 PNG 바이트를 직접 디코드한다.
## (VRAM 압축/밉맵 같은 import 설정이 측정값을 오염시키지 않게 하려는 것)
func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		push_error("읽기 실패: %s" % 경로)
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		push_error("PNG 디코드 실패: %s" % 경로)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _경로(테마: String, 이름: String) -> String:
	return 루트 + 테마 + "/" + 이름 + ".png"


# ------------------------------------------------------------------ 통계
## 알파 127 초과 픽셀만 세는 256칸 히스토그램. 필처럼 불투명한 것은 전부 센다.
func _히스토(im: Image, 알파필터: bool) -> PackedInt64Array:
	var h := PackedInt64Array()
	h.resize(256)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if 알파필터 and c.a * 255.0 <= 127.0:
				continue
			h[int(round(c.r * 255.0))] += 1
	return h


func _합(h: PackedInt64Array) -> int:
	var s := 0
	for v in h:
		s += v
	return s


func _평균(h: PackedInt64Array) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var acc := 0.0
	for i in 256:
		acc += float(i) * float(h[i])
	return acc / float(n)


func _분위(h: PackedInt64Array, q: float) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var 목표 := q * float(n)
	var acc := 0.0
	for i in 256:
		acc += float(h[i])
		if acc >= 목표:
			return float(i)
	return 255.0


func _최소(h: PackedInt64Array) -> int:
	for i in 256:
		if h[i] > 0:
			return i
	return -1


func _최대(h: PackedInt64Array) -> int:
	for i in range(255, -1, -1):
		if h[i] > 0:
			return i
	return -1


## 임계 이상 픽셀 비율 (하이라이트 비율 계산용)
func _비율_이상(h: PackedInt64Array, 임계: int) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var c := 0
	for i in range(임계, 256):
		c += h[i]
	return float(c) / float(n) * 100.0


func _비율_이하(h: PackedInt64Array, 임계: int) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var c := 0
	for i in range(0, 임계 + 1):
		c += h[i]
	return float(c) / float(n) * 100.0


func _더하기(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	for i in 256:
		a[i] += b[i]
	return a


func _빈히스토() -> PackedInt64Array:
	var h := PackedInt64Array()
	h.resize(256)
	return h


# ------------------------------------------------------------------ 1) 휘도 통계
func _테마_통계(테마: String) -> Dictionary:
	print("\n  [%s]" % 테마.to_upper())
	print("  %-22s %5s %5s  %7s %6s %6s %6s %6s %6s   %6s %6s"
		% ["텍스처", "폭", "높이", "평균", "min", "p05", "p50", "p95", "max", ">=200", "<=40"])
	var 합계 := _빈히스토()
	for 이름 in 엣지들 + 코너들 + 필들:
		var im := _png(_경로(테마, 이름))
		if im == null:
			continue
		var 알파필터: bool = not 이름.begins_with("grass_fill")
		var h := _히스토(im, 알파필터)
		print("  %-22s %5d %5d  %7.2f %6d %6.0f %6.0f %6.0f %6d   %5.1f%% %5.1f%%"
			% [이름, im.get_width(), im.get_height(), _평균(h), _최소(h),
				_분위(h, 0.05), _분위(h, 0.50), _분위(h, 0.95), _최대(h),
				_비율_이상(h, 200), _비율_이하(h, 40)])
		# 파이프라인 검증과 같은 집합만 합산한다 (4방향 엣지 + 코너 2 + fill_detail)
		if 이름 in 톤엣지 or 이름 in 코너들 or 이름 == "grass_fill_detail":
			합계 = _더하기(합계, h)
	print("  %-22s %11s  %7.2f %6d %6.0f %6.0f %6.0f %6d   %5.1f%% %5.1f%%"
		% ["* 집계(4엣지+코너2+필)", "", _평균(합계), _최소(합계),
			_분위(합계, 0.05), _분위(합계, 0.50), _분위(합계, 0.95), _최대(합계),
			_비율_이상(합계, 200), _비율_이하(합계, 40)])
	return {"평균": _평균(합계), "p05": _분위(합계, 0.05), "p95": _분위(합계, 0.95),
		"min": _최소(합계), "max": _최대(합계)}


# ------------------------------------------------------------------ 2) 흑백 대응
func _반전_검사() -> void:
	print("\n[2] 흑백 구조 대응 - WHITE 가 BLACK 휘도의 정확한 반전인가")
	print("  %-22s %10s %10s %10s" % ["텍스처", "평균오차", "최대오차", "알파최대차"])
	var 전체최대 := 0.0
	for 이름 in 엣지들 + 코너들 + 필들:
		var b := _png(_경로("black", 이름))
		var w := _png(_경로("white", 이름))
		if b == null or w == null:
			continue
		var 합 := 0.0
		var 최대 := 0.0
		var 알파최대 := 0.0
		var n := 0
		for y in b.get_height():
			for x in b.get_width():
				var cb := b.get_pixel(x, y)
				var cw := w.get_pixel(x, y)
				알파최대 = maxf(알파최대, absf(cb.a - cw.a) * 255.0)
				if cb.a * 255.0 <= 127.0:
					continue
				var d := absf((255.0 - cb.r * 255.0) - cw.r * 255.0)
				합 += d
				최대 = maxf(최대, d)
				n += 1
		전체최대 = maxf(전체최대, 최대)
		print("  %-22s %10.3f %10.1f %10.0f" % [이름, 합 / maxf(1.0, float(n)), 최대, 알파최대])
	print("  -> 전체 최대 오차 %.1f / 255  (0 이면 수식으로 완전 대응)" % 전체최대)


# ------------------------------------------------------------------ 3) 타일링 이음매
## 끝 픽셀 차이를 '내부 이웃 픽셀 차이 평균' 과 비교한다.
## 비율이 1 근처면 이음매가 그냥 평범한 이웃 관계라는 뜻 = 안 보인다.
func _이음매(im: Image, 가로: bool) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	var 끝합 := 0.0
	var 끝수 := 0
	var 내부합 := 0.0
	var 내부수 := 0
	if 가로:
		for y in H:
			var a := im.get_pixel(W - 1, y)
			var b := im.get_pixel(0, y)
			if a.a > 0.5 and b.a > 0.5:
				끝합 += absf(a.r - b.r) * 255.0
				끝수 += 1
			for x in range(0, W - 1):
				var p := im.get_pixel(x, y)
				var q := im.get_pixel(x + 1, y)
				if p.a > 0.5 and q.a > 0.5:
					내부합 += absf(p.r - q.r) * 255.0
					내부수 += 1
	else:
		for x in W:
			var a := im.get_pixel(x, H - 1)
			var b := im.get_pixel(x, 0)
			if a.a > 0.5 and b.a > 0.5:
				끝합 += absf(a.r - b.r) * 255.0
				끝수 += 1
			for y in range(0, H - 1):
				var p := im.get_pixel(x, y)
				var q := im.get_pixel(x, y + 1)
				if p.a > 0.5 and q.a > 0.5:
					내부합 += absf(p.r - q.r) * 255.0
					내부수 += 1
	var 끝 := 끝합 / maxf(1.0, float(끝수))
	var 내부 := 내부합 / maxf(1.0, float(내부수))
	return [끝, 내부, 끝 / maxf(0.0001, 내부)]


func _타일링_검사() -> void:
	print("\n[3] 타일링 이음매 (끝 픽셀 차 / 내부 이웃 픽셀 차)")
	print("  %-32s %9s %9s %8s  %s" % ["텍스처", "끝차", "내부차", "비율", "판정"])
	for 테마 in ["black", "white"]:
		for 이름 in 엣지들 + 필들:
			var im := _png(_경로(테마, 이름))
			if im == null:
				continue
			var r := _이음매(im, true)
			# 기준: 비율 3.0 이하면 통과. 비율이 커도 절대차가 1/255 미만이면 지각 불가.
			var ok: bool = r[2] <= 3.0 or r[0] < 1.0
			print("  %-32s %9.3f %9.3f %8.2f  %s"
				% ["%s/%s 좌우" % [테마, 이름], r[0], r[1], r[2], "PASS" if ok else "FAIL"])
		for 이름2 in 필들:
			var im2 := _png(_경로(테마, 이름2))
			if im2 == null:
				continue
			var r2 := _이음매(im2, false)
			var ok2: bool = r2[2] <= 3.0 or r2[0] < 1.0
			print("  %-32s %9.3f %9.3f %8.2f  %s"
				% ["%s/%s 상하" % [테마, 이름2], r2[0], r2[1], r2[2], "PASS" if ok2 else "FAIL"])


# ------------------------------------------------------------------ 4) 반복 모티프
## 축 방향 평균 프로파일의 **순환** 자기상관.
## ⚠ 짧은 lag 는 반드시 제외한다. lag 16 이 높은 것은 '반복' 이 아니라
##   그냥 이웃 픽셀이 비슷하다는 뜻이다 (전에 이걸로 오판한 적 있다).
##
## ★ 정규화 상관값만 보면 안 된다.
##   상관은 분산으로 나누기 때문에, 프로파일 진폭이 0.2/255 밖에 안 되는
##   거의 평평한 텍스처도 상관값이 쉽게 0.6~0.7 까지 올라간다.
##   그래서 프로파일 표준편차(진폭)를 항상 같이 낸다.
##   "상관이 높다 + 진폭이 1/255 넘는다" 일 때만 실제로 눈에 보이는 반복이다.
func _프로파일(im: Image, 가로: bool) -> PackedFloat64Array:
	var W := im.get_width()
	var H := im.get_height()
	var n: int = W if 가로 else H
	var m: int = H if 가로 else W
	var prof := PackedFloat64Array()
	prof.resize(n)
	for i in n:
		var s := 0.0
		for j in m:
			var c := im.get_pixel(i, j) if 가로 else im.get_pixel(j, i)
			# 실제로 보이는 모습 = 휘도 x 알파 (프리멀티플라이)
			s += c.r * 255.0 * c.a
		prof[i] = s / float(m)
	return prof


func _자기상관(prof: PackedFloat64Array) -> Array:
	var W := prof.size()
	var m := 0.0
	for v in prof:
		m += v
	m /= float(W)
	var p := PackedFloat64Array()
	p.resize(W)
	var var0 := 0.0
	for i in W:
		p[i] = prof[i] - m
		var0 += p[i] * p[i]
	var 표준편차: float = sqrt(var0 / float(W))
	if var0 < 1e-9:
		return [0.0, 0, 표준편차, 0.0]
	var 최대 := 0.0
	var 최대lag := 0
	var 하한: int = int(float(W) / 8.0)   # 짧은 lag 제외 (기존 파이썬 검사와 동일 기준)
	for lag in range(하한, int(W / 2) + 1):
		var acc := 0.0
		for i in W:
			acc += p[i] * p[(i + lag) % W]
		var r := acc / var0
		if r > 최대:
			최대 = r
			최대lag = lag
	# 반복이 실제로 만드는 밝기 진동 폭 (255 기준). 이게 작으면 눈에 안 보인다.
	return [최대, 최대lag, 표준편차, 최대 * 표준편차]


func _모티프_검사() -> void:
	print("\n[4] 반복 모티프 순환 자기상관")
	print("    판정: 상관 0.5 미만 = PASS, 또는 반복 진폭 < 1.0/255 = 지각 한계 이하로 PASS")
	print("  %-30s %5s %8s %6s %9s %9s  %s"
		% ["텍스처", "축", "최대상관", "lag", "진폭σ/255", "반복폭/255", "판정"])
	for 테마 in ["black", "white"]:
		for 이름 in 엣지들 + 필들:
			var im := _png(_경로(테마, 이름))
			if im == null:
				continue
			var 축들 := [true, false] if 이름.begins_with("grass_fill") else [true]
			for 가로 in 축들:
				var r := _자기상관(_프로파일(im, 가로))
				var 상관: float = r[0]
				var 진폭: float = r[3]
				var ok: bool = 상관 < 0.5 or 진폭 < 1.0
				var 사유 := ""
				if 상관 >= 0.5 and ok:
					사유 = "  <- 반복 진폭 %.2f/255 로 지각한계 이하" % 진폭
				print("  %-30s %5s %8.3f %6d %9.3f %9.3f  %s%s"
					% ["%s/%s" % [테마, 이름], "가로" if 가로 else "세로",
						상관, r[1], r[2], 진폭, "PASS" if ok else "FAIL", 사유])


# ------------------------------------------------------------------ 5) 코너 이음매
## apply_final.py 의 sample() 과 같은 쌍선형 샘플링 (u 는 순환, v 는 클램프)
func _샘플(im: Image, u: float, v: float) -> Color:
	var W := im.get_width()
	var H := im.get_height()
	var x := fposmod(u, 1.0) * float(W) - 0.5
	var y := clampf(v, 0.0, 1.0) * float(H - 1)
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var fx := x - float(x0)
	var fy := y - float(y0)
	var x0m := ((x0 % W) + W) % W
	var x1m := (((x0 + 1) % W) + W) % W
	var y0c := clampi(y0, 0, H - 1)
	var y1c := clampi(y0 + 1, 0, H - 1)
	var a := im.get_pixel(x0m, y0c).lerp(im.get_pixel(x1m, y0c), fx)
	var b := im.get_pixel(x0m, y1c).lerp(im.get_pixel(x1m, y1c), fx)
	return a.lerp(b, fy)


## 한 줄(코너 가장자리 256픽셀)의 차이 분포를 요약한다.
## 평균만 보면 안 된다 — 최대가 어디서 나는지가 "눈에 보이는 단차인가" 를 가른다.
func _줄요약(라벨: String, 차: PackedFloat64Array, 알파: PackedFloat64Array) -> void:
	var 유효 := PackedFloat64Array()
	for i in 차.size():
		if 알파[i] > 127.0:
			유효.push_back(차[i])
	if 유효.is_empty():
		print("  %-28s (유효 픽셀 없음)" % 라벨)
		return
	var 정렬 := 유효.duplicate()
	정렬.sort()
	var 합 := 0.0
	for v in 유효:
		합 += v
	var 최대idx := 0
	for i in 차.size():
		if 알파[i] > 127.0 and 차[i] >= 정렬[정렬.size() - 1]:
			최대idx = i
			break
	print("  %-28s n %3d  평균 %5.3f  p50 %5.2f  p95 %5.2f  최대 %5.2f (i=%d, α=%.0f)"
		% [라벨, 유효.size(), 합 / float(유효.size()),
			정렬[int(정렬.size() * 0.50)], 정렬[int(정렬.size() * 0.95)],
			정렬[정렬.size() - 1], 최대idx, 알파[최대idx]])


func _코너_검사(테마: String) -> void:
	var top := _png(_경로(테마, "grass_edge_top"))
	var side := _png(_경로(테마, "grass_edge_right"))
	var 아웃 := _png(_경로(테마, "grass_corner_outer"))
	var 인 := _png(_경로(테마, "grass_corner_inner"))
	if top == null or side == null or 아웃 == null or 인 == null:
		return
	var S := 아웃.get_width()
	var d1 := PackedFloat64Array(); var a1 := PackedFloat64Array()
	var d2 := PackedFloat64Array(); var a2 := PackedFloat64Array()
	var d3 := PackedFloat64Array(); var a3 := PackedFloat64Array()
	var d4 := PackedFloat64Array(); var a4 := PackedFloat64Array()

	for i in S:
		var f := float(i)
		# OUTER 왼쪽 열 (x=0) = TOP 엣지 단면. v = (y+0.5)/S, u = 0.31
		var c1 := 아웃.get_pixel(0, i)
		d1.push_back(absf(c1.r - _샘플(top, U_TOP, (f + 0.5) / float(S)).r) * 255.0)
		a1.push_back(c1.a * 255.0)
		# OUTER 아래 행 (y=S-1) = SIDE 엣지 단면(역방향). v = 1-(x+0.5)/S, u = 0.62
		var c2 := 아웃.get_pixel(i, S - 1)
		d2.push_back(absf(c2.r - _샘플(side, U_SIDE, 1.0 - (f + 0.5) / float(S)).r) * 255.0)
		a2.push_back(c2.a * 255.0)
		# INNER 위 행 (y=0) = TOP 단면(역방향). v = (S-x-0.5)/S
		var c3 := 인.get_pixel(i, 0)
		d3.push_back(absf(c3.r - _샘플(top, U_TOP, (float(S) - f - 0.5) / float(S)).r) * 255.0)
		a3.push_back(c3.a * 255.0)
		# INNER 오른쪽 열 (x=S-1) = SIDE 단면. v = (y+0.5)/S
		var c4 := 인.get_pixel(S - 1, i)
		d4.push_back(absf(c4.r - _샘플(side, U_SIDE, (f + 0.5) / float(S)).r) * 255.0)
		a4.push_back(c4.a * 255.0)

	_줄요약("%s OUTER 왼쪽열<->TOP" % 테마, d1, a1)
	_줄요약("%s OUTER 아래행<->SIDE" % 테마, d2, a2)
	_줄요약("%s INNER 위행  <->TOP" % 테마, d3, a3)
	_줄요약("%s INNER 오른열<->SIDE" % 테마, d4, a4)


# ------------------------------------------------------------------ 5-b) 코너 재현
## apply_final.py 의 build_corners 를 그대로 다시 계산해서 커밋된 PNG 와 비교한다.
##
## 왜 이게 필요한가:
##   위 5) 는 "코너 경계열 = u 0.31 의 TOP 단면" 이라는 근사로 쟀는데,
##   실제 수식의 u 는 0.31 + (pi/2 - phi)*r / 1024 이고 경계에서 이 항이 정확히
##   반 텍셀(0.5px) 이다. 반 텍셀 어긋난 채로 재면 기울기가 급한 곳에서 p95 가
##   14 까지 뜬다 — 그건 이음매 오차가 아니라 내 재구성 오차다.
##   수식을 그대로 돌려 비교하면 그 둘을 분리할 수 있다.
func blend_premul(a: Color, b: Color, w: float) -> Color:
	var outa: float = a.a * w + b.a * (1.0 - w)
	var pr: float = (a.r * a.a) * w + (b.r * b.a) * (1.0 - w)
	var 결과 := Color(0, 0, 0, 0)
	결과.a = clampf(outa, 0.0, 1.0)
	결과.r = clampf(pr / maxf(outa, 0.002 / 1.0), 0.0, 1.0) if outa > 0.002 else 0.0
	return 결과


func _코너_재현(테마: String) -> void:
	var top := _png(_경로(테마, "grass_edge_top"))
	var side := _png(_경로(테마, "grass_edge_right"))
	if top == null or side == null:
		return
	for kind in ["outer", "inner"]:
		var 원본 := _png(_경로(테마, "grass_corner_" + kind))
		if 원본 == null:
			continue
		var S := 원본.get_width()
		var 합 := 0.0
		var 최대 := 0.0
		var 알파합 := 0.0
		var 알파최대 := 0.0
		var n := 0
		# 경계 한 줄만 따로 본다 (진짜 이음매 자리)
		var 경계합 := 0.0
		var 경계최대 := 0.0
		var 경계n := 0
		for y in S:
			for x in S:
				var px := float(x) + 0.5
				var py := float(y) + 0.5
				var dx: float
				var dy: float
				var v_eq: float
				var phi: float
				if kind == "outer":
					dx = px
					dy = float(S) - py
					var r0 := sqrt(dx * dx + dy * dy)
					v_eq = 1.0 - r0 / float(S)
					phi = atan2(dy, maxf(dx, 1e-6))
				else:
					dx = float(S) - px
					dy = py
					var r1 := sqrt(dx * dx + dy * dy)
					v_eq = r1 / float(S)
					phi = atan2(maxf(dx, 1e-6), maxf(dy, 1e-6))
				var r := sqrt(dx * dx + dy * dy)
				var t := clampf((clampf(phi / (PI * 0.5), 0.0, 1.0) - 0.15) / 0.70, 0.0, 1.0)
				var w_top := t * t * (3.0 - 2.0 * t)
				var u_top := 0.31 + ((PI * 0.5 - phi) * r) / float(top.get_width())
				var u_side := 0.62 - (phi * r) / float(side.get_width())
				var 계산 := blend_premul(_샘플(top, u_top, v_eq), _샘플(side, u_side, v_eq), w_top)
				var 실제 := 원본.get_pixel(x, y)
				var da := absf(계산.a - 실제.a) * 255.0
				알파합 += da
				알파최대 = maxf(알파최대, da)
				if 실제.a * 255.0 > 127.0:
					var d := absf(계산.r - 실제.r) * 255.0
					합 += d
					최대 = maxf(최대, d)
					n += 1
					var 경계: bool = (x == 0 or y == S - 1) if kind == "outer" else (y == 0 or x == S - 1)
					if 경계:
						경계합 += d
						경계최대 = maxf(경계최대, d)
						경계n += 1
		print("  %-6s %-6s 전체 평균 %.3f 최대 %.2f (n %d) | 알파 평균 %.3f 최대 %.2f | 경계줄 평균 %.3f 최대 %.2f (n %d)"
			% [테마, kind, 합 / maxf(1.0, float(n)), 최대, n,
				알파합 / float(S * S), 알파최대,
				경계합 / maxf(1.0, float(경계n)), 경계최대, 경계n])


# ------------------------------------------------------------------ 6) 필 vs 엣지 안쪽 톤
func _안쪽평균(im: Image, lo: float, hi: float) -> float:
	var H := im.get_height()
	var s := 0.0
	var w := 0.0
	for y in range(int(float(H) * lo), int(float(H) * hi)):
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			s += c.r * 255.0 * c.a
			w += c.a
	return s / maxf(0.0001, w)


func _톤_검사(테마: String) -> void:
	var 합 := 0.0
	var n := 0
	for 이름 in 톤엣지:
		var im := _png(_경로(테마, 이름))
		if im == null:
			continue
		합 += _안쪽평균(im, 0.55, 0.77)
		n += 1
	var 엣지안쪽 := 합 / maxf(1.0, float(n))
	var fd := _png(_경로(테마, "grass_fill_detail"))
	var fs := _png(_경로(테마, "grass_fill_solid"))
	var hd := _히스토(fd, false)
	var hs := _히스토(fs, false)
	print("  %-6s 엣지 안쪽 톤 %6.2f   fill_detail %6.2f (차 %+5.2f)   fill_solid %6.2f (차 %+5.2f)"
		% [테마, 엣지안쪽, _평균(hd), _평균(hd) - 엣지안쪽, _평균(hs), _평균(hs) - 엣지안쪽])
	print("         fill_detail 내부 디테일 폭 p05~p95 = %.0f ~ %.0f (%d 단계)"
		% [_분위(hd, 0.05), _분위(hd, 0.95), int(_분위(hd, 0.95) - _분위(hd, 0.05))])
	print("         fill_solid  내부 디테일 폭 p05~p95 = %.0f ~ %.0f (%d 단계)"
		% [_분위(hs, 0.05), _분위(hs, 0.95), int(_분위(hs, 0.95) - _분위(hs, 0.05))])


# ------------------------------------------------------------------ 7) 배율 환산
func _배율표() -> void:
	print("\n[7] texture_scale 후보별 월드 치수 (TOP 1024x256 / 코너 캐리어 256 기준)")
	print("  플레이어 55 x 264 월드px · 카메라 줌 0.82 · 뷰포트 1920x1080")
	print("  -> 화면이 담는 월드 영역 %.0f x %.0f px" % [1920.0 / 0.82, 1080.0 / 0.82])
	print("  %6s %8s %10s %8s %10s %12s %12s"
		% ["scale", "띠두께", "잔디술", "코너변", "반복주기", "플레이어키비", "화면당반복"])
	for s in [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45]:
		var 띠: float = 256.0 * s
		var 주기: float = 1024.0 * s
		print("  %6.2f %8.0f %10.0f %8.0f %10.0f %11.0f%% %12.1f"
			% [s, 띠, 띠 * 0.367, 띠, 주기, 띠 / 264.0 * 100.0, (1920.0 / 0.82) / 주기])


# ------------------------------------------------------------------ 8) 잔디 술 실측
## "잔디 술" = TOP 텍스처에서 위쪽부터 알파가 충분히 차오르기 전까지의 들쭉날쭉한 구간.
## 행별 평균 알파가 0.5 를 처음 넘는 지점까지를 술 높이로 본다.
func _술높이() -> void:
	print("\n[8] 잔디 술 높이 실측 (행 평균 알파 0.5 도달 지점)")
	for 테마 in ["black", "white"]:
		for 이름 in ["grass_edge_top", "grass_edge_top_alt"]:
			var im := _png(_경로(테마, 이름))
			if im == null:
				continue
			var H := im.get_height()
			var W := im.get_width()
			var 술 := H
			for y in H:
				var a := 0.0
				for x in W:
					a += im.get_pixel(x, y).a
				if a / float(W) >= 0.5:
					술 = y
					break
			print("  %-6s %-20s 술 %3d px / 띠 %3d px = %.1f%%   (scale 0.35 -> 월드 %.0f px)"
				% [테마, 이름, 술, H, float(술) / float(H) * 100.0, float(술) * 0.35])


# ------------------------------------------------------------------ 9) 대비 사다리
## STEP 4 의 색상 테스트 시트를 수치로 다시 만든다.
##
## 파이프라인이 쓰는 유일한 색 변환은 감마다: y = (x/255)^g * 255.
## 단조증가라 픽셀 밝기 '순서' 가 안 바뀌고(구조 보존) 클리핑이 없다.
## 그러니 원본(tools/grass_v4_pipeline/src/) 에 감마를 걸어 보면
## 현재 / A / B(채택) / C 각 단계가 어떤 평균으로 가는지 그대로 나온다.
## WHITE 는 BLACK 의 휘도 반전이므로 255 - BLACK 이다 (따로 계산하지 않는다).
const 원본들 := [
	"res://tools/grass_v4_pipeline/src/black_grass_top_B_1024x256.png",
	"res://tools/grass_v4_pipeline/src/black_grass_bottom_1024x192.png",
	"res://tools/grass_v4_pipeline/src/black_grass_side_1024x256.png",
]
const 원본필 := "res://tools/grass_v4_pipeline/src/black_grass_fill_1024.png"


func _감마평균(h: PackedInt64Array, g: float) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var acc := 0.0
	for i in 256:
		if h[i] == 0:
			continue
		acc += pow(float(i) / 255.0, g) * 255.0 * float(h[i])
	return acc / float(n)


func _감마분위(h: PackedInt64Array, g: float, q: float) -> float:
	# 감마는 단조증가라 분위수 자리가 안 바뀐다 -> 원본 분위수에 감마만 걸면 된다.
	return pow(_분위(h, q) / 255.0, g) * 255.0


func _대비사다리() -> void:
	print("\n[9] 대비 사다리 — 원본(src/) 에 감마를 걸었을 때 (STEP 4 테스트 시트 재현)")
	var 합계 := _빈히스토()
	var 필히스토 := _빈히스토()
	for p in 원본들:
		var im := _png(p)
		if im == null:
			print("  (원본 없음: %s)" % p)
			return
		합계 = _더하기(합계, _히스토(im, true))
	var f := _png(원본필)
	if f != null:
		필히스토 = _히스토(f, false)
		합계 = _더하기(합계, 필히스토)
	print("  %-14s %8s %10s %10s %12s   %s"
		% ["단계", "감마", "BLACK평균", "WHITE평균", "대비폭", "필 내부 p05~p95"])
	var 단계 := [["현재(원본)", 1.00], ["A", 1.35], ["B (채택)", 1.60], ["C", 1.90]]
	for s in 단계:
		var g: float = s[1]
		var b := _감마평균(합계, g)
		var 필lo := _감마분위(필히스토, g, 0.05)
		var 필hi := _감마분위(필히스토, g, 0.95)
		print("  %-14s %8.2f %10.2f %10.2f %12.1f   %.0f ~ %.0f (%d 단계)"
			% [s[0], g, b, 255.0 - b, 255.0 - 2.0 * b, 필lo, 필hi, int(필hi - 필lo)])
	print("  ※ 커밋된 PNG 의 실측 평균은 위 [1] 의 집계값이다. 파이프라인이 감마 외에")
	print("    알파 바닥 제거·안쪽 페이드·필 톤 맞추기를 더 하므로 몇 단계 차이가 난다.")


# ------------------------------------------------------------------ 실행
func _실행() -> void:
	print("=".repeat(96))
	print("grass_v4 시각 품질 실측  (원본 PNG 바이트 직접 측정)")
	print("=".repeat(96))

	print("\n[1] 테마별 휘도 통계 (엣지·코너는 알파>127 픽셀만, 필은 전부)")
	var b := _테마_통계("black")
	var w := _테마_통계("white")
	print("\n  BLACK 집계 평균 %.2f   WHITE 집계 평균 %.2f   대비 폭 %.1f / 255 (%.1f%%)"
		% [b["평균"], w["평균"], w["평균"] - b["평균"], (w["평균"] - b["평균"]) / 255.0 * 100.0])

	_반전_검사()
	_타일링_검사()
	_모티프_검사()

	print("\n[5] 코너 <-> 엣지 단면 이음매 (경계열 = u 0.31 TOP 단면 이라는 근사로 측정)")
	_코너_검사("black")
	_코너_검사("white")

	print("\n[5-b] 코너 재현 검사 (apply_final.py 수식을 그대로 다시 계산해 커밋된 PNG 와 비교)")
	print("      -> 잔차가 작으면 5) 의 p95 는 '이음매 오차' 가 아니라 근사 오차다")
	_코너_재현("black")
	_코너_재현("white")

	print("\n[6] 필 <-> 엣지 안쪽 톤 연결")
	_톤_검사("black")
	_톤_검사("white")

	_배율표()
	_술높이()
	_대비사다리()

	print("\n" + "=".repeat(96))
	quit(0)
