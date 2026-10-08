shader_type canvas_item;
render_mode unshaded;
// Natural water (2026-10-01). Kinds 0 and 1 (falling streams) in the sewer, all three tones.
// Concept: white water is thin, fast-falling water (not white paint). Look matched to the approved
// reference (v4): glass-tube stream with bright fresnel rims and a see-through core, accelerating fall,
// beads sliding down the edges, a crown splash at the floor; wide sheets are one curtain with small tears.
// Collision is NOT drawn here. The drawn body never gets narrower than the hit box (hit_inset).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform bool impact = true;
// Concept A (2026-10-07): opt-in low radial impact; the owner limits the stage scope.
uniform bool low_floor_impact = false;
uniform sampler2D impact_frames : filter_linear, repeat_disable;
uniform bool higgsfield_fluid = false;
// Use the minimum visible fixed-center beam so wide streams do not hide their collision edges.
uniform vec4 white_fluid_layout = vec4(123.022222, 69.6, 471.6, 26.0);
// Hopper inlet: the stream enters a hopper pool drawn in front of it -> cut cleanly at the end
// (a soft fade shows the metal behind as a grey block). Set by hopper_inlet script.
uniform bool hard_end = false;
uniform int water_tone = 1;
uniform vec2 extent = vec2(64.0, 320.0);
uniform float back_depth = 4.0;
uniform float hit_inset = 7.0;
uniform float phase = 0.0;
uniform bool animate = true;
// Fed every frame by the owning script at runtime (not TIME): TIME makes the editor redraw forever.
uniform float anim_time = 0.0;
uniform float flow_head = 100000.0;
uniform float flow_tail = -100000.0;
// Water leaves the opening at release_speed and accelerates with gravity (px/s, px/s^2).
uniform float release_speed = 200.0;
uniform float gravity = 1800.0;
uniform vec4 lights[6];
uniform vec4 light_extra[6];
uniform int light_count = 0;

