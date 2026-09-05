shader_type canvas_item;
// ============================================================================
// [2026-09-05] Paint HUD - circular vessel (portrait disc / gauge sphere).
// (Korean is forbidden inside .gdshader - the shader silently fails to build.)
// ----------------------------------------------------------------------------
// One shader, two passes, so the portrait and the gauge share the same look:
//   back_pass = true  -> the filled disc drawn BEHIND the contents
//                        (ink disc for the portrait, dark glass for the gauge)
//   back_pass = false -> the rim + glass highlight drawn IN FRONT of them
// The project has no UI frame artwork (assets/textures/ui holds only
// brush_cursor.svg), so the frame is generated here rather than imported -
// this keeps it resolution independent and recolourable by paint state.
//
// The game is black & white: `inner_color` is flipped by the controller so the
// contents (a black character, black liquid) always land on the opposite tone.
// ============================================================================
uniform bool back_pass = true;
// Disc interior. Flipped light/dark by 페인트_HUD.gd to keep contrast.
uniform vec4 inner_color : source_color = vec4(0.10, 0.10, 0.12, 0.92);
// Old metal rim. Stays metallic in both paint states so the vessel reads as one object.
uniform vec4 rim_color : source_color = vec4(0.62, 0.60, 0.56, 1.0);
uniform vec4 rim_dark : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.30);
// Rim thickness as a fraction of the radius.
uniform float rim_width : hint_range(0.0, 0.4) = 0.085;
// Edge softness, also a fraction of the radius.
uniform float feather : hint_range(0.001, 0.2) = 0.03;
// 0 = flat disc, 1 = strong inner vignette (glass depth).
uniform float depth : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float disc = 1.0 - smoothstep(1.0 - feather, 1.0, d);

	if (back_pass) {
		// Interior: darkest at the rim so the vessel looks concave.
		float vig = mix(1.0, 1.0 - smoothstep(0.35, 1.0, d) * 0.75, depth);
		vec3 rgb = inner_color.rgb * vig;
		COLOR = vec4(rgb, inner_color.a * disc);
	} else {
		float inner_edge = 1.0 - rim_width;
		// Metal band hugging the outside.
		float ring = smoothstep(inner_edge - feather, inner_edge, d) * disc;
		// Light falls from the upper left, so the top-left of the rim is bright.
		float lit = clamp(dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.7, -0.7))), 0.0, 1.0);
		vec3 metal = mix(rim_dark.rgb, rim_color.rgb, 0.25 + 0.75 * lit);
		// A thin dark line just inside the rim reads as the glass lip.
		float lip = smoothstep(inner_edge - rim_width * 0.9, inner_edge - rim_width * 0.2, d)
			* (1.0 - smoothstep(inner_edge, inner_edge + feather, d));
		// Specular blob on the upper-left glass. Kept small so it reads as glass, not fog.
		float spec = 1.0 - smoothstep(0.0, 0.24, distance(p, vec2(-0.40, -0.46)));
		spec *= (1.0 - smoothstep(inner_edge - 0.06, inner_edge, d));
		vec3 rgb = metal;
		float a = ring;
		// Composite the lip and the specular over the (transparent) centre.
		a = max(a, lip * 0.45);
		rgb = mix(rgb, rim_dark.rgb, lip * 0.6 * (1.0 - ring));
		// A constant dark contour on the very outside, so the vessel keeps its shape
		// against BOTH a light interior (black paint) and a dark one (white paint).
		float contour = smoothstep(1.0 - feather * 2.2, 1.0 - feather * 0.6, d)
			* (1.0 - smoothstep(1.0 - feather, 1.0, d));
		rgb = mix(rgb, rim_dark.rgb, contour * 0.85);
		a = max(a, contour * 0.9);
		vec4 outc = vec4(rgb, a);
		outc.rgb = mix(outc.rgb, highlight_color.rgb, spec * highlight_color.a);
		outc.a = max(outc.a, spec * highlight_color.a);
		COLOR = vec4(outc.rgb, outc.a * disc);
	}
}
