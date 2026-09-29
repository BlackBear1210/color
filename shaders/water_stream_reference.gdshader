shader_type canvas_item;
render_mode unshaded;
// Falling-stream look v3 (kinds 0 and 1 only). Pools and other kinds keep v2.
// Body is procedural so any width/height keeps its pixel density.
// The impact splash is baked frames from tools/ (see header of the python baker).
// Collision is NOT drawn here; the hit rectangle stays inside the narrowest body width.

uniform sampler2D flow_texture : filter_linear, repeat_enable;
uniform sampler2D splash_sheet : filter_linear, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform bool impact = true;
uniform bool colored_splash = false;
uniform int water_tone = 1;
uniform vec2 extent = vec2(64.0, 320.0);
uniform int kind = 0;
uniform float speed = 130.0;
uniform float back_depth = 4.0;
uniform float hit_inset = 7.0;
uniform float phase = 0.0;
uniform bool animate = true;
// Fed every frame by the owning script at runtime (not TIME). A shader that reads TIME
// forces the Godot editor to redraw every frame, which steals GPU from the running game.
uniform float anim_time = 0.0;
uniform float refraction = 1.0;
// Turn-on / turn-off flow (valves, reservoirs, hoppers): water is drawn only between
// flow_tail (top, moves down after the valve closes) and flow_head (front, falls down after it opens).
uniform float flow_head = 100000.0;
uniform float flow_tail = -100000.0;

// Must match the baker constants.
const float FRAMES = 16.0;
const float COLS = 4.0;
const vec2 FRAME_SIZE = vec2(384.0, 128.0);
const vec2 IMPACT_IN_FRAME = vec2(192.0, 112.0);
const float REF_W = 64.0;
const float SPLASH_FPS = 20.0;

varying vec2 pixel;

float rand1(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
float flow_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    float n = cell.x+cell.y*57.0;
    return mix(mix(rand1(n),rand1(n+1.0),f.x),mix(rand1(n+57.0),rand1(n+58.0),f.x),f.y);
}

vec4 fine_splash(vec2 p, float cx, float h, float w, float t) {
    if (abs(p.x-cx) > w*0.5+75.0 || p.y < h-92.0 || p.y > h+2.0) return vec4(0.0);
    float a = 0.0;
    float sparkle = 0.0;
    for (int i=0; i<42; i++) {
        float n = float(i);
        float age = fract(t*(1.1+rand1(n+4.0)*0.9)+rand1(n+9.0));
        float side = mod(n,2.0)*2.0-1.0;
        float vx = side*(30.0+rand1(n+12.0)*85.0);
        float vy = 130.0+rand1(n+25.0)*130.0;
        float seconds = age*0.65;
        vec2 pos = vec2(cx+side*w*0.20+vx*seconds, h-vy*seconds+350.0*seconds*seconds);
        vec2 delta = p-pos;
        float radius = 0.65+rand1(n+33.0)*1.15;
        float d = length(delta/vec2(radius,radius*1.4));
        float dot_alpha = (1.0-smoothstep(0.55,1.5,d))*(1.0-smoothstep(0.65,1.0,age));
        a = max(a,dot_alpha);
        sparkle = max(sparkle,dot_alpha*rand1(n+46.0));
    }
    float tone = water_tone == 1 ? 0.96 : (water_tone == 0 ? 0.085 : 0.62);
    return vec4(vec3(tone+sparkle*(water_tone==1 ? 0.02 : 0.14)),a*0.9);
}

// Per tone: body, see-through, body mix, rim L, rim R, flow sign*strength, edge, foam lo, foam hi.
// White foam is kept BELOW the white body so the impact reads as a separate shape.
void tone_params(int tone, out float body, out float see, out float mixb, out float rim_l,
        out float rim_r, out float flow, out float edge, out float foam_lo, out float foam_hi) {
    if (tone == 0) {
        body = 0.04; see = 0.06; mixb = 0.90; rim_l = 0.59; rim_r = 0.31;
        flow = 0.235; edge = 0.0; foam_lo = 0.18; foam_hi = 0.55;
    } else if (tone == 2) {
        body = 0.50; see = 0.30; mixb = 0.72; rim_l = 0.33; rim_r = 0.18;
        flow = 0.13; edge = -0.22; foam_lo = 0.59; foam_hi = 0.88;
    } else {
        body = 0.91; see = 0.20; mixb = 0.85; rim_l = 0.086; rim_r = 0.04;
        flow = -0.165; edge = -0.43; foam_lo = 0.70; foam_hi = 0.84;
    }
}

