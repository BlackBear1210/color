@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 물 저장고
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 긴 직사각형. 윗부분에 배관과 이어지는 곳이 있다.
##   · **플랫폼처럼 밟고 색칠할 수 있다.**
##   · **저장고 전체를 색칠하면 저장고에서 흐르는 물의 색이 바뀐다.**
##   · 저장고에 이어진 배관을 따라 물이 흐른다.
##
## ▣ 퍼즐에서의 역할
##   물은 반대색 페인트를 지운다. 그래서 "저장고를 무슨 색으로 칠하느냐"가
##   아래쪽 지형의 페인트를 지울지 말지를 결정한다 = 원격 스위치가 된다.
## ============================================================================
class_name 물저장고

@export var 크기: Vector2 = Vector2(230, 90):
	set(v):
		크기 = Vector2(maxf(v.x, 40.0), maxf(v.y, 24.0))
		_다시_만들기()

## 전체 색칠에 필요한 명중 횟수.
@export_range(1, 8) var 필요횟수: int = 3

## 이 저장고가 색을 공급하는 물줄기. 비워 두면 윗쪽 출구_포트에 닿은 유체를 자동으로 찾는다.
@export var 공급_유체: NodePath

## 2D 작업 화면에서 유체의 시작점을 저장고 상단 포트에 맞추면 NodePath 연결 없이 공급된다.
@export_group("출구 포트 자동 연결")
@export var 자동_공급_연결: bool = true
@export_range(8.0, 128.0, 1.0) var 포트_연결거리: float = 36.0
@export_group("")

var _상태색: int = -1                 ## -1 = 무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _유체: 유체 = null
var _수동_공급: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_다시_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("칠할수있음")
	add_to_group("물저장고")
	if not 공급_유체.is_empty():
		_유체 = get_node_or_null(공급_유체) as 유체
		_수동_공급 = _유체 != null
	if _유체 == null and 자동_공급_연결:
		_유체 = _포트에_닿은_유체_찾기()
	# ★[2026-08-01 버그 수정] 시작 상태를 물줄기에 반영하는 걸 빠뜨려서,
	#   저장고가 무색인데도 물이 흐르고 있었다(유체의 켜짐 기본값 true 가 그대로 남음).
	#   → 그 물이 호퍼로 들어가 아래 물줄기까지 켜져서 "칠해야 물이 흐른다" 규칙이 깨졌다.
	_공급_반영()
	# 자동 포트는 배치된 유체의 _ready 다음 프레임에 발견될 수도 있으므로 계속 찾는다.
	set_process(자동_공급_연결 and not _수동_공급)
	queue_redraw()


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null("충돌") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "충돌"
		add_child(c)
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = 크기
	var 출구포트 := get_node_or_null("출구_포트") as Marker2D
	if 출구포트 != null:
		# _draw의 상단 배관 연결구 시작점과 같은 좌표다.
		출구포트.position = Vector2(0, -크기.y * 0.5 - 16.0)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _수동_공급 or not 자동_공급_연결:
		return
	var 자동유체 := _포트에_닿은_유체_찾기()
	if 자동유체 == _유체:
		return
	if _유체 != null:
		_유체.켜짐 = false
	_유체 = 자동유체
	_공급_반영()


## 유체의 원점은 물이 시작되는 출구다. 저장고 상단 포트와 맞닿은 물만 공급 대상으로 한다.
func _포트에_닿은_유체_찾기() -> 유체:
	if not 자동_공급_연결 or not is_inside_tree():
		return null
	var 포트 := get_node_or_null("출구_포트") as Marker2D
	if 포트 == null:
		return null
	var 가장가까운: 유체 = null
	var 최소거리제곱 := 포트_연결거리 * 포트_연결거리
	for 노드 in get_tree().get_nodes_in_group("유체"):
		var 후보 := 노드 as 유체
		if 후보 == null or 후보.종류 != 유체.종류_.물:
			continue
		var 거리제곱 := 포트.global_position.distance_squared_to(후보.시작점_월드좌표())
		if 거리제곱 <= 최소거리제곱:
			가장가까운 = 후보
			최소거리제곱 = 거리제곱
	return 가장가까운


