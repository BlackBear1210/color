shader_type canvas_item;
// Prototype snapshot of sewer paint shader; keep paint uniforms synchronized.
uniform vec4 surface_bounds = vec4(0.0, 0.0, 340.0, 48.0);
uniform bool ground_platform = false;
// 1: body with no geometry queries; 2: preclipped single-edge trim.
uniform int cached_draw_mode = 1;
uniform sampler2D ground_cap_tex : filter_linear, repeat_disable;
uniform int ground_edge_count = 0;
// Keep capacity synchronized with the terrain script for long shared seams.
uniform vec4 ground_edges[128];
uniform float ground_top_half_depth : hint_range(1.0, 6.0) = 4.0;
uniform bool ground_top_enabled = true;
uniform bool ground_side_enabled = true;

// Approved end-stone finish, parameterized by the actual exposed side edge.
vec4 ground_side_stone(vec4 frame) {
 float edge = frame.x;
 float y = frame.y;
 float height = frame.z;
 if (y < 22.0 || y >= height || edge < 0.0 || height <= 32.0) { return vec4(0.0); }
 float rows = max(1.0,floor((height-24.0)/21.0+0.5));
 float row_height = (height-24.0)/rows;
 float row = floor(max(y-24.0,0.0)/row_height);
 float row_y = mod(max(y-24.0,0.0),row_height);
 float width = mix(12.0,18.0,mod(row,2.0));
 float weight = (1.0-smoothstep(width-2.0,width,edge))*smoothstep(22.0,30.0,y);
 if (weight <= 0.0) { return vec4(0.0); }
 vec2 uv = vec2((266.0+clamp(edge/width,0.0,1.0)*198.0)/1774.0,
                (351.0+row_y/row_height*82.0)/887.0);
 float stone = dot(texture(ground_cap_tex,uv).rgb,vec3(0.2126,0.7152,0.0722));
 float mortar = 1.0-smoothstep(0.4,1.2,min(row_y,row_height-row_y));
 float side = 1.0-smoothstep(3.0,5.0,edge);
 float lighting = mix(1.0,frame.w < 0.0 ? 1.06 : 0.76,side);
 float black = stone*0.78*lighting*(1.0-0.40*mortar);
 float white = mix(0.30,0.94,smoothstep(0.01,0.27,stone))*lighting*(1.0-0.28*mortar);
 return vec4(black,white,weight,mortar*weight);
}
uniform int ground_cover_count = 0;
uniform vec4 ground_cover_edges[256];

// Consistently oriented neighboring polygons use nonzero winding for a union.
bool ground_covered(vec2 p) {
 int winding = 0;
 for (int i = 0; i < ground_cover_count; i++) {
  vec2 a = ground_cover_edges[i].xy;
  vec2 b = ground_cover_edges[i].zw;
  float side = (b.x-a.x)*(p.y-a.y)-(p.x-a.x)*(b.y-a.y);
  if (a.y <= p.y && b.y > p.y && side > 0.0) { winding += 1; }
  if (a.y > p.y && b.y <= p.y && side < 0.0) { winding -= 1; }
 }
 return winding != 0;
}

