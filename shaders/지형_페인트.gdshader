shader_type canvas_item;
// ============================================================================
// [2026-08-01 신규] SmartShape2D 지형용 페인트 셰이더
// ----------------------------------------------------------------------------
// ▣ 하는 일
//   지형에 "물감 얼룩"을 찍는다. 얼룩은 노드 로컬 좌표(px) 기준의 원이고,
//   원 안쪽은 검정 아트 ↔ 흰색 아트를 섞어서 그린다.
//
// ▣ 왜 텍스처를 두 장 받나
//   아티스트가 black_* / white_* 를 각각 그려뒀다. 밝기만 조절해서 흉내내면
//   흰색 지형의 무늬(잔디·균열)가 검정 것과 달라 어색해진다. 그래서 같은 UV로
//   두 장을 샘플해서 섞는다. TEXTURE = SS2D 가 물려준 검정 아트, alt_tex = 흰색 짝.
//
// ▣ 좌표계
//   SS2D 는 채우기 메시와 테두리 메시를 **노드 로컬 좌표**로 만든다.
//   그래서 vertex() 에서 VERTEX 를 그대로 넘기면 그게 곧 로컬 px 좌표가 된다.
//   → 시드도 같은 로컬 px 로 넣으면 채우기와 테두리에 똑같이 얼룩이 얹힌다.
//
// ▣ 실루엣 고정
//   알파는 항상 TEXTURE 의 것을 쓴다. 흰색 아트의 들쭉날쭉한 모양이 검정과
//   조금씩 달라서, 알파까지 섞으면 색칠할 때 지형 윤곽이 꿈틀거린다.
// ============================================================================

// 짝 텍스처. 검정 아트가 base 면 흰색 짝이, 흰색 아트가 base 면 검정 짝이 들어온다.
uniform sampler2D alt_tex : filter_nearest, repeat_enable;

// ★[2026-08-29] 흑백 대칭 유니폼 두 개 ─────────────────────────────────────
// ▣ base_is_white
//   흰색 Template(흰 아트를 기본으로 든 지형)이 생기면서, "TEXTURE = 검정 아트"
//   라는 가정이 깨졌다. 이 값이 켜지면 검정/흰색 매핑을 통째로 뒤집는다.
//   → 흰 지형을 검정으로 칠하면 alt(검정 아트)가, 흰색으로 칠하면 base 가 나온다.
// ▣ alt_invert
//   짝 파일이 아직 없을 때의 안전망. 짝이 없으면 지금까지는 셰이더를 **아예 안 붙였고**,
//   그래서 총에 맞아 상태는 바뀌는데 화면은 그대로였다(= 화면이 거짓말을 한다).
//   이 값이 켜지면 짝을 파일에서 읽지 않고 base 의 밝기를 뒤집어 즉석에서 만든다.
//   식(1.0 - r)은 근사가 아니라 `tools/생성_타일셋_파생.gd _반전()` 과 **같은 식**이다.
//   나중에 진짜 짝 파일이 들어오면 지형.gd 가 그쪽을 먼저 집으므로 자동으로 교체된다.
uniform bool base_is_white = false;
uniform bool alt_invert = false;

const int MAX_SEEDS = 24;
uniform int seed_count = 0;
uniform vec2 seeds[MAX_SEEDS];        // 노드 로컬 좌표(px)
uniform float seed_r[MAX_SEEDS];      // 반지름(px)
uniform float seed_a[MAX_SEEDS];      // 세기 0~1 (부분 색칠이 흐려질 때 줄어든다)
uniform int seed_c[MAX_SEEDS];        // 0=검정 1=흰색 2=회색
// ★[2026-08-29] 아래로 흘러내린 길이(px). 0 이면 그냥 원이다.
uniform float seed_d[MAX_SEEDS];
// Stable per-hit variation supplied by the stage-only paint bridge.
uniform float seed_v[MAX_SEEDS];

// ★테두리부터 물든다 — SS2D 는 테두리 메시와 채우기 메시가 **다른 재질**이라
//   같은 얼룩을 테두리 쪽에서만 크게 그리면 "가장자리가 먼저 잠기고 안쪽이 따라오는" 순서가 된다.
//   지형.gd 가 테두리 재질에만 1 보다 큰 값을 넣는다. 채우기는 1.0.
uniform float r_scale = 1.0;
// 흘러내린 줄기의 굵기(얼룩 반지름 대비). 가닥마다 이 값의 55~100% 로 갈라진다.
uniform float drip_width = 0.26;

