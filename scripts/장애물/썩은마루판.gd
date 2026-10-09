@tool
extends StaticBody2D
## ============================================================================
## [2026-10-09 Claude 신규] 썩은 마루판 — 쳅터1(집)의 부서지는 발판 한 장(96×32 · 3칸)
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-F (v3 확정 규칙) · 카드 5(마루판 4상태 원화)
##   · 밟음 → 삐걱 + 먼지 → 금 1(0.3초) → 금 2·처짐(0.6초) → 0.9초에 부서져 조각이 떨어진다.
##   · 칠해도 아무 변화 없음(물감으로 보강 불가 — 이 판은 페인트 대상이 아니다 · 총알은 그냥 막힌다).
##   · 저절로 복구되지 않는다. 플레이어가 죽어 부활할 때만 복구(월드.gd `_리스폰` → "붕괴발판" 그룹 `부활_복구()`).
##   · 레벨 규칙: 아래는 반드시 낙사·가시·반대색(못 건너면 죽는다 → 죽으면 초기화) — 검사기(tools/쳅터1/기믹.py) 가 본다.
##
## ▣ 왜 SS2D 지형이 아니라 사물인가
##   하수도는 SS2D 지형에 금·파편을 덧그리는 `SS2D_붕괴발판.gd` 를 쓴다. 쳅터1 은 아스트라 원화
##   「썩은 마루판 정상/금/처짐/부서짐」이 그대로 있어서(기둥 둘 + 판자 한 칸) 그 그림을 상태별로 바꿔 끼우는 편이
##   2.5D 목재 지형과 같은 문법(윗면이 보이는 판)으로 읽힌다.
##
## ▣ 색 — **무색(회색 계열 나무) = 검정·흰 몸 모두 설 수 있다.** 이 게임의 "회색만 안전" 규칙과 같은 자리다.
##   부서지는 발판을 처음 배우는 자리(04 복도 B)에서 색 규칙까지 겹치면 무엇 때문에 죽었는지 안 읽힌다 —
##   한 번에 장치 하나(도형님: "장애물을 학습할 수 있게 배치 … 하나씩").
##
## ▣ 배치 규약 — 원점 = 판 **윗면(발 닿는 선) 가운데**. 도안에서는 {"종류": "부서지는판", "x", "y"(윗면 칸), "장수"}.
##   그림은 목재 상판처럼 윗면 가운데가 발 그림 깊이(+7)에 오게 놓는다 → 플레이어 발 그림과 맞는다(`발_그림_깊이`).
## ============================================================================

const 폴더 := "res://assets/textures/props/신규기믹_v02/게임용/부서지는발판/"
const 폭 := 96.0
const 두께 := 16.0          ## 판정 두께(px) — 위에서 밟는 판. 옆에서 부딪히면 막힌다(얇은 판자 끝)

@export_range(0.2, 4.0, 0.05) var 붕괴_대기: float = 0.9

var _단계 := 0               ## 0 멀쩡 · 1 금 가는 중 · 2 부서짐
var _남은 := 0.0
var _그림단계 := 0           ## 0 정상 · 1 금 1 · 2 처짐 · (부서지면 숨김)
var _떨림 := 0.0
var _판정: CollisionShape2D
var _그림들: Array[Texture2D] = []


func _ready() -> void:
	for k in 4:
		var 경로 := 폴더 + "마루판_상태_%d.png" % k
		_그림들.append(load(경로) if ResourceLoader.exists(경로) else null)
	_판정 = get_node_or_null("판정") as CollisionShape2D
	if _판정 == null:
		_판정 = CollisionShape2D.new()
		_판정.name = "판정"
		var r := RectangleShape2D.new()
		r.size = Vector2(폭 - 6.0, 두께)
		_판정.shape = r
		_판정.position = Vector2(0, 두께 * 0.5)
		add_child(_판정)                 # owner 없음 — 씬에 저장되지 않는다(스크립트가 늘 다시 만든다)
	collision_layer = 1
	collision_mask = 0
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group("붕괴발판")


## 플레이어 발 그림 깊이(목재 상판과 같은 +7) — player_anim 이 발밑 콜리전의 조상에서 찾는다.
func 발_그림_깊이() -> float:
	return 7.0


func 부서졌나() -> bool:
	return _단계 == 2


func _physics_process(delta: float) -> void:
	if _단계 == 0:
		if _밟혔나():
			_단계 = 1
			_남은 = 붕괴_대기
			_먼지(5, 0.0)
		return
	if _단계 == 1:
		_남은 -= delta
		var 지남 := 붕괴_대기 - _남은
		# 리듬 3등분(0.9초 기준 0.3 / 0.6 / 0.9) — 대기를 바꿔도 같은 비율
		var 새 := 2 if 지남 >= 붕괴_대기 * (2.0 / 3.0) else (1 if 지남 >= 붕괴_대기 / 3.0 else 0)
		if 새 != _그림단계:
			_그림단계 = 새
			_먼지(3 + 새 * 3, 0.0)
		# 떨림 — 그림만(판정을 흔들면 위에 선 몸이 밀린다). 처짐 단계에서 더 세게.
		_떨림 = sin(_남은 * 55.0) * (0.6 if _그림단계 < 2 else 1.3)
		queue_redraw()
		if _남은 <= 0.0:
			_부서지기()


