@tool
extends Area2D
class_name ColorZone
## [2026-07-19 · 신규] 다각형 "색 구역" 프레임.
##
## 목적: 타일맵으로 찍은 지형 위에 겹쳐 놓는, 에디터에서 자유롭게 모양을 바꿀 수 있는
##   다각형 틀. 플레이어가 이 다각형 "안"에 들어오면 지정한 색(흑/백)으로 자동 고정되고,
##   구역 "밖"에서는 강제하지 않으므로 플레이어가 키보드로 자유롭게 색을 토글할 수 있다.
##
## 사용법 (디자이너):
##   1. 이 색 구역 씬(color_zone.tscn)을 지형 씬에 드래그해 넣는다 (여러 개 가능).
##   2. 자식 CollisionPolygon2D 를 선택 → 에디터에서 꼭짓점을 찍고 드래그해 모양을 잡는다.
##   3. Inspector 의 "Zone Color" 를 Black/White 중 선택한다. 끝.
##
## ★[2026-08-23 전면 변경] 몸이 걸치면 몸을 자른다
##   예전에는 "가장 마지막에 진입한 구역이 이긴다"는 스택으로 얼버무렸다. 몸이 경계선에
##   걸치면 상체·하체 중 한쪽을 버리는 셈이라, 보이는 것과 죽는 것이 어긋났다.
##   이제 이 스크립트는 **색을 강제하지 않는다.** 대신 두 가지 질문에만 답한다:
##     강제색(월드좌표)     이 점이 내 안인가? 그러면 무슨 색인가?
##     경계_폴리곤들()      내 모양은 어디인가? (플레이어가 몸을 자를 선을 찾는 데 쓴다)
##   자르고 색을 정하는 일은 `색경계.gd` 와 `player.gd` 가 한다.
##
## 겹침 규칙: **경계끼리 면이 겹칠 수 없다.** 변이 맞닿는 것만 허용한다.
##   겹치면 자를 선이 여러 개가 되어 판정이 애매해지고, 작업자도 어느 색인지 못 읽는다.
##   → 에디터에서 겹침을 빨갛게 표시하고, 가까운 변·꼭짓점에는 자석처럼 붙는다.

enum ZoneColor { BLACK, WHITE }

## 이 구역이 강제하는 색. Inspector 에서 드롭다운으로 선택.
@export var zone_color: ZoneColor = ZoneColor.WHITE:
	set(v):
		zone_color = v
		queue_redraw()
## 에디터/게임에서 구역을 반투명 색으로 표시할지 (연출용, 로직과 무관).
@export var show_tint: bool = true:
	set(v):
		show_tint = v
		queue_redraw()

@export_group("에디터 안전장치")
## 꼭짓점이나 구역 전체를 이 거리 안으로 가져가면, 다른 경계의 꼭짓점·변에 정확히 붙인다.
## 0이면 스냅만 끌 뿐, 면 겹침 되돌리기와 레벨검사는 계속 작동한다.
@export_range(0.0, 64.0, 1.0) var 스냅거리: float = 12.0:
	set(v):
		스냅거리 = maxf(v, 0.0)

## 에디터에서 잡아낸 겹침 영역(현재 ColorZone 로컬 좌표). 빨간 틴트로 그린다.
var _겹침영역: Array[PackedVector2Array] = []
var _겹침이름: Array[String] = []

## 마지막으로 확인된 안전한 배치. 꼭짓점 드래그·노드 이동으로 면이 겹치면 여기로 되돌린다.
## 직접 드래그를 가로채는 EditorPlugin 없이도 "겹치는 위치에 놓을 수 없음"을 보장하는 방법이다.
var _마지막_폴리곤 := PackedVector2Array()
var _마지막_존변환 := Transform2D.IDENTITY
var _마지막_폴리곤변환 := Transform2D.IDENTITY
var _안전배치_있음 := false
var _되돌리는중 := false

func _ready() -> void:
	add_to_group(색경계.그룹)
	if Engine.is_editor_hint():
		call_deferred("_에디터_안전_갱신")
		return
	# 더 이상 몸 진입을 감지하지 않는다 — 플레이어가 점 단위로 물어보기 때문이다.
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


# ── 색경계 계약 ────────────────────────────────────────────────────────────

## 이 점이 구역 안이면 색, 아니면 -1.
func 강제색(월드좌표: Vector2) -> int:
	for poly in 경계_폴리곤들():
		if Geometry2D.is_point_in_polygon(월드좌표, poly):
			return ColorDefs.WHITE if zone_color == ZoneColor.WHITE else ColorDefs.BLACK
	return -1


