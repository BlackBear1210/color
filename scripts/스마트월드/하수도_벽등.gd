@tool
extends Node2D
## 시안의 세로형 철제 벽등: 광원 크기와 주변 벽의 조명을 분리한다.
## 동심원 겹치기는 띠가 생기므로 부드러운 방사형 그라데이션 텍스처를 사용한다.
@export_range(0.0, 1.0) var 빛번짐: float = 0.3:
	set(value):
		빛번짐 = value
		queue_redraw()
## 2-9에서 검토하는 입체 본체만 선택한다. 다른 스테이지에 미검증 외관을 전파하지 않는다.
@export var 입체_본체: bool = false
var _빛: GradientTexture2D

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.84, 0.84, 0.84, 0.5), Color(0.76, 0.76, 0.76, 0.22), Color(0.66, 0.66, 0.66, 0.06), Color(0.6, 0.6, 0.6, 0.0)])
	_빛 = GradientTexture2D.new()
	_빛.gradient = gradient
	_빛.width = 256
	_빛.height = 256
	_빛.fill = GradientTexture2D.FILL_RADIAL
	_빛.fill_from = Vector2(0.5, 0.5)
	_빛.fill_to = Vector2(1.0, 0.5)
	if 입체_본체:
		# 빛 번짐과 본체를 분리해 기존 광원 범위/밝기는 보존한다.
		for center in [Vector2(190, 145), Vector2(735, 465)]:
			var body := ColorRect.new()
			body.name = "주철벽등본체%d" % get_child_count()
			body.position = center - Vector2(44, 55)
			body.size = Vector2(88, 110)
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var surface := ShaderMaterial.new()
			surface.shader = preload("res://shaders/sewer_lamp_volume.gdshader")
			body.material = surface
			add_child(body) # 실행/미리보기 전용: owner를 지정하지 않는다.
	queue_redraw()

func _draw() -> void:
	for center in [Vector2(190, 145), Vector2(735, 465)]:
		if _빛 != null:
			draw_texture_rect(_빛, Rect2(center - Vector2(100, 110), Vector2(200, 220)), false, Color(1, 1, 1, 빛번짐 * 2.0))
		if 입체_본체:
			continue
		# 광원 중심은 세로로 긴 타원형 철망. 네모난 흰 표시로 보이지 않게 한다.
		draw_line(center + Vector2(0, -27), center + Vector2(0, -43), Color(0.09, 0.09, 0.09), 3.0, true)
		draw_set_transform(center, 0.0, Vector2(0.58, 1.0))
		draw_circle(Vector2.ZERO, 26.0, Color(0.09, 0.09, 0.09))
		draw_circle(Vector2.ZERO, 23.0, Color(0.34, 0.34, 0.34))
		draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.85, 0.85))
		draw_set_transform(Vector2.ZERO)
		for x in [-6.0, 0.0, 6.0]:
			draw_line(center + Vector2(x, -20), center + Vector2(x, 20), Color(0.16, 0.16, 0.16), 1.6, true)
		for y in [-10.0, 10.0]:
			draw_line(center + Vector2(-11, y), center + Vector2(11, y), Color(0.16, 0.16, 0.16), 1.6, true)
