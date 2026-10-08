@tool
extends Node2D
## 색칠 대신 반사면의 법선을 바꿔 길을 여는 가구. 위치/회전은 빛 경로가 매 물리 프레임 읽는다.
@export_range(-180, 180) var 법선각: float = -15.0
@export var 반길이: float = 72.0
var _눌림 := false
var _가까움 := false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
		_가까움 = p != null and p.global_position.distance_to(global_position + Vector2(0, 50)) < 145.0
		var left := Input.is_physical_key_pressed(KEY_Q)
		var right := Input.is_physical_key_pressed(KEY_R)
		if _가까움 and (left or right) and not _눌림:
			법선각 = wrapf(법선각 + (15.0 if right else -15.0), -180.0, 180.0)
		_눌림 = left or right
	queue_redraw()

func 법선() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(법선각) + global_rotation)

func 끝점들() -> PackedVector2Array:
	var t := 법선().orthogonal() * 반길이
	return PackedVector2Array([global_position - t, global_position + t])

func _draw() -> void:
	# 받침대는 입체 가구로, 반사면은 법선에 수직으로 그려 물리 계산과 그림을 일치시킨다.
	draw_colored_polygon(PackedVector2Array([Vector2(-38, 68), Vector2(26, 68), Vector2(40, 78), Vector2(-24, 78)]), Color(0.25, 0.24, 0.22))
	draw_line(Vector2(0, 60), Vector2.ZERO, Color(0.25, 0.23, 0.2), 10, true)
	var t := Vector2.RIGHT.rotated(deg_to_rad(법선각)).orthogonal() * 반길이
	draw_line(-t, t, Color(0.09, 0.08, 0.07), 17, true)
	draw_line(-t, t, Color(0.65, 0.64, 0.61), 10, true)
	draw_line(-t * 0.88, t * 0.88, Color(0.94, 0.97, 1), 4, true)
	if _가까움 or Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-92, -100), "Q / R  거울 회전", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
