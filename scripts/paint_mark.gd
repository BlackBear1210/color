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

# ▼ 2026-06-28: 텍스처(비주얼) 알파 클리핑용 데이터.
#   _clip_tex 가 설정되면 폴리곤 대신 '지형 그림의 알파'에 맞춰 페인트를 오린다(우선 적용).
const CLIP_TEX_SHADER = preload("res://shaders/paint_clip_alpha.gdshader")
var _clip_tex: Texture2D     = null
var _clip_inv: Transform2D   = Transform2D.IDENTITY   # 월드→지형로컬 역변환
var _clip_tex_size: Vector2  = Vector2.ONE
var _clip_tex_offset: Vector2 = Vector2.ZERO
var _clip_centered: bool     = true

# ▼ 2026-06-28 신규: '분사(스프레이) 페인트' 절차적 비주얼.
#   [왜?] 기존엔 미리 그린 splat PNG 한 장을 찍어 '이미지 덧씌움'처럼 보였다(사용자 피드백).
#   [원리] 총알의 페인트가 지형에 닿아 '흩뿌려지는' 느낌 → 중심 블롭 + 흩어진 물방울 다발 + 흘러내림(드립)을
#          코드로 매번 다르게 생성하고, 지형 텍스처 알파에 클립해 그림 위에만 칠해지게 한다.
const SURFACE_LOCAL: float = -SPAWN_DEPTH    # 지형 표면이 mark 루트-로컬에서 y=-SPAWN_DEPTH 에 위치
var _spray: Node2D = null                    # 물방울들을 담는 컨테이너(재색칠/정리 편의)
static var _droplet_tex: Texture2D = null    # 부드러운 원형 물방울 텍스처(공유 캐시)

## 부드러운 원형 물방울 텍스처를 1회 생성해 캐시(모든 페인트가 공유).
static func _get_droplet_tex() -> Texture2D:
	if _droplet_tex != null:
		return _droplet_tex
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz * 0.5, sz * 0.5)
	for y in sz:
		for x in sz:
			var dist: float = Vector2(x, y).distance_to(c) / (sz * 0.5)
			# ▼ 2026-06-28: 코어는 '꽉 찬' 불투명, 가장자리만 부드럽게.
			#   (이전엔 전체가 흐릿해 여러 물방울이 겹쳐도 검은 틈이 보이는 듬성듬성 느낌이었음)
			var a: float = clampf((1.0 - dist) * 2.4, 0.0, 1.0)   # 안쪽 ~58% 완전 불투명
			a = smoothstep(0.0, 1.0, a)                           # 림만 부드럽게
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_droplet_tex = ImageTexture.create_from_image(img)
	return _droplet_tex

# ── bullet.gd 에서 add_child 전에 호출 ───────────────────────────────
## 지형의 CollisionPolygon2D 꼭짓점을 월드 좌표로 변환해 저장 (폴리곤 클리핑 — 비주얼 텍스처가 없을 때 폴백)
func setup_terrain_clip(polygon: PackedVector2Array, terrain_xform: Transform2D) -> void:
	_clip_polygon = PackedVector2Array()
	for v in polygon:
		_clip_polygon.append(terrain_xform * v)

## ▼ 2026-06-28 신규: 지형 '비주얼(Sprite2D 텍스처 알파)'에 맞춰 페인트를 오리도록 설정.
##   충돌폴리곤과 무관하게 그림 위에만 정확히 칠해진다(권장 경로).
func setup_terrain_clip_tex(tex: Texture2D, sprite_global_xform: Transform2D,
		tex_size: Vector2, centered: bool, offset: Vector2) -> void:
	_clip_tex        = tex
	_clip_inv        = sprite_global_xform.affine_inverse()
	_clip_tex_size   = tex_size
	_clip_centered   = centered
	_clip_tex_offset = offset

func _ready() -> void:
	add_to_group("runtime_paint")
	add_to_group("paint_bodies")

	# ▼ 2026-06-29: 일부 스테이지(예: stage_2 동굴)는 지형 StaticBody 가 자체 Sprite2D를
	#   들고 있고, 그 바디가 PaintOverlay 보다 트리 상 나중에(=위에) 그려져서 페인트가
	#   지형 그림에 덮여 가려지는 문제가 있었다. z_index 를 지형보다 확실히 높게 고정해
	#   씬 트리 순서와 무관하게 항상 지형 그림 위에 그려지도록 한다.
	z_index = 10
	z_as_relative = false

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
	# ▼ 2026-06-28: 분사 물방울 컨테이너 생성(스탬프 대신 이게 비주얼 담당)
	_spray = Node2D.new()
	add_child(_spray)
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

	# 인스펙터의 rect.size.y 값을 그대로 사용
	# zone 중심 = surface_local - rect.size.y / 2 → 윗변이 표면에 닿음
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
		# ▼ 2026-06-28: 미리 그린 스탬프 PNG 는 '숨기고'(분사 비주얼은 _build_spray 가 담당),
		#   선택된 스프라이트의 JudgmentZone(색 사망 판정)만 살린다.
		#   self_modulate.a=0 → 스탬프는 안 그려지지만 자식 JudgmentZone(Area2D) 판정은 그대로 동작.
		sprite.visible = is_picked
		sprite.self_modulate.a = 0.0

		var zone := sprite.get_node_or_null("JudgmentZone") as Area2D
		if zone:
			zone.monitorable = is_picked

	# ▼ 2026-06-28: 절차적 분사 비주얼 생성(중심 블롭+흩뿌림+드립), 지형 알파에 클립
	_build_spray(c)

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

