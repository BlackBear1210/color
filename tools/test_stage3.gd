extends SceneTree
## ▼ 2026-06-21 (작업 W-E 검증용) 샘플 stage_3 로드 + 모듈 인스턴스 충돌 레이어 검증.
##   실행: Godot --headless --path . -s res://tools/test_stage3.gd

var _root: Node
var _checked := false

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/world_1/stage_3/stage_3.tscn")
	if ps == null:
		print("FAIL: stage_3 로드 실패"); quit(1); return
	_root = ps.instantiate()
	get_root().add_child(_root)

func _process(_d: float) -> bool:
	if _checked:
		return true
	_checked = true
	var mp := _root.get_node("MapPhysics")
	var floor_a := mp.get_node("Floor_A")
	var gate := mp.get_node("White_Gate")
	var slope := mp.get_node("GrayGradientSlope")
	var fail := 0
	# Floor_A=BLACK(2), White_Gate=WHITE(4), GraySlope=GRAY(8)
	if floor_a.collision_layer != (1 << 1): fail += 1
	if gate.collision_layer != (1 << 2): fail += 1
	if slope.collision_layer != (1 << 3): fail += 1
	print("Floor_A layer = ", floor_a.collision_layer, " (기대 2)")
	print("White_Gate layer = ", gate.collision_layer, " (기대 4)")
	print("GraySlope layer = ", slope.collision_layer, " (기대 8)")
	# DeathDetector 가 death_zones 에 등록됐는지 (사망 판정용)
	var dd := floor_a.get_node_or_null("DeathDetector")
	print("Floor_A DeathDetector death_zones = ", dd != null and dd.is_in_group("death_zones"))
	# Portal/Player 존재
	print("Player 존재 = ", _root.get_node_or_null("Player") != null)
	print("Portal 존재 = ", mp.get_node_or_null("Portal") != null)
	print("STAGE3_TEST_DONE  실패=%d" % fail)
	quit(fail)
	return true
