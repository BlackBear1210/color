class_name 색경계
extends RefCounted
## ============================================================================
## [2026-08-23 신규] 색 경계 — 공통 규칙
## ----------------------------------------------------------------------------
## ▣ 무엇이 바뀌었나
##   예전에는 플레이어 색이 `player_color` **정수 하나**였다. 그래서 경계선이 몸을
##   가로지르면 답이 없었다 — `color_zone.gd` 는 "마지막에 진입한 구역이 이긴다" 로,
##   `월드.gd` 는 "지대 목록을 훑어 마지막 것" 으로 각자 얼버무리고 있었다.
##
##   이제 **색은 값이 아니라 위치의 함수**다.
##     · 그 좌표를 품은 경계가 있으면 → 경계의 색 (강제)
##     · 없으면                      → 플레이어의 `자유색` (Shift 로 바꾸는 단 하나의 상태)
##
## ▣ 경계가 지켜야 할 약속 (덕 타이핑)
##   `색경계.그룹` 에 들어가고 아래 둘을 구현한다.
##     강제색(월드좌표: Vector2) -> int
##         그 점을 품으면 색 코드, 아니면 -1. 회색은 강제하지 않으므로 -1 을 준다.
##     경계_폴리곤들() -> Array[PackedVector2Array]
##         **월드 좌표**의 닫힌 폴리곤들. 몸을 어디서 자를지 찾는 데만 쓴다.
##
## ▣ 왜 자르는 선과 색을 따로 구하나
##   자를 위치는 폴리곤 변에서 찾지만, 잘린 조각의 색은 **조각 무게중심을 점 질의**해서
##   정한다. 이렇게 해야 "몸이 통째로 경계 안" (변이 하나도 안 걸림) 인 경우와
##   "통째로 밖" 인 경우가 특수 처리 없이 같은 코드로 맞는다.
##
## ▣ 겹침
##   경계끼리 면이 겹치는 것은 금지다(`color_zone.gd` 가 에디터에서 막는다).
##   변끼리 맞닿는 것은 허용이므로, 몸을 가르는 선은 최대 2개까지만 본다.
## ============================================================================

## 모든 색 경계가 들어가는 그룹. color_zone · 식물B · 빛기둥이 함께 쓴다.
const 그룹: String = "색경계"

## 몸을 가르는 선을 최대 몇 개까지 볼지. 겹침이 금지라 1개가 보통이고,
## 폴리곤 모서리가 몸 안에 들어온 경우에만 2개가 된다.
const 최대_분할선: int = 2

## 이보다 작은 조각은 버린다(px²). 선이 몸을 스칠 때 생기는 먼지 조각 제거용.
const _최소_면적: float = 6.0

## 이보다 작은 교집합은 수치 오차로 본다(px²).
## 변·꼭짓점이 정확히 닿는 경우의 넓이는 0 이므로, 이 문턱 아래면 허용된다.
const 최소_겹침면적: float = 0.05


