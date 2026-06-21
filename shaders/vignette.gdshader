// ▼ 2026-06-22 (작업 C: 분위기) 화면 가장자리를 어둡게 하는 비네트 셰이더.
//   전체화면 ColorRect 에 적용. 가장자리만 검게 깔려 화면에 깊이감/집중감을 준다.
shader_type canvas_item;

// 비네트 진하기(0=없음, 1=진함)
uniform float strength : hint_range(0.0, 1.0) = 0.45;
// 어두워지기 시작하는 반경(작을수록 넓게 어두워짐)
uniform float inner_radius : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	// 화면 중심(0.5,0.5) 기준 거리(모서리=약 1.0)
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 1.41421356;
	// inner_radius~1.0 구간에서 부드럽게 알파 증가
	float v = smoothstep(inner_radius, 1.0, dist) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, v);
}
