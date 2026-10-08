extends Node2D
## 한 경로를 그림·위험 판정·수광판 활성화에 함께 쓴다. 거울이 움직여도 다음 물리 틱에 다시 계산한다.
const Mirror := preload("res://scripts/쳅터1/거울.gd")
const Beam := preload("res://scripts/쳅터1/창문빛.gd")
@export var 광원 := Vector2(0, -300)
@export var 광원방향 := Vector2.DOWN
@export var 수광점 := Vector2(580, 0)
@export var 최대거리 := 1600.0
@export var 최대반사 := 6
var 거울: Node2D
var 빛경로: Array[Vector2] = []
var 길켜짐 := false
var _빔들: Array[Node2D] = []
var _발판들: Array[StaticBody2D] = []

func _ready() -> void:
	z_index = 12 # 조작 안내가 앞쪽 목재에 가려지지 않게 한다.
	거울 = Mirror.new()
	거울.name = "거울"
	add_child(거울)
	for i in 최대반사 + 1:
		var beam := Beam.new()
		beam.시작색 = ColorDefs.WHITE
		beam.주기 = 0
		beam.두께 = 14
		beam.알갱이 = 8
		add_child(beam)
		_빔들.append(beam)
	for x in [120.0, 350.0, 570.0]:
		var body := StaticBody2D.new()
		# [2026-10-07 Claude] y 40 → 25: 발판 윗면(노드 y + 25 − 9)이 32px 칸 경계(15번 37행)에 오게 —
		#   도안 검사(검사.py 반사빛길_발판_y)와 엔진 경로 재생이 같은 높이를 본다. 그림(_draw)은 body 위치를 따라간다.
		body.position = Vector2(x, 25)
		body.collision_layer = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(170, 18)
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
		_발판들.append(body)

func 반대색인가(색: int) -> bool:
	return 길켜짐 and 색 != ColorDefs.WHITE

func _physics_process(_delta: float) -> void:
	var origin := to_global(광원)
	var direction := 광원방향.normalized()
	var remaining := 최대거리
	빛경로.clear()
	빛경로.append(origin)
	var received := false
	var exclude: Array[RID] = []
	var p := get_tree().current_scene.get_node_or_null("Player") as CollisionObject2D
	if p:
		exclude.append(p.get_rid())
	for body in _발판들:
		exclude.append(body.get_rid())
	var previous: Node2D = null
	for bounce in 최대반사 + 1:
		var endpoint := origin + direction * remaining
		var q := PhysicsRayQueryParameters2D.create(origin, endpoint, 1, exclude)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			endpoint = hit.position
		var nearest: Node2D = null
		# 자식 거울을 추가하면 같은 계산으로 다중 반사를 지원한다. 자기 면 재충돌은 건너뛴다.
		for node in get_children():
			if not node.has_method("끝점들") or node == previous:
				continue
			var ends: PackedVector2Array = node.끝점들()
			var point: Variant = Geometry2D.segment_intersects_segment(origin, endpoint, ends[0], ends[1])
			if point != null and origin.distance_to(point) > 0.1:
				endpoint = point
				nearest = node
		var receiver := to_global(수광점)
		var close := Geometry2D.get_closest_point_to_segment(receiver, origin, endpoint)
		# 직사광은 열지 않는다. 적어도 한 번 거울에 반사된 빛만 수광판을 작동시킨다.
		if bounce > 0 and close.distance_to(receiver) < 22:
			received = true
		빛경로.append(endpoint)
		remaining -= origin.distance_to(endpoint)
		if nearest == null or remaining < 1:
			break
		var normal: Vector2 = nearest.법선()
		direction = (direction - 2.0 * direction.dot(normal) * normal).normalized()
		origin = endpoint + direction * 0.5
		previous = nearest
	길켜짐 = received
	for body in _발판들:
		body.collision_layer = 1 if 길켜짐 else 0
	for i in _빔들.size():
		var beam := _빔들[i]
		var on := i < 빛경로.size() - 1
		beam.visible = on
		beam._켜짐 = on
		if on:
			var v := 빛경로[i+1] - 빛경로[i]
			beam.global_position = 빛경로[i]
			if absf(beam.각도 - rad_to_deg(v.angle())) > 0.01:
				beam.각도 = rad_to_deg(v.angle())
			if absf(beam.길이 - v.length()) > 0.1:
				beam.길이 = v.length()
	queue_redraw()

func _draw() -> void:
	# 외부 마당의 집광 창은 공중에 떠 있지 않도록 오래된 철제 받침과 연결한다.
	draw_line(광원 + Vector2(-44, -45), Vector2(-44, 78), Color(0.16,0.15,0.13), 9, true)
	draw_line(광원 + Vector2(-44, -45), 광원 + Vector2(40,-45), Color(0.23,0.22,0.2), 9, true)
	draw_circle(광원 + Vector2(-44,-45), 9, Color(0.3,0.28,0.23))
	# 광원 유리와 빛 출발점이 동일 좌표라 장식 창문과 빛이 따로 놀지 않는다.
	draw_rect(Rect2(광원 - Vector2(34, 44), Vector2(68, 88)), Color(0.09, 0.08, 0.07))
	draw_rect(Rect2(광원 - Vector2(26, 36), Vector2(52, 72)), Color(0.68, 0.72, 0.78))
	draw_line(광원 + Vector2(-26, 0), 광원 + Vector2(26, 0), Color(0.14, 0.13, 0.12), 5)
	draw_line(광원 + Vector2(0, -36), 광원 + Vector2(0, 36), Color(0.14, 0.13, 0.12), 5)
	draw_circle(수광점, 25, Color(0.18, 0.17, 0.15))
	draw_circle(수광점, 15, Color.WHITE if 길켜짐 else Color(0.4, 0.4, 0.4))
	for body in _발판들:
		var r := Rect2(body.position - Vector2(85, 9), Vector2(170, 18))
		if 길켜짐:
			draw_rect(r.grow(7), Color(0.85, 0.91, 1, 0.12))
			draw_rect(r, Color(0.94, 0.97, 1))
		else:
			draw_rect(r, Color(0.6, 0.64, 0.7, 0.32), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(-125, 128), "거울로 빛을 돌리면 흰 길이 생긴다 · Shift 흰색", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.9, 0.9, 0.88))
