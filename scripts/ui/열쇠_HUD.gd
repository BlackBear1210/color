extends Control
## ============================================================================
## [2026-10-08 Claude 신규] 반반 열쇠 HUD 칸 — 페인트 게이지 오른쪽
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-A 규칙 1·4·5 · §1-4 7·9
##   · 열쇠 스테이지에 들어오면 **열쇠 전체 외곽선만 점선**(안쪽 금선·고리 구멍 윤곽 없음) → "잠긴 스테이지" 신호.
##   · 조각을 주우면 점선 안이 **주운 반쪽의 실제 모양 그대로** 0.4초 동안 잉크가 차오르듯 채워진다
##     (왼쪽 반 = 검정 · 오른쪽 반 = 흰색).
##   · 둘 다 차면 지그재그 면이 **맞물리며 붙는 연출**(0.6초) → 점선이 실선 = 완성된 열쇠.
##   · 잠긴 문에 열쇠 없이 다가가면 흔들림(`흔들기`) · 조각 하나뿐이면 빈 반쪽이 깜빡인다(`빈쪽_깜빡`).
##
## ▣ 그림
##   `게임용/열쇠/왼쪽_HUD.png` · `오른쪽_HUD.png`(평면 실루엣) · `실루엣.png`(구멍 메운 바깥 윤곽 전용).
##   셋 다 같은 원화 한 장에서 같은 캔버스로 잘랐다(`tools/생성_신규기믹_게임용.py` 열쇠) → 겹치면 픽셀 단위로 맞는다.
##   점선은 그림으로 받지 않고 **실루엣의 바깥 윤곽(BitMap.opaque_to_polygons)** 을 따라 코드로 그린다
##   — 아스트라 HUD 시안은 고리 구멍에도 점선이 남아 기획(외곽선만)과 달랐다(Codex 사용안내 2번).
##
## ▣ 이 노드는 `반반열쇠_관리.gd` 가 열쇠 스테이지에서만 페인트 HUD 의 `루트` 아래에 만든다
##   (HUD 씬 파일은 고치지 않는다 — 열쇠 없는 스테이지에는 칸 자체가 없다).
## ============================================================================

const 폴더 := "res://assets/textures/props/신규기믹_v02/게임용/열쇠/"
const 채움_셰이더 := preload("res://shaders/key_fill.gdshader")

## 그림(2배 저장) → 화면 배율. 0.6 → 열쇠 키 약 86px(페인트 HUD 배율 1.2 와 같은 무게).
@export var 배율: float = 0.6
@export var 채움_시간: float = 0.4
@export var 맞물림_시간: float = 0.6

var _반: Dictionary = {}          ## "왼쪽"/"오른쪽" → TextureRect
var _재질: Dictionary = {}        ## 같은 키 → ShaderMaterial
var _가짐 := {"왼쪽": false, "오른쪽": false}
var _채움 := {"왼쪽": 0.0, "오른쪽": 0.0}
var _완성 := false
var _외곽: PackedVector2Array = PackedVector2Array()   ## 그림 픽셀 좌표(2배) — 그릴 때 배율을 곱한다
var _윤곽: Control = null
var _크기 := Vector2(80, 143)
var _t := 0.0
var _맞물림_t := -1.0
var _흔들_t := 0.0
var _깜빡_t := 0.0
var _깜빡_쪽 := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 실 := load(폴더 + "실루엣.png") as Texture2D
	if 실:
		_크기 = Vector2(실.get_size())
		_외곽 = _바깥윤곽(실.get_image())
	size = _크기 * 배율
	for 쪽 in ["왼쪽", "오른쪽"]:
		var tr := TextureRect.new()
		tr.name = 쪽
		tr.texture = load(폴더 + 쪽 + "_HUD.png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = 채움_셰이더
		m.set_shader_parameter("fill", 0.0)
		tr.material = m
		add_child(tr)
		_반[쪽] = tr
		_재질[쪽] = m
	# 윤곽은 채움 **위**에 그린다(채움 가장자리가 점선을 덮어 끊어 보이지 않게)
	_윤곽 = Control.new()
	_윤곽.name = "윤곽"
	_윤곽.size = size
	_윤곽.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_윤곽)
	_윤곽.draw.connect(_윤곽_그리기)
	set_process(false)


