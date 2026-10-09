@tool
extends "res://scripts/player_anim.gd"
## 새 시트만 연결해 팀 소유 이동 모션의 발 정렬·경사 보정을 그대로 이용한다.
## 탄약과 발사 신호는 총에서 받아 입력 실패나 빈 탄창에 반동이 나오는 일을 막는다.

const 잔량_셰이더 := preload("res://shaders/paint_head.gdshader")
const 탱크_데이터 := preload("res://assets/characters/paint_head_a/tank_rects.gd")
var _탄약: Node
var _발사_남음: float = 0.0
var _탱크_좌표: Dictionary = {}

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		# 기존 발 깊이 보정에 접지 그림자를 더한다. 물리 몸은 그대로여서 점프 높이와 색 규칙을 바꾸지 않는다.
		if _player.get_node_or_null("발접지") == null:
			var 접지 := preload("res://scripts/발_접지그림.gd").new()
			접지.name = "발접지"
			_player.add_child.call_deferred(접지)
		# 부모가 색분할 재질을 만든 다음 교체해야 기존 색 경계 갱신을 함께 받는다.
		call_deferred("_재질_준비")

func _재질_준비() -> void:
	_탱크_좌표 = 탱크_데이터.FRAMES
	for 시트 in [self, get_node_or_null("색겹침")]:
		if 시트 != null and 시트.material is ShaderMaterial:
			시트.material.shader = 잔량_셰이더

func 연결_총(총: Node, 탄약: Node = null) -> void:
	_탄약 = 탄약
	if 총 != null and 총.has_signal("fired") and not 총.is_connected("fired", _발사됨):
		총.connect("fired", _발사됨)

func _발사됨() -> void:
	# 입력 지연 없이 총을 든 발사 자세부터 재생하고 회복 자세로 끝낸다.
	_발사_남음 = 12.0 / 45.0
	flip_h = get_global_mouse_position().x < _player.global_position.x
	# 연사 때도 반동을 다시 시작하되 실제 투사체는 기존 총에서 한 번만 만든다.
	play(_color + "_shoot")
	set_frame_and_progress(0, 0.0)

func 총구_월드좌표() -> Vector2:
	# 기존 입 좌표는 색 판정용으로 보존하고, 실제 탄·조준선은 새 그림의 총구에서 시작한다.
	var 좌표: Array = 탱크_데이터.MUZZLES[_color][4]
	var 점 := Vector2(float(좌표[0]) - 320.0, float(좌표[1]) - 320.0)
	if get_global_mouse_position().x < _player.global_position.x:
		점.x = -점.x
	return to_global(점)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_발사_남음 = maxf(_발사_남음 - delta, 0.0)
	super._process(delta)
	if _발사_남음 > 0.0:
		flip_h = get_global_mouse_position().x < _player.global_position.x
	_잔량_갱신()

func _switch(full: String) -> void:
	# 사망은 발사보다 우선하고, 밀기는 실제 밀 수 있는 물체와 접촉한 동안만 보인다.
	if not full.ends_with("_death"):
		if _발사_남음 > 0.0:
			full = _color + "_shoot"
		elif _밀고_있나():
			full = _color + "_push"
	super._switch(full)

func _밀고_있나() -> bool:
	if _player == null or not _player.is_on_floor():
		return false
	var 방향 := Input.get_axis("move_left", "move_right")
	if absf(방향) < 0.1:
		return false
	for i in range(_player.get_slide_collision_count()):
		var 충돌 := _player.get_slide_collision(i)
		var 물체 := 충돌.get_collider()
		if 물체 != null and 물체.has_method("밀기") and 충돌.get_normal().x * 방향 < -0.7:
			flip_h = 방향 < 0.0
			return true
	return false

func _잔량_갱신() -> void:
	var 비율: float = 1.0
	if is_instance_valid(_탄약):
		var 최대 = _탄약.get("최대_탄약")
		var 남음 = _탄약.get("남은_탄약")
		if 최대 != null and 남음 != null and float(최대) > 0.0:
			# 비행 중인 탄은 이미 소모된 탄이므로 HUD의 회수 가능 합계가 아닌 실제 잔량을 쓴다.
			비율 = clampf(float(남음) / float(최대), 0.0, 1.0)
	var 동작 := String(animation).get_slice("_", 1)
	var 원본 := "jump" if 동작 in ["jump", "fall", "land"] else 동작
	var 원본_프레임 := frame
	if 동작 == "jump":
		원본_프레임 += 2
	elif 동작 == "fall":
		원본_프레임 += 8
	elif 동작 == "land":
		원본_프레임 += 12
	elif 동작 == "shoot":
		원본_프레임 += 4
	for 시트 in [self, get_node_or_null("색겹침")]:
		if 시트 == null or not 시트.material is ShaderMaterial:
			continue
		var 색 := _color if 시트 == self else ("white" if _color == "black" else "black")
		var 키 := 색 + "_" + 원본
		# 새 대기 루프도 프레임마다 수위를 맞추고, 미생성 색은 기존 정지 자세를 쓴다.
		var 표시_프레임 := 원본_프레임
		if 원본 == "idle" and not _탱크_좌표.has(키):
			키 = 색 + "_walk"
			표시_프레임 = 0
		if _탱크_좌표.has(키):
			var 좌표: Array = _탱크_좌표[키][표시_프레임]
			시트.material.set_shader_parameter("tank_rect", Vector4(좌표[0], 좌표[1], 좌표[2], 좌표[3]))
		시트.material.set_shader_parameter("paint_fill", 비율)
		시트.material.set_shader_parameter("tank_enabled", 원본 != "death")

func 사망_재생() -> void:
	# 본체의 마지막 프레임까지 기다린 뒤에만 월드가 체크포인트로 이동시킨다.
	_발사_남음 = 0.0
	var 선택: int = _player.call("선택색")
	_color = "black" if 선택 == ColorDefs.BLACK else "white"
	play(_color + "_death")
	set_frame_and_progress(0, 0.0)
	await animation_finished
