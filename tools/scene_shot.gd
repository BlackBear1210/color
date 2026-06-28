extends SceneTree
## ▼ 2026-06-28 씬 시각 확인(창 모드 렌더 → PNG). 헤드리스로는 화면을 못 봐서 실제 렌더로 확인.
##   실행(창 모드): Godot --path . -s res://tools/scene_shot.gd
##   SCENE 를 바꿔 다른 씬도 촬영 가능.
const SCENE := "res://scenes/world_1/stage_4/stage_4.tscn"
const OUT   := "res://scene_shot_out.png"
var _frame := 0

func _initialize() -> void:
	var ps: PackedScene = load(SCENE)
	if ps == null:
		print("SCENE_SHOT: 씬 로드 실패 ", SCENE); quit(1); return
	var inst := ps.instantiate()
	get_root().add_child(inst)
	print("SCENE_SHOT: 로드한 루트 = ", inst.name, "  scene_file=", inst.scene_file_path)
	var mp := inst.get_node_or_null("MapPhysics")
	if mp: print("  MapPhysics 자식: ", mp.get_children().map(func(c): return c.name))
	var at := inst.get_node_or_null("ArchTerrain")
	if at:
		print("  ArchTerrain 자식: ", at.get_children().map(func(c): return c.name))
		for c in at.get_children():
			var s := c.get_node_or_null("Sprite2D")
			print("    ", c.name, " pos=", c.position, " scale=", c.scale, " visible=", c.visible, " tex=", (s.texture != null if s else "no-spr"))
	else:
		print("  ArchTerrain 없음!")
	var pl := inst.get_node_or_null("Player")
	if pl: print("  Player pos=", pl.position)

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 50:   # 플레이어 안착·카메라 정착 후
		var img := get_root().get_texture().get_image()
		if img:
			img.save_png(OUT)
			print("SCENE_SHOT_DONE 저장: ", OUT, " 크기=", img.get_size())
		else:
			print("SCENE_SHOT: 이미지 없음")
		quit(0)
		return true
	return false
