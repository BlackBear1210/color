@tool
extends PaintPlatform
## ============================================================================
## [실험/테스트] 타일맵 조각으로 만든 페인트 플랫폼
## ----------------------------------------------------------------------------
## PaintPlatform(재질 하나로 스프라이트를 자동 생성)을 상속만 받고, 시각 표현
## 부분만 갈아 끼운다. 게임 규칙(명중 판정·필요횟수·회수 등)은 전부 부모 것을
## 그대로 쓴다 — 그래야 paint_manager.gd/stage_lab.gd 의 `as PaintPlatform`
## 캐스팅이 이 노드에도 그대로 통과한다.
##
## ▣ 씬 구조 (이 스크립트가 붙는 노드의 자식으로 미리 넣어둬야 함)
##   무색_레이어  TileMapLayer  — 항상 바닥에 깔리는 "아직 안 칠함" 표시(어둡게 틴트)
##   흑_레이어    TileMapLayer  — 검정으로 칠했을 때 드러나는 실제 타일 그림
##   백_레이어    TileMapLayer  — 흰색으로 칠했을 때 드러나는 실제 타일 그림
##   (셋 다 같은 TileSet 을 참조해야 하고, 콜리전은 그 TileSet 의 physics layer
##    가 부모(AnimatableBody2D)에 자동으로 합쳐지므로 따로 안 만든다.)
## ============================================================================
class_name TilePaintPlatform

const MASK_SHADER := preload("res://shaders/ink_spread_mask.gdshader")

var _무색: TileMapLayer
var _흑: TileMapLayer
var _백: TileMapLayer

func _그림_만들기() -> void:
	_무색 = get_node_or_null("무색_레이어") as TileMapLayer
	_흑 = get_node_or_null("흑_레이어") as TileMapLayer
	_백 = get_node_or_null("백_레이어") as TileMapLayer
	if _무색 == null or _흑 == null or _백 == null:
		push_warning("[TilePaintPlatform] 자식으로 무색_레이어/흑_레이어/백_레이어 (TileMapLayer) 3개가 필요합니다.")
		return

	_무색.self_modulate = Color(0.55, 0.55, 0.55, 1.0)
	for 층 in [_흑, _백]:
		var mat := 층.material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = MASK_SHADER
			층.material = mat

	# 필요횟수() 계산이 "실제로 배치된 타일 크기"를 따라가도록 자동 보정.
	# ⚠ 크기_칸 의 setter(부모 PaintPlatform)가 _다시_만들기() → _그림_만들기() 를
	#   다시 호출한다. 값이 같아도 무조건 대입하면 setter가 매번 재귀 호출을
	#   일으켜 무한 재귀(스택 오버플로우)에 빠진다 — 그래서 값이 실제로 바뀔 때만 대입한다.
	var 범위 := _무색.get_used_rect()
	if 범위.size.x > 0 and 범위.size.y > 0 and 크기_칸 != 범위.size:
		크기_칸 = 범위.size

func _충돌_만들기() -> void:
	pass  # TileMapLayer 자신의 물리 레이어(physics_layer_0)가 부모 AnimatableBody2D 에 자동으로 합쳐진다.

func _유니폼_갱신() -> void:
	if _무색 == null or _흑 == null or _백 == null:
		return

	var 진행_레이어 := _흑 if _진행색 == ColorDefs.BLACK else _백
	var 상대_레이어 := _백 if _진행색 == ColorDefs.BLACK else _흑
	상대_레이어.visible = false

	if 현재상태 == 상태.회색:
		# 영구 회색: 마스크 애니메이션 없이 그냥 밝기만 낮춘 상태로 고정.
		진행_레이어.visible = true
		진행_레이어.self_modulate = Color(0.72, 0.72, 0.72, 1.0)
		var 잠금_mat := 진행_레이어.material as ShaderMaterial
		if 잠금_mat:
			잠금_mat.set_shader_parameter("seed_count", 0)
		return

	진행_레이어.visible = (현재상태 != 상태.무색) or _맞은횟수 > 0 or _시드.size() > 0
	진행_레이어.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	var mat := 진행_레이어.material as ShaderMaterial
	if mat == null:
		return

	var 범위 := 진행_레이어.get_used_rect()
	var 타일px: float = float(진행_레이어.tile_set.tile_size.x) if 진행_레이어.tile_set else 16.0
	var origin_px := Vector2(범위.position) * 타일px
	var node_size := Vector2(크기_칸) * 타일px

	var 시드8 := PackedVector2Array()
	var 반지름8 := PackedFloat32Array()
	for i in 최대_시드:
		시드8.append(_시드[i] if i < _시드.size() else Vector2.ZERO)
		반지름8.append(_시드반지름[i] if i < _시드반지름.size() else 0.0)

	mat.set_shader_parameter("origin_px", origin_px)
	mat.set_shader_parameter("node_size", node_size)
	mat.set_shader_parameter("aspect", _종횡비())
	mat.set_shader_parameter("seeds", 시드8)
	mat.set_shader_parameter("seed_r", 반지름8)
	mat.set_shader_parameter("seed_count", _시드.size())
	mat.set_shader_parameter("noise_amount", 0.13)
	mat.set_shader_parameter("noise_scale", 3.2)
	mat.set_shader_parameter("edge_soft", 0.035)
