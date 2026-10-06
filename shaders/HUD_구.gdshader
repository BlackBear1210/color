shader_type canvas_item;
// A hand-inked vessel contour, matching the character's monochrome linework.
// No metallic bevel, glass hotspot, or instrument ticks.
uniform bool back_pass = true;
uniform vec4 inner_color : source_color = vec4(0.26, 0.26, 0.26, 0.94);
uniform vec4 rim_color : source_color = vec4(0.86, 0.86, 0.84, 1.0);
uniform vec4 rim_dark : source_color = vec4(0.015, 0.015, 0.015, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0);
uniform float rim_width = 0.02;
uniform float feather = 0.015;
uniform float depth = 0.3;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float wobble = sin(angle * 7.0 + 0.8) * 0.003 + sin(angle * 13.0) * 0.002;
	float r = length(p) + wobble;
	float aa = max(fwidth(r), 0.006);
	float outline = 1.0 - smoothstep(0.955 - aa, 0.955 + aa, r);
	if (back_pass) {
		float shading = 0.85 - smoothstep(0.40, 0.94, r) * 0.30;
		float tooth = (grain(floor(UV * 180.0)) - 0.5) * 0.022;
		COLOR = vec4(inner_color.rgb * shading + vec3(tooth), inner_color.a * outline);
	} else {
		float contour = 1.0 - smoothstep(0.009, 0.009 + aa, abs(r - 0.933));
		float ink_edge = 1.0 - smoothstep(0.024, 0.024 + aa, abs(r - 0.936));
		float etched = (1.0 - smoothstep(0.003, 0.003 + aa, abs(r - 0.886))) * 0.20;
		float pressure = 0.65 + 0.25 * sin(angle * 2.0 - 0.7) + 0.10 * sin(angle * 19.0);
		vec3 color = mix(rim_dark.rgb, rim_color.rgb, contour * pressure);
		float alpha = max(ink_edge, etched) * rim_color.a;
		COLOR = vec4(color, alpha);
	}
}
