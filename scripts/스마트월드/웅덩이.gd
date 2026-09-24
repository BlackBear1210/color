@tool
extends Area2D
## ============================================================================
## [2026-09-07 신규] 웅덩이 — 바닥에 잔잔하게 깔린 물
## ----------------------------------------------------------------------------
## ▣ 기획 (도형님 지시 2026-09-07)
##   ① "물 웅덩이 같은거 만들자. 높은곳에서 떨어지면 낙사로 죽는데,
##      만약 아래 물이 잔잔하게 깔려 있으면 살게 하자."
##   ② "차오르는 물 만들자. 대신 모든 유체가 차오르게 하는 것이 아니라,
##      인스펙터로 값을 설정할 수 있게 해서 만들자."
##   → 이 두 가지가 사실 같은 물건이다. **바닥에 고인 물**이 낙하를 받아주고,
##     그 물의 수면이 올라오면 그게 곧 "차오르는 물"이다.
##
## ▣ 왜 `유체.gd` 에 옵션을 더하지 않고 새로 팠나
##   `유체` 는 **떨어지는 물줄기**다. 원점이 물의 **윗끝**이고 아래로 뻗으며,
##   그림도 세로로 흐르는 폭포 실루엣 8 프레임이다(`유체_판정모양.gd`).
##   웅덩이는 정반대다 — 원점이 **아랫변**이고 위로 자라며, 수면이 가로로 눕는다.
##   같은 스크립트에 두 원점 규칙을 넣으면 맵 찍는 사람이 매번 헷갈린다.
##   (그래도 하수도 스테이지의 기존 물은 전부 `유체` 라서, `유체.gd` 에도
##    같은 차오름 손잡이를 따로 달아 두었다. 규칙과 이름은 두 파일에서 같다.)
##
## ▣ 색 규칙 — 웅덩이도 예외가 아니다
##   `색규칙.gd` 한 곳에서만 판단한다. 검은 웅덩이는 흰색 플레이어를 죽인다.
##   즉 "낙하를 받아주는 물"과 "닿으면 죽는 물"은 **같은 물**이고,
##   살아남으려면 **떨어지기 전에 색을 맞춰야** 한다.
##   ★이게 이 부품의 핵심이다. 낙사 안전망을 그냥 주는 게 아니라
##     색 판단을 한 번 더 시키는 안전망으로 준다.
##   누구에게나 안전한 물이 필요하면 색을 **회색**으로 두면 된다.
##
## ▣ 물리 레이어 (`유체.gd` 와 같은 표)
##   layer 32 = 유체. 총알(mask 16|32)이 감지해서 반대색이면 막힌다.
##   mask 1|8 = 플레이어(낙하 받기) + 지형(페인트 지우기)
##   ⚠ 충돌은 없다(Area2D). 물에 빠지면 그대로 통과해 바닥까지 내려간다.
## ============================================================================
class_name 웅덩이

## `유체.gd` 와 같은 표기 — ColorDefs 의 고정값을 인스펙터에서 이름으로 고른다.
enum 물색_ { 흰색 = 1, 회색 = 2, 검정색 = 0 }

## 웅덩이 크기(px). **원점은 아랫변 한가운데**다 — 바닥선에 그대로 얹으면 된다.
## 높이가 곧 수심이고, 차오름은 이 높이를 키우는 것이다.
@export var 크기: Vector2 = Vector2(420, 96):
	set(v):
		크기 = Vector2(maxf(v.x, 16.0), maxf(v.y, 8.0))
		if is_node_ready():
			_모양_갱신()
		queue_redraw()

@export var 색: 물색_ = 물색_.회색:
	set(v):
		색 = v
		queue_redraw()

## 제어레버가 껐다 켰다 한다. 꺼진 웅덩이는 없는 것과 같다(안 죽이고 안 받아준다).
@export var 켜짐: bool = true:
	set(v):
		켜짐 = v
		if is_node_ready():
			_켜짐_반영()

@export_group("낙하 받기")
## 이 물 위로 떨어지면 낙사하지 않는다.
## ⚠ 색이 다르면 낙사 대신 **색으로 죽는다** — 안전망은 색을 맞춘 사람 것이다.
@export var 낙하_받아줌: bool = true

## 이보다 얕으면 못 받아준다(px). 발목까지 오는 물이 100m 낙하를 살려주면 거짓말이다.
## 차오르는 중에는 이 값을 넘긴 순간부터 안전해진다 = 수면 높이가 곧 난이도다.
@export_range(0.0, 400.0, 1.0) var 받아주는_최소수심: float = 40.0

