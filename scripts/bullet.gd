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
@export var paint_overlap_radius: float = 3.0    # 이 반경 안의 기존 마크를 제거 (작을수록 촘촘히 칠해짐)

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
		if hit_mark and hit_mark.get("paint_color") != bullet_color:
			# 다른 색: 반경 내 모든 페인트를 새 색으로 변경
			var pos: Vector2 = hit_mark.global_position
			for p in get_tree().get_nodes_in_group("runtime_paint"):
				if p.global_position.distance_to(pos) < paint_overlap_radius:
					p.call_deferred("update_color", bullet_color)
		# 같은 색: 아무것도 안 함 (bullet만 소멸)
	elif body.is_in_group("gray_slopes"):
		# ▼ 2026-06-22 변경: 회색 경사로는 '플레이어 색'으로 칠해야 밟고 오를 수 있다.
		#   총알은 플레이어의 반대색이므로, 칠하는 색 = 반대색의 반대 = 플레이어 색.
		#   (전역 총알색을 반대색으로 되돌린 뒤에도 회색경사로 기믹을 유지하기 위한 예외 처리)
		var player_color := ColorDefs.BLACK if bullet_color == ColorDefs.WHITE else ColorDefs.WHITE
		_spawn_splat()
		_spawn_impact_particles()         # ▼ 2026-06-22: 탄착 스플래터 파티클
		_spawn_mark(body, player_color)   # 등반/안전/미끄럼해제용 PaintMark (플레이어 색)
		if body.has_method("paint_at"):
			# 경사로 표면 '플레이어색→회색' 그라데이션 (비주얼)
			body.call_deferred("paint_at", global_position, player_color)
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
	var pos: Vector2 = global_position + direction * 25.0

	# 반경 내 다른 색 페인트만 제거 (같은 색은 유지 → 스택)
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		if p.global_position.distance_to(pos) < paint_overlap_radius:
			if p.get("paint_color") != col:
				p.queue_free()

	var mark := PAINT_MARK.instantiate()
	mark.paint_color      = col
	mark.global_position  = pos

	# ① 1차: 플레이어 기준 (총알 방향)
	# ② 2차: 실제 지형 폴리곤 엣지 법선으로 보정
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
			mark.setup_terrain_clip(poly_node.polygon, poly_node.global_transform)

	mark.impact_direction = impact_dir

	var overlay := get_tree().current_scene.find_child("PaintOverlay", true, false)
	var parent: Node = overlay if overlay else get_tree().current_scene
	parent.call_deferred("add_child", mark)

## StaticBody 안의 모든 CollisionPolygon2D 중 충돌 지점에 가장 가까운 것을 반환
func _find_collision_polygon(node: Node) -> CollisionPolygon2D:
	# 모든 폴리곤 수집
	var all_polys: Array[CollisionPolygon2D] = []
	_collect_polygons(node, all_polys)
	if all_polys.is_empty():
		return null
	if all_polys.size() == 1:
		return all_polys[0]

	# 충돌 지점(global_position)에서 가장 가까운 엣지를 가진 폴리곤 선택
	var best: CollisionPolygon2D = all_polys[0]
	var best_dist := INF
	for poly in all_polys:
		var xf := poly.global_transform
		var n   := poly.polygon.size()
		for i in n:
			var a: Vector2 = xf * poly.polygon[i]
			var b: Vector2 = xf * poly.polygon[(i + 1) % n]
			var edge    := b - a
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

func _safe_free() -> void:
	if is_inside_tree():
		queue_free()
