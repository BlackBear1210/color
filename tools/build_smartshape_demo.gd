extends SceneTree
## ============================================================================
## [2026-08-01 신규] SmartShape2D 적용 데모 생성기
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_smartshape_demo.gd
##
## ▣ 무엇을 만드나
##   ① `assets/textures/smartshape/검정_지형.tres` / `흰색_지형.tres`
##      = SS2D_Material_Shape (내부채우기 + 위/아래/좌/우 테두리 4종 묶음)
##   ② `scenes/smartshape_test/스마트셰이프_테스트.tscn`
##      = 검정 지형 1개 + 흰색 지형 1개 + 카메라 + 회색 배경. 눈으로 확인하는 용도.
##
## ▣ 왜 코드로 만드나
##   .tres 안의 배열(fill_textures / _edge_meta_materials)을 손으로 채우면 클릭이 40번쯤
##   필요하다. 여기서 한 번 만들어두면 에디터에서는 값만 만져보면 된다.
##   ★ 만들고 나면 이 스크립트는 다시 돌릴 필요 없다. 에디터에서 .tres 를 직접 수정하고
##     이 스크립트를 다시 돌리면 **수정분이 날아간다** (덮어쓰기).
##
## ▣ 텍스처 방향 규칙 (SS2D 노멀 각도)
##   0°=오른쪽, 90°=위, 180°=왼쪽, 270°=아래.  (화면 기준. y 는 아래로 증가)
##   각 테두리는 "이 방향을 바라보는 변에만 그려라" 를 begin/distance 로 지정한다.
## ============================================================================

const 텍스처_폴더 := "res://assets/textures/smartshape/"
const 씬_폴더 := "res://scenes/smartshape_test/"

## 색깔별 텍스처 이름표.
## 파일이 없으면 그 슬롯만 조용히 건너뛴다 (아트가 추가되면 자동으로 반영됨).
const 색상표 := {
	"검정": {
		"채우기": ["black_fill"],
		"위": ["black_center", "black_center2"],
		"아래": ["black_bottom_center"],
		"왼쪽": ["black_left", "black_left2"],
		"오른쪽": ["black_right", "black_right2"],
		"모서리바깥": ["black_bottom_left", "black_bottom_right"],
	},
	"흰색": {
		"채우기": ["white_fill"],
		"위": ["white_center", "white_center2"],
		"아래": ["white_bottom_center"],
		"왼쪽": ["white_left", "white_left2"],
		"오른쪽": ["white_right", "white_right2"],
		"모서리바깥": ["white_bottom_left", "white_bottom_right"],
	},
}

## 테두리 슬롯 → 노멀 범위 [시작각, 폭].
##   위   : 45~135  (위를 보는 변)
##   오른쪽: 315~45
##   아래 : 225~315
##   왼쪽 : 135~225
const 노멀범위 := {
	"위": [45.0, 90.0],
	"오른쪽": [315.0, 90.0],
	"아래": [225.0, 90.0],
	"왼쪽": [135.0, 90.0],
}

## 테두리를 그리는 순서(=겹칠 때 누가 위로 오나). 위쪽 풀이 제일 잘 보여야 한다.
const 그리는순서 := ["아래", "왼쪽", "오른쪽", "위"]


func _init() -> void:
	var 실패 := 0
	for 색 in 색상표.keys():
		실패 += _머티리얼_만들기(색)
	실패 += _데모씬_만들기()
	print("\n[build_smartshape_demo] 완료 — 실패 %d 건" % 실패)
	quit(실패)