@export_group("차오름")
## 켜야 물이 올라온다. **기본은 꺼짐** — 지금까지 놓아둔 웅덩이는 아무것도 안 바뀐다.
@export var 차오름_켜기: bool = false

## 수면이 올라오는 속도(px/s). 60 이면 플레이어 키(약 96px)만큼 오르는 데 1.6 초.
@export_range(1.0, 600.0, 1.0) var 차오름_속도: float = 60.0

## 다 차올랐을 때의 높이(px). `크기.y` 보다 커야 의미가 있다.
@export_range(8.0, 4000.0, 1.0) var 차오름_최종높이: float = 600.0

## 시작 신호를 받고 실제로 오르기 시작할 때까지의 뜸(초). 방에 들어선 뒤 한 박자 준다.
@export_range(0.0, 20.0, 0.1) var 차오름_시작지연: float = 0.0

## 켜면 스테이지가 시작되자마자 오른다.
## 끄면 레버·버튼이 `차오르기_시작()` 을 부를 때까지 기다린다.
@export var 차오름_자동시작: bool = true

@export_group("모양")
## 수면 물결의 높이(px)와 한 주기(초). 0 이면 완전히 잔잔하다.
@export_range(0.0, 24.0, 0.5) var 물결_높이: float = 4.0
@export_range(0.2, 12.0, 0.1) var 물결_주기: float = 3.2

@export_group("")
## 켜면 물이 닿은 지형의 **반대색 페인트를 지운다**(`유체` 의 물과 같은 규칙).
## 기본은 꺼짐 — 웅덩이는 바닥에 얹혀 있어서, 켜면 발밑 페인트를 계속 지운다.
@export var 페인트_지움: bool = false

## 켜면 반대색 총알을 막는다(`유체` 와 같은 규칙). 회색 웅덩이는 아무것도 안 막는다.
@export var 총알_막음: bool = true


## 판정을 매 프레임 다시 만들지 않기 위한 계단 폭(px).
## 60px/s 로 차오르면 초당 30 번만 갱신된다 — 눈으로는 매끈하고 물리는 싸다.
const 차오름_판정간격: float = 2.0

# ── 상태 ────────────────────────────────────────────────────────────────────
var _시간: float = 0.0
var _코어: 페인트코어 = null
var _지운적: Dictionary = {}

var _차오르는중: bool = false
var _대기: float = 0.0
var _실제높이: float = 0.0          ## 계단으로 자르기 **전**의 연속 높이
var _시작높이: float = 0.0          ## 씬에 적어둔 처음 높이 — 리스폰 때 여기로 되돌린다


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 8
	monitorable = true
	_모양_갱신()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("웅덩이")
	if 낙하_받아줌:
		add_to_group("낙하받이")      # 월드.gd 가 낙사 직전에 이 그룹만 훑는다
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
	_시작높이 = 크기.y
	_실제높이 = 크기.y
	if 차오름_켜기:
		add_to_group("차오르는물")     # 월드.gd 가 리스폰 때 이 그룹을 초기화한다
		if 차오름_자동시작:
			차오르기_시작()
	_켜짐_반영()
	set_physics_process(true)
	set_process(true)
	queue_redraw()


func _모양_갱신() -> void:
	var c := get_node_or_null("모양") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "모양"
		add_child(c)
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = 크기
	# 원점이 아랫변이므로 사각형 중심은 위로 절반 올라간다.
	c.position = Vector2(0.0, -크기.y * 0.5)
	var 그림 := 아트슬롯.슬롯(self)
	if 그림 != null:
		그림.기준_크기 = 크기
		그림.position = Vector2(0.0, -크기.y * 0.5)
	queue_redraw()


func _켜짐_반영() -> void:
	# ★[2026-09-21] 유체.gd 와 같은 고침 — monitoring 만 끄면 monitorable 이 남아 **총알(다른 Area2D)에는 계속 잡힌다.**
	#   레버로 끈 웅덩이가 보이지도 않는데 총알을 삼켰다(2-5 밸브 물에서 발견 · 검사 `tools/test_유체_끄면_총알통과.gd`).
	#   레이어는 즉시 비우고(물리 콜백 안에서도 허용) monitoring/monitorable 은 지연 반영한다.
	collision_layer = 32 if 켜짐 else 0
	set_deferred("monitoring", 켜짐)
	set_deferred("monitorable", 켜짐)
	visible = 켜짐


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not 켜짐:
		return
	if 물결_높이 > 0.0:
		_시간 += delta
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not 켜짐:
		return
	_차오름_진행(delta)
	if 페인트_지움 and 색 != ColorDefs.GRAY:
		_페인트_지우기()


