// The body and the independent cap share paint coordinates, not edge UVs.
// [2026-10-05 Claude] 2.5D shading pass (user: "white wood looks like a flat 2D image;
// add black/shading for depth"). Comments are ASCII-only because this include is
// parsed by the shader compiler; the Korean rationale lives in the wood deck terrain
// script (wood_deck terrain .gd) and the 2026-10-05 work log in docs/.
uniform int wood_mode = 0;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wood_top_grain : source_color, filter_linear_mipmap, repeat_enable;
// Shading proposal chosen by the designer from engine captures:
//   0 = board fitting only (v03 tones), 1 = A soft, 2 = B deep, 3 = C ink outline.
uniform int wood_style = 2;
// Node global position. local_pos + wood_origin = world px, so the 32 px board rows of
// the front art (grain.png: 9 rows per 1024 px at scale 0.28125) can be found exactly.
uniform vec2 wood_origin = vec2(0.0);

// A two-pixel joint with derivative filtering stays legible at different zooms.
float wood_joint(float coordinate) {
 float edge = min(fract(coordinate), 1.0-fract(coordinate));
 float aa = max(fwidth(coordinate)*0.65,0.003);
 return 1.0-smoothstep(0.012,0.012+aa,edge);
}

float deck_grain(float board_coordinate, float depth) {
 return texture(wood_top_grain,vec2(floor(board_coordinate)*0.125+0.02+fract(board_coordinate)*0.085,depth*0.34+0.13)).r;
}

