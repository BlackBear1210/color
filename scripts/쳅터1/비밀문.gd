@tool
extends StaticBody2D
## ============================================================================
## [2026-10-09 Claude 신규] 비밀문 — 숨은 길목 앞을 막고 선 책장. 장치(레버 퍼즐)가 풀리면 옆으로 밀려 길이 열린다
## ----------------------------------------------------------------------------
## ▣ 도형님 아이디어(10-09): 패턴을 맞추면 "특별 스테이지로 가는 기믹이 활성화되어 그 장소로 통하는 통로를 카메라 무빙으로
##   비추어 준 다음 … 닫힌 통로의 길을 열어 주는 역할". 기획 §4-B 원칙 "포탈 금지 · 새 길은 장치로 연다" 와 같다.
## ▣ 열기(): 1.2초 동안 `밀림` 만큼 옆으로 미끄러진다(먼지 · 덜컹) → 판정 해제. 닫기(): 거꾸로.
##   `제한시간` 이 있는 퍼즐은 시간이 다 되면 닫힌다. 단, 플레이어가 **한 번 지나가면 영구히 열린 채**로 둔다
##   (특별 스테이지에서 돌아올 때 길목이 막혀 갇히지 않게 — 갇힘 금지 원칙).
## ▣ 그림: 배경 가구 원화 `책장.png`(7×12칸) — 방에 원래 있는 책장 하나가 사실은 문이다.
## ▣ 원점 = 책장 바닥 가운데(발 닿는 선). 판정 = 책장 전체(통로를 다 막는다).
## ============================================================================

const 그림 := "res://assets/background/쳅터1/레이어_v01/가구/책장.png"

@export var 크기: Vector2 = Vector2(224, 384):      ## 7×12 칸
	set(v): 크기 = v; _재구성()
## 열릴 때 미끄러지는 거리·방향(px). 기본 = 오른쪽으로 책장 폭만큼.
@export var 밀림: Vector2 = Vector2(224, 0)
@export var 열림: bool = false
## [2026-10-09 거미방] 생김새 — 책장(배경 가구 원화) / 창살(코드 그림 · 위로 들어 올리는 쇠창살 문). 판정은 같다.
@export_enum("책장:0", "창살:1") var 모양: int = 0:
	set(v): 모양 = v; _재구성()

signal 열림_바뀜(열림: bool)

var 영구 := false
var _진행 := 0.0              ## 0 닫힘 ~ 1 열림
var _목표 := 0.0
var _그림: Sprite2D
var _판정: CollisionShape2D
var _처음위치 := Vector2.ZERO
var _밀린 := Vector2.ZERO        ## 창살 모양이 그릴 때 쓰는 지금 밀린 거리


func _ready() -> void:
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("비밀문")
	_진행 = 1.0 if 열림 else 0.0
	_목표 = _진행
	_반영()


func _재구성() -> void:
	if not is_inside_tree():
		return
	if _그림 == null:
		_그림 = Sprite2D.new()
		_그림.centered = false
		_그림.texture = load(그림) if ResourceLoader.exists(그림) else null
		_그림.z_index = -2           # 배경 가구보다 앞, 플레이어(0)보다 뒤 — 플레이어가 책장 앞을 지나가 보인다
		add_child(_그림)
	if _그림.texture:
		_그림.scale = 크기 / Vector2(_그림.texture.get_size())
	_그림.visible = 모양 == 0
	z_index = -2 if 모양 == 1 else 0     # 창살도 책장처럼 플레이어 뒤 · 지형 뒤(위로 들리면 천장 속으로 숨는다)
	queue_redraw()
	_그림.position = Vector2(-크기.x * 0.5, -크기.y)
	if _판정 == null:
		_판정 = CollisionShape2D.new()
		_판정.shape = RectangleShape2D.new()
		add_child(_판정)
	(_판정.shape as RectangleShape2D).size = Vector2(크기.x * 0.6, 크기.y)
	_판정.position = Vector2(0, -크기.y * 0.5)


