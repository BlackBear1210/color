extends CharacterBody2D
## [프로토타입] 테스트_월드_24x24 전용 총알.
## 발사 방향으로 날아가다 타일(콜리전)에 부딪히면, "그 충돌 지점"에서
## 물감 마스크에 명중 신호를 보낸다 — 마우스 클릭 지점이 아니라 실제로 맞은 지점 기준.

const 속도: float = 900.0
const 최대_수명: float = 2.0   ## 이 시간 안에 아무것도 안 맞으면 그냥 사라짐 (허공 낭비 방지)

var 색: int = ColorDefs.BLACK
var _대상: Node                ## 명중(world_pos, color) 을 가진 노드 (테스트_월드_24x24)
var _수명: float = 0.0

func 시작(방향: Vector2, 색상: int, 대상: Node) -> void:
	velocity = 방향.normalized() * 속도
	색 = 색상
	_대상 = 대상
	collision_layer = 0
	collision_mask = 1
	queue_redraw()

func _physics_process(delta: float) -> void:
	_수명 += delta
	if _수명 > 최대_수명:
		queue_free()
		return
	var 충돌 := move_and_collide(velocity * delta)
	if 충돌:
		if _대상 and _대상.has_method("명중"):
			_대상.명중(충돌.get_position(), 색)
		queue_free()

## 눈에 보이게 작은 원으로 표시 (콜리전과 별개, 순수 시각용)
func _draw() -> void:
	var c := Color(0.08, 0.08, 0.08) if 색 == ColorDefs.BLACK else Color(0.95, 0.95, 0.95)
	draw_circle(Vector2.ZERO, 4.0, c)
