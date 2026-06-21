@tool
extends SceneTree
## ════════════════════════════════════════════════════════════════════════
##  아키텍처 타일셋 자동 생성기 (2026-06-17)
##  ※ 헤드리스 실행 가능하도록 SceneTree(MainLoop) 로 작성.
##    실행: godot --headless --path <proj> --script res://tools/bake_architecture_tileset.gd
## ════════════════════════════════════════════════════════════════════════
## 무엇을 하나:
##   프로젝트에 이미 있는 "디테일 살아있는 흑색 지형 PNG" 들을 하나씩
##   "이미지(Sprite2D) + 폴리(CollisionPolygon2D) + 색판정(DeathDetector)" 이
##   묶인 .tscn 씬으로 굽는다. → 도형_타일셋/도형_타일셋_최신/Arch_XX_*.tscn
##
## 왜 스크립트로(자동화):
##   PNG 마다 충돌을 손으로 찍는 건 비현실적이고, opaque_to_polygons() 로
##   알파 외곽선을 따라 자동으로 폴리를 만들 수 있다. 이 작업을 10개(앞으로 N개)
##   반복하므로 EditorScript 로 일괄 처리한다. 새 PNG 를 ENTRIES 에 추가하고
##   이 스크립트를 다시 실행(파일 > 실행)하면 타일셋이 갱신된다.
##
## 실행법(에디터): 스크립트 편집기에서 이 파일 열고 [파일 > 실행](Ctrl+Shift+X)
##         또는 헤드리스: godot --headless --path <proj> --script res://tools/bake_architecture_tileset.gd
##
## ※ 충돌은 SOLIDS(채움) 모드로 굽는다 → 에디터에서 1스테이지처럼 무지개색으로 보인다.
##   (단일 블록형 지형이라 구멍 메움 문제 없음. 동굴형은 별도로 SEGMENTS 사용)

# ▼ 2026-06-17 갱신: 타일셋 폴더가 scenes/ 아래로 이동되어 출력 경로 수정.
const OUT_DIR: String = "res://scenes/도형_타일셋_최신/"
const TERRAIN_SCRIPT: String = "res://scripts/terrain_image.gd"

# 굽는 알파/단순화 파라미터
const ALPHA_THRESHOLD: float = 0.5
const SIMPLIFY: float = 4.0   # 외곽선 단순화(px). 클수록 정점↓(가벼움)

## 10가지 아키텍처 = 프로젝트에 존재하는 흑색 지형 PNG 들.
## 디자이너가 PNG 를 추가/교체하면 이 목록만 고치면 된다.
const ENTRIES: Array = [
	{"name": "Arch_01_BlackBlock_A",  "tex": "res://map3/Platform_Black_01.png"},
	{"name": "Arch_02_BlackBlock_B",  "tex": "res://map3/Platform_Black_02.png"},
	{"name": "Arch_03_BlackBlock_C",  "tex": "res://map3/Platform_Black_03.png"},
	{"name": "Arch_04_SlopeBlack",    "tex": "res://map3/PlatformSlope_Black.png"},
	{"name": "Arch_05_Ledge_A",       "tex": "res://scenes/world_1/map1/Platform_Black_01.png"},
	{"name": "Arch_06_Ledge_B",       "tex": "res://scenes/world_1/map1/Platform_Black_02.png"},
	{"name": "Arch_07_SlopeBody_A",   "tex": "res://scenes/world_1/map1/Slope_Body_01.png"},
	{"name": "Arch_08_SlopeBody_B",   "tex": "res://scenes/world_1/map2/Slope_Body_02.png"},
	{"name": "Arch_09_Cave_A",        "tex": "res://scenes/world_1/map2/Platform_Black_01.png"},
	{"name": "Arch_10_BrokenPlatform","tex": "res://도형_타일셋/broken_platform.png.png"},
]


