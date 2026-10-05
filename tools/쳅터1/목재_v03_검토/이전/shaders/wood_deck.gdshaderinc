// Top-only deck: parallel boards run into depth, with aligned end grain below.
uniform int wood_mode = 0;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap, repeat_enable;

vec2 wood_tones(vec2 uv) {
 vec2 tex_uv = uv;
 float joint = 0.0;
 float top = 0.0;
 float board = 0.0;
 if (wood_mode == 2) {
  top = 1.0 - step(0.72, uv.y);
  // Constant oblique projection; no vanishing point. About 31px per board.
  float depth = min(uv.y / 0.72, 1.0);
  float across = uv.x * 9.0 + (1.0 - depth) * 0.36;
  board = floor(across);
  float x = fract(across);
  joint = 1.0 - smoothstep(0.008, 0.033, min(x, 1.0-x));
  // Rotate the existing long grain into the depth direction on the top face.
  tex_uv = vec2(depth * 0.48 + board * 0.173, (x * 0.75 + 0.12) / 9.0);
  if (top < 0.5) {
   tex_uv = vec2(x * 0.12 + board * 0.173, 0.04 + (uv.y-0.72)*0.48);
  }
 }
 tex_uv = vec2(1.0) - abs(mod(tex_uv, vec2(2.0)) - vec2(1.0));
 float g = texture(wood_grain, tex_uv).r;
 float black = clamp(g * 0.66, 0.018, 0.25);
 float white = mix(0.12, min(0.84, 0.66 + g * 0.52), smoothstep(0.01, 0.065, g)) * 0.945;
 if (wood_mode == 1) {
  black *= 0.50;
  white *= 0.90;
 }
 if (wood_mode == 2) {
  float variation = 0.94 + 0.06 * sin(board * 2.399);
  black *= mix(0.50, variation, top);
  white *= mix(0.86, variation, top);
  black = mix(black, 0.012, joint * 0.85);
  white = mix(white, 0.24, joint * 0.72);
  // One front arris and a contact shadow, never a repeated perimeter frame.
  float arris = smoothstep(0.66, 0.69, uv.y) * (1.0-smoothstep(0.70, 0.73, uv.y));
  float shadow = step(0.73, uv.y) * (1.0-smoothstep(0.75, 0.97, uv.y));
  black = black * (1.0-shadow*0.30) + arris*0.032;
  white = white * (1.0-shadow*0.15) + arris*0.035;
 }
 return vec2(black, white);
}
