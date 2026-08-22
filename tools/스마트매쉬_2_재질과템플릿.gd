extends SceneTree
## ============================================================================
## [2026-08-22 신규] SmartShape 재질(.tres) + 드래그 템플릿 씬 생성기
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/스마트매쉬_2_재질과템플릿.gd
##   (선행: 스마트매쉬_1_슬라이스.gd 실행 + `--import` 로 조각 임포트가 끝나 있어야 한다.)
##
## ▣ 무엇을 만드나 (도형님 지시: "작업자가 씬으로 불러오기만 하면 플랫폼을 만들 수 있게")
##   ① 재질 5종  assets/textures/smartshape/지형_<한글>.tres
##      = SS2D_Material_Shape (내부 채움 black_<slug>_fill + 테두리 4방향 black_<slug>_edge)
##   ② 템플릿 씬 5종  scenes/집/발판_<한글>.tscn
##      = 루트가 `스마트지형` 노드 하나. 재질을 미리 물려두고 기본 사각 발판을 넣어둔다.
##      작업자는 이 .tscn 을 스테이지에 **드래그**해 넣고 점만 끌어 지형을 성형하면 된다.
##
## ▣ 왜 흑(black) 텍스처만 참조하나
##   페인트 셰이더가 런타임에 white_ 짝을 찾아 스왑한다(지형.gd _짝_텍스처). 재질은
##   기본 아트(검정)만 가리키면 되고, 칠하면 흰색으로 바뀐다. 기존 지형_기본.tres 와 동일.
##
## ▣ ★설계상 함정 — 스마트지형은 @tool 이라 트리에 들어가면 _ready 가 돈다
##   _ready 는 shape_material 을 **인스턴스별로 깊은 복사**한다(여러 지형이 재질을 공유하다
##   한 곳을 칠하면 다 같이 칠해지는 걸 막으려고). 만약 템플릿을 짤 때 노드를 활성 트리
##   (get_root())에 넣으면, pack 될 때 그 복제된 재질이 씬에 통째로 구워져 공유가 깨진다.
##   → 그래서 여기서는 노드를 **활성 트리에 넣지 않고** 오프라인으로 조립해서 pack 한다.
##     (build_smartshape_demo.gd 가 SS2D_Shape_Closed 로 쓰던 것과 같은 안전 패턴)
##
## ▣ 멱등: 항상 원본 텍스처에서 다시 만들어 덮어쓴다. 여러 번 돌려도 결과 동일.
## ============================================================================

const 스마트지형_S := preload("res://scripts/스마트월드/지형.gd")
const 공통 := preload("res://tools/지형공통.gd")

const 텍스처_폴더 := "res://assets/textures/smartshape/"
const 재질_폴더 := "res://assets/textures/smartshape/"
const 템플릿_폴더 := "res://scenes/집/"

## slug(영문 파일 이름) → 한글 이름표. 슬라이서와 반드시 같은 표.
const 타일셋들 := {
	"brick": "벽돌",
	"wood": "나무",
	"soil": "흙",
	"grass": "잔디",
	"rock": "바위",
}

## 테두리 4방향 → 노멀 범위 [시작각, 폭]. (SS2D: 0°=오른쪽,90°=위,180°=왼,270°=아래)
##   같은 edge 텍스처를 네 방향에 다 물려 사방을 브릭/나무 테두리로 감싼다.
const 노멀범위 := {
	"위": [45.0, 90.0],
	"오른쪽": [315.0, 90.0],
	"아래": [225.0, 90.0],
	"왼쪽": [135.0, 90.0],
}
const 그리는순서 := ["아래", "왼쪽", "오른쪽", "위"]   ## 위쪽 테두리가 제일 위로 오게

## 템플릿 기본 발판 크기(px). 작업자가 드래그 후 점을 끌어 바꾼다.
const 기본_크기 := Vector2(384, 128)


func _init() -> void:
	var 실패 := 0
	for slug in 타일셋들.keys():
		실패 += _재질_만들기(slug)
	for slug in 타일셋들.keys():
		실패 += _템플릿_만들기(slug)
	print("\n[스마트매쉬_2_재질과템플릿] 완료 — 실패 %d건" % 실패)
	quit(실패)


