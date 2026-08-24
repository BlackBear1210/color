extends SceneTree
## ============================================================================
## [2026-08-24 신규] 타일셋 파생 에셋 생성기 — apply_final.py 의 GDScript 이식 (재질 무관)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_타일셋_파생.gd -- \
##       --원본=res://.../src --출력=res://assets/textures/smartshape/brick_v1 \
##       [--감마=1.60] [--키잉=magenta] [--이음매폭=0.10] [--확인만]
##
## ▣ 왜 GDScript 인가 (추측 아님 — 실제로 조사하고 정한 것)
##   apply_final.py 가 쓰는 연산을 전부 열거해 보니
##   numpy 산술 / power(감마) / percentile / hypot·arctan2(코너 극좌표) /
##   FLIP_LEFT_RIGHT / tile 3x3 / LANCZOS resize / GaussianBlur 뿐이다.
##   이 중 Godot 에 없는 건 GaussianBlur 하나이고 분리형으로 20줄이면 된다.
##   LANCZOS 는 Image.INTERPOLATE_LANCZOS 로 실제 동작을 확인했다.
##   코너 극좌표 합성은 이미 GDScript 로 재구현해 Python 산출물과
##   **최대 잔차 1.00/255** 로 일치함을 확인해 뒀다.
##   ★ 픽셀 단위 동일성은 요구되지 않는다 — grass_v4 산출물은 LOCK 이라
##     다시 굽지 않고, 새 재질은 알고리즘만 같으면 된다.
##
## ▣ 파이프라인 (마스터 템플릿 §7 그대로)
##   마스터 이미지 → 배경 키잉 → 그레이스케일 → 좌우 seamless → 띠 추출
##   → 알파 바닥 제거 → 감마 → 안쪽 알파 페이드 → 필(톤 맞추기 + solid 파생)
##   → 코너 극좌표 합성 → taper 합성 → 흰색 = 검정 휘도 반전
##
## ▣ 만드는 것 (테마당 16장, 합계 32장)
##   <출력>/black/  edge_{top,bottom,left,right} corner_{outer,inner} fill_{detail,solid}
##   <출력>/white/  (같은 8장 — 반전)
##   <출력>/taper/{black,white}/ taper_{top,bottom,left,right}_{left,right}
##
## ▣ 원본 파일명 (없으면 무엇이 없는지 찍고 멈춘다)
##   <원본>/master_top.png  master_bottom.png  master_side.png  master_fill.png
## ============================================================================

# ---- 마스터 템플릿 확정 상수 (§5, §6). 재질별로 바꿀 일이 거의 없다 ----
const 출력폭 := 1024
const TOP높이 := 256
const BOTTOM높이 := 192
const SIDE높이 := 256
const FILL변 := 1024
const 코너변 := 256
const TAPER폭 := 128
const TAPER높이 := 256
const TAPER페이드 := 0.35
const U_TOP := 0.31
const U_SIDE := 0.62
const 알파바닥 := 0.06      # 리샘플 잔여 알파 제거 임계
const 안쪽페이드 := 0.22    # 띠 안쪽 알파 페이드 구간 비율
const SOLID대비 := 0.20     # solid 는 detail 대비를 20% 로 눌러 만든다

var _원본 := ""
var _출력 := ""
var _감마 := 1.60
var _이음매폭 := 0.10
## 코너 합성 방식: polar(grass 확정) 또는 miter(규칙적 격자 재질용)
var _코너방식 := "polar"
var _확인만 := false
var _빠짐: PackedStringArray = PackedStringArray()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--원본="):
			_원본 = a.substr("--원본=".length()).rstrip("/")
		elif a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length()).rstrip("/")
		elif a.begins_with("--감마="):
			_감마 = a.substr("--감마=".length()).to_float()
		elif a.begins_with("--이음매폭="):
			_이음매폭 = a.substr("--이음매폭=".length()).to_float()
		elif a.begins_with("--코너방식="):
			_코너방식 = a.substr("--코너방식=".length())
		elif a == "--확인만":
			_확인만 = true
	call_deferred("_실행")


