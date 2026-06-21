// ▼ 2026-06-21 (작업 W-C) 신규: 회색 경사로 '그라데이션 페인트' 셰이더.
//   목적: 총알이 닿은 지점마다 플레이어 색(검정/흰색)이 중심에서 가장 진하고
//         바깥으로 갈수록 옅어져, 아래에 깔린 회색 경사로로 자연스럽게
//         녹아드는(=그라데이션) 효과를 만든다.
//   원리: 이 셰이더가 칠해진 'ColorRect 오버레이'에 적용된다. 오버레이는 평소
//         완전 투명(알파 0)이라 회색 경사로가 그대로 보이고, 페인트 지점 근처만
//         알파가 올라가며 색이 나타난다. 알파가 1→0 으로 옅어지므로 결과적으로
//         '플레이어 색 → 회색' 그라데이션이 된다.
shader_type canvas_item;

const int MAX_POINTS = 32;

// 칠해진 지점들 (ColorRect 로컬 픽셀 좌표, 0..rect_size)
uniform int   point_count : hint_range(0, 32) = 0;
uniform vec2  points[MAX_POINTS];
// 각 지점의 색: 0.0 = 검정, 1.0 = 흰색
uniform float colors[MAX_POINTS];
// 오버레이(ColorRect)의 픽셀 크기 — UV(0..1) 를 픽셀 좌표로 환산하는 데 사용
uniform vec2  rect_size = vec2(512.0, 256.0);
// 한 번의 페인트가 번지는 반경(px). 클수록 그라데이션이 넓고 부드럽다.
uniform float radius = 120.0;
// 중심부 페인트의 최대 진하기(알파 상한). 1.0 이면 중심이 완전 불투명.
uniform float max_strength = 0.95;

void fragment() {
	// 이 픽셀의 로컬 좌표(px)
	vec2 px = UV * rect_size;

	float best_influence = 0.0;   // 가장 강한 페인트 영향력(중심=1, 반경끝=0)
	float best_color = 0.0;       // 그 페인트의 색(0=검정,1=흰색)

	for (int i = 0; i < point_count; i++) {
		float d = distance(px, points[i]);
		if (d < radius) {
			// 중심에서 1, 반경 끝에서 0 으로 부드럽게 감쇠 → 그라데이션
			float infl = smoothstep(1.0, 0.0, d / radius);
			if (infl > best_influence) {
				best_influence = infl;
				best_color = colors[i];
			}
		}
	}

	// 검정(0.05)과 흰색(0.97) 사이를 색 값으로 보간
	vec3 paint_rgb = mix(vec3(0.05), vec3(0.97), best_color);
	// 알파를 영향력에 비례시켜 중심=진함 → 바깥=투명(아래 회색이 비침)
	COLOR = vec4(paint_rgb, best_influence * max_strength);
}