float wood_hash(float n) {
 return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// x = bevel highlight gain, y = bevel shadow gain, z = per-board tone spread, w = ink outline.
vec4 wood_style_params() {
 if (wood_style == 1) { return vec4(0.16, 0.26, 0.08, 0.0); }
 if (wood_style == 2) { return vec4(0.30, 0.52, 0.15, 0.0); }
 if (wood_style == 3) { return vec4(0.30, 0.52, 0.15, 1.0); }
 return vec4(0.0);
}

// Grain contrast for the white body: the printed sheet looked flat because the grain
// only moved white between ~0.68 and 0.82.
float wood_grain_contrast() {
 if (wood_style == 1) { return 1.35; }
 if (wood_style >= 2) { return 1.8; }
 return 1.0;
}

// Front body boards: each 32 px row gets a lit top bevel, a shadowed bottom bevel and its
// own tone, so white boards read as stacked planks instead of one printed sheet.
vec2 wood_front_shade(vec2 t, vec2 world, float g) {
 if (wood_style == 0) { return t; }
 vec4 s = wood_style_params();
 float yy = world.y / 32.0 + 0.016;
 float rowf = fract(yy);
 float rowi = floor(yy);
 // Rounded board: a bright lip just under the joint, then a long fall-off into a dark
 // underside, so every 32 px row reads as a plank with thickness.
 float hi = smoothstep(0.03, 0.06, rowf) * (1.0 - smoothstep(0.09, 0.26, rowf));
 float sh = smoothstep(0.45, 0.97, rowf);
 sh = sh * sh;
 // Row tone plus a slow drift along the row, so neighbouring boards differ a little.
 float tone = (wood_hash(rowi) - 0.5) + 0.6 * (wood_hash(rowi * 3.1 + floor(world.x / 176.0 + wood_hash(rowi) * 3.0)) - 0.5);
 float kw = 1.0 + s.x * hi - s.y * sh + s.z * tone;
 // Black tones are small absolute values; a relative gain needs to be larger to be seen.
 float kb = 1.0 + s.x * 6.0 * hi - s.y * 1.1 * sh + s.z * 3.0 * tone;
 t.y = 0.70 + (t.y - 0.70) * wood_grain_contrast();
 t.y = t.y * kw * (wood_style >= 2 ? 0.92 : 1.0);
 t.x = t.x * kb;
 if (s.w > 0.5) {
  float seam = 1.0 - smoothstep(0.0, 0.05, min(rowf, 1.0 - rowf));
  float butt = 1.0 - smoothstep(0.03, 0.08, g);
  float ink = max(seam, butt);
  t.y = mix(t.y, 0.05, ink * 0.92);
  t.x = mix(t.x, 0.0, ink * 0.85);
 }
 return clamp(t, vec2(0.0), vec2(1.0));
}

vec2 wood_tones_at(vec2 uv, vec2 world) {
 vec4 s = wood_style_params();
 if (wood_mode != 2) {
  vec2 p = vec2(1.0) - abs(mod(uv, vec2(2.0)) - vec2(1.0));
  float g = texture(wood_grain, p).r;
  float black = clamp(g * 0.66, 0.018, 0.25) * 0.50;
  float white = mix(0.12, min(0.84, 0.66 + g * 0.52), smoothstep(0.01, 0.065, g)) * 0.8505;
  return wood_front_shade(vec2(black, white), world, g);
 }
 // UV.y selects independent geometric faces. The top can never wrap a wall.
 if (uv.y >= 4.0) {
  float face = floor(uv.y);
  float across = fract(uv.y);
  if (face > 6.5) {
   // Right end cap line: closes the cut end of the deck (the right side face is hidden).
   return vec2(0.010, mix(0.20, 0.34, across));
  }
  if (face > 5.5) { return vec2(0.014 + 0.05, 0.34 + 0.10); }
  if (face > 4.5) {
   // Right wall shade strip, rows aligned with the front boards.
   float g5 = deck_grain(uv.x * 2.0, across);
   float k5 = mix(0.55, 1.0, across);
   return vec2((0.030 + g5 * 0.08) * k5, (0.36 + g5 * 0.16) * k5);
  }
  // Left side face of the box. uv.x is already the front board row (mesh bakes the
  // 22 px rise), so seams continue around the corner from the front art.
  float course = uv.x;
  float g = deck_grain(course * 2.0, across);
  float joint = wood_joint(course);
  // End grain: rings centred on each board end.
  vec2 q = vec2((across - 0.5) * 0.56, fract(course) - 0.5);
  float rings = 0.5 + 0.5 * sin(length(q) * 70.0 + wood_hash(floor(course)) * 6.0);
  float light = wood_style == 0 ? 1.0 : (wood_style == 1 ? 0.78 : 0.62);
  // Darker toward the back edge: the face turns away from the light.
  light *= wood_style == 0 ? 1.0 : mix(0.78, 1.0, across);
  float black = (0.036 + g * 0.14 + rings * 0.012) * light;
  float white = (0.43 + g * 0.16 + rings * 0.05) * mix(0.78, 1.0, light);
  if (wood_style > 0) { white = (0.40 + g * 0.14 + rings * 0.06) * light + 0.06; }
  vec2 tone = vec2(black, white);
  float ink = s.w > 0.5 ? 0.95 : 0.8;
  return mix(tone, vec2(0.016, s.w > 0.5 ? 0.06 : 0.25), joint * ink);
 }
 if (uv.y >= 2.0) {
  float g = deck_grain(uv.x*4.0,fract(uv.y));
  float light = uv.y < 3.0 ? 1.0 : 0.72;
  return vec2((0.036+g*0.14)*light,(0.43+g*0.16)*light);
 }
 const float split = 0.7333333;
 float depth = clamp(uv.y / split, 0.0, 1.0);
 // Board coordinate baked by the mesh: fitted width per deck run and the 18 px
 // projection slant, so both ends of a run land exactly on a board joint.
 float course = uv.x*4.0;
 vec2 p = vec2(course*0.125,depth*0.34+0.13);
 float grain = deck_grain(course,depth);
 float seam = wood_joint(course);
 float tone = (wood_hash(floor(course) + floor(wood_origin.x * 0.01)) - 0.5) * s.z * 2.0;
 float top_black = mix((0.080 + grain*0.22) * (1.0 + tone * 2.0), 0.018, seam*0.85);
 float top_white = mix((0.67 + grain*0.18) * (1.0 + tone), s.w > 0.5 ? 0.06 : 0.30, seam*(s.w > 0.5 ? 0.95 : 0.72));
 if (uv.y < split) {
  float arris = smoothstep(0.66,0.70,uv.y);
  if (wood_style > 0) {
   // Lit from the front-top: the receding back of the deck is a little darker,
   // the front arris catches a thin highlight.
   float back = 1.0 - depth;
   top_white *= 1.0 - back * (0.06 + s.y * 0.25);
   top_black *= 1.0 - back * 0.25;
   arris = smoothstep(0.86, 0.99, depth);
   return vec2(top_black + arris * 0.025, min(0.92, top_white + arris * 0.06));
  }
  return vec2(top_black+arris*0.010, min(0.88,top_white+arris*0.020));
 }
 // Short end grain beneath the cap; a dark joint anchors it to the broad front.
 float y = (uv.y-split)/(1.0-split);
 float rings = sin(p.x*220.0 + sin(y*5.0)*1.5);
 float contact = smoothstep(0.65,1.0,y);
 float black = (0.060+grain*0.14+rings*0.005)*(1.0-contact*0.55);
 float white = (0.64+grain*0.18+rings*0.015)*(1.0-contact*0.22);
 if (wood_style > 0) {
  // The lip faces the viewer under the deck: slightly darker than the deck top,
  // with a deeper contact shadow where it meets the body boards.
  white = (0.56 + grain * 0.16 + rings * 0.015) * (1.0 - contact * (0.25 + s.y * 0.5));
  black = black * (1.0 - contact * 0.3);
  if (s.w > 0.5) { white = mix(white, 0.06, smoothstep(0.80, 1.0, y)); }
 }
 return vec2(black,white);
}

// Old entry point kept for callers that have no world position.
vec2 wood_tones(vec2 uv) {
 return wood_tones_at(uv, vec2(0.0));
}
