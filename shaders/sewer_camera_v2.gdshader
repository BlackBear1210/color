shader_type canvas_item;
render_mode unshaded;
uniform float vignette_strength : hint_range(0.0, 0.2) = 0.075;
uniform float grain_strength : hint_range(0.0, 0.03) = 0.012;
uniform float clock = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
    vec2 q = (UV - 0.5) * 2.0;
    float vignette = smoothstep(0.55, 1.35, length(q)) * vignette_strength;
    float grain = (hash(floor(FRAGCOORD.xy) + floor(clock * 12.0)) - 0.5) * grain_strength;
    // Overlay only: no screen-copy, global blur, or changes to water hues.
    float a = vignette + abs(grain);
    float light = max(grain, 0.0) / max(a, 0.00001);
    COLOR = vec4(vec3(light), a);
}
