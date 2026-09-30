shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 extent = vec2(1408.0, 64.0);
uniform float pool_right_inset = 0.0;
uniform int pool_tone = 2;
uniform float phase = 0.0;
uniform bool animate = true;
// Fed every frame by the owning script at runtime (not TIME). A shader that reads TIME
// forces the Godot editor to redraw every frame, which steals GPU from the running game.
uniform float anim_time = 0.0;
// Enabled only by the stage 2-9 pool controller; other stages retain their look.
uniform bool stage5_surface = false;
uniform vec3 step_waves[6];
uniform int step_wave_count = 0;
varying vec2 pixel;

// Low-contrast sediment and broken reflections.
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float soft_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
        mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

// Pixel-space waves keep the same scale in short and long basins.
float surface_height(float x, float t) {
    return -0.6 + sin(x * 0.043 - t * 0.85) * 0.75
        + sin(x * 0.097 - t * 1.23) * 0.32;
}

vec4 pool(vec2 p, float t, vec2 screen_uv, vec2 pixel_size) {
    float h = max(extent.y, 8.0);
    float depth = p.y - surface_height(p.x, t);
    float right = extent.x - pool_right_inset * clamp(p.y / h, 0.0, 1.0);
    float edge = min(p.x, right - p.x);
    float wet_edge = 1.0 - smoothstep(0.0, 7.0, edge);
    float alpha = smoothstep(-0.65, 0.65, depth)
        * smoothstep(0.0, 1.5, edge);

    // A shallow tonal range avoids the polished cylindrical gradient.
    vec2 drift = vec2(p.x - t * 3.5, p.y);
    float silt = soft_noise(drift / vec2(61.0, 13.0));
    float patches = soft_noise((drift + vec2(93.0, 17.0)) / vec2(23.0, 5.5));
    float grain = hash21(floor(p * 0.8));
    float value = mix(0.315, 0.265, smoothstep(0.0, h, max(depth, 0.0)));
    value += (silt - 0.5) * 0.018 + (patches - 0.5) * 0.009;
    // Fixed, subtle grain avoids temporal sparkle and matches the masonry density.
    value += (grain - 0.5) * 0.016;

    // Discontinuous silver glints travel slowly to the right.
    float glint = smoothstep(0.53, 0.76, soft_noise(vec2(drift.x / 19.0, 7.3)));
    float rim = 1.0 - smoothstep(0.25, 1.1, abs(depth - 0.55));
    // No constant bright rim: highlights exist only in small, irregular islands.
    value += rim * glint * 0.19;
    // Thin, staggered strokes replace broad cloudy highlights.
    float row = floor(max(depth, 0.0) / 7.0);
    float lane = mod(max(depth, 0.0), 7.0);
    float stroke_x = drift.x + hash21(vec2(row, 3.0)) * 113.0;
    float ripple_y = 3.4 + sin(p.x * 0.048 - t * 0.65 + row) * 0.65;
    float ripple = 1.0 - smoothstep(0.25, 0.85, abs(lane - ripple_y));
    float broken = smoothstep(0.58, 0.77, soft_noise(vec2(stroke_x / 13.0, row * 3.7)));
    float near_surface = 1.0 - smoothstep(7.0, 38.0, depth);
    value += ripple * broken * near_surface * 0.10;

    // A narrow irregular wet seam softens the cut end without hiding water bounds.
    value -= wet_edge * (0.025 + patches * 0.035);
    float contact_width = 1.5 + soft_noise(vec2(p.x / 9.0, 2.8)) * 2.0;
    value -= smoothstep(h - contact_width, h, p.y) * 0.045;
    float marks = rim * glint * 0.12 + ripple * broken * near_surface * 0.10;
    if (pool_tone == 0) {
        value = 0.025 + marks * 1.3 + grain * 0.008;
    } else if (pool_tone == 1) {
        // Opaque white down to the floor; dark short ripples, never gray depth.
        value = 0.91 - marks * 1.8 - clamp(depth / h, 0.0, 1.0) * 0.025;
        value += (grain - 0.5) * 0.006;
    } else {
        // Refraction is restrained and mixed into a stable mid-gray body.
        vec2 offset = vec2(sin(p.y * 0.17 + t) * 1.5, sin(p.x * 0.035 - t) * 0.6);
        float wall = texture(screen_tex, screen_uv + offset * pixel_size).r;
        value = mix(0.47, 0.40, clamp(depth / h, 0.0, 1.0));
        value += (wall - 0.25) * 0.18 + marks;
    }
    if (stage5_surface) {
        // Reference: long, broken horizontal reflections, not a dotted gray slab.
        float reflection_mask = smoothstep(0.38, 0.67,
            soft_noise(vec2(stroke_x / 43.0, row * 5.3 + 1.7)));
        float surface_glint = rim * (0.22 + glint * 0.78);
        float reflection = ripple * reflection_mask * near_surface;
        float moving_ripples = 0.0;
        for (int i=0; i<6; i++) {
            if (i >= step_wave_count) { break; }
            vec3 wave = step_waves[i];
            float radius = 9.0 + wave.y * 47.0;
            float distance_to_ring = length(vec2(p.x - wave.x, (depth - 6.0) * 7.0)) - radius;
            float ring = 1.0 - smoothstep(0.5, 2.1, abs(distance_to_ring));
            moving_ripples += ring * pow(max(0.0, 1.0 - wave.y / 1.2), 2.0) * wave.z;
        }
        float wake = min(moving_ripples, 1.0);
        if (pool_tone == 0) {
            // Ink-black body and silver reflections concentrated at the surface.
            value = 0.016 + grain * 0.005 + surface_glint * 0.48 + reflection * 0.32 + wake * 0.32;
            alpha *= 0.97;
        } else if (pool_tone == 1) {
            // Milky opaque body. Gray is confined to fine surface strokes, never the body.
            value = 0.925 - clamp(depth / h, 0.0, 1.0) * 0.025;
            value -= surface_glint * 0.12 + reflection * 0.25 + wake * 0.22;
            alpha *= 0.99;
        } else {
            // The reference gray is transparent water: preserve masonry and submerged silhouettes.
            // Alpha blending keeps the actual scene visible instead of painting it mid-gray.
            value = 0.43 + surface_glint * 0.40 + reflection * 0.28 + wake * 0.30;
            float reflected_alpha = max(surface_glint, max(reflection, wake));
            alpha *= mix(0.34, 0.84, clamp(reflected_alpha, 0.0, 1.0));
        }
    }
    return vec4(vec3(clamp(value, 0.0, 0.96)), alpha);

}

void vertex() {
    pixel = VERTEX + vec2(extent.x * 0.5, 0.0);
}

void fragment() {
    COLOR = pool(pixel, phase + (animate ? anim_time : 0.0), SCREEN_UV, SCREEN_PIXEL_SIZE);
}
