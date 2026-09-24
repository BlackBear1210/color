shader_type canvas_item;
// Prototype snapshot of sewer paint shader; keep paint uniforms synchronized.
uniform vec4 surface_bounds = vec4(0.0, 0.0, 340.0, 48.0);
uniform bool ground_platform = false;
// Visual depth around the unchanged collision/foot line, in local pixels.
uniform float ledge_top_half_depth : hint_range(1.0, 6.0) = 4.0;























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
varying float ledge_modulate_alpha;

varying vec2 sewer_world;
uniform vec2 sewer_light = vec2(-100000.0);
uniform float sewer_radius = 190.0;
uniform float sewer_strength = 0.10;
uniform bool sewer_trim = false;
uniform int sewer_edge_count = 0;
uniform vec4 sewer_edges[32];
uniform float sewer_visible[32];
void vertex() {
 // Fragment COLOR already includes the texture alpha at the original mesh UV.
 // Preserve only vertex/modulate alpha before sampling our custom ledge UV.
 ledge_modulate_alpha = COLOR.a;
 // Expand only the rendered upper strip; SS2D collision points stay intact.
 float upper_weight = 1.0 - smoothstep(0.0, 12.0, VERTEX.y - surface_bounds.y);
 VERTEX.y -= ledge_top_half_depth * upper_weight;
 sewer_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local_pos = VERTEX;
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

// Preserve the end stones; repeat the middle at constant pixel density.
vec2 ledge_uv(vec2 p) {
 float width = surface_bounds.z-surface_bounds.x;
 float x = clamp(p.x-surface_bounds.x, 0.0, width);
 // Keep stone density and end caps independent of platform length.
 float scale = 60.0/255.0;
 float cap = min(240.0*scale, width*0.3);
 float source_x;
 if (x < cap) { source_x = 18.0 + x/cap*240.0; }
 else if (x > width-cap) { source_x = 1514.0 + (x-width+cap)/cap*240.0; }
 else { source_x = 258.0 + mod((x-cap)/scale, 1256.0); }
 // Source top plane spans rows 290..350. Row 320 lies on the foot line.
 float y = p.y - surface_bounds.y;
 float half_depth = max(ledge_top_half_depth, 1.0);
 float source_y;
 if (y <= half_depth) {
  source_y = 320.0 + y * 30.0 / half_depth;
 } else {
  // Rejoin the original sampling below the lip so the underside stays put.
  float front_y = 350.0 + (y - half_depth) / scale;
  float original_y = 330.0 + y / scale;
  source_y = mix(front_y, original_y, smoothstep(half_depth, 24.0, y));
 }
 return vec2(source_x/1774.0, source_y/887.0);
}

void fragment() {
	vec4 base = texture(TEXTURE, ledge_uv(local_pos));      
	
	// 2026-09-21 fix: ink_black/ink_white below are luminance maps tuned for the DARK brick art.
	// When the node's own art is the white one (base_is_white), feeding it in made
	// black paint come out as light bricks and white paint as flat white
	// (stage 2-5: a white-prefab ghost ledge painted black looked white but killed white players).
	// Always derive the stone luminance from the dark art: own texture, or the alt (black) pair.
	vec4 alt = alt_invert
		? vec4(vec3(1.0 - base.r), base.a)
		: texture(alt_tex, ledge_uv(local_pos));
	vec4 dark = base_is_white ? alt : base;
	
	float stone = dot(dark.rgb, vec3(0.2126,0.7152,0.0722));
 vec3 ink_black = vec3(stone * 0.72);
	vec3 ink_white = vec3(mix(0.30,0.94,smoothstep(0.01,0.27,stone)));
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
		// The decorative rear half inherits paint from the collision surface.
		vec2 paint_pos = vec2(local_pos.x, max(local_pos.y, surface_bounds.y));
		vec2 dv = paint_pos - seeds[i];
		
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

	float alpha = smoothstep(0.45,0.55,base.a) * ledge_modulate_alpha;

	
	
	
	
	
	
	
	
	
	if (ghost_amount > 0.001) {
		float g = ghost_amount * (1.0 - painted);

		
		
		
		
		
		
		
		
		
		
		
		
		
		
		vec2 uv_per_lp = fwidth(UV) / max(fwidth(local_pos), vec2(0.0001));
		float grid = max(ghost_mosaic, 1.0);
		vec2 lp_snapped = (floor(local_pos / grid) + 0.5) * grid;
		vec2 uv_base = UV + (lp_snapped - local_pos) * uv_per_lp;

		
		float step_x = uv_per_lp.x * ghost_smear * 0.5;
        vec4 blurred = base_is_white
            ? (alt_invert ? vec4(vec3(1.0 - texture(TEXTURE, ledge_uv(lp_snapped)).r), 1.0) : texture(alt_tex, ledge_uv(lp_snapped)))
            : texture(TEXTURE, ledge_uv(lp_snapped));
        float ghost_stone = dot(blurred.rgb, vec3(0.2126,0.7152,0.0722));
        blurred.rgb = base_is_white ? vec3(mix(0.30,0.94,smoothstep(0.01,0.27,ghost_stone))) : vec3(ghost_stone*0.72);

		vec3 ghost_rgb = mix(blurred.rgb, ghost_tint.rgb, ghost_tint_amount);
		col = mix(col, ghost_rgb, g);
		alpha *= mix(1.0, ghost_alpha, g);
	}
	float rim = 0.0;
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
 col += vec3(sewer_strength * rim) * (1.0-col);
 // Surface shading follows paint, never introduces a white outline.
 vec2 d = local_pos - surface_bounds.xy;
 float top_face = 1.0 - smoothstep(3.0, 6.0, d.y);
 float right_face = 1.0 - smoothstep(2.0, 6.0, surface_bounds.z-local_pos.x);
 float underside = 1.0 - smoothstep(1.0, 9.0, surface_bounds.w-local_pos.y);
 if (ground_platform) { underside = 0.0; }
 float luminance = dot(col, vec3(0.2126, 0.7152, 0.0722));
 col = vec3(luminance);
 COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), alpha);
}
