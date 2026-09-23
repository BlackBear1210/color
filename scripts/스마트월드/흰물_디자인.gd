@tool
extends Node2D
## 새 물의 시각 전용 부품. 기존 유체의 충돌을 임의로 덮어쓰지 않는다.
## 크기는 노드 scale 대신 이 값으로 바꿔야 물결/물방울의 픽셀 밀도가 유지된다.
const WATER_SHADER = preload("res://shaders/white_water_modular_v2.gdshader")
const FLOW_TEXTURE = preload("res://assets/textures/obstacles/liquid/white_modular_v2/flow_white.png")
const SPLASH_TEXTURE = preload("res://assets/textures/obstacles/liquid/white_modular_v2/splash_white.png")

## 기존 씬 경로는 유지하며 세 색이 같은 물살과 애니메이션을 공유한다.
@export_enum("검정:0", "흰색:1", "회색:2") var 물색: int = 1:
	set(value):
		물색 = value
		_갱신()

## 웅덩이는 실제 지형과 같은 사선을 쓰고 색이 바뀌어도 외곽선을 유지한다.
@export var 웅덩이_오른쪽_안쪽폭: float = 0.0:
	set(value):
		웅덩이_오른쪽_안쪽폭 = maxf(0.0, value)
		_갱신()
@export_enum("검정:0", "흰색:1", "회색:2") var 웅덩이_색: int = 1:
	set(value):
		웅덩이_색 = value
		_갱신()

## 착수 물보라는 고정 분무 그림 대신 짧은 물방울이 포물선으로 떨어진다.
## 착수점이 없는 공중 물줄기는 끈다. 물보라가 잘리지 않도록 그리기 영역만 확장한다.
@export var 착수_물보라: bool = true:
	set(value):
		착수_물보라 = value
		_갱신()

@export_enum("가는 물줄기", "넓은 물막", "배관 출수", "수면과 웅덩이", "충돌 물보라", "잔물과 물방울") var 형태: int = 0:
	set(value):
		형태 = value
		_갱신()
@export var 크기: Vector2 = Vector2(64, 320):
	set(value):
		크기 = Vector2(maxf(8.0, value.x), maxf(8.0, value.y))
		_갱신()
## 빠른 낙하 물살도 에디터에서 조정할 수 있도록 속도 범위를 넓힌다.
@export_range(0.0, 2000.0, 1.0) var 흐름속도: float = 130.0:
	set(value):
		흐름속도 = value
		_갱신()
@export_range(32.0, 512.0, 1.0) var 무늬_크기: float = 128.0:
	set(value):
		무늬_크기 = value
		_갱신()
## 기본 지형 마감 메시와 동일: 뒤쪽 4px, 끝 모따기 3px. 폭 비례 확대 금지.
## 착수점도 셰이더에서 이 뒤깊이의 절반만큼 올려 윗면 중앙에 맞춘다. 충돌은 유지한다.
@export_range(1.0, 24.0, 0.5) var 수면_뒤깊이: float = 4.0:
	set(value):
		수면_뒤깊이 = value
		_갱신()
@export var 애니메이션: bool = true:
	set(value):
		애니메이션 = value
		_갱신()
@export var 위상: float = 0.0:
	set(value):
		위상 = value
		_갱신()

func _ready() -> void:
	# 인스턴스마다 크기와 속도가 달라 공유 재질을 사용하지 않는다.
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	material = mat
	_갱신()

func _갱신() -> void:
	if not is_node_ready() or material == null:
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("flow_texture", FLOW_TEXTURE)
	mat.set_shader_parameter("splash_texture", SPLASH_TEXTURE)
	mat.set_shader_parameter("impact", 착수_물보라)
	mat.set_shader_parameter("pool_right_inset", minf(웅덩이_오른쪽_안쪽폭, 크기.x * 0.75))
	mat.set_shader_parameter("pool_tone", 웅덩이_색)
	mat.set_shader_parameter("water_tone", 물색)
	mat.set_shader_parameter("extent", 크기)
	mat.set_shader_parameter("kind", 형태)
	mat.set_shader_parameter("speed", 흐름속도)
	mat.set_shader_parameter("tile_size", 무늬_크기)
	mat.set_shader_parameter("back_depth", 수면_뒤깊이)
	mat.set_shader_parameter("corner_inset", minf(3.0, 크기.x * 0.2))
	mat.set_shader_parameter("animate", 애니메이션)
	mat.set_shader_parameter("phase", 위상)
	queue_redraw()

func _draw() -> void:
	# 셰이더 TIME으로 흐르므로 CPU에서 매 프레임 메시나 판정을 다시 만들지 않는다.
	var back := 수면_뒤깊이 if 형태 == 3 else 0.0
	# 가장자리 분무와 착수 물보라는 디자인 크기 밖에도 보여야 종이처럼 잘리지 않는다.
	var margin := 150.0 if 형태 in [0, 1, 2] else 0.0
	var bottom := 32.0 if 형태 in [0, 1, 2] else 0.0
	draw_rect(Rect2(Vector2(-크기.x * 0.5 - margin, -back), 크기 + Vector2(margin * 2.0, back + bottom)), Color.WHITE)
