@tool
extends Area2D
## ============================================================================
## [2026-08-01 신규] 식물 B — 덤불 / 임시 색 지대 생성기
## ----------------------------------------------------------------------------
## ▣ 기획 (오브젝트 문서)
##   · 색칠 횟수에 따라 촘촘해지는 덤불.
##   · 덤불 **안쪽에서** 페인트를 쏠 때, 커서가 덤불 안이면 덤불이 칠해지고
##     커서가 덤불 밖이면 총알이 덤불을 뚫고 나간다. (판정은 총.gd 가 물어본다)
##   · **같은 색 2회** → 그 색과 같은 임시 지대 생성.
##   · **두 색 1회씩** → 임시 회색 지대 생성.
##
## ▣ "지대"가 하는 일 (기획의 색 시스템)
##   검정/흰색 지대 = 그 안에 있는 동안 플레이어 색이 그 색으로 고정된다.
##   회색 지대     = 플레이어가 임의로 색을 전환할 수 있다.
##   판정은 월드.gd 가 매 프레임 `지대색()` 을 물어보는 방식으로 통합한다
##   (기존 scenes/경계/color_zone.gd 와 같은 문법 — 나중에 하나로 합칠 수 있다).
##
## ▣ 물리 레이어
##   16 = 색칠 가능한 통과형 오브젝트. 총알(mask 16|32)이 감지하고, 플레이어는 통과한다.
## ============================================================================
class_name 식물B

## 덤불 반경(px). 지대 범위도 이 값을 쓴다.
@export var 반경: float = 96.0:
	set(v):
		반경 = maxf(v, 24.0)
		_모양_갱신()
		queue_redraw()

## 지대가 유지되는 시간(초). 0 이면 회수하기 전까지 계속 남는다.
@export var 지대_지속: float = 0.0

var _칠한색: Array[int] = []          ## 최대 2개. [검정] / [흰색,흰색] / [검정,흰색] …
var _지대색: int = -1                 ## -1 = 지대 없음
var _남은시간: float = 0.0
var _가지: Array[Dictionary] = []     ## 그림용 가지 데이터 (칠할수록 늘어난다)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false                # 감지는 총알 쪽에서 한다 (여긴 감지 대상이기만 하면 됨)
	monitorable = true
	_모양_갱신()
	_가지_생성(10)
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("칠할수있음")
	add_to_group("식물B")
	set_process(true)
	queue_redraw()


func _모양_갱신() -> void:
	var c := get_node_or_null("모양") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "모양"
		add_child(c)
	var s := c.shape as CircleShape2D
	if s == null:
		s = CircleShape2D.new()
		c.shape = s
	s.radius = 반경


# ── 페인트코어와의 약속 ─────────────────────────────────────────────────────
func 현재색() -> int:
	return _지대색


func 명중(색: int, _월드좌표: Vector2) -> String:
	if _칠한색.size() >= 2:
		return "wasted"                    # 이미 지대가 만들어졌다 → 페인트 회수
	_칠한색.append(색)
	_가지_생성(10 + _칠한색.size() * 9)     # 칠할수록 촘촘해진다
	_지대_갱신()
	queue_redraw()
	return "painted"


## FIFO 회수 — 한 번에 한 칠씩 되돌린다.
func 되돌리기() -> bool:
	if _칠한색.is_empty():
		return false
	_칠한색.pop_back()
	_가지_생성(10 + _칠한색.size() * 9)
	_지대_갱신()
	queue_redraw()
	return true


## 덤불은 밟는 물건이 아니다 — 사망 판정에 관여하지 않는다.
func 반대색인가(_플레이어색: int) -> bool:
	return false


# ── 지대 ───────────────────────────────────────────────────────────────────
## 칠한 색 2개로 지대 색을 정한다.
##   같은 색 2회        → 그 색 지대
##   검정 + 흰색 (순서 무관) → 회색 지대
func _지대_갱신() -> void:
	if _칠한색.size() < 2:
		_지대색 = -1
		_남은시간 = 0.0
		return
	_지대색 = _칠한색[0] if _칠한색[0] == _칠한색[1] else ColorDefs.GRAY
	_남은시간 = 지대_지속


## 월드.gd 가 매 프레임 물어본다. -1 이면 지대 없음.
func 지대색() -> int:
	return _지대색


## 이 점이 덤불 안인가 (총.gd 의 "커서가 안/밖" 판정에 쓴다)
func 안에_있나(월드좌표: Vector2) -> bool:
	return global_position.distance_to(월드좌표) <= 반경


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _지대색 >= 0 and 지대_지속 > 0.0:
		_남은시간 -= delta
		if _남은시간 <= 0.0:
			_칠한색.clear()
			_지대_갱신()
			_가지_생성(10)
			queue_redraw()


# ── 그림 ───────────────────────────────────────────────────────────────────
## 가지를 미리 뽑아두고(랜덤 시드 고정) 개수만 늘린다 → 칠해도 모양이 안 흔들린다.
func _가지_생성(개수: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) if not name.is_empty() else 12345
	_가지.clear()
	for i in 개수:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 반경 * 0.92
		_가지.append({
			"뿌리": Vector2(cos(a), sin(a)) * r * 0.35 + Vector2(0, 반경 * 0.35),
			"끝": Vector2(cos(a), sin(a)) * r,
			"굵기": rng.randf_range(2.0, 4.5),
		})


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 색 := Color(0.30, 0.34, 0.30, 0.95)
	match _지대색:
		ColorDefs.BLACK: 색 = Color(0.10, 0.10, 0.11)
		ColorDefs.WHITE: 색 = Color(0.93, 0.93, 0.90)
		ColorDefs.GRAY:  색 = Color(0.50, 0.50, 0.50)

	# 지대가 살아 있으면 범위를 은은한 원으로 표시 (플레이어가 규칙을 눈으로 알아야 한다)
	if _지대색 >= 0:
		draw_circle(Vector2.ZERO, 반경, Color(색.r, 색.g, 색.b, 0.13))
		draw_arc(Vector2.ZERO, 반경, 0.0, TAU, 48, Color(색.r, 색.g, 색.b, 0.5), 2.0)

	for 가지 in _가지:
		draw_line(가지["뿌리"], 가지["끝"], 색, 가지["굵기"])
		draw_circle(가지["끝"], 가지["굵기"] * 1.3, 색)
