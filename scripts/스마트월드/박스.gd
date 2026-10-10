@tool
extends CharacterBody2D
## 색이 없는 무게 상자. 어느 플레이어든 밀 수 있고 압력 버튼을 계속 누를 수 있다.

@export_range(20.0, 600.0, 1.0) var 밀기_속도: float = 220.0
@export_range(0.0, 2400.0, 1.0) var 낙사_y: float = 1900.0
## [2026-10-09 Claude · 쳅터1 15] 켜면 플레이어가 죽어 부활할 때 상자도 처음 자리로 돌아간다(그룹 "부활복구").
##   왜: 쳅터1 마당에서는 상자를 구석으로 밀어 넣으면 다시 꺼낼 수 없다(밀기만 된다) → 죽으면 퍼즐이 처음으로.
##   하수도 스테이지는 기본값 false 라 예전과 똑같다.
@export var 부활하면_제자리: bool = false

const 중력: float = 1200.0
const 최대_낙하속도: float = 1500.0
const 접지그림 = preload("res://scripts/스마트월드/이동물체_접지그림.gd")
var _그림보정 := 0.0
var _바닥깊이 := 0.0
var _리스폰_월드좌표: Vector2 = Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("박스")
	_리스폰_월드좌표 = global_position
	if 부활하면_제자리:
		add_to_group("부활복구")
	# 상자는 플레이어·지형과만 충돌한다. 버튼의 Area2D는 그룹으로 따로 감지한다.
	collision_layer = 1
	collision_mask = 1


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + 중력 * delta, 최대_낙하속도)
	else:
		velocity.y = 0.0
	move_and_slide()
	# 새로 누적하지 않고 현재 바닥에서 다시 구한다. 밀거나 떨어진 후에도 접지 중앙이 지형을 따른다.
	var 접지 := 접지그림.보정(self, 0.0, _바닥깊이)
	_바닥깊이 = 접지.y
	if not is_equal_approx(_그림보정, 접지.x):
		_그림보정 = 접지.x
		queue_redraw()
	if global_position.y > 낙사_y:
		global_position = _리스폰_월드좌표
		velocity = Vector2.ZERO


## [2026-10-09] 월드 `_리스폰` → "부활복구" 그룹(부활하면_제자리 일 때만 그룹에 든다)
func 부활_복구() -> void:
	global_position = _리스폰_월드좌표
	velocity = Vector2.ZERO


## 색이 없는 물체라 플레이어색은 받기만 하고 판정에는 쓰지 않는다.
func 밀기(방향: float, _플레이어색: int) -> void:
	if 방향 == 0.0:
		return
	# 플레이어가 밀었는데 한 프레임 뒤에 움직이면 손맛이 끊기므로 즉시 짧게 이동한다.
	var 이동거리 := minf(밀기_속도 * get_physics_process_delta_time(), 14.0)
	move_and_collide(Vector2(signf(방향) * 이동거리, 0.0))
	velocity.x = 0.0


func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return -1


func 반대색인가(_플레이어색: int) -> bool:
	return false


## ★[2026-09-30 Claude] 주철 무게 궤짝 그림(시안 1 확정). 굽는 곳 = `tools/생성_박스_주철.py`(손으로 그리지 말 것).
##   preload 가 아니라 load 인 이유: PNG 가 에디터에서 아직 임포트 안 됐으면 preload 는 **스크립트 전체가 파싱 실패**해
##   박스가 통째로 사라진다. load 는 null 을 주고 아래 옛 그림으로 넘어간다.
const 주철_그림_경로 := "res://assets/textures/obstacles/box/cast_iron_v1/box.png"
## 그림(104x102) 안에서 노드 원점(바닥 중앙)이 놓인 자리. 판정 96x96 = 그림 (4,4)~(100,100). 굽는 도구의 OX·OY 와 같아야 한다.
const 그림_원점 := Vector2(52.0, 100.0)
static var _주철_그림: Texture2D = null

## [2026-10-09 Claude · 쳅터1 15] 생김새 — 0 = 하수도 주철 궤짝(예전 그대로) / 1 = 쳅터1 나무 상자.
##   도형님: "너무 기존의 지형 이미지와 안 어울려 · 기존 타일셋과 어울리게" → 저택 가구 '상자더미' 와 같은 말:
##   어두운 판자 줄 + X 버팀목 + 모서리 쇠 덧댐 + 2.5D 윗면(목재 데크와 같은 위 왼쪽 빛). 판정(96×96)은 같다.
@export_enum("주철 궤짝", "쳅터1 나무 상자") var 생김새: int = 0:
	set(v):
		생김새 = v
		queue_redraw()

## 켜면 예전 코드 그림(회색 사각형 + X)으로 돌아간다 — 비교·문제 확인용.
@export var 옛_그림: bool = false:
	set(v):
		옛_그림 = v
		queue_redraw()


