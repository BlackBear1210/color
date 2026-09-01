@tool
extends Node2D
## ============================================================================
## SS2D 스테이지 편집용 점프 범위 표시기
## ----------------------------------------------------------------------------
## Player의 실제 튜닝값과 CollisionPolygon2D를 읽어, 2D 워크스페이스에
## 일반 점프와 코요테 점프의 궤적·착지 몸통을 함께 그린다.
## 런타임에는 보이지 않는다. 맵 제작자가 "그림 크기"가 아닌 물리 몸통 기준으로
## 발판 간격을 판단할 수 있게 두는 에디터 전용 보조선이다.
## ============================================================================

const 낙하_기본배수: float = 2.4
const 코요테_시간: float = 0.12

@export var 표시: bool = true:
	set(value):
		표시 = value
		queue_redraw()
@export var 플레이어_경로: NodePath = NodePath("../Player")


func _ready() -> void:
	# 게임 화면에 제작 보조선이 섞이면 안 되므로 에디터에서만 보인다.
	visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(_delta: float) -> void:
	# Player 위치·점프 Inspector 값이 바뀐 즉시 선도 따라가야 한다.
	queue_redraw()


func _draw() -> void:
	if not 표시:
		return
	var player := get_node_or_null(플레이어_경로) as CharacterBody2D
	if player == null:
		return

	var data := _점프값(player)
	var origin := to_local(player.global_position)
	var normal_time: float = data["상승시간"] + data["일반_하강시간"]
	var coyote_time: float = 코요테_시간 + data["상승시간"] + data["코요테_하강시간"]

	# 노랑 실선 = 발판을 밟은 순간 누르는 일반 점프.
	for direction in [-1.0, 1.0]:
		_궤적_그리기(origin, data, direction, normal_time, false,
			Color(1.0, 0.82, 0.22, 0.95), 3.0)
		var landing := origin + Vector2(direction * data["일반_가로거리"], 0.0)
		_몸통_그리기(player, landing - origin, Color(1.0, 0.82, 0.22, 0.9))

	# 청록 점선 = 절벽을 벗어난 뒤 0.12초 안에 누르는 코요테 점프.
	for direction in [-1.0, 1.0]:
		_궤적_그리기(origin, data, direction, coyote_time, true,
			Color(0.20, 0.88, 1.0, 0.9), 2.5)
		var coyote_apex := origin + Vector2(direction * data["속도"] * (코요테_시간 + data["상승시간"]),
			data["코요테_낙하거리"] - data["높이"])
		_몸통_그리기(player, coyote_apex - origin, Color(0.20, 0.88, 1.0, 0.75))
		var landing := origin + Vector2(direction * data["코요테_가로거리"], 0.0)
		_몸통_그리기(player, landing - origin, Color(0.20, 0.88, 1.0, 0.75))

	# 세로 최대치는 코요테를 쓰지 않은 점프가 더 높다.
	var apex := origin + Vector2(0.0, -data["높이"])
	draw_line(origin, apex, Color(1.0, 0.82, 0.22, 0.82), 2.0, true)
	draw_circle(apex, 5.0, Color(1.0, 0.82, 0.22, 0.95))
	_몸통_그리기(player, apex - origin, Color(1.0, 0.82, 0.22, 0.9))
	_글자(apex + Vector2(14.0, -10.0), "세로: %dpx / %.1f칸" % [
		int(round(data["높이"])), data["높이"] / data["타일크기"]], Color(1.0, 0.88, 0.46, 1.0))
	_글자(origin + Vector2(14.0, 24.0), "일반: %dpx / %.1f칸" % [
		int(round(data["일반_가로거리"])), data["일반_가로거리"] / data["타일크기"]],
		Color(1.0, 0.88, 0.46, 1.0))
	_글자(origin + Vector2(14.0, 46.0), "코요테: %dpx / %.1f칸" % [
		int(round(data["코요테_가로거리"])), data["코요테_가로거리"] / data["타일크기"]],
		Color(0.35, 0.92, 1.0, 1.0))
	_몸통_그리기(player, Vector2.ZERO, Color(1.0, 1.0, 1.0, 0.9))


