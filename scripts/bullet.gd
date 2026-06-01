extends Area2D
## 페인트 총알.
## 인스펙터의 Speed / Bullet Gravity 를 조절해 포물선 강도를 바꿀 수 있다.
##
## [충돌 처리]
##   · paint_bodies 그룹  → 기존 PaintMark 색 덮어씌우기
##   · obstacle 그룹      → 페인트 생성 없이 소멸 (가시 등 장애물)
##   · 그 외 지형         → PaintSplat 이펙트 + 새 PaintMark 생성

# ── 인스펙터 조절 파라미터 ────────────────────────────────────────────
@export var speed: float          = 1400.0   # 발사 초기 속도 (px/s)
@export var bullet_gravity: float = 600.0    # 중력 가속도 (px/s²). 0 이면 직선 비행.

# ── 런타임 변수 ───────────────────────────────────────────────────────
var direction:    Vector2 = Vector2.RIGHT    # 발사 방향 (단위 벡터)
var bullet_color: int     = ColorDefs.WHITE  # 총알 색 (player.gd 에서 설정)

const PAINT_MARK  := preload("res://scenes/effects/PaintMark.tscn")
const PAINT_SPLAT := preload("res://scenes/effects/PaintSplat.tscn")

var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_velocity = direction * speed

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

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("paint_bodies"):
		# 이미 페인트가 있는 자리 → 색만 덮어씌우기 (Node2D라 body_entered 는 안 잡힘,
		# 아래 _spawn_mark 의 40px 제거 로직이 담당)
		body.call_deferred("update_color", bullet_color)
	elif not body.is_in_group("obstacle"):
		# 빈 지형 → 순간 스플래시 이펙트 + 영구 페인트 마크 생성
		_spawn_splat()
		_spawn_mark()
	_safe_free()

## 순간 스플래시 이펙트: 0.22초 후 자동 삭제
func _spawn_splat() -> void:
	var splat := PAINT_SPLAT.instantiate()
	splat.set_color(bullet_color)
	splat.global_position = global_position
	# PaintOverlay 하위에 추가 (없으면 루트 씬)
	var overlay := get_tree().current_scene.find_child("PaintOverlay", true, false)
	var parent: Node = overlay if overlay else get_tree().current_scene
	parent.call_deferred("add_child", splat)

## 영구 페인트 자국: "runtime_paint" 그룹 → 리스폰 시 일괄 제거
func _spawn_mark() -> void:
	var pos: Vector2 = global_position + direction * 6.0

	# 반경 40px 내 기존 페인트 제거 → 한 지점에 한 겹만 칠해지는 느낌
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		if p.global_position.distance_to(pos) < 40.0:
			p.queue_free()

	var mark := PAINT_MARK.instantiate()
	mark.paint_color     = bullet_color
	mark.global_position = pos

	var overlay := get_tree().current_scene.find_child("PaintOverlay", true, false)
	var parent: Node = overlay if overlay else get_tree().current_scene
	parent.call_deferred("add_child", mark)

func _safe_free() -> void:
	if is_inside_tree():
		queue_free()
