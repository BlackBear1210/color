shader_type canvas_item;
render_mode unshaded;

// Fade finite artwork into the distant wall instead of exposing a straight cut.
void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float fog = 1.0 - smoothstep(0.72, 0.995, UV.y);
	float sides = smoothstep(0.0, 0.04, UV.x) * (1.0 - smoothstep(0.96, 1.0, UV.x));
	COLOR = vec4(tex.rgb, tex.a * fog * sides);
}