float wobble(float y, float t, float h) {
    // Reference look: straight sides. Side wobble is deferred (kept as 0 on purpose).
    return 0.0 * (y + t + h);
}

vec4 over(vec4 under, vec4 front) {
    float a = front.a + under.a * (1.0 - front.a);
    return vec4((front.rgb * front.a + under.rgb * under.a * (1.0 - front.a)) / max(a, 0.0001), a);
}

// Reference impact: curved leaf-shaped sheets thrown up and out on both sides, in the water's own
// tone, plus a bright foam band on the contact line. Each leaf lives briefly and restarts.
vec4 leaf_spray(vec2 p, float cx, float h, float w, float t) {
    if (abs(p.x - cx) > w * 0.5 + 90.0 || p.y < h - 70.0 || p.y > h + 3.0) return vec4(0.0);
    float a = 0.0;
    float lit = 0.0;
    for (int i = 0; i < 20; i++) {
        float n = float(i);
        float side = mod(n, 2.0) * 2.0 - 1.0;
        float age = fract(t * (0.9 + rand1(n + 3.0) * 0.8) + rand1(n + 7.0));
        float ang = mix(0.35, 1.25, rand1(n + 11.0));
        vec2 dir = vec2(side * sin(ang), -cos(ang));
        float len = (18.0 + rand1(n + 17.0) * 34.0) * (0.35 + age * 0.9);
        vec2 base = vec2(cx + side * (w * 0.35 + rand1(n + 19.0) * 6.0), h - 1.0);
        vec2 mid = base + dir * len * 0.55;
        vec2 d = p - mid;
        float along = dot(d, dir);
        float across = dot(d, vec2(-dir.y, dir.x));
        float width = (2.8 + rand1(n + 23.0) * 4.0) * (1.0 - abs(along) / max(len * 0.55, 1.0));
        float leaf = (1.0 - smoothstep(width * 0.6, width, abs(across + 0.02 * along * along * side)))
            * step(abs(along), len * 0.55);
        leaf *= (1.0 - smoothstep(0.6, 1.0, age)) * smoothstep(0.0, 0.08, age);
        a = max(a, leaf);
        lit = max(lit, leaf * step(0.0, -across * side));
    }
    float foam = exp(-pow((p.x - cx) / (w * 0.95 + 8.0), 2.0)) * exp(-pow((p.y - h + 1.5) / 2.2, 2.0));
    foam *= 0.6 + 0.4 * flow_noise(vec2(p.x / 3.0 + t * 6.0, 1.0));
    float tone = water_tone == 1 ? 0.93 : (water_tone == 0 ? 0.07 : 0.55);
    float hi = water_tone == 1 ? 1.0 : (water_tone == 0 ? 0.42 : 0.85);
    vec4 leaves = vec4(vec3(mix(tone, hi, lit * 0.6)), a * 0.92);
    float foam_tone = water_tone == 0 ? 0.35 : 0.95;
    return over(leaves, vec4(vec3(foam_tone), foam * 0.8));
}

vec4 splash_at(vec2 p, float center, float ground, float bottom_w, float t, float seed,
        float body, float foam_lo, float foam_hi) {
    float sc = clamp(bottom_w / (REF_W * 0.85), 0.7, 1.6);
    vec2 f = (p - vec2(center, ground)) / sc + IMPACT_IN_FRAME;
    if (f.x < 0.0 || f.y < 0.0 || f.x >= FRAME_SIZE.x || f.y >= FRAME_SIZE.y) {
        return vec4(0.0);
    }
    float idx = floor(mod(t * SPLASH_FPS + seed * FRAMES, FRAMES));
    vec2 cell = vec2(mod(idx, COLS), floor(idx / COLS));
    vec2 sheet = vec2(COLS, FRAMES / COLS) * FRAME_SIZE;
    vec4 s = texture(splash_sheet, (cell * FRAME_SIZE + f) / sheet);
    float v = mix(mix(foam_lo, foam_hi, s.r), body, s.g);
    // Airborne water keeps its identity; only surface contact gets darker shading.
    if (colored_splash) {
        float airborne = 1.0 - smoothstep(ground - 5.0, ground - 1.0, p.y);
        float own_tone = water_tone == 1 ? mix(0.90, 0.98, s.r)
            : (water_tone == 0 ? mix(0.035, 0.16, s.r) : mix(0.46, 0.62, s.r));
        v = mix(v, own_tone, airborne);
    }
    return vec4(vec3(v), s.a);
}

