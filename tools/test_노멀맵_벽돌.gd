extends SceneTree
## ============================================================================
## [2026-09-05 신규] BRICK 노멀맵 + Light2D 실런타임 검증
## ----------------------------------------------------------------------------
## 실행 (실제 화면 + 스크린샷):
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . ^
##         -s res://tools/test_노멀맵_벽돌.gd -- <저장폴더>
##
## ▣ 무엇을 확인하나 (지시서 §8 A~I)
##   같은 지형·같은 카메라에서 세 장을 찍는다.
##     ① 노멀맵 없음 (원본 재질로 되돌린 상태)
##     ② 노멀맵 + 빛 왼쪽
##     ③ 노멀맵 + 빛 오른쪽
##   그리고 "전체가 밝아진 것"이 아니라 **벽돌마다 하이라이트가 반대편으로 옮겨갔는지**를
##   본다. 판정은 사람 눈이 기준이고, 수치는 보조로만 쓴다.
##
## ▣ 원본 보호 확인
##   테스트 씬이 쓰는 재질만 CanvasTexture 이고, 실제 스테이지가 쓰는 원본 재질은
##   여전히 CompressedTexture2D 인지 같이 확인한다.
## ============================================================================

const 테스트씬 := "res://scenes/집/테스트_2층방_노멀맵.tscn"
const 원본씬 := "res://scenes/집/스테이지_1_2층방.tscn"
const 원본재질 := "res://assets/textures/smartshape/brick_v2_opaque/tres/지형_벽돌v2_opaque_black_사방.tres"

var _저장 := ""


func _init() -> void: call_deferred("_go")


