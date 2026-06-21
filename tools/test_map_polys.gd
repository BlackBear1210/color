extends SceneTree
## ▼ 2026-06-21 (작업 W-D 검증용) 맵폴리 씬들이 '직속 CollisionPolygon2D 1개'인지 + 레이어 확인.
##   실행: Godot --headless --path . -s res://tools/test_map_polys.gd

const ROOT := "res://scenes/지형파일셋/맵폴리/"

var _nodes := []
var _checked := false

func _initialize() -> void:
	for sub in ["map1", "map2", "map3"]:
		var d := DirAccess.open(ROOT + sub)
		if d == null: continue
		for f in d.get_files():
			if not f.ends_with(".tscn"): continue
			var ps: PackedScene = load(ROOT + sub + "/" + f)
			if ps == null:
				print("FAIL 로드: ", f); continue
			var inst := ps.instantiate()
			get_root().add_child(inst)
			_nodes.append([sub + "/" + f, inst])

func _process(_d: float) -> bool:
	if _checked: return true
	_checked = true
	var total := 0
	var fail := 0
	var multi := 0
	for pair in _nodes:
		total += 1
		var inst: Node = pair[1]
		# 직속 CollisionPolygon2D 개수
		var n := 0
		for c in inst.get_children():
			if c is CollisionPolygon2D: n += 1
		if n != 1:
			multi += 1; fail += 1
			print("조각/누락: ", pair[0], " (직속 CollisionPolygon2D=", n, ")")
		# 색 지형이면 layer 가 0/1(player) 이 아닌 색 레이어여야
		var lyr: int = inst.collision_layer
		if lyr != (1<<1) and lyr != (1<<2) and lyr != (1<<8):
			fail += 1
			print("레이어 이상: ", pair[0], " layer=", lyr)
	print("총 %d개, 폴리곤단일위반 %d, 실패 %d" % [total, multi, fail])
	print("MAP_POLYS_TEST_DONE  => ", "OK" if fail == 0 else "FAIL")
	quit(fail)
	return true
