extends SceneTree
## ▼ 2026-06-28 stage_1: 텍스처에서 '실제 불투명(검정 지형) 픽셀'을 샘플링해 그 위에 페인트를 찍어
##   클립이 지형 모양대로 칠하는지 확정 검증. (충돌좌표 추측이 아니라 텍스처 불투명 위치를 직접 사용)
const PAINT := "res://scenes/effects/PaintMark.tscn"
const OUT   := "res://stage1_paint_out.png"
var _frame := 0
var _done := false

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/world_1/stage_1/stage_1.tscn")
	get_root().add_child(ps.instantiate())

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 6 and not _done:
		_done = true
		var surf: Sprite2D = null
		for n in get_root().get_tree().get_nodes_in_group("paint_surface"):
			surf = n as Sprite2D
			if surf and surf.texture:
				break
		if surf == null:
			print("STAGE1_PAINT: 지형 없음"); quit(1); return true
		var img := surf.texture.get_image()
		var ts := surf.texture.get_size()
		var paint_scene: PackedScene = load(PAINT)
		var placed := 0
		# 화면에 보이는 좌측 구간(텍스처 x 0~1600)에서 불투명 픽셀을 찾아 격자로 페인트
		var gx := 60
		while gx < 1600 and placed < 60:
			var gy := 40
			while gy < int(ts.y):
				if img.get_pixel(gx, gy).a > 0.6:   # 불투명(검정 지형) 픽셀만
					var world: Vector2 = surf.global_transform * Vector2(gx, gy)
					var m := paint_scene.instantiate()
					m.paint_color = 1
					m.impact_direction = Vector2.DOWN
					m.setup_terrain_clip_tex(surf.texture, surf.global_transform, ts, surf.centered, surf.offset)
					get_root().add_child(m)
					m.global_position = world
					placed += 1
					gy += 90        # 같은 열에서 띄엄띄엄
				gy += 30
			gx += 80
		print("STAGE1_PAINT: 불투명 위 ", placed, "발 배치")
	elif _frame == 45:
		var img2 := get_root().get_texture().get_image()
		if img2: img2.save_png(OUT); print("STAGE1_PAINT_DONE ", OUT)
		quit(0); return true
	return false