func _go() -> void:
	_저장 = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""

	# ── 0) 원본이 안 바뀌었는지 ──
	var 원 := load(원본재질)
	var of: Texture2D = 원.fill_textures[0]
	print("원본 재질 fill_textures[0] = %s (%s)  → %s" % [
		of.get_class(), of.resource_path.get_file(),
		("원본 그대로 ✔" if not (of is CanvasTexture) else "★원본이 바뀌었다 ✗")])

	var 노드 := (load(테스트씬) as PackedScene).instantiate()
	root.add_child(노드)
	current_scene = 노드
	for _i in 40: await process_frame

	# ── 1) 실제로 무엇이 물렸는지 런타임에서 확인 ──
	#   ⚠ `지형.gd` 는 실행 중에 `shape_material.duplicate(true)` 로 전용 사본을 만든다.
	#     그래서 "씬 파일에 뭐라고 적혀 있나"가 아니라 **런타임 노드가 무엇을 들고 있나**를 본다.
	var 지형들 := _모두(노드).filter(func(n): return n.get_class() == "Node2D" \
		and n.get("shape_material") != null)
	var 캔버스텍스처_지형 := 0
	var 표본: CanvasTexture = null
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty(): continue
		var f: Texture2D = sm.fill_textures[0]
		if f is CanvasTexture:
			캔버스텍스처_지형 += 1
			if 표본 == null: 표본 = f as CanvasTexture
	print("지형 노드 %d개 중 CanvasTexture(노멀맵) 물린 것 = %d개" % [지형들.size(), 캔버스텍스처_지형])
	if 표본:
		print("  diffuse = %s" % 표본.diffuse_texture.resource_path.get_file())
		print("  normal  = %s" % 표본.normal_texture.resource_path.get_file())

	var 빛 := _찾기(노드, func(n): return n is PointLight2D and n.name == "노멀맵_테스트빛")
	if 빛 == null:
		print("★테스트 광원을 못 찾았다"); quit(1); return
	print("광원: energy=%.1f  height=%.0f  texture_scale=%.1f" % [
		빛.energy, 빛.height, 빛.texture_scale])

	# ── 카메라·빛을 **실제 벽돌 지형** 앞에 세운다 ──
	#   좌표를 손으로 적으면 지형을 조금만 옮겨도 엉뚱한 곳을 찍는다.
	#   → 노멀맵이 물린 지형 중 **가장 큰 것**을 런타임에 찾아 그 한가운데를 본다.
	var 과녁 := Vector2.ZERO
	var 최대넓이 := -1.0
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty(): continue
		if not (sm.fill_textures[0] is CanvasTexture): continue
		var 점들: PackedVector2Array = t.get_point_array().get_vertices()
		if 점들.size() < 3: continue
		var 상자 := Rect2(t.to_global(점들[0]), Vector2.ZERO)
		for p in 점들:
			상자 = 상자.expand(t.to_global(p))
		var 넓이 := 상자.size.x * 상자.size.y
		if 넓이 > 최대넓이:
			최대넓이 = 넓이
			과녁 = 상자.get_center()
	print("가장 큰 벽돌 지형 중심 = %s (넓이 %.0f)" % [과녁, 최대넓이])

	var 카메라 := _찾기(노드, func(n): return n is Camera2D and n.enabled)
	if 카메라:
		카메라.set_script(null)          # ProtoCamera 의 추적을 멈춘다(테스트 전용)
		카메라.make_current()
		카메라.global_position = 과녁
		카메라.zoom = Vector2(1.6, 1.6)
	빛.global_position = 과녁 + Vector2(0, -40)
	빛.set("_시작", 빛.position)          # 왕복 기준점을 여기로 다시 잡는다
	for _i in 10: await process_frame

	# ── 2) 세 장 촬영 ──
	빛.set("왕복_거리", 520.0)
	빛.call("세우기", -0.45)
	for _i in 15: await process_frame
	await _찍기("2_노멀맵_빛왼쪽")
	빛.call("세우기", 0.45)
	for _i in 15: await process_frame
	await _찍기("3_노멀맵_빛오른쪽")

	# ① 대조군 — 같은 자리에서 노멀맵만 뺀다(디퓨즈는 그대로).
	#    CanvasTexture 의 normal_texture 만 비우면 나머지 조건이 100% 같은 비교가 된다.
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty(): continue
		var f: Texture2D = sm.fill_textures[0]
		if f is CanvasTexture:
			(f as CanvasTexture).normal_texture = null
	빛.call("세우기", -0.45)
	for _i in 15: await process_frame
	await _찍기("1_노멀맵없음_빛왼쪽")

	print("\n스크린샷 3장 저장 완료 → %s" % _저장)

	# ── 3) 흑↔백 짝 찾기가 살아 있나 (§5 의 진짜 위험) ──
	#   CanvasTexture 를 인라인으로 넣으면 resource_path 가 비어 `_짝_찾기()` 가 실패하고
	#   페인트 셰이더가 밝기 반전 폴백으로 떨어진다. 파일로 저장한 이유가 이것이므로 확인한다.
	var 짝_성공 := 0
	var 짝_실패 := 0
	for t in 지형들:
		var sm = t.get("shape_material")
		if sm == null or sm.fill_textures.is_empty(): continue
		if not (sm.fill_textures[0] is CanvasTexture): continue
		var mm = sm.fill_mesh_material
		if mm == null: continue
		# alt_invert 가 켜져 있으면 = 흰색 짝을 못 찾아 밝기 반전으로 때우고 있다는 뜻
		if mm.get_shader_parameter("alt_invert") == true:
			짝_실패 += 1
		else:
			짝_성공 += 1
	print("\n흑↔백 짝 찾기: 성공 %d개 / 폴백(alt_invert) %d개  → %s" % [
		짝_성공, 짝_실패,
		("진짜 흰색 아트를 물었다 ✔" if 짝_실패 == 0 else "★밝기 반전 폴백으로 떨어졌다 ✗")])

	# ── 4) 콜리전이 원본과 같은가 ──
	#   재질만 바꿨으니 콜리전은 한 점도 달라지면 안 된다.
	var 테스트_콜: Array = _콜리전_요약(노드)
	노드.queue_free()
	current_scene = null
	for _i in 6: await process_frame
	var 원노드 := (load(원본씬) as PackedScene).instantiate()
	root.add_child(원노드)
	current_scene = 원노드
	for _i in 40: await process_frame
	var 원본_콜: Array = _콜리전_요약(원노드)
	var 같나 := 테스트_콜 == 원본_콜
	print("콜리전: 테스트 %d개 / 원본 %d개  → %s" % [
		테스트_콜.size(), 원본_콜.size(),
		("완전히 동일 ✔" if 같나 else "★달라졌다 ✗")])
	quit()


## 씬 안 모든 CollisionPolygon2D 의 (전역위치, 점 개수, 점 합) 요약.
## 좌표를 통째로 비교하면 부동소수 잡음이 끼므로 개수와 합으로 지문을 만든다.
func _콜리전_요약(뿌리: Node) -> Array:
	var 결과: Array = []
	for n in _모두(뿌리):
		if not (n is CollisionPolygon2D): continue
		var cp := n as CollisionPolygon2D
		var 합 := Vector2.ZERO
		for p in cp.polygon: 합 += p
		결과.append("%s|%d|%.1f,%.1f|%.1f,%.1f" % [
			cp.get_path(), cp.polygon.size(), 합.x, 합.y,
			cp.global_position.x, cp.global_position.y])
	결과.sort()
	return 결과


func _찍기(이름: String) -> void:
	await process_frame
	if _저장 == "": return
	var img := root.get_texture().get_image()
	img.save_png("%s/NM_%s.png" % [_저장, 이름])
	print("  저장: NM_%s.png" % 이름)


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children(): r.append_array(_모두(c))
	return r


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 뿌리 == null: return null
	if 조건.call(뿌리): return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null: return r
	return null
