shader_type canvas_item;
render_mode unshaded;

// Keep fixed gameplay colors readable against the masonry without filling holes.
uniform bool white_grate = false;
varying vec4 face_tint;

void vertex() {
	face_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float grain = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	// Screen-space neighbors retain a narrow rim even on projected faces.
	vec2 dx = dFdx(UV) * 0.8;
	vec2 dy = dFdy(UV) * 0.8;
	float adjacent = min(min(texture(TEXTURE, UV + dx).a, texture(TEXTURE, UV - dx).a),
		min(texture(TEXTURE, UV + dy).a, texture(TEXTURE, UV - dy).a));
	float rim = clamp(source.a - adjacent, 0.0, 1.0);
	float ink = white_grate ? 0.78 + grain * 0.22 : 0.012 + grain * 0.075;
	// Black bars get a restrained gray rim; white bars retain a dark cut edge.
	ink = mix(ink, white_grate ? 0.16 : 0.48, rim * 0.8);
	COLOR = vec4(vec3(ink) * face_tint.rgb, source.a * face_tint.a);
}
