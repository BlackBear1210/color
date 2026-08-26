extends SceneTree
## ============================================================================
## [2026-08-27 신규] 작업자 Template 에 **사방 미터 조인 재질**을 적용한다
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/적용_사방재질.gd
## 검증:  godot --headless --path . -s res://tools/진단_콜리전대_그림.gd
##        godot --headless --path . -s res://tools/검증_작업자씬.gd
##
## ▣ 왜 (도형님 제보 3 가지가 전부 같은 원인이었다)
##   ① "지형 플랫폼에 물리작용이 너무 안쪽으로 되어 있다"
##   ② "잔디 말고 다른 타일셋들은 전부 코너가 이상하다"
##   ③ "코너 부분을 보면 지형 플랫폼들이 전부 안 칠해진다"
##
##   셋 다 **구형 재질 구성**(방향별 엣지 4 + taper 8 + 코너 전용 메타) 때문이다.
##     · 엣지 텍스처 1024×256 을 `texture_scale 0.35` 로 쓰면 띠 두께가 89.6px 이고,
##       SS2D 는 이 띠를 외곽선에 **가운데 정렬**로 그린다 → 사방 44.8px 이 도형 밖으로.
##       실측: 그림이 콜리전보다 위·아래·좌·우 **+44.8px** (①의 정체)
##     · 한 모서리에 방향 엣지·taper·코너 쿼드가 겹쳐 뾰족점·두께 불균일 (②)
##     · `지형.gd _셰이더_설치()` 는 **코너 텍스처를 든 메타를 건너뛴다**
##       (그 메타의 기본 텍스처는 투명 캐리어라 흰색 짝이 없다)
##       → 코너 쿼드에 페인트 셰이더가 안 붙어 총을 맞아도 코너만 안 변한다 (③)
##
##   성진님이 WOOD 에 적용한 **360° 단일 엣지 + `offset = -1.0`** 이 셋을 한 번에 없앤다.
##   (docs/작업기록_2026-08-27_성진_WOOD_SOLID_사방미터조인.md)
##   여기서는 같은 처방을 **BRICK 전부 + WOOD HOLLOW** 로 넓힌다.
##
## ▣ GRASS 는 일부러 안 건드린다
##   grass_v4 는 `PRODUCTION LOCK` 이고, 도형님도 "잔디는 괜찮다" 고 했다.
##   잔디는 **윗면만 잔디 · 옆·아랫면은 흙**이라 방향별 엣지가 그 그림의 핵심이다.
##   360° 단일 엣지로 바꾸면 사방에 잔디가 자란 모양이 되어 아트가 망가진다.
##   → 잔디는 그대로 두고, 필요해지면 아트 판단을 받아 따로 처리한다.
##     (잔디는 집 챕터에서 안 쓰인다 — 숲 챕터 전용)
##
## ⚠ 트리에 넣지 않는다. 넣으면 `지형.gd _ready()` 가 `shape_material` 을 깊은 복사해
##   페인트 셰이더가 박힌 재질이 Template 에 저장된다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const 벽돌_사방 := "res://assets/textures/smartshape/brick_v2/tres/지형_벽돌v2_black_detail_사방.tres"
const 벽돌_속빔_사방 := "res://assets/textures/smartshape/brick_v2/tres/지형_벽돌v2_black_detail_속빔_사방.tres"
const 나무_속빔_사방 := "res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_속빔_사방.tres"

## [Template 경로, 새 재질]
const 할일 := [
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn", 벽돌_사방],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_STAIRS.tscn", 벽돌_사방],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_HOLLOW.tscn", 벽돌_속빔_사방],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_HOLLOW.tscn", 나무_속빔_사방],
]


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 작업자 Template 사방 재질 적용 ===")
	var 실패 := 0
	for 줄 in 할일:
		if not _바꾸기(String(줄[0]), String(줄[1])):
			실패 += 1
	print("=== 끝 (실패 %d) ===\n" % 실패)
	quit(0 if 실패 == 0 else 1)


func _바꾸기(씬경로: String, 재질경로: String) -> bool:
	var 팩 := load(씬경로) as PackedScene
	if 팩 == null:
		push_error("씬을 못 읽음: %s" % 씬경로)
		return false
	var 재질 := load(재질경로) as Resource
	if 재질 == null:
		push_error("재질을 못 읽음: %s" % 재질경로)
		return false

	# ⚠ 트리에 넣지 않는다(위 주석 참고).
	var 루트: Node = 팩.instantiate()
	if not 루트.has_method("get_point_array"):
		push_error("루트가 스마트지형이 아님: %s" % 씬경로)
		return false

	루트.set("shape_material", 재질)

	# 구운 메시를 비운다. 표준 씬(인스턴스가 아님)이라 빈 배열은 저장되지 않고,
	# 로드할 때 `지형.gd _ready()` 의 `_meshes.clear()` + `force_update()` 가 새로 굽는다.
	var 빈: Array[SS2D_Mesh] = []
	루트.set("_meshes", 빈)

	# 콜리전도 지금 점으로 다시 굽는다(에디터에서 열자마자 맞게 보이도록).
	var 폴리 := 루트.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		var 생성기 := SS2D_CollisionGen.new()
		생성기.collision_size = 루트.get("collision_size")
		생성기.collision_offset = 루트.get("collision_offset")
		폴리.polygon = 생성기.generate_filled(루트.get_point_array().get_tessellated_points())

	var 새팩 := PackedScene.new()
	var e := 새팩.pack(루트)
	if e != OK:
		push_error("pack 실패 %s: %s" % [씬경로, error_string(e)])
		return false
	e = ResourceSaver.save(새팩, 씬경로)
	print("   %-28s → %s   %s"
		% [씬경로.get_file(), 재질경로.get_file(), error_string(e)])
	return e == OK
