shader_type canvas_item;
// [2026-07-17 도형] 로비 전용 "반전(Inversion)" 오버레이.
// 화면 전체를 캡처해서, 천천히 움직이는 경계선 오른쪽을 색 반전시킨다.
// (흑 바탕+백 글자 → 경계 너머에서는 백 바탕+흑 글자 — 게임의 핵심 콘셉트를 로비에서 바로 보여줌)
// 마우스 주변 원은 XOR 로 한 번 더 뒤집힌다 = "커서가 붓" 인터랙션.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float split_x = 0.5;        // 경계선 위치 (스크립트가 sin 으로 애니메이션)
uniform float slope = 0.18;         // 경계선 기울기 (수직이 아니라 살짝 사선)
uniform float edge = 0.004;         // 경계 부드러움
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float brush_r = 0.06;       // 마우스 반전 원 반지름 (화면 세로 기준)
uniform float aspect = 1.7778;      // 뷰포트 가로/세로 비 (원이 찌그러지지 않게)

void fragment() {
	vec4 scr = texture(screen_tex, SCREEN_UV);

	// 사선 경계: 오른쪽 = 반전 구역
	float d = SCREEN_UV.x + (SCREEN_UV.y - 0.5) * slope - split_x;
	float band = smoothstep(-edge, edge, d);

	// 마우스 원 (XOR: 반전 구역 안에서는 원래대로, 밖에서는 반전)
	vec2 duv = SCREEN_UV - mouse_uv;
	duv.x *= aspect;
	float circle = 1.0 - smoothstep(brush_r - 0.012, brush_r, length(duv));

	float mask = abs(band - circle);
	vec3 inverted = vec3(1.0) - scr.rgb;
	COLOR = vec4(mix(scr.rgb, inverted, mask), 1.0);
}
