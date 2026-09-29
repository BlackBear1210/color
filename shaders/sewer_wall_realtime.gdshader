shader_type canvas_item;


uniform bool opaque_wall = false;
uniform sampler2D relief_normal : filter_linear, repeat_enable;
uniform float relief_depth : hint_range(0.0, 2.0) = 0.65;
uniform float edge_width : hint_range(0.001, 0.25) = 0.025;
uniform vec4 haze_color : source_color = vec4(0.19, 0.19, 0.19, 1.0);
uniform float atmosphere : hint_range(0.0, 1.0) = 0.15;
// Remap luminance without a fog overlay or a spatial blur.
uniform vec3 tone_curve = vec3(0.35, 0.23, 0.9);
uniform vec2 tone_limits = vec2(0.09, 0.38);
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
// 1: vertical supports, 2: recessed wall panels with broad open bays.
uniform int silhouette_mode = 0;
varying vec4 vertex_tint;
// Screen-space housings: center.xy, half-size.zw. No baked shadow direction.
uniform vec4 lamp_housings[32];
uniform int lamp_housing_count = 0;
uniform float housing_depth = 18.0;
uniform bool housing_shadows = true;

void vertex() {
 vertex_tint = COLOR;
}

void fragment() {
 // Join opposite borders instead of fading masonry to transparent strips.
 vec2 p = clamp(UV, vec2(0.0), vec2(1.0));
 vec2 edge = min(p, vec2(1.0) - p);
 vec2 weight = 0.5 * (vec2(1.0) - smoothstep(vec2(0.0), vec2(edge_width), edge));
 vec2 lo = source_region.xy;
 vec2 span = source_region.zw - lo;
 vec4 a = texture(TEXTURE, lo + p * span);
 // Only border pixels need opposite-edge samples; interiors use one fetch.
 vec4 b = a;
 vec4 c = a;
 vec4 d = a;
 if (weight.x > 0.0) {
  b = texture(TEXTURE, lo + vec2(1.0-p.x, p.y) * span);
 }
 if (weight.y > 0.0) {
  c = texture(TEXTURE, lo + vec2(p.x, 1.0-p.y) * span);
  d = c;
  if (weight.x > 0.0) {
   d = texture(TEXTURE, lo + (vec2(1.0)-p) * span);
  }
 }
 // Premultiplied mixing prevents black RGB in transparent openings leaking into stone.
 vec4 ap = vec4(a.rgb*a.a, a.a);
 vec4 bp = vec4(b.rgb*b.a, b.a);
 vec4 cp = vec4(c.rgb*c.a, c.a);
 vec4 dp = vec4(d.rgb*d.a, d.a);
 vec4 mixed = mix(mix(ap,bp,weight.x),mix(cp,dp,weight.x),weight.y);
 vec3 color = mixed.a > 0.0001 ? mixed.rgb/mixed.a : haze_color.rgb;
 float alpha = mixed.a;
 // Keep the stronger border's coverage where the other side contains an opening.
 float coverage_x = mix(a.a,max(a.a,b.a),weight.x*2.0);
 float coverage_y = mix(c.a,max(c.a,d.a),weight.x*2.0);
 alpha = mix(coverage_x,max(coverage_x,coverage_y),weight.y*2.0);
 float silhouette = 1.0;
 if (silhouette_mode == 1) {
  // Continuous vertical silhouettes have no footings or walkable-looking tops.
  silhouette = 1.0-smoothstep(0.055,0.056,abs(p.x-0.5));
 } else if (silhouette_mode == 2) {
  // Keep the far layer visible instead of covering it with an opaque wall.
  silhouette = 1.0-smoothstep(0.19,0.1913,min(p.x,1.0-p.x));
 }
 float luminance = dot(color,vec3(0.2126,0.7152,0.0722));
 float value = clamp((luminance-tone_curve.x)*tone_curve.z+tone_curve.y,tone_limits.x,tone_limits.y);
 // Real-time lights use the surface normals; no baked directional illumination.
 NORMAL_MAP = texture(relief_normal, p).rgb;
 NORMAL_MAP_DEPTH = relief_depth;
 COLOR = vec4(vec3(value),(opaque_wall ? 1.0 : alpha)*silhouette) * vertex_tint;
}

void light() {
 float visibility = 1.0;
 if (housing_shadows && !LIGHT_IS_DIRECTIONAL) {
  // Project a raised back housing onto the wall along each actual light ray.
  float ratio = clamp(housing_depth / max(abs(LIGHT_POSITION.z), housing_depth + 1.0), 0.0, 0.4);
  float expansion = 1.0 / (1.0 - ratio);
  for (int i=0; i<32; i++) {
   if (i >= lamp_housing_count) { break; }
   vec4 h = lamp_housings[i];
   vec2 center = LIGHT_POSITION.xy + (h.xy - LIGHT_POSITION.xy) * expansion;
   vec2 radii = h.zw * expansion;
   vec2 delta = FRAGCOORD.xy - center;
   if (abs(delta.x) < radii.x + 3.0 && abs(delta.y) < radii.y + 3.0) {
    float distance_to_housing = (length(delta / radii) - 1.0) * min(radii.x,radii.y);
    float cover = 1.0 - smoothstep(-1.0, 2.0, distance_to_housing);
    visibility *= 1.0 - 0.88 * cover;
   }
  }
 }
 float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
 LIGHT = vec4(COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse * visibility, LIGHT_COLOR.a);
}
