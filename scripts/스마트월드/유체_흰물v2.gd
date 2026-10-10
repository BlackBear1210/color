@tool
extends "res://scripts/스마트월드/유체.gd"
## 기존 경로를 유지한 세 색 공용 외관. 물의 혼합 시에도 현재 색을 전달한다.
## 2-1의 선택된 물에만 적용. 혼합/도색 제거/켜짐은 기존 유체가 담당한다.
## 2-1~2-4에만 승인된 삼색 프레임을 연결해 다른 스테이지의 외관을 유지한다.
@export var 힉스필드_삼색프레임: bool = false
const REFERENCE_VISUAL = preload("res://scripts/스마트월드/물_힉스필드_삼색프레임.gd")
const WHITE_DESIGN = preload("res://scenes/장식/유체/흰물_디자인.tscn")
var _white_visual: Node2D
var _white_active: bool = false
var _바닥_그림높이: float = 0.0
## 원근 지형은 충돌선보다 상판 중앙이 아래에 있다. 웅덩이 착수와 구분해서 보관한다.
var _바닥_그림깊이: float = 0.0
var _수면_검사대기: float = 0.0

func _웅덩이_착수_맞추기(delta: float) -> void:
	# 물리 길이는 유지하고 웅덩이 윗면에서 그림/물보라만 끝낸다. 꺼지면 바닥으로 복구한다.
	_수면_검사대기 -= delta
	if _수면_검사대기 > 0.0 or Engine.is_editor_hint() or 호퍼_유입:
		return
	_수면_검사대기 = 0.1
	var stage: Node = self
	while stage != null and not stage.scene_file_path.begins_with("res://scenes/world_2_클로드/stage_"):
		stage = stage.get_parent()
	if stage == null or not is_instance_valid(_white_visual):
		return
	var height := minf(_바닥_그림높이, 크기.y) if _바닥_그림높이 > 0.0 else 크기.y
	var depth := _바닥_그림깊이
	for pool in get_tree().get_nodes_in_group("웅덩이"):
		if not pool.get("켜짐"):
			continue
		var size: Vector2 = pool.get("크기")
		var local: Vector2 = pool.to_local(global_position)
		if absf(local.x) > size.x * 0.5:
			continue
		var surface := to_local(pool.to_global(Vector2(local.x, -size.y))).y
		if surface > 0.0 and surface <= height:
			height = surface
			# 웅덩이는 아래 바닥 대신 자기 수면의 원근 중앙을 따른다.
			var pool_depth := float(pool.call("수면_그림깊이")) if pool.has_method("수면_그림깊이") else 0.0
			depth = to_local(pool.to_global(Vector2(0, pool_depth))).y - to_local(pool.to_global(Vector2.ZERO)).y
	_white_visual.set("착수_그림깊이", depth)
	# ★[2026-10-02 실측] 같은 값이어도 넣으면 물 그림이 재질을 통째로 다시 만든다(한 번 1.3ms).
	#   0.1 초마다 물 8 개가 같은 프레임에 몰려 2-3 에서 스크립트가 10ms 씩 튀었다 → 바뀐 때만 넣는다.
	if not is_equal_approx(float(_white_visual.get("보이는_높이")), height):
		_white_visual.set("보이는_높이", height)


## 호퍼 유입은 바닥 충돌이 아니므로 끝에서 물보라가 터지지 않게 한다.
@export var 호퍼_유입: bool = false:
	set(value):
		호퍼_유입 = value
		_물_애니_크기_맞추기()

## [2026-09-27] 물줄기 v3 외관(흰물_디자인.물줄기_v3). 2-9 시범 뒤 기본 켬 — 하수도 전 스테이지.
## 판정은 바뀌지 않는다(아래 _판정_폴리곤들 그대로).
@export var 물줄기_v3: bool = true:
	set(value):
		물줄기_v3 = value
		_물_애니_크기_맞추기()

## ── [2026-09-30 도형님] 레버·저장고·호퍼로 켜고 끌 때 "빡" 나타나지 않고 위에서 흘러내리게 ──
## 켜면: 앞끝(머리)이 출구에서 중력처럼 가속하며 떨어진다. **판정도 머리까지만** 생긴다 —
##       물이 아직 안 보이는 곳에서 죽으면 안 된다.
## 끄면: 판정은 즉시 없어지고(꺼진 물 규칙 · 총알 통과) 그림만 위에서부터 끊겨 남은 물이 떨어진다.
## 게임 시작 때의 첫 상태는 연출 없이 바로.
const 흐름_처음속도 := 250.0     ## px/s
const 흐름_중력 := 2600.0        ## px/s² — 800px 물줄기가 약 0.7 초에 바닥에 닿는다
## 사용자 요청: 켜고 끌 때 흐름도 40% 빠르게. 속도·중력을 따로 바꾸지 않고 시간을 배속한다.
const 흐름_배속 := 1.4
var _흐름_준비 := false
var _이전_켜짐 := true
var _머리 := -1.0                ## <0 = 연출 없음(전부 보임)
var _꼬리 := -1.0                ## <0 = 연출 없음
var _머리_속도 := 0.0
var _꼬리_속도 := 0.0
var _출수_선행거리 := 0.0