## 밟힘 = 몸이 실제로 움직이는 중이고(사망 모션 중 멈춘 몸의 남은 접촉 기록은 무시) 발이 이 판 윗면에 있다.
##   SS2D_붕괴발판 에서 겪은 함정 두 가지(부활 직후 다시 무너짐 · 옆 판 오인)를 같은 방법으로 막는다.
func _밟혔나() -> bool:
	for 후보 in get_tree().get_nodes_in_group("player"):
		var 몸 := 후보 as CharacterBody2D
		if 몸 == null or not 몸.is_on_floor() or not 몸.is_physics_processing():
			continue
		var 발 := to_local(몸.global_position)
		if absf(발.x) > 폭 * 0.5 + 24.0 or absf(발.y) > 10.0:
			continue
		for i in 몸.get_slide_collision_count():
			var c := 몸.get_slide_collision(i)
			if c.get_collider() == self and c.get_normal().dot(Vector2.UP) > 0.5:
				return true
	return false


func _부서지기() -> void:
	_단계 = 2
	_떨림 = 0.0
	_판정.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	_먼지(10, 0.0)
	_조각_떨어뜨리기()
	queue_redraw()


## 월드.gd `_리스폰()` 이 부른다 — 죽어 부활할 때만(v3).
func 부활_복구() -> void:
	if _단계 == 0:
		return
	_단계 = 0
	_그림단계 = 0
	_떨림 = 0.0
	_판정.set_deferred("disabled", false)
	set_deferred("collision_layer", 1)
	queue_redraw()


# ── 그림 ─────────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _단계 == 2:
		# 부서진 자리 — 양쪽 기둥 끝만 옅게 남는다(여기 판이 있었다)
		var 끝 := _그림들[3]
		if 끝:
			_판_그리기(끝, Color(1, 1, 1, 0.22), Vector2.ZERO, true)
		return
	var t := _그림들[_그림단계] if _그림단계 < _그림들.size() else null
	if t == null:
		# 그림이 없으면(도구를 안 돌렸으면) 코드 판자
		draw_rect(Rect2(-폭 * 0.5, -3.0, 폭, 두께 + 6.0), Color(0.30, 0.29, 0.27))
		return
	_판_그리기(t, Color.WHITE, Vector2(_떨림, 0.0), false)


## 상태 그림(2배 · 왼쪽 기둥 기준 정렬)을 판정 위에 얹는다.
##   그림 세로: 윗면이 위쪽 약 40% — 윗면 가운데가 발 그림 깊이(+7)에 오도록 그림 위끝을 −3 에 둔다(목재 상판 −4…18 과 같은 자리).
func _판_그리기(t: Texture2D, 색: Color, 밀기: Vector2, 끝만: bool) -> void:
	var 크기 := Vector2(t.get_size()) * 0.5
	var 왼 := Vector2(-폭 * 0.5, -3.0) + 밀기     # 정상 판(원화 357px → 2배 192 → 게임 96)이 기둥까지 꼭 96px
	if 끝만:
		# 부서짐 그림의 양 끝 기둥 부분만(가운데 조각은 떨어지는 조각으로 따로 그린다)
		var 쪽 := 크기.x * 0.17
		draw_texture_rect_region(t, Rect2(왼, Vector2(쪽, 크기.y)), Rect2(Vector2.ZERO, Vector2(쪽 * 2.0, 크기.y * 2.0)), 색)
		var 오른쪽x := 폭 * 0.5 - 쪽
		draw_texture_rect_region(t, Rect2(Vector2(오른쪽x, 왼.y), Vector2(쪽, 크기.y)),
			Rect2(Vector2((오른쪽x - 왼.x) * 2.0, 0.0), Vector2(쪽 * 2.0, 크기.y * 2.0)), 색)
		return
	draw_texture_rect(t, Rect2(왼, 크기), false, 색)


func _조각_떨어뜨리기() -> void:
	var 그림 := _그림들[3]
	if 그림 == null or not is_inside_tree():
		return
	# 부서짐 상태 그림의 가운데 조각들을 세 덩이로 잘라 각자 돌며 떨어뜨린다
	var 크기 := Vector2(그림.get_size())
	for k in 3:
		var s := Sprite2D.new()
		var a := AtlasTexture.new()
		a.atlas = 그림
		a.region = Rect2(크기.x * (0.2 + 0.2 * k), 0.0, 크기.x * 0.2, 크기.y)
		s.texture = a
		s.scale = Vector2.ONE * 0.5
		s.top_level = true
		s.z_index = 5
		get_tree().current_scene.add_child(s)
		s.global_position = to_global(Vector2(-폭 * 0.5 + 크기.x * 0.5 * (0.3 + 0.2 * k), 14.0))
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "global_position", s.global_position + Vector2(randf_range(-22, 22), randf_range(170, 240)), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "rotation", randf_range(-1.8, 1.8), 0.75)
		tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.45)
		tw.chain().tween_callback(s.queue_free)


func _먼지(개수: int, _x: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 개수
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(폭 * 0.42, 2.0)
	p.position = Vector2(0, 두께 + 6.0)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.55, 0.53, 0.49, 0.7)
	p.z_index = 2
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true
