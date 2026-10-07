shader_type canvas_item;
// Preserve the original world-space color split while replacing baked tank fill.
uniform int split_count = 0;
uniform vec4 line_1 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 line_2 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_table = vec4(0.0);
uniform float sheet_color = 0.0;
uniform vec4 tank_rect = vec4(0.0);
uniform float paint_fill : hint_range(0.0, 1.0) = 1.0;
uniform bool tank_enabled = true;
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
    if (abs(region_color - sheet_color) > 0.5) { discard; }
    bool inside_tank = UV.x > tank_rect.x && UV.x < tank_rect.z && UV.y > tank_rect.y && UV.y < tank_rect.w;
    if (tank_enabled && inside_tank) {
        float tank_y = (UV.y - tank_rect.y) / max(tank_rect.w - tank_rect.y, 0.00001);
        // Seven shots fill the usable 88% capacity; keep an air gap visible.
        float wet = step(1.0 - paint_fill * 0.88, tank_y);
        if (paint_fill <= 0.0) { wet = 0.0; }
        vec4 glass = vec4(0.74, 0.74, 0.74, 0.16);
        vec4 paint = vec4(vec3(mix(0.045, 0.94, sheet_color)), 0.97);
        COLOR = mix(glass, paint, wet);
    }
}
