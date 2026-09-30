shader_type canvas_item;
render_mode unshaded;
uniform sampler2D flow_texture : filter_linear, repeat_disable;
uniform vec2 extent = vec2(64.0, 320.0);
uniform int kind = 0;
uniform float speed = 130.0;
uniform float tile_size = 128.0;
uniform float back_depth = 4.0;
uniform float corner_inset = 3.0;
uniform float phase = 0.0;
uniform bool animate = true;
varying vec2 pixel;

float band(float distance_to_edge) {
    return smoothstep(0.0, 1.2, distance_to_edge);
}
vec2 mirror_uv(vec2 uv) {
    return 1.0 - abs(mod(uv, 2.0) - 1.0);
}
float detail(vec2 p) {
    return clamp((texture(flow_texture, mirror_uv(p / tile_size)).r - 0.65) / 0.35, 0.0, 1.0);
}
vec4 water(vec2 p, float t) {
    float w = extent.x;
    float h = extent.y;
    float opacity = 0.0;
    float value = 0.9;
    if (kind == 0 || kind == 1) {
        float edge = 1.5 + sin(p.y * 0.065 - t * 3.0) * 0.7;
        float d = min(p.x, w - p.x) - edge;
        opacity = band(d) * band(p.y) * band(h - p.y);
        float a = detail(vec2(p.x, p.y - t * speed));
        float b = detail(vec2(p.x + 41.0, p.y - t * speed * 0.73));
        value = 0.72 + 0.27 * mix(a, b, 0.28);
        value += 0.035 * exp(-max(d, 0.0) * 0.5);
    } else if (kind == 2) {
        // A curved exit, with a fixed-size cross-section instead of a stretched sprite.
        float u = clamp(p.y / h, 0.0, 1.0);
        float radius = min(18.0, w * 0.18);
        float center = radius + (w - 2.0 * radius) * (1.0 - exp(-u * 4.0));
        float d = radius - abs(p.x - center);
        opacity = band(d) * band(h - p.y);
        value = 0.8 + 0.19 * detail(vec2(p.x - center + radius, p.y - t * speed));
    } else if (kind == 3) {
        float inset = corner_inset * clamp(-p.y / max(back_depth, 0.1), 0.0, 1.0);
        opacity = band(min(p.x - inset, w - inset - p.x)) * band(h - p.y);
        if (p.y < 0.0) {
            float waves = sin(p.x * 0.1 - t * 2.0 + p.y * 1.5);
            value = 0.92 + 0.06 * waves;
            opacity *= band(p.y + back_depth);
        } else {
            float a = detail(vec2(p.y * 2.0 + 60.0, p.x + t * 12.0));
            value = 0.77 + 0.19 * a;
            value += 0.055 * exp(-p.y / 3.0);
            value -= 0.04 * smoothstep(24.0, max(25.0, h), p.y);
        }
    } else if (kind == 4) {
        float base = h - 5.0;
        float x = p.x - w * 0.5;
        float mound = 4.0 + 9.0 * exp(-x*x / max(w * 6.0, 1.0));
        mound += 2.0 * sin(x * 0.18 + t * 6.0);
        opacity = band(mound - abs(p.y - base)) * band(w * 0.5 - abs(x));
        for (int i = 0; i < 12; i++) {
            float fi = float(i);
            float age = fract(t * 0.85 + fi * 0.618);
            float direction = mod(fi, 2.0) * 2.0 - 1.0;
            float dx = direction * age * w * (0.15 + mod(fi, 5.0) * 0.058);
            float dy = -sin(age * 3.14159265) * (h - 12.0) * (0.4 + mod(fi, 4.0) * 0.18);
            float drop = 1.0 - smoothstep(1.0, 2.3, length((vec2(x, p.y - base) - vec2(dx, dy)) / vec2(0.8, 1.4)));
            opacity = max(opacity, drop * (1.0 - age));
            float reach = w * (0.12 + mod(fi, 5.0) * 0.048);
            float u = x * direction / max(reach, 1.0);
            float jet_y = base - sin(clamp(u, 0.0, 1.0) * 3.14159265) * min(h * 0.45, 24.0) * (0.7 + 0.3 * sin(t * 4.0 + fi));
            float jet = (1.0 - smoothstep(0.3, 1.2, abs(p.y - jet_y))) * step(0.0, u) * (1.0 - step(1.0, u));
            opacity = max(opacity, jet * 0.7);
        }
        value = 0.96;
    } else {
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float age = fract(t * 0.6 + fi * 0.25);
            vec2 center = vec2(w * 0.5 + sin(fi * 13.0) * min(w * 0.2, 9.0), age * age * (h + 12.0) - 6.0);
            float drop = 1.0 - smoothstep(1.2, 2.7, length((p - center) / vec2(0.8, 1.5)));
            opacity = max(opacity, drop);
        }
        value = 0.94;
    }
    return vec4(vec3(clamp(value, 0.0, 1.0)), opacity);
}
void vertex() {
    pixel = VERTEX + vec2(extent.x * 0.5, 0.0);
}
void fragment() {
    COLOR = water(pixel, phase + (animate ? TIME : 0.0));
}
