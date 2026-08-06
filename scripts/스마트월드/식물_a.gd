@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 식물 A — 화분 + 성장하는 잎 발판
## ----------------------------------------------------------------------------
## ▣ 기획 (오브젝트 문서)
##   · 화분에 작은 봉우리가 자라 있고, 최대 성장 시 꽃이 핀다.
##   · 화분을 색칠하면 한 단계 자라고, **칠한 색과 같은 잎**이 생긴다.
##   · 잎은 왼쪽 → 오른쪽 순서로 생긴다.
##   · 잎은 이미 색칠된 상태라 다시 칠할 수 없고, **밟을 수 있는 발판**이다.
##   · 회수하면 한 단계씩 줄어든다.
##   · 식물마다 최대 색칠 횟수가 다르다.
##
## ▣ 페인트코어와의 계약
##   한 단계 성장 = 한 번의 "완성"으로 취급한다(명중 → "painted").
##   그래야 회수줄(FIFO)에 단계마다 한 칸씩 쌓이고, E 회수 한 번에 한 단계만 줄어든다
##   = 기획의 "회수 시 한 단계씩 줄어듦" 과 정확히 일치한다.
##
## ▣ 그림
##   전용 아트가 아직 없으므로 _draw() 로 그린다. 흑백 게임이라 실루엣만 맞으면
##   충분히 읽히고, 나중에 Sprite2D 로 교체해도 로직은 그대로다.
## ============================================================================
class_name 식물A

## 이 식물이 받을 수 있는 최대 색칠 횟수 = 잎 개수.
@export_range(1, 6) var 최대_단계: int = 3:
	set(v):
		최대_단계 = clampi(v, 1, 6)
		if is_inside_tree():
			queue_redraw()

## 잎 하나의 크기(px). 발판 판정 크기와 그림이 이 값을 함께 쓴다.
@export var 잎_크기: Vector2 = Vector2(78, 18)

## 화분 크기(px).
@export var 화분_크기: Vector2 = Vector2(56, 44)

var _단계: int = 0
var _잎색: Array[int] = []                 ## 각 단계에서 칠해진 색
var _잎노드: Array[StaticBody2D] = []


func _ready() -> void:
	_화분_충돌_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("칠할수있음")
	add_to_group("식물A")
	queue_redraw()


## 화분 자체도 밟을 수 있다 — 총알도 여기 맞는다(레이어 1).
func _화분_충돌_만들기() -> void:
	if get_node_or_null("화분충돌") != null:
		return
	var c := CollisionShape2D.new()
	c.name = "화분충돌"
	var r := RectangleShape2D.new()
	r.size = 화분_크기
	c.shape = r
	c.position = Vector2(0, -화분_크기.y * 0.5)
	add_child(c)
	collision_layer = 1
	collision_mask = 0


# ── 페인트코어와의 약속 ─────────────────────────────────────────────────────
func 현재색() -> int:
	return _잎색[-1] if not _잎색.is_empty() else -1


## 잎은 이미 칠해진 상태 = 플레이어와 색이 다르면 밟을 때 죽는다.
## (화분 자체는 무색이라 항상 안전 — 잎만 위험하다)
func 반대색인가(_플레이어색: int) -> bool:
	return false


func 명중(색: int, _월드좌표: Vector2) -> String:
	if _단계 >= 최대_단계:
		return "wasted"                    # 다 자랐다 → 페인트 회수
	_단계 += 1
	_잎색.append(색)
	_잎_만들기(_단계 - 1, 색)
	queue_redraw()
	return "painted"


## 한 단계씩 줄어든다 (기획). 0단계면 더 줄일 게 없어 false.
func 되돌리기() -> bool:
	if _단계 <= 0:
		return false
	_단계 -= 1
	_잎색.pop_back()
	var n: StaticBody2D = _잎노드.pop_back()
	if is_instance_valid(n):
		n.queue_free()
	queue_redraw()
	return true


# ── 잎 발판 ────────────────────────────────────────────────────────────────
## 잎은 왼쪽 → 오른쪽 순서로 번갈아 난다. 단계가 올라갈수록 위로 쌓인다.
func _잎_위치(단계: int) -> Vector2:
	var 왼쪽 := (단계 % 2 == 0)                       # 0번째 = 왼쪽
	var 높이 := -화분_크기.y - 34.0 - float(단계) * 46.0
	var x := (-1.0 if 왼쪽 else 1.0) * (잎_크기.x * 0.5 - 6.0)
	return Vector2(x, 높이)


func _잎_만들기(단계: int, 색: int) -> void:
	var 잎 := StaticBody2D.new()
	잎.name = "잎%d" % 단계
	잎.position = _잎_위치(단계)
	잎.collision_layer = 1
	잎.collision_mask = 0
	잎.set_meta("잎색", 색)
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = 잎_크기
	c.shape = r
	잎.add_child(c)
	# 잎도 "밟으면 죽는지"를 스스로 답할 수 있어야 한다 (월드.gd 의 발밑 판정이 물어본다)
	잎.set_script(preload("res://scripts/스마트월드/식물_잎.gd"))
	잎.set("잎색", 색)
	add_child(잎)
	_잎노드.append(잎)
	잎.queue_redraw()


# ── 그림 ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	var 흑 := Color(0.10, 0.10, 0.11)
	var 백 := Color(0.93, 0.93, 0.90)

	# 화분 — 아래가 좁은 사다리꼴
	var w := 화분_크기.x * 0.5
	var h := 화분_크기.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(w * 0.72, 0), Vector2(-w * 0.72, 0)
	]), 흑)
	# 화분 테두리(입구) — 밝게 쳐서 실루엣이 배경에 묻히지 않게
	draw_rect(Rect2(Vector2(-w - 3, -h - 7), Vector2(w * 2 + 6, 8)), Color(0.62, 0.62, 0.60))

	# 줄기
	var 꼭대기 := -h - 20.0 - float(_단계) * 46.0
	draw_line(Vector2(0, -h), Vector2(0, 꼭대기), Color(0.55, 0.58, 0.52), 5.0)

	# 봉우리 / 꽃
	if _단계 >= 최대_단계:
		# 최대 성장 = 꽃
		for i in 6:
			var a := TAU * float(i) / 6.0
			draw_circle(Vector2(cos(a), sin(a)) * 11.0 + Vector2(0, 꼭대기), 8.0, 백)
		draw_circle(Vector2(0, 꼭대기), 7.0, Color(0.45, 0.45, 0.42))
	else:
		draw_circle(Vector2(0, 꼭대기), 9.0, Color(0.40, 0.44, 0.38))

	# 아직 안 자란 잎 자리를 점선으로 예고 — "여기에 발판이 생긴다"는 정보
	for 단계 in range(_단계, 최대_단계):
		var p := _잎_위치(단계)
		var 반 := 잎_크기 * 0.5
		var 칸 := 8
		for k in 칸:
			if k % 2 == 1:
				continue
			var t0 := -반.x + 잎_크기.x * float(k) / float(칸)
			var t1 := -반.x + 잎_크기.x * float(k + 1) / float(칸)
			draw_line(p + Vector2(t0, 0), p + Vector2(t1, 0), Color(0.75, 0.75, 0.72, 0.5), 2.0)
