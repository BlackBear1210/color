@tool
extends Node2D
## ============================================================================
## [2026-08-06 신규] 색 레이저 — 주기적으로 색이 바뀌는 빛줄기
## ----------------------------------------------------------------------------
## ▣ 기획 근거
##   `docs/장애물_아이디어_정리.md` §3 "색 레이저 / 가로등 서치라이트" 항목.
##   **빛 안에 있는데 빛과 다른 색이면 사망** — 이 게임에서 유일하게 "색 규칙이
##   내장된" 장애물이고, 물감을 쓰지 않고도 색 전환(Shift)만으로 넘는 구간을 만든다.
##
## ▣ 왜 지금 넣었나
##   스마트월드 오브젝트 11 종은 전부 **물감을 쓰는** 것들이라, 물감이 떨어지면
##   할 수 있는 게 없어진다. 색 레이저는 **물감 0 발로도 통과할 수 있는** 장애물이라
##   레벨의 리듬(물감 구간 ↔ 반사신경 구간)을 만들 수 있다.
##
## ▣ 규칙
##   · 빔이 켜져 있는 동안, 빔에 몸이 닿은 플레이어의 색이 **빔 색과 다르면 사망**.
##   · 색은 `주기` 마다 흑↔백으로 전환된다. 전환 직전 `예고시간` 동안 깜빡여 경고한다.
##   · `점멸` 을 켜면 색은 그대로 두고 켜짐/꺼짐만 반복한다(타이밍 장애물).
##   · 빔 자체는 칠할 수 없다. 물감으로 해결하는 장애물이 아니다.
##
## ▣ 사망 판정을 누가 하나
##   월드.gd 의 `_사망_판정()` 은 "발밑 지형" 과 "유체" 만 본다. 레이저는 몸 전체가
##   닿는 판정이라 성격이 달라서, **이 노드가 직접** 그룹 "색레이저" 로 등록하고
##   월드.gd 가 한 줄로 물어보게 했다 (`위험한가(플레이어)`).
## ============================================================================
class_name 색레이저

## 빔이 뻗는 길이(px).
@export_range(60, 2000) var 길이: float = 520.0:
	set(v): 길이 = v; _재구성()
## 빔 두께(px). 플레이어 폭이 약 50px 이라 그보다 얇으면 스쳐 지나갈 수 있다.
@export_range(8, 200) var 두께: float = 44.0:
	set(v): 두께 = v; _재구성()
## 빔 방향(도). 0 = 오른쪽, 90 = 아래, 270 = 위.
@export_range(0.0, 360.0) var 각도: float = 90.0:
	set(v): 각도 = v; _재구성()

@export_group("주기")
## 시작 색.
@export var 시작색: int = ColorDefs.BLACK
## 색이 바뀌는 주기(초). 0 이면 색이 고정된다.
@export_range(0.0, 20.0) var 주기: float = 3.0
## 색이 바뀌기 전 경고로 깜빡이는 시간(초).
@export_range(0.0, 3.0) var 예고시간: float = 0.7
## 켜면 색 전환 대신 켜짐/꺼짐을 반복한다.
@export var 점멸: bool = false
## 시작 위상(초). 여러 개를 엇갈리게 배치할 때 쓴다.
@export var 위상: float = 0.0

var _t: float = 0.0
var _색: int = ColorDefs.BLACK
var _켜짐: bool = true
var _영역: Area2D = null


func _ready() -> void:
	_색 = 시작색
	_t = 위상
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("색레이저")
	set_physics_process(true)
	set_process(true)


