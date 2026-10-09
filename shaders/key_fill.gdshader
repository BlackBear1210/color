shader_type canvas_item;
render_mode unshaded;

// HUD split-key fill: the picked half "fills up like ink" from the bottom inside the dotted outline.
// fill 0..1 is driven by script (no TIME - project rule). wave_phase too.
// flash > 0 brightens briefly (the moment the two halves lock together).

uniform float fill = 1.0;
uniform float wave_phase = 0.0;
uniform float flash = 0.0;
// ghost > 0 : show the half faintly (blink of the missing half)
uniform float ghost = 0.0;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float level = 1.0 - fill;
	float w = sin(UV.x * 17.0 + wave_phase) * 0.018 + sin(UV.x * 41.0 - wave_phase * 1.7) * 0.007;
	float m = smoothstep(level - 0.035, level + 0.005, UV.y + w);
	if (fill >= 0.999) {
		m = 1.0;
	}
	m = max(m, ghost);
	vec3 c = mix(t.rgb, vec3(0.86), clamp(flash, 0.0, 1.0) * 0.6);
	COLOR = vec4(c * vcol.rgb, t.a * m * vcol.a);
}
