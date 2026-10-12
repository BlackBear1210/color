extends Node2D
## 최초 걷기 원화의 다리 그림만 번갈아 앞뒤로 흔든다.
## 무릎·발목·발끝 보정이나 길이 변경 없이 원래 다리 모양을 그대로 유지한다.

const 원화_셰이더 := preload("res://shaders/paint_head.gdshader")
const 분할_키 := ["split_count", "line_1", "line_2", "color_table", "water_pool_count", "water_edges", "water_edge_counts"]
# 배열 생성자를 상수식으로 선언하지 않고 인스턴스 초기화 때 한 번 만든다.
var 도안: Dictionary = {
	"black": {"cut": 470.0,
		"far": {"hip": Vector2(275,470), "outline": PackedVector2Array([Vector2(180,470),Vector2(321,470),Vector2(321,590),Vector2(180,590)])},
		"near": {"hip": Vector2(355,470), "outline": PackedVector2Array([Vector2(321,470),Vector2(490,470),Vector2(490,590),Vector2(321,590)])}},
	"white": {"cut": 478.0,
		"far": {"hip": Vector2(268,478), "outline": PackedVector2Array([Vector2(180,478),Vector2(321,478),Vector2(321,590),Vector2(180,590)])},
		"near": {"hip": Vector2(351,478), "outline": PackedVector2Array([Vector2(321,478),Vector2(490,478),Vector2(490,590),Vector2(321,590)])}}
}
var _본체: AnimatedSprite2D
var _다리들: Array[Dictionary] = []

func 연결(본체: AnimatedSprite2D) -> void:
	_본체 = 본체
	for 쪽 in ["far", "near"]:
		for 색 in ["black", "white"]:
			var 그림 := MeshInstance2D.new()
			그림.name = 색 + "_" + 쪽
			var 원본 := 본체.sprite_frames.get_frame_texture(색 + "_walk", 0) as AtlasTexture
			그림.texture = 원본.atlas
			그림.mesh = ArrayMesh.new()
			var 재질 := ShaderMaterial.new()
			재질.shader = 원화_셰이더
			재질.set_shader_parameter("sheet_color", 0.0 if 색 == "black" else 1.0)
			재질.set_shader_parameter("tank_enabled", false)
			그림.material = 재질
			add_child(그림)
			var 윤곽: PackedVector2Array = 도안[색][쪽]["outline"]
			var 점들 := PackedVector2Array()
			# 코트 접합부만 고정하고 나머지 다리는 원래 그림 한 장으로 회전시킨다.
			for y in [윤곽[0].y, 윤곽[0].y + 9.0, 윤곽[0].y + 18.0, 윤곽[2].y]:
				점들.append(Vector2(윤곽[0].x, y))
				점들.append(Vector2(윤곽[1].x, y))
			var 번호 := PackedInt32Array()
			for i in 3:
				var a := i * 2
				번호.append_array(PackedInt32Array([a,a+1,a+3,a,a+3,a+2]))
			_다리들.append({"node": 그림, "color": 색, "side": 쪽, "points": 점들, "indices": 번호, "hip": 도안[색][쪽]["hip"]})
	visible = false

func 절단높이(색: String) -> float:
	return float(도안[색]["cut"])

func 갱신(위상: float, 켜짐: bool) -> void:
	visible = 켜짐
	if not 켜짐:
		return
	scale = Vector2(-1.0 if _본체.flip_h else 1.0, 1.0)
	for 다리 in _다리들:
		var 재질 := 다리["node"].material as ShaderMaterial
		var 본체재질 := _본체.material as ShaderMaterial
		if 본체재질:
			# 기존 색 경계와 수중 가림은 다리에도 동일하게 전달한다.
			for 키 in 분할_키:
				var 값 = 본체재질.get_shader_parameter(키)
				if 값 != null:
					재질.set_shader_parameter(키, 값)
		var 원본 := _본체.sprite_frames.get_frame_texture(다리["color"] + "_walk", _본체.frame) as AtlasTexture
		var 각도 := sin(위상 * TAU) * 0.28 * (-1.0 if 다리["side"] == "far" else 1.0)
		var 골반: Vector2 = 다리["hip"]
		var 꼭짓점 := PackedVector2Array()
		var uv := PackedVector2Array()
		for 점 in 다리["points"]:
			# 다리 전체를 반대 방향으로 회전시킬 뿐, 관절이나 발 모양을 새로 만들지 않는다.
			var 이동: Vector2 = 골반 + (점 - 골반).rotated(각도)
			꼭짓점.append(점.lerp(이동, smoothstep(골반.y, 골반.y + 18.0, 점.y)) - Vector2(320,320))
			uv.append((원본.region.position + 점) / Vector2(원본.atlas.get_size()))
		var 배열 := []
		배열.resize(Mesh.ARRAY_MAX)
		배열[Mesh.ARRAY_VERTEX] = 꼭짓점
		배열[Mesh.ARRAY_TEX_UV] = uv
		배열[Mesh.ARRAY_INDEX] = 다리["indices"]
		var 메시 := 다리["node"].mesh as ArrayMesh
		메시.clear_surfaces()
		메시.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, 배열)
