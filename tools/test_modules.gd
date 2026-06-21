extends SceneTree
## ▼ 2026-06-21 (작업 W-B 검증용) 모듈 10종 로드/구조/색전환 검증.
##   실행: Godot --headless --path . -s res://tools/test_modules.gd

const DIR := "res://scenes/지형파일셋/모듈/"
const NAMES := ["Ground_Flat","Slope_Up","Slope_Down","Platform_Float","Ledge_Edge",
				"Pillar","Ceiling","Step_Small","Gap_Bridge","Curve_Hill"]

var _i := 0
var _fail := 0
var _nodes := []

func _initialize() -> void:
	for n in NAMES:
		var ps: PackedScene = load(DIR + n + ".tscn")
		if ps == null:
			print("FAIL 로드: ", n); _fail += 1; continue
		var inst := ps.instantiate()
		get_root().add_child(inst)
		_nodes.append([n, inst])

func _process(_d: float) -> bool:
	# _ready 가 돈 다음 프레임에 구조 검증
	for pair in _nodes:
		var n: String = pair[0]
		var inst: Node = pair[1]
		var has_col := inst.get_node_or_null("CollisionPolygon2D") != null
		var dd := inst.get_node_or_null("DeathDetector")
		var has_entry := inst.get_node_or_null("SnapPoints/Entry") != null
		var has_exit := inst.get_node_or_null("SnapPoints/Exit") != null
		var dz := dd != null and dd.is_in_group("death_zones")
		# 색 전환 테스트: WHITE 로 바꾸면 collision_layer 가 platform_white(4) 가 되는지
		inst.set("color_state", ColorDefs.WHITE)
		var white_ok: bool = inst.collision_layer == (1 << 2)
		inst.set("color_state", ColorDefs.BLACK)
		var black_ok: bool = inst.collision_layer == (1 << 1)
		var ok: bool = has_col and dz and has_entry and has_exit and white_ok and black_ok
		if not ok:
			_fail += 1
		print("%-16s col=%s death_zone=%s entry=%s exit=%s white=%s black=%s  => %s" % [
			n, has_col, dz, has_entry, has_exit, white_ok, black_ok, "OK" if ok else "FAIL"])
	print("MODULES_TEST_DONE  실패=%d" % _fail)
	quit(_fail)
	return true