func _재구성() -> void:
	if not is_inside_tree():
		return
	if _영역 == null:
		_영역 = get_node_or_null("빔판정") as Area2D
	if _영역 == null:
		_영역 = Area2D.new()
		_영역.name = "빔판정"
		add_child(_영역)
		if Engine.is_editor_hint() and owner:
			_영역.owner = owner
	_영역.collision_layer = 0
	_영역.collision_mask = 1
	_영역.monitoring = true

	var cs := _영역.get_node_or_null("모양") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "모양"
		cs.visible = false
		_영역.add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	r.size = Vector2(길이, 두께)
	# 회전은 Area2D 에 주고, 모양은 빔 중앙에 놓는다
	_영역.rotation = deg_to_rad(각도)
	cs.position = Vector2(길이 * 0.5, 0.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if 주기 <= 0.0:
		return
	# 주기마다 한 번 뒤집는다. floor(t/주기) 의 홀짝으로 상태를 정하면
	# 프레임 드랍이 나도 상태가 어긋나지 않는다(누적 방식은 어긋난다).
	var 짝 := int(floor(_t / 주기)) % 2 == 0
	if 점멸:
		_켜짐 = 짝
		_색 = 시작색
	else:
		_켜짐 = true
		_색 = 시작색 if 짝 else _반대(시작색)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


static func _반대(색: int) -> int:
	return ColorDefs.WHITE if 색 == ColorDefs.BLACK else ColorDefs.BLACK


## 다음 전환까지 남은 시간(초). 예고 깜빡임에 쓴다.
func _남은() -> float:
	if 주기 <= 0.0:
		return 999.0
	return 주기 - fmod(_t, 주기)


## 월드.gd 가 매 프레임 한 줄로 물어본다.
## 빔이 켜져 있고, 플레이어가 빔 안에 있고, 색이 다르면 위험하다.
func 위험한가(플레이어: Node) -> bool:
	if not _켜짐 or _영역 == null:
		return false
	if not _영역.get_overlapping_bodies().has(플레이어):
		return false
	return int(플레이어.get("player_color")) != _색


func _draw() -> void:
	if not _켜짐:
		# 꺼져 있을 때도 발사구는 보여야 "여기서 나온다"를 안다
		_발사구(0.25)
		return

	var 밝기 := 1.0
	# 색이 바뀌기 직전에는 빠르게 깜빡여 경고한다 (예고 없이 바뀌면 불합리하게 느껴진다)
	var 남 := _남은()
	if 예고시간 > 0.0 and 남 < 예고시간:
		밝기 = 0.45 + 0.55 * absf(sin(_t * 26.0))

	var 빔색 := Color(0.94, 0.94, 0.96) if _색 == ColorDefs.WHITE else Color(0.06, 0.06, 0.07)
	# 대비색 테두리 — 검정 빔이 어두운 배경에 묻히지 않게 반드시 필요하다
	var 테 := Color(0.05, 0.05, 0.06) if _색 == ColorDefs.WHITE else Color(0.85, 0.85, 0.88)

	var 방향 := Vector2.RIGHT.rotated(deg_to_rad(각도))
	var 수직 := 방향.orthogonal()
	var 끝 := 방향 * 길이

	# 바깥 번짐 → 안쪽 심지 순으로 겹쳐 그린다
	for i in range(3, 0, -1):
		var w := 두께 * (0.5 + float(i) * 0.42)
		var a := 0.10 * 밝기 * (1.0 - float(i) / 4.0) * 3.0
		draw_colored_polygon(PackedVector2Array([
			수직 * w * 0.5, 끝 + 수직 * w * 0.5,
			끝 - 수직 * w * 0.5, -수직 * w * 0.5,
		]), Color(빔색.r, 빔색.g, 빔색.b, a))

	var 심지 := PackedVector2Array([
		수직 * 두께 * 0.5, 끝 + 수직 * 두께 * 0.5,
		끝 - 수직 * 두께 * 0.5, -수직 * 두께 * 0.5,
	])
	draw_colored_polygon(심지, Color(빔색.r, 빔색.g, 빔색.b, 0.88 * 밝기))
	draw_polyline(PackedVector2Array([수직 * 두께 * 0.5, 끝 + 수직 * 두께 * 0.5]),
		Color(테.r, 테.g, 테.b, 0.75 * 밝기), 2.0)
	draw_polyline(PackedVector2Array([-수직 * 두께 * 0.5, 끝 - 수직 * 두께 * 0.5]),
		Color(테.r, 테.g, 테.b, 0.75 * 밝기), 2.0)

	_발사구(밝기)


## 빔이 나오는 장치 — 벽에 박힌 원통
func _발사구(밝기: float) -> void:
	var 본색 := Color(0.94, 0.94, 0.96) if _색 == ColorDefs.WHITE else Color(0.06, 0.06, 0.07)
	draw_circle(Vector2.ZERO, 두께 * 0.62, Color(0.13, 0.13, 0.14))
	draw_arc(Vector2.ZERO, 두께 * 0.62, 0, TAU, 24, Color(0.70, 0.70, 0.74, 0.9), 2.5)
	draw_circle(Vector2.ZERO, 두께 * 0.34, Color(본색.r, 본색.g, 본색.b, 0.55 + 0.45 * 밝기))