// 얼룩 가장자리 흐림(px). 픽셀아트라 크게 주면 뭉개진다.
uniform float edge_soft = 2.0;
// 얼룩 경계를 찌글찌글하게 만드는 노이즈. 0 이면 정확한 원.
uniform float noise_amount = 5.0;
uniform float noise_scale = 0.07;
// ★[2026-08-29] 얼룩을 통째로 일그러뜨리는 큰 물결. 위 noise 는 px 단위라
//   얼룩이 커지면 상대적으로 안 보여서 **큰 얼룩일수록 완벽한 원**이 된다.
//   이 값은 반지름에 비례하므로 크기와 상관없이 덩어리 모양이 제각각이 된다.
uniform float blob_wobble = 0.14;
// Disabled by default so every existing stage keeps the original rendering.
// The stage-only mode uses smooth angular lobes, area-preserving stretch, and
// one to three deterministic drips instead of a circular stamp.
uniform bool organic_mode = false;
uniform float organic_shape = 0.11;
uniform float organic_aspect = 0.14;
// 방금 맞은 직후의 젖은 광택(0~1). 코어가 시간에 따라 낮춰준다.
uniform float wet = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// 값싼 해시 노이즈 — 얼룩 테두리를 유기적으로 흔들기만 하면 되므로 품질보다 속도.
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
	vec4 base = texture(TEXTURE, UV);      // 이 지형이 기본으로 든 아트
	// 짝이 없으면 밝기를 뒤집어 즉석에서 만든다 (생성기의 _반전() 과 같은 식).
	vec4 alt = alt_invert
		? vec4(vec3(1.0 - base.r), base.a)
		: texture(alt_tex, UV);
	// 어느 쪽이 검정 아트인지는 base_is_white 가 정한다.
	vec3 ink_black = base_is_white ? alt.rgb : base.rgb;
	vec3 ink_white = base_is_white ? base.rgb : alt.rgb;
	vec3 gray = mix(ink_black, ink_white, 0.5);

	vec3 col = base.rgb;                   // 무색 = 기본 아트 그대로
	float wet_edge = 0.0;

	// 경계를 흔드는 노이즈는 픽셀마다 한 번만 구해서 모든 시드에 공용으로 쓴다.
	float n = (vnoise(local_pos * noise_scale) - 0.5) * 2.0 * noise_amount;
	// 큰 물결(-1~1). 아래에서 반지름에 곱해 얼룩 자체를 일그러뜨린다.
	float nlow = (vnoise(local_pos * noise_scale * 0.22 + vec2(17.1, 3.9)) - 0.5) * 2.0;

	// 나중에 찍힌 얼룩이 위에 온다 = 배열 순서대로 겹쳐 칠한다.
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		vec2 dv = local_pos - seeds[i];
		// 반지름 자체를 자리마다 다르게 흔든다 = 덩어리 모양이 제각각이 된다.
		float base_r = seed_r[i] * r_scale;
		float r = base_r * (1.0 + nlow * blob_wobble);
		float d = length(dv) + n;
		float organic_d = 0.0;

		if (organic_mode) {
			// Three low-frequency harmonics make rounded corners and unequal lobes.
			// Reciprocal axis scaling keeps the ellipse area near the requested area.
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

			// Each hit receives one to three different gravity trails. Their position,
			// length, thickness, bend, taper, and optional detached tip are stable per hit.
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
					// Start near the lower silhouette instead of the seed center; otherwise
					// most of a short trail remains hidden inside the main blot.
					float attach_y = sqrt(max(base_r * base_r - offset * offset, 0.0))
						* mix(0.78, 0.92, h3);
					vec2 p = dv - vec2(offset, attach_y);
					if (p.y <= 0.0) { continue; }
					// The first trail is the readable main stream. Extra trails are shorter
					// side runs, preventing every blot from looking like the same comb.
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

					// Some trails shed a small moving bead below the rounded main tip.
					if (j > 0 && h5 > 0.74) {
						vec2 bead = vec2(p.x - (h4 - 0.5) * base_r * 0.12,
							(p.y - len - w * 2.15) * 0.72);
						float bead_d = length(bead) - max(w * 0.70, 2.5);
						organic_d = min(organic_d, bead_d);
					}
				}
			}
		}

		// ── 흘러내림 ──────────────────────────────────────────────────────
		// 얼룩 아래로 늘어지는 줄기. 가로 거리를 나눠서 재면(= 좁게 보면)
		// 세로로만 긴 영역이 되고, 그 길이를 x 칸마다 다르게 흔들어
		// 물감이 여러 가닥으로 흘러내린 모양이 된다.
		// 얼룩 하나에서 흘러내리는 물줄기는 **한 가닥, 많아야 두 가닥**이다.
		//
		// ⚠[2026-08-29] 예전에는 x 를 따라 길이만 흔들었다. 그러면 얼룩 폭 전체에서
		//   **일정한 간격으로 똑같은 줄기가 줄줄이** 생겨 톱니처럼 보인다(제보 스크린샷).
		//   실제로 흘러내리는 물감은 몇 군데에서만, 서로 다른 길이로 흐른다.
		//   → 가닥마다 시작 x · 길이 · 굵기를 씨앗 번호로 뽑는다. 두 번째 가닥은 절반 확률.
		float run = seed_d[i] * r_scale;
		if (!organic_mode && run > 0.5) {
			for (int j = 0; j < 2; j++) {
				vec2 k = vec2(float(i) * 7.31 + float(j) * 13.77, 3.17);
				float h1 = hash21(k);
				float h2 = hash21(k + vec2(5.21, 1.33));
				float h3 = hash21(k + vec2(1.97, 7.71));
				if (j == 1 && h3 < 0.5) { continue; }     // 두 가닥일 때만 둘째를 그린다
				vec2 p = dv - vec2((h1 - 0.5) * 1.1 * r, 0.0);   // 얼룩 안 어딘가에서 시작
				if (p.y <= 0.0) { continue; }
				float len = run * mix(0.35, 1.0, h2);            // 가닥마다 길이가 다르다
				float w = max(r * drip_width * mix(0.55, 1.0, h1), 2.0);
				// 흐르면서 살짝 휜다 — 자로 그은 듯 곧으면 물감처럼 안 보인다
				p.x -= (vnoise(vec2(p.y * 0.035, float(i) * 3.0 + float(j))) - 0.5) * w;
				float t = clamp(p.y / max(len, 0.001), 0.0, 1.0);
				float ww = max(w * (1.0 - 0.45 * t), 1.0);       // 끝으로 갈수록 조금 가늘게
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

		// 얼룩 테두리 근처만 살짝 반짝이게 (갓 칠한 물감 느낌)
		wet_edge = max(wet_edge, a * (1.0 - a) * 4.0);
	}

	col += vec3(wet_edge * wet * 0.25);
	COLOR = vec4(col, base.a * COLOR.a);
}
