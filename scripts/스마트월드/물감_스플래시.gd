extends Node2D
## ============================================================================
## [2026-09-03 신규] 물감 스플래시 — 페인트가 지형에 닿을 때 튀는 연출
## ----------------------------------------------------------------------------
## ▣ 도형님 지시
##   "지금은 그저 블럭이 날라가는 느낌이야. water 5,6,7,8 이펙트처럼 페인트가
##    지형에 닿으면 랜덤한 이펙트를 가져와서 퍼지는 느낌을 매번 다르게 만들거야."
##
## ▣ 왜 파티클(CPUParticles2D)이 아니라 손으로 그리나
##   물 이펙트 gif(Water 05·06·07·08)의 핵심은 **모양이 매번 다른 물줄기**다.
##   파티클은 점을 흩뿌리는 것이라 "왕관처럼 솟는 물기둥", "별처럼 뻗는 가시"
##   같은 **형태**를 못 만든다. 그래서 프레임마다 자라는 물줄기를 직접 그린다.
##   (`player_action_fx.gd` 의 파티클 튐은 남겨 뒀다 — 이건 그 위에 얹는 형태 연출이다)
##
## ▣ 4 가지 원형(archetype) — 매 명중마다 하나를 랜덤으로 고른다
##   0 별폭발  (Water 08) : 사방으로 뻗는 가시. 정면 명중에 어울린다
##   1 부채    (Water 06·07) : 튕긴 방향으로 치우친 가시 다발
##   2 왕관     (Water 03·12) : 표면을 따라 위로 솟는 물기둥 + 방울
##   3 잔뿌림  (Water 05·16) : 가늘고 많은 잔줄기 + 방울
##   같은 원형이라도 씨앗이 매번 달라 굵기·길이·각도·방울이 전부 달라진다.
##
## ▣ 색 — 흑백 게임이라 물감색 그대로 쓴다
##   검정 페인트면 검정 물줄기, 흰 페인트면 흰 물줄기. 어두운/밝은 배경 어디서나
##   보이도록 **가는 반대색 테두리**를 한 겹 깐다(HUD 점의 받침과 같은 수법).
## ============================================================================
class_name 물감스플래시

## 한 가닥(물줄기) = 시작각도·길이·굵기·휨·끝방울 여부.
class 가닥:
	var 각: float
	var 길이: float
	var 굵기: float
	var 휨: float          ## 좌우로 휘는 정도(라디안)
	var 방울: float        ## 끝에 맺히는 물방울 반경(0 이면 없음)
	var 지연: float        ## 자라기 시작하는 시점(0~0.3)

var _색: Color = Color(0.06, 0.06, 0.07)
var _테두리: Color = Color(0.95, 0.95, 0.93, 0.5)
var _바깥: Vector2 = Vector2.UP       ## 표면에서 바깥으로(=튕기는 방향)
var _가닥들: Array = []
var _중심반경: float = 6.0
var _시간: float = 0.0
var _최대수명: float = 0.40
var _크기배율: float = 1.0
var _rng := RandomNumberGenerator.new()
## ★[2026-09-04] 시작()이 준 값을 _ready 까지 들고 있는다. add_child 가 _ready 를 먼저
##   돌리므로, 생성은 반드시 _ready 에서 해야 튕기는 방향(_바깥)이 반영된다.
var _시작점: Vector2 = Vector2.ZERO
var _시작됨: bool = false


