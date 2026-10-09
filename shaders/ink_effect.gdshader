shader_type canvas_item;
render_mode unshaded;

// Ink / paint effect colouring for the new gimmick effects (jump, spring pad, key pickup).
// The PNG only stores the SHAPE (alpha) and the paint THICKNESS detail (rgb, 0.55..1.0).
// The colour is decided here so one sheet serves both player colours:
//   mode 0 = white paint  : value capped at white_value (184/255) - never pure white.
//   mode 1 = black ink    : near-black body, the soft alpha edge turns into a thin lighter rim
//                           so black ink still reads on the dark (~31) background.
// unshaded: the value must not be crushed by the stage CanvasModulate (design values are final).
// No TIME here (project rule): fading is driven by the vertex colour (modulate) from the script.

uniform int mode = 0;
uniform float white_value = 0.72;
uniform float ink_value = 0.06;
uniform float rim_value = 0.38;
// alpha range that is treated as "edge" for the black rim
uniform float rim_lo = 0.30;
uniform float rim_hi = 0.85;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float d = clamp((t.r - 0.55) / 0.45, 0.0, 1.0);
	vec3 c;
	if (mode == 0) {
		c = vec3(white_value * mix(0.84, 1.0, d));
	} else {
		float body = smoothstep(rim_lo, rim_hi, t.a);
		c = vec3(mix(rim_value, ink_value * mix(1.25, 0.8, d), body));
	}
	COLOR = vec4(c * vcol.rgb, t.a * vcol.a);
}