varying vec2 pixel;
varying vec2 world;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float a = 0.5;
    float s = 0.0;
    for (int i = 0; i < 4; i++) {
        s += a * vnoise(p);
        p = p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return s;
}
// Distance to the nearest random point: small = inside a bubble.
float worley(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float d = 1.5;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = vec2(hash(i + g), hash(i + g + 19.1));
            d = min(d, length(g + o - f));
        }
    }
    return d;
}
// Flow noise: y is the parcel clock (seconds). Higher octaves add only HORIZONTAL detail (thin strands)
// and barely speed up in time, so nothing changes faster than a frame can show (the v2 flicker).
float fbm_flow(vec2 p) {
    float a = 0.5;
    float s = 0.0;
    for (int i = 0; i < 4; i++) {
        s += a * vnoise(p);
        p = vec2(p.x * 1.8, p.y * 1.4) + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return s;
}
vec4 over(vec4 under, vec4 front) {
    float a = front.a + under.a * (1.0 - front.a);
    return vec4((front.rgb * front.a + under.rgb * under.a * (1.0 - front.a)) / max(a, 0.0001), a);
}
vec2 lamp_light(vec3 n, vec2 wp) {
    vec2 acc = vec2(0.0);
    for (int i = 0; i < 6; i++) {
        if (i >= light_count) { break; }
        vec4 l = lights[i];
        vec2 d = l.xy - wp;
        float att = pow(1.0 - clamp(length(d) / max(l.z, 1.0), 0.0, 1.0), 3.5) * l.w * light_extra[i].y / 3.0;
        vec3 lv = normalize(vec3(d, max(light_extra[i].x, 1.0)));
        vec3 hv = normalize(lv + vec3(0.0, 0.0, 1.0));
        acc.x += att * max(dot(n, lv), 0.0);
        acc.y += att * pow(max(dot(n, hv), 0.0), 28.0);
    }
    return acc;
}
float fall_speed(float y) {
    return sqrt(release_speed * release_speed + 2.0 * gravity * max(y, 0.0));
}
// Seconds since the water now at height y left the opening. (t - fall_time) labels one parcel of
// water, so noise sampled on it moves at the true, accelerating speed and stretches as it falls.
float fall_time(float y) {
    return (fall_speed(y) - release_speed) / gravity;
}

// The whole white fluid comes from the generated video, not a procedural splash rig.
// Layout: original fixed-camera center X, body top Y, ground Y, and reference beam width.
vec4 higgsfield_white_water(vec2 p, float t) {
    float w = max(extent.x, 1.0);
    float fy = max(1.0, extent.y - (impact ? back_depth + 1.0 : 0.0));
    float sx = white_fluid_layout.x + (p.x - extent.x * 0.5) * white_fluid_layout.w / w;
    float pixel_scale = w / max(white_fluid_layout.w, 1.0);
    float foot_height = min(min(96.0 * pixel_scale, 96.0), fy * 0.3);
    bool contact_ready = impact && flow_head >= extent.y - back_depth * 0.5 - 1.0
        && flow_tail < extent.y - back_depth * 0.5 - 2.0;
    bool foot = contact_ready && p.y >= fy - foot_height;
    float body_end = max(1.0, fy - (contact_ready ? foot_height : 0.0));
    float sy = mix(white_fluid_layout.y, white_fluid_layout.z - 96.0,
        clamp(p.y / body_end, 0.0, 1.0));
    if (foot) {
        sy = white_fluid_layout.z + (p.y - fy) * 96.0 / max(foot_height, 1.0);
    }
    if (p.y < 0.0 || (!foot && p.y >= fy) || sx < 0.5 || sx > 255.5 || sy < 0.5 || sy > 511.5) {
        return vec4(0.0);
    }
    float clock = mod(t * 12.0, 48.0);
    float first = floor(clock);
    float next = mod(first + 1.0, 48.0);
    vec2 local_uv = vec2(sx, sy) / vec2(256.0, 512.0);
    vec2 ca = vec2(mod(first, 8.0), floor(first / 8.0));
    vec2 cb = vec2(mod(next, 8.0), floor(next / 8.0));
    vec4 a = texture(impact_frames, (ca + local_uv) / vec2(8.0, 6.0));
    vec4 b = texture(impact_frames, (cb + local_uv) / vec2(8.0, 6.0));
    float alpha = mix(a.a, b.a, fract(clock));
    vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, fract(clock)) / max(alpha, 0.0001);
    float present = smoothstep(0.0, 6.0, flow_head - p.y)
        * smoothstep(-2.0, 4.0, p.y - flow_tail);
    alpha *= present;
    // Only the floor film is limited to the collision/column width. Free airborne drops remain visible.
    if (foot) {
        float dx = abs(p.x - extent.x * 0.5);
        float footprint = 1.0 - smoothstep(max(0.0, w * 0.5 - 2.0), w * 0.5, dx);
        alpha *= mix(1.0, footprint, smoothstep(fy - 2.0, fy, p.y));
    }
    return vec4(rgb, alpha);
}

// Short ballistic bursts: 48 frames at 30 FPS, 1.6 second loop.
// Roots detach after 65 ms; separated droplets fall instead of warping a persistent sheet.
// Map each outer edge separately so narrow streams retain a readable splash,
// while a wide curtain stretches only the compact foam between its edges.
vec4 low_floor_splash(vec2 p, float t, float bw, float floor_y, float wide_k) {
    float dx = p.x - extent.x * 0.5;
    float half_body = max(1.0, bw - 6.0);
    float atlas_x = abs(dx) <= half_body ? dx * 27.0 / half_body : sign(dx) * (27.0 + abs(dx) - half_body);
    vec2 local = vec2(atlas_x + 192.0, p.y - floor_y + 112.0);
    if (local.x < 0.5 || local.x > 383.5 || local.y < 0.5 || local.y > 127.5) {
        return vec4(0.0);
    }
    float clock = mod(t * 30.0, 48.0);
    float first = floor(clock);
    float next = mod(first + 1.0, 48.0);
    vec2 cell_a = vec2(mod(first, 8.0), floor(first / 8.0));
    vec2 cell_b = vec2(mod(next, 8.0), floor(next / 8.0));
    vec2 uv = local / vec2(384.0, 128.0);
    vec4 a = texture(impact_frames, (cell_a + uv) / vec2(8.0, 6.0));
    vec4 b = texture(impact_frames, (cell_b + uv) / vec2(8.0, 6.0));
    // Interpolate premultiplied colours to avoid dark fringes on transparent edges.
    float alpha = mix(a.a, b.a, fract(clock));
    vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, fract(clock)) / max(alpha, 0.0001);
    // Keep the ground film within the stream width; airborne spray keeps its own travel.
    float floor_width = 1.0 - smoothstep(extent.x * 0.45, extent.x * 0.5, abs(dx));
    alpha *= mix(1.0, floor_width, smoothstep(104.0, 109.0, local.y));
    return vec4(rgb, alpha);
}

