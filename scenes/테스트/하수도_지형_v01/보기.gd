extends Node2D
## 게임 조작과 충돌 규칙을 건드리지 않고 재질과 시차만 비교하기 위한 관찰용 카메라다.
@onready var camera: Camera2D = $Camera2D

func _process(delta: float) -> void:
	# 이동 범위를 제한해 준비한 배경 바깥 빈 공간이 시험 화면에 나타나지 않게 한다.
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	camera.position += direction.normalized() * 280.0 * delta
	camera.position = camera.position.clamp(Vector2(700, 450), Vector2(1200, 650))