func _점프값(player: CharacterBody2D) -> Dictionary:
	var tile_size: float = float(player.get("타일_크기"))
	var height: float = float(player.get("점프_높이_칸")) * tile_size
	var configured_distance: float = float(player.get("점프_거리_칸")) * tile_size
	var speed: float = float(player.get("move_speed"))
	var rise_mult: float = float(player.get("상승_배수"))
	var fall_gain: float = float(player.get("낙하_가속_증가율"))
	var fall_cap: float = float(player.get("낙하_최대_배수"))

	# player.gd의 `_점프_재계산()` 공식과 같은 식을 쓴다.
	# 따로 수치를 복사하면 플레이어 튜닝을 바꾼 뒤 보조선만 옛날 값으로 남는다.
	var k := 1.0 / sqrt(rise_mult) + 1.0 / sqrt(낙하_기본배수)
	var gravity := 2.0 * height * speed * speed * k * k / maxf(configured_distance * configured_distance, 0.0001)
	var jump_velocity := -sqrt(2.0 * gravity * rise_mult * height)
	var rise_time := -jump_velocity / (gravity * rise_mult)
	var normal_descent := _낙하시간(height, 0.0, gravity, fall_gain, fall_cap)

	# 코요테 중에는 먼저 떨어진 거리와 누적된 낙하 타이머를 그대로 갖고 점프한다.
	# player.gd가 공중 점프 시 `_fall_timer`를 초기화하지 않는 실제 동작까지 반영한다.
	var coyote_drop := _낙하거리(코요테_시간, 0.0, gravity, fall_gain, fall_cap)
	var coyote_descent := _낙하시간(height - coyote_drop, 코요테_시간,
		gravity, fall_gain, fall_cap)
	return {
		"타일크기": tile_size,
		"높이": height,
		"속도": speed,
		"중력": gravity,
		"낙하_증가": fall_gain,
		"낙하_상한": fall_cap,
		"상승시간": rise_time,
		"일반_하강시간": normal_descent,
		"코요테_하강시간": coyote_descent,
		"코요테_낙하거리": coyote_drop,
		"일반_가로거리": speed * (rise_time + normal_descent),
		"코요테_가로거리": speed * (코요테_시간 + rise_time + coyote_descent),
	}


func _낙하시간(target_distance: float, timer_start: float, gravity: float,
		fall_gain: float, fall_cap: float) -> float:
	# 수치 이분법: 낙하 가속·상한이 있어도 목표 높이에 닿는 시간을 안정적으로 찾는다.
	var low := 0.0
	var high := 3.0
	for _i in 32:
		var mid := (low + high) * 0.5
		if _낙하거리(mid, timer_start, gravity, fall_gain, fall_cap) < target_distance:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


func _낙하거리(time: float, timer_start: float, gravity: float,
		fall_gain: float, fall_cap: float) -> float:
	if fall_gain <= 0.0001:
		return gravity * 낙하_기본배수 * time * time * 0.5
	var cap_time := maxf((fall_cap - 낙하_기본배수) / fall_gain - timer_start, 0.0)
	var initial_mult := 낙하_기본배수 + fall_gain * timer_start
	if time <= cap_time:
		return gravity * (initial_mult * time * time * 0.5 + fall_gain * time * time * time / 6.0)
	var distance_at_cap := gravity * (initial_mult * cap_time * cap_time * 0.5
		+ fall_gain * cap_time * cap_time * cap_time / 6.0)
	var velocity_at_cap := gravity * (initial_mult * cap_time + fall_gain * cap_time * cap_time * 0.5)
	var after_cap := time - cap_time
	return distance_at_cap + velocity_at_cap * after_cap + gravity * fall_cap * after_cap * after_cap * 0.5


func _궤적_그리기(origin: Vector2, data: Dictionary, direction: float,
		total_time: float, coyote: bool, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var time := total_time * float(i) / 32.0
		var offset := _궤적_좌표(time, data, coyote)
		offset.x *= direction
		points.append(origin + offset)
	if coyote:
		_점선_그리기(points, color, width)
	else:
		draw_polyline(points, color, width, true)


func _궤적_좌표(time: float, data: Dictionary, coyote: bool) -> Vector2:
	var speed: float = data["속도"]
	var rise_time: float = data["상승시간"]
	var gravity: float = data["중력"]
	# Dictionary에서 꺼낸 값은 Variant라 명시적으로 float로 바꾼다.
	# 안 그러면 @tool 스크립트가 에디터 파싱 단계에서 타입을 추론하지 못한다.
	var rise_mult: float = (2.0 * float(data["높이"])) / (gravity * rise_time * rise_time)
	var jump_velocity: float = -gravity * rise_mult * rise_time
	var drop_before_jump: float = float(data["코요테_낙하거리"]) if coyote else 0.0
	var timer_before_jump: float = 코요테_시간 if coyote else 0.0
	var jump_time: float = time
	if coyote and time <= 코요테_시간:
		return Vector2(speed * time, _낙하거리(time, 0.0, gravity,
			float(data.get("낙하_증가", 0.0)), float(data.get("낙하_상한", 낙하_기본배수))))
	if coyote:
		jump_time -= 코요테_시간
	if jump_time <= rise_time:
		return Vector2(speed * time, drop_before_jump + jump_velocity * jump_time
			+ gravity * rise_mult * jump_time * jump_time * 0.5)
	return Vector2(speed * time, drop_before_jump - data["높이"]
		+ _낙하거리(jump_time - rise_time, timer_before_jump, gravity,
			float(data.get("낙하_증가", 0.0)), float(data.get("낙하_상한", 낙하_기본배수))))


func _점선_그리기(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(1, points.size()):
		if i % 2 == 1:
			draw_line(points[i - 1], points[i], color, width, true)


func _몸통_그리기(player: CharacterBody2D, offset: Vector2, color: Color) -> void:
	var polygon := player.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if polygon == null or polygon.polygon.size() < 3:
		return
	var points := PackedVector2Array()
	for point in polygon.polygon:
		points.append(to_local(polygon.to_global(point)) + offset)
	points.append(points[0])
	draw_polyline(points, color, 1.8, true)


func _글자(position: Vector2, text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