# ------------------------------------------------------------------ 입출력
func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		_빠짐.push_back(경로)
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		_빠짐.push_back(경로 + " (디코드 실패)")
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _저장(im: Image, 경로: String) -> void:
	if _확인만:
		return
	var 절대 := ProjectSettings.globalize_path(경로)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	if im.save_png(절대) != OK:
		push_error("저장 실패: %s" % 경로)


# ------------------------------------------------------------------ 1) 배경 키잉 + 그레이스케일
## 마젠타 계열(R,B 높고 G 낮음) 픽셀을 투명으로 만든다.
## AI 생성물은 키 색이 완전히 균일하지 않으므로 거리 기반으로 부드럽게 판정한다.
func _키잉_그레이(im: Image) -> Image:
	var W := im.get_width()
	var H := im.get_height()
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var c := im.get_pixel(x, y)
			# 마젠타다움: R,B 가 크고 G 가 작을수록 1 에 가깝다
			var 마젠타 := minf(c.r, c.b) - c.g
			var a := 1.0
			if 마젠타 > 0.15:
				# 0.15 에서 0.45 사이를 알파 1->0 으로 부드럽게 넘긴다
				a = clampf(1.0 - (마젠타 - 0.15) / 0.30, 0.0, 1.0)
			# ★ 디스필(despill) — 경계 픽셀의 색을 키 색에서 되돌린다.
			#   경계의 반투명 픽셀은 '마젠타 절반 + 벽돌 절반' 이라 그냥 휘도를 재면
			#   벽돌보다 밝게 나온다. 그 밝은 테두리를 코너 극좌표 합성이
			#   부채꼴로 늘려 버려서 코너에 회색 안개가 생겼다 (실제로 겪음).
			#   키가 마젠타(G=0)이고 벽돌은 무채색(R=G=B)이므로
			#   관측 G = alpha x 벽돌휘도 -> 벽돌휘도 = G / alpha 로 정확히 복원된다.
			var lum: float
			if a > 0.004:
				lum = clampf(c.g / a, 0.0, 1.0)
			else:
				lum = 0.0
			out.set_pixel(x, y, Color(lum, lum, lum, a * c.a))
	return out


