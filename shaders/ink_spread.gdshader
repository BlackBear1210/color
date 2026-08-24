shader_type canvas_item;
// ============================================================================
// [2026-07-24 도형] 잉크 번짐 셰이더 (Ink Spread Shader)  —  페인트 시스템 v3
// [2026-07-25 개정] ★물감 얼룩 프로파일 통합 + 실루엣 이탈 버그 수정
// ----------------------------------------------------------------------------
// ▣ 무엇을 하는가
//   "플랫폼 하나"를 통째로 그리는 셰이더다. 디자이너가 준 흑/백 한 쌍 텍스처를
//   받아서, 아직 안 칠해진 곳은 중간 명도 회색, 칠해진 곳은 목표색으로 보여준다.
//   칠해지는 경계는 노이즈로 일그러져 "잉크가 스며드는" 모양이 된다.
//
// ▣ 왜 이렇게 만들었나 (2026-07-24 회의 결정 반영)
//   "플랫폼/장애물마다 최대 색칠 횟수가 있고, 8칸 플랫폼은 4번 칠하면 전체가 바뀐다"
//   → 색칠 단위 = 타일 1칸이 아니라 **플랫폼 1개**. 칠해진 지점에서 색이 퍼져나간다.
//   게임 규칙(몇 번 맞았나 / 지금 무슨 색인가)은 셰이더가 아니라 paint_platform.gd 가
//   CPU 쪽에서 소유한다 (퍼즐 판정은 결정론적이어야 하고 GPU 값은 되읽기가 비싸다).
//
// ▣ [2026-07-25] 프로파일 2종 — zone_04 / zone_05 비교의 실체
//   profile 0 = 스며듦 : 부드러운 경계. 종이에 잉크가 번지는 느낌
//   profile 1 = 물감 얼룩 : 딱딱하고 울퉁불퉁한 경계. 물감을 던져 붙은 느낌
//   ⚠ 예전엔 profile 1 을 "얼룩 스프라이트를 겹쳐 찍는" 완전히 다른 방식으로 만들었는데,
//     ① 스프라이트가 플랫폼 실루엣 밖으로 삐져나가고(= "벽돌 옆 마스킹 테이프까지 칠해짐")
//     ② 랜덤 배치라 가운데가 덜 칠해진 채로 남는
//     두 가지 문제가 있었다. 지금은 **같은 마스크 안에서 프로파일만 바꾼다** →
//     실루엣을 절대 벗어날 수 없고, 진행률 100% 에서 반드시 전부 덮인다.
// ============================================================================

// ── 아트: 디자이너 시트 1장 + 흑/백 셀의 UV 사각형 ─────────────────────────
uniform sampler2D sheet : filter_linear, source_color;
uniform vec4 uv_black = vec4(0.0, 0.0, 0.5, 1.0);   // xy=시작 UV, zw=크기 UV
uniform vec4 uv_white = vec4(0.5, 0.0, 0.5, 1.0);

// ── 9슬라이스: 384px 덩어리 아트를 임의 크기 플랫폼에 안 찌그러지게 붙이기 ──
uniform vec2  node_size  = vec2(256.0, 32.0);  // 이 플랫폼의 실제 월드 크기(px)
uniform vec2  cell_px    = vec2(384.0, 384.0); // 원본 셀 한 칸 크기(px)
uniform float border_px  = 56.0;               // 유기적 테두리 두께(원본 px)
uniform bool  tile_middle = true;              // 가운데를 반복할지 늘릴지

// ── 색칠 상태 (CPU 가 매번 갱신) ────────────────────────────────────────────
const int MAX_SEEDS = 16;
uniform int   paint_color = 0;                 // 0=검정, 1=흰색 (목표색)
uniform vec2  seeds[MAX_SEEDS];                // 색칠 시작점 (로컬 UV)
uniform float seed_r[MAX_SEEDS];               // 각 시작점의 현재 번짐 반지름
uniform float seed_a[MAX_SEEDS];               // 색별 자동 회수 감쇠 0~1
uniform int   seed_c[MAX_SEEDS];               // 각 시작점의 색 0=검정, 1=흰색
uniform int   seed_count = 0;
uniform float locked = 0.0;                    // 1 = 회색(영구) 상태

// ── 번짐 모양 튜닝 ─────────────────────────────────────────────────────────
uniform int   profile = 0;                     // 0=스며듦(zone4) 1=물감얼룩(zone5)
uniform float noise_amount = 0.13;             // 경계가 일그러지는 정도 (0=완전 원)
uniform float noise_scale  = 3.2;              // 노이즈 세밀도 (클수록 잘게)
uniform float blob_amount  = 0.0;              // 얼룩 프로파일에서 경계를 덩어리지게
uniform float edge_soft    = 0.035;            // 경계 부드러움
uniform float wet_amount   = 0.0;              // 젖은 하이라이트 세기 (명중 직후 1 → 0)
uniform float wet_width    = 0.14;             // 젖은 띠 두께
uniform float aspect       = 8.0;              // node_size.x / node_size.y