func 열기() -> void:
	_목표 = 1.0
	set_process(true)
	_덜컹()


func 닫기() -> void:
	if 영구:
		return
	_목표 = 0.0
	set_process(true)
	_덜컹()


func 열렸나() -> bool:
	return _진행 >= 0.99


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 한 번 지나간 뒤로는 영구히 열림 — 책장이 밀려난 자리(통로 쪽)에 몸이 들어가면
	if not 영구 and _진행 > 0.5:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			var 로컬 := to_local(p.global_position)
			if signf(로컬.x) == signf(-밀림.x) and absf(로컬.x) > 크기.x * 0.6 and absf(로컬.y) < 크기.y:
				영구 = true
	if _진행 == _목표:
		set_process(false)
		return
	# [2026-10-09] 닫히는 중인데 몸이 문간(닫힌 자리)에 서 있으면 기다린다 — 판정이 몸 위로 되살아나 갇히지 않게
	#   ('켜진 동안만' 빛받이가 반딧불이 떠나 문을 닫을 때 · 레버 퍼즐 양초 시간이 끝날 때)
	if _목표 < _진행 and _문간에_몸이_있나():
		return
	_진행 = move_toward(_진행, _목표, delta / 1.2)
	_반영()
	if _진행 == _목표:
		열림 = _목표 >= 1.0
		열림_바뀜.emit(열림)


func _문간에_몸이_있나() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	var 로컬 := to_local(p.global_position)
	return absf(로컬.x) < 크기.x * 0.3 + 26.0 and 로컬.y > -크기.y - 10.0 and 로컬.y < 10.0


func _반영() -> void:
	var k := _진행 * _진행 * (3.0 - 2.0 * _진행)        # smoothstep — 무거운 가구가 밀리기 시작·멈춤
	_그림.position = Vector2(-크기.x * 0.5, -크기.y) + 밀림 * k + Vector2(sin(_진행 * 60.0) * 1.2 * (1.0 - absf(_진행 - _목표)), 0.0)
	_판정.position = Vector2(0, -크기.y * 0.5) + 밀림 * k
	_밀린 = 밀림 * k
	if 모양 == 1:
		queue_redraw()
	_판정.set_deferred("disabled", _진행 >= 0.85)


func _덜컹() -> void:
	var 카메라 := get_tree().get_first_node_in_group("주카메라")
	if 카메라 and 카메라.has_method("add_trauma"):
		카메라.add_trauma(0.15)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.5
	p.amount = 14
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(크기.x * 0.45, 4)
	p.position = Vector2(0, -4)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.5, 0.48, 0.44, 0.6)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


## [2026-10-09] 창살 모양 — 쇠 테 + 세로 창살 + 가로대 두 줄 + 아래 뾰족 끝(임시 코드 그림 · 아스트라 그림이 오면 바꾼다)
func _draw() -> void:
	if 모양 != 1:
		return
	var 쇠 := Color(0.13, 0.12, 0.11)
	var 밝 := Color(0.32, 0.3, 0.27)
	var o := Vector2(-크기.x * 0.5, -크기.y) + _밀린
	var 수 := maxi(int(크기.x / 22.0), 3)
	for i in 수:
		var x := o.x + 6.0 + (크기.x - 12.0) * float(i) / float(수 - 1)
		draw_line(Vector2(x, o.y), Vector2(x, o.y + 크기.y - 10.0), 쇠, 7.0)
		draw_line(Vector2(x - 2.0, o.y), Vector2(x - 2.0, o.y + 크기.y - 10.0), 밝, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, o.y + 크기.y - 12), Vector2(x + 5, o.y + 크기.y - 12), Vector2(x, o.y + 크기.y)]), 쇠)
	for fy in [0.12, 0.55]:
		draw_rect(Rect2(o + Vector2(0, 크기.y * fy), Vector2(크기.x, 10)), 쇠)
		draw_line(o + Vector2(0, 크기.y * fy + 2), o + Vector2(크기.x, 크기.y * fy + 2), 밝, 1.5)
