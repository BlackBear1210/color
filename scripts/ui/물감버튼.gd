extends RefCounted
## 로비·지도·설정의 버튼을 같은 붓 원화로 통일한다. 글씨는 이미지에 굽지 않고 실제 버튼에 남긴다.
static func 꾸미기(b: Button, 붓: Texture2D) -> void:
	for 키 in ["normal", "hover", "pressed", "focus"]:
		var 칠 := StyleBoxTexture.new()
		칠.texture = 붓
		var 밝기 := 0.14 if 키 == "normal" else (0.72 if 키 == "pressed" else 0.92)
		칠.modulate_color = Color(밝기, 밝기, 밝기)
		칠.set_content_margin_all(16)
		b.add_theme_stylebox_override(키, 칠)
	b.flat = false
	b.add_theme_color_override("font_color", Color(0.83, 0.83, 0.83))
	for 키 in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(키, Color(0.06, 0.06, 0.06))
