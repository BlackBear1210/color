extends Camera2D

@export var target: Node2D

# 데드존 크기
@export var dead_zone_size: Vector2 = Vector2(400.0, 250.0)

# 카메라 부드러움 정도
# 값이 클수록 빠르게 따라감
@export var smooth_speed: float = 8.0

# 디버그 데드존 표시 여부
@export var show_debug_dead_zone: bool = true

# 디버그 선 색상
@export var debug_color: Color = Color(0.0, 1.0, 0.0, 0.8)

# 디버그 선 두께
@export var debug_line_width: float = 2.0

@export var zoom_level: Vector2 = Vector2(2.0, 2.0)

var desired_position: Vector2
var initial_position: Vector2


func _ready() -> void:
	add_to_group("camera")
	zoom = zoom_level
	if target == null:
		push_warning("DeadZoneCamera: target이 설정되지 않았습니다.")

	initial_position = global_position
	desired_position = global_position
	make_current()


func snap_to_initial() -> void:
	desired_position = initial_position
	global_position = initial_position


func _process(delta: float) -> void:
	if target == null:
		return

	update_camera_target_position()
	apply_smooth_movement(delta)
	
	if show_debug_dead_zone:
		queue_redraw()


func update_camera_target_position() -> void:
	var target_pos: Vector2 = target.global_position
	var camera_pos: Vector2 = desired_position
	
	var half_zone: Vector2 = dead_zone_size * 0.5
	
	var left_limit: float = camera_pos.x - half_zone.x
	var right_limit: float = camera_pos.x + half_zone.x
	var top_limit: float = camera_pos.y - half_zone.y
	var bottom_limit: float = camera_pos.y + half_zone.y
	
	# 플레이어가 왼쪽 경계를 벗어나려 할 때
	if target_pos.x < left_limit:
		desired_position.x = target_pos.x + half_zone.x
	
	# 플레이어가 오른쪽 경계를 벗어나려 할 때
	elif target_pos.x > right_limit:
		desired_position.x = target_pos.x - half_zone.x
	
	# 플레이어가 위쪽 경계를 벗어나려 할 때
	if target_pos.y < top_limit:
		desired_position.y = target_pos.y + half_zone.y
	
	# 플레이어가 아래쪽 경계를 벗어나려 할 때
	elif target_pos.y > bottom_limit:
		desired_position.y = target_pos.y - half_zone.y


func apply_smooth_movement(delta: float) -> void:
	var weight: float = 1.0 - exp(-smooth_speed * delta)
	global_position = global_position.lerp(desired_position, weight)


func _draw() -> void:
	if not show_debug_dead_zone:
		return
	
	var half_zone: Vector2 = dead_zone_size * 0.5
	
	var rect := Rect2(
		-half_zone,
		dead_zone_size
	)
	
	draw_rect(rect, debug_color, false, debug_line_width)
