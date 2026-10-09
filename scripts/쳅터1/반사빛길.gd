extends Node2D
## 한 경로를 그림·위험 판정·수광판 활성화에 함께 쓴다. 거울이 움직여도 다음 물리 틱에 다시 계산한다.
const Mirror := preload("res://scripts/쳅터1/거울.gd")
const Beam := preload("res://scripts/쳅터1/창문빛.gd")
## [2026-10-09 Claude] 광원 = 하늘(달빛). 예전엔 −300(쇠기둥 위 창문)이었다 → 도형님 "집 밖 스테이지에 왜 창문이 달렸나 · 지워 줘".
##   빛은 맨 위(하늘)에서 거울로 곧게 내려온다 — 거울·수광판·흰 다리 계산은 그대로(빛이 더 위에서 시작할 뿐).
@export var 광원 := Vector2(0, -1200)       # 맨 위에서 3칸 안쪽 — 0 이면 방 밖 바깥 지형 경계에서 광선이 바로 막힌다
@export var 광원방향 := Vector2.DOWN
@export var 수광점 := Vector2(580, 0)
@export var 최대거리 := 2500.0     # [2026-10-09] 광원을 하늘로 900px 올린 만큼 늘렸다(예전 1600 — 그대로면 반사 뒤 수광판 앞에서 빛이 끊긴다)
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
	# [2026-10-09] 창문·쇠기둥 그림을 지웠다(집 밖 마당) — 빛은 하늘에서 내려오는 달빛 줄기(빔 그림)만 보인다.
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