# ------------------------------------------------------------------ 2) 좌우 seamless
## 왼쪽 w 열을 오른쪽 끝 w 열과 교차 페이드한 뒤 오른쪽 w 열을 버린다.
## 그러면 새 왼쪽 끝과 새 오른쪽 끝이 원본에서 서로 이웃이던 열이 되어 이어진다.
func _가로_seamless(im: Image, 비율: float) -> Image:
	var W := im.get_width()
	var H := im.get_height()
	var w: int = clampi(int(float(W) * 비율), 1, W / 3)
	var nW := W - w
	var out := Image.create(nW, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in nW:
			var c: Color
			if x < w:
				var f: float = float(x) / float(w)
				var s: float = f * f * (3.0 - 2.0 * f)   # smoothstep
				var a := im.get_pixel(W - w + x, y)      # 오른쪽 끝 (새 왼쪽이 될 내용)
				var b := im.get_pixel(x, y)              # 원래 왼쪽
				c = a.lerp(b, s)
			else:
				c = im.get_pixel(x, y)
			out.set_pixel(x, y, c)
	return out


# ------------------------------------------------------------------ 3) 띠 추출
## ★ SS2D 규칙 (grass_v4 원본을 실측해 확인): **네 방향 엣지 전부**
##   텍스처의 위쪽(v=0)이 지형 **바깥**, 아래쪽(v=1)이 지형 **안쪽**이다.
##   grass_bottom 도 불투명 구간이 행 68~191(아래쪽)이었다.
##   따라서 BOTTOM 마스터처럼 너덜한 가장자리가 아래에 있는 그림은
##   **세로로 뒤집어서** 너덜한 쪽을 위로 올려야 한다.
##
## ★ 종횡비를 지켜야 한다. 마스터 전체를 256px 로 눌러 담으면
##   벽돌이 6배 납작해져서 벽돌로 안 보인다.
##   가로 축소율과 같은 비율로 세로를 잘라낸다.
func _띠추출(원본: Image, 출력높이: int, 세로뒤집기: bool) -> Image:
	var im: Image = 원본.duplicate()
	if 세로뒤집기:
		im.flip_y()
	var W := im.get_width()
	var H := im.get_height()
	# ★ 기준선은 '가장 뾰족한 봉우리' 가 아니라 **열별 실루엣의 중앙값** 이다.
	#   최고점에 맞추면, 골이 깊은 재질(벽돌의 부서진 윗면 등)은 띠의 대부분이
	#   빈 공간이 되어 버린다. 실제로 벽돌 엣지가 40.7% 투명이 되었고
	#   (잔디는 21.5%), 그 빈 구간을 코너 합성이 코너 전체로 퍼뜨려서
	#   코너가 '반투명한 벽돌 유령' 으로 렌더됐다.
	#   중앙값을 쓰면 평균적인 윗면이 제자리에 오고 봉우리만 위로 삐져나온다.
	var 첫행 := PackedInt32Array()
	for x in W:
		for y in H:
			if im.get_pixel(x, y).a > 0.5:
				첫행.push_back(y)
				break
	var 경계 := 0
	if not 첫행.is_empty():
		첫행.sort()
		경계 = 첫행[첫행.size() / 2]
	# 가로 축소율과 같게 세로를 잡아 종횡비를 보존한다
	var 축소: float = float(출력폭) / float(W)
	var src높이: int = maxi(8, int(round(float(출력높이) / 축소)))
	# grass 실측: 불투명 시작이 높이의 약 26% 지점 -> 그 비율을 맞춘다
	var y0: int = 경계 - int(round(float(src높이) * 0.26))
	y0 = clampi(y0, 0, maxi(0, H - src높이))
	var h: int = mini(src높이, H - y0)
	var 조각 := Image.create(W, h, false, Image.FORMAT_RGBA8)
	조각.blit_rect(im, Rect2i(0, y0, W, h), Vector2i(0, 0))
	조각.resize(출력폭, 출력높이, Image.INTERPOLATE_LANCZOS)
	return 조각


# ------------------------------------------------------------------ 4) 엣지 마감
func _감마적용(v: float) -> float:
	return clampf(pow(clampf(v, 0.0, 1.0), _감마), 0.0, 1.0)


## 알파 바닥 제거 + 감마 + 안쪽 알파 페이드.
## 아래방향=true 면 띠의 '안쪽'이 아래쪽이다(TOP/SIDE). BOTTOM 은 안쪽이 위쪽이다.
func _엣지마감(im: Image, 안쪽이아래: bool) -> Image:
	var W := im.get_width()
	var H := im.get_height()
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var n: int = maxi(1, int(round(float(H) * 안쪽페이드)))
	for y in H:
		# 안쪽 끝 n 행에서 코사인으로 알파를 0 까지 내린다 (양 끝 기울기 0)
		var 마스크 := 1.0
		var d: int = (H - 1 - y) if 안쪽이아래 else y
		if d < n:
			var t: float = 1.0 - float(d) / float(n)
			마스크 = 0.5 * (1.0 + cos(PI * (1.0 - t)))
		for x in W:
			var c := im.get_pixel(x, y)
			var a: float = clampf((c.a - 알파바닥) / (1.0 - 알파바닥), 0.0, 1.0) * 마스크
			var l := _감마적용(c.r)
			out.set_pixel(x, y, Color(l, l, l, a))
	return out


## 엣지 안쪽(페이드 시작 직전) 구간의 알파 가중 평균 휘도. 필이 이어받아야 할 톤.
func _안쪽톤(im: Image, 안쪽이아래: bool) -> float:
	var H := im.get_height()
	var lo := 0.55
	var hi := 0.77
	var y0: int
	var y1: int
	if 안쪽이아래:
		y0 = int(float(H) * lo)
		y1 = int(float(H) * hi)
	else:
		y0 = int(float(H) * (1.0 - hi))
		y1 = int(float(H) * (1.0 - lo))
	var s := 0.0
	var w := 0.0
	for y in range(y0, y1):
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			s += c.r * c.a
			w += c.a
	return (s / maxf(w, 0.0001)) * 255.0


# ------------------------------------------------------------------ 5) 필
## 순환 가우시안 블러 (분리형). PIL 의 GaussianBlur 는 가장자리를 복제해서
## 그대로 쓰면 타일 경계에 격자선이 생긴다. 색인을 순환시키면 3x3 으로 깔 필요가 없다.
func _순환블러(im: Image, sigma: float) -> Image:
	var W := im.get_width()
	var H := im.get_height()
	var r: int = maxi(1, int(ceil(sigma * 3.0)))
	var k := PackedFloat64Array()
	var 합 := 0.0
	for i in range(-r, r + 1):
		var v: float = exp(-float(i * i) / (2.0 * sigma * sigma))
		k.push_back(v)
		합 += v
	for i in k.size():
		k[i] = k[i] / 합
	# 가로
	var tmp := PackedFloat64Array()
	tmp.resize(W * H)
	for y in H:
		for x in W:
			var acc := 0.0
			for i in range(-r, r + 1):
				acc += im.get_pixel(((x + i) % W + W) % W, y).r * k[i + r]
			tmp[y * W + x] = acc
	# 세로
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var acc := 0.0
			for i in range(-r, r + 1):
				acc += tmp[(((y + i) % H + H) % H) * W + x] * k[i + r]
			var v: float = clampf(acc, 0.0, 1.0)
			out.set_pixel(x, y, Color(v, v, v, 1.0))
	return out


## 순환 축소: 3x3 으로 깔아 축소한 뒤 가운데만 잘라낸다.
## LANCZOS 는 가장자리에서 커널이 잘려 끝 픽셀이 어긋나기 때문이다.
func _순환축소(im: Image, 변: int) -> Image:
	var W := im.get_width()
	var H := im.get_height()
	var big := Image.create(W * 3, H * 3, false, Image.FORMAT_RGBA8)
	for ty in 3:
		for tx in 3:
			big.blit_rect(im, Rect2i(0, 0, W, H), Vector2i(tx * W, ty * H))
	big.resize(변 * 3, 변 * 3, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(변, 변, false, Image.FORMAT_RGBA8)
	out.blit_rect(big, Rect2i(변, 변, 변, 변), Vector2i(0, 0))
	return out


func _필만들기(원본필: Image, 목표톤: float) -> Array:
	var im: Image = 원본필.duplicate()
	im.resize(FILL변, FILL변, Image.INTERPOLATE_LANCZOS)
	# 감마 → 평균을 엣지 안쪽 톤에 맞춘다
	var 합 := 0.0
	var 값 := PackedFloat64Array()
	값.resize(FILL변 * FILL변)
	for y in FILL변:
		for x in FILL변:
			var g := _감마적용(im.get_pixel(x, y).r)
			값[y * FILL변 + x] = g
			합 += g
	var 평균: float = 합 / float(FILL변 * FILL변)
	var 이동: float = 목표톤 / 255.0 - 평균
	var detail := Image.create(FILL변, FILL변, false, Image.FORMAT_RGBA8)
	for y in FILL변:
		for x in FILL변:
			var v: float = clampf(값[y * FILL변 + x] + 이동, 0.0, 1.0)
			detail.set_pixel(x, y, Color(v, v, v, 1.0))
	# solid = detail 을 순환 축소 + 순환 블러 + 대비 20% 압축 -> 평균이 자동으로 같다
	var 작 := _순환축소(detail, 코너변)
	var m := 0.0
	for y in 코너변:
		for x in 코너변:
			m += 작.get_pixel(x, y).r
	m /= float(코너변 * 코너변)
	var 블러 := _순환블러(작, float(코너변) / 24.0)
	var solid := Image.create(코너변, 코너변, false, Image.FORMAT_RGBA8)
	for y in 코너변:
		for x in 코너변:
			var v: float = clampf(m + (블러.get_pixel(x, y).r - m) * SOLID대비, 0.0, 1.0)
			solid.set_pixel(x, y, Color(v, v, v, 1.0))
	return [detail, solid]


# ------------------------------------------------------------------ 6) 코너 합성
func _샘플(im: Image, u: float, v: float) -> Color:
	var W := im.get_width()
	var H := im.get_height()
	var x := fposmod(u, 1.0) * float(W) - 0.5
	var y: float = clampf(v, 0.0, 1.0) * float(H - 1)
	var x0 := int(floor(x)); var y0 := int(floor(y))
	var fx := x - float(x0); var fy := y - float(y0)
	var x0m := ((x0 % W) + W) % W
	var x1m := (((x0 + 1) % W) + W) % W
	var y0c := clampi(y0, 0, H - 1); var y1c := clampi(y0 + 1, 0, H - 1)
	var a := im.get_pixel(x0m, y0c).lerp(im.get_pixel(x1m, y0c), fx)
	var b := im.get_pixel(x0m, y1c).lerp(im.get_pixel(x1m, y1c), fx)
	return a.lerp(b, fy)


## 프리멀티플라이 블렌드 (알파가 낮은 곳에서 색이 끌려가지 않게)
func _블렌드(a: Color, b: Color, w: float) -> Color:
	var outa: float = a.a * w + b.a * (1.0 - w)
	var pr: float = (a.r * a.a) * w + (b.r * b.a) * (1.0 - w)
	var r: float
	# ★ 언프리멀티플라이(pr/outa)는 알파가 작아지면 폭주한다.
	#   alpha 0.01 인데 pr 이 조금만 커도 몫이 1.0 으로 잘려 **흰색**이 된다.
	#   그 흰 픽셀은 낮은 알파로 깔리기 때문에 통계(알파>127 필터)에는 안 잡히는데
	#   밝은 배경 위에 합성되면 배경보다 더 밝은 사각 얼룩으로 드러난다.
	#   벽돌에서 코너 자리에 흰 블록이 뜬 원인이 바로 이것이었다.
	#   (원본 apply_final.py 의 가드 0.002 는 유기적인 잔디에서만 우연히 안 터졌다)
	#   알파가 낮은 구간에서는 나눗셈을 아예 쓰지 않고 색만 가중평균한다.
	#   어차피 거의 안 보이는 구간이라 색 정확도보다 폭주 방지가 중요하다.
	if outa > 0.05:
		r = clampf(pr / outa, 0.0, 1.0)
	else:
		r = clampf(a.r * w + b.r * (1.0 - w), 0.0, 1.0)
	return Color(r, r, r, clampf(outa, 0.0, 1.0))


## ★ 코너 합성 방식 두 가지 — 재질의 성격에 따라 고른다
##
##   polar : 극좌표로 감는다 (grass_v4 확정 방식).
##           띠가 코너를 **돌아가는** 그림이 되어 유기적인 질감에 잘 맞는다.
##   miter : 두 띠를 각각 **직선 그대로** 이어 붙이고 45도 대각선에서 섞는다.
##           벽돌처럼 규칙적인 격자 무늬는 극좌표로 감으면 줄눈이 부채꼴로
##           휘어져서 직선 줄눈과 절대 안 맞는다. 그래서 직선을 유지한다.
##
## 두 방식 모두 **엣지의 실제 단면에서만** 만든다 (AI 로 코너를 그리지 않는다).
## 경계는 동일하다: 왼쪽 열(OUTER) / 위 행(INNER) = TOP 단면 u=0.31,
##                 아래 행(OUTER) / 오른쪽 열(INNER) = SIDE 단면 u=0.62.
func _코너합성_miter(top: Image, side: Image, 바깥: bool) -> Image:
	var S := 코너변
	var topW := float(top.get_width())
	var sideW := float(side.get_width())
	var out := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var px: float = (float(x) + 0.5) / float(S)
			var py: float = (float(y) + 0.5) / float(S)
			var phi: float
			var u_t: float
			var v_t: float
			var u_s: float
			var v_s: float
			if 바깥:
				# 왼쪽 열(px=0)이 TOP 단면, 아래 행(py=1)이 SIDE 단면
				phi = atan2((1.0 - py) * float(S), maxf(px * float(S), 1e-6))
				u_t = U_TOP + px * float(S) / topW
				v_t = py
				u_s = U_SIDE - (1.0 - py) * float(S) / sideW
				v_s = 1.0 - px
			else:
				# 위 행(py=0)이 TOP 단면, 오른쪽 열(px=1)이 SIDE 단면
				phi = atan2((1.0 - px) * float(S), maxf(py * float(S), 1e-6))
				u_t = U_TOP + py * float(S) / topW
				v_t = 1.0 - px
				u_s = U_SIDE - (1.0 - px) * float(S) / sideW
				v_s = py
			# 45도 대각선에서 부드럽게 섞는다 (경계에서는 한쪽만 100%)
			var t: float = clampf((clampf(phi / (PI * 0.5), 0.0, 1.0) - 0.15) / 0.70, 0.0, 1.0)
			var w_top := t * t * (3.0 - 2.0 * t)
			out.set_pixel(x, y, _블렌드(_샘플(top, u_t, v_t), _샘플(side, u_s, v_s), w_top))
	return out


## OUTER: 중심 UV(0,1) = 지형 안쪽 구석 / INNER: 중심 UV(1,0) = 바깥 빈 구석
## u 는 반드시 **호 길이**에 비례해야 한다. 각도 비례면 방사형으로 뭉갠다.
func _코너합성(top: Image, side: Image, 바깥: bool) -> Image:
	var S := 코너변
	var out := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var dx: float
			var dy: float
			var v_eq: float
			var phi: float
			if 바깥:
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
			# 각도 블렌드는 중심에서 축퇴한다. smoothstep 으로 이음매에서 포화시킨다.
			var t: float = clampf((clampf(phi / (PI * 0.5), 0.0, 1.0) - 0.15) / 0.70, 0.0, 1.0)
			var w_top := t * t * (3.0 - 2.0 * t)
			var u_top := U_TOP + ((PI * 0.5 - phi) * r) / float(top.get_width())
			var u_side := U_SIDE - (phi * r) / float(side.get_width())
			var c := _블렌드(_샘플(top, u_top, v_eq), _샘플(side, u_side, v_eq), w_top)
			if 바깥 and v_eq < 0.0:
				c.a = 0.0
			out.set_pixel(x, y, c)
	return out


# ------------------------------------------------------------------ 7) taper
## 엣지의 u ∈ [0.31 − N/엣지폭, 0.31] 실제 그림 + 바깥 끝 알파 페이드.
## ★ 평균 단면으로 만들면 톤은 이어지지만 그림이 사라져 뭉갠 자국이 된다 (한 번 겪음).
func _taper합성(엣지: Image, 오른쪽: bool) -> Image:
	var N := TAPER폭
	var H := TAPER높이
	var out := Image.create(N, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var t: float = (float(y) + 0.5) / float(H)
		for x in N:
			var s: float = (float(x) + 0.5) / float(N)
			if not 오른쪽:
				s = 1.0 - s
			var u: float = U_TOP - (1.0 - s) * (float(N) / float(엣지.get_width()))
			var c := _샘플(엣지, u, t)
			var k: float = clampf((s - (1.0 - TAPER페이드)) / TAPER페이드, 0.0, 1.0)
			var a: float = c.a * (0.5 * (1.0 + cos(PI * k)))
			out.set_pixel(x, y, Color(c.r, c.r, c.r, clampf(a, 0.0, 1.0)))
	return out


# ------------------------------------------------------------------ 8) 흰색 = 검정 반전
func _반전(im: Image) -> Image:
	var out := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			out.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.r, 1.0 - c.r, c.a))
	return out


func _좌우반전(im: Image) -> Image:
	var out: Image = im.duplicate()
	out.flip_x()
	return out


# ------------------------------------------------------------------ 실행
func _실행() -> void:
	if _원본.is_empty() or _출력.is_empty():
		push_error("--원본= 과 --출력= 이 필요하다")
		quit(1)
		return
	print("원본 %s\n출력 %s\n감마 %.2f" % [_원본, _출력, _감마])

	var 마스터 := {}
	for n in ["top", "bottom", "side", "fill"]:
		마스터[n] = _png("%s/master_%s.png" % [_원본, n])
	if not _빠짐.is_empty():
		print("\n빠진 원본:")
		for p in _빠짐:
			print("  - %s" % p)
		quit(1)
		return
	for n in ["top", "bottom", "side", "fill"]:
		var im: Image = 마스터[n]
		print("  master_%-7s %d x %d" % [n, im.get_width(), im.get_height()])

	# --- 1~3: 키잉 → 그레이 → seamless → 띠 추출 ---
	print("\n1) 키잉 + 그레이스케일 + 좌우 seamless + 띠 추출")
	var top := _띠추출(_가로_seamless(_키잉_그레이(마스터["top"]), _이음매폭), TOP높이, false)
	# BOTTOM 마스터는 너덜한 가장자리가 아래에 있으므로 뒤집어서 위로 올린다
	var bottom := _띠추출(_가로_seamless(_키잉_그레이(마스터["bottom"]), _이음매폭), BOTTOM높이, true)
	var side := _띠추출(_가로_seamless(_키잉_그레이(마스터["side"]), _이음매폭), SIDE높이, false)
	var fill원 := _가로_seamless(_키잉_그레이(마스터["fill"]), _이음매폭)

	# --- 4: 엣지 마감 ---
	print("2) 엣지 마감 (알파 바닥 %.2f · 감마 %.2f · 안쪽 페이드 %.2f)"
		% [알파바닥, _감마, 안쪽페이드])
	var e_top := _엣지마감(top, true)
	var e_bottom := _엣지마감(bottom, true)   # 네 방향 모두 안쪽이 아래다
	var e_left := _엣지마감(side, true)
	var e_right := _좌우반전(e_left)

	# --- 5: 필 ---
	var 톤 := (_안쪽톤(e_top, true) + _안쪽톤(e_bottom, true)
		+ _안쪽톤(e_left, true) + _안쪽톤(e_right, true)) / 4.0
	print("3) 필 (엣지 안쪽 목표 톤 %.2f)" % 톤)
	var 필 := _필만들기(fill원, 톤)

	# --- 6: 코너 ---
	print("4) 코너 합성 방식 %s (u_top %.2f / u_side %.2f)" % [_코너방식, U_TOP, U_SIDE])
	var c_outer: Image
	var c_inner: Image
	if _코너방식 == "miter":
		c_outer = _코너합성_miter(e_top, e_right, true)
		c_inner = _코너합성_miter(e_top, e_right, false)
	else:
		c_outer = _코너합성(e_top, e_right, true)
		c_inner = _코너합성(e_top, e_right, false)

	# --- 7: taper ---
	print("5) taper %dx%d (월드 %.1fpx @ 배율 0.35)"
		% [TAPER폭, TAPER높이, float(TAPER폭) * 0.35])
	var 엣지맵 := {"top": e_top, "bottom": e_bottom, "left": e_left, "right": e_right}

	# --- 저장 (검정) + 반전 (흰색) ---
	print("6) 저장")
	var 검정 := {
		"edge_top": e_top, "edge_bottom": e_bottom,
		"edge_left": e_left, "edge_right": e_right,
		"corner_outer": c_outer, "corner_inner": c_inner,
		"fill_detail": 필[0], "fill_solid": 필[1],
	}
	for k in 검정.keys():
		_저장(검정[k], "%s/black/%s.png" % [_출력, k])
		_저장(_반전(검정[k]), "%s/white/%s.png" % [_출력, k])
	for d in 엣지맵.keys():
		for 쪽 in [["right", true], ["left", false]]:
			var t := _taper합성(엣지맵[d], 쪽[1])
			_저장(t, "%s/taper/black/taper_%s_%s.png" % [_출력, d, 쪽[0]])
			_저장(_반전(t), "%s/taper/white/taper_%s_%s.png" % [_출력, d, 쪽[0]])

	print("\n%s: 테마당 16장 (엣지4 + 코너2 + 필2 + taper8), 합계 32장"
		% ["확인만 — 저장 안 함" if _확인만 else "완료"])
	quit(0)
