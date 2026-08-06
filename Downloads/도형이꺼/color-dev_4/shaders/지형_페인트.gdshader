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

// 흰색 짝 텍스처. 채우기면 white_fill, 윗면 테두리면 white_center …
uniform sampler2D alt_tex : filter_nearest, repeat_enable;

const int MAX_SEEDS = 24;
uniform int seed_count = 0;
uniform vec2 seeds[MAX_SEEDS];        // 노드 로컬 좌표(px)
uniform float seed_r[MAX_SEEDS];      // 반지름(px)
uniform float seed_a[MAX_SEEDS];      // 세기 0~1 (부분 색칠이 흐려질 때 줄어든다)
uniform int seed_c[MAX_SEEDS];        // 0=검정 1=흰색 2=회색

// 얼룩 가장자리 흐림(px). 픽셀아트라 크게 주면 뭉개진다.
uniform float edge_soft = 2.0;
// 얼룩 경계를 찌글찌글하게 만드는 노이즈. 0 이면 정확한 원.
uniform float noise_amount = 5.0;
uniform float noise_scale = 0.07;
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
	vec4 base = texture(TEXTURE, UV);      // 검정 아트
	vec4 alt = texture(alt_tex, UV);       // 흰색 아트
	vec3 gray = mix(base.rgb, alt.rgb, 0.5);

	vec3 col = base.rgb;                   // 무색 = 검정 아트 그대로
	float wet_edge = 0.0;

	// 경계를 흔드는 노이즈는 픽셀마다 한 번만 구해서 모든 시드에 공용으로 쓴다.
	float n = (vnoise(local_pos * noise_scale) - 0.5) * 2.0 * noise_amount;

	// 나중에 찍힌 얼룩이 위에 온다 = 배열 순서대로 겹쳐 칠한다.
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		float d = distance(local_pos, seeds[i]) + n;
		float r = seed_r[i];
		float a = 1.0 - smoothstep(r - edge_soft, r + edge_soft, d);
		a *= seed_a[i];
		if (a <= 0.001) { continue; }

		vec3 target = base.rgb;
		if (seed_c[i] == 1) { target = alt.rgb; }
		else if (seed_c[i] == 2) { target = gray; }
		col = mix(col, target, a);

		// 얼룩 테두리 근처만 살짝 반짝이게 (갓 칠한 물감 느낌)
		wet_edge = max(wet_edge, a * (1.0 - a) * 4.0);
	}

	col += vec3(wet_edge * wet * 0.25);
	COLOR = vec4(col, base.a * COLOR.a);
}
