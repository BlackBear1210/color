extends SceneTree
## ▼ 2026-06-21 (작업 W-D) map1/2/3 의 지형 PNG 마다 '깨끗한 충돌 폴리곤 1개'를 박은 씬 생성기.
##   실행: Godot --headless --path . -s res://tools/build_map_polys.gd
##   결과: res://scenes/지형파일셋/맵폴리/<mapN>/<PNG이름>.tscn
##
## ◆ 핵심 원칙 (맵_레벨디자인_시스템.md)
##   - 자동 베이크(opaque_to_polygons)는 '조각난 볼록 폴리곤들'을 만들어 발 걸림을 유발한다.
##   - 그래서 여기서는 알파 외곽점 전체의 '볼록 껍질(convex hull)' 을 구해
##     이음새 없는 '단일 매끈한 폴리곤 1개' 로 충돌을 만든다. (조각 금지)
##   - 비주얼(Sprite2D)과 충돌(CollisionPolygon2D)을 분리한다.
##
## ◆ 색/분류 (파일명 기준)
##   - 이름에 White → WHITE 지형 / Black·Slope → BLACK 지형 (platform.gd + DeathDetector)
##   - Thorn·Spike·Cog·Gear·Vine·Chase → 장애물(obstacle 레이어, 색 판정 없음)
##   - Guide·Crack·Clear → 장식/가이드라 충돌 생성 제외(스킵)

const OUT_ROOT := "res://scenes/지형파일셋/맵폴리/"
const PLATFORM_SCRIPT := "res://scripts/platform.gd"
const MAP_DIRS := {
	"map1": "res://scenes/world_1/map1/",
	"map2": "res://scenes/world_1/map2/",
	"map3": "res://map3/",
}
const EPSILON := 4.0          # 외곽 단순화(px)
const ALPHA_THRESHOLD := 0.5
const LAYER_BLACK := 1 << 1
const LAYER_WHITE := 1 << 2
const LAYER_OBSTACLE := 1 << 8

func _initialize() -> void:
	var script: Script = load(PLATFORM_SCRIPT)
	var made := 0
	var skipped := 0
	for map_key in MAP_DIRS:
		var src_dir: String = MAP_DIRS[map_key]
		var out_dir: String = OUT_ROOT + map_key + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var dir := DirAccess.open(src_dir)
		if dir == null:
			print("폴더 열기 실패: ", src_dir); continue
		for f in dir.get_files():
			if not f.to_lower().ends_with(".png"):
				continue
			var base := f.get_basename()
			# 장식/가이드/클리어 표식은 충돌 제외
			if _matches(base, ["Guide", "Crack", "Clear"]):
				skipped += 1; continue
			var tex: Texture2D = load(src_dir + f)
			if tex == null:
				print("텍스처 로드 실패: ", f); skipped += 1; continue
			var hull := _hull_from_texture(tex)
			if hull.size() < 3:
				print("폴리곤 생성 실패(알파 없음?): ", f); skipped += 1; continue
			var is_obstacle := _matches(base, ["Thorn", "Spike", "Cog", "Gear", "Vine", "Chase"])
			var is_white := _matches(base, ["White"])
			var path := out_dir + base + ".tscn"
			if _build_scene(script, base, tex, hull, is_obstacle, is_white, path) == OK:
				made += 1
				print("저장: ", path, "  (", _polys(is_obstacle, is_white), ", 정점 ", hull.size(), ")")
			else:
				print("저장 실패: ", path)
	print("MAP_POLYS_DONE  생성=%d  스킵=%d" % [made, skipped])
	quit(0)

func _polys(is_obstacle: bool, is_white: bool) -> String:
	if is_obstacle: return "obstacle"
	return "WHITE" if is_white else "BLACK"

func _matches(s: String, keys: Array) -> bool:
	var low := s.to_lower()
	for k in keys:
		if low.find(String(k).to_lower()) != -1:
			return true
	return false

## 텍스처 알파 외곽점들의 볼록 껍질(단일 폴리곤)을 반환. 좌표=텍스처 px(좌상단 원점).
func _hull_from_texture(tex: Texture2D) -> PackedVector2Array:
	var img := tex.get_image()
	if img == null:
		return PackedVector2Array()
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, ALPHA_THRESHOLD)
	var rect := Rect2i(Vector2i.ZERO, bm.get_size())
	var polys := bm.opaque_to_polygons(rect, EPSILON)
	# 모든 조각의 점을 한데 모아 convex_hull → 이음새 없는 단일 폴리곤
	var all := PackedVector2Array()
	for p in polys:
		for v in p:
			all.append(v)
	if all.size() < 3:
		return PackedVector2Array()
	return Geometry2D.convex_hull(all)

## PNG 1장 → (Sprite + 단일 CollisionPolygon2D) 씬 저장
func _build_scene(script: Script, body_name: String, tex: Texture2D,
		hull: PackedVector2Array, is_obstacle: bool, is_white: bool, path: String) -> int:
	var root := StaticBody2D.new()
	root.name = body_name
	if is_obstacle:
		# 장애물: 색 판정 없음. obstacle 레이어 + 그룹 등록(총알이 칠하지 않도록)
		root.collision_layer = LAYER_OBSTACLE
		root.collision_mask = 0
		root.add_to_group("obstacle", true)   # persistent=true → .tscn 에 저장됨
	else:
		# 색 지형: platform.gd 재사용(색 레이어 + DeathDetector 색 판정)
		root.set_script(script)
		root.set("color_state", ColorDefs.WHITE if is_white else ColorDefs.BLACK)

	# 비주얼(좌상단 정렬: 충돌 폴리곤 px 좌표와 일치시키기 위해 centered=false)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = tex
	spr.centered = false
	root.add_child(spr)
	spr.owner = root

	# 단일 충돌 폴리곤
	var col := CollisionPolygon2D.new()
	col.name = "CollisionPolygon2D"
	col.polygon = hull
	root.add_child(col)
	col.owner = root

	# 색 지형만 DeathDetector(색 판정 영역) 추가
	if not is_obstacle:
		var dd := Area2D.new()
		dd.name = "DeathDetector"
		dd.monitoring = false
		root.add_child(dd)
		dd.owner = root
		var ddcol := CollisionPolygon2D.new()
		ddcol.name = "CollisionPolygon2D"
		ddcol.polygon = hull
		dd.add_child(ddcol)
		ddcol.owner = root

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		return perr
	return ResourceSaver.save(packed, path)
