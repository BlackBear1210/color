extends SceneTree
## ============================================================================
## [2026-09-05 신규] 실런타임에서 노멀맵이 실제로 몇 개 붙었나 + 흑↔백 짝이 살아 있나
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/진단_노멀맵_적용.gd
##   godot --headless --path . -s res://tools/진단_노멀맵_적용.gd -- <씬경로> ...
##
## ▣ 왜 필요한가
##   `노멀맵_표.gd` 의 경로가 하나라도 틀리면 **아무 오류 없이** 노멀맵이 안 붙는다.
##   화면이 조금 밋밋해질 뿐이라 눈으로는 못 잡는다 → 숫자로 확인한다.
##
## ▣ 무엇을 보나
##   ① 지형 노드 수 / 그중 CanvasTexture(노멀맵)를 문 것 수
##   ② `alt_invert` 폴백으로 떨어진 지형 수  ← 0 이 아니면 흑↔백 짝이 깨진 것
##   ③ 원본 .tres 가 안 바뀌었는지 (CompressedTexture2D 그대로여야 한다)
## ============================================================================

const 기본씬 := [
	"res://scenes/집/스테이지_1_2층방.tscn",
	"res://scenes/집/스테이지_2_복도계단.tscn",
	"res://scenes/world_1/1-1/stage_1-1.1.tscn",
	"res://scenes/world_1/1-2/stage_1-2.1.tscn",
	"res://scenes/world_2/stage_2-1.tscn",
	"res://scenes/world_2/stage_2-2.tscn",
	"res://scenes/world_2/stage_2-3.tscn",
]

## 표에 등록된 원본 재질들 — 여기가 CanvasTexture 로 바뀌어 있으면 원본이 오염된 것이다.
const 원본_재질 := [
	"res://assets/textures/smartshape/brick_v2_opaque/tres/지형_벽돌v2_opaque_black_사방.tres",
	"res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_얇은_사방.tres",
	"res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres",
	"res://assets/textures/smartshape/metal_v1/tres/지형_철판v1_black_사방.tres",
]


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	var 씬들: Array = 인자 if not 인자.is_empty() else 기본씬

	print("── 원본 재질 보호 ──")
	var 오염 := 0
	for p: String in 원본_재질:
		if not ResourceLoader.exists(p):
			print("  ⚠ 없음 %s" % p.get_file())
			continue
		var m = load(p)
		if m.fill_textures.is_empty():
			print("  ⚠ fill 없음 %s" % p.get_file())
			continue
		var t: Texture2D = m.fill_textures[0]
		var 깨끗 := not (t is CanvasTexture)
		if not 깨끗:
			오염 += 1
		print("  %s %s = %s" % ["✔" if 깨끗 else "✗", p.get_file(), t.get_class()])

	var 총_지형 := 0
	var 총_노멀 := 0
	var 총_폴백 := 0
	print("\n── 씬별 ──")
	for 경로: String in 씬들:
		if not ResourceLoader.exists(경로):
			print("  ⚠ 없음 %s" % 경로)
			continue
		var 뿌리 := (load(경로) as PackedScene).instantiate()
		root.add_child(뿌리)
		current_scene = 뿌리
		for _i in 25:
			await process_frame

		var 지형 := 0
		var 노멀 := 0
		var 폴백 := 0
		var 재질이름: Dictionary = {}
		for n in _모두(뿌리):
			var sm = n.get("shape_material")
			if sm == null or not (n is Node2D):
				continue
			if sm.fill_textures.is_empty():
				continue
			지형 += 1
			var f: Texture2D = sm.fill_textures[0]
			if f is CanvasTexture:
				노멀 += 1
				var 키: String = (f as CanvasTexture).resource_path.get_file()
				재질이름[키] = int(재질이름.get(키, 0)) + 1
			var mm = sm.fill_mesh_material
			if mm != null and mm.get_shader_parameter("alt_invert") == true:
				폴백 += 1
		총_지형 += 지형
		총_노멀 += 노멀
		총_폴백 += 폴백
		print("  %-38s 지형 %3d · 노멀맵 %3d · 짝실패(alt_invert) %d" % [
			경로.get_file(), 지형, 노멀, 폴백])
		for k in 재질이름:
			print("      %s × %d" % [k, 재질이름[k]])

		뿌리.queue_free()
		current_scene = null
		for _i in 5:
			await process_frame

	print("\n합계: 지형 %d · 노멀맵 %d · 짝실패 %d · 원본오염 %d" % [
		총_지형, 총_노멀, 총_폴백, 오염])
	quit(1 if (오염 > 0) else 0)


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r