## 실루엣 알파 → 가장 큰 바깥 윤곽 하나(고리 구멍은 도구가 이미 메웠다).
func _바깥윤곽(img: Image) -> PackedVector2Array:
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	var 폴리들 := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 0.8)
	var 최대 := PackedVector2Array()
	for p in 폴리들:
		if p.size() > 최대.size():
			최대 = p
	return 최대


## 관리자가 스테이지에 들어올 때 부른다 — 이미 주운 조각(저장된 진행)은 연출 없이 바로 채운다.
func 준비(왼: bool, 오: bool) -> void:
	_가짐 = {"왼쪽": 왼, "오른쪽": 오}
	for 쪽 in ["왼쪽", "오른쪽"]:
		_채움[쪽] = 1.0 if _가짐[쪽] else 0.0
		_재질[쪽].set_shader_parameter("fill", _채움[쪽])
	_완성 = 왼 and 오
	_윤곽.queue_redraw()


## 조각 하나를 주웠다 — 0.4초 동안 아래에서 위로 차오른다. 둘 다 차면 이어서 맞물림.
func 채우기(쪽: String) -> void:
	_가짐[쪽] = true
	set_process(true)


func 가짐(쪽: String) -> bool:
	return bool(_가짐.get(쪽, false))


func 완성됨() -> bool:
	return _완성


## 화면(뷰포트) 좌표 — 조각이 날아올 목표 · 완성 열쇠가 문으로 떠날 출발점.
func 칸_중심() -> Vector2:
	return get_global_transform_with_canvas() * (size * 0.5)


## 잠긴 문에 열쇠 없이 다가갔다(0.35초 좌우 흔들림).
func 흔들기() -> void:
	_흔들_t = 0.35
	set_process(true)


## 조각 하나만 가지고 문에 갔다 — 무엇이 모자란지 빈 반쪽을 깜빡인다(0.9초).
func 빈쪽_깜빡() -> void:
	for 쪽 in ["왼쪽", "오른쪽"]:
		if not _가짐[쪽]:
			_깜빡_쪽 = 쪽
	_깜빡_t = 0.9
	set_process(true)


## 문에 꽂으러 떠난다 — 칸은 비지 않고 '쓴 열쇠' 로 남아 옅어진다.
func 사용함() -> void:
	modulate.a = 0.45


