@tool
extends 스마트지형
## ============================================================================
## [2026-08-31 신규 · STEP 1-4.2] 단방향 지형 — 아래에서 위로는 통과, 위에서는 착지
## ----------------------------------------------------------------------------
## ▣ 왜 스크립트가 필요한가 (빌더에서 한 줄로 못 끝낸 이유)
##   빌더가 `CollisionPolygon2D.one_way_collision = true` 를 켜도 **씬에 저장되지 않는다.**
##   그 폴리곤은 Template 씬 **인스턴스의 내부 노드**라 owner 가 없고
##   (`지형공통.gd::주인_지정()` 은 인스턴스 내부로 안 들어간다 — 그 씬이 관리하니까),
##   `PackedScene.pack()` 이 owner 없는 노드의 속성 변경을 통째로 버린다.
##   게다가 SS2D 는 `force_update()` 마다 `bake_collision()` 으로 폴리곤을 다시 굽는다.
##   → **런타임에 켜는 것이 유일하게 확실한 방법이다.**
##
## ▣ 선례
##   이 프로젝트의 OneWay 는 `식물_a.gd:121` 하나뿐이고, 거기서도
##   `CollisionShape2D.one_way_collision = true` 한 줄이 전부다. 같은 문법을 쓴다.
##   ⚠ `통과플랫폼.gd` 는 이름과 달리 OneWay 가 아니다 — 물만 통과시키는
##     사방 막힌 하수구 격자다. 그래서 재사용 대상이 아니었다.
##
## ▣ 방향
##   Godot 의 OneWay 는 **도형의 로컬 +Y(아래) 쪽에서 오는 것만 막는다.**
##   축 정렬 사각형(회전 0)이면 곧 "위에서 내려오는 것만 막고 밑에서는 통과" 다.
## ============================================================================
class_name 단방향지형

## 끄면 평범한 지형이 된다(인스펙터에서 확인용).
@export var 단방향: bool = true:
	set(v):
		단방향 = v
		_적용()

## 얇은 판을 빠르게 통과할 때 새어 나가지 않게 하는 여유. Godot 기본은 1.0.
@export_range(0.0, 128.0) var 단방향_여유: float = 24.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# SS2D 는 `force_update()` 를 call_deferred 로 돌리고 그때 폴리곤을 다시 굽는다.
	# 그 뒤에 켜야 확실하다 → 첫 굽기 신호에 맞춰 켜고, 이후 다시 구워도 계속 켠다.
	if not on_dirty_update.is_connected(_적용):
		on_dirty_update.connect(_적용)
	_적용.call_deferred()


func _적용() -> void:
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return
	폴리.one_way_collision = 단방향
	폴리.one_way_collision_margin = 단방향_여유


## 런타임 시험이 상태를 확인하는 창.
func 단방향_켜졌나() -> bool:
	var 폴리 := get_collision_polygon_node()
	return 폴리 != null and 폴리.one_way_collision
