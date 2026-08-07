@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 송풍기
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 선풍기처럼 팬이 돌아간다.
##   · 바라보는 방향으로 바람을 발사한다.
##   · **연기를 이동시키고, 페인트 투사체의 경로에 영향을 준다.**
##
## ▣ 바람을 어떻게 전달하나
##   Area2D 로 감지하지 않고 **총알이 매 프레임 물어보는** 방식을 쓴다.
##   총알은 collision_layer 0(아무에게도 안 잡힘)이라 Area2D 로는 못 잡는데,
##   레이어를 열어주면 총알끼리 서로 감지하는 등 부작용이 생긴다.
##   송풍기는 스테이지에 몇 대 없으므로 그룹 순회가 훨씬 싸고 확실하다.
##
## ▣ 방향
##   노드의 rotation 이 곧 바람 방향이다. 기본(0도)은 오른쪽.
## ============================================================================
class_name 송풍기

## 바람이 닿는 거리(px)와 폭(px).
@export var 사거리: float = 420.0:
	set(v): 사거리 = maxf(v, 40.0); _다시_만들기(); queue_redraw()
@export var 바람폭: float = 130.0:
	set(v): 바람폭 = maxf(v, 20.0); _다시_만들기(); queue_redraw()

## 총알에 매초 더해지는 가속(px/s²). 끝으로 갈수록 약해진다.
@export var 세기: float = 900.0

## 켜져 있는가. 나중에 색칠/스위치로 껐다 켤 수 있게 열어둔다.
@export var 켜짐: bool = true:
	set(v): 켜짐 = v; queue_redraw()

var _회전: float = 0.0
var _디버그_누적: float = 0.0   ## [디버그전용] "바람이 안 먹히는 것 같다" 제보 원인 확인용


func _ready() -> void:
	collision_layer = 1               # 본체는 밟을 수 있는 구조물
	collision_mask = 0
	_다시_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("송풍기")
	set_process(true)
	set_physics_process(true)
	queue_redraw()


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null("본체") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "본체"
		add_child(c)
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = Vector2(34.0, 바람폭 * 0.7)
	c.position = Vector2(-17.0, 0)


## 이 위치에 작용하는 바람 가속도(월드 기준). 바람 밖이면 0 벡터.
## 총알·연기가 이 함수를 부른다.
func 바람(월드좌표: Vector2) -> Vector2:
	if not 켜짐:
		return Vector2.ZERO
	var 로컬 := to_local(월드좌표)
	if 로컬.x < 0.0 or 로컬.x > 사거리:
		return Vector2.ZERO
	# 원뿔 모양 — 멀어질수록 넓어지고 약해진다
	var 진행 := 로컬.x / 사거리
	var 반폭 := 바람폭 * 0.5 * lerpf(0.55, 1.35, 진행)
	if absf(로컬.y) > 반폭:
		return Vector2.ZERO
	var 감쇠 := (1.0 - 진행) * (1.0 - absf(로컬.y) / 반폭 * 0.6)
	return Vector2.RIGHT.rotated(global_rotation) * 세기 * 감쇠


## 연기를 밀어낸다 — 기획의 "연기를 이동시킨다".
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not 켜짐:
		return
	for n in get_tree().get_nodes_in_group("유체"):
		var f := n as 유체
		if f == null or f.종류 != 유체.종류_.연기 or not f.켜짐:
			continue
		var 힘 := 바람(f.global_position)
		if 힘 != Vector2.ZERO:
			f.global_position += 힘 * delta * 0.0016 * 60.0


func _process(delta: float) -> void:
	if 켜짐:
		_회전 += delta * 14.0
		queue_redraw()

	if OS.is_debug_build():
		_디버그_누적 += delta
		if _디버그_누적 >= 1.0:
			_디버그_누적 = 0.0
			print("[송풍기:%s] 켜짐=%s 방향각=%.0f° 사거리=%.0f 바람폭=%.0f 세기=%.0f" %
				[name, 켜짐, rad_to_deg(global_rotation), 사거리, 바람폭, 세기])


# ── 페인트코어와의 약속 — 색칠할 수 없다 ────────────────────────────────────
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"

func 되돌리기() -> bool:
	return false

func 현재색() -> int:
	return -1

func 반대색인가(_플레이어색: int) -> bool:
	return false


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 금속 := Color(0.26, 0.27, 0.30)
	var 밝은 := Color(0.55, 0.56, 0.60)

	# 바람 — 사거리를 따라 흐르는 반투명 줄무늬 (보이지 않으면 퍼즐이 안 읽힌다)
	if 켜짐:
		var 칸 := 7
		for i in 칸:
			var t0 := float(i) / float(칸)
			var t1 := float(i + 1) / float(칸)
			var 반0 := 바람폭 * 0.5 * lerpf(0.55, 1.35, t0)
			var 반1 := 바람폭 * 0.5 * lerpf(0.55, 1.35, t1)
			var a := 0.14 * (1.0 - t0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(사거리 * t0, -반0), Vector2(사거리 * t1, -반1),
				Vector2(사거리 * t1, 반1), Vector2(사거리 * t0, 반0)
			]), Color(0.85, 0.88, 0.92, a))

	# 케이스
	draw_rect(Rect2(Vector2(-34, -바람폭 * 0.42), Vector2(34, 바람폭 * 0.84)), 금속)
	draw_rect(Rect2(Vector2(-34, -바람폭 * 0.42), Vector2(34, 바람폭 * 0.84)), 밝은, false, 2.0)

	# 팬 — 날개 3장이 돈다
	var 중심 := Vector2(-17, 0)
	var 반지름 := 바람폭 * 0.34
	for i in 3:
		var a := _회전 + TAU * float(i) / 3.0
		var pts := PackedVector2Array([
			중심,
			중심 + Vector2(cos(a), sin(a)) * 반지름,
			중심 + Vector2(cos(a + 0.7), sin(a + 0.7)) * 반지름 * 0.8,
		])
		draw_colored_polygon(pts, 밝은)
	draw_circle(중심, 5.0, Color(0.15, 0.15, 0.17))
