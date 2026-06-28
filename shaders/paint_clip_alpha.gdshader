// ▼ 2026-06-28 신규: 페인트를 '지형 충돌폴리곤'이 아니라 '지형 비주얼(텍스처 알파)'에 맞춰 오린다.
//   [왜?] 기존 paint_clip.gdshader 는 지형의 CollisionPolygon2D(물리레이어) 한 조각에 맞춰 페인트를 잘랐다.
//         자동 생성된 충돌은 비주얼과 다르거나(단순화/볼록분해) 여러 조각으로 쪼개져, 페인트가 그림과
//         어긋나거나 잘려 보였다(= "물리레이어를 정확히 안 찍으면 색이 정확히 안 칠해지는" 문제).
//   [해결] 지형이 '그려진(텍스처 알파>cut)' 픽셀에만 페인트를 남긴다 → 충돌과 무관하게 그림 위에 정확히 칠해짐.
shader_type canvas_item;

uniform sampler2D terrain_tex : filter_linear, repeat_disable;
// 월드좌표 → 지형 로컬좌표 역변환(Transform2D 를 열벡터 3개로 전달: local = inv_x*wx + inv_y*wy + inv_o)
uniform vec2  inv_x      = vec2(1.0, 0.0);
uniform vec2  inv_y      = vec2(0.0, 1.0);
uniform vec2  inv_o      = vec2(0.0);
uniform vec2  tex_size   = vec2(1.0);    // 지형 텍스처 픽셀 크기
uniform vec2  tex_offset = vec2(0.0);    // 지형 Sprite2D 의 offset
uniform float centered   = 1.0;          // 1=centered Sprite(중심정렬), 0=좌상단정렬
uniform float alpha_cut  : hint_range(0.0, 1.0) = 0.35;  // 이 알파 미만이면 '지형 바깥' → 페인트 안 칠함
uniform int   enabled    = 0;            // 0이면 클리핑 끔(텍스처 정보 없을 때 그대로 표시)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;  // 프래그먼트의 월드(캔버스) 좌표
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (enabled == 1) {
		vec2 local = inv_x * world_pos.x + inv_y * world_pos.y + inv_o;   // 월드 → 지형 로컬
		vec2 uv = (local - tex_offset) / tex_size + vec2(0.5) * centered; // 지형 로컬 → 텍스처 UV
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			discard;                                          // 텍스처 범위 밖
		}
		if (texture(terrain_tex, uv).a < alpha_cut) {
			discard;                                          // 지형이 안 그려진(투명) 자리
		}
	}
	COLOR = tex_color;
}