# ============================================================================
# ① SS2D_Material_Shape 만들기
# ============================================================================
func _머티리얼_만들기(색: String) -> int:
	var 정보: Dictionary = 색상표[색]
	var 재질 := SS2D_Material_Shape.new()

	# ── 내부 채우기 ───────────────────────────────────────────────────────
	# fill_textures 는 Array[Texture2D] 타입이라 반드시 타입을 맞춰서 넣어야 한다.
	# (그냥 [] 를 넣으면 "Invalid assignment" 로 조용히 실패한다)
	var 채우기: Array[Texture2D] = _텍스처들(정보["채우기"])
	if 채우기.is_empty():
		push_error("[%s] 채우기 텍스처를 못 찾음 — 중단" % 색)
		return 1
	재질.fill_textures = 채우기
	# 채우기는 테두리보다 뒤에 깔린다 (기본 -10 유지).
	재질.fill_texture_scale = 1.0

	# ── 테두리 4종 ───────────────────────────────────────────────────────
	var 메타들: Array[SS2D_Material_Edge_Metadata] = []
	for 슬롯 in 그리는순서:
		var 텍스처: Array[Texture2D] = _텍스처들(정보[슬롯])
		if 텍스처.is_empty():
			print("  [%s] '%s' 테두리 텍스처 없음 — 건너뜀" % [색, 슬롯])
			continue

		var 테두리 := SS2D_Material_Edge.new()
		테두리.textures = 텍스처
		# 모서리(급격히 꺾이는 지점)용 조각. 없으면 use_corner_texture 를 꺼야
		# 빈 텍스처로 구멍이 뚫린 것처럼 보이지 않는다.
		var 모서리: Array[Texture2D] = _텍스처들(정보["모서리바깥"])
		if 슬롯 == "아래" and not 모서리.is_empty():
			테두리.textures_corner_outer = 모서리
			테두리.use_corner_texture = true
		else:
			테두리.use_corner_texture = false
		# 타일셋 조각이라 길이가 딱 안 맞으면 늘어나는 것보다 잘리는 게 덜 어색하다.
		테두리.fit_mode = SS2D_Material_Edge.FITMODE.SQUISH_AND_STRETCH
		테두리.use_taper_texture = false

		var 메타 := SS2D_Material_Edge_Metadata.new()
		메타.edge_material = 테두리
		메타.normal_range = SS2D_NormalRange.new(노멀범위[슬롯][0], 노멀범위[슬롯][1])
		메타.weld = true
		# 위쪽 풀이 채우기 위로 확실히 올라오도록 z 를 살짝 띄운다.
		메타.z_index = 1 if 슬롯 == "위" else 0
		메타들.push_back(메타)

	재질.set_edge_meta_materials(메타들)

	var 경로 := "%s%s_지형.tres" % [텍스처_폴더, 색]
	var err := ResourceSaver.save(재질, 경로)
	if err != OK:
		push_error("저장 실패 %s : %s" % [경로, error_string(err)])
		return 1
	print("  저장 → %s (테두리 %d종)" % [경로, 메타들.size()])
	return 0


## 이름 목록 → 실제로 존재하는 텍스처만 골라 타입 배열로.
func _텍스처들(이름들: Array) -> Array[Texture2D]:
	var 결과: Array[Texture2D] = []
	for 이름 in 이름들:
		var 경로 := "%s%s.png" % [텍스처_폴더, 이름]
		if not ResourceLoader.exists(경로):
			continue
		var t := load(경로) as Texture2D
		if t:
			결과.push_back(t)
	return 결과


