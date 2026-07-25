extends Node2D
## ============================================================================
## [프로토타입] 테스트_월드_24x24 — 작은 타일(24px) + 셰이더 물감 마스크 실험.
## ----------------------------------------------------------------------------
## ink_spread.gdshader 의 씨앗(seed) 개념을 "플랫폼 하나의 로컬 UV"가 아니라
## 이 씬의 TileMapLayer 전체 "월드 좌표" 기준으로 확장해서 쓴다.
## 바닥 여러 군데가 흑/백 섞여서 칠해질 수 있어야 하므로, 씨앗마다 자기 색을 따로 가진다.
##
## 판정(어디에 뭘 칠했는지)은 이 스크립트가 CPU 에서 소유하고, 셰이더는 그 결과를
## "번지는 모양"으로 보여주기만 한다 (paint_platform.gd 와 같은 원칙).
##
## ⚠ TileMapLayer 의 material 에 셰이더가 아직 연결 안 됐으면 경고만 찍고 계속 진행한다
##   (3단계에서 셰이더를 만들고 4단계에서 에디터로 연결하기 전까지는 정상 상태).
## ============================================================================

const MAX_SEEDS := 64           ## 셰이더 유니폼 배열 상한. 넘으면 가장 오래된 씨앗부터 밀려남
const 번짐_속도: float = 90.0    ## 씨앗 반지름이 커지는 속도 (px/s)
const 목표_반지름: float = 33.0  ## 다 자랐을 때의 최종 반지름 (px) — 기존 55에서 40% 축소

const 총알_스크립트 := preload("res://scenes/world_1/테스트_총알.gd")

@onready var _타일맵: TileMapLayer = $TileMapLayer
@onready var _player: Node2D = get_node_or_null("Player")

var _mat: ShaderMaterial

var _pos: Array[Vector2] = []
var _rad: Array[float] = []
var _col: Array[int] = []       ## 0=검정, 1=흰색 (ColorDefs 값과 동일)

func _ready() -> void:
	_mat = _타일맵.material as ShaderMaterial
	if _mat == null:
		push_warning("테스트_월드_24x24: TileMapLayer 에 ShaderMaterial 이 없음 — 셰이더를 먼저 연결할 것")
	else:
		_mat.set_shader_parameter("max_r", 목표_반지름)   # 셰이더의 젖은 하이라이트 계산이 이 값을 참조함
	if _player == null:
		push_warning("테스트_월드_24x24: 'Player' 자식 노드를 못 찾음 — 총알 발사 지점을 잡을 수 없음")
	else:
		# Player.tscn 내장 Gun 은 "shoot"(좌클릭) 을 감시해 진짜 Bullet.tscn 을 같이 쏜다.
		# Player.tscn 파일은 무수정 원칙이라 여기서 런타임에만 꺼둔다 (zone_lab.gd 와 동일 방식).
		var gun := _player.get_node_or_null("Gun")
		if gun:
			gun.set_process(false)

## [5단계 · 테스트 입력] 왼쪽 클릭=검정, 오른쪽 클릭=흰색 총알 발사.
## ⚠ 마우스는 "방향"만 정한다 — 실제 명중은 총알이 타일에 부딪힌 지점에서 일어난다(테스트_총알.gd).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_발사(ColorDefs.BLACK)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_발사(ColorDefs.WHITE)

const 발사_높이_오프셋 := Vector2(0, -70)   ## Player.tscn 의 Gun 위치와 동일 — 원점(발밑)이 아니라 머리~몸 사이에서 발사

func _발사(색: int) -> void:
	if _player == null:
		return
	var 시작점: Vector2 = _player.global_position + 발사_높이_오프셋
	var 방향 := get_global_mouse_position() - 시작점
	if 방향.length() < 1.0:
		return
	var 총알 := CharacterBody2D.new()
	총알.set_script(총알_스크립트)
	총알.global_position = 시작점
	var 모양 := CollisionShape2D.new()
	var 원 := CircleShape2D.new()
	원.radius = 4.0
	모양.shape = 원
	총알.add_child(모양)
	add_child(총알)
	총알.add_collision_exception_with(_player)   # 스폰 위치가 플레이어 몸 안이라 자기 자신은 무시
	총알.시작(방향, 색, self)

## 명중 지점 기록. 상한을 넘으면 가장 오래된 씨앗을 밀어낸다 (ink_spread.gdshader 와 동일한 정책).
func 명중(world_pos: Vector2, color: int) -> void:
	if _pos.size() >= MAX_SEEDS:
		_pos.pop_front()
		_rad.pop_front()
		_col.pop_front()
	_pos.append(world_pos)
	_rad.append(0.0)
	_col.append(color)
	_유니폼_갱신()

func _process(delta: float) -> void:
	if _rad.is_empty() or _mat == null:
		return
	var 자라는_중 := false
	for i in _rad.size():
		if _rad[i] < 목표_반지름:
			_rad[i] = minf(_rad[i] + 번짐_속도 * delta, 목표_반지름)
			자라는_중 = true
	if 자라는_중:
		_유니폼_갱신()

func _유니폼_갱신() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("seed_count", _pos.size())
	_mat.set_shader_parameter("seeds", PackedVector2Array(_pos))
	_mat.set_shader_parameter("seed_r", PackedFloat32Array(_rad))
	_mat.set_shader_parameter("seed_color", PackedInt32Array(_col))