## 두 폴리곤이 실제로 **면적을 가진 채** 겹치는 부분들.
## `Geometry2D.intersect_polygons()` 는 변이 닿은 경우도 결과를 낼 수 있으므로,
## 넓이를 다시 재야 "맞닿음 허용 / 면 겹침 금지" 규칙을 정확히 지킬 수 있다.
static func 양의_교집합들(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	var 결과: Array = []
	if a.size() < 3 or b.size() < 3:
		return 결과
	for 교집합 in Geometry2D.intersect_polygons(a, b):
		var poly := 교집합 as PackedVector2Array
		if _면적(poly) > 최소_겹침면적:
			결과.append(poly)
	return 결과


## 두 폴리곤 사이에 금지된 면 겹침이 있는가.
static func 면_겹치나(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return not 양의_교집합들(a, b).is_empty()


## 이 월드 좌표를 강제하는 색. 없으면 -1.
## 겹침은 금지지만 변이 맞닿은 자리에서는 둘 다 걸릴 수 있어, 나중에 만난 것이 이긴다.
static func 강제색_at(트리: SceneTree, 월드좌표: Vector2) -> int:
	var 결과 := -1
	for n in 트리.get_nodes_in_group(그룹):
		if not is_instance_valid(n) or not n.has_method("강제색"):
			continue
		var c: int = n.강제색(월드좌표)
		if c >= 0:
			결과 = c
	return 결과


## 몸 사각형을 가르는 경계 변들을 반평면으로 돌려준다.
## 원소 = { "점": Vector2(선 위의 한 점), "법선": Vector2(경계 **안쪽** 방향) }
static func 분할선들(트리: SceneTree, 몸: Rect2) -> Array:
	var 선들: Array = []
	for n in 트리.get_nodes_in_group(그룹):
		if not is_instance_valid(n) or not n.has_method("경계_폴리곤들"):
			continue
		for poly in n.경계_폴리곤들():
			var 개수: int = poly.size()
			if 개수 < 3:
				continue
			for i in 개수:
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % 개수]
				if not _변이_몸에_걸리나(a, b, 몸):
					continue
				var 중점 := (a + b) * 0.5
				var 법선 := (b - a).orthogonal().normalized()
				# 법선이 폴리곤 **안쪽**을 보게 맞춘다. 오목한 모양에서도 맞도록
				# 각도가 아니라 "살짝 밀어 본 점이 안에 있나" 로 판단한다.
				if not Geometry2D.is_point_in_polygon(중점 + 법선 * 2.0, poly):
					법선 = -법선
				선들.append({ "점": 중점, "법선": 법선 })
				if 선들.size() >= 최대_분할선:
					return 선들
	return 선들


## 몸을 색이 같은 조각들로 자른다.
## 원소 = { "폴리곤": PackedVector2Array(월드), "색": int, "강제": bool }
## `강제` 는 그 조각이 경계 안이라 색이 고정됐다는 뜻 — 색 전환 차단 판정에 쓴다.
## (색만 봐서는 알 수 없다. 자유색과 경계색이 우연히 같을 수 있기 때문이다.)
## 경계에 안 걸리면 조각 하나(= 몸 전체)에 `자유색` 이 담겨 돌아온다.
static func 몸_영역들(트리: SceneTree, 몸: Rect2, 자유색: int) -> Array:
	var 조각들: Array = [_사각형_폴리곤(몸)]
	for 선 in 분할선들(트리, 몸):
		var 다음: Array = []
		for p in 조각들:
			var 안 := 반평면_자르기(p, 선["점"], 선["법선"])
			var 밖 := 반평면_자르기(p, 선["점"], -선["법선"])
			if _면적(안) > _최소_면적:
				다음.append(안)
			if _면적(밖) > _최소_면적:
				다음.append(밖)
		if 다음.is_empty():
			break                          # 전부 먼지가 됐다면 자르기 전 상태를 지킨다
		조각들 = 다음

	var 영역들: Array = []
	for p in 조각들:
		var c := 강제색_at(트리, _무게중심(p))
		영역들.append({
			"폴리곤": p,
			"색": (c if c >= 0 else 자유색),
			"강제": c >= 0,
		})
	return 영역들


## 분할 셰이더(`shaders/색분할.gdshader`)에 넣을 값 한 벌.
##   { "개수": int, "선1": Vector4, "선2": Vector4, "색표": Vector4 }
## 선은 (점.xy, 법선.xy) 월드 좌표. 색표는 부호 조합별 색(0=검정, 1=흰색).
##
## ⚠ 판정(`몸_영역들`)과 **같은 분할선**을 쓴다. 다른 값으로 계산하면 보이는 것과
##   죽는 것이 어긋난다 — 이 규칙을 지키려고 굳이 한 파일에 같이 뒀다.
static func 분할_셰이더값(트리: SceneTree, 몸: Rect2, 자유색: int) -> Dictionary:
	var 선들 := 분할선들(트리, 몸)
	var 결과 := {
		"개수": 선들.size(),
		"선1": Vector4(0, 0, 0, 1),
		"선2": Vector4(0, 0, 0, 1),
		"색표": Vector4(float(자유색), float(자유색), float(자유색), float(자유색)),
	}
	if 선들.is_empty():
		var c := 강제색_at(트리, 몸.get_center())
		var v := float(c if c >= 0 else 자유색)
		결과["색표"] = Vector4(v, v, v, v)
		return 결과

	for i in 선들.size():
		var 선: Dictionary = 선들[i]
		결과["선%d" % (i + 1)] = Vector4(선["점"].x, 선["점"].y, 선["법선"].x, 선["법선"].y)

	# 부호 조합마다 색을 뽑는다. 조합 순서는 셰이더와 같아야 한다:
	#   1개 → [+, −]            2개 → [++, +−, −+, −−]
	var 조합: Array = [[true], [false]] if 선들.size() == 1 \
		else [[true, true], [true, false], [false, true], [false, false]]
	var 색값: Array[float] = [float(자유색), float(자유색), float(자유색), float(자유색)]
	for i in 조합.size():
		var c := _조합의_색(트리, 몸, 선들, 조합[i], 자유색)
		색값[i] = float(c)
	결과["색표"] = Vector4(색값[0],색값[1],색값[2],색값[3])
	return 결과


## 부호 조합 하나가 가리키는 영역의 색.
## 몸 안에 그 조합의 조각이 있으면 그 무게중심을, 없으면(스프라이트가 몸 밖으로
## 삐져나온 부분) 선을 건너간 대표점을 질의한다.
static func _조합의_색(트리: SceneTree, 몸: Rect2, 선들: Array, 부호: Array, 자유색: int) -> int:
	var 조각 := _사각형_폴리곤(몸)
	for i in 부호.size():
		var 선: Dictionary = 선들[i]
		var n: Vector2 = 선["법선"] if 부호[i] else -선["법선"]
		조각 = 반평면_자르기(조각, 선["점"], n)
	if _면적(조각) > _최소_면적:
		var c := 강제색_at(트리, _무게중심(조각))
		return c if c >= 0 else 자유색

	# 몸 안에는 없는 조합 — 중심에서 각 선을 건너뛴 점으로 대신 묻는다.
	var 점 := 몸.get_center()
	for i in 부호.size():
		var 선: Dictionary = 선들[i]
		# ⚠ Dictionary 값은 Variant 라 := 로 타입 추론이 안 된다 → 명시 타입으로 받는다.
		var 선점: Vector2 = 선["점"]
		var n: Vector2 = 선["법선"] if 부호[i] else -선["법선"]
		var d := (점 - 선점).dot(n)
		if d < 0.0:
			점 += n * (-d + 24.0)
	var c2 := 강제색_at(트리, 점)
	return c2 if c2 >= 0 else 자유색


## 폴리곤을 반평면 `(p - 점)·법선 >= 0` 쪽만 남기고 자른다 (Sutherland–Hodgman).
## 볼록 폴리곤을 자르면 결과도 볼록이라 ConvexPolygonShape2D 로 바로 쓸 수 있다.
static func 반평면_자르기(폴리: PackedVector2Array, 점: Vector2, 법선: Vector2) -> PackedVector2Array:
	var 결과 := PackedVector2Array()
	var n := 폴리.size()
	if n == 0:
		return 결과
	for i in n:
		var 지금: Vector2 = 폴리[i]
		var 다음: Vector2 = 폴리[(i + 1) % n]
		var d1 := (지금 - 점).dot(법선)
		var d2 := (다음 - 점).dot(법선)
		if d1 >= 0.0:
			결과.append(지금)
		if (d1 >= 0.0) != (d2 >= 0.0):
			var 분모 := d1 - d2
			if absf(분모) > 0.00001:
				결과.append(지금 + (다음 - 지금) * (d1 / 분모))
	return 결과


# ── 내부 ────────────────────────────────────────────────────────────────────

static func _사각형_폴리곤(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])


## 선분 a→b 가 몸 사각형과 걸치는가. 끝점이 안에 들어온 경우도 걸침으로 본다
## (폴리곤 모서리가 몸 안에 있으면 변이 사각형을 관통하지 않는다).
static func _변이_몸에_걸리나(a: Vector2, b: Vector2, 몸: Rect2) -> bool:
	if 몸.has_point(a) or 몸.has_point(b):
		return true
	var 모서리 := _사각형_폴리곤(몸)
	for i in 4:
		var c: Vector2 = 모서리[i]
		var d: Vector2 = 모서리[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return true
	return false


static func _면적(폴리: PackedVector2Array) -> float:
	var n := 폴리.size()
	if n < 3:
		return 0.0
	var 합 := 0.0
	for i in n:
		var p: Vector2 = 폴리[i]
		var q: Vector2 = 폴리[(i + 1) % n]
		합 += p.x * q.y - q.x * p.y
	return absf(합) * 0.5


static func _무게중심(폴리: PackedVector2Array) -> Vector2:
	var n := 폴리.size()
	if n == 0:
		return Vector2.ZERO
	var 합 := Vector2.ZERO
	for p in 폴리:
		합 += p
	return 합 / float(n)
