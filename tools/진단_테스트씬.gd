extends SceneTree
## ============================================================================
## [2026-09-05 신규] 조명/노멀맵 테스트 씬 진단 — **런타임 실측**
## ----------------------------------------------------------------------------
## 실행:
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . \
##         -s res://tools/진단_테스트씬.gd -- [씬경로]
##   (기본: res://scenes/집/테스트_2층방_노멀맵.tscn)
##
## ▣ 왜 만들었나
##   "리소스가 존재한다 / 파일이 연결되어 있다" 만 보는 진단은 **화면이 안 보이는 문제를
##   절대 못 잡는다.** 실제로 씬은 멀쩡한데 카메라가 엉뚱한 데를 보고 있어서 안 보이는
##   경우가 있었다.
##   → 씬을 **실제로 실행한 뒤** 카메라가 보는 사각형과 각 노드의 전역 좌표를 비교해서
##     "화면 안에 있나 / 밖에 있나"를 숫자로 찍는다.
##
## ▣ 무엇을 찍나 (지시서 §1 의 24 항목)
##   루트 타입 · current_scene · 카메라(존재/위치/줌/보는 사각형)
##   · 지형 좌표와 화면 포함 여부 · SS2D 재질과 **런타임 mesh.texture 의 실제 타입**
##   · CanvasModulate · 광원(위치/반경/height/텍스처/마스크) · Occluder
##   · Player(존재/위치/스케일/보조광) · CanvasLayer(HUD)
##   · 런타임에 재질을 바꿔 끼는 코드가 돌았는지 · @tool 여부
## ============================================================================

