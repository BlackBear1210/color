extends RefCounted
## ============================================================================
## [2026-08-08 신규] 타일맵 → 스마트 지형(SS2D) 변환기
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가 (도형님 지시)
##   "stage_1-1, 1-2 씬의 지형 구성 즉 맵 레벨 디자인이 끝났기에
##    씬과 똑같은 지형을 스마트월드의 방식으로 다시 재구현해줘."
##   → 손으로 다시 그리면 **레벨 디자인이 미묘하게 달라진다.** 그러면 지금까지의
##     플레이 테스트 결과가 전부 무효가 된다. 그래서 타일맵을 **읽어서** 옮긴다.
##
## ▣ 어떻게 옮기나 — 3 단계
##   1. 윤곽 추출 : 칸 단위로 "이웃이 없는 면"만 모아 **닫힌 고리**로 잇는다.
##                  (마칭 스퀘어와 같은 원리지만, 변을 직접 이어서 꼬임이 원천 봉쇄된다)
##   2. 단순화   : 일직선 위의 점을 지우고, RDP 로 계단을 **경사면**으로 편다.
##                  16px 짜리 계단이 그대로 남으면 규칙 1(최소 64px)을 어길 뿐 아니라
##                  세로 벽이 되어 플레이어가 못 올라간다.
##   3. 규칙 검사: `지형규칙.위반_찾기()` 로 남은 위반을 보고한다.
##
## ▣ 구멍(동굴)을 어떻게 다루나 — ★가장 위험한 부분
##   SS2D_Shape_Closed 는 **구멍이 있는 다각형을 못 만든다.** 바깥 고리만 쓰면
##   그 안의 동굴이 통째로 메워진다 → **플레이어가 지나던 길이 막힌다.**
##   조용히 망가지면 절대 못 찾는 종류의 사고라, 여기서는
##     · 안쪽 고리(구멍)를 전부 찾아서
##     · 플레이어가 들어갈 만한 크기(폭 44 · 키 97)면 **경고하고 목록으로 돌려준다**
##   호출부는 그 구멍을 `유령 지형`이나 별도 처리로 뚫어줄 수 있다.
## ============================================================================
class_name 타일맵변환

const 규칙 := preload("res://scripts/스마트월드/지형규칙.gd")


# ============================================================================
# 1. 칸 모으기
# ============================================================================
## 타일맵에서 "채워진 칸" 집합을 만든다. 키 = Vector2i(셀좌표), 값 = 소스 id.
## x 범위를 주면 그 안만 자른다(스테이지를 여러 개로 쪼갤 때 쓴다).
static func 칸_모으기(층: TileMapLayer,
		셀x_최소: int = -2147483648, 셀x_최대: int = 2147483647) -> Dictionary:
	var 칸: Dictionary = {}
	for c in 층.get_used_cells():
		if c.x < 셀x_최소 or c.x > 셀x_최대:
			continue
		칸[c] = 층.get_cell_source_id(c)
	return 칸


# ============================================================================
# 2. 섬(연결 요소) 나누기
# ============================================================================
## 4-연결로 이어진 덩어리끼리 묶는다. 각 덩어리가 지형 노드 하나가 된다.
## ⚠ 8-연결(대각선 포함)을 쓰면 모서리만 스친 두 덩어리가 하나로 묶여서
##   윤곽 고리가 8자 모양으로 꼬인다. 반드시 4-연결이어야 한다.
static func 섬_나누기(칸: Dictionary) -> Array:
	var 방문: Dictionary = {}
	var 섬들: Array = []
	var 이웃 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for 시작 in 칸:
		if 방문.has(시작):
			continue
		var 덩어리: Dictionary = {}
		var 대기: Array[Vector2i] = [시작]
		방문[시작] = true
		while not 대기.is_empty():
			var c: Vector2i = 대기.pop_back()
			덩어리[c] = 칸[c]
			for d in 이웃:
				var n: Vector2i = c + d
				if 칸.has(n) and not 방문.has(n):
					방문[n] = true
					대기.append(n)
		섬들.append(덩어리)

	# 큰 덩어리부터 — 로그를 읽을 때 중요한 것이 먼저 보인다
	섬들.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size() > b.size())
	return 섬들


