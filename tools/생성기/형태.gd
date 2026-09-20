extends RefCounted
## ============================================================================
## [2026-09-20 신규] 지형 형태 분류·검사 — **점 배열 자체**를 본다
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가 (2026-09-20 실제 사고)
##   집 1-1 적용본이 SS2D 지형 27개 중 22개가 **직각삼각형**으로 무너진 채 발견됐다.
##   원본(생성 직후)은 27/27 직사각형이었고, 에디터에서 저장된 뒤 각 지형의 2번째 점(키 1)이
##   (0,0) 으로 바뀌거나(21개) 아예 삭제(천장 1개)돼 있었다. 그런데 `레벨검사.gd` 는
##   "29/29 도달 · 소프트락 0" 으로 **통과시켰다** — 삼각형 빗변 위도 걸을 수 있기 때문이다.
##   → 도달성·보행성 검사는 **모양이 의도한 것인지** 를 보지 못한다. 그 구멍을 여기서 막는다.
##
## ▣ 무엇을 보나
##   · 유효 꼭짓점 수  : 닫힘용 중복점과 **일직선 위의 점**(퇴화점)을 뺀 수
##   · 분류            : 직사각형 / 사다리꼴 / 삼각형 / 복합
##   · 퇴화            : 일직선 점·중복 점이 끼어 있다 → 손상 또는 손으로 꼬인 흔적
##                       (무너진 사각형은 4점처럼 보이지만 유효 꼭짓점이 3 이라 삼각형으로 잡힌다)
##
## ▣ 이 파일을 쓰는 곳
##   · `조립.gd 저장()`            굽고 나서 다시 읽어 검사 (생성기 자기검증)
##   · `tools/검사_지형형태.gd`     에디터에서 저장된 씬을 사람이 검사할 때
##   · (다음 단계) 형태 어휘 생성기가 "의도한 모양이 그대로 나왔나" 를 비교할 때
## ============================================================================

const 오차: float = 0.5         ## 일직선 판정 여유 (외적 절댓값 px²). 격자 16 이라 이보다 작은 값은 오차뿐이다


## 닫힘용으로 끝에 붙은 첫 점 복사본을 뗀다. SS2D 는 닫힌 도형의 마지막 점 = 첫 점 이다.
static func 닫힘점_제거(점들: PackedVector2Array) -> PackedVector2Array:
	var p := PackedVector2Array(점들)
	if p.size() > 1 and p[0].is_equal_approx(p[p.size() - 1]):
		p.remove_at(p.size() - 1)
	return p


## 일직선 위의 점(앞뒤 점과 외적 ≈ 0)을 뺀 진짜 꼭짓점. 한 번에 하나씩 빼며 안정될 때까지 되풀이한다.
##   ★"한 번에 다 빼면" 안 되는 이유: 세 점이 연달아 일직선이면 가운데만 빼야 하는데,
##     동시에 판정하면 양 끝도 같이 빠져 도형이 사라진다.
static func 유효_꼭짓점(점들: PackedVector2Array) -> PackedVector2Array:
	var p := 닫힘점_제거(점들)
	var 바뀜 := true
	while 바뀜 and p.size() > 3:
		바뀜 = false
		for i in p.size():
			var a: Vector2 = p[(i - 1 + p.size()) % p.size()]
			var b: Vector2 = p[i]
			var c: Vector2 = p[(i + 1) % p.size()]
			if absf((b - a).cross(c - b)) <= 오차 or a.is_equal_approx(b):
				p.remove_at(i)
				바뀜 = true
				break
	return p


static func 넓이(점들: PackedVector2Array) -> float:
	var p := 닫힘점_제거(점들)
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return absf(s) * 0.5


## 분류. 반환: "직사각형" | "사다리꼴" | "삼각형" | "복합" | "붕괴"(넓이 0 · 점 3 미만)
static func 분류(점들: PackedVector2Array) -> String:
	var v := 유효_꼭짓점(점들)
	if v.size() < 3 or 넓이(v) < 1.0:
		return "붕괴"
	if v.size() == 3:
		return "삼각형"
	if v.size() == 4:
		var xs := {}
		var ys := {}
		for q in v:
			xs[roundi(q.x)] = true
			ys[roundi(q.y)] = true
		if xs.size() == 2 and ys.size() == 2:
			return "직사각형"
		return "사다리꼴"        # 4점이지만 축에 안 맞는 것 = 사다리꼴·기울어진 사각형
	return "복합"


## 퇴화점(일직선·중복 점)이 끼어 있나 — 닫힘 복사본을 뺀 점 수 ≠ 유효 꼭짓점 수
static func 퇴화점_있나(점들: PackedVector2Array) -> bool:
	return 닫힘점_제거(점들).size() != 유효_꼭짓점(점들).size()


## SS2D 지형 노드의 점을 월드 변환 없이(로컬) 순서대로 읽는다. SS2D 가 아니면 빈 배열.
static func 노드_점들(노드: Node) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not 노드.has_method("get_point_array"):
		return out
	var pa = 노드.get_point_array()
	if pa == null:
		return out
	for k in pa.get_all_point_keys():
		out.append(pa.get_point_position(k))
	return out


## 씬 안의 SS2D 지형을 전부 검사한다. `지형` 노드 밑만 본다(배경·조명의 SS2D 는 대상이 아니다).
##   돌려주는 것: {"개수", "분류별": {이름: 개수}, "문제": [String], "삼각형": [이름], "표": [[이름, 분류, 유효점수]]}
static func 검사(루트: Node, 지형통_이름: String = "지형") -> Dictionary:
	var r := {"개수": 0, "분류별": {}, "문제": [], "삼각형": [], "표": []}
	var 통 := 루트.get_node_or_null(지형통_이름)
	if 통 == null:
		(r["문제"] as Array).append("`%s` 노드가 없다" % 지형통_이름)
		return r
	for n in 통.get_children():
		var 점들 := 노드_점들(n)
		if 점들.is_empty():
			continue                                  # SS2D 가 아닌 자식(표식 등)
		r["개수"] += 1
		var 종류 := 분류(점들)
		r["분류별"][종류] = int(r["분류별"].get(종류, 0)) + 1
		(r["표"] as Array).append([String(n.name), 종류, 유효_꼭짓점(점들).size()])
		if 종류 == "삼각형":
			(r["삼각형"] as Array).append(String(n.name))
		if 종류 == "붕괴":
			(r["문제"] as Array).append("%s: 형태가 붕괴했다(넓이 0 또는 점 3 미만)" % n.name)
		elif 퇴화점_있나(점들):
			(r["문제"] as Array).append("%s: 일직선·중복 점이 끼어 있다(점 %d → 유효 %d) — 점 배열이 손상됐을 수 있다"
				% [n.name, 닫힘점_제거(점들).size(), 유효_꼭짓점(점들).size()])
	return r
