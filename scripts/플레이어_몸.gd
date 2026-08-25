extends RefCounted
## ============================================================================
## [2026-08-25 신규] 플레이어 몸 치수를 재는 **유일한 자**
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   똑같은 "플레이어 콜리전을 찾아 크기를 잰다" 코드가 **7 곳에 복사**돼 있었다:
##       scripts/player.gd            _몸_실측()          ← 사망 판정 기준
##       scripts/스마트월드/월드.gd    _접촉모양_준비()     ← 접촉 겹침 질의
##       scripts/스마트월드/지형규칙.gd 플레이어에서_재기()  ← 레벨 규칙 상수 검증
##       tools/레벨검사.gd                                ← 도달 가능성 게이트
##       tools/지형_진단.gd                               ← 끼임·발뜸 진단
##       tools/지형_보정.gd                               ← 디딤돌 놓기
##       tools/치수_보정.gd                               ← 치수 보정
##
##   전부 `get_node_or_null("CollisionShape2D")` 로 찾고, 모양은 `RectangleShape2D`
##   (일부는 `CapsuleShape2D` 까지)만 처리했다. 그래서 콜리전 모양을 바꿀 때마다
##   **어디가 조용히 깨졌는지 하나씩 찾아다녀야** 했다.
##
##   실제로 2026-08-25 에 두 번 터졌다:
##     ① 캡슐로 바꿈  → `지형규칙.gd` 가 캡슐을 못 읽고 **상수를 그대로 반환**.
##        그 상수와 다시 비교하니 `test_지형규칙` 이 **가짜로 통과**했다.
##     ② CollisionPolygon2D 로 바꿈 → 7 곳 전부 노드조차 못 찾음.
##        사망 판정이 발밑 레이로 퇴화해 **"몸이 반대색 벽에 닿으면 죽는다"는
##        이 게임의 중심 규칙이 작동을 멈췄다**(`test_사망판정` 24/25).
##
##   → 자를 하나로 모은다. 여기만 고치면 7 곳이 전부 따라온다.
##
## ▣ 무엇을 지원하나
##   노드:  CollisionShape2D · CollisionPolygon2D  (이름 무관 — **타입으로 찾는다**)
##   모양:  RectangleShape2D · CapsuleShape2D · CircleShape2D · ConvexPolygonShape2D
##   개수:  여러 개면 **전부의 합집합** 바운딩 박스
##
## ▣ ⚠ 판정은 어차피 사각형이다
##   폴리곤으로 아무리 정교하게 깎아도 이 함수는 **바운딩 박스**를 돌려준다.
##   `몸_사각형()` 이 Rect2 이고 사망 판정이 그것을 쓰기 때문이다(설계상 그렇다).
##   콜리전 모양은 **물리**(서 있기·벽 충돌)만 바꾼다.
## ============================================================================
class_name 플레이어몸


## 플레이어의 몸 치수를 잰다.
##
## 반환: {
##   "찾음":       bool,      콜리전을 하나라도 찾았나
##   "크기":       Vector2,   월드 픽셀 (스케일 반영 완료)
##   "중심오프셋": Vector2,   플레이어 원점(발바닥) → 몸 중심, 월드 픽셀
## }
##
## 못 찾으면 `찾음 = false` 를 준다. **부르는 쪽이 반드시 확인할 것** —
## 조용히 기본값으로 넘어가면 2026-08-25 사고가 그대로 반복된다.
static func 재기(플레이어: Node) -> Dictionary:
	var 결과 := { "찾음": false, "크기": Vector2.ZERO, "중심오프셋": Vector2.ZERO }
	if 플레이어 == null:
		return 결과

	# 로컬(플레이어 좌표계) 기준 합집합 사각형. 여러 콜리전을 다 품는다.
	var 최소 := Vector2.INF
	var 최대 := -Vector2.INF

	for 자식 in 플레이어.get_children():
		var 상자 := _자식_상자(자식)
		if 상자.is_empty():
			continue
		var mn: Vector2 = 상자["최소"]
		var mx: Vector2 = 상자["최대"]
		최소 = Vector2(minf(최소.x, mn.x), minf(최소.y, mn.y))
		최대 = Vector2(maxf(최대.x, mx.x), maxf(최대.y, mx.y))

	if 최소.x > 최대.x:
		return 결과            # 하나도 못 찾았다

	# 플레이어는 비균등 스케일(0.79, 0.37)이라 마지막에 한 번만 곱해 월드로 바꾼다.
	var 배율 := Vector2.ONE
	if 플레이어 is Node2D:
		배율 = (플레이어 as Node2D).scale.abs()

	결과["찾음"] = true
	결과["크기"] = (최대 - 최소) * 배율
	결과["중심오프셋"] = (최소 + 최대) * 0.5 * 배율
	return 결과


## 콜리전 자식 하나의 로컬 바운딩 박스. 콜리전이 아니면 빈 사전.
## ⚠ 자식 자신의 position·scale 까지 반영한다 — 안 하면 오프셋이 통째로 빠진다.
static func _자식_상자(자식: Node) -> Dictionary:
	var 반: Vector2 = Vector2.ZERO      # 중심에서 각 축으로 뻗은 반지름
	var 중심 := Vector2.ZERO

	if 자식 is CollisionPolygon2D:
		var poly: PackedVector2Array = (자식 as CollisionPolygon2D).polygon
		if poly.size() < 3:
			return {}
		var mn := poly[0]
		var mx := poly[0]
		for p in poly:
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
		중심 = (mn + mx) * 0.5
		반 = (mx - mn) * 0.5

	elif 자식 is CollisionShape2D:
		var sh: Shape2D = (자식 as CollisionShape2D).shape
		if sh == null:
			return {}
		if sh is RectangleShape2D:
			반 = (sh as RectangleShape2D).size * 0.5
		elif sh is CapsuleShape2D:
			var cap := sh as CapsuleShape2D
			반 = Vector2(cap.radius, cap.height * 0.5)
		elif sh is CircleShape2D:
			var r := (sh as CircleShape2D).radius
			반 = Vector2(r, r)
		elif sh is ConvexPolygonShape2D:
			var pts: PackedVector2Array = (sh as ConvexPolygonShape2D).points
			if pts.size() < 3:
				return {}
			var mn2 := pts[0]
			var mx2 := pts[0]
			for p in pts:
				mn2 = Vector2(minf(mn2.x, p.x), minf(mn2.y, p.y))
				mx2 = Vector2(maxf(mx2.x, p.x), maxf(mx2.y, p.y))
			중심 = (mn2 + mx2) * 0.5
			반 = (mx2 - mn2) * 0.5
		else:
			# ConcavePolygonShape2D 등 — 움직이는 몸에 쓸 모양이 아니다.
			# 여기서 조용히 넘기면 또 "판정만 옛날 크기" 가 되므로 못 잰다고 알린다.
			return {}
	else:
		return {}

	# 자식 노드 자신의 변환(위치·배율)을 반영한다.
	var 자식배율 := Vector2.ONE
	if 자식 is Node2D:
		자식배율 = (자식 as Node2D).scale.abs()
		중심 = 중심 * 자식배율 + (자식 as Node2D).position
		반 = 반 * 자식배율

	return { "최소": 중심 - 반, "최대": 중심 + 반 }
