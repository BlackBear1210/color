extends Area2D
## 페인트 총알.
## 인스펙터의 Speed / Bullet Gravity 를 조절해 포물선 강도를 바꿀 수 있다.
##
## [충돌 처리]
##   · paint_bodies 그룹  → 기존 PaintMark 색 덮어씌우기
##   · obstacle 그룹      → 페인트 생성 없이 소멸 (가시 등 장애물)
##   · 그 외 지형         → PaintSplat 이펙트 + 새 PaintMark 생성

# ── 인스펙터 조절 파라미터 ────────────────────────────────────────────
@export var speed: float               = 1400.0  # 발사 초기 속도 (px/s)
@export var bullet_gravity: float      = 600.0   # 중력 가속도 (px/s²). 0 이면 직선 비행.
@export var paint_overlap_radius: float = 20.0   # 이 반경 안의 기존 마크를 제거 (작을수록 촘촘히 칠해짐)

# PaintMark 생성 위치 깊이 — paint_mark.gd 의 SPAWN_DEPTH 와 반드시 일치해야 함
const PAINT_SPAWN_DEPTH: float = 25.0

# ── 런타임 변수 ───────────────────────────────────────────────────────
var direction:    Vector2 = Vector2.RIGHT    # 발사 방향 (단위 벡터)
var bullet_color: int     = ColorDefs.WHITE  # 총알 색 (player.gd 에서 설정)

const PAINT_MARK  := preload("res://scenes/effects/PaintMark.tscn")
const PAINT_SPLAT := preload("res://scenes/effects/PaintSplat.tscn")

var _velocity: Vector2 = Vector2.ZERO

# ▼ 2026-06-22 (작업 A) 총알 잔상(트레일)용 Line2D
var _trail: Line2D = null

