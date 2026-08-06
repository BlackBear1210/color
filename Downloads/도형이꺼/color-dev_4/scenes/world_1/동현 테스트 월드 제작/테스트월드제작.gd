extends Node2D
## ============================================================================
## [프로토타입] 테스트월드제작 — 5종 재질(brick·grass·rock·soil·wood) 통합 실험.
## ----------------------------------------------------------------------------
## ink_spread_world.gdshader 의 씨앗(seed) 방식을 그대로 쓰되, 시트마다 흑/백
## 배치 축이 다르다는 걸 반영한다:
##   - brick·grass·rock·soil : 가로(행) 기준 — 왼쪽=검정, 오른쪽=흰색
##   - wood                  : 세로(열) 기준 — 위쪽=검정, 아래쪽=흰색
## brick.png 와 wood.png 가 둘 다 768×768 라 텍스처 크기로는 구분이 안 되므로,
## 명중 시점에 CPU 가 "어느 시트에서 맞았는지"(텍스처 파일명)를 직접 확인해서
## 씨앗마다 축(seed_axis)을 같이 기록하고, 셰이더는 그 값만 보고 방향을 정한다.
##
## 발사는 Player.tscn 내장 Gun 의 위치·조준(Muzzle)을 재사용하되, 원래
## gun.gd 의 발사(구형 회색 칠 Bullet)는 런타임에 꺼두고 우리 총알로 대체한다
## (player.gd 무수정 원칙과 같은 방식 — Gun 은 Player 의 자식일 뿐 파일은 안 건드림).
## ============================================================================

const 총알_스크립트 := preload("res://scenes/world_1/테스트_총알.gd")

const MAX_SEEDS := 64
const 번짐_속도: float = 90.0
const 목표_반지름: float = 12.0   ## 1칸(16px) 발판에도 원이 안 잘리도록 발판 두께의 절반으로 설정

@onready var _타일맵: TileMapLayer = $TileMapLayer
@onready var _player: Node2D = get_node_or_null("Player")
@onready var _gun: Node2D = _player.get_node_or_null("Gun") if _player else null
@onready var _muzzle: Marker2D = _gun.get_node_or_null("Muzzle") if _gun else null

var _mat: ShaderMaterial

var _pos: Array[Vector2] = []
var _rad: Array[float] = []
var _col: Array[int] = []
var _axis: Array[int] = []       ## 0=가로 오프셋, 1=세로 오프셋 (wood 전용)

func _ready() -> void:
	_mat = _타일맵.material as ShaderMaterial
	if _mat == null:
		push_warning("테스트월드제작: TileMapLayer 에 ShaderMaterial 이 없음 — 셰이더를 먼저 연결할 것")
	else:
		_mat.set_shader_parameter("max_r", 목표_반지름)

	if _player == null:
		push_warning("테스트월드제작: 'Player' 자식 노드를 못 찾음")
	elif _gun == null or _muzzle == null:
		push_warning("테스트월드제작: Player 안에서 Gun/Muzzle 을 못 찾음 — Player.tscn 구조 확인 필요")
	else:
		# 원래 Gun 의 발사(구형 회색 칠 Bullet)는 꺼둔다 — 조준(look_at)은 우리가 대신 돌려준다.
		_gun.set_process(false)

func _process(delta: float) -> void:
	if _gun and is_instance_valid(_gun):
		_gun.look_at(get_global_mouse_position())

## [테스트 입력] "shoot"(좌클릭, Gun 이 원래 쓰던 액션과 동일) → Muzzle 위치에서 발사.
## 총알 색 = 플레이어의 현재 색 (원래 gun.gd 와 동일한 규칙).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		_발사()

func _발사() -> void:
	if _muzzle == null or _player == null:
		return
	var 색: int = _player.get("player_color")
	var 시작점: Vector2 = _muzzle.global_position
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
	총알.add_collision_exception_with(_player)
	총알.시작(방향, 색, self)

## 명중 지점의 실제 타일이 어느 시트(atlas source)에서 왔는지 확인해 축을 판별한다.
## 텍스처 파일명에 "wood" 가 있으면 세로(1), 그 외(brick·grass·rock·soil)는 가로(0).
func _축_조회(world_pos: Vector2) -> int:
	var cell := _타일맵.local_to_map(_타일맵.to_local(world_pos))
	var source_id := _타일맵.get_cell_source_id(cell)
	if source_id == -1:
		return 0
	var source := _타일맵.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return 0
	return 1 if "wood" in source.texture.resource_path else 0

## 명중 지점 기록. 상한을 넘으면 가장 오래된 씨앗을 밀어낸다.
func 명중(world_pos: Vector2, color: int) -> void:
	if _pos.size() >= MAX_SEEDS:
		_pos.pop_front()
		_rad.pop_front()
		_col.pop_front()
		_axis.pop_front()
	_pos.append(world_pos)
	_rad.append(0.0)
	_col.append(color)
	_axis.append(_축_조회(world_pos))
	_유니폼_갱신()

func _physics_process(delta: float) -> void:
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
	_mat.set_shader_parameter("seed_axis", PackedInt32Array(_axis))
