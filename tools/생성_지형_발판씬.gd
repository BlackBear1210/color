extends SceneTree
## ============================================================================
## [2026-08-24 신규] 레벨 작업자용 SmartShape2D 발판 씬 생성기 (재질 무관 · 멱등)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_지형_발판씬.gd
##
## ▣ 목적
##   레벨 작업자가 FileSystem 에서 씬을 끌어다 놓고 바로 지형을 찍을 수 있게 한다.
##   씬에는 지형 노드 + 머티리얼 + 콜리전만 넣는다. Player/Camera/게임로직은 안 넣는다.
##
## ▣ 기존 프로젝트 규칙을 따른다 (임의 구조를 강제하지 않는다)
##   기존: scenes/집/스마트 매쉬 assets/발판_<재질>.tscn  ->  지형_<재질>.tres
##   루트는 단순 SS2D 노드가 아니라 **지형.gd (class_name 스마트지형)** 이다.
##   collision_* 속성과 StaticBody2D/CollisionPolygon2D 자식이 있어야 밟을 수 있다.
##
## ▣ 흑/백을 왜 머티리얼로 안 나누나
##   이 게임에서 색은 **런타임 상태**다. 지형.gd 가 black_ 텍스처의 white_ 짝을 찾아
##   페인트 셰이더에 물리고, 총에 맞으면 검정↔흰색이 섞인다.
##   '흰색 전용 머티리얼' 을 만들면 그 지형은 검정으로 칠할 수 없게 되어 규칙이 깨진다.
##   그래서 머티리얼은 재질당 하나(검정 텍스처 기반)이고,
##   흑/백은 `시작상태` export 로만 다르게 둔다.
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 폴더 := "res://scenes/집/스마트 매쉬 assets"

## [재질키, 표시이름, 채움 머티리얼, 속빔 머티리얼, 폴더이름]
## ★ 폴더 이름에 영문 키워드를 같이 넣는다 — 작업자가 BRICK/SEWER/WOOD/GRASS 로도,
##   벽돌/하수/나무/잔디 로도 찾을 수 있게 하려는 것이다.
const 재질표 := [
	["잔디v4", "잔디",
		"res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres",
		"res://assets/textures/smartshape/grass_v4/tres/지형_잔디v4_black_detail_속빔.tres",
		"GRASS_잔디"],
	["벽돌v1", "벽돌",
		"res://assets/textures/smartshape/brick_v1/tres/지형_벽돌v1_black_detail.tres",
		"res://assets/textures/smartshape/brick_v1/tres/지형_벽돌v1_black_detail_속빔.tres",
		"BRICK_벽돌"],
	["하수v1", "하수",
		"res://assets/textures/smartshape/sewer_v1/tres/지형_하수v1_black_detail.tres",
		"res://assets/textures/smartshape/sewer_v1/tres/지형_하수v1_black_detail_속빔.tres",
		"SEWER_하수"],
	["나무v1", "나무",
		"res://assets/textures/smartshape/wood_v1/tres/지형_나무v1_black_detail.tres",
		"res://assets/textures/smartshape/wood_v1/tres/지형_나무v1_black_detail_속빔.tres",
		"WOOD_나무"],
]

## [파일이름틀, 시작상태(지형.gd 의 enum 값), 속빔여부]
## enum 상태 { 무색=0, 검정=1, 흰색=2, 회색=3 }
##
## ★ 이름만 보고 용도를 알 수 있게 짓는다 (작업자용 규칙)
##   발판_*_채움 = SOLID  (내부가 꽉 찬 지형 · 평소에 쓰는 것)
##   발판_*_속빔 = HOLLOW (내부가 진짜 투명한 테두리 지형)
##   프리뷰_*    = 시작상태만 다르게 둔 확인용. 맵에 그냥 써도 되지만
##                 색은 런타임이 바꾸므로 보통은 '채움' 을 쓰고 시작상태만 고른다.
const 변형표 := [
	["발판_%s_채움", 0, false],
	["발판_%s_속빔", 0, true],
	["프리뷰_%s_검정", 1, false],
	["프리뷰_%s_흰색", 2, false],
]

## 기본 발판 크기 (기존 발판_잔디.tscn 과 같은 384 x 128)
const 반폭 := 192.0
const 반높이 := 64.0


func _init() -> void:
	call_deferred("_실행")


func _만들기(이름: String, 머티경로: String, 시작상태: int) -> bool:
	if not ResourceLoader.exists(머티경로):
		push_error("머티리얼 없음: %s" % 머티경로)
		return false
	var n = 지형_S.new()
	n.name = 이름
	root.add_child(n)

	# 점 4개로 닫힌 사각형. 작업자는 이걸 잡아 늘리거나 점을 추가해서 지형을 만든다.
	var pa: SS2D_Point_Array = n.get_point_array()
	pa.begin_update()
	pa.add_points(PackedVector2Array([
		Vector2(-반폭, -반높이), Vector2(반폭, -반높이),
		Vector2(반폭, 반높이), Vector2(-반폭, 반높이)]))
	pa.end_update()
	pa.close_shape()

	n.shape_material = load(머티경로)
	n.시작상태 = 시작상태

	# 콜리전 — 기존 발판 씬과 같은 설정. 이게 없으면 밟을 수 없다.
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	n.add_child(body)
	var poly := CollisionPolygon2D.new()
	poly.name = "CollisionPolygon2D"
	body.add_child(poly)
	n.collision_update_mode = 2          # 2 = 에디터에서도 갱신
	n.collision_size = 24.0
	n.collision_polygon_node_path = NodePath("StaticBody2D/CollisionPolygon2D")

	n.force_update()

	# owner 는 **새로 만든 노드에만** 준다 (CLAUDE.md 규칙 6).
	body.owner = n
	poly.owner = n

	var packed := PackedScene.new()
	if packed.pack(n) != OK:
		push_error("pack 실패: %s" % 이름)
		return false
	var 경로 := "%s/%s.tscn" % [폴더, 이름]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(경로.get_base_dir()))
	if ResourceSaver.save(packed, 경로) != OK:
		push_error("저장 실패: %s" % 경로)
		return false
	n.queue_free()
	root.remove_child(n)
	print("  %s" % 경로.replace("res://scenes/집/스마트 매쉬 assets/", ""))
	return true


func _실행() -> void:
	var 수 := 0
	for 재질 in 재질표:
		var 표시: String = 재질[1]
		var 폴더이름: String = 재질[4]
		for 변형 in 변형표:
			var 틀: String = 변형[0]
			var 상태: int = 변형[1]
			var 속빔: bool = 변형[2]
			var 머티: String = 재질[3] if 속빔 else 재질[2]
			# 재질별 하위 폴더에 넣어 파일 목록이 안 뒤엉키게 한다.
			# 기존 발판_*.tscn 5개는 루트에 그대로 둔다 (건드리지 않는다).
			var 이름 := "%s/%s" % [폴더이름, 틀 % 표시]
			if _만들기(이름, 머티, 상태):
				수 += 1
	print("\n작업자 씬 %d 개 생성 (재질 %d x 용도 %d)" % [수, 재질표.size(), 변형표.size()])
	quit(0)
