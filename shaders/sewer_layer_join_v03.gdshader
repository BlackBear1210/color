shader_type canvas_item;
render_mode unshaded;

uniform bool opaque_wall = false;
uniform sampler2D relief_normal : filter_linear, repeat_enable;
uniform float normal_strength = 0.0;
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
 // Fixed directional diffuse relief, evaluated once by the background cache.
 if (normal_strength > 0.0) {
  vec3 n = normalize(texture(relief_normal, p).rgb * 2.0 - 1.0);
  vec3 lamp = normalize(vec3(-0.45, 0.55, 1.0));
  float relief = clamp(dot(n, lamp) - lamp.z, -0.16, 0.16);
  float seam_fade = smoothstep(0.0, edge_width, min(edge.x, edge.y));
  value *= 1.0 + relief * normal_strength * seam_fade;
 }
 COLOR = vec4(vec3(value),(opaque_wall ? 1.0 : alpha)*silhouette) * vertex_tint;
}