func 배관_선두설정(depth: float) -> void:
	# 물의 첫 앞끝을 배관 안에서 출발시킨다. 밖에 먼저 생기거나 확대되는 그림을 막는다.
	var distance := maxf(depth, 0.0) * .87
	if is_equal_approx(_출수_선행거리, distance):
		return
	_출수_선행거리 = distance
	_흐름_셰이더()
	if _머리 >= 0.0:
		_물_판정_갱신()

func 출수_앞끝() -> float:
	# 입구 안쪽의 음수 좌표도 그림에 넘기고, 판정은 이 앞끝이 지형 쪽으로 나온 뒤 생긴다.
	return _머리 - _출수_선행거리 if _머리 >= 0.0 else 100000.0

func _켜짐_반영() -> void:
	super._켜짐_반영()
	if not _흐름_준비 or Engine.is_editor_hint() or not _새물인가():
		_이전_켜짐 = 켜짐
		return
	if 켜짐 and not _이전_켜짐:
		_머리 = 0.0
		_머리_속도 = 흐름_처음속도
		_꼬리 = -1.0
		call_deferred("_물_판정_갱신")
	elif not 켜짐 and _이전_켜짐:
		_꼬리 = 0.0
		_꼬리_속도 = 흐름_처음속도
		visible = true            # 판정·총알·감지는 이미 꺼졌다 — 남은 물 그림만 떨어뜨린다
	_이전_켜짐 = 켜짐
	_흐름_셰이더()

func _흐름_셰이더() -> void:
	if not is_instance_valid(_white_visual):
		return
	var mat := _white_visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flow_head", 출수_앞끝())
	mat.set_shader_parameter("flow_tail", _꼬리 if _꼬리 >= 0.0 else -100000.0)

func _흐름_진행(delta: float) -> void:
	# 머리·꼬리·보이는 물의 판정이 같은 시간을 사용해 그림보다 먼저 위험해지지 않게 한다.
	delta *= 흐름_배속
	if _머리 >= 0.0:
		_머리_속도 += 흐름_중력 * delta
		_머리 += _머리_속도 * delta
		# 출수 직후 끄더라도 배관 물의 앞끝은 보존한다. -1로 바꾸면 아직 없는 아래쪽 물이 생겨 버린다.
		if 출수_앞끝() >= 크기.y + 40.0 or (not 켜짐 and _출수_선행거리 <= 0.0):
			_머리 = -1.0
		_물_판정_갱신()        # 판정 아랫끝이 머리를 따라 내려온다(_판정_폴리곤들)
		_흐름_셰이더()
	if _꼬리 >= 0.0:
		_꼬리_속도 += 흐름_중력 * delta
		_꼬리 += _꼬리_속도 * delta
		if _꼬리 >= 크기.y + 40.0 or 켜짐:
			_꼬리 = -1.0
			visible = 켜짐
		_흐름_셰이더()

func _ready() -> void:
	super._ready()
	_이전_켜짐 = 켜짐
	# 첫 상태가 자리 잡은 다음부터만 흘러내림 연출(스테이지 시작 때 모든 물이 떨어지는 일이 없게).
	set_deferred("_흐름_준비", true)
	# 상위 _ready 안에서 호출될 때는 준비 검사 때문에 외관 생성이 미뤄질 수 있다.
	call_deferred("_물_그림_갱신")
	if not Engine.is_editor_hint():
		_바닥_찾기()

## [2026-09-27] v3 물막·물보라를 **실제 바닥 윗면**에 앉힌다(그림만 — 판정은 그대로).
## 판정 사각형이 바닥 속까지 내려간 물줄기(2-5 F1: 60px)는 물막이 벽돌 속에 그려졌다.
## 아랫끝에서 위로 4px 씩 올라가며 "지형(레이어 1) 안인가" 를 묻고, 처음 벗어난 곳이 바닥 윗면이다.
## 위로 쏘는 광선은 시작점을 품은 바닥을 못 본다(hit_from_inside) → 점 질의로 한다.
## 격자(통과플랫폼)도 레이어 1 이지만 물 아랫끝이 격자 속에 있는 배치는 없어서 문제되지 않는다.
func _바닥_찾기() -> void:
	# 지형 콜리전이 물리 서버에 올라간 뒤에 묻는다(첫 물리 프레임 전에는 비어 있다).
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or 호퍼_유입 or not is_instance_valid(_white_visual):
		return
	var 공간 := get_world_2d().direct_space_state
	var 질의 := PhysicsPointQueryParameters2D.new()
	질의.collision_mask = 1
	질의.collide_with_areas = false
	# 끝점이 바닥 충돌선과 정확히 같아도 지형을 찾도록 1px 안쪽에서 시작한다.
	var 아래 := 크기.y + 1.0
	# 물줄기 절반 · 240px 넘게 파묻혔으면 뭔가 다른 배치다 — 손대지 않는다.
	var 한계 := minf(크기.y * 0.5, 240.0)
	var 파묻힘 := 0.0
	while 파묻힘 <= 한계:
		질의.position = to_global(Vector2(0.0, 아래 - 파묻힘))
		if 공간.intersect_point(질의, 1).is_empty():
			break
		파묻힘 += 4.0
	if 파묻힘 < 4.0 or 파묻힘 > 한계:
		return
	# 4px 걸음으로 지나친 만큼 1px 씩 되돌아가 윗면을 정확히 잡는다.
	while 파묻힘 > 0.0:
		질의.position = to_global(Vector2(0.0, 아래 - 파묻힘 + 1.0))
		var 접촉 := 공간.intersect_point(질의, 1)
		if not 접촉.is_empty():
			# 플레이어 발과 동일한 지형 API로 상판 중앙을 얻는다. 스케일은 물 로컬 좌표로 환산한다.
			var 면: Node = 접촉[0]["collider"]
			while 면 != null and not 면.has_method("발_그림_깊이"):
				면 = 면.get_parent()
			if 면 is Node2D:
				var 지형깊이 := float(면.call("발_그림_깊이"))
				_바닥_그림깊이 = to_local(면.to_global(Vector2(0, 지형깊이))).y - to_local(면.to_global(Vector2.ZERO)).y
			break
		파묻힘 -= 1.0
	# 마지막 질의가 닿은 +1px 지점을 사용해야 상판 중앙보다 1px 떠 있지 않는다.
	_바닥_그림높이 = 아래 - 파묻힘 + 1.0
	_white_visual.set("착수_그림깊이", _바닥_그림깊이)
	_white_visual.set("보이는_높이", _바닥_그림높이)