# ── 페인트코어와의 약속 ─────────────────────────────────────────────────────
func 현재색() -> int:
	return _상태색


## 저장고는 밟는 구조물 — 색이 있어도 죽이지 않는다(기획에 사망 규칙 없음).
func 반대색인가(플레이어색: int) -> bool:
	# ★[2026-08-30] 물저장고는 **칠할 수 있다**(`_상태색`). 그런데 여기서 늘 false 를 돌려
	#   화면은 칠해졌는데 밟아도 안 죽는 상태였다. 지형과 같은 규칙을 태운다.
	return 색규칙.위험한가(_상태색, 플레이어색)


func 명중(색: int, _월드좌표: Vector2) -> String:
	if _상태색 == ColorDefs.GRAY:
		return "blocked"
	if _상태색 >= 0:
		if 색 == _상태색:
			return "wasted"
		_상태색 = 색                    # 플레이어가 마지막에 쏜 색으로 그대로 덮는다.
		_공급_반영()
		queue_redraw()
		return "painted"

	if _맞은횟수 > 0 and _진행색 != 색:
		_맞은횟수 = 0
	_진행색 = 색
	_맞은횟수 += 1
	if _맞은횟수 >= 필요횟수:
		_상태색 = 색
		_공급_반영()
		queue_redraw()
		return "painted"
	queue_redraw()
	return "progress"


func 되돌리기() -> bool:
	if _상태색 == ColorDefs.GRAY:
		return false
	_상태색 = -1
	_맞은횟수 = 0
	_공급_반영()
	queue_redraw()
	return true


## 저장고 색 → 물줄기 색. 무색이면 물을 끈다(= 색 없는 물은 흐르지 않는다).
func _공급_반영() -> void:
	if _유체 == null:
		return
	if _상태색 < 0:
		_유체.켜짐 = false
		return
	_유체.켜짐 = true
	_유체.색 = _상태색


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 금속 := Color(0.23, 0.24, 0.27)
	var 반 := 크기 * 0.5
	draw_rect(Rect2(-반, 크기), 금속)

	# 내용물 — 칠한 진행도만큼 아래에서 차오른다
	var 진행 := 1.0 if _상태색 >= 0 else clampf(float(_맞은횟수) / float(maxi(필요횟수, 1)), 0.0, 1.0)
	var 내용 := Color(0.45, 0.47, 0.50)
	match (_상태색 if _상태색 >= 0 else _진행색):
		ColorDefs.BLACK: 내용 = Color(0.09, 0.09, 0.11)
		ColorDefs.WHITE: 내용 = Color(0.90, 0.92, 0.94)
		ColorDefs.GRAY:  내용 = Color(0.50, 0.50, 0.51)
	if _상태색 < 0 and _맞은횟수 == 0:
		진행 = 0.0
	if 진행 > 0.0:
		var h := (크기.y - 14.0) * 진행
		draw_rect(Rect2(Vector2(-반.x + 7, 반.y - 7 - h), Vector2(크기.x - 14, h)),
			Color(내용.r, 내용.g, 내용.b, 0.9))

	# 테두리 + 배관 연결구(위쪽)
	draw_rect(Rect2(-반, 크기), Color(0.45, 0.46, 0.50), false, 3.0)
	draw_rect(Rect2(Vector2(-16, -반.y - 16), Vector2(32, 18)), 금속)
	# 눈금 — 저장고처럼 보이게 하는 디테일
	for i in range(1, 4):
		var y := -반.y + 크기.y * float(i) / 4.0
		draw_line(Vector2(-반.x + 6, y), Vector2(-반.x + 22, y), Color(1, 1, 1, 0.14), 2.0)
