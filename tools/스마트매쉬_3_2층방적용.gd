extends SceneTree
## ============================================================================
## [2026-08-22 신규] 2층 방 지형을 브릭구조(9-슬라이스) → SmartShape 로 교체
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/스마트매쉬_3_2층방적용.gd
##   (선행: 스마트매쉬_2 로 재질 5종이 만들어져 있어야 한다.)
##
## ▣ 도형님 지시(그대로)
##   "2층 방 씬을 나무와 벽돌의 스마트매쉬를 사용해 지형을 변경. 색칠까지 잘 작동하고
##    플레이어 사망 판정까지 확인." + "구조물은 안전, 발판만 칠 가능"(결정 확정).
##
## ▣ 무엇을 하나 — 기존 씬을 **로드해서 블록만 갈아끼운다**(통째 재생성 아님)
##   집_2층방.tscn 을 instantiate 해서 `지형` 노드의 자식(브릭구조 StaticBody)들을 훑고,
##   각 블록의 **위치·크기를 그대로 읽어** 같은 자리에 `스마트지형` 사각형으로 바꾼다.
##   → 배경·오브젝트·플레이어·카메라 등 나머지는 1px 도 안 건드린다.
##   → 씬을 통째로 다시 빌드하지 않으므로 편집된 지오메트리가 보존된다(빌더 상수 무시).
##
## ▣ 벽돌/나무 · 칠 규칙 배정 (이름 기준)
##   구조물 {1층바닥,왼벽,천장,시작선반} → 벽돌 재질 · 칠하기_허용=false (무색 안전 뼈대)
##   발판   {발판_A,발판_B,오름_1,오름_2} → 나무 재질 · 칠하기_허용=true  (색 퍼즐·사망 판정)
##   그 외 이름은 안전한 벽돌 구조물로 처리(기본값).
##
## ▣ ★_ready 안 돌게 오프라인에서 조립한다 (스마트매쉬_2 머리말과 같은 이유)
##   로드한 루트를 활성 트리(get_root())에 **넣지 않는다.** 그래야 스마트지형 _ready 의
##   재질 깊은 복사가 안 일어나 씬에 공유 .tres 참조가 그대로 저장된다.
##
## ▣ owner(§규약 6): 지형공통.주인_지정 은 인스턴스(Player) 내부를 건너뛴다 → 안전.
## ============================================================================

const 스마트지형_S := preload("res://scripts/스마트월드/지형.gd")
const 공통 := preload("res://tools/지형공통.gd")

const 씬경로 := "res://scenes/집/집_2층방.tscn"
const 재질_폴더 := "res://assets/textures/smartshape/"

## 구조물(무색 안전) 블록 이름. 나머지는 발판(칠 가능)으로 본다.
const 구조물_이름 := ["1층바닥", "왼벽", "천장", "시작선반"]


func _init() -> void:
	var 팩본: PackedScene = load(씬경로)
	if 팩본 == null:
		push_error("씬을 못 읽음: %s" % 씬경로); quit(1); return
	# instantiate 만으로는 _ready 가 안 돈다(활성 트리에 안 넣으므로). 안전.
	var 루트: Node = 팩본.instantiate()
	var 지형층: Node = 루트.get_node_or_null("지형")
	if 지형층 == null:
		push_error("'지형' 노드가 없다"); quit(1); return

	var 바뀐수 := 0
	# 자식 목록을 먼저 복사해 둔다(순회 중 교체하면 인덱스가 흔들린다).
	for 옛것 in 지형층.get_children():
		var 결과 := _블록_교체(지형층, 옛것 as Node2D)
		if 결과:
			바뀐수 += 1

	# 새로 넣은 스마트지형에 owner 를 준다(Player 인스턴스 내부는 건너뜀).
	공통.주인_지정(루트, 루트)

	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("pack 실패: %s" % error_string(e)); quit(1); return
	e = ResourceSaver.save(팩, 씬경로)
	print("\n[스마트매쉬_3_2층방적용] 블록 %d개 교체, 저장 %s → %s"
		% [바뀐수, error_string(e), 씬경로])
	quit(0 if e == OK else 1)


## 브릭구조 블록 하나를 같은 위치·크기의 스마트지형으로 교체. 교체했으면 true.
func _블록_교체(지형층: Node, 옛것: Node2D) -> bool:
	if 옛것 == null:
		return false
	# 브릭구조 블록은 '크기' 속성을 가진 StaticBody2D 다. 아니면 손대지 않는다.
	var 크기: Variant = 옛것.get("크기")
	if not (크기 is Vector2):
		return false
	var 중심: Vector2 = 옛것.position
	var 이름: String = 옛것.name

	var 구조물 := 구조물_이름.has(이름)
	var 재질경로 := 재질_폴더 + ("지형_벽돌.tres" if 구조물 else "지형_나무.tres")

	var 새것 := _스마트지형_사각(이름, 중심, 크기, 재질경로, not 구조물)
	if 새것 == null:
		return false

	# 옛 블록을 빼고 새 블록을 같은 자리에 꽂는다(트리 순서 유지 위해 index 보존).
	var idx := 옛것.get_index()
	지형층.remove_child(옛것)
	옛것.queue_free()
	지형층.add_child(새것)
	지형층.move_child(새것, idx)
	return true


## 중심·크기로 스마트지형 사각형 블록 하나를 오프라인 조립한다.
func _스마트지형_사각(이름: String, 중심: Vector2, 크기: Vector2,
		재질경로: String, 칠가능: bool) -> SS2D_Shape_Closed:
	if not ResourceLoader.exists(재질경로):
		push_error("재질 없음: %s" % 재질경로); return null

	var 지형: SS2D_Shape_Closed = 스마트지형_S.new()
	지형.name = 이름
	지형.position = 중심
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	지형.set("칠하기_허용", 칠가능)          # 구조물=false(안전) · 발판=true(색 퍼즐·사망)
	지형.set("무색일때_통과", false)          # 안 칠해도 항상 밟히는 실체

	var w := 크기.x * 0.5
	var h := 크기.y * 0.5
	# 시계방향(TL→TR→BR→BL) — 감김 방향이 섞이면 콜리전 볼록분해가 조용히 깨진다.
	var 점들 := PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h),
	])
	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()

	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	지형.collision_size = 24.0
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime

	var 생성기 := SS2D_CollisionGen.new()
	생성기.collision_size = 지형.collision_size
	생성기.collision_offset = 지형.collision_offset
	폴리.polygon = 생성기.generate_filled(지형.get_point_array().get_tessellated_points())
	return 지형
