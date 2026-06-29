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

	# ▼ 2026-06-29 (버그수정): 위치 오프셋과 회전 정렬이 서로 다른 방향(궤적 vs 법선)을 써서
	#   벽처럼 궤적과 표면 법선이 어긋나는 경우 마크가 안쪽으로 박혀 보이던 문제.
	#   → 법선(impact_dir)을 먼저 한 번만 구해서 위치/회전 둘 다 동일하게 사용한다.
	var poly_node: CollisionPolygon2D = null
	var spr: Sprite2D = null
	if terrain_body:
		poly_node = _find_collision_polygon(terrain_body)
		# ▼ 클리핑은 '지형 비주얼(Sprite2D 텍스처 알파)' 우선.
		#   ① 먼저 맞은 물리 바디의 자식 Sprite2D(TerrainImage 형) 를 찾고,
		#   ② 없으면(stage_1 처럼 비주얼/물리가 분리된 경우) paint_surface 그룹에서
		#      '탄착점을 덮는' 지형 그림을 찾는다.
		spr = _find_terrain_sprite(terrain_body)
		if spr == null:
			spr = _find_surface_sprite(global_position)

	# ▼ 2026-06-29 (버그수정 2차): body_entered 가 발동하는 순간의 global_position 은
	#   "표면에 닿은 지점"이 아니라 Area2D 가 겹침을 감지한 위치라 이미 폴리곤 안쪽으로
	#   파고든 상태일 수 있다. 거기서 또 법선 방향으로 25px 를 밀어넣으면 깊이가 누적되어
	#   더 깊숙이 박힌다. → 폴리곤 위 '실제 표면 접점'을 구해 그 점을 기준으로 깊이를 넣는다.
	var impact_dir   := direction
	var surface_point := global_position
	if poly_node:
		var closed := poly_node.build_mode == CollisionPolygon2D.BUILD_SOLIDS
		var proj := _project_to_surface(poly_node.polygon, poly_node.global_transform, global_position, direction, closed)
		surface_point = proj.point
		impact_dir    = proj.normal
	elif spr and spr.texture:
		# 폴리곤이 없는(텍스처 전용) 표면은 알파 그라디언트로 법선을 근사
		impact_dir = _normal_from_texture_alpha(spr, global_position, direction)

	var pos: Vector2 = surface_point + impact_dir * 25.0

	# 반경 내 다른 색 페인트만 제거. 같은 색이 이미 있으면 새로 만들지 않고 그대로 둔다.
	# ▼ 2026-06-28 (안전장치): 같은 자리에 같은 색 PaintMark 가 무한 스택되는 걸 막는다.
	#   연발 사격 시 한 지점에 마크가 폭증해 색 판정/성능이 꼬이던 문제를 줄인다.
	#   (연발 자체는 player.gd 의 에너지 시스템이 1차로 제한한다.)
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		if p.global_position.distance_to(pos) < paint_overlap_radius:
			if p.get("paint_color") != col:
				p.queue_free()
			else:
				return   # 같은 색 마크가 이미 있음 → 중복 생성 방지

	var mark := PAINT_MARK.instantiate()
	mark.paint_color      = col
	mark.global_position  = pos
	mark.impact_direction = impact_dir

	if spr and spr.texture:
		mark.setup_terrain_clip_tex(
			spr.texture, spr.global_transform, spr.texture.get_size(),
			spr.centered, spr.offset
		)
	elif poly_node:
		mark.setup_terrain_clip(poly_node.polygon, poly_node.global_transform)

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
		# ▼ 2026-06-29: build_mode=1(SEGMENTS, 열린 선)은 마지막 점과 첫 점을 잇지 않는다.
		#   닫힌 폴리곤(SOLIDS)처럼 (i+1)%n 으로 강제로 닫으면 존재하지 않는 가짜 변이
		#   생겨 그 변이 "가장 가까운 변"으로 잘못 뽑히는 경우가 있었다(stage_2 동굴).
		var closed := poly.build_mode == CollisionPolygon2D.BUILD_SOLIDS
		var edge_count := n if closed else n - 1
		for i in edge_count:
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

## ▼ 2026-06-28 신규: 지형 노드 안에서 '텍스처가 있는 첫 Sprite2D'(비주얼 그림)를 찾는다.
##   TerrainImage 처럼 그림 지형이면 반환, Polygon2D 기반 기하 발판이면 null(→ 폴리곤 클립 폴백).
func _find_terrain_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			return child as Sprite2D
		var found := _find_terrain_sprite(child)
		if found:
			return found
	return null

