@tool
extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 빛받이 — 요구한 색의 빛이 닿으면 켜져 문(창살·책장)을 여는 벽 장치 (거미방)
## ----------------------------------------------------------------------------
## ▣ 왜 따로 만들었나
##   이미 있는 수광점은 `반사빛길.gd` 안에 박혀 있어(거울 반사 전용) 다른 광원이 쓸 수 없다.
##   반딧불 몹의 빛은 움직이고 색이 바뀌고 거미줄에 가린다 → 그 규칙을 그대로 묻는 독립 장치가 필요했다.
## ▣ 판정
##   매 물리 프레임 그룹 "광원몹" 의 `빛_도달(내 위치)` 를 묻는다(반딧불 몹이 거미줄·지형 가림까지 계산한다).
##   그 값이 `요구색` 이면 빛을 받는 중. 검은 빛은 흰 빛과 다르다 — 흰 빛을 요구하는 장치에 검은 빛은 안 통한다(반대도).
## ▣ 동작 방식(장치마다 고른다)
##   · 유지(기본): 한 번 켜지면 계속 켜짐 — 문이 열린 채로 남는다(도입·학습용, 갇힘 없음).
##   · 켜진 동안만: 빛이 끊기고 `놓침_여유` 초가 지나면 꺼지고 문이 닫힌다(새장 레버로 반딧불을 붙잡는 퍼즐).
## ▣ 그림(임시 코드): 놋쇠 테 + 렌즈. 렌즈 테두리 색 = 요구색(검은 테 = 검은 빛 · 흰 테 = 흰 빛) · 켜지면 렌즈가 그 색으로 찬다.
##   아스트라 그림이 오면 `_draw` 만 바꾼다.
## ▣ 놓는 법: 원점 = 렌즈 가운데. 도안 {"종류": "빛받이", "x", "y", "색", "유지", "문": {…}} → 생성기가 문과 함께 놓는다.
## ============================================================================

@export_enum("검정:0", "흰:1") var 요구색: int = 1:
	set(v): 요구색 = v; queue_redraw()
## true = 한 번 켜지면 계속 켜짐. false = 빛을 받는 동안만(놓침_여유 뒤 꺼짐).
@export var 유지: bool = true:
	set(v): 유지 = v; queue_redraw()
@export_range(0.0, 3.0, 0.05) var 놓침_여유: float = 0.5
## 켜지면 `열기()` · 꺼지면 `닫기()` 를 부를 노드들(비밀문 등).
@export var 열것들: Array[NodePath] = []

signal 켜짐_바뀜(켜짐: bool)

var 켜짐 := false
var _받는중 := false
var _놓친 := 0.0
var _반짝 := 0.0


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group("빛받이")
	add_to_group("부활복구")
	z_index = 4


## 지금 이 자리에 요구색 빛이 닿나 — 시험·HUD 도 같은 함수를 쓴다.
func 빛_받나() -> bool:
	for n in get_tree().get_nodes_in_group("광원몹"):
		if n.has_method("빛_도달") and int(n.call("빛_도달", global_position)) == 요구색:
			return true
	return false


func _physics_process(delta: float) -> void:
	var 받음 := 빛_받나()
	if 받음 != _받는중:
		_받는중 = 받음
		queue_redraw()
	if 받음:
		_놓친 = 0.0
		if not 켜짐:
			_켜기(true)
	elif 켜짐 and not 유지:
		_놓친 += delta
		if _놓친 >= 놓침_여유:
			_켜기(false)
	if _반짝 > 0.0:
		_반짝 = maxf(_반짝 - delta, 0.0)
		queue_redraw()


func _켜기(v: bool) -> void:
	켜짐 = v
	_반짝 = 0.5 if v else 0.0
	for 경로 in 열것들:
		var n := get_node_or_null(경로)
		if n == null:
			continue
		if v and n.has_method("열기"):
			n.call("열기")
		elif not v and n.has_method("닫기"):
			n.call("닫기")
	켜짐_바뀜.emit(v)
	queue_redraw()


## 월드 `_리스폰` — '켜진 동안만' 장치는 처음 상태로(문도 닫는다 · 이미 지나간 문은 비밀문.gd 가 영구로 둔다).
func 부활_복구() -> void:
	if not 유지 and 켜짐:
		_켜기(false)


# ── 그림(임시 코드) ──────────────────────────────────────────────────────────
func _draw() -> void:
	var 놋 := Color(0.55, 0.45, 0.25)
	var 요구 := Color(0.06, 0.06, 0.07) if 요구색 == 0 else Color(0.95, 0.95, 0.92)
	# 벽에 박힌 받침
	draw_rect(Rect2(-26, -34, 52, 68), Color(0.16, 0.14, 0.12))
	draw_rect(Rect2(-26, -34, 52, 68), 놋.darkened(0.3), false, 3.0)
	# 놋쇠 테 + 요구색 테두리
	draw_circle(Vector2.ZERO, 22.0, 놋)
	draw_circle(Vector2.ZERO, 18.0, 요구)
	# 렌즈 — 꺼짐: 탁한 회색 · 받는 중: 요구색으로 빛남 · 켜짐(유지): 가운데 점등
	var 렌즈 := Color(0.32, 0.33, 0.35)
	if 켜짐 or _받는중:
		렌즈 = Color(1.0, 0.97, 0.85) if 요구색 == 1 else Color(0.0, 0.0, 0.0)
	draw_circle(Vector2.ZERO, 13.0, 렌즈)
	if 켜짐:
		var 빛 := Color(1, 0.95, 0.7, 0.25 + 0.5 * _반짝) if 요구색 == 1 else Color(0.75, 0.7, 1.0, 0.25 + 0.5 * _반짝)
		draw_arc(Vector2.ZERO, 27.0 + 10.0 * _반짝, 0, TAU, 32, 빛, 3.0, true)
	# 아래 작은 표시등 — 유지형(●)인지 켜진 동안만(◐)인지
	var 표시 := Vector2(0, 27)
	draw_circle(표시, 4.0, Color(0.85, 0.8, 0.6) if 켜짐 else Color(0.3, 0.28, 0.25))
	if not 유지:
		draw_arc(표시, 6.5, 0, TAU, 16, Color(0.85, 0.8, 0.6, 0.7), 1.5)