## 총알이 명중 지점에서 부른다. `바깥방향` 은 표면 법선(=진행 반대 방향).
## ⚠ 값만 저장한다. 실제 생성은 _ready(). 순서: new() → add_child() → 시작() 중
##   어느 쪽이 먼저 와도 되도록, 시작()이 늦게 오면 여기서 한 번 더 생성한다.
func 시작(지점: Vector2, 바깥방향: Vector2, 색: int, 크기배율: float = 1.0) -> void:
	_시작점 = 지점
	_크기배율 = 크기배율
	_바깥 = 바깥방향.normalized() if not 바깥방향.is_zero_approx() else Vector2.UP
	if 색 == ColorDefs.WHITE:
		_색 = Color(0.97, 0.97, 0.95)
		_테두리 = Color(0.05, 0.05, 0.06, 0.55)
	else:
		_색 = Color(0.055, 0.055, 0.065)
		_테두리 = Color(0.92, 0.94, 0.98, 0.45)
	_시작됨 = true
	# 이미 트리에 들어와 _ready 가 지났으면(= new→add_child→시작 순서) 지금 생성한다.
	if is_inside_tree():
		global_position = _시작점
		if _가닥들.is_empty():
			_생성()
		queue_redraw()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 31                         # 총알(30)보다 살짝 위
	_rng.randomize()
	# 시작()이 먼저 불렸으면 그 값으로, 아니면 기본값으로 생성한다.
	if _시작됨:
		global_position = _시작점
	if _가닥들.is_empty():
		_생성()
	set_process(true)


## 원형을 하나 고르고 그 규칙대로 가닥을 만든다. 여기서 랜덤이 다 정해진다.
func _생성() -> void:
	var 원형 := _rng.randi_range(0, 3)
	var 바깥각 := _바깥.angle()
	_중심반경 = _rng.randf_range(4.5, 7.5) * _크기배율

	match 원형:
		0:  # 별폭발 — 사방 균등 + 각도 지터
			var n := _rng.randi_range(7, 11)
			for i in n:
				var g := 가닥.new()
				g.각 = TAU * float(i) / float(n) + _rng.randf_range(-0.22, 0.22)
				g.길이 = _rng.randf_range(26.0, 62.0) * _크기배율
				g.굵기 = _rng.randf_range(2.2, 4.6) * _크기배율
				g.휨 = _rng.randf_range(-0.25, 0.25)
				g.방울 = _rng.randf_range(0.0, 3.2) * _크기배율 if _rng.randf() > 0.5 else 0.0
				g.지연 = _rng.randf_range(0.0, 0.06)
				_가닥들.append(g)
		1:  # 부채 — 바깥각 중심으로 ±0.9rad 안에 몰린 다발
			var n := _rng.randi_range(6, 10)
			for i in n:
				var g := 가닥.new()
				g.각 = 바깥각 + _rng.randf_range(-0.95, 0.95)
				g.길이 = _rng.randf_range(34.0, 78.0) * _크기배율
				g.굵기 = _rng.randf_range(2.0, 4.2) * _크기배율
				g.휨 = _rng.randf_range(-0.3, 0.3)
				g.방울 = _rng.randf_range(0.0, 3.6) * _크기배율 if _rng.randf() > 0.4 else 0.0
				g.지연 = _rng.randf_range(0.0, 0.08)
				_가닥들.append(g)
		2:  # 왕관 — 바깥각 위주로 위로 솟되 좌우로 갈라진다 + 방울 많음
			var n := _rng.randi_range(5, 8)
			for i in n:
				var g := 가닥.new()
				var t := float(i) / float(maxi(n - 1, 1)) - 0.5     # -0.5..0.5
				g.각 = 바깥각 + t * 1.7 + _rng.randf_range(-0.12, 0.12)
				g.길이 = _rng.randf_range(40.0, 70.0) * _크기배율 * (1.0 - absf(t) * 0.4)
				g.굵기 = _rng.randf_range(2.6, 4.8) * _크기배율
				g.휨 = t * 0.5 + _rng.randf_range(-0.15, 0.15)     # 바깥으로 벌어지게
				g.방울 = _rng.randf_range(2.0, 4.4) * _크기배율     # 왕관은 방울이 특징
				g.지연 = _rng.randf_range(0.0, 0.05)
				_가닥들.append(g)
		_:  # 잔뿌림 — 가늘고 많은 잔줄기
			var n := _rng.randi_range(10, 16)
			for i in n:
				var g := 가닥.new()
				g.각 = 바깥각 + _rng.randf_range(-1.4, 1.4)
				g.길이 = _rng.randf_range(14.0, 44.0) * _크기배율
				g.굵기 = _rng.randf_range(1.2, 2.6) * _크기배율
				g.휨 = _rng.randf_range(-0.35, 0.35)
				g.방울 = _rng.randf_range(0.0, 2.2) * _크기배율 if _rng.randf() > 0.55 else 0.0
				g.지연 = _rng.randf_range(0.0, 0.12)
				_가닥들.append(g)