# ── 차오름 ──────────────────────────────────────────────────────────────────
## 레버·압력버튼·통로 트리거가 이걸 부르면 물이 오르기 시작한다.
func 차오르기_시작() -> void:
	if not 차오름_켜기:
		return
	# ⚠ `유체.gd::차오르기_시작()` 과 같은 이유 — 아직 안 차올랐으면 지금 높이로 기준을 다시 잡는다.
	#   인스턴스를 만든 **뒤에** 크기를 넣는 배치 도구·코드를 위한 것이다.
	if not _차오르는중 and is_equal_approx(_실제높이, _시작높이):
		_시작높이 = 크기.y
		_실제높이 = 크기.y
	_차오르는중 = true
	_대기 = 차오름_시작지연


## 지금 높이에서 멈춘다. 다시 `차오르기_시작()` 하면 그 자리에서 이어서 오른다.
func 차오르기_멈춤() -> void:
	_차오르는중 = false


## 처음 높이로 되돌린다. **리스폰 때 반드시 불러야 한다** —
## 안 부르면 물이 가득 찬 방으로 되살아나서 무한히 죽는다.
func 차오르기_초기화() -> void:
	_차오르는중 = false
	_대기 = 0.0
	_실제높이 = _시작높이
	크기 = Vector2(크기.x, _시작높이)
	if 차오름_켜기 and 차오름_자동시작:
		차오르기_시작()


func _차오름_진행(delta: float) -> void:
	if not _차오르는중:
		return
	if _대기 > 0.0:
		_대기 = maxf(_대기 - delta, 0.0)
		return
	var 목표 := maxf(차오름_최종높이, _시작높이)
	if _실제높이 >= 목표 - 0.01:
		_차오르는중 = false
		return
	_실제높이 = minf(_실제높이 + 차오름_속도 * delta, 목표)
	# 계단으로 잘라서 판정 갱신 횟수를 줄인다(위 `차오름_판정간격` 주석 참고).
	var 계단 := clampf(snappedf(_실제높이, 차오름_판정간격), _시작높이, 목표)
	if absf(계단 - 크기.y) < 0.01:
		return
	크기 = Vector2(크기.x, 계단)


## 지금 수면의 월드 y. 도구·테스트·카메라 연출이 쓴다(작을수록 높다).
func 수면_월드y() -> float:
	return global_position.y - 크기.y


func 수심() -> float:
	return 크기.y


# ── 규칙 ───────────────────────────────────────────────────────────────────
## 월드.gd 가 낙사 직전에 물어본다. "이 물이 지금 낙하를 받아줄 수 있나?"
## 색은 여기서 안 본다 — 색이 다르면 어차피 아래 `반대색인가()` 가 죽인다.
## 두 판정을 섞으면 "받아줬는데 색으로 죽었다" 가 "안 받아줘서 낙사했다" 로 잘못 읽힌다.
func 낙하를_받아주나() -> bool:
	return 켜짐 and 낙하_받아줌 and 크기.y >= 받아주는_최소수심


## 플레이어가 이 물에 닿으면 죽는가. 규칙은 `색규칙.gd` 한 곳에만 있다.
func 반대색인가(플레이어색: int) -> bool:
	if not 켜짐:
		return false
	return 색규칙.위험한가(색, 플레이어색)


## 반대색 투사체를 막는다(`유체.총알_막나` 와 같은 규칙).
func 총알_막나(총알색: int) -> bool:
	if not 켜짐 or not 총알_막음 or 색 == ColorDefs.GRAY:
		return false
	return 총알색 != 색


## 웅덩이는 색칠할 수 없다 → 총알이 맞아도 페인트는 회수된다.
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return 색


