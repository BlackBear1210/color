shader_type canvas_item;
render_mode unshaded;
// Approved ver.2 lamp: capsule glass (straight sides, round ends), lit from inside.
// Must match the capsule in sewer_lamp_realtime.gdshader (half width 12.5, half height 22).
const float HW = 12.5;
const float HH = 22.0;
float capsule(vec2 p) {
 return length(vec2(p.x, max(abs(p.y) - (HH - HW), 0.0))) - HW;
}
void fragment() {
 vec2 p = (UV - 0.5) * vec2(48.0, 76.0);
 float d = capsule(p);
 float alpha = 1.0 - smoothstep(-0.6, 0.6, d + 1.2);
 // Frosted glass glows brightest at the core and dims toward the frame.
 float inner = clamp(-d / HW, 0.0, 1.0);
 float glow = 0.80 + 0.19 * smoothstep(0.0, 0.75, inner);
 // Cage bars block some light: a soft dark halo around each bar on the glass.
 float bars = min(abs(abs(p.x) - 4.2), abs(abs(p.y) - 7.0));
 glow -= 0.10 * (1.0 - smoothstep(1.0, 3.2, bars));
 // One vertical reflection streak on the curved glass (left side).
 float streak = exp(-pow((p.x + 7.2) / 1.1, 2.0)) * smoothstep(HH - 2.0, 6.0, abs(p.y));
 glow += 0.10 * streak;
 COLOR = vec4(vec3(clamp(glow, 0.0, 1.0)), alpha);
}
