extends Node2D
## 움직이지 않는 명도/이음새 계산은 한 번만 렌더하고 패럴랙스는 결과 텍스처를 움직인다.
@export var 표면_입체감: bool = true
@export var 지형_그림자: bool = true
const 그림자_스크립트 = preload("res://scripts/스마트월드/지형_고정그림자.gd")

func _ready() -> void:
	var 그림 := $벽돌벽/그림 as Sprite2D
	if 그림.texture == null or 그림.material == null:
		return
	# A/B 측정과 되돌리기를 위해 효과를 독립적으로 켤 수 있게 한다.
	그림.material = 그림.material.duplicate()
	그림.material.set_shader_parameter("normal_strength", 0.45 if 표면_입체감 else 0.0)
	if 지형_그림자:
		call_deferred("_그림자_설치")
	var 캐시 := SubViewport.new()
	캐시.name = "벽돌색상캐시"
	캐시.size = Vector2i(그림.texture.get_size())
	캐시.disable_3d = true
	캐시.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(캐시)
	var 원본 := Sprite2D.new()
	원본.texture = 그림.texture
	원본.material = 그림.material
	원본.centered = false
	원본.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	캐시.add_child(원본)
	# 기존 셰이더의 결과를 보존하며 매 프레임 화면 전체에서 같은 계산을 반복하지 않는다.
	await RenderingServer.frame_post_draw
	if not is_instance_valid(그림):
		return
	var 고정명도 := CanvasItemMaterial.new()
	고정명도.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	그림.material = 고정명도
	그림.texture = 캐시.get_texture()

func _그림자_설치() -> void:
	var 지형들 := get_parent().get_node_or_null("지형")
	if 지형들 == null:
		return
	for 지형 in 지형들.get_children():
		if not 지형.has_method("get_point_array") or 지형.has_node("고정그림자"):
			continue
		var 그림자 := Node2D.new()
		그림자.name = "고정그림자"
		그림자.set_script(그림자_스크립트)
		지형.add_child(그림자)