# ============================================================================
# ② 데모 씬 만들기
# ============================================================================
func _데모씬_만들기() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(씬_폴더))

	var 루트 := Node2D.new()
	루트.name = "스마트셰이프_테스트"

	# 배경 — 검정/흰색 지형을 둘 다 알아보려면 중간 회색이 필요하다.
	var 배경 := ColorRect.new()
	배경.name = "배경"
	배경.color = Color(0.45, 0.45, 0.48)
	배경.position = Vector2(-200, -200)
	배경.size = Vector2(2400, 1500)
	배경.z_index = -100
	배경.mouse_filter = Control.MOUSE_FILTER_IGNORE
	루트.add_child(배경)

	var 카메라 := Camera2D.new()
	카메라.name = "카메라"
	카메라.position = Vector2(700, 380)
	카메라.zoom = Vector2(1.4, 1.4)   # 16px 픽셀아트라 확대해야 테두리가 보인다
	루트.add_child(카메라)

	# 지형 두 덩어리. 윗면을 울퉁불퉁하게 해서 "유기적 지형" 느낌을 확인한다.
	var 검정_점 := PackedVector2Array([
		Vector2(0, 0), Vector2(120, -34), Vector2(260, 12), Vector2(400, -26),
		Vector2(540, 6), Vector2(660, -18), Vector2(660, 210), Vector2(0, 210),
	])
	var 흰색_점 := PackedVector2Array([
		Vector2(760, 60), Vector2(880, 22), Vector2(1030, 66), Vector2(1160, 30),
		Vector2(1300, 58), Vector2(1300, 260), Vector2(760, 260),
	])

	루트.add_child(_지형_만들기("검정_지형", "검정", 검정_점, Vector2(120, 300)))
	루트.add_child(_지형_만들기("흰색_지형", "흰색", 흰색_점, Vector2(120, 300)))

	# owner 를 루트로 지정해야 PackedScene 에 자식이 실제로 담긴다 (안 하면 빈 씬이 저장됨).
	_주인_지정(루트, 루트)

	var 팩 := PackedScene.new()
	var err := 팩.pack(루트)
	if err != OK:
		push_error("pack 실패: %s" % error_string(err))
		return 1
	var 경로 := 씬_폴더 + "스마트셰이프_테스트.tscn"
	err = ResourceSaver.save(팩, 경로)
	if err != OK:
		push_error("씬 저장 실패: %s" % error_string(err))
		return 1
	print("  저장 → %s" % 경로)
	return 0


func _지형_만들기(이름: String, 색: String, 점들: PackedVector2Array, 위치: Vector2) -> SS2D_Shape_Closed:
	var 지형 := SS2D_Shape_Closed.new()
	지형.name = 이름
	지형.position = 위치
	지형.shape_material = load("%s%s_지형.tres" % [텍스처_폴더, 색])

	# 픽셀아트라 확대·축소될 때 뭉개지지 않게 Nearest 로 고정한다.
	# (프로젝트 전역 기본값은 Linear 이므로 노드마다 켜줘야 한다)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 3.3 부터 shape.add_points() 는 deprecated — point_array 를 직접 다뤄야 한다.
	지형.get_point_array().add_points(점들)
	# 닫힌 도형은 마지막 점을 직접 이어붙이지 말고 반드시 close_shape() 로 닫는다.
	# 손으로 시작점을 한 번 더 넣으면 "같은 자리 점 2개" 가 되어 삼각분할이 깨진다.
	지형.get_point_array().close_shape()

	# ── 콜리전 ───────────────────────────────────────────────────────────
	# 에디터 툴바 버튼이 하는 일과 같은 구성: 지형 밑에 StaticBody2D → CollisionPolygon2D.
	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	# 그림(테두리 두께)과 충돌면을 맞추는 값. 게임 타일 32px 에 맞춰 시작한다.
	지형.collision_size = 32.0
	# 기본값 Editor 는 "에디터에서만 굽는다" 라서, 이 스크립트(헤드리스)로 만든 씬은
	# 폴리곤이 빈 채로 저장되고 게임에서 밟을 수 없다.
	# EditorAndRuntime = 에디터에서도 굽고 실행할 때도 다시 굽는다 → 어느 쪽이든 안전.
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime

	# 위와 별개로, 지금 당장 폴리곤을 채워 넣는다.
	# bake_collision() 은 Engine.is_editor_hint() 를 보기 때문에 여기선 안 돈다 →
	# 생성기(SS2D_CollisionGen)를 직접 불러서 .tscn 에 좌표가 남게 한다.
	# (CollisionPolygon2D 가 지형의 자식이고 변환이 없으므로 좌표 보정은 불필요)
	var 생성기 := SS2D_CollisionGen.new()
	생성기.collision_size = 지형.collision_size
	생성기.collision_offset = 지형.collision_offset
	폴리.polygon = 생성기.generate_filled(지형.get_point_array().get_tessellated_points())
	return 지형


## 노드 트리 전체의 owner 를 씬 루트로 지정.
func _주인_지정(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		자식.owner = 루트
		_주인_지정(자식, 루트)
