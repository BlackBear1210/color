extends SceneTree
## ============================================================================
## [2026-08-25 신규] 실제 게임 플랫폼처럼 배치해서 보는 미리보기
## ----------------------------------------------------------------------------
## 단일 도형이 아니라 **레벨 한 조각**을 만든다 —
##   계단식 지면 · 공중 발판 2개 · 벽 기둥 · 오목 구석.
## 코너가 실제 지형에서 어떻게 보이는지 확인하는 것이 목적이다.
##
## 실행 (⚠ --headless 금지):
##   Godot --path . -s res://tools/미리보기_플랫폼.gd -- \
##       --머티=res://..../x.tres --출력=res://tools/_shots/p.png \
##       [--줌=0.82] [--폭=1600] [--높이=900] [--중심=800,560] [--배경=0.72] [--라벨=이름]

const 지형_S := preload("res://scripts/스마트월드/지형.gd")

var _머티 := ""
var _출력 := "res://tools/_shots/플랫폼.png"
var _줌 := 0.82
var _폭 := 1600
var _높이 := 900
var _중심 := Vector2(800, 520)
var _배경 := 0.72
var _라벨 := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--머티="): _머티 = a.substr("--머티=".length())
		elif a.begins_with("--출력="): _출력 = a.substr("--출력=".length())
		elif a.begins_with("--줌="): _줌 = a.substr("--줌=".length()).to_float()
		elif a.begins_with("--폭="): _폭 = a.substr("--폭=".length()).to_int()
		elif a.begins_with("--높이="): _높이 = a.substr("--높이=".length()).to_int()
		elif a.begins_with("--배경="): _배경 = a.substr("--배경=".length()).to_float()
		elif a.begins_with("--라벨="): _라벨 = a.substr("--라벨=".length())
		elif a.begins_with("--중심="):
			var xy := a.substr("--중심=".length()).split(",")
			if xy.size() == 2: _중심 = Vector2(xy[0].to_float(), xy[1].to_float())
	call_deferred("_실행")


## 레벨 한 조각. 128px 을 한 칸으로 본다.
func _도형들() -> Array:
	return [
		# 계단식 지면 — 오른쪽으로 한 칸씩 올라간다 (볼록/오목 코너가 번갈아 나온다)
		["지면", PackedVector2Array([
			Vector2(-60, 700), Vector2(420, 700), Vector2(420, 572),
			Vector2(800, 572), Vector2(800, 444), Vector2(1180, 444),
			Vector2(1180, 316), Vector2(1660, 316),
			Vector2(1660, 1000), Vector2(-60, 1000)])],
		# 공중 발판 (얇은 것 — TOP 이 얇아야 하는 이유가 여기서 보인다)
		["발판1", PackedVector2Array([
			Vector2(120, 380), Vector2(500, 380), Vector2(500, 470), Vector2(120, 470)])],
		["발판2", PackedVector2Array([
			Vector2(700, 200), Vector2(1000, 200), Vector2(1000, 290), Vector2(700, 290)])],
		# 천장에서 내려온 기둥 — 아래쪽(BOTTOM)과 옆면(SIDE)을 같이 본다
		["기둥", PackedVector2Array([
			Vector2(1300, -60), Vector2(1450, -60), Vector2(1450, 180), Vector2(1300, 180)])],
	]


func _실행() -> void:
	if _머티.is_empty():
		push_error("--머티= 가 필요하다"); quit(1); return
	root.content_scale_size = Vector2i(_폭, _높이)
	DisplayServer.window_set_size(Vector2i(_폭, _높이))

	var r := Node2D.new()
	root.add_child(r)
	var bg := ColorRect.new()
	bg.position = Vector2(-4000, -4000)
	bg.size = Vector2(12000, 12000)
	bg.color = Color(_배경, _배경, _배경)
	bg.z_index = -100
	r.add_child(bg)

	var m: Resource = load(_머티)
	if m == null:
		push_error("머티 로드 실패"); quit(1); return
	for 항목 in _도형들():
		var s = 지형_S.new()
		s.name = 항목[0]
		s.shape_material = m
		s.시작상태 = 0
		r.add_child(s)
		var pa: SS2D_Point_Array = s.get_point_array()
		pa.begin_update()
		pa.add_points(항목[1])
		pa.end_update()
		pa.close_shape()
		s.force_update()

	if not _라벨.is_empty():
		var l := Label.new()
		l.position = Vector2(_중심.x - float(_폭) * 0.5 / _줌 + 16.0,
			_중심.y - float(_높이) * 0.5 / _줌 + 10.0)
		l.text = _라벨
		l.add_theme_color_override("font_color", Color(0.85, 0.08, 0.08))
		l.add_theme_font_size_override("font_size", int(26.0 / _줌))
		r.add_child(l)

	var cam := Camera2D.new()
	cam.position = _중심
	cam.zoom = Vector2(_줌, _줌)
	r.add_child(cam)
	cam.make_current()

	for i in 18:
		await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = root.get_texture().get_image()
	var 절대 := ProjectSettings.globalize_path(_출력)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	img.save_png(절대)
	print("[플랫폼] %s  %dx%d  줌 %.2f" % [_출력, img.get_width(), img.get_height(), _줌])
	quit(0)