// Return inward distance, distance from upper end, height, outward X.
vec4 ground_side_frame(vec2 p) {
 vec4 best = vec4(100000.0,0.0,0.0,0.0);
 for (int i = 0; i < ground_edge_count; i++) {
  vec2 a = ground_edges[i].xy;
  vec2 b = ground_edges[i].zw;
  vec2 v = b-a;
  float len = length(v);
  if (len < 0.001) { continue; }
  vec2 t = v/len;
  // Finish walls and steep side faces, not walkable slopes or undersides.
  if (abs(t.y) < 0.95) { continue; }
  vec2 outward = vec2(t.y,-t.x);
  float along = dot(p-a,t);
  float inward = dot(p-a,-outward);
  if (along < 0.0 || along > len || inward < 0.0 || inward > 18.0 || inward >= best.x) { continue; }
  vec2 surface = a+t*along;
  // Both the outer contact and the painted strip must be free of neighbors.
  if (ground_covered(surface+outward*0.5) || ground_covered(p)) { continue; }
  float run_along = along;
  float run_length = len;
  // Editing points on the same wall must not restart the masonry rows.
  for (int j = 1; j < ground_edge_count; j++) {
   int index = (i-j+ground_edge_count) % ground_edge_count;
   vec2 u = ground_edges[index].zw-ground_edges[index].xy;
   float span = length(u);
   if (span < 0.001) { continue; }
   if (dot(u/span,t) < 0.9999) { break; }
   run_along += span;
   run_length += span;
  }
  for (int j = 1; j < ground_edge_count; j++) {
   int index = (i+j) % ground_edge_count;
   vec2 u = ground_edges[index].zw-ground_edges[index].xy;
   float span = length(u);
   if (span < 0.001) { continue; }
   if (dot(u/span,t) < 0.9999) { break; }
   run_length += span;
  }
  best = vec4(inward,t.y > 0.0 ? run_along : run_length-run_along,run_length,outward.x);
 }
 return best;
}

// Bevel only convex top endpoints. Concave stair joints remain untouched.
float ground_top_corner_mask(vec2 p) {
 if (!ground_top_enabled || ground_covered(p)) { return 1.0; }
 float mask = 1.0;
 float depth = max(ground_top_half_depth, 1.0);
 for (int i = 0; i < ground_edge_count; i++) {
  vec2 a = ground_edges[i].xy;
  vec2 v = ground_edges[i].zw - a;
  float len = length(v);
  if (len < 0.001) { continue; }
  vec2 t = v / len;
  if (t.x < 0.65) { continue; }
  float along = dot(p-a, t);
  float inward = dot(p-a, vec2(-t.y, t.x));
  if (inward < -depth-0.5 || inward > depth+0.5) { continue; }
  vec2 surface = p + vec2(t.y,-t.x)*inward;
  if (ground_covered(surface+vec2(t.y,-t.x)*0.5)) { continue; }
  float inset = min(max(depth-inward, 0.0)*0.75, len*0.2);
  if (along < -depth || along > len+depth) { continue; }
  if (along < inset+0.5) {
   // Closed SS2D polygons may include a duplicate endpoint (zero-length edge).
   for (int j = 1; j < ground_edge_count; j++) {
    int prev = (i-j+ground_edge_count) % ground_edge_count;
    vec2 u = ground_edges[prev].zw-ground_edges[prev].xy;
    if (length(u) < 0.001) { continue; }
    u = normalize(u);
    if (u.x*t.y-u.y*t.x > 0.01) {
     mask = min(mask, smoothstep(-0.5,0.5,along-inset));
    }
    break;
   }
  }
  if (len-along < inset+0.5) {
   for (int j = 1; j < ground_edge_count; j++) {
    int next = (i+j) % ground_edge_count;
    vec2 u = ground_edges[next].zw-ground_edges[next].xy;
    if (length(u) < 0.001) { continue; }
    u = normalize(u);
    if (t.x*u.y-t.y*u.x > 0.01) {
     mask = min(mask, smoothstep(-0.5,0.5,len-along-inset));
    }
    break;
   }
  }
 }
 return mask;
}

