extends CharacterBody2D
## 색 추적자 (ColorTracker)
## 플레이어가 'recognize_color'와 같은 색일 때만 인식해서 직선으로 쫓아오고,
## 플레이어가 반대 색으로 바꾸면 시야에서 놓쳐 추적을 멈춘다.
## → "들키면 색을 바꿔서 회피"하는 스텔스형 적.
##
## 비행형(중력 없음)으로 만들어서 지형을 신경 쓰지 않고 플레이어를 향해 직선으로
## 날아온다(드론/눈알 같은 추적자 컨셉). 지형 충돌을 받게 하려면 collision_mask 를
## 지형 레이어로 바꾸면 된다.

@export_enum("BLACK:0", "WHITE:1") var recognize_color: int = ColorDefs.BLACK
@export var detect_radius: float = 260.0     # 이 거리 안에 있어야 인식 가능
@export var chase_speed: float = 160.0       # 추적 중 속도(px/s)
@export var acceleration: float = 500.0      # 속도 변화 가속도(px/s^2) — 급가속/급정거 방지
@export var lose_sight_delay: float = 0.4    # 인식 조건이 깨진 뒤에도 이 시간만큼은 추적 유지(너무 칼같이 멈추면 어색해서 약간의 유예)

var _player: Node = null
var _aware: bool = false
var _lost_timer: float = 0.0

@onready var kill_area: Area2D = $KillArea
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("obstacle")  # 총알 PaintMark 차단
	kill_area.body_entered.connect(_on_kill_area_entered)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	_update_awareness(delta)

	var target_velocity := Vector2.ZERO
	if _aware and _player:
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() > 1.0:
			target_velocity = to_player.normalized() * chase_speed

	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	move_and_slide()
	_update_visual()


## 인식 여부 갱신: 거리 안 + 플레이어 색이 recognize_color 와 같아야 인식.
## 조건이 깨져도 lose_sight_delay 동안은 추적을 유지하다가 그 뒤에 완전히 놓친다.
func _update_awareness(delta: float) -> void:
	if _player == null or not _player.has_method("get_player_color"):
		_aware = false
		return

	var in_range := global_position.distance_to(_player.global_position) <= detect_radius
	var color_match: bool = _player.get_player_color() == recognize_color

	if in_range and color_match:
		_aware = true
		_lost_timer = lose_sight_delay
	elif _lost_timer > 0.0:
		_lost_timer -= delta
		_aware = _lost_timer > 0.0
	else:
		_aware = false


## 인식 상태를 비주얼로 표시: 인식 중(추적)=경고색으로 진하게, 못 알아챔=옅게 가라앉음.
func _update_visual() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1.0, 0.3, 0.3, 1.0) if _aware else Color(1.0, 1.0, 1.0, 0.5)


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
