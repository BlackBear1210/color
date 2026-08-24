extends SceneTree
## ============================================================================
## [2026-08-24 신규] SS2D 고해상도 타일셋 머티리얼 생성기 (재질 무관 · 멱등)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_SS2D_타일셋_머티리얼.gd -- \
##       --재질=벽돌 --폴더=res://assets/textures/smartshape/brick_v1 [--배율=0.35] [--확인만]
##
## ▣ 이게 왜 있나
##   grass_v4 에서 SS2D 구조 문제(해상도 분리 · 코너 생성 · taper)를 전부 풀었다.
##   BRICK / SEWER / WOOD 를 만들 때 그 구조를 **다시 분석하지 않도록** 한 곳에 굳혀 둔다.
##   재질마다 바뀌는 것은 **PNG 뿐**이고, 머티리얼 구조는 이 파일이 전부 만든다.
##
## ▣ 만드는 것 (재질 하나당 4개)
##   지형_<재질>_<black|white>_<solid|detail>.tres
##
## ▣ 구조 (grass_v4 마스터 템플릿과 동일 — 근거는 docs 의 마스터 템플릿 문서)
##   엣지 메타 5개:
##     TOP    normal_range  45 ~ 135   texture_scale=배율  taper(top_left/right)
##     LEFT   normal_range 135 ~ 225   texture_scale=배율  taper(left_*)
##     BOTTOM normal_range 225 ~ 315   texture_scale=배율  taper(bottom_*)
##     RIGHT  normal_range 315 ~  45   texture_scale=배율  taper(right_*)
##     CORNER normal_range   0 ~ 360   texture_scale=배율  z_index=1
##            textures=[투명_256] (안 보이는 캐리어 · null 이면 코너가 안 생긴다)
##            textures_corner_outer/inner = 합성한 코너
##   fill_textures=[fill], fill_texture_scale=배율, fill_texture_z_index=-1
##
## ▣ 필요한 PNG (재질 폴더 기준). 없으면 무엇이 없는지 찍고 멈춘다.
##   <폴더>/<테마>/  edge_top, edge_bottom, edge_left, edge_right,
##                  corner_outer, corner_inner, fill_detail, fill_solid
##   <폴더>/taper/<테마>/ taper_{top,bottom,left,right}_{left,right}
##   <폴더>/공용/투명_256.png   (없으면 grass_v4 것을 그대로 쓴다 — 투명 캐리어는 재질 무관)
## ============================================================================

const 엣지스크립트 := "res://addons/rmsmartshape/materials/edge_material.gd"
const 메타스크립트 := "res://addons/rmsmartshape/materials/edge_material_metadata.gd"
const 범위스크립트 := "res://addons/rmsmartshape/normal_range.gd"
const 셰이프스크립트 := "res://addons/rmsmartshape/materials/shape_material.gd"
## 투명 캐리어는 재질과 무관하다. 재질 폴더에 없으면 이걸 그대로 쓴다.
const 기본캐리어 := "res://assets/textures/smartshape/grass_v4/공용/투명_256.png"

## [방향키, normal_range.begin, taper 파일 접두어]
const 방향표 := [
	["top", 45.0, "top"],
	["left", 135.0, "left"],
	["bottom", 225.0, "bottom"],
	["right", 315.0, "right"],
]

var _재질 := ""
var _폴더 := ""
var _배율 := 0.35
var _접두어 := ""
var _확인만 := false
var _빠진것: PackedStringArray = PackedStringArray()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--재질="):
			_재질 = a.substr("--재질=".length())
		elif a.begins_with("--폴더="):
			_폴더 = a.substr("--폴더=".length()).rstrip("/")
		elif a.begins_with("--배율="):
			_배율 = a.substr("--배율=".length()).to_float()
		elif a.begins_with("--접두어="):
			_접두어 = a.substr("--접두어=".length())
		elif a == "--확인만":
			_확인만 = true
	call_deferred("_실행")


## 있으면 로드, 없으면 목록에 적어 두고 null. (한 번에 다 알려주려고 즉시 안 죽는다)
func _텍(경로: String) -> Texture2D:
	if not ResourceLoader.exists(경로):
		_빠진것.push_back(경로)
		return null
	return load(경로)


func _엣지(텍: Texture2D, taper_l: Texture2D, taper_r: Texture2D) -> Resource:
	var e := Resource.new()
	e.set_script(load(엣지스크립트))
	var t: Array[Texture2D] = [텍]
	e.textures = t
	e.use_corner_texture = false
	e.use_taper_texture = true
	var tl: Array[Texture2D] = [taper_l]
	var tr: Array[Texture2D] = [taper_r]
	e.textures_taper_left = tl
	e.textures_taper_right = tr
	e.texture_scale = _배율
	return e