const 기본씬 := "res://scenes/집/테스트_2층방_노멀맵.tscn"


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	var 경로: String = 인자[0] if 인자.size() > 0 else 기본씬
	if not ResourceLoader.exists(경로):
		print("✗ 씬 없음: %s" % 경로)
		quit(1)
		return

	var ps := load(경로) as PackedScene
	var 뿌리 := ps.instantiate()
	root.add_child(뿌리)
	current_scene = 뿌리
	# 월드.gd 가 카메라·HUD·총을 붙이고 SS2D 가 콜리전을 굽는 데 시간이 걸린다.
	for _i in 60:
		await process_frame

	print("═══ 진단: %s ═══" % 경로.get_file())
	print("\n[1] 루트 노드 타입 = %s (이름 %s)" % [뿌리.get_class(), 뿌리.name])
	var scr: Variant = 뿌리.get_script()
	print("[21] 루트 스크립트 = %s" % (scr.resource_path if scr else "(없음)"))
	print("[2] current_scene = %s" % (current_scene.name if current_scene else "(없음)"))

	# ── 카메라 ──────────────────────────────────────────────────────────────
	var 캠: Camera2D = null
	for n in _모두(뿌리):
		if n is Camera2D and (n as Camera2D).is_current():
			캠 = n as Camera2D
			break
	if 캠 == null:
		print("[3] ★현재 카메라(current) 가 **없다** — 화면이 (0,0) 기준으로 그려진다")
	else:
		var 보는크기 := root.get_visible_rect().size / 캠.zoom
		var 보는상자 := Rect2(캠.global_position - 보는크기 * 0.5, 보는크기)
		print("[3] 카메라 = %s (부모 %s)" % [캠.name, 캠.get_parent().name])
		print("[4] 카메라 global_position = %s" % 캠.global_position)
		print("[5] 카메라 zoom = %s → 보는 범위 %s" % [캠.zoom, 보는상자])
		_보임_검사(뿌리, 보는상자)

	# ── CanvasModulate ─────────────────────────────────────────────────────
	var 어둠: CanvasModulate = null
	for n in _모두(뿌리):
		if n is CanvasModulate:
			어둠 = n as CanvasModulate
			break
	print("\n[9] CanvasModulate = %s" % ("(없음)" if 어둠 == null else str(어둠.color)))

	# ── 지형 / SS2D ────────────────────────────────────────────────────────
	print("\n[6~8·20] 지형 · 재질 · **런타임 mesh 텍스처 실측**")
	var 지형수 := 0
	var 캔버스텍스처수 := 0
	var 메시수 := 0
	var 재질별: Dictionary = {}
	for n in _모두(뿌리):
		var sm = n.get("shape_material")
		if sm == null or not (n is Node2D):
			continue
		지형수 += 1
		if sm.fill_textures.is_empty():
			continue
		var f: Texture2D = sm.fill_textures[0]
		var 키: String = "%s / %s" % [f.get_class(), f.resource_path.get_file()]
		재질별[키] = int(재질별.get(키, 0)) + 1
		if f is CanvasTexture:
			캔버스텍스처수 += 1
		# ★ SS2D 가 실제로 그리는 것은 `_meshes` 안의 mesh.texture 다.
		#   재질에 CanvasTexture 가 물려 있어도 메시가 옛 텍스처를 들고 있으면 화면은 안 바뀐다.
		var meshes = n.get("_meshes")
		if meshes != null:
			for m in meshes:
				if m == null or m.texture == null:
					continue
				메시수 += 1
	print("  지형 노드 %d개 · 그중 CanvasTexture(노멀맵) %d개 · 구운 mesh %d개"
		% [지형수, 캔버스텍스처수, 메시수])
	for k in 재질별:
		print("    %-58s × %d" % [k, 재질별[k]])

	# 첫 CanvasTexture 하나를 뜯어 본다
	for n in _모두(뿌리):
		var sm2 = n.get("shape_material")
		if sm2 == null or sm2.fill_textures.is_empty():
			continue
		var f2: Texture2D = sm2.fill_textures[0]
		if not (f2 is CanvasTexture):
			continue
		var ct := f2 as CanvasTexture
		print("  표본 지형 '%s'" % n.name)
		print("    CanvasTexture   = %s" % ct.resource_path)
		print("    diffuse_texture = %s (%s)" % [
			ct.diffuse_texture.resource_path.get_file() if ct.diffuse_texture else "(없음)",
			ct.diffuse_texture.get_class() if ct.diffuse_texture else "-"])
		print("    normal_texture  = %s (%s) RID=%s" % [
			ct.normal_texture.resource_path.get_file() if ct.normal_texture else "★없음",
			ct.normal_texture.get_class() if ct.normal_texture else "-",
			str(ct.normal_texture.get_rid()) if ct.normal_texture else "-"])
		# 실제 메시가 그 CanvasTexture 를 들고 있나
		var ms = n.get("_meshes")
		if ms != null and ms.size() > 0:
			var 같음 := 0
			for m in ms:
				if m != null and m.texture == f2:
					같음 += 1
			print("    구운 mesh %d개 중 이 텍스처를 든 것 = %d개" % [ms.size(), 같음])
		break

	# ── 광원 ───────────────────────────────────────────────────────────────
	print("\n[10~14] 광원")
	var 광원수 := 0
	for n in _모두(뿌리):
		if not (n is PointLight2D):
			continue
		광원수 += 1
		var L := n as PointLight2D
		var 반경: float = L.texture_scale * (L.texture.get_size().x * 0.5 if L.texture else 0.0)
		print("  · %-18s pos %-22s energy %.2f height %.0f 반경≈%.0f blend %d "
			% [L.name, str(L.global_position), L.energy, L.height, 반경, L.blend_mode]
			+ "tex %s shadow %s mask %d visible %s" % [
			("있음" if L.texture else "★없음(아무것도 안 비춘다)"),
			L.shadow_enabled, L.range_item_cull_mask, L.visible])
	if 광원수 == 0:
		print("  ★PointLight2D 가 하나도 없다")

	# ── Occluder ───────────────────────────────────────────────────────────
	var occ := 0
	for n in _모두(뿌리):
		if n is LightOccluder2D:
			occ += 1
	print("\n[15] LightOccluder2D = %d개" % occ)

	# ── Player ─────────────────────────────────────────────────────────────
	print("\n[16~18] Player")
	var p: Node2D = null
	for n in _모두(뿌리):
		# 랩 씬은 `테스트_Player` 를 쓴다 → 뒤에 "Player" 가 붙으면 전부 인정.
		if String(n.name).ends_with("Player"):
			p = n as Node2D
			break
	if p == null:
		print("  ★Player 가 없다")
	else:
		print("  위치 %s · scale %s · global_scale %s" % [
			p.global_position, p.scale, p.global_scale])
		var 보조 := p.get_node_or_null("플레이어_보조광")
		if 보조 == null:
			print("  ★플레이어_보조광 없음")
		else:
			var pl := 보조.get_node_or_null("PointLight2D") as PointLight2D
			print("  보조광: energy %.2f · 반경 %.0f · height %.0f · shadow %s · global_scale %s"
				% [pl.energy, 보조.get("반경"), pl.height, pl.shadow_enabled, pl.global_scale])

	# ── CanvasLayer / HUD ──────────────────────────────────────────────────
	print("\n[19] CanvasLayer")
	for n in _모두(뿌리):
		if n is CanvasLayer:
			print("  · %-16s layer %d · 자식 %d" % [n.name, (n as CanvasLayer).layer,
				n.get_child_count()])

	print("\n[23] @tool 스크립트가 붙은 노드 수 = %d" % _tool수(뿌리))
	print("═══ 진단 끝 ═══")
	quit()


## 카메라가 보는 사각형 안에 지형이 몇 개나 들어오나.
## ★"씬에는 있는데 카메라 밖이라 안 보인다"를 잡는 것이 이 검사의 목적이다.
func _보임_검사(뿌리: Node, 보는상자: Rect2) -> void:
	var 안 := 0
	var 밖 := 0
	var 밖목록: Array = []
	for n in _모두(뿌리):
		if n.get("shape_material") == null or not (n is Node2D):
			continue
		var g := (n as Node2D).global_position
		if 보는상자.has_point(g):
			안 += 1
		else:
			밖 += 1
			if 밖목록.size() < 6:
				밖목록.append("%s%s" % [n.name, str(g)])
	print("[24] ★카메라 화면 안 지형 = %d개 / 화면 밖 = %d개" % [안, 밖])
	if 밖 > 0:
		print("     밖 예시: %s" % ", ".join(밖목록))


func _tool수(n: Node) -> int:
	var c := 0
	for x in _모두(n):
		var s = x.get_script()
		if s != null and s is GDScript and (s as GDScript).is_tool():
			c += 1
	return c


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r
