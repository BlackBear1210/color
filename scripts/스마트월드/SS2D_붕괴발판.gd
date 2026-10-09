@tool
extends "res://scripts/스마트월드/지형.gd"
## 이전 PaintPlatform 부품을 섞지 않고 SS2D 편집·페인트코어 계약을 그대로 유지한다.
## ============================================================================
## [2026-10-08 Claude] 부서지는 발판 v3 — docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-F (도형님 확정)
## ----------------------------------------------------------------------------
## ▣ 규칙(확정)
##   · 리듬: 밟음 → 삐걱 + 먼지 → 금 1(0.3초) → 금 2·처짐(0.6초) → **0.9초에 부서져 조각이 떨어짐**.
##   · **칠해도 아무 변화 없음** — 물감으로 보강할 수 없다. `명중()` 은 칠하기만 하고 붕괴 타이머에 손대지 않는다.
##   · **저절로 복구되지 않는다.** 부서진 채로 남고, 플레이어가 **죽어 부활할 때만** 스테이지의 부서진 발판이 전부
##     원래대로(체크포인트 부활 포함) — 월드.gd `_리스폰()` 이 "붕괴발판" 그룹에 `부활_복구()` 를 부른다.
##     예전 3초 자동 복구는 `자동_복구` 를 켜야만 돈다(옛 판 비교용 · 기본 끔).
##   · 레벨 규칙: 부서지는 발판 아래는 반드시 낙사 또는 반대색 — "못 건너면 죽는다 → 죽으면 초기화".
##     같은 길을 여러 번 오가야 하는 구간에는 쓰지 않는다(살아서 갇히는 자리 금지).
##
## ▣ 하나로 통일
##   예전 3종(`장애물/무너지는발판.gd` · `스마트월드/무너지는바위.gd` · 이 파일) 중 실제 스테이지(2-4 · 2-11)가 쓰는 것은
##   이 파일 하나뿐이었다 → 이 파일이 표준. 앞의 둘은 쓰는 스테이지가 없어 손대지 않았다(새로 놓지 말 것).
##
## ▣ 그림 — 발판 본체는 SS2D 지형 그대로(색 판정과 그림이 한 몸). 그 위에 이 스크립트가
##   ① 금(코드로 그리는 갈라짐 — 단계마다 늘어난다) ② 먼지(밟는 순간·금 갈 때) ③ 처짐(금 2 부터 그림만 2px 출렁)
##   ④ 부서질 때 떨어지는 조각(아스트라 원화 낱 조각 · 집 = 썩은 마루판 / 하수도 = 녹슨 철망 · 지형 색으로 물들임)을 얹는다.
##   부서진 자리는 아주 옅은 자국(알파 0.12)만 남는다 — "여기 있었지만 지금은 없다".
## ============================================================================

@export_range(0.2, 4.0, 0.05) var 붕괴_대기: float = 0.9
## (v3: 기본 끔) 켜면 예전처럼 `복구_대기` 초 뒤 저절로 되살아난다 — 옛 판 비교·되돌리기용.
@export var 자동_복구: bool = false
@export_range(1.0, 12.0, 0.1) var 복구_대기: float = 3.0
## 떨어지는 조각 그림 — 자동 = 씬 경로에 world_2 가 있으면 하수도(철망), 아니면 집(마루판).
@export_enum("자동", "집", "하수도") var 파편_재질: int = 0

const 파편_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/부서지는발판/"

var _붕괴단계: int = 0        ## 0 멀쩡 · 1 금 가는 중 · 2 부서짐
var _남은시간: float = 0.0
var _겉: Node2D = null        ## 금·처짐을 그리는 덧그림(실행 때만 · 씬에 저장 안 함)
var _금단계: int = 0          ## 0 없음 · 1 금 1 · 2 금 2 + 처짐


