extends SceneTree
## ============================================================================
## [2026-08-25 개정] 작업자용 Template 씬 생성기 (STEP 2.7 Production Handoff)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_지형_발판씬.gd
##
## ▣ 목적
##   맵 작업자가 **복제해서 쓰는 템플릿**을 만든다. 쇼케이스가 아니다.
##   작업자는 이 씬을 복제 → SmartShape2D 점 편집 → 저장, 이 세 가지만 하면 된다.
##   texture / material / baker / UV / corner 는 절대 만질 필요가 없어야 한다.
##
## ▣ 재질 (STEP 2.7 기준)
##   PRODUCTION : GRASS v4(LOCK) · BRICK v2 · WOOD v2
##   PROVISIONAL: IRON v1 — 아직 굽지 않았고 작업자에게 제공하지 않는다.
##   SEWER v1 은 IRON 으로 대체될 예정이라 템플릿에서 뺐다 (에셋 자체는 남아 있다).
##
## ▣ 이름 규칙
##   TEMPLATE_<재질>_<SOLID|HOLLOW>.tscn — 이름만 보고 용도를 알 수 있게.
##   폴더 이름에는 한글을 같이 둔다 (영문/한글 어느 쪽으로 찾아도 나오게).
##
## ▣ 시작 크기 = 512 x 192
##   두께 192px 는 '공중 발판 권장 두께 180px 이상' 을 이미 만족한다.
##   (엣지 띠 한 장이 89.6 월드px 이라 180px 보다 얇으면 위아래 띠가 겹쳐
##    FILL 이 사라지고 검은 막대처럼 보인다 — 실측으로 확인했다)
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 폴더 := "res://scenes/집/스마트 매쉬 assets"
const T := "res://assets/textures/smartshape"

## [영문키, 폴더이름, 채움 머티리얼, 속빔 머티리얼]
const 재질표 := [
	["GRASS", "GRASS_잔디",
		T + "/grass_v4/tres/지형_잔디_v4_black_detail.tres",
		T + "/grass_v4/tres/지형_잔디v4_black_detail_속빔.tres"],
	["BRICK", "BRICK_벽돌",
		T + "/brick_v2/tres/지형_벽돌v2_black_detail.tres",
		T + "/brick_v2/tres/지형_벽돌v2_black_detail_속빔.tres"],
	["WOOD", "WOOD_나무",
		T + "/wood_v2/tres/지형_나무v2_black_detail.tres",
		T + "/wood_v2/tres/지형_나무v2_black_detail_속빔.tres"],
]

## [꼬리, 속빔여부, 계단여부]
## STAIRS 는 새로운 시스템이 아니다 — SOLID 와 완전히 같은 머티리얼이고
## **점 배치만 계단 모양으로 미리 잡아 둔 것**이다. 작업자가 매번 치수를 외우지 않아도 되게.
const 변형표 := [
	["SOLID", false, false],
	["HOLLOW", true, false],
	["STAIRS", false, true],
]

const 반폭 := 256.0
const 반높이 := 96.0

## 계단 확정 치수 (STEP 2.8 실측)
##   폭 180 — 코너 쿼드 89.6px 보다 넉넉히 커야 코너가 안 겹친다
##   높이 110 — 올라갈 수 있는 한계는 점프 높이 160 x 0.8 = 128px 다. 넘으면 못 올라간다.
const 계단폭 := 180.0
const 계단높이 := 110.0
const 계단수 := 4


func _init() -> void:
	call_deferred("_실행")


## 계단 점 배치. ★ 마지막에 **밟을 수 있는 수평 발판**을 반드시 둔다.
##   이걸 빼면 꼭대기가 폭 0 짜리 수직선이 되어 밟을 면이 없다 (STEP 2.8 에서 한 번 겪음).
func _계단점() -> PackedVector2Array:
	var 총폭: float = 계단폭 * float(계단수 + 1)
	var 총높이: float = 계단높이 * float(계단수)
	var x: float = -총폭 * 0.5
	var y: float = 총높이 * 0.5
	var p := PackedVector2Array()
	p.push_back(Vector2(x, y))
	for i in 계단수:
		x += 계단폭
		p.push_back(Vector2(x, y))
		y -= 계단높이
		p.push_back(Vector2(x, y))
	x += 계단폭                     # 꼭대기 발판
	p.push_back(Vector2(x, y))
	var 바닥: float = 총높이 * 0.5 + 반높이 * 2.0
	p.push_back(Vector2(x, 바닥))
	p.push_back(Vector2(-총폭 * 0.5, 바닥))
	return p


func _만들기(폴더이름: String, 이름: String, 머티경로: String, 계단: bool = false) -> bool:
	if not ResourceLoader.exists(머티경로):
		push_error("머티리얼 없음: %s" % 머티경로)
		return false
	var n = 지형_S.new()
	n.name = 이름
	root.add_child(n)

	# 시작 도형: 점 4개 사각형. 작업자는 이걸 잡아 늘리거나 점을 추가한다.
	var pa: SS2D_Point_Array = n.get_point_array()
	pa.begin_update()
	if 계단:
		pa.add_points(_계단점())
	else:
		pa.add_points(PackedVector2Array([
			Vector2(-반폭, -반높이), Vector2(반폭, -반높이),
			Vector2(반폭, 반높이), Vector2(-반폭, 반높이)]))
	pa.end_update()
	pa.close_shape()

	n.shape_material = load(머티경로)
	n.시작상태 = 0                        # 무색 — 색은 런타임이 정한다

	# 콜리전 — 이게 없으면 밟을 수 없다
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	n.add_child(body)
	var poly := CollisionPolygon2D.new()
	poly.name = "CollisionPolygon2D"
	body.add_child(poly)
	n.collision_update_mode = 2
	n.collision_size = 24.0
	n.collision_polygon_node_path = NodePath("StaticBody2D/CollisionPolygon2D")

	n.force_update()

	# owner 는 **새로 만든 노드에만** 준다 (CLAUDE.md 규칙 6)
	body.owner = n
	poly.owner = n

	var packed := PackedScene.new()
	if packed.pack(n) != OK:
		push_error("pack 실패: %s" % 이름)
		return false
	var 경로 := "%s/%s/%s.tscn" % [폴더, 폴더이름, 이름]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(경로.get_base_dir()))
	if ResourceSaver.save(packed, 경로) != OK:
		push_error("저장 실패: %s" % 경로)
		return false
	n.queue_free()
	root.remove_child(n)
	print("  %s/%s.tscn" % [폴더이름, 이름])
	return true


func _실행() -> void:
	var 수 := 0
	for 재질 in 재질표:
		for 변형 in 변형표:
			var 머티: String = 재질[3] if 변형[1] else 재질[2]
			var 이름 := "TEMPLATE_%s_%s" % [재질[0], 변형[0]]
			if _만들기(재질[1], 이름, 머티, 변형[2]):
				수 += 1
	print("\nTemplate 씬 %d 개 (재질 %d x SOLID/HOLLOW/STAIRS)" % [수, 재질표.size()])
	quit(0 if 수 == 재질표.size() * 변형표.size() else 1)
