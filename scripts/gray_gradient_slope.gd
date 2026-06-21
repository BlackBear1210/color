extends StaticBody2D
## ▼ 2026-06-21 (작업 W-C) 신규: 회색 그라데이션 경사로.
##
## ◆ 컨셉
##   - 평소엔 회색(GRAY) 경사로. 회색 그라데이션 비주얼이라 "왜 회색이지?" 궁금증을 유발.
##   - 그냥 오르려 하면 player.gd 의 회색 미끄럼 로직에 의해 주르륵 미끄러져 내려간다.
##   - 플레이어가 색깔총(=자기 색)을 쏘면, 총알이 닿은 부위가 그 색에서 회색으로
##     자연스럽게 번지는 '그라데이션'으로 칠해진다.
##   - 칠해진 부위는 자기 색이므로 밟고 오를 수 있다(미끄럼 해제 + 사망 안전).
##
## ◆ 역할 분담 (중요)
##   - '게임플레이'(밟기·미끄럼 해제·사망 안전)는 기존 PaintMark 시스템이 그대로 처리한다.
##     (bullet.gd 가 회색 경사로에 닿으면 평소처럼 PaintMark 를 생성 → 그 위는 등반 가능)
##   - 이 스크립트는 '비주얼 그라데이션'만 담당한다: 닿은 지점들을 셰이더에 누적해
##     PaintOverlay(ColorRect)에 자기색→회색 방사형 그라데이션을 그린다.
##   → 두 책임을 분리해 기존 시스템을 건드리지 않고 안전하게 확장.

# 셰이더 배열 최대 크기 (gray_slope_paint.gdshader 의 MAX_POINTS 와 반드시 일치)
const MAX_POINTS: int = 32

# player.gd 가 get("color_state") 로 직접 읽는다 → 이름 절대 불변. 회색 경사로는 항상 GRAY.
@export_enum("GRAY:2") var color_state: int = ColorDefs.GRAY

# 회색 지형 레이어 비트 (project.godot layer_4 = platform_gray)
const LAYER_GRAY: int = 1 << 3

# 셰이더에 넘길 누적 버퍼 (항상 MAX_POINTS 길이로 패딩해 전달)
var _points: PackedVector2Array = PackedVector2Array()
var _colors: PackedFloat32Array = PackedFloat32Array()

@onready var _overlay: ColorRect = $PaintOverlay

## 버퍼는 인스턴스화 시점(_ready 보다 먼저)에 미리 잡아둔다.
## → reset_paint/paint_at 가 어떤 시점에 호출돼도 'Out of bounds' 가 나지 않게 견고화.
func _init() -> void:
	_points.resize(MAX_POINTS)   # 셰이더 vec2[32] 와 길이 일치
	_colors.resize(MAX_POINTS)   # 셰이더 float[32] 와 길이 일치

func _ready() -> void:
	# 회색 지형 충돌 레이어 설정 (자기 색 레이어에만 존재, 마스크 없음)
	collision_layer = LAYER_GRAY
	collision_mask = 0
	# 총알(bullet.gd)이 회색 경사로를 식별해 paint_at() 을 호출하도록 그룹 등록
	add_to_group("gray_slopes")
	_push_to_shader(0)

## bullet.gd 가 회색 경사로에 총알이 닿을 때 호출.
## world_pos : 충돌 지점(월드 좌표)
## color     : 페인트 색 (0=검정, 1=흰색) = 플레이어 색
func paint_at(world_pos: Vector2, color: int) -> void:
	if _overlay == null:
		return
	# 월드 좌표 → 경사로 로컬 좌표(=오버레이 ColorRect 로컬 픽셀). 경사로 원점=좌상단 가정.
	var local_px: Vector2 = to_local(world_pos)
	# 현재 칠해진 개수 (다음에 채울 슬롯). MAX_POINTS 초과 시 가장 오래된 것부터 덮어씀(링버퍼).
	var count: int = _shader_count()
	var slot: int = count if count < MAX_POINTS else (count % MAX_POINTS)
	_points[slot] = local_px
	_colors[slot] = float(color)
	_push_to_shader(min(count + 1, MAX_POINTS))

## 칠한 페인트를 모두 지운다(리스폰 시 player.gd 가 호출). 그라데이션 초기화.
func reset_paint() -> void:
	for i in MAX_POINTS:
		_points[i] = Vector2.ZERO
		_colors[i] = 0.0
	_push_to_shader(0)

# ── 내부 헬퍼 ──────────────────────────────────────────────────────────
## 셰이더 머티리얼에 현재 버퍼와 개수를 전달.
func _push_to_shader(count: int) -> void:
	if _overlay == null:
		return
	var mat := _overlay.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("point_count", count)
	mat.set_shader_parameter("points", _points)
	mat.set_shader_parameter("colors", _colors)
	# 오버레이 실제 픽셀 크기를 셰이더에 알려 UV→픽셀 변환을 정확히 맞춤
	mat.set_shader_parameter("rect_size", _overlay.size)

## 현재 셰이더에 설정된 점 개수를 읽어온다(없으면 0).
func _shader_count() -> int:
	if _overlay == null:
		return 0
	var mat := _overlay.material as ShaderMaterial
	if mat == null:
		return 0
	var v = mat.get_shader_parameter("point_count")
	return int(v) if v != null else 0