# ============================================================================
# ① 재질 .tres
# ============================================================================
func _재질_만들기(slug: String) -> int:
	var fill_경로 := "%sblack_%s_fill.png" % [텍스처_폴더, slug]
	var edge_경로 := "%sblack_%s_edge.png" % [텍스처_폴더, slug]
	if not ResourceLoader.exists(fill_경로) or not ResourceLoader.exists(edge_경로):
		push_error("[%s] 조각 텍스처가 없다 — 슬라이서/임포트 먼저" % slug)
		return 1

	var 재질 := SS2D_Material_Shape.new()

	# 내부 채움 — Array[Texture2D] 타입을 정확히 맞춰야 한다(그냥 [] 는 조용히 실패).
	var 채움: Array[Texture2D] = [load(fill_경로)]
	재질.fill_textures = 채움
	재질.fill_texture_z_index = -1        # 채움은 테두리보다 뒤

	# 테두리 4방향 — 같은 edge 텍스처를 네 방향에 재사용(사방을 감싼다)
	var edge_tex: Texture2D = load(edge_경로)
	var 메타들: Array[SS2D_Material_Edge_Metadata] = []
	for 슬롯 in 그리는순서:
		var 테두리 := SS2D_Material_Edge.new()
		var t: Array[Texture2D] = [edge_tex]
		테두리.textures = t
		테두리.use_corner_texture = false
		테두리.use_taper_texture = false
		# 조각 길이가 변에 딱 안 맞을 때 늘리기보다 눌러 맞추면 이음새가 덜 튄다.
		테두리.fit_mode = SS2D_Material_Edge.FITMODE.SQUISH_AND_STRETCH

		var 메타 := SS2D_Material_Edge_Metadata.new()
		메타.edge_material = 테두리
		메타.normal_range = SS2D_NormalRange.new(노멀범위[슬롯][0], 노멀범위[슬롯][1])
		메타.weld = true
		메타.z_index = 1 if 슬롯 == "위" else 0
		메타들.push_back(메타)
	재질.set_edge_meta_materials(메타들)

	var 경로 := "%s지형_%s.tres" % [재질_폴더, 타일셋들[slug]]
	var e := ResourceSaver.save(재질, 경로)
	if e != OK:
		push_error("재질 저장 실패 %s: %s" % [경로, error_string(e)])
		return 1
	print("  재질 → %s" % 경로)
	return 0


# ============================================================================
# ② 드래그 템플릿 씬 .tscn
# ============================================================================
func _템플릿_만들기(slug: String) -> int:
	var 재질경로 := "%s지형_%s.tres" % [재질_폴더, 타일셋들[slug]]
	if not ResourceLoader.exists(재질경로):
		push_error("[%s] 재질이 없다 — 재질 단계 먼저" % slug)
		return 1

	# ── 루트 = 스마트지형(칠 가능 발판) ──
	# ⚠ 활성 트리에 넣지 않는다(위 머리말: _ready 재질 복제 방지). .new() 로만 조립한다.
	var 지형: SS2D_Shape_Closed = 스마트지형_S.new()
	지형.name = "발판_%s" % 타일셋들[slug]
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 픽셀아트 필수(전역 기본 Linear)
	지형.set("칠하기_허용", true)                              # 발판이라 칠할 수 있다(색 퍼즐)
	지형.set("무색일때_통과", false)                           # 안 칠해도 밟히는 실체 발판

	# 기본 사각 발판 점(닫힌 도형). 화면좌표(y 아래)에서 시계방향: TL→TR→BR→BL.
	# (지형규칙.닫기 주석의 감김 방향과 동일 — 방향이 섞이면 콜리전 볼록분해가 깨진다)
	var w := 기본_크기.x * 0.5
	var h := 기본_크기.y * 0.5
	var 점들 := PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h),
	])
	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()   # 시작점을 손으로 또 넣지 말 것(중복점=삼각분할 깨짐)

	# ── 콜리전 (지형 밑에 StaticBody2D → CollisionPolygon2D) ──
	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	지형.collision_size = 24.0
	# 헤드리스로 만든 씬도 게임에서 밟히도록 EditorAndRuntime(=2). 실행 시 다시 굽는다.
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime
	# 지금 당장 폴리곤도 채워 넣는다(bake_collision 은 editor_hint 를 봐서 헤드리스에선 생략됨).
	폴리.polygon = _콜리전_폴리곤(지형)

	# owner 지정 후 pack (인스턴스 내부는 안 건드림 — 여기엔 인스턴스가 없다)
	공통.주인_지정(지형, 지형)
	var 팩 := PackedScene.new()
	var e := 팩.pack(지형)
	if e != OK:
		push_error("[%s] pack 실패: %s" % [slug, error_string(e)])
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(템플릿_폴더))
	var 경로 := "%s발판_%s.tscn" % [템플릿_폴더, 타일셋들[slug]]
	e = ResourceSaver.save(팩, 경로)
	if e != OK:
		push_error("[%s] 템플릿 저장 실패: %s" % [slug, error_string(e)])
		return 1
	print("  템플릿 → %s" % 경로)
	return 0


## 닫힌 지형의 콜리전 폴리곤을 SS2D 생성기로 직접 만든다(변환 없는 자식이라 좌표 보정 불필요).
func _콜리전_폴리곤(지형: SS2D_Shape_Closed) -> PackedVector2Array:
	var 생성기 := SS2D_CollisionGen.new()
	생성기.collision_size = 지형.collision_size
	생성기.collision_offset = 지형.collision_offset
	return 생성기.generate_filled(지형.get_point_array().get_tessellated_points())
