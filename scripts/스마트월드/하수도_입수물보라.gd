extends Node2D
## ============================================================================
## [2026-09-30 Claude] 웅덩이 입수 물보라 — 그림만(판정 없음), 월드 좌표.
## ----------------------------------------------------------------------------
## ▣ 왜
##   입수했을 때 보이는 것이 화면 아래 렌즈 물방울(6단계 · 화면 공간)과 수면 잔물결뿐이라
##   "물에 풍덩 들어갔다" 가 발 자리에서 보이지 않았다(도형님: 입수 물방울과 잔물결).
##   발 자리에서 물 자기 색의 물방울이 포물선으로 튀고, 수면에 짧은 왕관(물막)이 선다.
##
## ▣ 쓰는 곳
##   `웅덩이_하수도29.gd` 가 입수 순간 `터뜨리기(발 전역 좌표, 수면 y, 색, 세기)` 를 부른다.
##   떨어진 속도가 빠를수록(세기) 물방울이 많고 높다. 걸어서 들어가면 작게.
## ============================================================================

const 수명 := 0.55
const 중력 := 900.0

var _방울: Array = []
var _왕관: Array = []

func _ready() -> void:
	# 캐릭터(z 0)와 앞 수면(z 2)보다 위 — 물보라는 캐릭터 앞에서도 보여야 한다.
	z_index = 3
	top_level = true

func 터뜨리기(발: Vector2, 수면_y: float, 색: int, 세기: float) -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var 개수 := int(round(lerpf(5.0, 14.0, 세기)))
	for i in 개수:
		var 쪽 := -1.0 if i % 2 == 0 else 1.0
		var 각 := r.randf_range(0.35, 1.25)
		var 속 := r.randf_range(110.0, 260.0) * lerpf(0.55, 1.0, 세기)
		_방울.append({
			"p": Vector2(발.x + 쪽 * r.randf_range(4.0, 14.0), 수면_y - 1.0),
			"v": Vector2(쪽 * sin(각) * 속, -cos(각) * 속),
			"r": r.randf_range(1.2, 2.6), "age": 0.0, "life": r.randf_range(0.35, 수명), "tone": 색, "surf": 수면_y})
	_왕관.append({"x": 발.x, "y": 수면_y, "age": 0.0, "w": lerpf(14.0, 26.0, 세기), "h": lerpf(6.0, 16.0, 세기), "tone": 색})
	set_process(true)

func _process(delta: float) -> void:
	for d in _방울:
		d["age"] = float(d["age"]) + delta
		d["v"] = (d["v"] as Vector2) + Vector2(0, 중력 * delta)
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
	for c in _왕관:
		c["age"] = float(c["age"]) + delta
	# 수면 아래로 다시 떨어진 물방울은 물에 들어간 것 — 물 위에 그려 두면 물속에 점이 떠 보였다.
	_방울 = _방울.filter(func(d): return float(d["age"]) < float(d["life"]) and not ((d["v"] as Vector2).y > 0.0 and (d["p"] as Vector2).y > float(d["surf"])))
	_왕관 = _왕관.filter(func(c): return float(c["age"]) < 0.28)
	if _방울.is_empty() and _왕관.is_empty():
		set_process(false)
	queue_redraw()

func _색(tone: int, a: float) -> Color:
	# 물 자기 색: 흰 물의 튀는 물은 흰색이다(인수인계 기준 — 거품을 어둡게 하는 규칙은 수면 접촉 음영에만).
	var v := 0.95 if tone == 1 else (0.12 if tone == 0 else 0.68)
	return Color(v, v, v, a)

func _draw() -> void:
	for c in _왕관:
		var t := float(c["age"]) / 0.28
		var w := float(c["w"]) * (0.7 + 0.6 * t)
		var h := float(c["h"]) * sin(t * PI)
		var col := _색(int(c["tone"]), 0.75 * (1.0 - t))
		for s in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for k in 7:
				var u := float(k) / 6.0
				pts.append(Vector2(float(c["x"]) + s * (w * 0.35 + u * w * 0.5), float(c["y"]) - h * u * (1.4 - u)))
			draw_polyline(pts, col, 2.0, true)
	for d in _방울:
		var t := float(d["age"]) / float(d["life"])
		var p: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var col := _색(int(d["tone"]), 0.9 * (1.0 - t * t))
		# 속도 방향으로 늘어난 물방울(꼬리) — 동그란 점은 자갈처럼 보였다.
		draw_line(p - v.normalized() * float(d["r"]) * 3.0, p, col, float(d["r"]), true)
		draw_circle(p, float(d["r"]) * 0.8, col)