## ▼ 2026-06-28 신규: 선택된 Sprite2D 에 '텍스처 알파' 클리핑 쉐이더 설정.
func _apply_clip_shader_tex(sprite: Sprite2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = CLIP_TEX_SHADER
	mat.set_shader_parameter("terrain_tex", _clip_tex)
	mat.set_shader_parameter("inv_x",      _clip_inv.x)
	mat.set_shader_parameter("inv_y",      _clip_inv.y)
	mat.set_shader_parameter("inv_o",      _clip_inv.origin)
	mat.set_shader_parameter("tex_size",   _clip_tex_size)
	mat.set_shader_parameter("tex_offset", _clip_tex_offset)
	mat.set_shader_parameter("centered",   1.0 if _clip_centered else 0.0)
	mat.set_shader_parameter("alpha_cut",  0.25)   # ▼ 2026-06-28: 반투명 가장자리도 포함되게 낮춤
	mat.set_shader_parameter("enabled",    1)
	sprite.material = mat

## ▼ 2026-06-28 신규: 분사(스프레이) 페인트 비주얼을 절차적으로 생성.
##   표면(SURFACE_LOCAL) 근처에 중심 블롭 + 흩뿌려진 물방울 + 흘러내림(드립)을 만든다.
##   매번 무작위라 같은 패턴이 반복되지 않음 → '뿌려진' 느낌. 지형 알파에 클립되어 그림 위에만 칠해짐.
func _build_spray(c: int) -> void:
	if _spray == null:
		return
	for ch in _spray.get_children():
		ch.queue_free()
	var col := Color(1, 1, 1, 1) if c == ColorDefs.WHITE else Color(0, 0, 0, 1)

	# ▼ 2026-06-29 (재수정): 두꺼운/불투명한 벽 텍스처는 알파 클립이 깊이를 막아주지 못해
	#   블롭이 SURFACE_LOCAL(-25)보다 한참 안쪽(+20~80px)까지 퍼지면 "벽 속에 칠해진" 것처럼
	#   보였다. → 모든 블롭을 SURFACE_LOCAL 기준 가까운 범위로 당겨와 표면 위주로만 칠한다.

	# ① 단단한 중심 패치 — 큰 블롭 4~5개를 가까이 겹쳐 '꽉 찬' 칠해진 영역을 만든다(직관적 가시성).
	var core := randi_range(4, 5)
	for i in core:
		var cx := randf_range(-16.0, 16.0)
		var cy := SURFACE_LOCAL + randf_range(-4.0, 14.0)  # 표면 바로 위~14px 안쪽
		_add_drop(col, Vector2(cx, cy), randf_range(0.42, 0.62), 1.0)

	# ② 중간 물방울 — 패치 주변을 메워 경계를 자연스럽게
	for i in randi_range(5, 8):
		var mx := randf_range(-1.0, 1.0)
		var ox := mx * mx * signf(mx) * 42.0
		var oy := SURFACE_LOCAL + randf_range(-8.0, 20.0)
		_add_drop(col, Vector2(ox, oy), randf_range(0.16, 0.30), randf_range(0.9, 1.0))

	# ③ 분사 흩뿌림 — 바깥으로 튄 작은 방울(스프레이 느낌)
	for i in randi_range(7, 11):
		var rr := randf_range(-1.0, 1.0)
		var sx := rr * rr * signf(rr) * 66.0
		var sy := SURFACE_LOCAL + randf_range(-12.0, 26.0)
		_add_drop(col, Vector2(sx, sy), randf_range(0.05, 0.12), randf_range(0.8, 1.0))

	# ④ 흘러내림(드립) 2~3개 — 표면 근처에서 시작해 중력 방향(월드 수직)으로 길게
	for i in randi_range(2, 3):
		var drip := _add_drop(col, Vector2(randf_range(-30.0, 30.0), SURFACE_LOCAL + randf_range(0.0, 8.0)), randf_range(0.09, 0.14), 0.95)
		drip.rotation = -rotation                          # 루트 회전 상쇄 → 항상 월드 수직(중력)
		drip.scale.y *= randf_range(2.0, 3.5)              # 세로로 길게(과도하게 깊이 들어가지 않게 축소)

## 물방울 1개 생성(지형 텍스처 알파가 있으면 그에 클립). 생성한 Sprite2D 반환.
func _add_drop(col: Color, pos: Vector2, sc: float, a: float) -> Sprite2D:
	var d := Sprite2D.new()
	d.texture  = _get_droplet_tex()
	d.position = pos
	d.scale    = Vector2(sc, sc)
	d.modulate = Color(col.r, col.g, col.b, a)
	# ▼ 2026-06-28: 지형 그림(텍스처)이 있으면 알파 클립, 없으면(기하 발판) 폴리곤 클립으로 블록 밖 삐짐 방지.
	if _clip_tex != null:
		_apply_clip_shader_tex(d)
	elif not _clip_polygon.is_empty():
		_apply_clip_shader(d)
	_spray.add_child(d)
	return d

## 페인트가 튀겼다가 스며드는 애니메이션
func _play_splat_tween() -> void:
	# rotation = 으로 덮어쓰지 않고 += 로 미세 랜덤 추가 (표면 정렬 유지)
	rotation  += randf_range(-0.15, 0.15)
	scale      = Vector2(1.4, 1.4)
	modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale",      Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0,         0.14)
