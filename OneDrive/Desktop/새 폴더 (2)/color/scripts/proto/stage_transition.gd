extends CanvasLayer
## [2026-07-17 도형 · 신규] 잉크(페인트) 와이프 씬 전환.
## 리틀 나이트메어의 "공간을 통과하면 화면이 자연스럽게 넘어가는" 느낌을
## 흑백 게임에 맞게 번안: 가장자리가 물감처럼 울퉁불퉁한 잉크가 왼쪽에서 화면을
## 덮고 → 씬 교체 → 오른쪽으로 빠져나간다 (한 방향으로 흐르는 스윕 = 이동감).
##
## 사용법 (어디서든 한 줄):
##   StageTransition.change_scene(self, "res://scenes/world_1/stage_2/stage_2.tscn")
## 색 지정 (예: 흰 잉크):
##   StageTransition.change_scene(self, path, Color.WHITE)
##
## · autoload 등록 불필요 (project.godot 무수정 원칙) — 호출 시 root 에 스스로 붙고
##   전환이 끝나면 스스로 사라진다.
## · ExitZone(그룹 zone_exit) 쪽 진행 시스템에서 이 함수를 호출하면
##   스테이지 → 스테이지 연결에도 그대로 쓸 수 있다.
class_name StageTransition

const COVER_TIME: float = 0.45
const REVEAL_TIME: float = 0.55
## 잉크 가장자리 노이즈 — 딱 떨어지는 직선이 아니라 물감 자국처럼 번지게.
const WIPE_SHADER := "
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;          // 1 = 왼쪽에서 덮기, -1 = 오른쪽으로 걷히기
uniform vec3 wipe_color : source_color = vec3(0.03, 0.03, 0.03);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float x = direction > 0.0 ? UV.x : 1.0 - UV.x;
	float edge = vnoise(UV * vec2(3.0, 9.0)) * 0.22;   // 물감 가장자리 얼룩
	float p = progress * 1.5;
	float mask = smoothstep(p - 0.28, p, x + edge);
	COLOR = vec4(wipe_color, 1.0 - mask);
}
"

var _rect: ColorRect
var _mat: ShaderMaterial

## 잉크로 화면을 덮고 → scene_path 로 교체 → 잉크가 걷힌다. (호출 후 신경 쓸 것 없음)
static func change_scene(from: Node, scene_path: String,
		ink: Color = Color(0.03, 0.03, 0.03)) -> void:
	var tr := StageTransition.new()
	# current_scene 이 아니라 root 에 붙어야 씬이 바뀌어도 살아남는다
	from.get_tree().root.add_child(tr)
	tr._run(scene_path, ink)

func _init() -> void:
	layer = 100
	var shader := Shader.new()
	shader.code = WIPE_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func _run(scene_path: String, ink: Color) -> void:
	_mat.set_shader_parameter("wipe_color", Vector3(ink.r, ink.g, ink.b))

	# 1) 덮기: 왼쪽에서 잉크가 밀려온다
	_mat.set_shader_parameter("direction", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, COVER_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished

	# 2) 화면이 완전히 가려진 동안 씬 교체
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame   # 새 씬 첫 프레임이 그려질 때까지 잉크 유지
	await get_tree().process_frame

	# 3) 걷히기: 오른쪽으로 빠져나간다 (한 방향 스윕 = "앞으로 이동했다"는 느낌)
	_mat.set_shader_parameter("direction", -1.0)
	var tw2 := create_tween()
	tw2.tween_method(_set_progress, 1.0, 0.0, REVEAL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	queue_free()

func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
