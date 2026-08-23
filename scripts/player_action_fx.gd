extends Node2D
## 플레이어 행동에만 반응하는 짧은 파티클 효과.
## 몸의 색은 경계에서 바뀔 수 있으므로, 호출 순간에 받은 색만 써서 그림과 판정이 어긋나지 않게 한다.

const 점프_개수 := 10
const 명중_개수 := 20

@export_group("파티클 크기")
## Player > ActionFX 인스펙터에서 점프·발사 파티클을 함께 키우거나 줄인다.
@export_range(0.25, 3.0, 0.05) var 크기_배율 := 1.0

var _먼지_텍스처: Texture2D
var _물감_텍스처: Texture2D


func 점프(색: int) -> void:
	# 점프는 색을 옅게 머금은 흙먼지가 발밑에서 짧게 밀려 나가는 정도로만 보인다.
	_먼지_뿌리기(global_position + Vector2(0, -2), 색, 점프_개수, 75.0, 64.0, 0.24, 0.22)


func 착지(색: int, 낙하속도: float) -> void:
	if 낙하속도 < 180.0:
		return
	# 큰 착지일수록 먼지가 옆으로 넓게 퍼진다. 평지 이동에는 반응하지 않는다.
	var 세기 := clampf(낙하속도 / 900.0, 0.0, 1.0)
	var 개수 := roundi(lerpf(6.0, 12.0, 세기))
	_먼지_뿌리기(global_position + Vector2(0, -1), 색, 개수, 108.0,
		lerpf(52.0, 116.0, 세기), 0.30 + 세기 * 0.10, 0.30)


func 명중(지점: Vector2, 속도: Vector2, 색: int) -> void:
	# 충돌점에는 먼저 납작한 얼룩을 남기고, 그 둘레에서 작은 페인트 조각만 튄다.
	_물감_얼룩(지점, 색)
	_물감_뿌리기(지점, -속도.normalized(), 색)


func _먼지_뿌리기(위치: Vector2, 색: int, 개수: int, 퍼짐: float, 속도: float, 크기: float, 수명: float) -> void:
	_뿌리기(위치, Vector2.UP, _먼지_텍스처_가져오기(), _먼지색(색), 개수, 퍼짐, 속도, 크기, 720.0, 수명)


func _물감_뿌리기(위치: Vector2, 방향: Vector2, 색: int) -> void:
	_뿌리기(위치, 방향, _물감_텍스처_가져오기(), _물감색(색), 명중_개수, 92.0, 250.0, 0.50, 150.0, 0.46)


func _뿌리기(위치: Vector2, 방향: Vector2, 텍스처: Texture2D, 색상: Color, 개수: int, 퍼짐: float, 속도: float, 조각_크기: float, 중력: float, 수명: float) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.global_position = 위치
	p.z_as_relative = false
	p.z_index = 30
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 개수
	p.lifetime = 수명
	p.direction = 방향 if 방향 != Vector2.ZERO else Vector2.RIGHT
	p.spread = 퍼짐
	p.initial_velocity_min = 속도 * 0.45
	p.initial_velocity_max = 속도
	p.gravity = Vector2(0, 중력)
	p.scale_amount_min = 1.4 * 크기_배율 * 조각_크기
	p.scale_amount_max = 3.0 * 크기_배율 * 조각_크기
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.damping_min = 25.0
	p.damping_max = 55.0
	p.texture = 텍스처
	p.color = 색상
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


func _먼지색(색: int) -> Color:
	return Color(0.78, 0.78, 0.75, 0.48) if 색 == ColorDefs.WHITE else Color(0.15, 0.15, 0.16, 0.48)


func _물감색(색: int) -> Color:
	return Color(0.98, 0.98, 0.96, 1.0) if 색 == ColorDefs.WHITE else Color(0.04, 0.04, 0.05, 1.0)


func _먼지_텍스처_가져오기() -> Texture2D:
	if _먼지_텍스처:
		return _먼지_텍스처
	var 이미지 := Image.create_empty(12, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 12:
			var 거리 := Vector2((float(x) - 5.5) / 5.5, (float(y) - 3.5) / 2.8).length()
			var 알파 := clampf(1.1 - 거리, 0.0, 0.65)
			이미지.set_pixel(x, y, Color(1.0, 1.0, 1.0, 알파))
	_먼지_텍스처 = ImageTexture.create_from_image(이미지)
	return _먼지_텍스처


func _물감_텍스처_가져오기() -> Texture2D:
	if _물감_텍스처:
		return _물감_텍스처
	var 이미지 := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var 거리 := Vector2((float(x) - 3.5) / 3.4, (float(y) - 3.5) / 3.1).length()
			var 흔들림 := sin(float(x * 17 + y * 11)) * 0.13
			var 알파 := clampf(1.05 - 거리 + 흔들림, 0.0, 1.0)
			이미지.set_pixel(x, y, Color(1.0, 1.0, 1.0, 알파))
	_물감_텍스처 = ImageTexture.create_from_image(이미지)
	return _물감_텍스처


func _물감_얼룩(지점: Vector2, 색: int) -> void:
	var 얼룩 := Polygon2D.new()
	var 점들 := PackedVector2Array()
	for i in 11:
		var 각도 := TAU * float(i) / 11.0
		점들.append(Vector2.RIGHT.rotated(각도) * randf_range(5.0, 11.0))
	얼룩.polygon = 점들
	얼룩.color = _물감색(색)
	얼룩.top_level = true
	얼룩.global_position = 지점
	얼룩.z_as_relative = false
	얼룩.z_index = 29
	add_child(얼룩)
	var 트윈 := 얼룩.create_tween()
	트윈.tween_property(얼룩, "scale", Vector2(0.72, 0.72), 0.42)
	트윈.parallel().tween_property(얼룩, "modulate:a", 0.0, 0.42)
	트윈.tween_callback(얼룩.queue_free)
