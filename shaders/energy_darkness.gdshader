// ▼ 2026-06-28 신규: 발광(에너지) 소진에 따라 '화면 전체'를 어둡게 덮는 오버레이.
//   플레이어 주변(light_pos)만 원형으로 비워(빛 구멍) 둬서, 쏠수록 세상이 어두워지고
//   플레이어 근처만 밝게 남는 연출. (player.gd 가 매 프레임 파라미터를 갱신)
shader_type canvas_item;

uniform vec2  light_pos    = vec2(0.5);                  // 플레이어의 화면 UV 위치(0~1)
uniform float light_radius : hint_range(0.0, 1.5) = 0.4; // 빛 구멍 반경(UV)
uniform float darkness     : hint_range(0.0, 1.0) = 0.0; // 어둠 강도(0=밝음, 1=깜깜)
uniform float aspect       = 1.777;                      // 화면 가로/세로 비(원을 둥글게 유지)

void fragment() {
	vec2 d = UV - light_pos;
	d.x *= aspect;                                       // 가로 보정 → 정원(타원 방지)
	float dist = length(d);
	// 플레이어 근처 = 0(밝음) → 반경 바깥 = 1(어둠)
	float fade = smoothstep(light_radius * 0.35, light_radius, dist);
	COLOR = vec4(0.0, 0.0, 0.0, darkness * fade);
}
