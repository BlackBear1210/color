@tool
extends Node2D
## 새 물의 시각 전용 부품. 기존 유체의 충돌을 임의로 덮어쓰지 않는다.
## 크기는 노드 scale 대신 이 값으로 바꿔야 물결/물방울의 픽셀 밀도가 유지된다.
var 웅덩이_전용셰이더: Shader

const WATER_SHADER = preload("res://shaders/white_water_modular_v2.gdshader")
const FLOW_TEXTURE = preload("res://assets/textures/obstacles/liquid/white_modular_v2/flow_white.png")
const SPLASH_TEXTURE = preload("res://assets/textures/obstacles/liquid/white_modular_v2/splash_white.png")
## [2026-09-27] 물줄기 v3: 원통 반사선·굴절·톤별 흐름줄·구운 착수 프레임(왕관·눈물 물방울).
## 떨어지는 물줄기(형태 0·1)만 바꾼다. 웅덩이·수면 등은 v2 그대로.
## 프레임은 tools/생성_물줄기_v3_프레임.py 가 굽는다(손으로 그리지 말 것).
## load() 로 부르는 이유: preload 로 박으면 v3 를 안 쓰는 스테이지도 새 PNG 가 임포트되기 전엔
## 스크립트 자체가 안 열린다. 켠 노드에서만 읽는다.
const STREAM_V3_SHADER_PATH = "res://shaders/water_stream_v3.gdshader"
const STREAM_V3_FLOW_PATH = "res://assets/textures/obstacles/liquid/stream_v3/flow_v3.png"
const STREAM_V3_SPLASH_PATH = "res://assets/textures/obstacles/liquid/stream_v3/splash_v3_sheet.png"

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
## 켜면 형태 0·1 을 v3 외관으로 그린다. [2026-09-27] 2-9 시범 뒤 도형님 결정으로 기본 켬(전 스테이지).
## 옛 v2 외관이 필요한 노드만 인스펙터에서 끈다.
@export var 물줄기_v3: bool = true:
	set(value):
		물줄기_v3 = value
		_갱신()
## 유체의 판정_여유. v3 는 떨어지며 가늘어지는데, 판정 사각형보다 가늘어지면 안 보이는 곳에서 죽는다
## → 셰이더가 이 값을 빼고 남은 만큼만 조인다.
@export var 판정_여유: float = 0.0:
	set(value):
		판정_여유 = value
		_갱신()
## v3 전용: 그림이 끝나는 높이(0 = 크기.y). 판정이 바닥 속까지 내려가 있는 물줄기가 있어서
## (2-5 F1 은 바닥 윗면보다 60px 아래가 끝) 물막·물보라가 벽돌 속에 그려졌다.
## 유체_흰물v2 가 실행 중에 바닥 윗면을 찾아 넣어 준다. 판정은 건드리지 않는다.
@export var 보이는_높이: float = 0.0:
	set(value):
		보이는_높이 = maxf(0.0, value)
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
	# 에디터에서는 시간을 흘리지 않는다(아래 _process 주석). 게임에서만 매 프레임 넣는다.
	set_process(not Engine.is_editor_hint())

## ★[2026-09-30 Claude 실측] 물 셰이더 5 종이 TIME 을 읽고 있었다. TIME 을 읽는 그림이 화면에 하나라도 있으면
##   Godot 에디터는 **쉬지 않고 매 프레임 다시 그린다**(저전력 모드 2 초 290 장 vs 없으면 0 장).
##   가만히 둔 에디터가 내장 GPU 를 41% 쓰고, F5 로 켠 게임은 GPU 를 나눠 30ms(33FPS)까지 떨어졌다.
##   → 셰이더는 anim_time 유니폼을 읽고, 시간은 여기서 게임 중에만 넣는다. 에디터에서는 물이 멈춰 보인다.
##   TIME 과 같은 시계(엔진 시작 후 초 · 3600 초에서 되돌림)라 모든 물의 위상 관계는 예전과 같다.
func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("anim_time", fmod(float(Time.get_ticks_msec()) * 0.001, 3600.0))

func _v3_쓰나() -> bool:
	return 물줄기_v3 and 형태 in [0, 1]

