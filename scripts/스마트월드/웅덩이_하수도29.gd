@tool
extends "res://scripts/스마트월드/웅덩이_흰물v2.gd"
## 2-9의 넓고 얕은 물이 발판처럼 보이지 않도록 외관만 별도 재질로 바꾼다.
## 기존 색 판정, 수심, 낙하 받기, 침수 마감은 부모의 동작을 그대로 쓴다.
## 안개처럼 보이던 넓은 얼룩은 약하게 하고 얇고 끊긴 가로 반사를 쓴다.
## 물 밖의 벽돌에는 투명한 젖은 띠만 겹쳐 원래 줄눈과 색칠 상태가 보이게 한다.
const SEWER_SURFACE = preload("res://shaders/sewer_pool_29.gdshader")
var _잔물결: Array[Vector3] = []
var _물속 := false
var _마지막발 := Vector2.ZERO
var _수면시간 := 0.0
var _수면대기 := 0.0
## [2026-09-30] 입수 물보라(월드 좌표 · 물 자기 색) — 하나를 만들어 두고 입수 때마다 터뜨린다.
var _물보라: Node2D
var _이전발_y := 0.0

func _ready() -> void:
	super._ready()
	# 부모가 만든 인스턴스별 재질을 바꿔 다른 스테이지의 물에는 영향을 주지 않는다.
	var surface := _white_visual.material as ShaderMaterial
	# 부모가 새 하수도 재질을 골랐다면 구형 재질로 덮지 않는다.
	if _white_visual.get("웅덩이_전용셰이더") == null:
		_white_visual.set("웅덩이_전용셰이더", SEWER_SURFACE)
		surface.shader = SEWER_SURFACE
	_white_visual.call("_갱신")
	# 물이 캐릭터 뒤에 그려지면 발이 전부 보여 판 위에 선 것처럼 보인다. 얕은 물 영역만 앞에 둔다.
	_white_visual.z_index = 2
	surface.set_shader_parameter("stage5_surface", true)
	if not Engine.is_editor_hint():
		_물보라 = preload("res://scripts/스마트월드/하수도_입수물보라.gd").new()
		_물보라.name = "입수물보라"
		add_child(_물보라)

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or not is_instance_valid(_white_visual):
		return
	_수면시간 += delta
	_수면대기 -= delta
	if _수면대기 > 0.0:
		return
	_수면대기 = 1.0 / 30.0
	# 실제 발 위치로만 입수/보행 잔물결을 만든다. 리스폰·순간이동에는 길게 이어진 자국을 남기지 않는다.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var foot := to_local(player.global_position)
		var right := 크기.x * 0.5 - 오른쪽_안쪽폭 * clampf((foot.y + 크기.y) / 크기.y, 0.0, 1.0)
		var inside := 켜짐 and foot.x >= -크기.x * 0.5 and foot.x <= right and foot.y >= -크기.y and foot.y <= 8.0
		var travel := foot.distance_to(_마지막발)
		if inside and (not _물속 or travel >= 22.0):
			if travel > 180.0:
				_잔물결.clear()
			# 입수 잔물결은 걷기(0.65)보다 크게(1.0 → 1.6) — 셰이더에서 고리가 더 진하고 넓게 보인다.
			_잔물결.append(Vector3(foot.x + 크기.x * 0.5, _수면시간, 1.6 if not _물속 else 0.65))
			# 입수 순간에만 물보라. 떨어진 속도(최근 0.033 초 동안 내려온 거리)로 세기를 정한다.
			if not _물속 and travel <= 180.0 and is_instance_valid(_물보라):
				var 낙하 := maxf(0.0, foot.y - _이전발_y)
				var 세기 := clampf(낙하 / 20.0, 0.25, 1.0)
				_물보라.call("터뜨리기", player.global_position, global_position.y - 크기.y, int(색), 세기)
				get_tree().call_group("하수도_소리", "입수", 세기)
			_마지막발 = foot
		if not inside:
			_마지막발 = foot
		_이전발_y = foot.y
		_물속 = inside
	if not 켜짐:
		_잔물결.clear()
	while not _잔물결.is_empty() and (_수면시간 - _잔물결[0].y > 1.2 or _잔물결.size() > 6):
		_잔물결.pop_front()
	var waves := PackedVector3Array()
	for wave in _잔물결:
		waves.append(Vector3(wave.x, _수면시간 - wave.y, wave.z))
	var count := waves.size()
	waves.resize(6)
	var material := _white_visual.material as ShaderMaterial
	material.set_shader_parameter("step_waves", waves)
	material.set_shader_parameter("step_wave_count", count)

func _draw() -> void:
	if not 켜짐:
		return
	# 매립 수로의 양쪽 벽과 밑바닥에만 그린다. 수면 위와 판정 공간은 늘리지 않는다.
	var half := 크기.x * 0.5
	var inset := minf(오른쪽_안쪽폭, 크기.x * 0.75)
	_젖은_띠(Vector2(-half, -크기.y), Vector2(-half, 0.0), Vector2.LEFT, 0.0)
	_젖은_띠(Vector2(half, -크기.y), Vector2(half - inset, 0.0), Vector2.RIGHT, 1.7)
	_젖은_띠(Vector2(-half, 0.0), Vector2(half - inset, 0.0), Vector2.DOWN, 3.1)

func _젖은_띠(start: Vector2, end: Vector2, outward: Vector2, seed: float) -> void:
	# 경계로부터 2~6px 안에서만 불규칙하게 번져 직선 테두리나 검은 프레임을 피한다.
	var steps := maxi(2, int(ceil(start.distance_to(end) / 8.0)))
	var strip := PackedVector2Array([start, end])
	for i in range(steps, -1, -1):
		var along := start.lerp(end, float(i) / float(steps))
		var distance := start.distance_to(along)
		var width := 3.5 + sin(distance * 0.19 + seed) * 1.3 + sin(distance * 0.47) * 0.7
		strip.append(along + outward * width)
	draw_colored_polygon(strip, Color(0.025, 0.025, 0.025, 0.23))
