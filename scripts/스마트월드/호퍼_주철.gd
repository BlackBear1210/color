@tool
extends "res://scripts/스마트월드/호퍼.gd"
## 승인된 주철 아트만 교체하고 기존 입구/혼합/끊김 유예 로직을 상속한다.
## [2026-09-27] 평면 출구판 아틀라스. 원화 직하 노즐의 둥근 입구(아래서 올려다본 타원 · 안쪽 검은 구멍)를
## 깔때기 아랫단 띠로 마감해 정면 옆모습으로 맞췄다(도형님 결정). 원본은 hopper_atlas.png 그대로 있다.
## 굽는 도구: tools/생성_호퍼_평면출구.py (손으로 그리지 말 것). 좌하·우하 칸은 원본과 같다.
const 주철_아틀라스 = preload("res://assets/textures/obstacles/hopper/cast_iron_v1/hopper_atlas_flat.png")
## 노즐 안지름 = 호퍼 폭 × 0.2 (원화 400 폭 기준 관 안지름 80 — 도구 머리말의 실측값과 같아야 한다).
const 노즐_안지름_비율 := 0.2
const 입구_수면_스크립트 = preload("res://scripts/스마트월드/호퍼_입구수면.gd")
var _하수도_입구연출: bool = false

func _ready() -> void:
	super._ready()
	# 시안 적용 범위는 요청한 하수도 스테이지뿐. 공용 집/테스트 씬은 그대로 둔다.
	var 조상: Node = self
	while 조상 != null:
		if 조상.scene_file_path.begins_with("res://scenes/world_2_클로드/stage_"):
			_하수도_입구연출 = true
			break
		조상 = 조상.get_parent()
	if not _하수도_입구연출 or Engine.is_editor_hint():
		return
	var 수면 := 입구_수면_스크립트.new()
	수면.name = "InletWaterSurface"
	add_child(수면)  # 실행 전용: owner를 주어 씬에 중복 저장하지 않는다.
	입구_상태_갱신.connect(수면.상태_받기)
	set_physics_process(true)  # 출구 미연결 호퍼에서도 유입색을 표시한다.
	queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _하수도_입구연출 or Engine.is_editor_hint() or 출구방향 != 0:
		return
	# 출구가 허공에서 시작하는 기존 배치는 포트에 붙이되, 바닥 끝 좌표는 보존한다.
	var 포트 := get_node_or_null("출구_포트") as Marker2D
	if not is_instance_valid(_출구) or 포트 == null:
		return
	if _출구.global_position.distance_squared_to(포트.global_position) < 0.01:
		return
	var 기존끝 := _출구.to_global(Vector2(0.0, _출구.크기.y))
	var 새길이 := _출구.to_local(기존끝).y - _출구.to_local(포트.global_position).y
	if 새길이 <= 0.0:
		return
	_출구.global_position = 포트.global_position
	_출구.크기 = Vector2(_출구.크기.x, 새길이)

func 입구_아트_배율() -> Vector2:
	return Vector2(폭 / 400.0, 높이 / 328.0)
@export_enum("직하:0", "좌하:1", "우하:2") var 출구방향: int = 0:
	set(value):
		출구방향 = clampi(value, 0, 2)
		_다시_만들기()

## [2026-09-27] 출구 물 너비를 **노즐 안지름에 맞춘다**(도형님 결정: "물의 너비를 호퍼 출구에 맞춘다").
## 관보다 넓은 물이 관 아래 허공에서 시작하던 것을 없앤다. 끄면 예전처럼 `출구_물줄기_폭` 을 쓴다.
## ⚠ 물이 좁아지면 판정 폭도 좁아진다 — 넓은 물막이 통로를 막던 곳은 옆으로 지나갈 수 있게 된다
##   (도형님 확인: "작아도 돼"). 어느 호퍼가 그런지는 tools/진단_호퍼출구_물막.gd 로 잰다.
## 좌하·우하(곡선 출수)는 노즐 모양이 달라 맞추지 않는다.
@export var 출구폭_노즐에_맞춤: bool = true:
	set(value):
		출구폭_노즐에_맞춤 = value
		_출구_물줄기_크기_갱신()

func 노즐_안지름() -> float:
	return 폭 * 노즐_안지름_비율

func _출구_물줄기_크기_갱신() -> void:
	if not 출구폭_노즐에_맞춤 or 출구방향 != 0:
		super._출구_물줄기_크기_갱신()
		return
	# 부모 함수와 같은 순서로 대상을 찾되 폭만 노즐 안지름으로 쓴다.
	# (`출구_물줄기_폭` 에 대입하면 그 setter 가 다시 이 함수를 불러 무한히 돈다 — 직접 계산한다)
	var 대상 := _출구
	if 대상 == null and not 출구_유체.is_empty() and is_inside_tree():
		대상 = get_node_or_null(출구_유체) as 유체
	if 대상 == null:
		return
	var 새크기 := 대상.크기
	새크기.x = 노즐_안지름()
	if 출구_물줄기_길이 >= 0.0:
		새크기.y = 출구_물줄기_길이
	if 대상.크기 != 새크기:
		대상.크기 = 새크기

func _다시_만들기() -> void:
	super._다시_만들기()
	if not is_inside_tree():
		return
	# 폭이 바뀌면 노즐 안지름도 바뀐다 → 물 너비를 다시 맞춘다
	_출구_물줄기_크기_갱신()
	# 몸통 목을 원점으로 유지하고 실제 노즐 끝으로 출구 포트만 옮긴다.
	# 연결된 물의 위치/판정은 임의로 회전시키지 않는다. 맵 제작 시 포트에 맞춘다.
	var port := get_node_or_null("출구_포트") as Marker2D
	if port != null:
		var offset := Vector2(0,112) if 출구방향 == 0 else Vector2(-85 if 출구방향 == 1 else 85, 90)
		port.position = offset * Vector2(폭 / 400.0, 높이 / 328.0)
	queue_redraw()

func _draw() -> void:
	# 투명 배경 원본의 셀을 직접 그려 색칠/발판 충돌과 아트 스케일을 분리한다.
	_주철_그리기(입구_아트_배율(), 출구방향)

func _주철_그리기(ratio: Vector2, 방향: int) -> void:
	# 평면 출구 아래 원화의 타원 잔여가 남지 않게 실제 포트(y700)에서 그림만 자른다.
	var 셀높이 := 460.0 if _하수도_입구연출 and 방향 == 0 else 480.0
	var destination := Rect2(Vector2(-256.0 * ratio.x, -높이 - 20.0 * ratio.y), Vector2(512, 셀높이) * ratio)
	draw_texture_rect_region(주철_아틀라스, destination, Rect2(512 * 방향, 240, 512, 셀높이))
