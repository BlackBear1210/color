extends SceneTree
## ============================================================================
## [2026-08-27 신규] "밟는 자리(콜리전)" 와 "보이는 자리(메시)" 가 얼마나 어긋나나
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/진단_콜리전대_그림.gd -- <씬경로>
##        (씬을 안 주면 작업자 Template 9 종을 전부 잰다)
##
## ▣ 왜 필요한가 (도형님 제보)
##   "지형 플랫폼에 물리작용이 너무 안쪽으로 되어 있다."
##   눈으로는 못 잰다 — 세 값이 전부 다르기 때문이다:
##     ① 점(shape point)      작업자가 찍은 모양
##     ② 콜리전 폴리곤          점 + `collision_size` 만큼 **바깥으로 부풀림**
##     ③ 렌더 메시              점 + **엣지 텍스처가 밖으로 걸치는 양**
##   ③ 이 ② 보다 크면 "그림은 있는데 밟히지 않는" 띠가 생긴다 = 도형님이 본 증상.
##
## ▣ 무엇을 찍나
##   각 지형마다 세 AABB 와, **면(위/아래/왼/오른)별 어긋난 px** 을 찍는다.
##   양수 = 그림이 콜리전보다 그만큼 **더 튀어나왔다**(밟을 수 없는 그림 띠).
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const 템플릿들 := [
	키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn",
	키트 + "BRICK_벽돌/TEMPLATE_BRICK_HOLLOW.tscn",
	키트 + "BRICK_벽돌/TEMPLATE_BRICK_STAIRS.tscn",
	키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn",
	키트 + "WOOD_나무/TEMPLATE_WOOD_HOLLOW.tscn",
	키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn",
	키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn",
	키트 + "GRASS_잔디/TEMPLATE_GRASS_HOLLOW.tscn",
	키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS.tscn",
]

var _n := 0
var _대상: Array = []
var _루트: Node = null


func _init() -> void:
	Engine.max_fps = 60
	var a := OS.get_cmdline_user_args()
	_대상 = [a[0]] if a.size() > 0 else 템플릿들.duplicate()
	process_frame.connect(_틱)


func _틱() -> void:
	_n += 1
	var 칸 := 8
	var i := int(_n / 칸)
	if i >= _대상.size():
		quit(0)
		return
	var 단계 := _n % 칸
	if 단계 == 1:
		var 팩 := load(_대상[i]) as PackedScene
		if 팩 == null:
			print("못 읽음: ", _대상[i])
			return
		_루트 = 팩.instantiate()
		root.add_child(_루트)
	elif 단계 == 5:
		print("\n■ %s" % String(_대상[i]).get_file())
		_재기(_루트)
	elif 단계 == 6 and _루트 != null:
		_루트.queue_free()
		_루트 = null


func _재기(n: Node) -> void:
	# Template 은 루트 자체가 스마트지형이거나, 자식에 여러 개일 수 있다.
	# Template 은 루트 자체가 스마트지형이고, 스테이지 씬은 `지형` 층 아래에 여러 개다.
	# → 트리 전체를 훑는다.
	var 후보: Array = []
	_모으기_지형(n, 후보)
	if 후보.is_empty():
		print("   (스마트지형 없음)")
		return

	for 지형 in 후보:
		var pa: Object = 지형.get_point_array()
		var 점AABB := _점AABB(pa)
		var 메시AABB := _메시AABB(지형)
		var 콜AABB := _콜AABB(지형)
		print("   %-26s  collision_size=%.0f" % [String(지형.name), float(지형.get("collision_size"))])
		print("      점    %s" % _표(점AABB))
		print("      콜리전 %s" % _표(콜AABB))
		print("      메시   %s" % _표(메시AABB))
		if 콜AABB.size == Vector2.ZERO or 메시AABB.size == Vector2.ZERO:
			continue
		# 면별 어긋남 — 양수면 "그림이 콜리전보다 그만큼 밖으로 나와 있다"
		var 위 := 콜AABB.position.y - 메시AABB.position.y
		var 아래 := 메시AABB.end.y - 콜AABB.end.y
		var 왼 := 콜AABB.position.x - 메시AABB.position.x
		var 오 := 메시AABB.end.x - 콜AABB.end.x
		print("      ★그림이 콜리전 밖으로:  위 %+.1f · 아래 %+.1f · 왼 %+.1f · 오른 %+.1f"
			% [위, 아래, 왼, 오])


func _표(r: Rect2) -> String:
	return "(%.0f,%.0f)~(%.0f,%.0f)  %.0f×%.0f" % [
		r.position.x, r.position.y, r.end.x, r.end.y, r.size.x, r.size.y]


func _점AABB(pa: Object) -> Rect2:
	if pa == null:
		return Rect2()
	var 점들: Array = []
	for k in pa.get_all_point_keys():
		점들.append(pa.get_point_position(k))
	return _모으기(점들)


func _메시AABB(지형: Node) -> Rect2:
	var m = 지형.get("_meshes")
	if m == null or (m as Array).is_empty():
		return Rect2()
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for mm in (m as Array):
		var am: Mesh = mm.get("mesh") as Mesh
		if am == null:
			continue
		var bb := am.get_aabb()
		mn = mn.min(Vector2(bb.position.x, bb.position.y))
		mx = mx.max(Vector2(bb.end.x, bb.end.y))
	if mn.x > mx.x:
		return Rect2()
	return Rect2(mn, mx - mn)


func _콜AABB(지형: Node) -> Rect2:
	var poly := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if poly == null or poly.polygon.size() < 3:
		return Rect2()
	var 점들: Array = []
	for p in poly.polygon:
		점들.append(p)
	return _모으기(점들)


func _모으기(점들: Array) -> Rect2:
	if 점들.is_empty():
		return Rect2()
	var mn: Vector2 = 점들[0]
	var mx: Vector2 = 점들[0]
	for p in 점들:
		mn = mn.min(p)
		mx = mx.max(p)
	return Rect2(mn, mx - mn)


## 트리를 훑어 스마트지형을 전부 모은다.
func _모으기_지형(n: Node, 담을곳: Array) -> void:
	if n.has_method("get_point_array"):
		담을곳.append(n)
	for c in n.get_children():
		_모으기_지형(c, 담을곳)
