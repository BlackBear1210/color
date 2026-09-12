extends SceneTree
## ============================================================================
## [2026-09-05 신규 · 2026-09-05 랩 재구축에 맞춰 갱신]
## BRICK 노멀맵 + Light2D 실런타임 검증
## ----------------------------------------------------------------------------
## 실행 (실제 화면 + 스크린샷):
##   godot --rendering-method gl_compatibility --audio-driver Dummy ^
##         --resolution 1856x1044 --path . -s res://tools/test_노멀맵_벽돌.gd -- <저장폴더>
##
## ▣ 무엇을 확인하나
##   같은 지형·같은 카메라에서 네 장을 찍는다.
##     ① 노멀맵 없음 + 빛 왼쪽      ② 노멀맵 없음 + 빛 오른쪽
##     ③ 노멀맵 있음 + 빛 왼쪽      ④ 노멀맵 있음 + 빛 오른쪽
##   ★판정은 "전체가 밝아졌나"가 아니라 **벽돌마다 하이라이트가 반대편으로 옮겨갔나**다.
##     ①↔② 는 거의 안 바뀌어야 하고(노멀맵이 없으니 방향을 모른다),
##     ③↔④ 는 벽돌 테두리의 밝은 쪽이 바뀌어야 한다.
##   숫자로도 남긴다 — 빛이 닿는 좌·우 구역의 평균 밝기를 같이 찍는다.
##
## ▣ ⚠ 대상 씬이 바뀌었다
##   `scenes/집/테스트_2층방_노멀맵.tscn` 은 예전에 **스테이지 사본**이었다(루트에 월드.gd).
##   그때는 카메라가 방 맨 왼쪽 복도 입구를 보고 있어서 테스트 대상이 화면 밖이었다.
##   지금은 **고정 카메라 Lab**(`노멀맵_테스트_랩.gd`)이라 광원 이름과 창구가 다르다.
##     광원 = `환경광` · 위치 창구 = `빛_자리("LEFT"/"CENTER"/"RIGHT")`
##     노멀맵 토글 = `노멀_켜기(bool)`
## ============================================================================

const 테스트씬 := "res://scenes/집/테스트_2층방_노멀맵.tscn"
const 원본재질 := "res://assets/textures/smartshape/brick_v2_opaque/tres/지형_벽돌v2_opaque_black_사방.tres"

var _저장 := ""
var _실패 := 0


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_go")


