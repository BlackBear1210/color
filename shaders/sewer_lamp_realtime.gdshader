shader_type canvas_item;
// Approved ver.2 lamp cage: thin dark iron frame around capsule glass, 2 vertical and
// 2 horizontal bars, a top cap with a hanging ring, and a small bottom finial.
// Iron is dark and rough; the glass glow lights its inner edge so it reads as metal, not plastic.
const float HW = 12.5;
const float HH = 22.0;
float capsule(vec2 p) {
 return length(vec2(p.x, max(abs(p.y) - (HH - HW), 0.0))) - HW;
}
float edge(float d) { return 1.0 - smoothstep(-0.6, 0.6, d); }
void fragment() {
 vec2 p = (UV - 0.5) * vec2(48.0, 76.0);
 float d = capsule(p);
 float frame = edge(abs(d) - 1.9);
 float inside = edge(d + 0.5);
 float vbar = edge(abs(abs(p.x) - 4.2) - 1.0) * inside;
 float hbar = edge(abs(abs(p.y) - 7.0) - 1.0) * inside;
 float cap = edge(max(abs(p.x) - 5.5, abs(p.y + HH + 1.2) - 1.6));
 float ring = edge(abs(length(p - vec2(0.0, -HH - 6.0)) - 2.6) - 0.8);
 float fy = p.y - HH;
 float finial = edge(max(abs(p.x) - (2.4 - fy * 0.45), abs(fy - 2.6) - 2.6));
 // Short hanging rod above the ring (the reference lamp hangs, it is not glued to the wall).
 float rod = edge(max(abs(p.x) - 0.7, abs(p.y + 35.5) - 2.5));
 float metal = max(max(frame, max(vbar, hbar)), max(max(cap, rod), max(ring, finial)));
 // Rounded cross-section normals so real lights give a thin specular line on each bar.
 vec2 slope = vec2(0.0);
 if (frame > 0.5) { slope = normalize(p / vec2(HW * HW, HH * HH) + 0.00001) * clamp(d / 1.9, -0.95, 0.95); }
 else if (vbar > 0.5) { slope = vec2(clamp((abs(p.x) - 4.2) * sign(p.x) / 1.0, -0.95, 0.95), 0.0); }
 else if (hbar > 0.5) { slope = vec2(0.0, clamp((abs(p.y) - 7.0) * sign(p.y) / 1.0, -0.95, 0.95)); }
 else { slope = vec2(clamp(p.x / 5.5, -0.9, 0.9), 0.0); }
 float crown = sqrt(max(0.02, 1.0 - dot(slope, slope)));
 NORMAL = normalize(vec3(slope.x, -slope.y, crown));
 float grit = fract(sin(dot(floor(p * 2.0), vec2(127.1, 311.7))) * 43758.5453);
 float iron = 0.035 + 0.025 * grit;
 // Glass glow bounces onto the inner side of the frame and bars.
 float inner_lit = (frame > 0.5 ? smoothstep(0.2, -1.9, d) : 0.0) + (vbar + hbar) * 0.6;
 iron += 0.07 * clamp(inner_lit, 0.0, 1.0);
 COLOR = vec4(vec3(iron), metal);
}
void light() {
 // Wall lamps run at high energy (3.0): keep iron dark and the highlight a thin line,
 // otherwise the whole cage turns pale gray (read as plastic).
 float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0) * 0.5;
 vec3 halfway = normalize(LIGHT_DIRECTION + vec3(0.0, 0.0, 1.0));
 float shine = pow(max(dot(NORMAL, halfway), 0.0), 60.0) * 0.16;
 LIGHT = vec4((COLOR.rgb * diffuse + vec3(shine)) * LIGHT_COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
}
