shader_type canvas_item;
// Opaque pigment, a broad cohesive surface and a slower wall film.
// The rotated base plane preserves circular segment area at every tilt.
uniform float fill_level = 1.0;
uniform float surface_height = -0.56;
uniform vec4 liquid_color : source_color = vec4(0.07, 0.07, 0.07, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform float slosh_amount = 0.0;
uniform float wall_slosh = 0.0;
uniform float surface_lag = 0.0;
uniform float flow_energy = 0.0;
uniform float impact_shock = 0.0;
uniform float animation_time = 0.0;
uniform float wave_heights[33];
varying vec2 vessel_uv;

void vertex() {
	vessel_uv = VERTEX / 72.0;
}

vec2 tilted(vec2 p, float amount) {
	float a = amount * 0.78;
	return vec2(p.x * cos(a) + p.y * sin(a), p.y * cos(a) - p.x * sin(a));
}

void fragment() {
	vec2 p = vessel_uv * 2.0 - 1.0;
	float r = length(p);
	vec2 q = tilted(p, slosh_amount);
	float h = surface_height;
	float width = sqrt(max(0.0, 1.0 - h * h));
	float side = clamp(q.x / max(0.01, width), -1.0, 1.0);
	// Broad, low-frequency deformation, driven by motion only: no idle water ripples.
	float index = clamp((q.x + 1.0) * 16.0, 0.0, 32.0);
	int left = min(int(floor(index)), 31);
	float wave = mix(wave_heights[left], wave_heights[left + 1], index - float(left));
	float surface = h + wave;
	float cap = sqrt(max(0.0, 1.0 - side * side)) * width * 0.12;
	float aa = max(fwidth(q.y), 0.007);
	float body = smoothstep(surface + cap - aa, surface + cap + aa, q.y);
	float top = smoothstep(surface - cap - aa, surface - cap + aa, q.y)
		* (1.0 - smoothstep(surface + cap - aa, surface + cap + aa, q.y));
	float depth = sqrt(max(0.0, 1.0 - dot(p, p)));
	float lighting = clamp(0.57 + depth * 0.39 - p.x * 0.10 - p.y * 0.08, 0.25, 1.0);
	float dark_ink = 1.0 - smoothstep(0.15, 0.70, liquid_color.r);
	// Pigment stays opaque. Wide satin reflections replace glassy pin highlights.
	float satin = pow(max(0.0, depth * 0.8 - p.x * 0.3 - p.y * 0.12), 3.0);
	vec3 pigment = liquid_color.rgb * lighting + vec3(satin * mix(0.035, 0.095, dark_ink));
	float fold = sin(q.x * 6.0 + q.y * 3.0 - animation_time * 0.55) * 0.008 * flow_energy;
	pigment += vec3(fold);
	float top_light = 0.45 + 0.55 * sqrt(max(0.0, 1.0 - side * side));
	vec3 top_color = liquid_color.rgb * (0.77 + top_light * 0.20);
	top_color += vec3(dark_ink * (0.09 + top_light * 0.055));
	vec4 col = vec4(mix(pigment, top_color, top), max(body, top) * liquid_color.a);
	float lip = 1.0 - smoothstep(aa * 0.3, aa * 1.6, abs(q.y - surface - cap));
	col.rgb = mix(col.rgb, liquid_color.rgb * 0.35 + vec3(dark_ink * 0.15), lip * 0.38);
	// The film follows the old tilt and drains back, confined to the inside wall.
	vec2 old = tilted(p, wall_slosh);
	float film = smoothstep(h - 0.035, h + 0.025, old.y)
		* smoothstep(0.78, 0.98, r) * (1.0 - max(body, top));
	col.rgb = mix(col.rgb, liquid_color.rgb * 0.72 + vec3(dark_ink * 0.04), film);
	col.a = max(col.a, film * 0.40 * liquid_color.a);
	col.a *= 1.0 - smoothstep(0.975, 1.0, r);
	if (fill_level <= 0.0) { col = vec4(0.0); }
	COLOR = col;
}
