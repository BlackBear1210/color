// ▼ 2026-06-22 (색 표시 UI: 화면 테두리 글로우) 현재 플레이어 색을 화면 가장자리에 빛으로 표시.
//   전체화면 ColorRect 에 적용. 가장자리에서 안쪽으로 부드럽게 사라지는 테두리 빛을 그린다.
//   glow_color/intensity 를 player.gd 가 색 전환 때 바꿔(+펄스) 직관적인 상태 표시를 만든다.
shader_type canvas_item;

// 테두리 빛 색(플레이어 색에 맞춰 코드에서 설정). source_color 로 sRGB 보정.
uniform vec4 glow_color : source_color = vec4(0.1, 0.11, 0.18, 1.0);
// 빛의 세기(평소 약하게, 색 전환·사망 때 펄스로 강하게)
uniform float intensity : hint_range(0.0, 2.5) = 0.55;
// 테두리 두께(화면 가장자리에서 안쪽으로 차지하는 비율 0~0.5)
uniform float thickness : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	// 화면 네 변 중 가장 가까운 가장자리까지의 거리(0=가장자리, 0.5=중앙)
	float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	// 가장자리=1 → thickness 안쪽=0 으로 부드럽게 감쇠
	float edge = smoothstep(thickness, 0.0, d);
	COLOR = vec4(glow_color.rgb, edge * intensity * glow_color.a);
}
