shader_type canvas_item;
// ============================================================================
// [프로토타입] 잉크 번짐 셰이더 — 월드 좌표 버전
// ----------------------------------------------------------------------------
// ink_spread.gdshader(플랫폼 1개의 로컬 UV 기준)를 TileMapLayer 전체의
// "월드 좌표" 기준으로 확장한 버전. 씨앗(seed)마다 자기 색을 가지므로
// 바닥 여러 군데가 흑/백 섞여서 칠해질 수 있다.
//
// 판정(씨앗 좌표·반지름·색)은 테스트_월드_24x24.gd 가 CPU 에서 갱신하고,
// 이 셰이더는 그 결과를 "번지는 모양"으로 그리기만 한다.
//
// [젖은 하이라이트] ink_spread.gdshader 의 wet_amount 를 그대로 가져오되,
// 여기선 별도 타이머 없이 "이 씨앗이 아직 다 안 자랐다(rad < max_r)"는 사실 자체를
// 젖음 정도로 쓴다 — 막 칠해진 자리일수록 rad 가 작으니 자연히 더 반짝인다.
// ============================================================================

const int MAX_SEEDS = 64;
uniform int   seed_count = 0;
uniform vec2  seeds[MAX_SEEDS];        // 씨앗 위치 (월드 좌표)
uniform float seed_r[MAX_SEEDS];       // 각 씨앗의 현재 번짐 반지름 (월드 px)
uniform int   seed_color[MAX_SEEDS];   // 0=검정, 1=흰색
// 반대색 짝을 찾는 방향. 0=가로 오프셋(왼쪽=검정/오른쪽=흰색 — brick·grass·rock·soil),
// 1=세로 오프셋(위=검정/아래=흰색 — wood). 시트마다 배치 규칙이 달라 씨앗별로 저장한다.
uniform int   seed_axis[MAX_SEEDS];
uniform float max_r = 55.0;            // 씨앗이 다 자랐을 때의 반지름 (테스트_월드_24x24.gd 의 목표_반지름과 동일하게 맞출 것)

// ── 번짐 모양 튜닝 (ink_spread.gdshader 와 같은 알고리즘, 월드 px 단위로 환산한 값) ──
uniform float noise_amount = 14.0;     // 경계가 일그러지는 정도 (월드 px, 0=완전 원)
uniform float noise_scale  = 0.045;    // 노이즈 세밀도 (클수록 잘게. 월드 px 좌표에 곱해짐)
uniform float edge_soft    = 3.0;      // 경계 부드러움 (월드 px)

// ── 젖은 하이라이트 튜닝 ────────────────────────────────────────────────────
uniform float wet_width: hint_range(0.0, 20.0) = 6.0;   // 젖은 띠의 두께 (월드 px)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// ── 값 노이즈 (외부 텍스처 없이 코드로 생성) ────────────────────────────────
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
float fbm(vec2 p) {
	return vnoise(p) * 0.60 + vnoise(p * 2.13) * 0.28 + vnoise(p * 4.70) * 0.12;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// ── 가장 가까운 씨앗까지의 거리 (여러 씨앗 중 가장 가까운 것이 이 픽셀을 칠함) ──
	// ★cb/cw 계산보다 먼저 구해야 한다 — 반대색 짝을 어느 축으로 찾을지가
	//   "이 픽셀 주변에서 가장 가까운 씨앗이 어느 시트에서 만들어졌는지"에 달려있다.
	float d = 1e9;
	int nearest = -1;
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		float dist = distance(world_pos, seeds[i]) - seed_r[i];
		if (dist < d) {
			d = dist;
			nearest = i;
		}
	}

	// ── zone_04 와 같은 트릭: 이 타일(base)과 그 반대색 짝(there)을 같이 샘플링 ──
	// ⚠ 시트마다 배치 규칙이 다르다 — brick·grass·rock·soil 은 가로(axis=0),
	//   wood 는 세로(axis=1). 가장 가까운 씨앗이 어느 축인지로 판단한다.
	//   ★무색(안 칠한) 상태는 여전히 "원래 그려진 타일 색 그대로"다 — 회색으로 안 바꾼다.
	int axis = (nearest >= 0) ? seed_axis[nearest] : 0;
	vec2 other_uv = (axis == 1) ? UV + vec2(0.0, 0.5) : UV + vec2(0.5, 0.0);
	other_uv = fract(other_uv);
	vec4 there = texture(TEXTURE, other_uv);
	bool here_is_black = (axis == 1) ? (UV.y < 0.5) : (UV.x < 0.5);
	vec4 cb = here_is_black ? base : there;   // 검정 버전
	vec4 cw = here_is_black ? there : base;   // 흰색 버전

	// 경계를 노이즈로 흔든다 → 원이 아니라 "번진 잉크" 모양 (zone_04 와 같은 방식)
	d += (fbm(world_pos * noise_scale) - 0.5) * noise_amount;
	float mask = (seed_count == 0) ? 0.0 : (1.0 - smoothstep(0.0, edge_soft, d));

	vec3 target = (nearest >= 0 && seed_color[nearest] == 1) ? cw.rgb : cb.rgb;

	vec3 col = mix(base.rgb, target, mask);

	// ── 젖은 하이라이트: 명중 직후(반지름이 작을 때)만, 경계 근처에서 잠깐 빛남 ──
	if (nearest >= 0) {
		float wet_amount = clamp(1.0 - seed_r[nearest] / max(max_r, 0.001), 0.0, 1.0);
		float band = (1.0 - smoothstep(0.0, wet_width, abs(d))) * mask * wet_amount;
		vec3 sheen = (seed_color[nearest] == 1) ? vec3(0.55, 0.56, 0.60) : vec3(0.42, 0.43, 0.50);
		col = mix(col, col * 0.55 + sheen * 0.55, clamp(band, 0.0, 1.0));
	}

	COLOR = vec4(col, base.a);
}
