extends Control
## 월드 위/HUD 아래 전용 화면 효과. 입력을 받지 않으며 카메라 줌과 색 판정은 유지한다.
@export_range(0.0, 0.2) var 비네트_강도: float = 0.075
@export_range(0.0, 0.03) var 입자_강도: float = 0.012
@export var 전경_파티클: bool = true
@export var 입수_물방울: bool = true
var _시간: float = 0.0
var _이전발: Vector2
var _초기화됨: bool = false
var _입수중: bool = false
var _쿨다운: float = 0.0
var _물방울: Array[Dictionary] = []
var _난수 := RandomNumberGenerator.new()
var _막: ColorRect
var _재질: ShaderMaterial
var _재그림: float = 0.0

func _ready() -> void:
	# 이동 거리만으로는 같은 위치의 리스폰을 알 수 없어 월드의 재시도 알림을 받는다.
	add_to_group("하수도_입수효과")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_난수.randomize()
	_막 = ColorRect.new()
	_막.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_재질 = ShaderMaterial.new()
	_재질.shader = preload("res://shaders/sewer_camera_v2.gdshader")
	_막.material = _재질
	add_child(_막)
	get_viewport().size_changed.connect(_크기_맞추기)
	_크기_맞추기()

func _크기_맞추기() -> void:
	size = get_viewport_rect().size
	_막.size = size

func _physics_process(delta: float) -> void:
	_쿨다운 = maxf(0.0, _쿨다운 - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		입수_초기화()
		return
	var foot := player.global_position
	var inside := false
	var tone := 2
	# 발이 수면에 들어오는 순간을 검사한다. 머리 접촉/물 안 걷기로 중복 재생하지 않는다.
	for pool in get_tree().get_nodes_in_group("웅덩이"):
		if not pool.get("켜짐"):
			continue
		var local: Vector2 = pool.to_local(foot)
		var extent: Vector2 = pool.get("크기")
		var inset: float = float(pool.get("오른쪽_안쪽폭")) if "오른쪽_안쪽폭" in pool else 0.0
		var right := extent.x * 0.5 - inset * clampf((local.y + extent.y) / extent.y, 0.0, 1.0)
		if local.x >= -extent.x * 0.5 and local.x <= right and local.y >= -extent.y and local.y <= 2.0:
			inside = true
			tone = int(pool.get("색"))
			break
	# 리스폰/텔레포트 및 최초 스폰은 렌즈에 물이 튀는 사건으로 취급하지 않는다.
	if _초기화됨 and foot.distance_to(_이전발) < 180.0:
		# 얕은 웅덩이에는 옆으로도 들어가므로 하강 여부 대신 실제 이동을 확인한다.
		if inside and not _입수중 and foot.distance_to(_이전발) > 0.1 and _쿨다운 <= 0.0 and 입수_물방울:
			_입수(tone)
	elif _초기화됨:
		_물방울.clear()
	_이전발 = foot
	_입수중 = inside
	_초기화됨 = true

func 입수_초기화() -> void:
	# 사망 직전의 물방울과 쿨다운을 다음 생명으로 넘기지 않는다.
	_물방울.clear()
	_쿨다운 = 0.0
	_입수중 = false
	_초기화됨 = false
	queue_redraw()

func _입수(tone: int) -> void:
	_물방울.clear()
	_쿨다운 = 0.55
	for i in range(_난수.randi_range(3, 5)):
		_물방울.append({"x": _난수.randf_range(0.08, 0.92), "life": _난수.randf_range(0.3, 0.5), "age": 0.0,
			"radius": _난수.randf_range(2.0, 4.0), "rise": _난수.randf_range(16.0, 42.0), "tone": tone})

func _process(delta: float) -> void:
	_시간 += delta
	for drop in _물방울:
		drop["age"] = float(drop["age"]) + delta
	_물방울 = _물방울.filter(func(drop: Dictionary) -> bool: return float(drop["age"]) < float(drop["life"]))
	_재질_갱신()
	_재그림 += delta
	if _재그림 >= 1.0 / 30.0:
		_재그림 = 0.0
		queue_redraw()

func _재질_갱신() -> void:
	_재질.set_shader_parameter("clock", _시간)
	_재질.set_shader_parameter("vignette_strength", 비네트_강도)
	_재질.set_shader_parameter("grain_strength", 입자_강도)

func _draw() -> void:
	var scale_factor := size.y / 1080.0
	if 전경_파티클:
		# 눈/불꽃처럼 보이지 않게 작은 입자 12개만 화면 공간에서 천천히 움직인다.
		for i in range(12):
			var x := fposmod(float(i) * 0.618 + _시간 * (0.001 + i * 0.00004), 1.0) * size.x
			var y := fposmod(float(i) * 0.371 - _시간 * 0.003, 1.0) * size.y
			var radius := (0.7 + float(i % 3) * 0.35) * scale_factor
			draw_circle(Vector2(x, y), radius * 2.0, Color(0.65, 0.65, 0.65, 0.025))
			draw_circle(Vector2(x, y), radius, Color(0.65, 0.65, 0.65, 0.10))
	for drop in _물방울:
		var t := float(drop["age"]) / float(drop["life"])
		var center := Vector2(float(drop["x"]) * size.x, size.y - (5.0 + sin(t * PI) * float(drop["rise"])) * scale_factor)
		var radius := float(drop["radius"]) * scale_factor
		var outline := PackedVector2Array()
		# 동그란 비눗방울 테두리 대신 비대칭으로 찌그러진 작은 물방울 실루엣.
		for i in range(7):
			var angle := float(i) * TAU / 7.0
			outline.append(center + Vector2(cos(angle) * radius * (0.8 + 0.12 * (i % 3)), sin(angle) * radius * 1.5))
		var tone := int(drop["tone"])
		var value := 0.92 if tone == 1 else (0.08 if tone == 0 else 0.52)
		draw_colored_polygon(outline, Color(value, value, value, 0.35 * (1.0 - t)))