// ── 9슬라이스 UV 리맵 ──────────────────────────────────────────────────────
float slice_axis(float x, float size, float tex, float border, bool tiled) {
	float bn = min(border / max(size, 1.0), 0.45);   // 노드 기준 테두리 비율
	float bt = min(border / max(tex, 1.0), 0.45);    // 텍스처 기준 테두리 비율
	if (x < bn) {
		return x / bn * bt;                          // 시작 테두리 (원본 비율 유지)
	}
	if (x > 1.0 - bn) {
		return 1.0 - (1.0 - x) / bn * bt;            // 끝 테두리
	}
	float t = (x - bn) / max(1.0 - 2.0 * bn, 0.0001);
	if (tiled) {
		// 가운데를 원본 픽셀 비율에 가깝게 반복 (벽돌/나뭇결이 늘어나지 않게)
		float rep = (size * (1.0 - 2.0 * bn)) / max(tex * (1.0 - 2.0 * bt), 1.0);
		rep = max(1.0, floor(rep + 0.5));
		t = fract(t * rep);
	}
	return bt + t * (1.0 - 2.0 * bt);
}

// ── 값 노이즈 (외부 텍스처 없이 코드로 생성 — 에셋 의존 0) ──────────────────
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);                     // smoothstep 보간
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {                                  // 3옥타브 = 잉크 특유의 들쭉날쭉함
	return vnoise(p) * 0.60 + vnoise(p * 2.13) * 0.28 + vnoise(p * 4.70) * 0.12;
}

void fragment() {
	// ── 1) 이 픽셀이 원본 셀의 어디를 샘플할지 (9슬라이스) ──────────────
	vec2 local = (UV - uv_black.xy) / max(uv_black.zw, vec2(0.0001));
	local = clamp(local, vec2(0.0), vec2(1.0));

	vec2 cuv = vec2(
		slice_axis(local.x, node_size.x, cell_px.x, border_px, tile_middle),
		slice_axis(local.y, node_size.y, cell_px.y, border_px, tile_middle)
	);

	vec4 cb = texture(sheet, uv_black.xy + cuv * uv_black.zw);   // 흑 버전
	vec4 cw = texture(sheet, uv_white.xy + cuv * uv_white.zw);   // 백 버전

	// ── 2) 무색(아직 안 칠함) = 중간 명도 회색 ─────────────────────────
	// ⚠[2026-07-24] mix(흑,백,0.5) 로 만들었더니 **완전히 평평한 회색**이 나왔다.
	//   흑 벽돌(어두운 벽돌+밝은 줄눈)과 백 벽돌(밝은 벽돌+어두운 줄눈)이 정확히
	//   반대라 평균 내면 무늬가 상쇄된다(스크린샷으로 확인).
	//   → 백 텍스처의 명암을 살린 채 명도만 절반으로. (가이드 §5 "회색 45~55%")
	vec4 neutral = vec4(cw.rgb * 0.55, cw.a);
	// ── 3) 잉크 번짐 마스크 ────────────────────────────────────────────
	// 각 시드의 색을 순서대로 합성해야 검정·흰색 부분 칠이 동시에 남을 수 있다.
	vec2 ap = vec2(local.x * aspect, local.y);
	vec4 col = neutral;
	float wet_edge = 0.0;
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		vec2 s = vec2(seeds[i].x * aspect, seeds[i].y);
		float d = distance(ap, s) - seed_r[i];
		d += (fbm(ap * noise_scale) - 0.5) * noise_amount;
		if (profile == 1) {
			d += (vnoise(ap * (noise_scale * 0.42) + vec2(13.7, 4.1)) - 0.5) * blob_amount;
		}
		float mask = (1.0 - smoothstep(0.0, edge_soft, d)) * seed_a[i];
		vec4 target = (seed_c[i] == 1) ? cw : cb;
		col = mix(col, target, mask);
		wet_edge = max(wet_edge, (1.0 - smoothstep(0.0, wet_width, abs(d))) * mask);
	}

	// ── 4) 젖은 느낌의 하이라이트 (번지는 경계에만, 명중 직후 잠깐) ─────
	vec3 sheen = (paint_color == 1) ? vec3(0.55, 0.56, 0.60) : vec3(0.42, 0.43, 0.50);
	col.rgb = mix(col.rgb, col.rgb * 0.55 + sheen * 0.55, clamp(wet_edge * wet_amount, 0.0, 1.0));

	// ── 5) 회색(영구) 상태: 대비를 죽여 "죽은 지형"으로 보이게 ─────────
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// ⚠[2026-07-25] 실측 결과 회색 지형이 24% 로 렌더돼 배경(15%)과 거의 안 구분됐다.
	// 레벨디자인 가이드 §5 는 회색(죽은 지형)을 **45~55%** 로 못박고 있다 → 그 대역으로 올린다.
	col.rgb = mix(col.rgb, vec3(lum * 0.28 + 0.44), locked);

	// ── 6) 실루엣 ──────────────────────────────────────────────────────
	// ★[2026-07-25] 알파는 **항상 원본 텍스처의 실루엣**을 따른다.
	//   물감은 이 알파 안에서만 존재하므로 "그림 밖(투명 여백)에 페인트가 묻는" 일이
	//   구조적으로 불가능하다. (구 VFX 스탬프 방식의 가장 큰 문제였다)
	col.a = max(cb.a, cw.a);

	COLOR = col;
}