func _draw() -> void:
	# 앞면은 중앙에서 (+9,+11), 뒷면은 (-9,-11)이다. 밑면과 윗면의 중심이 모두 충돌선+지형 깊이에 온다.
	draw_set_transform(Vector2(9, _그림보정 + 11))
	if 생김새 == 1:
		_나무상자_그리기()
		return
	if not 옛_그림:
		if _주철_그림 == null and ResourceLoader.exists(주철_그림_경로):
			_주철_그림 = load(주철_그림_경로) as Texture2D
		if _주철_그림 != null:
			_주철_원근면()
			draw_texture(_주철_그림, -그림_원점)
			return
	draw_rect(Rect2(-48, -96, 96, 96), Color(0.28, 0.27, 0.25), true)
	draw_rect(Rect2(-48, -96, 96, 96), Color(0.68, 0.66, 0.60), false, 3.0)
	draw_line(Vector2(-42, -88), Vector2(42, -8), Color(0.14, 0.13, 0.12), 4.0)
	draw_line(Vector2(42, -88), Vector2(-42, -8), Color(0.14, 0.13, 0.12), 4.0)

func 발_그림_깊이() -> float:
	# 이 상자 위에 선 플레이어도 상판의 중앙을 밟도록 그림 깊이를 전달한다.
	return _그림보정

func _주철_원근면() -> void:
	# 기존 정면의 금속 가장자리만 UV로 빌린다. 상자 전체를 기울이지 않고 앞면·상판·옆면을 분리한다.
	var back := Vector2(-18, -22)
	var tl := Vector2(-48, -96)
	var tr := Vector2(48, -96)
	var bl := Vector2(-48, 0)
	var size := _주철_그림.get_size()
	var top_uv := PackedVector2Array([Vector2(4, 16) / size, Vector2(100, 16) / size, Vector2(100, 4) / size, Vector2(4, 4) / size])
	var side_uv := PackedVector2Array([Vector2(16, 4) / size, Vector2(16, 100) / size, Vector2(4, 100) / size, Vector2(4, 4) / size])
	draw_polygon(PackedVector2Array([tl, tr, tr + back, tl + back]), PackedColorArray([Color(1.12, 1.12, 1.12), Color(1.12, 1.12, 1.12), Color.WHITE, Color.WHITE]), top_uv, _주철_그림)
	draw_polygon(PackedVector2Array([tl, bl, bl + back, tl + back]), PackedColorArray([Color(0.7, 0.7, 0.7), Color(0.6, 0.6, 0.6), Color(0.55, 0.55, 0.55), Color(0.65, 0.65, 0.65)]), side_uv, _주철_그림)
	draw_polyline(PackedVector2Array([bl + back, tl + back, tr + back, tr]), Color(0.10, 0.10, 0.10), 1.0, true)


## [2026-10-09] 쳅터1 나무 상자 — 96×96 · 원점 = 바닥 가운데. 목재 데크·가구 상자더미와 같은 어두운 회색 판자.
func _나무상자_그리기() -> void:
	var 나무 := Color(0.17, 0.165, 0.16)
	var 나무밝 := Color(0.30, 0.29, 0.28)
	var 줄 := Color(0.07, 0.07, 0.07)
	var 쇠 := Color(0.36, 0.35, 0.33)
	# 정면 윗변도 실제 96px 충돌 높이에 맞춰 상자 위 발과 상판 중앙의 높이를 일치시킨다.
	var 앞 := Rect2(-48, -96, 96, 96)
	draw_rect(Rect2(-45, -2, 96, 5), Color(0, 0, 0, 0.4))                  # 바닥 그늘
	draw_rect(앞, 나무)
	# 판자 줄(가로 4장) · 결
	for i in 4:
		var y := -96.0 + 24.0 * i
		draw_line(Vector2(-48, y), Vector2(48, y), 줄, 2.0)
		draw_line(Vector2(-44, y + 9), Vector2(-10, y + 10), 나무밝.darkened(0.35), 1.0)
		draw_line(Vector2(6, y + 14), Vector2(42, y + 13), 나무밝.darkened(0.35), 1.0)
	# 테두리 틀 + X 버팀목
	draw_rect(앞, 줄, false, 5.0)
	draw_line(Vector2(-42, -90), Vector2(42, -6), 나무밝, 9.0)
	draw_line(Vector2(-42, -90), Vector2(42, -6), 줄, 2.0)
	draw_line(Vector2(42, -90), Vector2(-42, -6), 나무밝, 9.0)
	draw_line(Vector2(42, -90), Vector2(-42, -6), 줄, 2.0)
	# 2.5D 윗면(위 왼쪽 빛)
	# 목재도 동일한 (-18,-22) 사선을 쓴다. 좌우 대칭 사다리꼴은 지형의 한 방향 투영과 맞지 않았다.
	draw_colored_polygon(PackedVector2Array([Vector2(-48, -96), Vector2(48, -96), Vector2(30, -118), Vector2(-66, -118)]), 나무밝)
	draw_colored_polygon(PackedVector2Array([Vector2(-48, -96), Vector2(-48, 0), Vector2(-66, -22), Vector2(-66, -118)]), 나무.darkened(0.3))
	draw_line(Vector2(-66, -118), Vector2(30, -118), 나무밝.lightened(0.2), 1.5)
	# 모서리 쇠 덧댐 + 못
	for c in [Vector2(-48, -96), Vector2(40, -96), Vector2(-48, -8), Vector2(40, -8)]:
		draw_rect(Rect2(c, Vector2(8, 8)), 쇠)
		draw_circle(c + Vector2(4, 4), 1.4, 줄)
