@tool
extends Area2D
## ============================================================================
## [2026-08-06 신규] 무너지는 바위 — 밟으면 흔들리다 부서지는 발판
## ----------------------------------------------------------------------------
## ▣ 왜 낙하 사망과 짝인가
##   낙하 사망 규칙(`낙하_감시.gd`)만 있으면 "떨어지지 않게 조심" 이 전부라 정적이다.
##   무너지는 발판은 **플레이어가 멈출 수 없게** 만든다.
##   → 깊은 갱도 위에 이걸 깔면 "머뭇거리면 죽는다" 는 압박이 생긴다.
##   레인월드의 부서지는 파이프·비계와 같은 역할.
##
## ▣ 색 규칙
##   `칠하기_허용` 이 켜져 있으면 페인트로 칠할 수 있고, **칠하면 단단해져
##   무너지지 않는다.** 물감을 "보강재"로 쓰는 셈이라 색칠에 새 용도가 하나 생긴다.
##   (레벨디자인_가이드 §2 의 물감 이코노미 — 물감을 쓸 이유가 하나 더 늘어난다)
##
## ▣ 페인트 코어와의 약속 (덕 타이핑)
##   명중() / 되돌리기() / 현재색() / 반대색인가() 를 지형과 똑같이 구현한다.
##   그래서 페인트_코어.gd 는 이게 지형인지 바위인지 알 필요가 없다.
## ============================================================================
class_name 무너지는바위

signal 부서짐

@export_range(48, 500) var 폭: float = 170.0:
	set(v): 폭 = v; _재구성()
@export_range(16, 120) var 두께: float = 40.0:
	set(v): 두께 = v; _재구성()

## 밟은 뒤 무너지기까지 버티는 시간(초). 짧을수록 "쉬지 말고 달려라".
@export_range(0.15, 3.0) var 버티는시간: float = 0.75
## 무너진 뒤 다시 생기기까지(초). 0 이면 영영 안 돌아온다.
@export_range(0.0, 20.0) var 재생시간: float = 4.0

@export_group("색칠")
## 칠할 수 있는가. 칠하면 단단해져 무너지지 않는다.
@export var 칠하기_허용: bool = true
## 전체를 칠하는 데 필요한 명중 횟수.
@export_range(1, 6) var 필요횟수: int = 1

enum 상태_ { 멀쩡, 흔들림, 사라짐 }

var _상태: 상태_ = 상태_.멀쩡
var _남은: float = 0.0
var _색: int = -1                 ## −1 = 무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _떨림: float = 0.0
var _바디: StaticBody2D = null


func _ready() -> void:
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("무너지는바위")
	add_to_group("칠할수있음")           # 페인트 코어가 대상으로 인식하게
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	set_physics_process(true)
	set_process(true)


