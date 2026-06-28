extends SceneTree
## ▼ 2026-06-28 페인트 시각 검증(창 모드 렌더 → PNG 저장).
##   지형(Arch) 위에 PaintMark 를 격자로 쫙 뿌리고, 몇 프레임 뒤 뷰포트를 PNG 로 저장한다.
##   → "지형 전체가 칠해지는지 / 안 칠해지는 빈 구멍이 있는지"를 사람이 이미지로 확인.
##   실행(창 모드, --headless 금지): Godot --path . -s res://tools/paint_visual_test.gd
const TERRAIN := "res://scenes/지형파일셋/실루엣/Ground_Flat_01_B.tscn"
const PAINT   := "res://scenes/effects/PaintMark.tscn"
const OUT     := "res://paint_test_out.png"

var _root: Node2D
var _frame := 0

func _initialize() -> void:
	get_root().size = Vector2i(1100, 1000)
	_root = Node2D.new()
	get_root().add_child(_root)

	# 지형 배치(원점). 검정 실루엣이 보이도록 흰 배경 깔기.
	var bg := ColorRect.new()
	bg.size = Vector2(1100, 1000)
	bg.color = Color(0.5, 0.5, 0.5)   # 회색 배경(검정 지형/흰 페인트 둘 다 대비)
	var cl := CanvasLayer.new(); cl.layer = -10; cl.add_child(bg)
	_root.add_child(cl)

	var terrain: Node2D = load(TERRAIN).instantiate()
	terrain.position = Vector2(120, 60)
	_root.add_child(terrain)
	var spr := terrain.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		print("PAINT_TEST: 지형 스프라이트 없음"); quit(1); return

	# 지형 텍스처 영역에 격자로 PaintMark 뿌리기(흰색). 각 마크는 지형 알파에 클립됨.
	var tex_size: Vector2 = spr.texture.get_size()
	var step := 150
	var paint_scene: PackedScene = load(PAINT)
	var count := 0
	for gx in range(0, int(tex_size.x), step):
		for gy in range(0, int(tex_size.y), step):
			var world := spr.global_transform * Vector2(gx, gy)
			var m := paint_scene.instantiate()
			m.paint_color = 1                       # WHITE
			m.impact_direction = Vector2.DOWN       # 표면 아래(=지형 안쪽)
			m.setup_terrain_clip_tex(spr.texture, spr.global_transform, tex_size, spr.centered, spr.offset)
			_root.add_child(m)
			m.global_position = world
			count += 1
	print("PAINT_TEST: 마크 ", count, "개 배치. 렌더 대기...")

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 30:
		var img := get_root().get_texture().get_image()
		if img:
			img.save_png(OUT)
			print("PAINT_TEST_DONE 저장: ", OUT, "  크기=", img.get_size())
		else:
			print("PAINT_TEST: 뷰포트 이미지 없음(렌더 디바이스?)")
		quit(0)
		return true
	return false
