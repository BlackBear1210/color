shader_type canvas_item;
render_mode unshaded;

// Blend tile boundaries into haze instead of exposing hard image cuts.
uniform bool opaque_wall = false;
uniform float edge_width : hint_range(0.001, 0.25) = 0.06;
uniform vec4 haze_color : source_color = vec4(0.30, 0.30, 0.30, 1.0);
uniform float atmosphere : hint_range(0.0, 1.0) = 0.15;
varying vec4 vertex_tint;

// Keep modulation separate: fragment COLOR already contains texture sampling.
void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 edge = min(UV, vec2(1.0) - UV);
	float fade = smoothstep(0.0, edge_width, edge.x) * smoothstep(0.0, edge_width, edge.y);
	vec3 toned = mix(tex.rgb, haze_color.rgb, atmosphere);
	if (opaque_wall) {
		COLOR = vec4(mix(haze_color.rgb, toned, fade), 1.0) * vertex_tint;
	} else {
		COLOR = vec4(toned, tex.a * fade) * vertex_tint;
	}
}