# ============================================================================
# 3. 윤곽 고리 뽑기
# ============================================================================
## 덩어리의 경계 고리를 전부 뽑는다. 좌표 단위는 **칸**(나중에 타일크기를 곱한다).
## 반환: [{ "점들": PackedVector2Array, "넓이": float, "바깥": bool }, ...]
##
## ▣ 원리
##   채워진 칸의 네 변 중 **이웃이 비어 있는 변만** 남긴다. 그 변들을
##   "덩어리가 항상 진행 방향의 오른쪽"이 되도록 방향을 주면,
##   변의 끝점이 다음 변의 시작점과 정확히 맞물려 **자동으로 닫힌 고리**가 된다.
##   꼭짓점을 추측하지 않으므로 자기교차가 구조적으로 불가능하다.
static func 윤곽_고리들(덩어리: Dictionary) -> Array:
	# 시작점 → 끝점 (한 시작점에서 두 변이 나갈 수 있어 배열로 든다)
	var 나가는변: Dictionary = {}

	for c in 덩어리:
		var x := float(c.x)
		var y := float(c.y)
		# 화면 좌표계(y 아래)에서 시계 방향으로 한 칸을 돈다:
		#   위쪽 변 왼→오 / 오른쪽 변 위→아래 / 아래쪽 변 오→왼 / 왼쪽 변 아래→위
		if not 덩어리.has(c + Vector2i(0, -1)):
			_변_넣기(나가는변, Vector2(x, y), Vector2(x + 1, y))
		if not 덩어리.has(c + Vector2i(1, 0)):
			_변_넣기(나가는변, Vector2(x + 1, y), Vector2(x + 1, y + 1))
		if not 덩어리.has(c + Vector2i(0, 1)):
			_변_넣기(나가는변, Vector2(x + 1, y + 1), Vector2(x, y + 1))
		if not 덩어리.has(c + Vector2i(-1, 0)):
			_변_넣기(나가는변, Vector2(x, y + 1), Vector2(x, y))

	var 고리들: Array = []
	while not 나가는변.is_empty():
		var 시작: Vector2 = 나가는변.keys()[0]
		var 고리 := PackedVector2Array()
		var 지금 := 시작
		var 안전 := 0
		while 나가는변.has(지금) and 안전 < 400000:
			안전 += 1
			var 목록: Array = 나가는변[지금]
			var 다음: Vector2 = 목록.pop_front()
			if 목록.is_empty():
				나가는변.erase(지금)
			고리.append(지금)
			지금 = 다음
			if 지금 == 시작:
				break
		if 고리.size() >= 4:
			var 넓이 := _부호넓이(고리)
			고리들.append({
				"점들": 고리,
				"넓이": absf(넓이) * 0.5,
				# 시계 방향(부호넓이 > 0) = 바깥 윤곽 / 반시계 = 구멍
				"바깥": 넓이 > 0.0,
			})
	return 고리들


static func _변_넣기(표: Dictionary, 시작: Vector2, 끝: Vector2) -> void:
	if not 표.has(시작):
		표[시작] = []
	(표[시작] as Array).append(끝)


## 부호 있는 넓이 × 2. 화면 좌표계(y 아래)에서 양수면 시계 방향.
static func _부호넓이(점들: PackedVector2Array) -> float:
	var s := 0.0
	for i in 점들.size():
		var a := 점들[i]
		var b := 점들[(i + 1) % 점들.size()]
		s += a.x * b.y - b.x * a.y
	return s


# ============================================================================
# 4. 단순화
# ============================================================================
## 일직선 위에 있는 중간 점을 지운다. 타일 윤곽은 대부분 긴 직선이라
## 이것만으로 점이 10 분의 1 이하로 줄어든다.
static func 직선_합치기(점들: PackedVector2Array, 허용: float = 0.01) -> PackedVector2Array:
	var n := 점들.size()
	if n < 3:
		return 점들
	var 결과 := PackedVector2Array()
	for i in n:
		var 앞 := 점들[(i - 1 + n) % n]
		var 지금 := 점들[i]
		var 뒤 := 점들[(i + 1) % n]
		# 앞→지금 과 지금→뒤 의 방향이 같으면 '지금' 은 없어도 되는 점이다
		var a := (지금 - 앞).normalized()
		var b := (뒤 - 지금).normalized()
		if absf(a.cross(b)) > 허용:
			결과.append(지금)
	return 결과 if 결과.size() >= 3 else 점들


