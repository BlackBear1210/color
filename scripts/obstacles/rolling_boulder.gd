extends CharacterBody2D
## 굴러오는 바위 (RollingBoulder)
## 한쪽 방향으로 계속 가속하며 굴러오는 장애물(인디아나 존스식 추격 바위).
## 플레이어에 닿으면 즉사. '활성화된 블럭'(플레이어가 페인트로 만든 발판=
## paint_bodies 그룹)에 부딪히면 그 자리에서 박살나 사라진다.
## → 바위가 굴러올 길목에 미리 페인트를 칠해두면 막아서 없앨 수 있는 공략 포인트.

# 지형 레이어 (player.gd/platform.gd 와 일치) — 바위는 색 무관하게 모든 지형 위를 구른다.
const LAYER_BLACK: int = 1 << 1
const LAYER_WHITE: int = 1 << 2
const LAYER_GRAY:  int = 1 << 3

@export var max_speed: float = 480.0        # 최종 속도(px/s)
@export var acceleration: float = 260.0     # 가속도(px/s^2) — 이 값 때문에 갈수록 빨라진다
@export var gravity: float = 1000.0
@export var rotation_speed_factor: float = 0.02   # 속도 → 굴러가는 회전 속도 변환 비율

# 처음에 어느 방향으로 구를지: true=플레이어 쪽을 보고 자동 결정, false=direction_override 사용
@export var auto_face_player: bool = true
@export var direction_override: float = 1.0   # auto_face_player=false 일 때 -1(좌)/1(우)

var _direction: float = 1.0

@onready var kill_area: Area2D = $KillArea


func _ready() -> void:
	add_to_group("obstacle")  # 총알 PaintMark 차단
	kill_area.body_entered.connect(_on_kill_area_entered)
	collision_layer = 0
	collision_mask  = LAYER_BLACK | LAYER_WHITE | LAYER_GRAY

	_direction = direction_override
	if auto_face_player:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			_direction = 1.0 if player.global_position.x > global_position.x else -1.0


func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	# 계속 같은 방향으로 가속(중간에 멈추거나 방향을 안 바꿈 → "추격"보다는
	# "한번 굴러오기 시작하면 점점 빨라지는" 위협감을 준다).
	velocity.x = move_toward(velocity.x, max_speed * _direction, acceleration * delta)

	move_and_slide()

	# 굴러가는 비주얼 회전(속도에 비례)
	rotation += velocity.x * rotation_speed_factor * delta

	# 이번 프레임에 부딪힌 것 중 '활성화된 블럭'(페인트로 만든 발판)이 있으면 파괴
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("paint_bodies"):
			_explode()
			return


func _on_kill_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")


## 활성화된 블럭에 부딪혀 박살날 때 호출.
func _explode() -> void:
	# TODO: 파괴 파티클/사운드는 추후 연출 추가
	queue_free()