## 이 구역의 모양 — **월드 좌표** 닫힌 폴리곤들.
func 경계_폴리곤들() -> Array:
	var 결과: Array = []
	for 자식 in get_children():
		var cp := 자식 as CollisionPolygon2D
		if cp == null or cp.polygon.size() < 3:
			continue
		var 변환 := global_transform * cp.transform
		var pts := PackedVector2Array()
		for p in cp.polygon:
			pts.append(변환 * p)
		결과.append(pts)
	return 결과

# ── 에디터/런타임 시각화 (반투명 틴트 + 외곽선) ─────────────────────────
func _process(_delta: float) -> void:
	# 에디터에서 꼭짓점을 드래그하는 즉시 틴트가 따라오도록 매 프레임 다시 그린다.
	if Engine.is_editor_hint():
		_에디터_안전_갱신()


## ColorZone끼리만 편집을 막는다.
## 식물B·빛기둥은 런타임에 모양이 변하는 시스템이라 에디터에서 ColorZone처럼 되돌리면
## 정상 연출까지 막힐 수 있다. 대신 레벨검사는 모든 색 경계를 별도로 감사한다.
func _다른_색구역들() -> Array[ColorZone]:
	var 결과: Array[ColorZone] = []
	if get_tree() == null:
		return 결과
	for n in get_tree().get_nodes_in_group(색경계.그룹):
		var z := n as ColorZone
		if z != null and z != self and is_instance_valid(z):
			결과.append(z)
	return 결과


func _기본_폴리곤() -> CollisionPolygon2D:
	return get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D


## 현재 폴리곤의 월드 변환. `global_transform * 자식 transform` 순서가 중요하다.
func _월드변환(cp: CollisionPolygon2D) -> Transform2D:
	return global_transform * cp.transform


## 꼭짓점 하나가 다른 경계의 꼭짓점·변 근처면 가장 가까운 정확한 점으로 붙인다.
func _꼭짓점_스냅(원본: PackedVector2Array, cp: CollisionPolygon2D) -> PackedVector2Array:
	if 스냅거리 <= 0.0:
		return 원본
	var 결과 := PackedVector2Array(원본)
	var 변환 := _월드변환(cp)
	var 역변환 := 변환.affine_inverse()
	for i in 결과.size():
		var 월드점: Vector2 = 변환 * 결과[i]
		var 가장가까운 := 월드점
		var 최소거리 := 스냅거리
		for 다른 in _다른_색구역들():
			for poly in 다른.경계_폴리곤들():
				for j in poly.size():
					var a: Vector2 = poly[j]
					var b: Vector2 = poly[(j + 1) % poly.size()]
					# 꼭짓점과 변 둘 다 후보에 넣는다. 변 한가운데에 닿는 T 접합도 허용한다.
					for 후보 in [a, Geometry2D.get_closest_point_to_segment(월드점, a, b)]:
						var d := 월드점.distance_to(후보)
						if d < 최소거리:
							최소거리 = d
							가장가까운 = 후보
		if 가장가까운 != 월드점:
			결과[i] = 역변환 * 가장가까운
	return 결과


## 노드 전체를 옮겼을 때는 꼭짓점 하나만 휘면 안 된다. 가장 가까운 점까지 **구역 전체**를
## 평행이동해 붙인다. 변형(회전·스케일)은 보존된다.
func _노드_통째_스냅(cp: CollisionPolygon2D) -> void:
	if 스냅거리 <= 0.0:
		return
	var 변환 := _월드변환(cp)
	var 이동 := Vector2.ZERO
	var 최소거리 := 스냅거리
	for p in cp.polygon:
		var 월드점: Vector2 = 변환 * p
		for 다른 in _다른_색구역들():
			for poly in 다른.경계_폴리곤들():
				for j in poly.size():
					var a: Vector2 = poly[j]
					var b: Vector2 = poly[(j + 1) % poly.size()]
					for 후보 in [a, Geometry2D.get_closest_point_to_segment(월드점, a, b)]:
						var d := 월드점.distance_to(후보)
						if d < 최소거리:
							최소거리 = d
							이동 = 후보 - 월드점
	if 이동.length_squared() > 0.0001:
		global_position += 이동