## RDP(Ramer–Douglas–Peucker) — 닫힌 고리용.
## ★계단을 경사면으로 펴는 게 진짜 목적이다.
##   16px 계단이 그대로면 세로 벽이 되어 플레이어가 못 올라간다(규칙 2 위반).
##   허용오차를 타일 크기 정도로 주면 계단 여러 칸이 **하나의 비스듬한 선**이 된다.
static func 고리_단순화(점들: PackedVector2Array, 허용오차: float) -> PackedVector2Array:
	var n := 점들.size()
	if n < 4 or 허용오차 <= 0.0:
		return 점들
	# 닫힌 고리는 시작점이 없다. 서로 가장 먼 두 점을 골라 두 갈래로 나눠 각각 편다.
	var i0 := 0
	var i1 := n / 2
	var 최대 := -1.0
	for i in n:
		var d := 점들[0].distance_squared_to(점들[i])
		if d > 최대:
			최대 = d
			i1 = i
	var 갈래a := PackedVector2Array()
	for i in range(i0, i1 + 1):
		갈래a.append(점들[i])
	var 갈래b := PackedVector2Array()
	for i in range(i1, n):
		갈래b.append(점들[i])
	갈래b.append(점들[0])

	var 결과 := _rdp(갈래a, 허용오차)
	var 뒤 := _rdp(갈래b, 허용오차)
	# 이음매 중복 제거 (갈래a 의 끝 = 갈래b 의 시작, 갈래b 의 끝 = 갈래a 의 시작)
	for i in range(1, 뒤.size() - 1):
		결과.append(뒤[i])
	return 결과 if 결과.size() >= 3 else 점들


static func _rdp(점들: PackedVector2Array, 허용오차: float) -> PackedVector2Array:
	if 점들.size() < 3:
		return 점들
	var 처음 := 점들[0]
	var 끝 := 점들[점들.size() - 1]
	var 최대거리 := -1.0
	var 최대i := 0
	for i in range(1, 점들.size() - 1):
		var d := _점_선_거리(점들[i], 처음, 끝)
		if d > 최대거리:
			최대거리 = d
			최대i = i
	if 최대거리 <= 허용오차:
		return PackedVector2Array([처음, 끝])

	var 왼 := PackedVector2Array()
	for i in range(0, 최대i + 1):
		왼.append(점들[i])
	var 오른 := PackedVector2Array()
	for i in range(최대i, 점들.size()):
		오른.append(점들[i])

	var a := _rdp(왼, 허용오차)
	var b := _rdp(오른, 허용오차)
	var 결과 := PackedVector2Array(a)
	for i in range(1, b.size()):
		결과.append(b[i])
	return 결과


