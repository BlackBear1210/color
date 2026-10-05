// The body and the independent cap share paint coordinates, not edge UVs.
uniform int wood_mode = 0;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wood_top_grain : source_color, filter_linear_mipmap, repeat_enable;

vec2 wood_tones(vec2 uv) {
 if (wood_mode != 2) {
  vec2 p = vec2(1.0) - abs(mod(uv, vec2(2.0)) - vec2(1.0));
  float g = texture(wood_grain, p).r;
  float black = clamp(g * 0.66, 0.018, 0.25) * 0.50;
  float white = mix(0.12, min(0.84, 0.66 + g * 0.52), smoothstep(0.01, 0.065, g)) * 0.8505;
  return vec2(black, white);
 }
 // UV.y selects independent geometric faces. The top can never wrap a wall.
 if (uv.y >= 4.0) {
  float face = floor(uv.y);
  float across = fract(uv.y);
  float g = texture(wood_grain, vec2(uv.x * 0.13, across * 0.07)).r;
  float band = sin(uv.x * 6.2831853) * 0.004;
  if (face > 5.5) { return vec2(0.014 + g*0.09, 0.34 + g*0.30); }
  float light = face < 4.5 ? 1.0 : 0.62;
  return vec2((0.035 + g*0.18 + band)*light, (0.49 + g*0.22)*mix(0.78,1.0,light));
 }
 if (uv.y >= 2.0) {
  float rings = sin(uv.x * 120.0 + sin(fract(uv.y)*8.0)*2.0);
  float light = uv.y < 3.0 ? 1.0 : 0.72;
  return vec2((0.068 + rings*0.008)*light, (0.61 + rings*0.025)*light);
 }
 const float split = 0.7333333;
 float depth = clamp(uv.y / split, 0.0, 1.0);
 vec2 p = vec2(uv.x + (1.0-depth)*0.028, depth*0.34 + 0.13);
 float grain = texture(wood_top_grain, p).r;
 float seam = 1.0-smoothstep(0.005,0.025,grain);
 float top_black = mix(0.12 + grain*0.30, 0.026, seam*0.80);
 float top_white = mix(0.78 + grain*0.18, 0.38, seam*0.60);
 if (uv.y < split) {
  float arris = smoothstep(0.66,0.70,uv.y);
  return vec2(top_black+arris*0.024, min(0.93,top_white+arris*0.035));
 }
 // Short end grain beneath the cap; a dark joint anchors it to the broad front.
 float y = (uv.y-split)/(1.0-split);
 float rings = sin(p.x*220.0 + sin(y*5.0)*1.5);
 float contact = smoothstep(0.65,1.0,y);
 float black = (0.060+grain*0.14+rings*0.005)*(1.0-contact*0.55);
 float white = (0.64+grain*0.18+rings*0.015)*(1.0-contact*0.22);
 return vec2(black,white);
}