func _재구성() -> void:
	if not is_inside_tree():
		return
	# 밟힘 감지용 판정 — 윗면 바로 위 얇은 띠
	var cs := get_node_or_null("판정") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "판정"
		cs.visible = false
		add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	r.size = Vector2(폭 * 0.94, 두께 * 1.4)
	cs.position = Vector2(0, -두께 * 0.5)

	# 실제로 밟히는 바닥
	_바디 = get_node_or_null("발판") as StaticBody2D
	if _바디 == null:
		_바디 = StaticBody2D.new()
		_바디.name = "발판"
		add_child(_바디)
		if Engine.is_editor_hint() and owner:
			_바디.owner = owner
	_바디.collision_layer = 1
	_바디.collision_mask = 0
	var bcs := _바디.get_node_or_null("모양") as CollisionShape2D
	if bcs == null:
		bcs = CollisionShape2D.new()
		bcs.name = "모양"
		bcs.visible = false
		_바디.add_child(bcs)
		if Engine.is_editor_hint() and owner:
			bcs.owner = owner
	var br := bcs.shape as RectangleShape2D
	if br == null:
		br = RectangleShape2D.new()
		bcs.shape = br
	br.size = Vector2(폭, 두께)
	bcs.position = Vector2(0, 0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	match _상태:
		상태_.멀쩡:
			# 칠해진 바위는 무너지지 않는다 (물감 = 보강재)
			if _색 >= 0:
				return
			for 몸 in get_overlapping_bodies():
				if 몸 is CharacterBody2D:
					_상태 = 상태_.흔들림
					_남은 = 버티는시간
					break
		상태_.흔들림:
			_남은 -= delta
			_떨림 = 1.0 - clampf(_남은 / maxf(버티는시간, 0.01), 0.0, 1.0)
			if _남은 <= 0.0:
				_무너지기()
		상태_.사라짐:
			if 재생시간 <= 0.0:
				return
			_남은 -= delta
			if _남은 <= 0.0:
				_되살리기()
	queue_redraw()


func _무너지기() -> void:
	_상태 = 상태_.사라짐
	_남은 = 재생시간
	_떨림 = 0.0
	if _바디:
		_바디.set_deferred("collision_layer", 0)   # 밟을 수 없게
	부서짐.emit()


func _되살리기() -> void:
	_상태 = 상태_.멀쩡
	if _바디:
		_바디.set_deferred("collision_layer", 1)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


# ── 페인트 코어와의 약속 ────────────────────────────────────────────────────
func 현재색() -> int:
	return _색


## 칠해진 색과 반대색인 플레이어가 밟으면 죽는다 (지형과 같은 규칙).
func 반대색인가(플레이어색: int) -> bool:
	# ★[2026-08-30] 안 칠한 바위도 검정이다 — 흰색 플레이어가 밟으면 죽는다.
	return 색규칙.위험한가(_색, 플레이어색)


func 명중(색: int, _월드좌표: Vector2) -> String:
	if not 칠하기_허용 or _상태 == 상태_.사라짐:
		return "blocked"
	if _색 == ColorDefs.GRAY:
		return "blocked"
	if _색 >= 0:
		if 색 == _색:
			return "wasted"
		# 플레이어 페인트는 섞이지 않고 마지막에 맞은 색이 기존 색을 덮는다.
		_색 = 색
		queue_redraw()
		return "painted"

	if _맞은횟수 > 0 and _진행색 != 색:
		_맞은횟수 = 0
	_진행색 = 색
	_맞은횟수 += 1
	if _맞은횟수 >= 필요횟수:
		_색 = 색
		# 칠하는 순간 흔들림이 멎는다 — "보강했다"가 즉시 읽힌다
		if _상태 == 상태_.흔들림:
			_상태 = 상태_.멀쩡
			_떨림 = 0.0
		queue_redraw()
		return "painted"
	queue_redraw()
	return "progress"


func 되돌리기() -> bool:
	if not 칠하기_허용 or _색 == ColorDefs.GRAY:
		return false
	_색 = -1
	_맞은횟수 = 0
	queue_redraw()
	return true


# ── 그림 ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	if _상태 == 상태_.사라짐:
		# 부서진 자리 — 잔해 점선만 남겨 "여기 있었다"를 알린다.
		# 완전히 지우면 플레이어가 길을 잃는다.
		for i in 7:
			var x := lerpf(-폭 * 0.5, 폭 * 0.5, float(i) / 6.0)
			draw_circle(Vector2(x, 0), 2.5, Color(0.55, 0.55, 0.58, 0.30))
		return

	# 흔들릴수록 좌우로 떨린다 (프레임마다 다른 값 = 지진 느낌)
	var 흔들 := Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * _떨림 * 5.0

	var w := 폭 * 0.5
	var t := 두께 * 0.5
	# 위·아래가 살짝 들쭉날쭉한 바위 조각
	var 점들 := PackedVector2Array([
		Vector2(-w, -t * 0.7), Vector2(-w * 0.6, -t), Vector2(0, -t * 0.85),
		Vector2(w * 0.62, -t), Vector2(w, -t * 0.6),
		Vector2(w * 0.9, t * 0.8), Vector2(w * 0.3, t), Vector2(-w * 0.35, t * 0.9),
		Vector2(-w * 0.88, t * 0.7),
	])
	var 이동 := PackedVector2Array()
	for p in 점들:
		이동.append(p + 흔들)

	var 본색 := Color(0.09, 0.09, 0.10)
	match _색:
		ColorDefs.WHITE: 본색 = Color(0.90, 0.90, 0.92)
		ColorDefs.GRAY: 본색 = Color(0.50, 0.50, 0.52)
	draw_colored_polygon(이동, 본색)
	draw_polyline(이동, Color(0.66, 0.66, 0.70, 0.85), 2.0, true)

	# 흔들리는 동안 균열이 벌어진다 = 남은 시간의 시각적 게이지
	if _떨림 > 0.02:
		for i in 3:
			var x := lerpf(-w * 0.6, w * 0.6, float(i) / 2.0) + 흔들.x
			draw_line(Vector2(x, -t * 0.8 + 흔들.y), Vector2(x + 4.0, t * 0.8 + 흔들.y),
				Color(0.85, 0.85, 0.88, _떨림 * 0.8), 1.0 + _떨림 * 2.0)