## ▼ 2026-06-28 신규: paint_surface 그룹에서 '탄착점(world_pos)을 덮는' 지형 그림 Sprite2D 를 찾는다.
##   비주얼/물리가 분리된 스테이지(예: stage_1 MapVisual/TerrainSprite)에서 페인트를 그림에 클립하기 위함.
##   여러 개가 겹치면 가장 작은(=구체적인) 것을 선택. 정밀 알파 판정은 셰이더가 픽셀 단위로 처리.
func _find_surface_sprite(world_pos: Vector2) -> Sprite2D:
	var best: Sprite2D = null
	var best_area := INF
	for n in get_tree().get_nodes_in_group("paint_surface"):
		var s := n as Sprite2D
		if s == null or s.texture == null:
			continue
		var tex_size: Vector2 = s.texture.get_size()
		var local: Vector2 = s.to_local(world_pos)
		var rect := Rect2(s.offset - tex_size * 0.5, tex_size) if s.centered \
				else Rect2(s.offset, tex_size)
		if rect.has_point(local):
			var area: float = tex_size.x * tex_size.y
			if area < best_area:
				best_area = area
				best = s
	return best

## 점이 (월드 좌표) 폴리곤 내부인지 판정 (레이캐스팅/짝홀 판정).
func _point_in_polygon(point: Vector2, world_pts: PackedVector2Array) -> bool:
	var inside := false
	var n := world_pts.size()
	var j := n - 1
	for i in n:
		var pi: Vector2 = world_pts[i]
		var pj: Vector2 = world_pts[j]
		if (pi.y > point.y) != (pj.y > point.y):
			var slope := (point.y - pi.y) / (pj.y - pi.y)
			var x_intersect := pi.x + slope * (pj.x - pi.x)
			if point.x < x_intersect:
				inside = not inside
		j = i
	return inside

## 엣지 방향에서 지형 안쪽을 향하는 법선을 구함.
## ▼ 2026-06-29 (버그수정 3차): 기존엔 fallback(총알 진입 방향)과의 내적 부호로만 안/밖을
##   판단했는데, 총알이 표면에 거의 평행하게(스치듯) 맞으면 이 부호 판정이 불안정해서
##   가끔 반대로 뒤집혔다 → 페인트가 지형 밖(빈 공간, 텍스처 알파 0)에 찍혀 안 보이는
##   원인이었다(stage_2 동굴). 폴리곤이 닫혀 있으면 '점이 실제로 폴리곤 안에 있는지'를
##   직접 테스트해서 훨씬 안정적으로 방향을 정한다. 열린 체인(SEGMENTS)은 안/밖 개념이
##   없으므로 기존 fallback 내적 방식을 그대로 쓴다.
func _normal_for_edge(edge_dir: Vector2, fallback: Vector2,
		surface_point: Vector2 = Vector2.INF, world_pts: PackedVector2Array = PackedVector2Array()) -> Vector2:
	var normal := Vector2(-edge_dir.y, edge_dir.x)
	if not world_pts.is_empty() and surface_point.is_finite():
		var probe := surface_point + normal * 2.0
		if not _point_in_polygon(probe, world_pts):
			normal = -normal
		return normal
	if normal.dot(fallback) < 0.0:
		normal = -normal
	return normal

