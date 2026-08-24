extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 머티리얼 4종에 taper 텍스처를 연결한다 (멱등)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/적용_grass_v4_taper_머티리얼.gd [-- --확인만]
##
## ▣ 무엇을 바꾸나 (4방향 엣지에만, 코너전용 엣지는 그대로 둔다)
##   use_taper_texture = true
##   textures_taper_left  = [taper_<방향>_left.png]
##   textures_taper_right = [taper_<방향>_right.png]
##
## ▣ 안 바꾸는 것
##   texture_scale 0.35 · normal_range · 엣지/코너/필 텍스처 · z_index · fill_texture_scale
##   코너전용(0~360) 엣지는 taper 를 붙이지 않는다.
##   (닫힌 도형 하나를 통째로 도는 엣지라 first/last tess point 가 없어 어차피 안 걸린다)
##
## ▣ 멱등: 항상 현재 .tres 를 읽어 위 세 값만 덮어쓴다. 누적되는 값이 없다.
## ▣ 방향은 이름이 아니라 normal_range.begin 으로 판별한다.
##   .tres 의 배열 순서에 기대면 나중에 조용히 어긋난다.
## ============================================================================

const 머티폴더 := "res://assets/textures/smartshape/grass_v4/tres/"
const 방향이름 := {45: "top", 135: "left", 225: "bottom", 315: "right"}
const 대상 := [
	["지형_잔디_v4_black_detail.tres", "black"],
	["지형_잔디_v4_black_solid.tres", "black"],
	["지형_잔디_v4_white_detail.tres", "white"],
	["지형_잔디_v4_white_solid.tres", "white"],
]

var _확인만 := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--확인만":
			_확인만 = true
	call_deferred("_실행")


func _코너전용(meta) -> bool:
	return meta.normal_range != null and meta.normal_range.distance > 300.0


func _실행() -> void:
	var 실패 := 0
	for 항목 in 대상:
		var 경로: String = 머티폴더 + 항목[0]
		var 테마: String = 항목[1]
		var m = ResourceLoader.load(경로, "", ResourceLoader.CACHE_MODE_IGNORE)
		if m == null:
			push_error("로드 실패: %s" % 경로)
			실패 += 1
			continue
		var 붙임 := 0
		for meta in m.get_all_edge_meta_materials():
			if _코너전용(meta):
				continue
			var b := int(round(meta.normal_range.begin))
			if not 방향이름.has(b):
				push_error("모르는 normal_range.begin %d (%s)" % [b, 항목[0]])
				실패 += 1
				continue
			var d: String = 방향이름[b]
			var 폴더 := "res://assets/textures/smartshape/grass_v4/taper/%s/" % 테마
			var l: Texture2D = load(폴더 + "taper_%s_left.png" % d)
			var r: Texture2D = load(폴더 + "taper_%s_right.png" % d)
			if l == null or r == null:
				push_error("taper 텍스처 없음: %s%s" % [폴더, d])
				실패 += 1
				continue
			var al: Array[Texture2D] = [l]
			var ar: Array[Texture2D] = [r]
			meta.edge_material.textures_taper_left = al
			meta.edge_material.textures_taper_right = ar
			meta.edge_material.use_taper_texture = true
			붙임 += 1
		if _확인만:
			print("  [확인] %-34s 4방향 %d개에 붙일 예정" % [항목[0], 붙임])
			continue
		if ResourceSaver.save(m, 경로) != OK:
			push_error("저장 실패: %s" % 경로)
			실패 += 1
			continue
		print("  %-34s 4방향 %d개에 taper 연결" % [항목[0], 붙임])
	if 실패 > 0:
		push_error("실패 %d건" % 실패)
		quit(1)
		return
	print("완료. texture_scale / 코너 / 필은 건드리지 않았다.")
	quit(0)
