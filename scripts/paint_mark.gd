extends Node2D
## 총알이 지형에 남긴 페인트 자국.
##
## ▸ Node2D 기반: 물리 충돌(StaticBody) 없음
## ▸ "runtime_paint" 그룹: 플레이어 리스폰 시 player.gd 가 이 그룹 전체를 queue_free()
## ▸ 각 스프라이트(B1~B4, W1~W4)의 JudgmentZone: ColorSensor 가 색 판정에 사용
## ▸ 쉐이더 클리핑: 지형 폴리곤 바깥 픽셀 discard

@export var paint_color: int = ColorDefs.WHITE

# bullet.gd 에서 add_child 전에 설정
var impact_direction: Vector2 = Vector2.DOWN

# mark 중심이 지형 표면에서 얼마나 깊이 박히는지 (bullet.gd 의 * 25.0 과 일치)
const SPAWN_DEPTH := 25.0

# 물리 레이어 (player.gd 와 일치)
const LAYER_BLACK: int = 1 << 1   # layer 2
const LAYER_WHITE: int = 1 << 2   # layer 3

var _static_body: StaticBody2D = null

@onready var _black_mark: Node2D = $BlackMark
@onready var _white_mark: Node2D = $WhiteMark

# 지형 폴리곤 (월드 좌표계로 변환된 꼭짓점)
var _clip_polygon: PackedVector2Array = PackedVector2Array()

const CLIP_SHADER = preload("res://shaders/paint_clip.gdshader")

# ── bullet.gd 에서 add_child 전에 호출 ───────────────────────────────
## 지형의 CollisionPolygon2D 꼭짓점을 월드 좌표로 변환해 저장
func setup_terrain_clip(polygon: PackedVector2Array, terrain_xform: Transform2D) -> void:
	_clip_polygon = PackedVector2Array()
	for v in polygon:
		_clip_polygon.append(terrain_xform * v)

func _ready() -> void:
	add_to_group("runtime_paint")
	add_to_group("paint_bodies")

	# ① 루트를 지형 표면 각도에 맞춰 먼저 회전 (local +Y = 지형 방향)
	rotation = impact_direction.angle() - PI / 2.0

	# ② JudgmentZone 등록 + 로컬 공간 기준 표면 정렬
	for group_node in [_black_mark, _white_mark]:
		for sprite in group_node.get_children():
			var zone := sprite.get_node_or_null("JudgmentZone") as Area2D
			if zone:
				zone.add_to_group("paint_marks")
			_align_zone_to_surface(sprite as Sprite2D)

	_create_collision_body()
	_apply(paint_color)
	_play_splat_tween()

## 각 Sprite2D 의 JudgmentZone 위치·회전을 impact_direction 기반으로 정렬.
## 윗변이 지형 표면에 딱 닿도록 계산.
func _align_zone_to_surface(sprite: Sprite2D) -> void:
	if not sprite:
		return
	var zone := sprite.get_node_or_null("JudgmentZone") as Area2D
	if not zone:
		return
	var cs := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not cs or not (cs.shape is RectangleShape2D):
		return

	var rect := cs.shape as RectangleShape2D
	var s    := sprite.scale.x  # 0.13

	# Sprite2D 로컬 좌표계에서의 zone 중심 위치:
	#   surface_local = -SPAWN_DEPTH / s  (지형 표면까지 로컬 거리)
	#   zone 중심 = surface_local + rect.size.y / 2  (윗변이 표면에 닿도록)
	# 루트가 이미 surface_angle 로 회전된 상태이므로
	# 로컬 공간에서 "지형 방향" = Vector2.DOWN (항상 고정)
	var surface_local := -SPAWN_DEPTH / s
	zone.position = Vector2(0.0, surface_local - rect.size.y / 2.0)

	# CollisionShape2D 오프셋 초기화
	cs.position = Vector2.ZERO

	# 루트 회전이 이미 표면 정렬을 담당하므로 zone 자체 rotation 은 0
	zone.rotation = 0.0

## 페인트 색에 맞는 물리 충돌체를 동적으로 생성 (플레이어가 올라설 수 있도록)
func _create_collision_body() -> void:
	_static_body = StaticBody2D.new()
	_static_body.add_to_group("paint_bodies")

	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80.0, 10.0)
	cs.shape = rect
	# 상단이 지형 표면(local Y = -SPAWN_DEPTH)에 닿도록 중심을 5px 안쪽으로
	cs.position = Vector2(0.0, -SPAWN_DEPTH + 5.0)

	_static_body.add_child(cs)
	add_child(_static_body)
	_update_collision_layer()

## 페인트 색에 따라 충돌 레이어 갱신 (흰 페인트 → LAYER_WHITE, 검정 → LAYER_BLACK)
func _update_collision_layer() -> void:
	if _static_body == null:
		return
	_static_body.collision_layer = LAYER_WHITE if paint_color == ColorDefs.WHITE else LAYER_BLACK
	_static_body.collision_mask  = 0

## 같은 자리에 다시 쐈을 때 색만 덮어씀 (bullet.gd → call_deferred)
func update_color(new_color: int) -> void:
	paint_color = new_color
	_apply(paint_color)
	_play_splat_tween()
	_update_collision_layer()

## 색에 맞는 그룹만 보이고, 그 안에서 랜덤 1개 선택 + 쉐이더 적용
func _apply(c: int) -> void:
	_black_mark.visible = (c == ColorDefs.BLACK)
	_white_mark.visible = (c == ColorDefs.WHITE)

	var group: Node2D = _black_mark if c == ColorDefs.BLACK else _white_mark
	var sprites := group.get_children()
	var pick: int = randi() % sprites.size()

	for i in sprites.size():
		var sprite := sprites[i] as Sprite2D
		var is_picked := (i == pick)
		sprite.visible = is_picked

		# 선택된 스프라이트에만 클리핑 쉐이더 적용
		if is_picked and not _clip_polygon.is_empty():
			_apply_clip_shader(sprite)

		# 선택된 스프라이트의 JudgmentZone만 활성화
		var zone := sprite.get_node_or_null("JudgmentZone") as Area2D
		if zone:
			zone.monitorable = is_picked

## 선택된 Sprite2D 에 폴리곤 클리핑 쉐이더 설정
func _apply_clip_shader(sprite: Sprite2D) -> void:
	# 쉐이더 uniform 용 배열: 항상 MAX_VERTS(100)개로 패딩
	var verts := PackedVector2Array()
	verts.resize(100)
	var count := mini(_clip_polygon.size(), 100)
	for i in count:
		verts[i] = _clip_polygon[i]

	var mat := ShaderMaterial.new()
	mat.shader = CLIP_SHADER
	mat.set_shader_parameter("vert_count", count)
	mat.set_shader_parameter("polygon",    verts)
	sprite.material = mat

## 페인트가 튀겼다가 스며드는 애니메이션
func _play_splat_tween() -> void:
	# rotation = 으로 덮어쓰지 않고 += 로 미세 랜덤 추가 (표면 정렬 유지)
	rotation  += randf_range(-0.15, 0.15)
	scale      = Vector2(1.4, 1.4)
	modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale",      Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0,         0.14)
