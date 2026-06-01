shader_type canvas_item;

// 충돌한 지형의 폴리곤 꼭짓점 (월드 좌표계)
const int MAX_VERTS = 100;
uniform int   vert_count : hint_range(0, 100) = 0;
uniform vec2  polygon[100];

// 버텍스 셰이더에서 월드 좌표를 프래그먼트로 전달
varying vec2 world_pos;

// 레이캐스팅 알고리즘: 점 p 가 폴리곤 안에 있으면 true
bool point_in_polygon(vec2 p) {
	bool inside = false;
	int j = vert_count - 1;
	for (int i = 0; i < vert_count; i++) {
		vec2 vi = polygon[i];
		vec2 vj = polygon[j];
		if (((vi.y > p.y) != (vj.y > p.y)) &&
			(p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x)) {
			inside = !inside;
		}
		j = i;
	}
	return inside;
}

void vertex() {
	// 로컬 좌표 → 월드(캔버스) 좌표 변환
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// vert_count 가 0 이면 클리핑 없이 그대로 표시
	if (vert_count > 0 && !point_in_polygon(world_pos)) {
		discard;
	}
	COLOR = tex_color;
}
