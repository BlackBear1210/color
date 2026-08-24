shader_type canvas_item;
// ============================================================================
// 잉크 번짐 "마스크 전용" 셰이더 — 타일맵 오버레이 레이어에 붙인다
// ----------------------------------------------------------------------------
// ▣ 무엇을 하는가
//   ink_spread.gdshader 는 "흑/백 한 쌍이 든 시트 1장"을 직접 샘플링하는 셰이더였다.
//   이 버전은 텍스처를 건드리지 않는다. 대신 **이미 반대색 타일이 찍혀 있는
//   오버레이 TileMapLayer** 의 알파만 깎아서, 칠해진 영역에서만 그 타일이 드러나게 한다.
//     마스크 1 → 오버레이(=칠해진 무늬)가 보인다
//     마스크 0 → 알파 0 → 아래 원본 레이어(=칠하기 전 무늬)가 그대로 비친다
//   덕분에 "타일 한 칸이 통째로 바뀌는 각진 느낌"이 사라지고, 칸 경계와 무관하게
//   물감이 스며든 모양으로 경계가 생긴다. (규칙·판정은 전부 CPU 쪽 tile_paint_map.gd)
//
// ▣ 좌표계 — ★반드시 월드(캔버스) 좌표로 계산해야 한다
//   local_uv = (world_pos - origin_world) / size_world
//
//   ⚠ 처음엔 vertex() 에서 VERTEX 를 그대로 썼는데 **마스크가 전 영역 0 이 되어
//     오버레이가 완전히 투명해졌다**(스크린샷으로 확인). 이유:
//     TileMapLayer 는 타일을 통째로 하나의 CanvasItem 에 그리지 않고
//     **렌더링 쿼드런트(rendering_quadrant_size)별 CanvasItem** 으로 쪼개 그린다.
//     그래서 VERTEX 는 레이어 원점이 아니라 **그 쿼드런트 원점 기준**의 작은 값이다.
//     레이어 좌표로 넘긴 origin 과 뺄셈이 성립하지 않아 거리가 터져버린다.
//   → MODEL_MATRIX 로 월드 좌표로 올린 뒤 계산한다. 쿼드런트가 몇 개로 쪼개지든
//     각 쿼드런트의 MODEL_MATRIX 가 자기 오프셋을 품고 있어 항상 이어진 하나의 원이 된다.
// ============================================================================

const int MAX_SEEDS = 16;

uniform vec2  origin_world = vec2(0.0, 0.0);  // 플랫폼 바운딩박스 좌상단 (월드 px)
uniform vec2  size_world = vec2(256.0, 32.0); // 플랫폼 바운딩박스 크기 (월드 px)
uniform float aspect    = 8.0;                // size_world.x / size_world.y

uniform vec2  seeds[MAX_SEEDS];             // 명중 지점 (바운딩박스 UV)
uniform float seed_r[MAX_SEEDS];            // 각 지점의 현재 번짐 반지름
uniform float seed_a[MAX_SEEDS];            // 색별 자동 회수 감쇠 0~1
uniform int   seed_c[MAX_SEEDS];            // 각 지점의 색 0=검정, 1=흰색
uniform int   seed_count = 0;
uniform int   original_color = 0;            // 원본 타일 색
uniform float base_mask = 0.0;               // 완성 상태에서 반대색 오버레이를 전부 보일지

uniform float noise_amount = 0.13;          // 경계 일그러짐 (0 = 완전한 원)
uniform float noise_scale  = 3.2;           // 노이즈 세밀도
uniform float edge_soft    = 0.035;         // 경계 부드러움
uniform float wet_amount   = 0.0;           // 젖은 하이라이트 세기 (명중 직후 1 → 0)
uniform float wet_width    = 0.14;          // 젖은 띠 두께
uniform int   paint_color  = 0;             // 0 = 검정 물감, 1 = 흰색 물감 (광택 색조용)
uniform float locked       = 0.0;           // 1 = 회색(영구) — 대비를 죽인다

varying vec2 local_uv;

void vertex() {
	// 쿼드런트 로컬 → 월드. 이 변환이 있어야 타일 여러 칸/여러 쿼드런트에 걸쳐
	// 하나의 연속된 번짐 원이 만들어진다.
	vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local_uv = (world_pos - origin_world) / max(size_world, vec2(0.0001));
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
float fbm(vec2 p) {                                  // 3옥타브 = 잉크 특유의 들쭉날쭉함
	return vnoise(p) * 0.60 + vnoise(p * 2.13) * 0.28 + vnoise(p * 4.70) * 0.12;
}

void fragment() {
	// 가로가 긴 플랫폼에서 원이 타원으로 찌그러지지 않게 x 를 aspect 로 편다
	vec2 ap = vec2(local_uv.x * aspect, local_uv.y);

	float coverage = base_mask;
	float nearest_edge = 1e9;
	for (int i = 0; i < MAX_SEEDS; i++) {
		if (i >= seed_count) { break; }
		vec2 s = vec2(seeds[i].x * aspect, seeds[i].y);
		float d = distance(ap, s) - seed_r[i];
		d += (fbm(ap * noise_scale) - 0.5) * noise_amount;
		float influence = (1.0 - smoothstep(0.0, edge_soft, d)) * seed_a[i];
		float desired = (seed_c[i] == original_color) ? 0.0 : 1.0;
		coverage = mix(coverage, desired, influence);
		nearest_edge = min(nearest_edge, abs(d));
	}

	// 젖은 느낌의 하이라이트 — 번지는 경계에만, 명중 직후 잠깐
	float band = (1.0 - smoothstep(0.0, wet_width, nearest_edge)) * coverage * wet_amount;
	vec3 sheen = (paint_color == 1) ? vec3(0.55, 0.56, 0.60) : vec3(0.42, 0.43, 0.50);
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * 0.55 + sheen * 0.55, clamp(band, 0.0, 1.0));

	// 회색(영구) 상태: 대비를 죽여 "죽은 지형"으로 (레벨디자인 가이드 §5 = 45~55%)
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(lum * 0.28 + 0.44), locked);

	COLOR.a *= coverage;
}