## ▼ 2026-06-17 추가: 이 폴더(들) 안의 모든 .png 를 자동으로 구워 같은 폴더에 씬 생성.
##   slice_terrain.gd 가 만든 조각들을 손으로 일일이 ENTRIES 에 적지 않아도 됨.
##   (비우면 ENTRIES 만 처리)
const SCAN_DIRS: Array = [
	"res://scenes/도형_타일셋_최신/sliced/",
	# ▼ 2026-06-21 추가: silhouette_from_image.gd 가 만든 '흑/백 실루엣 PNG' 자동 굽기.
	#   파이프라인: 원본이미지 → silhouette_from_image.gd → 실루엣/ → (여기서 자동 bake) → Arch 씬
	"res://scenes/지형파일셋/실루엣/",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var script_res := load(TERRAIN_SCRIPT)
	var made := 0

	# 1) 명시적 ENTRIES (원본 큰 지형들) → OUT_DIR
	for e in ENTRIES:
		made += _bake_entry(str(e["name"]), str(e["tex"]), OUT_DIR, script_res)

	# 2) ▼ 2026-06-17: SCAN_DIRS 안의 모든 png 자동 처리 → 같은 폴더에 씬
	for dir_path in SCAN_DIRS:
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		for f in da.get_files():
			# .import 등 부산물 제외, 실제 png 만
			if not f.to_lower().ends_with(".png"):
				continue
			var tex_path: String = dir_path + f
			var arch_name: String = f.get_basename()   # 파일명 = 씬 이름
			# ▼ 2026-06-22 추가: silhouette_from_image.gd 가 붙인 색표기(_W/_B)로 color_state 결정.
			#   → 흰 지형은 platform_white(layer3), 검정은 platform_black(layer2) 물리레이어가 정확히 적용됨.
			var cs := 0   # 기본 BLACK
			if arch_name.ends_with("_W"):
				cs = 1     # WHITE
			made += _bake_entry(arch_name, tex_path, dir_path, script_res, cs)

	print("──────── 아키텍처 타일셋 %d개 생성 완료" % made)
	quit()   # 헤드리스 MainLoop 종료


## 텍스처 1장 → (이미지+폴리+색판정) 씬 1개. 반환: 성공 1 / 실패 0.
## ▼ 2026-06-22: color_state 인자 추가(0=BLACK/1=WHITE/2=GRAY). 물리레이어가 색에 맞게 적용됨.
func _bake_entry(arch_name: String, tex_path: String, out_dir: String, script_res: Resource, color_state: int = 0) -> int:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_warning("타일셋: 텍스처 로드 실패 → %s" % tex_path)
		return 0

	# terrain_image.gd 가 기대하는 노드 구조: StaticBody2D ├ Sprite2D └ DeathDetector
	var root := StaticBody2D.new()
	root.name = arch_name
	# 충돌 레이어는 color_state 에 맞춰: BLACK=2, WHITE=4, GRAY=8 (terrain_image._apply_color_state 가 재적용하나 초기값도 맞춤)
	root.collision_layer = [2, 4, 8][clampi(color_state, 0, 2)]
	root.collision_mask = 0

	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.centered = false           # 좌상단 원점 → 배치/스냅 쉬움
	spr.texture = tex
	root.add_child(spr)

	var detector := Area2D.new()
	detector.name = "DeathDetector"
	detector.collision_layer = 64
	detector.collision_mask = 0
	detector.monitoring = false
	root.add_child(detector)

	var size := tex.get_size()
	var entry := Marker2D.new()
	entry.name = "Entry"
	entry.position = Vector2(0, 0)
	root.add_child(entry)
	var exitm := Marker2D.new()
	exitm.name = "Exit"
	exitm.position = Vector2(size.x, 0)
	root.add_child(exitm)

	root.set_script(script_res)
	root.set("color_state", color_state)
	root.set("alpha_threshold", ALPHA_THRESHOLD)
	root.set("simplify", SIMPLIFY)
	root.set("collision_build_mode", 0)   # SOLIDS → 에디터에서 무지개색으로 보임
	root.set("terrain_texture", tex)

	var n := AutoCollision.bake_into(root, spr, ALPHA_THRESHOLD, SIMPLIFY, root, AutoCollision.BUILD_SOLIDS)
	AutoCollision.bake_into(detector, spr, ALPHA_THRESHOLD, SIMPLIFY, root, AutoCollision.BUILD_SOLIDS)
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_warning("타일셋: pack 실패 (%s)" % arch_name)
		root.free()
		return 0
	var path: String = out_dir + arch_name + ".tscn"
	var err := ResourceSaver.save(packed, path)
	root.free()   # 임시 노드 정리(leak 방지)
	if err == OK:
		print("타일셋 생성: %s  (폴리 %d개)" % [path, n])
		return 1
	push_warning("타일셋: 저장 실패 %s err=%d" % [path, err])
	return 0


## 노드와 그 모든 후손의 owner 를 지정 (root 자신은 제외)
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for c in node.get_children():
		if c != owner:
			c.owner = owner
		_set_owner_recursive(c, owner)