func _ready() -> void:
	super._ready()
	# 편집 중에는 타이머나 충돌을 바꾸지 않아 저장된 형상을 보존한다.
	set_physics_process(not Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		add_to_group("붕괴발판")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _붕괴단계 == 0:
		if _실제로_밟혔나():
			_붕괴단계 = 1
			_남은시간 = 붕괴_대기
			_금단계 = 0
			_먼지(6)                    # 밟는 순간 — 삐걱 + 먼지
		return
	if _붕괴단계 == 1:
		_남은시간 -= delta
		var 지남 := 붕괴_대기 - _남은시간
		# 0.9초 기준 0.3 / 0.6 → 붕괴_대기 비율로(대기를 바꿔도 리듬은 같은 3등분)
		var 새금 := 2 if 지남 >= 붕괴_대기 * (2.0 / 3.0) else (1 if 지남 >= 붕괴_대기 / 3.0 else 0)
		if 새금 != _금단계:
			_금단계 = 새금
			_먼지(4 + 새금 * 3)
			_겉_다시()
		if _금단계 == 2 and _겉:
			# 처짐 — 그림만 2px 아래로 출렁(지형 좌표를 움직이면 위에 선 몸이 밀린다 · 예전 주석과 같은 이유)
			_겉.position.y = 2.0 + sin(_남은시간 * 40.0) * 0.8
		if _남은시간 <= 0.0:
			_부서지기()
	elif 자동_복구:
		_남은시간 -= delta
		if _남은시간 <= 0.0 and not _복구위치에_플레이어가_있나():
			# 플레이어 몸 안에서 발판이 되살아나 끼이는 것을 막는다.
			부활_복구()


func _부서지기() -> void:
	_붕괴단계 = 2
	_남은시간 = 복구_대기
	_금단계 = 0
	_파편_떨어뜨리기()
	_먼지(10)
	_겉_다시()
	_충돌레이어_갱신()


## 월드.gd `_리스폰()` 이 부른다(죽어 부활할 때만 — v3 규칙). 페인트 리셋과 따로 불리므로 칠 상태는 건드리지 않는다.
func 부활_복구() -> void:
	if _붕괴단계 == 0:
		return
	_붕괴단계 = 0
	_남은시간 = 0.0
	_금단계 = 0
	self_modulate = Color.WHITE
	_겉_다시()
	_충돌레이어_갱신()


func 부서졌나() -> bool:
	return _붕괴단계 == 2


func _실제로_밟혔나() -> bool:
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return false
	var 범위 := _범위()
	for 후보 in get_tree().get_nodes_in_group("player"):
		var 몸 := 후보 as CharacterBody2D
		if 몸 == null or not 몸.is_on_floor():
			continue
		# ★[2026-10-08] 접촉 기록(get_slide_collision)·is_on_floor 는 **마지막 move_and_slide 결과가 남은 값**이다.
		#   사망 모션 동안 몸의 물리가 멈춰 있으면, 부활 복구 직후 이 발판이 '아직 밟혀 있다' 고 읽어 곧바로 다시 무너졌다
		#   (시험_부서지는발판 실측). → 몸이 실제로 움직이는 중이고 발이 이 발판 윗면 근처에 있을 때만 밟힘으로 본다.
		if not 몸.is_physics_processing():
			continue
		var 발 := to_local(몸.global_position)
		if 범위.size != Vector2.ZERO and (발.x < 범위.position.x - 40.0 or 발.x > 범위.end.x + 40.0
				or absf(발.y - 범위.position.y) > 12.0):
			continue
		for i in 몸.get_slide_collision_count():
			var 접촉 := 몸.get_slide_collision(i)
			if 접촉.get_collider() == 폴리.get_parent() and 접촉.get_normal().dot(Vector2.UP) > 0.5:
				return true
	return false


func _복구위치에_플레이어가_있나() -> bool:
	var 범위 := _범위()
	if 범위.size == Vector2.ZERO:
		return false
	for 몸 in get_tree().get_nodes_in_group("player"):
		if 몸 is Node2D and 범위.grow(64.0).has_point(to_local(몸.global_position + Vector2(0, -48))):
			return true
	return false


## 판정 폴리곤의 로컬 사각형(이 노드 기준).
func _범위() -> Rect2:
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null or 폴리.polygon.is_empty():
		return Rect2()
	var xf := get_global_transform().affine_inverse() * 폴리.get_global_transform()
	var r := Rect2(xf * 폴리.polygon[0], Vector2.ZERO)
	for 점 in 폴리.polygon:
		r = r.expand(xf * 점)
	return r


func _충돌레이어_갱신() -> void:
	super._충돌레이어_갱신()
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return
	# 페인트 회수·덮어칠이 들어와도 무너진 동안에는 충돌이 다시 켜지지 않는다.
	폴리.set_deferred("disabled", _붕괴단계 == 2)
	if _붕괴단계 == 2:
		폴리.get_parent().set_deferred("collision_layer", 0)
		self_modulate = Color(1, 1, 1, 0.12)


## 칠은 된다(색 규칙은 그대로) — 그러나 붕괴 타이머에는 아무 영향이 없다(v3: 물감으로 보강 불가).
func 명중(색: int, 월드좌표: Vector2) -> String:
	if _붕괴단계 == 2:
		return "blocked"
	return super.명중(색, 월드좌표)


## 페인트 코어 리셋(사망) 때 칠한 지형에만 불린다. 부서짐 복구는 `부활_복구()` 가 모든 발판에 따로 한다.
func 강제_초기화() -> void:
	super.강제_초기화()
	부활_복구()


# ── 덧그림: 금 · 처짐 ────────────────────────────────────────────────────────
func _겉_다시() -> void:
	if _겉 == null:
		_겉 = Node2D.new()
		_겉.name = "_금"
		_겉.z_index = 1
		add_child(_겉)          # owner 없음 — 씬에 저장되지 않는다(실행 때만)
		_겉.draw.connect(_금_그리기)
	if _금단계 == 0:
		_겉.position = Vector2.ZERO
	_겉.queue_redraw()


## 금 — 윗면에서 아래로 뻗는 지그재그 몇 줄. 단계 2 는 줄이 길어지고 가로로 이어지는 큰 금이 더해진다.
##   모양은 발판 위치로 정한 고정 난수(매번 같은 금) · 색은 지형 색의 반대 계열(검정 발판 = 밝은 금).
func _금_그리기() -> void:
	if _금단계 == 0 or _붕괴단계 == 2:
		return
	var r := _범위()
	if r.size == Vector2.ZERO:
		return
	var 난수 := RandomNumberGenerator.new()
	난수.seed = int(absf(global_position.x * 7.0 + global_position.y * 13.0)) + 17
	var 밝은 := 현재색() != ColorDefs.WHITE
	var 색 := Color(0.62, 0.61, 0.58, 0.85) if 밝은 else Color(0.10, 0.10, 0.10, 0.85)
	var 그늘 := Color(0, 0, 0, 0.6) if 밝은 else Color(1, 1, 1, 0.25)
	var 줄수 := 2 + int(r.size.x / 120.0)
	# 금은 밟는 면(윗면 아래 48px)에만 — 2-4 처럼 판정이 키 288 인 발판에서 금이 벽 아래까지 내려가던 것(촬영 2026-10-08)
	var 깊이 := minf(r.size.y, 48.0)
	for i in 줄수:
		var x := r.position.x + r.size.x * (float(i) + 0.5 + 난수.randf_range(-0.25, 0.25)) / float(줄수)
		var 길이 := 깊이 * (0.45 if _금단계 == 1 else 0.9)
		var 점들 := PackedVector2Array([Vector2(x, r.position.y)])
		var y := r.position.y
		while y < r.position.y + 길이:
			y += 난수.randf_range(5.0, 9.0)
			x += 난수.randf_range(-5.0, 5.0)
			점들.append(Vector2(x, minf(y, r.position.y + 길이)))
		_겉.draw_polyline(점들, 그늘, 3.0)
		_겉.draw_polyline(점들, 색, 1.4)
	if _금단계 == 2:
		# 가로로 이어지는 큰 금 — 처짐의 시작(가운데가 꺼진다)
		var 점들2 := PackedVector2Array()
		var n := maxi(6, int(r.size.x / 14.0))
		for k in n + 1:
			var u := float(k) / float(n)
			var 처짐 := sin(u * PI) * 3.0
			점들2.append(Vector2(r.position.x + r.size.x * u, r.position.y + 깊이 * 0.35 + 처짐 + 난수.randf_range(-2.5, 2.5)))
		_겉.draw_polyline(점들2, 그늘, 3.4)
		_겉.draw_polyline(점들2, 색, 1.6)


# ── 먼지 · 파편 ──────────────────────────────────────────────────────────────
func _먼지(개수: int) -> void:
	var r := _범위()
	if r.size == Vector2.ZERO:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 개수
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(r.size.x * 0.45, 2.0)
	p.position = Vector2(r.get_center().x, r.position.y + minf(r.size.y, 48.0))
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.55, 0.54, 0.50, 0.7)
	p.z_index = 2
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _파편_재질_이름() -> String:
	if 파편_재질 == 1:
		return "집"
	if 파편_재질 == 2:
		return "하수도"
	var 씬 := owner.scene_file_path if owner else ""
	if 씬 == "" and get_tree().current_scene:
		씬 = get_tree().current_scene.scene_file_path
	return "하수도" if 씬.contains("world_2") else "집"


