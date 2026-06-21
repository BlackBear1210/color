extends SceneTree
## ▼ 2026-06-22 (검증용) silhouette→bake 로 만든 Arch 씬의 물리레이어 확인.
##   기대: _test_sheet_01_B → layer 2(BLACK), _test_sheet_02_W → layer 4(WHITE)
const DIR := "res://scenes/지형파일셋/실루엣/"
var _nodes := []
var _checked := false
func _initialize() -> void:
	for nm in ["_test_sheet_01_B", "_test_sheet_02_W"]:
		var ps: PackedScene = load(DIR + nm + ".tscn")
		if ps == null:
			print("FAIL 로드: ", nm); continue
		var inst := ps.instantiate()
		get_root().add_child(inst)
		_nodes.append([nm, inst])
func _process(_d: float) -> bool:
	if _checked: return true
	_checked = true
	var fail := 0
	for pair in _nodes:
		var lyr: int = pair[1].collision_layer
		var cs = pair[1].get("color_state")
		print(pair[0], " collision_layer=", lyr, " color_state=", cs)
		if pair[0].ends_with("_B") and lyr != 2: fail += 1
		if pair[0].ends_with("_W") and lyr != 4: fail += 1
	if _nodes.size() != 2: fail += 1
	print("BAKED_LAYER_CHECK => ", "OK" if fail == 0 else "FAIL")
	quit(fail)
	return true