func _ready() -> void:
	_velocity = direction * speed

	# ▼ 2026-06-22: 총알 잔상 생성. top_level=true 로 월드 좌표에 그려 꼬리가 따라오게 한다.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 4.0
	_trail.z_index = -1
	_trail.default_color = Color(0.1, 0.1, 0.1, 0.55) if bullet_color == ColorDefs.BLACK \
						   else Color(1.0, 1.0, 1.0, 0.7)
	add_child(_trail)

	body_entered.connect(_on_body_entered)

	var life_timer := get_node_or_null("LifeTimer") as Timer
	if life_timer:
		life_timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_velocity.y += bullet_gravity * delta
	position    += _velocity * delta

	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr and _velocity.length_squared() > 0.0:
		spr.rotation = _velocity.angle()

	# ▼ 2026-06-22: 잔상 갱신 — 현재 위치를 추가하고 오래된 점은 버려 짧은 꼬리 유지
	if _trail:
		_trail.add_point(global_position)
		while _trail.get_point_count() > 10:
			_trail.remove_point(0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("paint_bodies"):
		var hit_mark: Node = body if body.has_method("update_color") else body.get_parent()
		if hit_mark and hit_mark.has_method("update_color") \
				and hit_mark.get("paint_color") != bullet_color:
			# 이 마크만 새 색으로 덮어씌움 + 시각 피드백
			hit_mark.call_deferred("update_color", bullet_color)
			_spawn_splat()
			_spawn_impact_particles()
		# 같은 색: 아무것도 안 함 (bullet만 소멸)
	elif body.is_in_group("gray_slopes"):
		# 경사로가 직접 '실제로 칠할 색'을 결정하도록 위임.
		# get_paint_color() 없는 오브젝트는 기존 방식(플레이어 색)으로 fallback.
		var paint_col: int = body.get_paint_color(bullet_color) \
				if body.has_method("get_paint_color") \
				else (ColorDefs.BLACK if bullet_color == ColorDefs.WHITE else ColorDefs.WHITE)
		_spawn_splat()
		_spawn_impact_particles()
		_spawn_mark(body, paint_col)
		if body.has_method("paint_at"):
			body.call_deferred("paint_at", global_position, paint_col)
	elif not body.is_in_group("obstacle"):
		_spawn_splat()
		_spawn_impact_particles()         # ▼ 2026-06-22: 탄착 스플래터 파티클
		_spawn_mark(body)
	_safe_free()

## ▼ 2026-06-22 신규(작업 A): 탄착 지점에 페인트 튀김 파티클을 잠깐 터뜨린다.
##   총알은 곧 사라지므로, 파티클은 씬 루트에 월드 좌표로 스폰해 독립적으로 재생/자동삭제.
func _spawn_impact_particles() -> void:
	var p := CPUParticles2D.new()
	p.one_shot     = true
	p.explosiveness = 0.9
	p.amount       = 10
	p.lifetime     = 0.4
	p.spread       = 80.0
	p.gravity      = Vector2(0, 500)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color        = Color(0.1, 0.1, 0.1, 0.9) if bullet_color == ColorDefs.BLACK \
					 else Color(1.0, 1.0, 1.0, 0.95)
	p.position     = global_position
	p.emitting     = true
	p.finished.connect(p.queue_free)
	var scene := get_tree().current_scene
	if scene:
		scene.call_deferred("add_child", p)

## 순간 스플래시 이펙트: 0.22초 후 자동 삭제
func _spawn_splat() -> void:
	var splat := PAINT_SPLAT.instantiate()
	splat.set_color(bullet_color)
	splat.global_position = global_position
	var overlay := get_tree().current_scene.find_child("PaintOverlay", true, false)
	var parent: Node = overlay if overlay else get_tree().current_scene
	parent.call_deferred("add_child", splat)

## 영구 페인트 자국: "runtime_paint" 그룹 → 리스폰 시 일괄 제거
## ▼ 2026-06-22: paint_col 인자 추가. -1 이면 총알색(bullet_color), 아니면 지정색으로 칠한다.
##   (회색 경사로는 '플레이어 색'으로 칠해야 해서 지정색이 필요)
func _spawn_mark(terrain_body: Node = null, paint_col: int = -1) -> void:
	var col: int = bullet_color if paint_col < 0 else paint_col
	var pos: Vector2 = global_position + direction * PAINT_SPAWN_DEPTH

	# 반경 내 기존 마크 전부 제거 (같은 색 포함) → 새 마크 하나로 교체
	# 같은 색을 남기면 같은 자리에 마크가 쌓여 z-fighting(겹침 깜빡임) 발생
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		if p.global_position.distance_to(pos) < paint_overlap_radius:
			p.queue_free()

	var mark := PAINT_MARK.instantiate()
	mark.paint_color      = col
	mark.global_position  = pos

	# ① CollisionPolygon2D(SOLIDS) → 엣지 법선 + 클리핑
	# ② CollisionPolygon2D(SEGMENTS) → 엣지 법선만, 클리핑 생략
	#    (SEGMENTS 는 꼭짓점이 100개를 초과하면 쉐이더 한도로 잘려 페인트가 사라짐)
	# ③ CollisionShape2D (Rectangle 등) → 면 법선 추정
	# ④ 없으면 총알 방향 그대로
	var impact_dir := direction
	if terrain_body:
		var poly_node := _find_collision_polygon(terrain_body)
		if poly_node:
			impact_dir = _get_surface_normal(
				poly_node.polygon,
				poly_node.global_transform,
				global_position,
				direction
			)
			# SOLIDS 폴리곤만 클리핑에 사용 (SEGMENTS 는 꼭짓점 과다로 생략)
			if poly_node.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
				mark.setup_terrain_clip(poly_node.polygon, poly_node.global_transform)
		else:
			impact_dir = _get_shape_normal(terrain_body, global_position, direction)

	mark.impact_direction = impact_dir

	var overlay := get_tree().current_scene.find_child("PaintOverlay", true, false)
	var parent: Node = overlay if overlay else get_tree().current_scene
	parent.call_deferred("add_child", mark)

## StaticBody 안의 모든 CollisionPolygon2D 중 충돌 지점에 가장 가까운 것을 반환.
## SOLIDS(채움) 폴리곤을 SEGMENTS(외곽선)보다 우선 선택한다.
## 이유: stage 2 동굴처럼 SEGMENTS 폴리곤이 수백 개 꼭짓점을 가질 때
##       클리핑 쉐이더 MAX_VERTS(100) 제한으로 잘리면 PaintMark 가 통째로 사라짐.
func _find_collision_polygon(node: Node) -> CollisionPolygon2D:
	var all_polys: Array[CollisionPolygon2D] = []
	_collect_polygons(node, all_polys)
	if all_polys.is_empty():
		return null
	if all_polys.size() == 1:
		return all_polys[0]

	# SOLIDS 만 먼저 추려서 가장 가까운 것 선택 — 없으면 전체에서 선택
	var candidates := all_polys.filter(
		func(p: CollisionPolygon2D) -> bool:
			return p.build_mode == CollisionPolygon2D.BUILD_SOLIDS
	)
	if candidates.is_empty():
		candidates = all_polys

	var best: CollisionPolygon2D = candidates[0]
	var best_dist := INF
	for poly: CollisionPolygon2D in candidates:
		var xf := poly.global_transform
		var n   := poly.polygon.size()
		for i in n:
			var a: Vector2 = xf * poly.polygon[i]
			var b: Vector2 = xf * poly.polygon[(i + 1) % n]
			var edge     := b - a
			var edge_len := edge.length()
			if edge_len < 0.001:
				continue
			var edge_dir := edge / edge_len
			var t    := clampf((global_position - a).dot(edge_dir), 0.0, edge_len)
			var dist := (global_position - (a + edge_dir * t)).length()
			if dist < best_dist:
				best_dist = dist
				best = poly
	return best

func _collect_polygons(node: Node, result: Array[CollisionPolygon2D]) -> void:
	for child in node.get_children():
		if child is CollisionPolygon2D:
			result.append(child as CollisionPolygon2D)
		_collect_polygons(child, result)

## 충돌 지점에서 가장 가까운 폴리곤 엣지의 법선을 반환.
## fallback(총알 방향)과 같은 방향인 법선을 선택 → 지형 안쪽을 향하도록 보정.
func _get_surface_normal(polygon: PackedVector2Array,
		terrain_xform: Transform2D,
		impact_pos: Vector2,
		fallback: Vector2) -> Vector2:
	var closest_dist := INF
	var result       := fallback

	var n := polygon.size()
	for i in n:
		var a: Vector2 = terrain_xform * polygon[i]
		var b: Vector2 = terrain_xform * polygon[(i + 1) % n]
		var edge    := b - a
		var edge_len := edge.length()
		if edge_len < 0.001:
			continue
		var edge_dir := edge / edge_len
		var t        := clampf((impact_pos - a).dot(edge_dir), 0.0, edge_len)
		var dist     := (impact_pos - (a + edge_dir * t)).length()

		if dist < closest_dist:
			closest_dist = dist
			var normal := Vector2(-edge_dir.y, edge_dir.x)
			# fallback(총알 방향)과 내적이 음수면 반전 → 항상 지형 안쪽 방향
			if normal.dot(fallback) < 0.0:
				normal = -normal
			result = normal

	return result

## CollisionPolygon2D 가 없을 때 CollisionShape2D(RectangleShape2D)로부터 충돌 면 법선을 추정한다.
## 충돌 지점(impact_pos)을 로컬 좌표로 변환 후, 가장 가까운 면의 법선을 반환.
## RectangleShape2D 이외의 Shape 는 fallback 반환.
func _get_shape_normal(node: Node, impact_pos: Vector2, fallback: Vector2) -> Vector2:
	for child in node.get_children():
		if not (child is CollisionShape2D):
			continue
		var shape := (child as CollisionShape2D).shape
		if not (shape is RectangleShape2D):
			continue

		var xf   := (child as CollisionShape2D).global_transform
		var half := (shape as RectangleShape2D).size * 0.5

		# 충돌 지점을 CollisionShape2D 로컬 좌표로 변환
		var local := xf.affine_inverse() * impact_pos

		# 각 면까지의 거리 — 최솟값 = 충돌한 면
		var dists   := [absf(local.x + half.x), absf(local.x - half.x),
						absf(local.y + half.y), absf(local.y - half.y)]
		var normals := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

		var min_i := 0
		for i in 4:
			if dists[i] < dists[min_i]:
				min_i = i

		var world_normal := xf.basis_xform(normals[min_i]).normalized()
		# fallback(총알 방향)과 같은 방향을 향하도록 보정
		if world_normal.dot(fallback) < 0.0:
			world_normal = -world_normal
		return world_normal

	return fallback


func _safe_free() -> void:
	if is_inside_tree():
		queue_free()
