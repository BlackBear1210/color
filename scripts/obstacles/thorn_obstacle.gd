@tool
extends Area2D
## 가시(Thorn) 장애물 — 닿으면 즉시 사망. 색과 무관하게 모두 위험.
## 이미지의 알파 모양 그대로 사망 판정 영역이 자동 생성된다.
##
## ◆ 사용법(에디터)
##   1) 이 씬(ThornObstacle)을 스테이지에 인스턴스
##   2) 인스펙터의 Thorn Texture 에 가시 PNG 드래그
##   3) "Bake Collision" 체크 → 가시 모양대로 판정 영역 자동 생성
##   ※ Bake 없이 실행해도 런타임에 자동으로 판정 영역이 생성된다.

@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5
@export_range(0.5, 20.0, 0.5) var simplify: float = 3.0

## 스테이지 tscn 에서 직접 지정하는 가시 텍스처.
## 값을 설정하면 자식 Sprite2D 에 자동 적용, 에디터에서는 충돌도 자동 재굽는다.
@export var thorn_texture: Texture2D:
	set(value):
		thorn_texture = value
		var spr := get_node_or_null("Sprite2D") as Sprite2D
		if spr:
			spr.texture = thorn_texture
		# 에디터에서 텍스처를 바꾸면 충돌도 즉시 다시 구움
		if Engine.is_editor_hint() and value != null and is_inside_tree():
			_bake()

@export var bake_collision: bool = false:
	set(value):
		bake_collision = false
		if Engine.is_editor_hint():
			_bake()


func _ready() -> void:
	# Area2D 설정: 플레이어(layer1)만 감지, 자신은 감지 대상 아님
	collision_layer = 0
	collision_mask  = 1
	monitoring      = true
	monitorable     = false

	if Engine.is_editor_hint():
		return

	# thorn_texture 가 설정된 경우 Sprite2D 에 적용
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr and thorn_texture and spr.texture == null:
		spr.texture = thorn_texture

	# 총알이 가시에 닿아도 PaintMark 가 생기지 않도록 차단
	add_to_group("obstacle")
	body_entered.connect(_on_body_entered)

	# 충돌 폴리곤이 없으면 런타임에 자동 생성
	_bake_if_missing()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# 물리 콜백 내 직접 die() 는 flush 오류 → call_deferred 필수
		body.call_deferred("die")


## 런타임에 auto_baked 충돌이 없을 때만 생성 (에디터 Bake 우선)
func _bake_if_missing() -> void:
	# 이미 충돌 폴리곤이 있으면 건너뜀
	for c in get_children():
		if c is CollisionPolygon2D and c.has_meta("auto_baked"):
			return
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		push_warning("ThornObstacle '%s': thorn_texture 가 설정되지 않았습니다." % name)
		return
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, null)
	if n == 0:
		push_warning("ThornObstacle '%s': 런타임 충돌 생성 실패 — 텍스처 import 를 확인하세요." % name)


# ── 판정 영역 자동 생성 (에디터 전용) ────────────────────────────
func _bake() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var root := get_tree().edited_scene_root if Engine.is_editor_hint() else null
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, root)
	if n == 0:
		push_warning("ThornObstacle '%s': 판정 영역 생성 실패 — Sprite2D 텍스처/알파를 확인하세요." % name)
	else:
		print("ThornObstacle '%s': 폴리곤 %d개 생성 완료." % [name, n])