// v4 (2026-10-01, matched to the approved Nano Banana reference):
//   narrow stream = a glass tube: bright, dense rims (fresnel) and a see-through core with vertical glints,
//     droplets clinging to and sliding down the edges, a real crown splash at the floor;
//   wide sheet = one continuous curtain rolling over a bright lip, with only SMALL, SHORT tears that ride
//     down with the water, and a spiky splash line along its whole foot.
vec4 stream(vec2 p, vec2 suv, vec2 px, float t) {
    if (higgsfield_fluid && water_tone == 1) {
        return higgsfield_white_water(p, t);
    }
    float w = extent.x;
    float h = extent.y;
    if (impact) { h = max(1.0, h - back_depth * 0.5); }
    float cx = w * 0.5;
    float dx = p.x - cx;
    float s = t - fall_time(p.y);
    float wide_k = smoothstep(120.0, 260.0, w);
    float present = smoothstep(0.0, 6.0, flow_head - p.y) * smoothstep(-2.0, 4.0, p.y - flow_tail);
    float sd_px = dx < 0.0 ? -1.0 : 1.0;

    // Tone palette: the same water in three colours. Black = ink that still flows like thin water
    // (dark see-through core, silver sheen only where light catches it). Grey = clearly see-through
    // mid-grey. White = the approved v4 look. Each must stay readable as its colour (the death rule).
    // White and grey must never look alike (on the 2-5 sheet they nearly did): white is denser and
    // brighter, grey is darker and more see-through.
    float core_base = 0.82; float core_bg = 0.22; float glint_k = 0.26; float dark_k = 0.10;
    float aer_v = 0.94; float rim_v = 0.92; float rim_k = 0.08; float edge_add = 0.10; float lip_k = 0.14;
    float splash_v = 0.97; float hi_v = 0.99; float sheet_v = 0.88; float alpha_lo = 0.88;
    float drop_v = 0.95; float foam_v = 0.97;
    if (water_tone == 0) {
        // Denser than the others: at 0.85 alpha / 0.28 wall it read as dark-grey smoke, not black water.
        core_base = 0.02; core_bg = 0.12; glint_k = 0.20; dark_k = 0.0;
        aer_v = 0.10; rim_v = 0.03; rim_k = 0.06; edge_add = 0.28; lip_k = 0.22;
        splash_v = 0.08; hi_v = 0.50; sheet_v = 0.04; alpha_lo = 0.94;
        drop_v = 0.40; foam_v = 0.20;
    } else if (water_tone == 2) {
        // Measured: 0.28 / 0.55 made the 2-5 sheet 0.25 = close to black water. Target ~0.4 (the old grey).
        core_base = 0.42; core_bg = 0.35; glint_k = 0.18; dark_k = 0.06;
        aer_v = 0.50; rim_v = 0.50; rim_k = 0.08; edge_add = 0.10; lip_k = 0.10;
        splash_v = 0.55; hi_v = 0.72; sheet_v = 0.45; alpha_lo = 0.68;
        drop_v = 0.60; foam_v = 0.58;
    }

    float neck = max(0.0, min(hit_inset - 1.0, w * 0.08));
    float hw0 = w * 0.5 - neck * (1.0 - exp(-clamp(p.y / max(h, 1.0), 0.0, 1.0) * 2.2));
    // Edge: gentle waviness, may bite inward only until the hit box.
    float inward = max(0.0, hit_inset - 1.0 - neck);
    float side_id = dx < 0.0 ? 3.7 : 11.3;
    float edge_n = fbm_flow(vec2(side_id, s * 5.0)) - 0.47;
    float hw = hw0 + clamp(edge_n * 3.0, -inward, 2.0);
    // Beads: droplets clinging to the edge and sliding down with it (round outward bulges).
    float bead_f = vnoise(vec2(side_id * 7.0, s * 11.0));
    float bead = smoothstep(0.72, 0.9, bead_f) * smoothstep(20.0, 60.0, p.y);
    hw += 2.6 * bead;
    // Lip: the water rolls over the opening a little wider than it falls.
    hw += 2.0 * exp(-p.y / 6.0);
    // Foot: the column splays over the last ~14px as it hits the floor (outward only).
    if (impact) {
        hw += 8.0 * pow(clamp(1.0 - (h - p.y) / 14.0, 0.0, 1.0), 2.0);
    }
    float e = hw - abs(dx);

    vec4 result = vec4(0.0);

    // 1) Shadow cast on the wall behind (2.5D separation). Away from the nearest lamp if one reaches.
    {
        vec2 off = vec2(7.0, 4.0);
        float strength = 0.30;
        if (light_count > 0) {
            vec2 d = world - lights[0].xy;
            float reach = 1.0 - clamp(length(d) / max(lights[0].z, 1.0), 0.0, 1.0);
            off = mix(off, normalize(d) * 14.0, clamp(reach * 2.0, 0.0, 1.0));
            strength += 0.25 * reach;
        }
        vec2 q = p - off;
        float inside = smoothstep(-7.0, 7.0, hw0 - abs(q.x - cx))
            * smoothstep(0.0, 10.0, q.y) * (1.0 - smoothstep(h - 6.0, h, q.y));
        inside *= smoothstep(0.0, 6.0, flow_head - q.y) * smoothstep(-2.0, 4.0, q.y - flow_tail);
        result = vec4(vec3(0.0), inside * strength * step(0.0, -e));
    }

    // 2) A few droplets that let go of the edge, motion-blurred by their speed.
    float drops = 0.0;
    // Cost: the draw rect is much wider than the water (splash margin). Droplets never go farther than
    // ~16px from the edge, so pixels beyond that skip the loop (frame spikes measured on 2-1).
    if (abs(dx) < hw0 + 18.0) {
        for (int i = 0; i < 10; i++) {
            float fi = float(i);
            float sd = mod(fi, 2.0) * 2.0 - 1.0;
            float r1 = hash(vec2(fi, 1.7));
            float r2 = hash(vec2(fi, 8.3));
            float r3 = hash(vec2(fi, 4.1));
            float period = 0.45 + r1 * 0.4;
            float age = fract(t / period + r2);
            float tt = age * period;
            float y0 = mix(0.15, 0.85, r3) * h;
            float v0 = fall_speed(y0);
            float yy = y0 + v0 * tt + 0.5 * gravity * tt * tt;
            float xx = cx + sd * (hw0 + 2.0 + (2.0 + r1 * 9.0) * age);
            float len = clamp((v0 + gravity * tt) / 160.0, 1.5, 6.0);
            float rad = 1.1 + r2 * 1.0;
            float d = length(vec2((p.x - xx) / rad, max(abs(p.y - (yy - len * 0.5)) - len * 0.5, 0.0) / rad));
            float a = (1.0 - smoothstep(0.7, 1.2, d)) * smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.75, 1.0, age));
            a *= step(yy, h - 4.0) * smoothstep(0.0, 6.0, flow_head - yy);
            drops = max(drops, a);
        }
    }
    result = over(result, vec4(vec3(drop_v), drops * 0.9));

    // 3) Body.
    if (e > -1.0 && p.y >= 0.0) {
        float cover = smoothstep(-0.8, 0.8, e) * smoothstep(0.0, 2.0, p.y) * present;
        if (impact) {
            cover *= 1.0 - smoothstep(h - 2.0, h + 1.0, p.y);
        } else if (hard_end) {
            cover *= 1.0 - step(h, p.y);
        } else {
            cover *= 1.0 - smoothstep(h - 9.0, h + 5.0, p.y);
        }
        // c: 0 in the core, 1 at the rim. A narrow stream is all rim-to-rim (a tube); a wide sheet is flat
        // in the middle and curls only near its sides.
        float c = 1.0 - clamp(e / min(max(hw, 1.0), 22.0), 0.0, 1.0);
        float th = sqrt(max(1.0 - c * c, 0.0));

        // Small, short tears in wide sheets only: they ride down with the water (sampled on the parcel
        // clock) and never reach the lip or the foot.
        float hf = vnoise(vec2(p.x / 8.0, s * 14.0)) * 0.65 + vnoise(vec2(p.x / 4.0 + 13.0, s * 18.0)) * 0.35;
        float tear_zone = wide_k * smoothstep(34.0, 70.0, p.y) * (1.0 - smoothstep(h - 44.0, h - 18.0, p.y))
            * smoothstep(10.0, 30.0, e);
        float tear = smoothstep(0.80, 0.83, hf) * tear_zone;
        float tear_rim = (smoothstep(0.76, 0.80, hf) - tear) * tear_zone;
        // Treat the tear edge like a sheet edge: bright, dense rim.
        c = max(c, tear_rim);

        // Fresnel: looking through the tube at its rims crosses more water -> brighter and denser there;
        // the core stays see-through.
        float fres = pow(c, 1.6);
        float lens = -sd_px * c * min(hw, 20.0) * 0.9;
        float bg = texture(screen_tex, suv + vec2(lens, 0.0) * px).r;
        float core = core_base + bg * core_bg;
        // Vertical glints and lighter strands sliding down (low time frequency: no flicker).
        float strand = fbm_flow(vec2(p.x / 4.5, s * 8.0));
        float lane = vnoise(vec2(p.x / 34.0, s * 1.2));
        float glint = smoothstep(0.55, 0.75, strand);
        float dark_line = smoothstep(0.38, 0.22, strand);
        float lightness = core + glint * glint_k - dark_line * dark_k + (lane - 0.5) * 0.10 * (0.4 + 0.6 * wide_k);
        // A little aeration builds toward the bottom.
        lightness = mix(lightness, aer_v, smoothstep(h * 0.5, h, p.y) * 0.25);
        // Lighting: key from the upper left plus nearby lamps.
        vec3 n = normalize(vec3(sd_px * c * 1.4 + (strand - 0.5) * 0.6, -0.1, th + 0.2));
        vec3 key = normalize(vec3(-0.55, -0.65, 0.55));
        float diff = max(dot(n, key), 0.0);
        vec2 ll = lamp_light(n, world);
        float rim_col = rim_v + rim_k * diff + 0.12 * ll.x;
        float col = mix(lightness, rim_col, fres);
        // Thin bright glint line just inside each rim (a glass tube edge).
        // For black water this line is its silver sheen, so it follows the light (no even outline).
        col += exp(-pow((e - 2.2) / 1.1, 2.0)) * edge_add * (water_tone == 0 ? 0.3 + diff : 1.0 + 1.2 * diff);
        // The bead value depends only on side and time, so keep its highlight at the edge
        // (applied across the body it lit a whole half-sheet band on wide black water).
        col += ll.y * 0.35 + bead * exp(-max(e, 0.0) / 3.0) * (water_tone == 0 ? 0.15 : 0.08);
        // Lip highlight where the water rolls over the opening.
        col += exp(-pow((p.y - 5.0) / 4.0, 2.0)) * lip_k;
        float alpha = cover * mix(alpha_lo, 1.0, max(fres, smoothstep(0.0, 14.0, -p.y + 14.0) * 0.6));
        alpha *= 1.0 - tear * 0.82;
        result = over(result, vec4(vec3(clamp(col, 0.0, 1.0)), alpha));
    }

    // 4) Impact on a hard floor.
    // Everything in the impact (crown, spray, floor sheet) stays within ~110px above the floor.
    if (impact && flow_head >= h - 1.0 && flow_tail < h - 2.0 && p.y > h - 110.0) {
        float bw = hw0 + 6.0;
        float fy = extent.y;
        float face_top = fy - back_depth - 1.0;
        float out_d = abs(dx) - bw;
        // The scoped floor wetting follows the actual column width in every tone.
        float floor_width = low_floor_impact
            ? 1.0 - smoothstep(w * 0.45, w * 0.5, abs(dx)) : 1.0;

        // a) Glossy floor sheet: thin bright water on the floor top, a highlight line riding on it.
        float reach = clamp(w * 1.4, 70.0, 150.0) + wide_k * 30.0;
        if (out_d > -bw && out_d < reach) {
            float k = clamp(out_d / reach, 0.0, 1.0);
            float thick = mix(3.0, 1.0, sqrt(max(k, 0.0)));
            float in_sheet = smoothstep(face_top - thick, face_top - thick + 1.0, p.y) * step(p.y, fy);
            float ripple = vnoise(vec2((out_d - t * 110.0) / 14.0, 1.0));
            float top_line = exp(-pow((p.y - (face_top - thick + 0.6)) / 0.7, 2.0));
            float a = in_sheet * (0.45 + 0.2 * ripple) * (1.0 - k * k);
            result = over(result, vec4(vec3(sheet_v), a * floor_width));
            result = over(result, vec4(vec3(hi_v), top_line * (0.5 + 0.4 * ripple) * (1.0 - k) * floor_width));
        }
        // b) Bright foam where the water lands.
        float strip = (1.0 - smoothstep(bw - 2.0, bw + 2.0, abs(dx)))
            * smoothstep(h - 9.0 - 3.0 * vnoise(vec2(p.x / 6.0, t * 5.0)), h - 5.0, p.y) * step(p.y, fy);
        result = over(result, vec4(vec3(foam_v), strip * 0.95 * floor_width));

        if (low_floor_impact && water_tone == 1) {
            result = over(result, low_floor_splash(p, t, bw, face_top, wide_k));
        } else {
        // c) Crown splash: thin petal walls rising from the foot that bend outward toward the top
        //    (x = x0 + L v^2, y = h - H v), each a translucent sheet with bright edges, torn into
        //    fingers at the top. Two petals per side.
        float crown_h = clamp(w * 0.75, 24.0, 52.0);
        float crown_l = clamp(w * 0.6, 26.0, 52.0);
        for (int i = 0; i < 2; i++) {
            float fi = float(i);
            float seed = sd_px * 3.0 + fi * 11.0;
            float H = crown_h * (1.0 - 0.35 * fi) * (0.85 + 0.3 * vnoise(vec2(t * 2.6, seed + 1.0)));
            float L = crown_l * (1.0 + 0.5 * fi) * (0.9 + 0.2 * vnoise(vec2(t * 2.1, seed + 7.0)));
            float v = (h - p.y) / H;
            if (v > 0.0 && v < 1.0) {
                float x0 = bw - 6.0 + 4.0 * fi;
                float xc = x0 + L * v * v;
                float slope = 2.0 * L * v / H;
                float dist = (abs(dx) - xc) / sqrt(1.0 + slope * slope);
                float tk = mix(5.5, 2.2, v);
                float body = 1.0 - smoothstep(tk * 0.5, tk * 0.5 + 0.8, abs(dist));
                float edge = exp(-pow((abs(dist) - tk * 0.5) / 0.6, 2.0));
                // Fingers: near the top the wall tears into separate tongues.
                float tongue = smoothstep(0.35, 0.6, vnoise(vec2(v * 5.0 + t * 1.5, seed * 4.0 + floor(p.x / 3.0))));
                float torn = mix(1.0, tongue, smoothstep(0.7, 0.95, v));
                float keep = torn * smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.88, 1.0, v)) * (1.0 - 0.25 * fi);
                // Body in the water's tone, edges as highlights (silver on black).
                result = over(result, vec4(vec3(splash_v), body * 0.5 * keep));
                result = over(result, vec4(vec3(hi_v), edge * 0.55 * keep));
            }
        }
        // Faint film inside the crown (the far wall seen through the near one).
        float vin = (h - p.y) / crown_h;
        float inner = step(0.0, vin) * (1.0 - smoothstep(0.4, 0.9, vin)) * (1.0 - smoothstep(bw - 6.0, bw - 6.0 + crown_l * 0.8, abs(dx))) * step(bw, abs(dx));
        result = over(result, vec4(vec3(splash_v), inner * 0.12));
        // d) Wide sheets also splash along their whole foot: a row of spikes rising above the landing.
        if (wide_k > 0.0 && abs(dx) < hw0) {
            float fk = p.x / 15.0 + 2.0 * vnoise(vec2(p.x / 50.0, 3.0));
            float tri = 1.0 - abs(fract(fk) - 0.5) * 2.0;
            float on = smoothstep(0.45, 0.8, vnoise(vec2(floor(fk) * 2.7, t * 2.4)));
            float hgt = (4.0 + 14.0 * vnoise(vec2(floor(fk) * 5.3, t * 1.9))) * pow(tri, 3.0) * on;
            float sp = smoothstep(h - 6.0 - hgt - 0.6, h - 6.0 - hgt + 0.6, p.y) * step(p.y, h - 3.0);
            result = over(result, vec4(vec3(splash_v), sp * 0.6 * wide_k));
        }
        // e) Droplets flung from the crown fingers (and along a wide foot).
        float spray = 0.0;
        for (int i = 0; i < 16; i++) {
            float fi = float(i);
            float sd = mod(fi, 2.0) * 2.0 - 1.0;
            float period = 0.5 + hash(vec2(fi, 3.0)) * 0.35;
            float age = fract(t / period + hash(vec2(fi, 9.0)));
            float sec = age * period;
            float r = hash(vec2(fi, 31.0));
            vec2 start = vec2(cx + sd * (bw - 6.0 + crown_l * (0.6 + 0.6 * r)), h - crown_h * (0.75 + 0.25 * r));
            if (wide_k > 0.5 && mod(fi, 4.0) < 2.0) {
                start = vec2((hash(vec2(fi, 51.0)) * 0.9 + 0.05) * w, h - 14.0);
            }
            float vx = sd * (40.0 + hash(vec2(fi, 12.0)) * 90.0);
            float vy = 70.0 + hash(vec2(fi, 25.0)) * 110.0;
            vec2 pos = start + vec2(vx * sec, -vy * sec + 450.0 * sec * sec);
            vec2 vel = vec2(vx, -vy + 900.0 * sec);
            vec2 dir = normalize(vel);
            vec2 rel = p - pos;
            float along = dot(rel, dir);
            float across = dot(rel, vec2(-dir.y, dir.x));
            float rad = 1.0 + hash(vec2(fi, 41.0)) * 0.9;
            float l = clamp(length(vel) / 120.0, 0.5, 3.0);
            float dd = length(vec2(across / rad, max(abs(along + l * 0.5) - l * 0.5, 0.0) / rad));
            float a = (1.0 - smoothstep(0.7, 1.2, dd)) * smoothstep(0.0, 0.05, age) * step(pos.y, fy - 1.0);
            spray = max(spray, a);
        }
        result = over(result, vec4(vec3(drop_v), spray * 0.95));
        }
    }
    return result;
}

void vertex() {
    pixel = VERTEX + vec2(extent.x * 0.5, 0.0);
    world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    COLOR = stream(pixel, SCREEN_UV, SCREEN_PIXEL_SIZE, phase + (animate ? anim_time : 0.0));
}