vec4 stream(vec2 p, vec2 screen_uv, vec2 px_size, float t) {
    float w = extent.x;
    float h = extent.y;
    if (impact) h = max(1.0, h - back_depth * 0.5);
    float body; float see; float mixb; float rim_l; float rim_r; float flow; float edge;
    float foam_lo; float foam_hi;
    tone_params(water_tone, body, see, mixb, rim_l, rim_r, flow, edge, foam_lo, foam_hi);

    // Necking while falling, capped so the visual never gets narrower than the hit box.
    float neck = max(0.0, min(hit_inset - 1.0, w * 0.08));
    float yn = clamp(p.y / max(h, 1.0), 0.0, 1.0);
    float hw = w * 0.5 - neck * (1.0 - exp(-yn * 2.2)) + 2.5 * exp(-max(p.y, 0.0) / 6.0);
    float c = w * 0.5 + wobble(p.y, t, h);
    float dx = p.x - c;
    float u = dx / hw;
    float au = clamp(abs(u), 0.0, 1.0);
    float cover = clamp(hw - abs(dx) + 0.5, 0.0, 1.0);
    cover *= smoothstep(0.0, 2.0, p.y);
    if (impact) {
        cover *= 1.0 - smoothstep(h - 3.0, h + 1.0, p.y);
    } else {
        cover *= 1.0 - smoothstep(h - 9.0, h + 5.0, p.y);
    }

    // Falling front: soft rounded head that is slightly narrower; falling tail: soft cut.
    float head_d = flow_head - p.y;
    cover *= smoothstep(0.0, 6.0, head_d) * smoothstep(-2.0, 4.0, p.y - flow_tail);
    float head_neck = 1.0 - smoothstep(0.0, 18.0, head_d);
    cover *= clamp(1.0 - smoothstep(hw * (1.0 - 0.35 * head_neck) - 1.0, hw * (1.0 - 0.35 * head_neck) + 1.0, abs(dx)) + step(head_neck, 0.0), 0.0, 1.0);
    vec4 result = vec4(0.0);
    if (cover > 0.0) {
        // Refraction: the wall behind shows mirrored and squeezed, with a small ripple.
        float ripple = 1.6 * sin(p.y * 0.09 + p.x * 0.21 - t * 5.0);
        float shift = (-u * min(hw, 24.0) * 1.7 + ripple) * refraction;
        float r = texture(screen_tex, screen_uv + vec2(shift, 0.0) * px_size).r;
        float base = body > 0.4 ? r * see + body * (1.0 - see) : r * see;
        float col = base * (1.0 - mixb) + body * mixb;
        col += (r - 0.18) * see * 0.6;
        vec4 fl = texture(flow_texture, vec2(p.x / 128.0, (p.y - t * speed) / 512.0));
        col += flow * pow(fl.r, 3.0) * (0.4 + 0.6 * (1.0 - au * au));
        // Rim highlights in pixels, so wide sheets do not get fat rims.
        float e_l = dx + hw;
        float e_r = hw - dx;
        float rw = body < 0.4 ? min(0.06 * hw, 1.6) : min(0.10 * hw, 2.5);
        float off = min(0.22 * hw, 6.0);
        col += rim_l * exp(-pow((e_l - off) / rw, 2.0));
        col += rim_r * exp(-pow((e_r - off * 0.73) / (rw * 0.8), 2.0));
        if (body < 0.4) {
            col += 0.086 * exp(-pow((u + 0.35) / 0.25, 2.0));
        }
        col += edge * clamp(1.0 - min(e_l, e_r) / min(0.14 * hw, 4.0), 0.0, 1.0);
        col += 0.04 * (fl.g - 0.5);
        // Reference look (approved GPT still): crisp hair-thin vertical strands falling down,
        // thin bright edge lines on both sides, straight sides. One strand per 1.5px column,
        // each with its own brightness and its own on/off rhythm along the fall.
        float falling = p.y - t * speed * 1.4;
        // Sparse, short, slightly wandering strands with plain body between them
        // (dense endless strands read as a fluted stone pillar).
        float sway = sin(falling * 0.021 + p.x * 0.3) * 0.9;
        float cid = floor((p.x + sway + 0.5) / 1.5);
        float cr = rand1(cid * 1.37 + 2.0);
        float along = flow_noise(vec2(cid * 0.73, falling / (28.0 + cr * 60.0)));
        float strand = smoothstep(0.58, 0.88, along) * step(0.25, cr) * (0.55 + 0.45 * cr);
        float wide = flow_noise(vec2(p.x / 14.0, falling / 180.0 + 7.3));
        float net_f = flow_noise(vec2(p.x / 9.0, falling / 24.0)) * 0.6 + flow_noise(vec2(p.x / 4.0, falling / 12.0)) * 0.4;
        float net = smoothstep(0.45, 0.495, abs(fract(net_f * 3.0) - 0.5));
        float thickness = pow(max(0.0, 1.0 - u * u), 0.45);
        // Wide sheets (2-2, 2-5, 2-11: 256-448px) read as a pleated curtain when only hair strands
        // repeat across the whole width. Break them into several broad sub-streams of varying
        // brightness that slide down at their own pace. Narrow streams (<=128) are unchanged.
        float wide_k = smoothstep(120.0, 260.0, w);
        float lane_n = flow_noise(vec2(p.x / 46.0, falling / 420.0 + 11.0));
        float lane_m = flow_noise(vec2(p.x / 17.0, falling / 190.0 + 4.0));
        float lanes = (lane_n * 0.7 + lane_m * 0.3 - 0.5) * wide_k;
        strand *= 1.0 - 0.45 * wide_k;
        float edge_line = exp(-pow((min(e_l, e_r) - 0.7) / 0.6, 2.0));
        float soft_edge = smoothstep(0.0, 1.0, hw - abs(dx));
        cover *= mix(0.8, 1.0, soft_edge);
        if (water_tone == 0) {
            col = 0.030 + strand * 0.34 + wide * 0.04 + lanes * 0.16 + edge_line * 0.52;
        } else if (water_tone == 1) {
            col = 0.86 - strand * 0.30 + wide * 0.07 + lanes * 0.22 - net * 0.05 - (1.0 - thickness) * 0.05 + edge_line * 0.08;
        } else {
            // Gray = mid-tone water about 40% over the wall behind (measured on the reference).
            float water = 0.46 + strand * 0.30 + wide * 0.06 + lanes * 0.22;
            col = mix(r, water, 0.62) + edge_line * 0.45;
        }
        result = vec4(vec3(clamp(col, 0.0, 0.98)), cover);
    }

    // No splash until the falling front reaches the floor, and none after the tail has passed it.
    if (impact && flow_head >= h - 1.0 && flow_tail < h - 2.0) {
        // Wet wall next to the stream near the floor: a thin dark veil, drawn under the water.
        float side = abs(p.x - w * 0.5) - (w * 0.5 - neck);
        float wet = clamp(1.0 - side / 26.0, 0.0, 1.0) * step(-2.0, side);
        wet *= smoothstep(h - 110.0, h - 50.0, p.y) * step(p.y, h);
        result = over(vec4(0.0, 0.0, 0.0, 0.28 * wet), result);

        float bottom_w = 2.0 * (w * 0.5 - neck);
        vec4 sp;
        float cx = w * 0.5 + wobble(h, t, h);
        if (w < 160.0) {
            sp = splash_at(p, cx, h, bottom_w, t, 0.0, body, foam_lo, foam_hi);
        } else {
            float count = ceil(w / 120.0);
            float spacing = w / count;
            float index = clamp(floor(p.x / spacing), 0.0, count - 1.0);
            sp = splash_at(p, (index + 0.5) * spacing, h, spacing * 0.9, t, fract(index * 0.618),
                    body, foam_lo, foam_hi);
        }
        // Soft mist over the impact.
        float mw = min(w, 160.0);
        float mist = 0.18 * exp(-(pow((p.x - cx) / (mw * 1.3), 2.0) + pow((p.y - h + 12.0) / 16.0, 2.0)));
        mist *= 0.85 + 0.15 * sin(t * 7.0);
        result = over(result, vec4(vec3(foam_hi), mist));
        result = over(result, sp);
        // Compact aerated impact crown, kept above the existing contact plane.
        float crown_x = (p.x-cx)/max(bottom_w*0.68,1.0);
        float crown_y = (h-p.y)/24.0;
        float bubbles = texture(flow_texture,vec2((p.x+t*8.0)/22.0,(p.y-t*80.0)/28.0)).g;
        float crown = exp(-crown_x*crown_x*2.0)*exp(-crown_y*crown_y*2.8);
        crown *= step(0.0,crown_y)*smoothstep(0.22,0.70,bubbles)*0.82;
        float crown_tone = water_tone == 1 ? 0.96 : (water_tone == 0 ? 0.12 : 0.75);
        result = over(result,vec4(vec3(crown_tone),crown));
        result = over(result, fine_splash(p,cx,h,bottom_w,t));
        result = over(result, leaf_spray(p,cx,h,bottom_w,t));
    }
    return result;
}

void vertex() {
    pixel = VERTEX + vec2(extent.x * 0.5, 0.0);
}

void fragment() {
    COLOR = stream(pixel, SCREEN_UV, SCREEN_PIXEL_SIZE, phase + (animate ? anim_time : 0.0));
}