// Distances to exposed top/right faces follow the polygon, including stairs.
vec4 ground_face_distances(vec2 p) {
 vec4 nearest = vec4(100000.0,100000.0,0.0,1.0);
 for (int i = 0; i < ground_edge_count; i++) {
  vec2 a = ground_edges[i].xy;
  vec2 v = ground_edges[i].zw-a;
  float len = length(v);
  if (len < 0.001) { continue; }
  vec2 tangent = v/len;
  vec2 outward = vec2(tangent.y,-tangent.x);
  float along = dot(p-a,tangent);
  float inward = dot(p-a,-outward);
  // A cap stops at its own endpoint; it must not project into a stair wall.
  if (along < 0.0 || along > len) { continue; }
  if (outward.y < -0.65 && inward >= -ground_top_half_depth-0.01 && inward <= 24.0) {
   vec2 surface = p + outward*inward;
   if (ground_top_enabled && abs(inward) < abs(nearest.x)
       && !ground_covered(surface + outward*0.5) && !ground_covered(p)) {
    // Merge collinear edges so extra editing points do not restart the joints.
    float run_along = along;
    float run_length = len;
    for (int j = 1; j < ground_edge_count; j++) {
     int index = (i-j+ground_edge_count) % ground_edge_count;
     vec2 u = ground_edges[index].zw-ground_edges[index].xy;
     float span = length(u);
     if (span < 0.001) { continue; }
     if (dot(u/span,tangent) < 0.9999) { break; }
     run_along += span;
     run_length += span;
    }
    for (int j = 1; j < ground_edge_count; j++) {
     int index = (i+j) % ground_edge_count;
     vec2 u = ground_edges[index].zw-ground_edges[index].xy;
     float span = length(u);
     if (span < 0.001) { continue; }
     if (dot(u/span,tangent) < 0.9999) { break; }
     run_length += span;
    }
    nearest.x = inward;
    nearest.z = run_along;
    nearest.w = run_length;
   }
  }
  if (outward.x > 0.65 && inward >= 0.0 && inward <= 7.0) {
   vec2 surface = p+outward*inward;
   if (!ground_covered(surface+outward*0.5) && !ground_covered(p)) {
    nearest.y = min(nearest.y,inward);
   }
  }
 }
 return nearest;
}























uniform sampler2D alt_tex : filter_nearest, repeat_enable;












uniform bool base_is_white = false;
uniform bool alt_invert = false;

const int MAX_SEEDS = 24;
uniform int seed_count = 0;
uniform vec2 seeds[MAX_SEEDS];        
uniform float seed_r[MAX_SEEDS];      
uniform float seed_a[MAX_SEEDS];      
uniform int seed_c[MAX_SEEDS];        

uniform float seed_d[MAX_SEEDS];

uniform float seed_v[MAX_SEEDS];




uniform float r_scale = 1.0;

uniform float drip_width = 0.26;


uniform float edge_soft = 2.0;

uniform float noise_amount = 5.0;
uniform float noise_scale = 0.07;



uniform float blob_wobble = 0.14;



uniform bool organic_mode = false;
uniform float organic_shape = 0.11;
uniform float organic_aspect = 0.14;

uniform float wet = 0.0;


















uniform float ghost_amount = 0.0;

uniform float ghost_mosaic = 12.0;

uniform float ghost_smear = 7.0;


uniform float ghost_alpha = 0.55;


uniform vec4 ghost_tint : source_color = vec4(0.78, 0.82, 0.88, 1.0);
uniform float ghost_tint_amount = 0.30;

varying vec2 local_pos;
varying vec2 ground_visual_pos;