func _새물인가() -> bool:
	return 종류 == 종류_.물

func _물_그림_갱신() -> void:
	super._물_그림_갱신()
	if not is_node_ready():
		return
	if not is_instance_valid(_white_visual):
		_white_visual = Node2D.new() if 힉스필드_삼색프레임 else WHITE_DESIGN.instantiate()
		if 힉스필드_삼색프레임:
			_white_visual.set_script(REFERENCE_VISUAL)
		_white_visual.name = "WhiteWaterV2"
		_white_visual.z_index = 2
		add_child(_white_visual)
	var active := _새물인가()
	_white_visual.visible = active
	if active:
		for animation_node in [_물_애니(), _물_상세_애니()]:
			if animation_node != null:
				animation_node.stop()
				animation_node.visible = false
	_물_애니_크기_맞추기()
	if active != _white_active:
		_white_active = active
		# 혼합 판정 도중 색이 바뀌어도 물리 서버 조회 중 도형을 수정하지 않는다.
		call_deferred("_물_판정_갱신")
	queue_redraw()

func _물_애니_크기_맞추기() -> void:
	super._물_애니_크기_맞추기()
	if is_instance_valid(_white_visual):
		_white_visual.set("착수_물보라", not 호퍼_유입)
		_white_visual.set("물색", int(색))
		_white_visual.set("크기", 크기)
		_white_visual.set("흐름속도", 흐름속도)
		_white_visual.set("형태", 1 if 크기.x >= 160.0 else 0)
		# v3 는 판정 사각형보다 가늘어지지 않도록 판정_여유를 알아야 한다(형태를 정한 뒤에 켠다)
		_white_visual.set("판정_여유", 판정_여유)
		_white_visual.set("물줄기_v3", 물줄기_v3)

func _판정_폴리곤들(frame_index: int) -> Array:
	if not _새물인가():
		return super._판정_폴리곤들(frame_index)
	# v2 가장자리 분무/착수 물보라는 비위험 장식. 밝은 연속 몸통만 접촉 판정한다.
	# 새 그림 위에 이전 프레임의 불규칙한 섬 폴리곤을 남기지 않는다.
	var inset := minf(7.0, 크기.x * 0.2)
	var half_width := maxf(1.0, 크기.x * 0.5 - inset + 판정_여유)
	var top := minf(3.0, 크기.y * 0.1)
	var bottom := maxf(top + 1.0, 크기.y - minf(9.0, 크기.y * 0.2))
	# 흘러내리는 중이면 판정도 머리(앞끝)까지만 — 보이지 않는 물에 닿아 죽지 않게.
	if _머리 >= 0.0:
		var front := 출수_앞끝()
		if front - 6.0 <= top + 1.0:
			return []
		bottom = minf(bottom, front - 6.0)
	return [PackedVector2Array([Vector2(-half_width, top), Vector2(half_width, top), Vector2(half_width, bottom), Vector2(-half_width, bottom)])]

func _물_애니_재생중() -> bool:
	return (is_instance_valid(_white_visual) and _새물인가()) or super._물_애니_재생중()

func _process(delta: float) -> void:
	_웅덩이_착수_맞추기(delta)
	if _머리 >= 0.0 or _꼬리 >= 0.0:
		_흐름_진행(delta)
	if not _새물인가():
		super._process(delta)
		return
	# GPU TIME으로 재생한다. 매 프레임 충돌 재생성과 queue_redraw를 피한다.
	if is_instance_valid(_white_visual) and _white_visual.get("흐름속도") != 흐름속도:
		_white_visual.set("흐름속도", 흐름속도)
