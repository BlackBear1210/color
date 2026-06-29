extends Node2D
## 진자 칼날 장애물 (PendulumBlade)
## 이 노드의 원점(피벗)을 중심으로 칼날이 좌우로 흔들린다. 칼날에 닿으면 사망.
## 톱니(GearObstacle)처럼 일정 속도로 도는 게 아니라, 사인파로 좌우 끝에서
## 속도가 0으로 줄었다가 반대로 가속하는 '진짜 진자' 운동을 한다.
## → 플레이어가 진동 주기(period)를 보고, 칼날이 반대편으로 비켜난 타이밍에 통과해야 한다.

@export var amplitude_degrees: float = 45.0   # 좌우 최대 스윙 각도 (수직 기준)
@export var period: float = 2.0               # 왕복 1회(왼쪽→오른쪽→왼쪽)에 걸리는 시간(초)
@export var phase_offset: float = 0.0         # 시작 위상(초). 같은 장애물을 여러 개 배치할 때
											   # 타이밍을 서로 어긋나게 만들고 싶으면 조절

var _elapsed: float = 0.0

@onready var kill_area: Area2D = $Blade/KillArea


func _ready() -> void:
	add_to_group("obstacle")  # 총알 PaintMark 차단
	kill_area.body_entered.connect(_on_kill_area_entered)
	_elapsed = phase_offset


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var angular_speed: float = TAU / maxf(period, 0.01)
	# sin() 이라서 양 끝(±amplitude)에서 속도가 자연스럽게 0이 됨(진짜 진자처럼).
	# 톱니(GearObstacle)의 왕복 이동도 같은 이유로 사인파로 바꾼 적이 있다(끝점 떨림 방지).
	rotation_degrees = sin(_elapsed * angular_speed) * amplitude_degrees


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")
