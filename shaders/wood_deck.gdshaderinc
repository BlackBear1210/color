// Same relief source for both paint colors. No inverted grooves or extra rim light.
uniform int wood_mode = 0;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap, repeat_enable;

vec2 wood_tones(vec2 uv) {
 vec2 tex_uv = uv;
 float joint = 0.0;
 float top = 0.0;
 if (wood_mode == 2) {
  top = 1.0 - step(0.72, uv.y);
  float row = min(floor(uv.y / 0.24), 2.0);
  float y = fract(uv.y / 0.24);
  float x = fract(uv.x + row * 0.37 + uv.y * 0.035);
  float gap = min(min(x, 1.0-x), min(abs(x-0.17), min(abs(x-0.43), abs(x-0.75))));
  float end_gap = 1.0 - smoothstep(0.0, 0.005, gap);
  float row_gap = 1.0 - smoothstep(0.0, 0.10, min(y, 1.0-y));
  joint = max(end_gap, row_gap) * top;
  tex_uv = vec2(uv.x + row * 0.19, (row + 0.15 + y * 0.65) / 9.0);
  if (top < 0.5) { tex_uv.y = 0.04 + (uv.y-0.72)*0.24; }
 }
 // Mirror the source to avoid a hard seam even when the source border differs by a pixel.
 tex_uv = vec2(1.0) - abs(mod(tex_uv, vec2(2.0)) - vec2(1.0));
 float g = texture(wood_grain, tex_uv).r;
 float black = clamp(g * 0.66, 0.018, 0.25);
 float white = mix(0.12, min(0.84, 0.66 + g * 0.52), smoothstep(0.01, 0.065, g)) * 0.945;
 if (wood_mode == 2) {
  black = black * mix(0.90, 1.28, top) + top * 0.020;
  white *= mix(0.85, 1.03, top);
  black = mix(black, 0.025, joint * 0.75);
  white = mix(white, 0.16, joint * 0.75);
  float lip = 1.0-smoothstep(0.006,0.024,abs(uv.y-0.72));
  black *= 1.0-lip*0.24;
  white *= 1.0-lip*0.20;
 }
 return vec2(black, white);
}