static func _점_선_거리(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var 길이제곱 := ab.length_squared()
	if 길이제곱 < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / 길이제곱, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ============================================================================
# 5. 한 번에 — 타일맵 → 지형 조각 목록
# ============================================================================
## 반환: [{
##   "점들"  : PackedVector2Array (월드 px · 닫힌 다각형 · 시계 방향)
##   "칸수"  : int
##   "소스"  : int         (가장 많이 쓰인 타일 소스 id — 재질 고르기에 쓴다)
##   "범위"  : Rect2       (월드 px)
##   "구멍"  : Array[Rect2] (플레이어가 들어갈 만한 크기의 내부 공동)
## }, ...]
##
##   최소칸수 : 이보다 작은 부스러기 섬은 버린다(1~2칸짜리 점 타일이 지형 노드가 되면
##              노드 수만 늘고 화면에는 안 보인다)
##   허용오차 : RDP 허용오차(px).
##
## ⚠⚠[2026-08-08 · 레벨이 통째로 끊기던 버그. 반드시 읽을 것]
##   처음엔 허용오차를 **타일 한 칸(16px)** 으로 줬다. "계단을 경사면으로 펴려면
##   타일 크기만큼은 줘야 한다"고 생각해서다. 그런데 그 값이 **두께 16px 짜리
##   얇은 발판을 통째로 뭉갰다.**
##     · 얇은 가로 막대의 윤곽은 긴 직사각형이다.
##     · RDP 는 그 직사각형을 대각선으로 두 갈래로 나눠 각각 편다.
##     · 갈래 하나(윗변+오른변)에서 모서리가 현(弦)에서 벗어난 거리는 **두께의 절반(8px)**.
##     · 허용오차 16 ≥ 8 이므로 그 모서리가 **지워져** 직사각형이 삼각형이 된다.
##   결과: 발판이 사라지거나 쐐기가 되어 밟을 수 없게 되고,
##         레벨검사가 "밟는 지형 87 개 중 도달 5 개" 를 뱉었다.
##         씬을 열어 보면 지형이 그럴싸하게 그려져 있어 눈으로는 절대 안 보인다.
##   → 허용오차는 **가장 얇은 구조물 두께의 절반보다 작아야 한다.**
##     타일 16px 기준으로 6px 이 안전하다(8px 여유의 75%).
##     계단은 덜 펴지지만, 그건 **원본 레벨 디자인 그대로**라는 뜻이라 오히려 맞다.
static func 지형조각들(층: TileMapLayer, 셀x_최소: int, 셀x_최대: int,
		최소칸수: int = 6, 허용오차: float = 6.0) -> Array:
	var 타일크기: Vector2i = 층.tile_set.tile_size
	var 칸 := 칸_모으기(층, 셀x_최소, 셀x_최대)
	var 섬들 := 섬_나누기(칸)
	var 조각들: Array = []

	for 덩어리 in 섬들:
		if 덩어리.size() < 최소칸수:
			continue
		var 고리들 := 윤곽_고리들(덩어리)
		if 고리들.is_empty():
			continue

		# 가장 넓은 바깥 고리가 이 섬의 외곽선이다
		var 바깥: Dictionary = {}
		var 구멍들: Array = []
		for 고리 in 고리들:
			if 고리["바깥"]:
				if 바깥.is_empty() or 고리["넓이"] > 바깥["넓이"]:
					바깥 = 고리
			else:
				구멍들.append(고리)
		if 바깥.is_empty():
			continue

		# 칸 좌표 → 월드 px
		var 점들 := PackedVector2Array()
		for p in 바깥["점들"]:
			점들.append(Vector2(p.x * 타일크기.x, p.y * 타일크기.y))
		점들 = 직선_합치기(점들)
		점들 = 고리_단순화(점들, 허용오차)
		점들 = 직선_합치기(점들)
		if 점들.size() < 3:
			continue

		# 소스(타일 종류) 다수결 — 재질을 고르는 데 쓴다
		var 표: Dictionary = {}
		for c in 덩어리:
			var s: int = 덩어리[c]
			표[s] = int(표.get(s, 0)) + 1
		var 대표소스 := -1
		var 최다 := -1
		for s in 표:
			if 표[s] > 최다:
				최다 = 표[s]
				대표소스 = s

		# ★플레이어가 들어갈 만한 구멍만 보고한다 (폭 44 · 키 97)
		var 큰구멍: Array[Rect2] = []
		for h in 구멍들:
			var r := _범위(h["점들"])
			var 월드구멍 := Rect2(
				Vector2(r.position.x * 타일크기.x, r.position.y * 타일크기.y),
				Vector2(r.size.x * 타일크기.x, r.size.y * 타일크기.y))
			if 월드구멍.size.x >= 규칙.플레이어_폭 and 월드구멍.size.y >= 규칙.플레이어_키:
				큰구멍.append(월드구멍)

		조각들.append({
			"점들": 점들,
			"칸수": 덩어리.size(),
			"소스": 대표소스,
			"범위": _범위(점들),
			"구멍": 큰구멍,
		})
	return 조각들


static func _범위(점들: PackedVector2Array) -> Rect2:
	if 점들.is_empty():
		return Rect2()
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	return Rect2(최소, 최대 - 최소)


# ============================================================================
# 6. 진단 — 옮긴 지형이 플레이 가능한가
# ============================================================================
## 조각의 **윗면(위를 향한 면)** 만 뽑는다. 규칙 검사·장식 배치가 이걸 쓴다.
## 다각형 전체를 검사하면 벽·아랫면까지 "경사 위반"으로 잡혀 의미가 없다.
##   위를 향한 면 = 시계 방향 고리에서 x 가 **증가**하는 변 (화면 좌표계 기준)
##
## ⚠ 반환은 **이어진 조각(체인)들의 배열**이다. 하나로 합치면 안 된다 —
##   윗면은 절벽·수직 벽으로 끊겨 있어서, 합치면 끊긴 자리가
##   "수평 간격 0px" 이라는 가짜 규칙 위반으로 보고된다(실제로 그렇게 오판했다).
static func 윗면_체인들(점들: PackedVector2Array) -> Array:
	var 체인들: Array = []
	var 지금 := PackedVector2Array()
	var n := 점들.size()
	for i in n:
		var a := 점들[i]
		var b := 점들[(i + 1) % n]
		if b.x > a.x + 0.01:
			# 앞 변과 이어져 있으면 같은 체인, 아니면 새 체인을 연다
			if 지금.is_empty() or 지금[지금.size() - 1] != a:
				if 지금.size() >= 2:
					체인들.append(지금)
				지금 = PackedVector2Array([a])
			지금.append(b)
		else:
			if 지금.size() >= 2:
				체인들.append(지금)
			지금 = PackedVector2Array()
	if 지금.size() >= 2:
		체인들.append(지금)
	return 체인들


## 가장 긴 윗면 체인 하나. "이 지형의 대표 지면"이 필요할 때 쓴다.
static func 주된_윗면(점들: PackedVector2Array) -> PackedVector2Array:
	var 최장 := PackedVector2Array()
	var 최장폭 := -1.0
	for c in 윗면_체인들(점들):
		var 체인: PackedVector2Array = c
		var 폭: float = 체인[체인.size() - 1].x - 체인[0].x
		if 폭 > 최장폭:
			최장폭 = 폭
			최장 = 체인
	return 최장