func _process(delta: float) -> void:
	_시간 += delta
	if _시간 >= _최대수명:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_시간 / _최대수명, 0.0, 1.0)
	# 알파: 초반 짧게 유지하다 후반에 사라진다. 번쩍임 없이 스며들 듯.
	var 알파 := 1.0 - smoothstep(0.55, 1.0, t)

	# ── 중심 얼룩 — 빠르게 커졌다가 그대로 남는다(닿은 자리 표시) ──
	var 중심t := smoothstep(0.0, 0.28, t)
	var 중심r := _중심반경 * lerpf(0.35, 1.0, 중심t)
	_얼룩(Vector2.ZERO, 중심r, 알파)

	# ── 가닥 — 각자 자기 지연 뒤부터 자란다 ──
	for item in _가닥들:
		var g: 가닥 = item
		var 진행 := smoothstep(g.지연, g.지연 + 0.30, t)
		if 진행 <= 0.001:
			continue
		var 길이 := g.길이 * 진행
		# 물줄기: 시작(중심 언저리)에서 각도 방향으로, 휨을 주며 뻗는다.
		var 시작 := Vector2.RIGHT.rotated(g.각) * (_중심반경 * 0.6)
		var 방향 := g.각 + g.휨 * 진행
		var 끝 := 시작 + Vector2.RIGHT.rotated(방향) * 길이
		# 테이퍼: 뿌리는 굵고 끝은 가늘게 — 폴리곤 4점으로 그린다.
		_테이퍼선(시작, 끝, g.굵기 * lerpf(1.0, 0.7, 진행), maxf(g.굵기 * 0.28, 0.8), 알파)
		# 끝 물방울 — 줄기가 거의 다 자란 뒤에만 맺힌다.
		if g.방울 > 0.4 and 진행 > 0.7:
			var 방울알파 := 알파 * smoothstep(0.7, 0.85, 진행)
			_얼룩(끝, g.방울, 방울알파)


## 물감 방울 하나 — 테두리 한 겹 + 채움. 완전한 원이 아니라 살짝 일그러뜨린다.
func _얼룩(중심: Vector2, 반경: float, 알파: float) -> void:
	if 반경 <= 0.3 or 알파 <= 0.01:
		return
	var 점들 := PackedVector2Array()
	var n := 10
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 반경 * (0.86 + 0.14 * sin(a * 3.0 + 반경))
		점들.append(중심 + Vector2.RIGHT.rotated(a) * r)
	var 채움 := _색
	채움.a = 알파
	draw_colored_polygon(점들, 채움)


## 뿌리(굵음)→끝(가늚) 테이퍼 물줄기. 반대색 테두리를 얇게 깐 뒤 채운다.
func _테이퍼선(a: Vector2, b: Vector2, w0: float, w1: float, 알파: float) -> void:
	if 알파 <= 0.01:
		return
	var 방향 := (b - a)
	if 방향.length() < 0.5:
		return
	var 수직 := Vector2(-방향.y, 방향.x).normalized()
	var 점들 := PackedVector2Array([
		a + 수직 * w0, b + 수직 * w1, b - 수직 * w1, a - 수직 * w0])
	# 테두리(살짝 넓게) → 안이 밝은 배경에서도 물줄기가 안 묻힌다.
	var 테 := _테두리
	테.a *= 알파
	var 점들t := PackedVector2Array([
		a + 수직 * (w0 + 1.0), b + 수직 * (w1 + 0.8),
		b - 수직 * (w1 + 0.8), a - 수직 * (w0 + 1.0)])
	draw_colored_polygon(점들t, 테)
	var 채움 := _색
	채움.a = 알파
	draw_colored_polygon(점들, 채움)
