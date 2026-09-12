shader_type canvas_item;
// ============================================================================
// [2026-09-05] Paint impact effect - keys the water sheet and tints it.
// (Korean comments are forbidden inside .gdshader - the shader silently dies.)
// ----------------------------------------------------------------------------
// The original water_05..08 sheets ship on an OPAQUE BLACK background: every
// pixel has alpha 1.0, so the alpha channel carries no shape at all. Brightness
// is the only mask we have -> luminance becomes opacity. This leaves the source
// PNGs untouched (no repainting, no re-export) while still giving us a cut-out.
//
// The game is black & white, so the cyan artwork is recolored to the paint
// colour the player fired. Two nodes share this shader: the body (paint colour)
// and a slightly larger backing copy in the opposite colour, so a BLACK splash
// is still readable on a dark stage.
// ============================================================================
uniform vec4 paint_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float paint_alpha : hint_range(0.0, 1.0) = 1.0;
// Below key_low the pixel is background, above key_high it is solid water.
uniform float key_low : hint_range(0.0, 1.0) = 0.04;
uniform float key_high : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float lum = max(src.r, max(src.g, src.b));
	float mask = smoothstep(key_low, key_high, lum);
	COLOR = vec4(paint_tint.rgb, mask * src.a * paint_alpha);
}
