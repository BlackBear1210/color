shader_type canvas_item;
// ============================================================================
// [2026-09-05] Paint HUD - the liquid inside the gauge sphere.
// (Korean is forbidden inside .gdshader.)
// ----------------------------------------------------------------------------
// This node is drawn inside a Polygon2D whose `clip_children` is CLIP_CHILDREN_ONLY,
// so the circle keeps the liquid inside the vessel - this shader only decides
// WHERE the surface sits and what the bands look like.
//
// Three stacked levels, all 0..1 of the vessel height, all fed from the real
// paint system through 페인트_HUD_어댑터 (never from a HUD-only counter):
//   fill_level    shots you can fire right now      -> solid ink
//   pending_level fill + paint out in the world      -> faint band (comes back with E)
//   locked_level  fill + pending + greyed-out shots  -> hatched band at the top
// The old capsule bar carried the same three states as segments; keeping them
// here means the new gauge loses no information.
//
// wave_* / slosh_* / impact_shock are declared but left at 0 by default.
// STEP 2 ships a still surface on purpose; STEP 3 drives these.
// ============================================================================
uniform float fill_level : hint_range(0.0, 1.0) = 1.0;
uniform float pending_level : hint_range(0.0, 1.0) = 0.0;
uniform float locked_level : hint_range(0.0, 1.0) = 0.0;
uniform vec4 liquid_color : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.0;
uniform float wave_frequency : hint_range(0.5, 6.0) = 2.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float slosh_amount : hint_range(-1.0, 1.0) = 0.0;
uniform float impact_shock : hint_range(0.0, 1.0) = 0.0;
// Thickness of the bright surface line, in UV units.
uniform float foam_thickness : hint_range(0.0, 0.1) = 0.016;
// ★[2026-09-05 STEP 3] Shading toward the vessel wall.
// Without it a full sphere of WHITE ink is one flat white blob and the glass
// vessel disappears. This keeps the ink reading as a round body of liquid
// WITHOUT lowering its alpha (which would make the HUD look washed out).
uniform float edge_shade : hint_range(0.0, 1.0) = 0.38;

// Height (0 = top of the vessel, 1 = bottom) of a surface for a given level.
float surface_at(float level, float x) {
	float y = 1.0 - clamp(level, 0.0, 1.0);
	float w = sin((x * wave_frequency + TIME * wave_speed) * 6.2831853) * wave_amplitude;
	w += sin((x * wave_frequency * 1.7 - TIME * wave_speed * 1.3) * 6.2831853) * wave_amplitude * 0.5;
	// Tilting the surface is what "sloshing" will look like once STEP 3 drives it.
	w += (x - 0.5) * slosh_amount * 0.5;
	w -= impact_shock * 0.06;
	return y + w;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float s_fill = surface_at(fill_level, x);
	float s_pend = surface_at(pending_level, x);
	float s_lock = surface_at(locked_level, x);

	vec4 col = vec4(0.0);

	// Locked band (greyed-out paint) - hatched so it reads without colour in a B/W game.
	if (locked_level > 0.001 && y > s_lock && y <= s_pend) {
		float hatch = step(0.5, fract((UV.x * 26.0 + UV.y * 26.0)));
		col = vec4(liquid_color.rgb, 0.16 + 0.14 * hatch);
	}
	// Pending band (out in the world, comes back with E) - faint, no hatch.
	if (pending_level > 0.001 && y > s_pend && y <= s_fill) {
		col = vec4(liquid_color.rgb, 0.30);
	}
	// The paint you can actually fire.
	if (y > s_fill) {
		col = vec4(liquid_color.rgb, liquid_color.a);
	}
	// Round the body of liquid off toward the vessel wall. The ColorRect sits on
	// the vessel circle, so UV distance from the centre is the vessel radius.
	float d = length(UV * 2.0 - 1.0);
	col.rgb *= 1.0 - smoothstep(0.45, 1.05, d) * edge_shade;

	// Bright meniscus on the real surface so the level is readable at a glance.
	if (fill_level > 0.002 && fill_level < 0.999) {
		float line = 1.0 - smoothstep(0.0, foam_thickness, abs(y - s_fill));
		col.rgb = mix(col.rgb, foam_color.rgb, line * foam_color.a);
		col.a = max(col.a, line * foam_color.a);
		// A thin darker band just under the meniscus = the liquid has depth.
		float under = smoothstep(0.0, foam_thickness * 3.0, y - s_fill)
			* (1.0 - smoothstep(foam_thickness * 3.0, foam_thickness * 7.0, y - s_fill));
		col.rgb *= 1.0 - under * 0.22;
	}
	COLOR = col;
}