## 현재 배치가 다른 ColorZone과 양의 면적으로 겹치는지 검사하고, 빨간 표시용 영역도 만든다.
func _겹침_검사(cp: CollisionPolygon2D) -> bool:
	_겹침영역.clear()
	_겹침이름.clear()
	var 내폴리곤 := PackedVector2Array()
	var 변환 := _월드변환(cp)
	for p in cp.polygon:
		내폴리곤.append(변환 * p)
	for 다른 in _다른_색구역들():
		for poly in 다른.경계_폴리곤들():
			for 교집합 in 색경계.양의_교집합들(내폴리곤, poly):
				var 로컬 := PackedVector2Array()
				for 월드점 in 교집합:
					로컬.append(to_local(월드점))
				_겹침영역.append(로컬)
				if not _겹침이름.has(다른.name):
					_겹침이름.append(다른.name)
	return not _겹침영역.is_empty()


func _안전배치_저장(cp: CollisionPolygon2D) -> void:
	_마지막_폴리곤 = PackedVector2Array(cp.polygon)
	_마지막_존변환 = transform
	_마지막_폴리곤변환 = cp.transform
	_안전배치_있음 = true


func _마지막_안전배치로_되돌리기(cp: CollisionPolygon2D) -> void:
	if not _안전배치_있음:
		return
	_되돌리는중 = true
	transform = _마지막_존변환
	cp.transform = _마지막_폴리곤변환
	cp.polygon = PackedVector2Array(_마지막_폴리곤)
	_되돌리는중 = false


## @tool 이라 에디터 2D 워크스페이스에서 직접 작동한다.
## ① 가까우면 자석처럼 붙이고 ② 면 겹침이면 마지막 유효 배치로 돌린다.
func _에디터_안전_갱신() -> void:
	if not Engine.is_editor_hint() or _되돌리는중:
		return
	var cp := _기본_폴리곤()
	if cp == null or cp.polygon.size() < 3:
		return

	var 노드만_움직임 := _안전배치_있음 \
		and cp.polygon == _마지막_폴리곤 \
		and cp.transform == _마지막_폴리곤변환 \
		and transform != _마지막_존변환
	if 노드만_움직임:
		_노드_통째_스냅(cp)
	else:
		var 스냅됨 := _꼭짓점_스냅(cp.polygon, cp)
		if 스냅됨 != cp.polygon:
			cp.polygon = 스냅됨

	if _겹침_검사(cp):
		# 기존에 이미 겹친 씬을 처음 열었을 때는 복구 기준이 없다.
		# 그때는 빨갛게 남겨 디자이너가 의도를 보고 고치게 한다.
		if _안전배치_있음:
			_마지막_안전배치로_되돌리기(cp)
			_겹침_검사(cp)
	else:
		_안전배치_저장(cp)
	update_configuration_warnings()
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	if _겹침이름.is_empty():
		return PackedStringArray()
	return PackedStringArray([
		"색 경계가 면적으로 겹칩니다: %s\n변·꼭짓점 접촉은 허용되지만 면적 겹침은 금지입니다. " \
			% ", ".join(_겹침이름),
	])

func _draw() -> void:
	if not show_tint:
		return
	var poly_node := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly_node == null or poly_node.polygon.size() < 3:
		return
	# CollisionPolygon2D 의 로컬 폴리곤을 이 Area2D 좌표계로 변환해 그린다.
	var xf := poly_node.transform
	var pts := PackedVector2Array()
	for p in poly_node.polygon:
		pts.append(xf * p)
	var is_white := zone_color == ZoneColor.WHITE
	var fill := Color(0.95, 0.95, 0.95, 0.14) if is_white else Color(0.05, 0.05, 0.05, 0.24)
	var line := Color(0.98, 0.98, 0.98, 0.7) if is_white else Color(0.05, 0.05, 0.05, 0.8)
	draw_colored_polygon(pts, fill)
	# 외곽선 (닫힌 루프)
	var loop := pts
	loop.append(pts[0])
	draw_polyline(loop, line, 2.0)
	# 겹침은 편집 중에도 놓치기 쉽다. 화면에서 바로 보이게 붉은 반투명으로 덮는다.
	for poly in _겹침영역:
		draw_colored_polygon(poly, Color(0.95, 0.08, 0.08, 0.42))
		var 빨간선 := PackedVector2Array(poly)
		if not 빨간선.is_empty():
			빨간선.append(빨간선[0])
			draw_polyline(빨간선, Color(1.0, 0.1, 0.1, 0.95), 3.0)
