shader_type canvas_item;
// ============================================================================
// [2026-08-23] Boundary split -- clips each source-color sprite on world lines.
// ----------------------------------------------------------------------------
// IMPORTANT: shader source must remain ASCII. Godot can silently fail to compile
// shader files containing Korean identifiers/comments in this project.
// Two original black/white SpriteFrames overlap. Each keeps only its matching
// world-space region, preserving the separate linework and shading of both art sets.
// ============================================================================

// split_count: 0 = whole body, 1 = one line, 2 = two lines.
uniform int split_count = 0;
// lineN: xy = point on the line, zw = normal facing into the boundary.
uniform vec4 line_1 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 line_2 = vec4(0.0, 0.0, 0.0, 1.0);
// color_table: 0 = black, 1 = white. For two lines: ++, +-, -+, --.
uniform vec4 color_table = vec4(0.0);
// sheet_color: which original SpriteFrames this draw call contains.
uniform float sheet_color = 0.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float region_color;
	if (split_count <= 0) {
		region_color = color_table.x;
	} else if (split_count == 1) {
		bool a = dot(world_pos - line_1.xy, line_1.zw) >= 0.0;
		region_color = a ? color_table.x : color_table.y;
	} else {
		bool a = dot(world_pos - line_1.xy, line_1.zw) >= 0.0;
		bool b = dot(world_pos - line_2.xy, line_2.zw) >= 0.0;
		region_color = a ? (b ? color_table.x : color_table.y) : (b ? color_table.z : color_table.w);
	}
	if (abs(region_color - sheet_color) > 0.5) {
		discard;
	}
}