func _go() -> void:
	_저장 = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""

	# ── 0) 원본 재질이 안 바뀌었는지 ──
	#   런타임에 CanvasTexture 를 바꿔 끼는 구조라, 원본 .tres 오염이 제일 무서운 사고다.
	var 원 := load(원본재질)
	var of: Texture2D = 원.fill_textures[0]
	var 깨끗 := not (of is CanvasTexture)
	print("원본 재질 fill_textures[0] = %s (%s) → %s" % [
		of.get_class(), of.resource_path.get_file(),
		("원본 그대로 ✔" if 깨끗 else "★원본이 바뀌었다 ✗")])
	if not 깨끗:
		_실패 += 1

	var 노드 := (load(테스트씬) as PackedScene).instantiate()
	root.add_child(노드)
	current_scene = 노드
	for _i in 40:
		await process_frame

	# ── 1) 실제로 무엇이 물렸는지 런타임에서 확인 ──
	#   ⚠ `지형.gd` 는 실행 중에 `shape_material.duplicate(true)` 로 전용 사본을 만들고,
	#     그 뒤 `노멀맵_표.gd` 가 CanvasTexture 를 바꿔 낀다.
	#     그래서 "씬 파일에 뭐라고 적혀 있나"가 아니라 **런타임 노드가 무엇을 들고 있나**를 본다.
	var 지형들 := _모두(노드).filter(func(n): return n is Node2D and n.get("shape_material") != null)
	var 캔버스텍스처_지형 := 0
	var 벽돌표본: CanvasTexture = null
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty():
			continue
		var f: Texture2D = sm.fill_textures[0]
		if f is CanvasTexture:
			캔버스텍스처_지형 += 1
			if 벽돌표본 == null and String(t.name).contains("브릭"):
				벽돌표본 = f as CanvasTexture
	print("지형 노드 %d개 중 CanvasTexture(노멀맵) 물린 것 = %d개" % [
		지형들.size(), 캔버스텍스처_지형])
	if 벽돌표본:
		print("  BRICK diffuse = %s" % 벽돌표본.diffuse_texture.resource_path.get_file())
		print("  BRICK normal  = %s" % (벽돌표본.normal_texture.resource_path.get_file()
			if 벽돌표본.normal_texture else "★없음"))
		if 벽돌표본.normal_texture == null:
			_실패 += 1
	else:
		print("  ★BRICK 지형에서 CanvasTexture 를 못 찾았다")
		_실패 += 1

	# ── 2) 랩 창구가 있는지 ──
	if not 노드.has_method("빛_자리"):
		print("★테스트 씬이 Lab 이 아니다 — `빛_자리()` 창구가 없다")
		_실패 += 1
		quit(1)
		return
	var 빛 := 노드.get_node_or_null("환경광") as PointLight2D
	if 빛 == null:
		print("★환경광을 못 찾았다")
		_실패 += 1
		quit(1)
		return
	print("환경광: energy=%.2f  height=%.0f  texture=%s  blend=%d" % [
		빛.energy, 빛.height, ("있음" if 빛.texture else "★없음"), 빛.blend_mode])
	if 빛.texture == null:
		# PointLight2D 는 texture 가 없으면 **아무것도 안 비춘다**. 조용한 실패라 꼭 잡는다.
		print("★광원에 텍스처가 없다 — 아무것도 비추지 못한다")
		_실패 += 1

	# 그림자·보조광은 끄고 **환경광 하나만** 남긴다(노멀맵만 보기 위해).
	노드.call("그림자_켜기", false)
	노드.call("보조광_켜기", false)
	노드.call("환경광_켜기", true)

	# ── 3) 네 장 촬영 ──
	var 순서 := [
		["OFF", "LEFT", "1_노멀OFF_빛왼쪽"],
		["OFF", "RIGHT", "2_노멀OFF_빛오른쪽"],
		["ON", "LEFT", "3_노멀ON_빛왼쪽"],
		["ON", "RIGHT", "4_노멀ON_빛오른쪽"],
	]
	for 줄 in 순서:
		노드.call("노멀_켜기", 줄[0] == "ON")
		노드.call("빛_자리", 줄[1])
		for _i in 12:
			await process_frame
		await _찍기(줄[2])

	# ── 4) 흑↔백 짝 찾기가 살아 있나 ──
	#   CanvasTexture 를 인라인으로 넣으면 resource_path 가 비어 `_짝_찾기()` 가 실패하고
	#   페인트 셰이더가 밝기 반전 폴백(alt_invert)으로 떨어진다. 파일로 만든 이유가 이것이다.
	var 짝_성공 := 0
	var 짝_실패 := 0
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty():
			continue
		if not (sm.fill_textures[0] is CanvasTexture):
			continue
		var mm = sm.fill_mesh_material
		if mm == null:
			continue
		if mm.get_shader_parameter("alt_invert") == true:
			짝_실패 += 1
		else:
			짝_성공 += 1
	print("\n흑↔백 짝 찾기: 성공 %d개 / 폴백(alt_invert) %d개 → %s" % [
		짝_성공, 짝_실패,
		("진짜 흰색 아트를 물었다 ✔" if 짝_실패 == 0 else "★밝기 반전 폴백으로 떨어졌다 ✗")])
	if 짝_실패 > 0:
		_실패 += 1

	print("\n[test_노멀맵_벽돌] 실패 %d" % _실패)
	quit(1 if _실패 > 0 else 0)


func _찍기(이름: String) -> void:
	await process_frame
	if _저장 == "":
		return
	var img := root.get_texture().get_image()
	img.save_png("%s/NM_%s.png" % [_저장, 이름])
	print("  저장: NM_%s.png" % 이름)


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r
