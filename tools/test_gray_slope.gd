extends SceneTree
## ▼ 2026-06-21 (작업 W-C 검증용 임시 스크립트) 회색 경사로 paint_at/reset_paint 기능 테스트.
##   실행: Godot --headless --path . -s res://tools/test_gray_slope.gd
##   _ready() 가 실행되도록 노드를 추가한 뒤 '한 프레임 지나고' 검증한다.
##   검증 끝나면 삭제해도 됨.

var _slope: Node
var _checked := false

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/지형파일셋/회색경사로/GrayGradientSlope.tscn")
	if ps == null:
		print("FAIL: 씬 로드 실패")
		quit(1)
		return
	_slope = ps.instantiate()
	get_root().add_child(_slope)
	# 여기서 바로 검증하면 _ready 가 아직 안 돌았으므로, _process(첫 프레임)에서 검증한다.

func _process(_delta: float) -> bool:
	if _checked:
		return true
	_checked = true

	print("color_state = ", _slope.get("color_state"), "  (기대: 2)")
	print("in gray_slopes group = ", _slope.is_in_group("gray_slopes"), "  (기대: true)")
	print("collision_layer = ", _slope.collision_layer, "  (기대: 8)")

	var overlay := _slope.get_node("PaintOverlay")
	var mat := overlay.material as ShaderMaterial

	_slope.paint_at(_slope.to_global(Vector2(256, 128)), ColorDefs.BLACK)
	print("paint 후 point_count = ", mat.get_shader_parameter("point_count"), "  (기대: 1)")

	_slope.paint_at(_slope.to_global(Vector2(400, 60)), ColorDefs.WHITE)
	print("paint x2 후 point_count = ", mat.get_shader_parameter("point_count"), "  (기대: 2)")

	_slope.reset_paint()
	print("reset 후 point_count = ", mat.get_shader_parameter("point_count"), "  (기대: 0)")

	print("TEST_DONE")
	quit(0)
	return true