## v3 착수 프레임의 화면상 배율(셰이더 splash_at 과 같은 식). 그리기 여백 계산에 쓴다.
func _v3_착수_배율() -> float:
	var 조임 := maxf(0.0, minf(_판정_안쪽() - 1.0, 크기.x * 0.08))
	return clampf((크기.x - 2.0 * 조임) / (64.0 * 0.85), 0.7, 1.6)

## 판정 사각형이 몸통 가장자리에서 들어온 거리(유체_흰물v2._판정_폴리곤들 과 같은 식).
func _판정_안쪽() -> float:
	return minf(7.0, 크기.x * 0.2) - 판정_여유

func _갱신() -> void:
	if not is_node_ready() or material == null:
		return
	var mat := material as ShaderMaterial
	if _v3_쓰나():
		_v3_갱신(mat)
		return
	var selected: Shader = 웅덩이_전용셰이더 if 형태 == 3 and 웅덩이_전용셰이더 != null else WATER_SHADER
	# 전용 수면 재질이 색/크기 갱신 때 기본 재질로 돌아가지 않게 한다.
	if mat.shader != selected:
		mat.shader = selected
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

func _v3_갱신(mat: ShaderMaterial) -> void:
	# 승인 시안의 낙수 본체까지 교체한다. 웅덩이 셰이더만 바꿔 물줄기가 그대로 남던 누락을 방지한다.
	var stage: Node = self
	var sewer := false
	while stage != null:
		if stage.scene_file_path.begins_with("res://scenes/world_2_클로드/stage_"):
			sewer = true
			break
		stage = stage.get_parent()
	var shader := load("res://shaders/water_stream_reference.gdshader" if sewer else STREAM_V3_SHADER_PATH) as Shader
	var flow := load(STREAM_V3_FLOW_PATH) as Texture2D
	var sheet := load(STREAM_V3_SPLASH_PATH) as Texture2D
	if shader == null or flow == null or sheet == null:
		# 새 PNG 가 아직 임포트되지 않았으면(에디터를 한 번도 안 열었으면) v2 로 그린다 — 물이 사라지면 안 된다.
		push_warning("물줄기 v3 리소스를 못 읽어 v2 로 그립니다: 에디터를 한 번 열어 임포트하세요")
		물줄기_v3 = false
		return
	if mat.shader != shader:
		mat.shader = shader
	mat.set_shader_parameter("flow_texture", flow)
	mat.set_shader_parameter("splash_sheet", sheet)
	# 하수도에서만 새 낙수 색 규칙을 적용한다. 다른 챕터의 기존 외관은 유지한다.
	mat.set_shader_parameter("colored_splash", sewer)
	mat.set_shader_parameter("impact", 착수_물보라)
	mat.set_shader_parameter("water_tone", 물색)
	var 높이 := 보이는_높이 if 보이는_높이 > 0.0 else 크기.y
	mat.set_shader_parameter("extent", Vector2(크기.x, minf(높이, 크기.y)))
	mat.set_shader_parameter("kind", 형태)
	mat.set_shader_parameter("speed", 흐름속도)
	mat.set_shader_parameter("back_depth", 수면_뒤깊이)
	mat.set_shader_parameter("hit_inset", _판정_안쪽())
	mat.set_shader_parameter("animate", 애니메이션)
	mat.set_shader_parameter("phase", 위상)
	queue_redraw()

func _draw() -> void:
	# 셰이더 TIME으로 흐르므로 CPU에서 매 프레임 메시나 판정을 다시 만들지 않는다.
	var back := 수면_뒤깊이 if 형태 == 3 else 0.0
	# 가장자리 분무와 착수 물보라는 디자인 크기 밖에도 보여야 종이처럼 잘리지 않는다.
	var margin := 150.0 if 형태 in [0, 1, 2] else 0.0
	if _v3_쓰나():
		# v3 착수 프레임은 기준 폭에서 좌우 192px, 배율만큼 커진다(바닥 물막·잔물결이 잘리지 않게).
		margin = maxf(margin, 192.0 * _v3_착수_배율() - 크기.x * 0.5 + 4.0)
	var bottom := 32.0 if 형태 in [0, 1, 2] else 0.0
	draw_rect(Rect2(Vector2(-크기.x * 0.5 - margin, -back), 크기 + Vector2(margin * 2.0, back + bottom)), Color.WHITE)