func _process(delta: float) -> void:
	_t += delta
	var 바쁨 := false
	# ── 채움 ──
	for 쪽 in ["왼쪽", "오른쪽"]:
		var 목표 := 1.0 if _가짐[쪽] else 0.0
		if _채움[쪽] != 목표:
			_채움[쪽] = move_toward(_채움[쪽], 목표, delta / 채움_시간)
			_재질[쪽].set_shader_parameter("fill", _채움[쪽])
			_재질[쪽].set_shader_parameter("wave_phase", _t * 9.0)
			바쁨 = true
	# 둘 다 다 찼으면 → 맞물림 시작(한 번)
	if not _완성 and _채움["왼쪽"] >= 1.0 and _채움["오른쪽"] >= 1.0 and _맞물림_t < 0.0:
		_맞물림_t = 0.0
	# ── 맞물림 0.6초: 0~0.25 벌어짐(±5px) → 0.25~0.4 철컥 붙음(살짝 넘침) → 번쩍 → 점선이 실선 ──
	if _맞물림_t >= 0.0:
		_맞물림_t += delta
		var k := _맞물림_t / 맞물림_시간
		var 벌어짐 := 0.0
		if k < 0.42:
			벌어짐 = 5.0 * sin(k / 0.42 * PI * 0.5)
		elif k < 0.67:
			var u := (k - 0.42) / 0.25
			벌어짐 = lerpf(5.0, -1.2, u * u)
		else:
			벌어짐 = lerpf(-1.2, 0.0, clampf((k - 0.67) / 0.33, 0.0, 1.0))
		_반["왼쪽"].position.x = -벌어짐
		_반["오른쪽"].position.x = 벌어짐
		var 번쩍 := clampf(1.0 - absf(k - 0.62) / 0.18, 0.0, 1.0)
		for 쪽 in ["왼쪽", "오른쪽"]:
			_재질[쪽].set_shader_parameter("flash", 번쩍)
		if k >= 0.62 and not _완성:
			_완성 = true            # 붙는 순간 점선 → 실선
			_윤곽.queue_redraw()
		if k >= 1.0:
			_맞물림_t = -1.0
			for 쪽 in ["왼쪽", "오른쪽"]:
				_반[쪽].position.x = 0.0
				_재질[쪽].set_shader_parameter("flash", 0.0)
		else:
			바쁨 = true
	# ── 흔들림 ──
	if _흔들_t > 0.0:
		_흔들_t = maxf(_흔들_t - delta, 0.0)
		var 세기 := _흔들_t / 0.35
		position.x = _기준x() + sin(_흔들_t * 70.0) * 6.0 * 세기
		바쁨 = 바쁨 or _흔들_t > 0.0
		if _흔들_t <= 0.0:
			position.x = _기준x()
	# ── 빈 반쪽 깜빡임 ──
	if _깜빡_t > 0.0:
		_깜빡_t = maxf(_깜빡_t - delta, 0.0)
		var g := 0.0
		if _깜빡_t > 0.0:
			g = 0.18 + 0.32 * absf(sin(_깜빡_t * PI * 3.3))
		if _깜빡_쪽 != "":
			_재질[_깜빡_쪽].set_shader_parameter("ghost", g)
		바쁨 = 바쁨 or _깜빡_t > 0.0
	if 바쁨:
		_윤곽.queue_redraw()
	else:
		set_process(false)


var _기준x_값 := NAN
func _기준x() -> float:
	if is_nan(_기준x_값):
		_기준x_값 = position.x
	return _기준x_값


func _윤곽_그리기() -> void:
	if _외곽.size() < 3:
		return
	var s := 배율
	var 점들 := PackedVector2Array()
	for p in _외곽:
		점들.append(p * s)
	점들.append(_외곽[0] * s)
	var 밝은 := Color(0.80, 0.80, 0.80, 0.92)
	var 어두운 := Color(0.02, 0.02, 0.02, 0.75)
	if _완성:
		# 실선 — 어두운 받침선 위에 밝은 선(어떤 배경에서도 읽히게)
		_윤곽.draw_polyline(점들, 어두운, 3.6, true)
		_윤곽.draw_polyline(점들, 밝은, 1.8, true)
		return
	# 점선 — 둘레를 따라 길이를 누적해 7px 그리고 5px 쉰다(꼭짓점에서 끊기지 않게 구간을 이어 간다)
	var 켬 := 7.0
	var 끔 := 5.0
	var 누적 := 0.0
	for i in 점들.size() - 1:
		var a := 점들[i]
		var b := 점들[i + 1]
		var 길이 := a.distance_to(b)
		var d := 0.0
		while d < 길이:
			var 주기안 := fmod(누적 + d, 켬 + 끔)
			var 남음 := (켬 - 주기안) if 주기안 < 켬 else (켬 + 끔 - 주기안)
			var 끝 := minf(d + 남음, 길이)
			if 주기안 < 켬:
				var p0 := a.lerp(b, d / 길이)
				var p1 := a.lerp(b, 끝 / 길이)
				_윤곽.draw_line(p0, p1, 어두운, 3.4)
				_윤곽.draw_line(p0, p1, 밝은, 1.7)
			d = 끝 + 0.0001
		누적 += 길이