## 탄착점에서 가장 가까운 폴리곤 엣지 위의 '실제 표면 접점'과 그 법선을 함께 반환.
## fallback(총알 방향)과 같은 방향인 법선을 선택 → 지형 안쪽을 향하도록 보정.
## ▼ 2026-06-29: 탄착점이 꼭짓점(엣지의 끝) 근처면 인접 엣지의 법선과 블렌딩해
##   "어느 엣지가 더 가깝냐"에 따라 법선이 툭 끊겨 튀는 현상(코너 스냅)을 줄인다.
## ▼ 2026-06-29 (버그수정 2차): 단순히 법선만 반환하면 호출 쪽에서 이미 폴리곤 안쪽으로
##   파고든 impact_pos 를 기준점으로 써서 깊이가 누적되는 문제가 있었다. 표면 위의
##   '투영점(point)'을 같이 돌려줘서, 그 점을 기준으로만 깊이를 더하도록 한다.
func _project_to_surface(polygon: PackedVector2Array,
		terrain_xform: Transform2D,
		impact_pos: Vector2,
		fallback: Vector2,
		closed: bool = true) -> Dictionary:
	var n := polygon.size()
	if n < 2:
		return {"point": impact_pos, "normal": fallback}

	# ▼ 2026-06-29: build_mode=1(SEGMENTS, 열린 선)은 마지막 점과 첫 점을 잇지 않는다.
	#   강제로 닫으면 존재하지 않는 가짜 변이 "가장 가까운 변"으로 잘못 뽑힐 수 있다
	#   (stage_2 동굴에서 마크가 엉뚱한 곳에 생기던 원인).
	var edge_count := n if closed else n - 1
	if edge_count < 1:
		return {"point": impact_pos, "normal": fallback}

	var edge_dirs: Array[Vector2] = []
	edge_dirs.resize(edge_count)

	var best_i := -1
	var best_t := 0.0
	var best_edge_len := 0.0
	var best_a := Vector2.ZERO
	var closest_dist := INF

	for i in edge_count:
		var a: Vector2 = terrain_xform * polygon[i]
		var b: Vector2 = terrain_xform * polygon[(i + 1) % n]
		var edge    := b - a
		var edge_len := edge.length()
		if edge_len < 0.001:
			edge_dirs[i] = Vector2.ZERO
			continue
		var edge_dir := edge / edge_len
		edge_dirs[i] = edge_dir

		var t    := clampf((impact_pos - a).dot(edge_dir), 0.0, edge_len)
		var dist := (impact_pos - (a + edge_dir * t)).length()
		if dist < closest_dist:
			closest_dist  = dist
			best_i        = i
			best_t        = t
			best_edge_len = edge_len
			best_a        = a

	if best_i == -1:
		return {"point": impact_pos, "normal": fallback}

	# 닫힌 폴리곤이면 점-내부 판정용 월드 좌표 배열을 한 번만 만들어 둔다.
	var world_pts := PackedVector2Array()
	if closed:
		world_pts.resize(n)
		for i in n:
			world_pts[i] = terrain_xform * polygon[i]

	var surface_point: Vector2 = best_a + edge_dirs[best_i] * best_t
	var normal := _normal_for_edge(edge_dirs[best_i], fallback, surface_point, world_pts)

	# 꼭짓점까지 남은 거리 (엣지 양 끝 중 가까운 쪽). 열린 선의 양 끝(체인의 시작/끝)은
	# 블렌딩할 인접 변이 없으므로 건너뛴다.
	var dist_to_vertex := minf(best_t, best_edge_len - best_t)
	var blend_radius    := minf(best_edge_len * 0.3, 20.0)
	if blend_radius > 0.001 and dist_to_vertex < blend_radius:
		var prev_ok := closed or best_i > 0
		var next_ok := closed or best_i < edge_count - 1
		var to_prev := best_t < best_edge_len * 0.5
		if (to_prev and prev_ok) or (not to_prev and next_ok):
			var adj_i := (best_i - 1 + edge_count) % edge_count if to_prev else (best_i + 1) % edge_count
			if edge_dirs[adj_i] != Vector2.ZERO:
				var adj_normal := _normal_for_edge(edge_dirs[adj_i], fallback, surface_point, world_pts)
				var w := 1.0 - dist_to_vertex / blend_radius   # 꼭짓점일수록 1.0
				normal = (normal * (1.0 - w) + adj_normal * w).normalized()

	return {"point": surface_point, "normal": normal}

## ▼ 2026-06-29 신규: 폴리곤(충돌체)이 없는 텍스처 전용 표면에서, 그림의 알파 그라디언트로
##   법선을 근사한다. (예: stage_1 처럼 비주얼만 있고 충돌은 별도 박스로 처리되는 지형)
##   알파가 진해지는 방향 = 지형 안쪽 → fallback과 내적이 음수면 반전.
static var _alpha_image_cache: Dictionary = {}

func _get_cached_image(tex: Texture2D) -> Image:
	if _alpha_image_cache.has(tex):
		return _alpha_image_cache[tex]
	var img := tex.get_image()
	if img:
		_alpha_image_cache[tex] = img
	return img

func _alpha_at(img: Image, px: Vector2i, size: Vector2i) -> float:
	if px.x < 0 or px.y < 0 or px.x >= size.x or px.y >= size.y:
		return 0.0
	return img.get_pixelv(px).a

func _normal_from_texture_alpha(sprite: Sprite2D, world_pos: Vector2, fallback: Vector2) -> Vector2:
	var img := _get_cached_image(sprite.texture)
	if img == null:
		return fallback

	var tex_size: Vector2 = sprite.texture.get_size()
	var local: Vector2 = sprite.to_local(world_pos)
	var top_left: Vector2 = (sprite.offset - tex_size * 0.5) if sprite.centered else sprite.offset
	var px := local - top_left

	var size_i := Vector2i(tex_size)
	var step := 4
	var p := Vector2i(px)
	var gx := _alpha_at(img, p + Vector2i(step, 0), size_i) - _alpha_at(img, p - Vector2i(step, 0), size_i)
	var gy := _alpha_at(img, p + Vector2i(0, step), size_i) - _alpha_at(img, p - Vector2i(0, step), size_i)
	var grad_local := Vector2(gx, gy)
	if grad_local.length() < 0.01:
		return fallback

	# 로컬(텍스처) 공간의 그라디언트를 월드 방향으로 회전만 적용해 변환
	var dir_world: Vector2 = sprite.global_transform.basis_xform(grad_local).normalized()
	if dir_world.dot(fallback) < 0.0:
		dir_world = -dir_world
	return dir_world

func _safe_free() -> void:
	if is_inside_tree():
		queue_free()