## `유체.gd::_physics_process` 의 2) 와 같은 일. 켰을 때만 돈다.
func _페인트_지우기() -> void:
	if not monitoring:            # 켠 프레임에는 아직 지연 반영 전(유체.gd 와 같음)
		return
	for 바디 in get_overlapping_bodies():
		var 대상 := _칠할대상_찾기(바디)
		if 대상 == null:
			continue
		if 대상.has_method("물에_안지워짐") and 대상.물에_안지워짐():
			continue
		if not 대상.has_method("현재색") or not 대상.has_method("되돌리기"):
			continue
		var 대상색: int = 대상.현재색()
		if 대상색 < 0 or 대상색 == ColorDefs.GRAY or 대상색 == 색:
			continue
		if _지운적.has(대상):
			continue
		if 대상.되돌리기():
			_지운적[대상] = true
			if _코어:
				_코어.부분_자동회수(대상, 1)


func _칠할대상_찾기(바디: Object) -> Node:
	var n := 바디 as Node
	while n != null:
		if n.has_method("되돌리기"):
			return n
		n = n.get_parent()
	return null


# ── 그림 ───────────────────────────────────────────────────────────────────
## 흑백 게임이라 몸통 하나만 칠하면 같은 색 지형 위에서 통째로 사라진다.
## → `장애물_공통.gd` 와 같은 원칙: **몸통 + 반대 밝기 테두리**로 항상 실루엣을 남긴다.
func _색깔() -> Array:
	match 색:
		ColorDefs.BLACK:
			return [Color(0.07, 0.075, 0.10, 0.86), Color(0.46, 0.49, 0.56, 0.95)]
		ColorDefs.WHITE:
			return [Color(0.88, 0.90, 0.88, 0.86), Color(0.30, 0.32, 0.36, 0.95)]
		_:
			return [Color(0.45, 0.46, 0.50, 0.82), Color(0.82, 0.84, 0.88, 0.95)]


func _draw() -> void:
	# 디자이너 그림이 꽂혀 있으면 코드 그리기는 쉰다(`아트슬롯.gd` 규약).
	if 아트슬롯.그림_있나(self):
		return

	var 색들 := _색깔()
	var 몸통: Color = 색들[0]
	var 테두리: Color = 색들[1]
	var 반폭 := 크기.x * 0.5
	var 윗변 := -크기.y

	# 몸통 — 수면 아래 전체
	draw_rect(Rect2(Vector2(-반폭, 윗변), 크기), 몸통)

	# 수면 물결 — "잔잔하다"를 눈으로 읽히게 하는 유일한 표시.
	#   진폭이 작고 주기가 길어야 잔잔해 보인다. 급하게 출렁이면 위험한 물로 읽힌다.
	var 분할 := clampi(int(크기.x / 14.0), 8, 96)
	var 선 := PackedVector2Array()
	var 위상 := _시간 / maxf(물결_주기, 0.05) * TAU
	for i in 분할 + 1:
		var t := float(i) / float(분할)
		var x := -반폭 + 크기.x * t
		var y := 윗변 + sin(위상 + t * TAU * 1.5) * 물결_높이
		선.append(Vector2(x, y))
	if 선.size() >= 2:
		draw_polyline(선, 테두리, 2.4, true)
		# 수면 바로 아래 밝은 띠 — 빛이 물에 닿는 자리
		var 띠 := PackedVector2Array(선)
		for i in range(선.size() - 1, -1, -1):
			띠.append(선[i] + Vector2(0, 7.0))
		draw_colored_polygon(띠, Color(테두리.r, 테두리.g, 테두리.b, 0.28))

	# 바닥·옆면 테두리 — 같은 색 지형 위에서도 경계가 보이게
	draw_line(Vector2(-반폭, 0), Vector2(반폭, 0), 테두리, 1.6)
	draw_line(Vector2(-반폭, 윗변), Vector2(-반폭, 0), 테두리, 1.6)
	draw_line(Vector2(반폭, 윗변), Vector2(반폭, 0), 테두리, 1.6)

	# 차오르는 물이면 "여기까지 올라온다"를 화살표로 알려 준다(에디터에서도 보인다).
	if 차오름_켜기:
		var 꼭대기 := -maxf(차오름_최종높이, 크기.y)
		var 안내 := Color(테두리.r, 테두리.g, 테두리.b, 0.30)
		draw_line(Vector2(0, 윗변), Vector2(0, 꼭대기), 안내, 1.4)
		draw_line(Vector2(0, 꼭대기), Vector2(-9, 꼭대기 + 14), 안내, 1.4)
		draw_line(Vector2(0, 꼭대기), Vector2(9, 꼭대기 + 14), 안내, 1.4)
		draw_line(Vector2(-반폭, 꼭대기), Vector2(반폭, 꼭대기), 안내, 1.0)