## 부서지는 순간 — 원화 낱 조각 3~5 개를 지형 색으로 물들여 떨어뜨린다(돌며 떨어지고 0.8초 뒤 사라짐).
func _파편_떨어뜨리기() -> void:
	var r := _범위()
	if r.size == Vector2.ZERO:
		return
	var 재 := _파편_재질_이름()
	var 그림들: Array[Texture2D] = []
	for k in 2:
		var 경로 := 파편_폴더 + "%s_파편_%d.png" % [재, k]
		if ResourceLoader.exists(경로):
			그림들.append(load(경로))
	if 그림들.is_empty():
		return
	# 색: 검정 발판 = 어둡게(밝은 결이 테처럼 남는다) · 흰 발판 = 밝게(184 근처)
	var 색 := 현재색()
	var 물 := Color(0.45, 0.45, 0.45) if 색 != ColorDefs.WHITE else Color(1.55, 1.55, 1.52)
	var 개수 := clampi(int(r.size.x / 48.0), 3, 5)
	for i in 개수:
		var tex := 그림들[i % 그림들.size()]
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = 물
		# 조각 하나 = 발판 폭의 (1/개수 × 1.1) — 발판 크기가 달라도 비율이 맞는다
		var 폭 := r.size.x / float(개수) * 1.1
		s.scale = Vector2.ONE * (폭 / float(tex.get_width()))
		s.top_level = true
		s.z_index = 5
		get_tree().current_scene.add_child(s)
		s.global_position = to_global(Vector2(r.position.x + r.size.x * (float(i) + 0.5) / float(개수), r.position.y + minf(r.size.y, 48.0) * 0.5))
		var 아래 := randf_range(160.0, 260.0)
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "global_position", s.global_position + Vector2(randf_range(-30, 30), 아래), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(s, "rotation", randf_range(-1.6, 1.6), 0.8)
		t.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.5)
		t.chain().tween_callback(s.queue_free)
