@tool
extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 샹들리에 함정 — 레버 패턴이 틀리면 머리 위로 떨어진다
## ----------------------------------------------------------------------------
## ▣ 도형님 아이디어(10-09): "잘못된 패턴일 때 함정이 발동되어서 위에 샹들리에가 떨어진다
##   (떨어진 후에 플레이어는 죽음 처리한다. 그리고 함정도 다시 되돌아간다)"
## ▣ 한 바퀴
##   매달림 → `떨어뜨리기()` → 0.6초 예고(삐걱 · 사슬이 흔들리고 수정 장식이 떨린다) → 떨어짐(중력 가속) →
##   바닥에 부딪혀 산산조각(수정 조각 · 먼지 · 화면 흔들림) → 그 아래 있던 몸은 즉사(색 무관 · hazard) →
##   부활하면(월드 `_리스폰` → "부활복구" 그룹) 천장으로 되돌아가 다시 매달린다. 피했으면 2.5초 뒤 스스로 끌려 올라간다.
## ▣ 왜 0.6초 예고인가: "떨어지면 죽는다" 는 도형님 말대로 하되, 예고가 없으면 **이유를 모르고** 죽는다(색 규칙과 같은
##   원칙 — '왜 죽었는지 읽혀야 한다'). 레버 받침대는 좁고 샹들리에가 그 폭을 다 덮게 놓아(도안) 실제로는 거의 못 피한다.
## ▣ 그림: 배경 가구 원화 `샹들리에.png`(쳅터1 레이어_v01) 를 쓴다 — 거실·식당 천장의 그 샹들리에가 떨어진다.
##   사슬은 코드 선. 원점 = 천장 고정점. `늘어짐` = 고정점에서 샹들리에 위끝까지(px).
## ============================================================================

const 그림 := "res://assets/background/쳅터1/레이어_v01/가구/샹들리에.png"

@export var 폭: float = 192.0                     ## 게임에서 보이는 폭(px) — 원화 비율 그대로 키를 정한다
@export var 늘어짐: float = 96.0
@export var 예고: float = 0.6
## 피했을 때 스스로 끌려 올라가기까지(초). 0 이면 부활 때만.
@export var 스스로_복구: float = 2.5

signal 끝남                                       ## 떨어져 부서진 뒤(퍼즐이 레버를 되돌릴 때 쓴다)

enum 상태 { 매달림, 예고, 떨어짐, 부서짐, 올라감 }
var 지금: 상태 = 상태.매달림
var _t := 0.0
var _y := 0.0                 ## 매달린 자리에서 아래로 내려간 거리
var _속도 := 0.0
var _바닥 := 400.0            ## 떨어질 거리(고정점 기준) — 실행 때 아래로 레이를 쏴 잰다
var _판정: Area2D
var _텍스처: Texture2D
var _흔들 := 0.0


func _ready() -> void:
	_텍스처 = load(그림) if ResourceLoader.exists(그림) else null
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group("부활복구")
	_판정 = Area2D.new()
	_판정.collision_layer = 0
	_판정.collision_mask = 1
	_판정.monitorable = false
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(폭 * 0.85, _키() * 0.7)
	c.shape = r
	_판정.add_child(c)
	add_child(_판정)
	_판정.monitoring = false
	_판정.add_to_group("hazard")
	_바닥_재기.call_deferred()


func _키() -> float:
	if _텍스처 == null:
		return 120.0
	return 폭 * float(_텍스처.get_height()) / float(_텍스처.get_width())


func _바닥_재기() -> void:
	await get_tree().physics_frame
	var 시작 := global_position + Vector2(0, 늘어짐 + _키() + 4)
	var q := PhysicsRayQueryParameters2D.create(시작, 시작 + Vector2(0, 3000), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_바닥 = (Vector2(hit["position"]).y - 시작.y) if not hit.is_empty() else 600.0


func 떨어뜨리기() -> void:
	if 지금 != 상태.매달림:
		return
	지금 = 상태.예고
	_t = 0.0


func 매달려있나() -> bool:
	return 지금 == 상태.매달림


func 부활_복구() -> void:
	지금 = 상태.매달림
	_y = 0.0
	_속도 = 0.0
	_판정.set_deferred("monitoring", false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	match 지금:
		상태.매달림:
			return
		상태.예고:
			_흔들 = sin(_t * 45.0) * 3.0 * (_t / 예고)
			if _t >= 예고:
				지금 = 상태.떨어짐
				_t = 0.0
				_흔들 = 0.0
				_판정.monitoring = true
		상태.떨어짐:
			_속도 += 2600.0 * delta
			_y += _속도 * delta
			if _y >= _바닥:
				_y = _바닥
				지금 = 상태.부서짐
				_t = 0.0
				_부딪힘()
		상태.부서짐:
			if _t > 0.15:
				_판정.monitoring = false
			if 스스로_복구 > 0.0 and _t >= 스스로_복구:
				지금 = 상태.올라감
				_t = 0.0
		상태.올라감:
			_y = maxf(_y - 520.0 * delta, 0.0)
			if _y <= 0.0:
				지금 = 상태.매달림
				끝남.emit()
	_판정.position = Vector2(_흔들, 늘어짐 + _y + _키() * 0.5)
	queue_redraw()


func _부딪힘() -> void:
	var 카메라 := get_tree().get_first_node_in_group("주카메라")
	if 카메라 and 카메라.has_method("add_trauma"):
		카메라.add_trauma(0.45)
	# 수정 조각 — 밝은 점이 사방으로 튄다
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 28
	p.lifetime = 0.9
	p.position = Vector2(0, 늘어짐 + _y + _키() * 0.85)
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.85, 0.84, 0.80, 0.9)
	p.z_index = 6
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _draw() -> void:
	var 위 := Vector2(_흔들, 늘어짐 + _y)
	# 사슬 — 매달려 있는 동안만(떨어지면 끊어져 위에 짧게 남는다)
	var 사슬끝 := 위 if 지금 in [상태.매달림, 상태.예고, 상태.올라감] else Vector2(0, 늘어짐 * 0.35)
	var 칸수 := int(사슬끝.length() / 9.0)
	for k in 칸수:
		var a := Vector2.ZERO.lerp(사슬끝, (float(k) + 0.5) / float(maxi(칸수, 1)))
		draw_arc(a, 3.4, 0, TAU, 10, Color(0.35, 0.33, 0.30), 1.8)
	if _텍스처:
		var 크기 := Vector2(폭, _키())
		var 기울기 := 0.0
		if 지금 == 상태.부서짐:
			기울기 = 0.18
		draw_set_transform(위 + Vector2(0, 크기.y * 0.5), 기울기, Vector2.ONE)
		var 색 := Color(0.85, 0.85, 0.85) if 지금 != 상태.부서짐 else Color(0.55, 0.55, 0.55)
		draw_texture_rect(_텍스처, Rect2(-크기 * 0.5, 크기), false, 색)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(위 + Vector2(0, 40), 40.0, Color(0.6, 0.6, 0.6))
	if Engine.is_editor_hint():
		# 에디터: 떨어질 폭을 표시(레버 받침대를 덮는지 보려고)
		draw_rect(Rect2(Vector2(-폭 * 0.425, 늘어짐), Vector2(폭 * 0.85, 600)), Color(1, 0.3, 0.2, 0.15))