func _코너엣지(캐리어: Texture2D, outer: Texture2D, inner: Texture2D) -> Resource:
	var e := Resource.new()
	e.set_script(load(엣지스크립트))
	var t: Array[Texture2D] = [캐리어]
	e.textures = t
	var o: Array[Texture2D] = [outer]
	var i: Array[Texture2D] = [inner]
	e.textures_corner_outer = o
	e.textures_corner_inner = i
	e.use_corner_texture = true
	# ★ 코너전용 엣지에는 taper 를 붙이지 않는다.
	#   0~360 은 닫힌 도형을 통째로 도는 엣지라 first/last tess point 가 없다.
	e.use_taper_texture = false
	e.texture_scale = _배율
	return e


func _메타(엣지: Resource, begin: float, distance: float, z: int) -> Resource:
	var m := Resource.new()
	m.set_script(load(메타스크립트))
	var nr := Resource.new()
	nr.set_script(load(범위스크립트))
	nr.begin = begin
	nr.distance = distance
	m.edge_material = 엣지
	m.normal_range = nr
	m.z_index = z
	return m


func _머티(테마: String, 종류: String) -> Resource:
	var 캐리어경로 := "%s/공용/투명_256.png" % _폴더
	var 캐리어: Texture2D = load(캐리어경로) if ResourceLoader.exists(캐리어경로) else load(기본캐리어)

	var metas: Array = []
	for d in 방향표:
		var 텍 := _텍("%s/%s/%sedge_%s.png" % [_폴더, 테마, _접두어, d[0]])
		var tl := _텍("%s/taper/%s/taper_%s_left.png" % [_폴더, 테마, d[2]])
		var tr := _텍("%s/taper/%s/taper_%s_right.png" % [_폴더, 테마, d[2]])
		if 텍 == null or tl == null or tr == null:
			continue
		metas.push_back(_메타(_엣지(텍, tl, tr), d[1], 90.0, 0))

	var co := _텍("%s/%s/%scorner_outer.png" % [_폴더, 테마, _접두어])
	var ci := _텍("%s/%s/%scorner_inner.png" % [_폴더, 테마, _접두어])
	if co != null and ci != null:
		# z_index 1 = 4방향 엣지 위에 얹는다
		metas.push_back(_메타(_코너엣지(캐리어, co, ci), 0.0, 360.0, 1))

	var fill := _텍("%s/%s/%sfill_%s.png" % [_폴더, 테마, _접두어, 종류])
	if fill == null or metas.size() != 5:
		return null

	var s := Resource.new()
	s.set_script(load(셰이프스크립트))
	var typed: Array[SS2D_Material_Edge_Metadata] = []
	for m in metas:
		typed.push_back(m)
	s.set_edge_meta_materials(typed)
	var ft: Array[Texture2D] = [fill]
	s.fill_textures = ft
	s.fill_texture_scale = _배율
	s.fill_texture_z_index = -1
	return s


func _실행() -> void:
	if _재질.is_empty() or _폴더.is_empty():
		push_error("--재질= 과 --폴더= 가 필요하다")
		quit(1)
		return
	print("재질 '%s'  폴더 %s  배율 %.2f" % [_재질, _폴더, _배율])

	var 만든것 := 0
	for 테마 in ["black", "white"]:
		for 종류 in ["solid", "detail"]:
			var m := _머티(테마, 종류)
			if m == null:
				continue
			var 경로 := "%s/tres/지형_%s_%s_%s.tres" % [_폴더, _재질, 테마, 종류]
			if _확인만:
				print("  [확인] 만들 수 있다: %s" % 경로)
				만든것 += 1
				continue
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path("%s/tres" % _폴더))
			if ResourceSaver.save(m, 경로) != OK:
				push_error("저장 실패: %s" % 경로)
				continue
			print("  저장: %s" % 경로)
			만든것 += 1

	if not _빠진것.is_empty():
		var 중복 := {}
		print("\n  빠진 PNG %d개:" % _빠진것.size())
		for p in _빠진것:
			if 중복.has(p):
				continue
			중복[p] = true
			print("    - %s" % p)

	print("\n머티리얼 %d / 4 개 %s" % [만든것, "확인" if _확인만 else "생성"])
	quit(0 if 만든것 == 4 else 1)