varying vec2 sewer_world;
uniform vec2 sewer_light = vec2(-100000.0);
uniform float sewer_radius = 190.0;
uniform float sewer_strength = 0.10;
uniform bool sewer_trim = false;
uniform int sewer_edge_count = 0;
uniform vec4 sewer_edges[32];
uniform float sewer_visible[32];
void vertex() {
 // Keep paint coordinates on the original SS2D mesh; expand only the image.
 local_pos = VERTEX;
 if (cached_draw_mode == 0 && ground_platform && ground_top_enabled && !ground_covered(VERTEX+vec2(0.0,-0.5))) {
  float extension = 0.0;
  for (int i = 0; i < ground_edge_count; i++) {
   vec2 a = ground_edges[i].xy;
   vec2 v = ground_edges[i].zw-a;
   float len = length(v);
   if (len < 0.001) { continue; }
   vec2 tangent = v/len;
   vec2 outward = vec2(tangent.y,-tangent.x);
   float along = dot(VERTEX-a,tangent);
   float inward = dot(VERTEX-a,-outward);
   if (outward.y < -0.65 && along >= -0.01 && along <= len+0.01 && inward >= -0.01) {
    extension = max(extension, ground_top_half_depth * (1.0-smoothstep(0.0,12.0,inward)));
   }
  }
  VERTEX.y -= extension;
 }
 ground_visual_pos = VERTEX;
 sewer_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 cached_faces = vec4(100000.0,100000.0,0.0,1.0);
	if (ground_platform && cached_draw_mode != 1 && ground_edge_count > 0) {
		cached_faces = ground_face_distances(ground_visual_pos);
	}
	vec4 side_stone = vec4(0.0);
	vec4 side_frame = vec4(100000.0,0.0,0.0,0.0);
	vec4 base = texture(TEXTURE, UV);      
	
	vec4 alt = alt_invert
		? vec4(vec3(1.0 - base.r), base.a)
		: texture(alt_tex, UV);
	
	vec3 ink_black = base_is_white ? alt.rgb : base.rgb;
	vec3 ink_white = base_is_white ? base.rgb : alt.rgb;
 if (ground_platform && cached_draw_mode != 1 && ground_edge_count > 0) {
  vec4 faces = cached_faces;
  float cap_weight = 1.0-smoothstep(18.0,24.0,faces.x);
  // The collision line samples the middle of source top rows 290..350.
  float half_depth = max(ground_top_half_depth,1.0);
  float source_y = 320.0 + faces.x * 30.0/half_depth;
  if (faces.x > half_depth) {
   float front_y = 350.0 + (faces.x-half_depth)/0.2353;
   float old_y = 330.0 + min(faces.x,24.0)/0.2353;
   source_y = mix(front_y,old_y,smoothstep(half_depth,24.0,faces.x));
  }
  // Fit whole coping stones between the actual endpoints, joint to joint.
  float stone_count = max(1.0,floor(faces.w/(198.0*0.2353)+0.5));
  float stone_phase = fract(clamp(faces.z/faces.w,0.0,1.0)*stone_count);
  vec2 cap_uv = vec2((266.0+stone_phase*198.0)/1774.0,
                     source_y/887.0);
  vec4 cap = texture(ground_cap_tex,cap_uv);
  float stone = dot(cap.rgb,vec3(0.2126,0.7152,0.0722));
  cap_weight *= smoothstep(0.45,0.55,cap.a);
  ink_black = mix(ink_black,vec3(stone*0.72),cap_weight);
  ink_white = mix(ink_white,vec3(mix(0.30,0.94,smoothstep(0.01,0.27,stone))),cap_weight);
 }
	if (ground_platform && cached_draw_mode != 1 && ground_side_enabled) {
		side_frame = ground_side_frame(ground_visual_pos);
		side_stone = ground_side_stone(side_frame);
		ink_black = mix(ink_black,vec3(side_stone.x),side_stone.z);
		ink_white = mix(ink_white,vec3(side_stone.y),side_stone.z);
	}
	if (sewer_trim) {
		ink_black *= 0.45;
	}
	vec3 gray = mix(ink_black, ink_white, 0.5);

	vec3 col = base_is_white ? ink_white : ink_black;
	float wet_edge = 0.0;
	
	
	float painted = 0.0;

	
	float n = (vnoise(local_pos * noise_scale) - 0.5) * 2.0 * noise_amount;
	
	float nlow = (vnoise(local_pos * noise_scale * 0.22 + vec2(17.1, 3.9)) - 0.5) * 2.0;

	
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		vec2 dv = local_pos - seeds[i];
		
		float base_r = seed_r[i] * r_scale;
		float r = base_r * (1.0 + nlow * blob_wobble);
		float d = length(dv) + n;
		float organic_d = 0.0;

		if (organic_mode) {
			
			
			float variant = seed_v[i];
			float phase = variant * 6.28318530718;
			float cs = cos(phase);
			float sn = sin(phase);
			vec2 q = vec2(cs * dv.x + sn * dv.y, -sn * dv.x + cs * dv.y);
			float stretch = mix(1.0 - organic_aspect, 1.0 + organic_aspect,
				hash21(vec2(variant * 91.7 + 4.3, 8.1)));
			q = vec2(q.x / max(stretch, 0.1), q.y * stretch);
			float angle = atan(q.y, q.x);
			float waves = sin(angle * 3.0 + phase * 1.7) * 0.52
				+ sin(angle * 5.0 - phase * 2.3) * 0.31
				+ sin(angle * 7.0 + phase * 3.1) * 0.17;
			float fine = (vnoise((q + vec2(variant * 173.0, variant * 67.0))
				* noise_scale) - 0.5) * 2.0 * noise_amount;
			organic_d = length(q) - base_r * (1.0 + waves * organic_shape) + fine;

			
			
			float run = seed_d[i] * r_scale;
			if (run > 0.5) {
				int drip_count = 1 + int(floor(hash21(vec2(variant * 137.1 + 2.7, 5.9)) * 3.0));
				for (int j = 0; j < 3; j++) {
					if (j >= drip_count) { continue; }
					vec2 k = vec2(variant * 211.3 + float(j) * 17.7,
						variant * 73.1 + float(j) * 9.2);
					float h1 = hash21(k + vec2(1.3, 7.1));
					float h2 = hash21(k + vec2(5.2, 1.9));
					float h3 = hash21(k + vec2(9.7, 4.6));
					float h4 = hash21(k + vec2(3.8, 12.4));
					float h5 = hash21(k + vec2(14.2, 2.5));
					float offset = (h1 - 0.5) * 1.45 * base_r;
					
					
					float attach_y = sqrt(max(base_r * base_r - offset * offset, 0.0))
						* mix(0.78, 0.92, h3);
					vec2 p = dv - vec2(offset, attach_y);
					if (p.y <= 0.0) { continue; }
					
					
					float len_factor = j == 0 ? mix(0.82, 1.12, h2) : mix(0.30, 0.78, h2);
					float width_factor = j == 0 ? mix(0.76, 1.0, h3) : mix(0.42, 0.78, h3);
					float len = run * len_factor;
					float w = max(base_r * drip_width * width_factor, 3.0);
					float cy = clamp(p.y, 0.0, max(len, 0.001));
					float t = cy / max(len, 0.001);
					float bend = (h4 - 0.5) * base_r * 0.12 * t * t
						+ sin(t * 3.14159265) * (h5 - 0.5) * w * 1.2;
					float ww = max(w * mix(1.0, 0.48, t), 2.0);
					float drip_d = length(vec2(p.x - bend, p.y - cy)) - ww;
					organic_d = min(organic_d, drip_d + fine * 0.18);

					
					if (j > 0 && h5 > 0.74) {
						vec2 bead = vec2(p.x - (h4 - 0.5) * base_r * 0.12,
							(p.y - len - w * 2.15) * 0.72);
						float bead_d = length(bead) - max(w * 0.70, 2.5);
						organic_d = min(organic_d, bead_d);
					}
				}
			}
		}

		
		
		
		
		
		
		
		
		
		
		float run = seed_d[i] * r_scale;
		if (!organic_mode && run > 0.5) {
			for (int j = 0; j < 2; j++) {
				vec2 k = vec2(float(i) * 7.31 + float(j) * 13.77, 3.17);
				float h1 = hash21(k);
				float h2 = hash21(k + vec2(5.21, 1.33));
				float h3 = hash21(k + vec2(1.97, 7.71));
				if (j == 1 && h3 < 0.5) { continue; }     
				vec2 p = dv - vec2((h1 - 0.5) * 1.1 * r, 0.0);   
				if (p.y <= 0.0) { continue; }
				float len = run * mix(0.35, 1.0, h2);            
				float w = max(r * drip_width * mix(0.55, 1.0, h1), 2.0);
				
				p.x -= (vnoise(vec2(p.y * 0.035, float(i) * 3.0 + float(j))) - 0.5) * w;
				float t = clamp(p.y / max(len, 0.001), 0.0, 1.0);
				float ww = max(w * (1.0 - 0.45 * t), 1.0);       
				float dy = max(p.y - len, 0.0);
				d = min(d, length(vec2(p.x * r / ww, dy)) + n);
			}
		}

		float a = organic_mode
			? 1.0 - smoothstep(-edge_soft, edge_soft, organic_d)
			: 1.0 - smoothstep(r - edge_soft, r + edge_soft, d);
		a *= seed_a[i];
		if (a <= 0.001) { continue; }

		vec3 target = ink_black;
		if (seed_c[i] == 1) { target = ink_white; }
		else if (seed_c[i] == 2) { target = gray; }
		col = mix(col, target, a);
		painted = max(painted, a);

		
		wet_edge = max(wet_edge, a * (1.0 - a) * 4.0);
	}

	col += vec3(wet_edge * wet * 0.25);

	float alpha = base.a * COLOR.a;

	
	
	
	
	
	
	
	
	
	if (ghost_amount > 0.001) {
		float g = ghost_amount * (1.0 - painted);

		
		
		
		
		
		
		
		
		
		
		
		
		
		
		vec2 uv_per_lp = fwidth(UV) / max(fwidth(local_pos), vec2(0.0001));
		float grid = max(ghost_mosaic, 1.0);
		vec2 lp_snapped = (floor(local_pos / grid) + 0.5) * grid;
		vec2 uv_base = UV + (lp_snapped - local_pos) * uv_per_lp;

		
		float step_x = uv_per_lp.x * ghost_smear * 0.5;
		vec4 blurred = texture(TEXTURE, uv_base)
			+ texture(TEXTURE, uv_base + vec2(step_x, 0.0))
			+ texture(TEXTURE, uv_base - vec2(step_x, 0.0))
			+ texture(TEXTURE, uv_base + vec2(step_x * 2.0, 0.0))
			+ texture(TEXTURE, uv_base - vec2(step_x * 2.0, 0.0));
		blurred *= 0.2;

		vec3 ghost_rgb = mix(blurred.rgb, ghost_tint.rgb, ghost_tint_amount);
		col = mix(col, ghost_rgb, g);
		alpha *= mix(1.0, ghost_alpha, g);
	}
	float rim = 0.0;
 if (sewer_strength > 0.0 && distance(sewer_world,sewer_light) <= sewer_radius + 2.0) {
 for (int i = 0; i < sewer_edge_count; i++) {
  vec2 a = sewer_edges[i].xy;
  vec2 b = sewer_edges[i].zw;
  vec2 v = b - a;
  float t = clamp(dot(sewer_world-a,v)/max(dot(v,v),0.001),0.0,1.0);
  vec2 q = a + v*t;
  vec2 n = normalize(vec2(v.y,-v.x));
  float facing = max(dot(n,normalize(sewer_light-q)),0.0);
  float near_light = 1.0-smoothstep(0.0,sewer_radius,distance(sewer_light,q));
  float line = 1.0-smoothstep(0.4,1.8,distance(sewer_world,q));
  rim = max(rim, line*near_light*facing*sewer_visible[i]);
 }
 }
 col += vec3(sewer_strength * rim) * (1.0-col);
 // Surface shading follows paint, never introduces a white outline.
 vec2 d = local_pos - surface_bounds.xy;
 float top_face = 1.0 - smoothstep(3.0, 6.0, d.y);
 float right_face = 1.0 - smoothstep(2.0, 6.0, surface_bounds.z-local_pos.x);
 float underside = 1.0 - smoothstep(1.0, 9.0, surface_bounds.w-local_pos.y);
 if (ground_platform) { underside = 0.0; }
 if (ground_platform && cached_draw_mode == 1) { top_face = 0.0; right_face = 0.0; }
 if (ground_platform && cached_draw_mode != 1 && ground_edge_count > 0) {
  vec4 faces = cached_faces;
  top_face = 1.0-smoothstep(2.0,4.0,faces.x);
  right_face = 1.0-smoothstep(2.0,7.0,faces.y);
 }
 float luminance = dot(col, vec3(0.2126, 0.7152, 0.0722));
 col = vec3(luminance) * (0.94 + 0.12*top_face - 0.17*right_face - 0.20*underside);
 if (ground_platform && cached_draw_mode == 0 && ground_edge_count > 0) {
  alpha *= ground_top_corner_mask(ground_visual_pos);
 }
 if (ground_platform && ground_side_enabled && side_stone.z > 0.0) {
  // Subpixel mortar recesses avoid a perfectly cut paper silhouette.
  alpha *= smoothstep(-0.25,0.65,side_frame.x-side_stone.w*0.8);
 }
 COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha);
}
