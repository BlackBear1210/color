extends RefCounted
## ============================================================================
## [2026-09-21 신규] 윤곽 뽑기 — 파낸 격자를 **하나의 캡슐 폴리곤**으로
## ----------------------------------------------------------------------------
## ▣ 도형님 요구 (2026-09-21)
##   "맨 아래의 바닥과 지붕을 전부 하나의 콜리전으로 구성해서 … 하나의 캡슐, 즉 하나의
##    smartshape2D 로 크게 만들어서 큰 뼈대를 잡고 안에 공중 플랫폼이나 튀어나온 바닥을 배치"
##
## ▣ 어떻게 하나 — **빈 공간의 테두리를 따라간다**
##   1. 빈칸(동굴)의 경계 변을 전부 모은다 (바위와 맞닿은 칸 변)
##   2. 변들을 끝점끼리 이어 **닫힌 고리**로 만든다
##        · 가장 큰 고리 = 동굴 바깥 테두리
##        · 나머지 고리 = 동굴 안에 떠 있는 **바위 섬**(= 공중 발판이 된다)
##   3. 껍데기 = [스테이지 바깥 사각형] − [동굴 테두리]
##      폴리곤 하나로 표현하려면 구멍을 바깥과 이어 줘야 한다 → **열쇠구멍(bridge) 절개**
##      절개선은 동굴의 제일 윗점에서 **똑바로 위로** 낸다. 그 위는 전부 바위라 안전하다.
##   4. 계단처럼 자잘한 점을 정리한다(Douglas–Peucker)
##      ★이 단계가 "각진 네모" 를 없앤다. 96 px 계단이 **비스듬한 벽**으로 합쳐진다.
##
## ▣ 왜 절개선이 보이지 않나
##   절개선 양쪽은 같은 바위(같은 재질)라 그림으로는 이어져 보인다. 폴리곤이 갈라지지 않게
##   두 다리를 **서로 다른 점**에 붙인다(한 점에 모으면 폴리곤이 자기 자신을 꼬집어 콜리전이 깨진다).
## ============================================================================

const 동굴_S := preload("res://tools/생성기/동굴.gd")
const 규격 := preload("res://tools/생성기/규격.gd")

## 계단을 직선·사선으로 합칠 때의 허용 오차(px). 칸(96)의 2/3 정도가 보기 좋다.
## 크게 하면 벽이 밋밋해지고, 작게 하면 점이 수백 개로 늘어 SS2D 가 무거워진다.
const 단순화_오차: float = 64.0


## 격자 → {껍데기: PackedVector2Array, 섬들: Array[PackedVector2Array], 동굴테두리: PackedVector2Array}
static func 뽑기(동굴: Dictionary) -> Dictionary:
	var W: int = int(동굴["폭칸"])
	var H: int = int(동굴["높이칸"])
	var 고리들 := _고리들(동굴, W, H)
	if 고리들.is_empty():
		return {}

	# 가장 넓은 고리가 동굴 바깥 테두리다(섬은 반드시 그보다 작다).
	var 최대 := 0
	for i in 고리들.size():
		if _넓이(고리들[i]) > _넓이(고리들[최대]):
			최대 = i
	var 테두리: PackedVector2Array = 고리들[최대]

	var 섬들: Array = []
	for i in 고리들.size():
		if i == 최대:
			continue
		var s: PackedVector2Array = _단순화_고리(고리들[i])
		# 너무 작은 섬은 SS2D 조각으로 만들면 코너가 깨진다. 한 칸짜리 돌기는 껍데기에 맡긴다.
		if _넓이(s) >= float(동굴["칸크기"]) * float(동굴["칸크기"]) * 2.0:
			섬들.append(_시계방향(일직선_제거(s)))

	var 테두리원본 := 테두리

	# ★★단순화는 **동굴을 파고들 수 있다** — 여기가 이 파일에서 제일 위험한 곳이다.
	#   계단을 사선으로 합치는 것이 목적인데, 오차를 크게 잡으면 사선이 통로를 가로질러
	#   **빈 공간을 바위로 덮어 버린다**(실측: 오차 64 에서 최대 1,635 px 짜리 변이 생겨
	#   방 몇 개를 가로질렀다). 그러면 플레이어가 못 지나가는데 도달성 검사는 지형을
	#   기준으로 보므로 "원래 그런 맵" 으로 통과해 버린다.
	#   → 단순화한 뒤 **빈칸이 하나라도 폴리곤 밖으로 나갔는지 직접 센다.** 나갔으면
	#     오차를 절반으로 줄여 다시 한다. 16 px(격자 한 칸)까지 줄여도 안 되면 원본을 쓴다.
	var 오차 := 단순화_오차
	var 테두리단순 := 테두리원본
	var 잘림 := 0
	while 오차 >= 규격.격자:
		var 후보 := _단순화_고리(테두리원본, 오차)
		잘림 = _잘려나간_빈칸(동굴, 후보, W, H)
		# 자기교차도 같이 본다 — 꼬인 폴리곤은 SS2D 채우기와 콜리전 분해가 **조용히** 깨진다.
		if 잘림 == 0 and not _자기교차(후보):
			테두리단순 = 후보
			break
		오차 *= 0.5
	if 잘림 != 0:
		# 어떤 오차로도 안전하지 않으면 **단순화를 포기**한다. 점이 많아 무겁지만 맵은 산다.
		테두리단순 = 테두리원본
		오차 = 0.0

	var 껍데기 := 일직선_제거(_껍데기_만들기(테두리단순, 동굴, W, H))
	return {
		"껍데기": 껍데기, "섬들": 섬들, "동굴테두리": 테두리단순,
		"테두리원본": 테두리원본, "단순화오차": 오차, "잘린빈칸": 잘림,
	}


## 단순화한 테두리가 **원래 빈 공간을 다 품고 있나**. 밖으로 밀려난 빈칸 수를 돌려준다.
## ⚠ 이 검사가 이 알고리즘의 안전장치다. 숫자가 0 이 아니면 그 맵은 쓰면 안 된다.
static func _잘려나간_빈칸(동굴: Dictionary, 테두리: PackedVector2Array, W: int, H: int) -> int:
	var 칸크기: float = float(동굴["칸크기"])
	var 원점: Vector2 = 동굴["원점"]
	var 잘림 := 0
	for y in H:
		for x in W:
			if 동굴_S.읽기(동굴, x, y) != 동굴_S.빈칸:
				continue
			var c := 원점 + Vector2(x + 0.5, y + 0.5) * 칸크기
			if not Geometry2D.is_point_in_polygon(c, 테두리):
				잘림 += 1
	return 잘림


# ============================================================================
# 1·2 단계 — 경계 변을 모아 닫힌 고리로 잇는다
# ============================================================================
## 빈칸 하나하나에 대해 "바위와 맞닿은 변" 을 방향을 붙여 모은다.
## 방향 약속: **빈 공간이 오른쪽**에 오도록 돈다(화면 좌표는 y 가 아래로 커진다).
## 그래야 뒤에서 신발끈으로 방향을 판정할 때 부호가 일정하다.
static func _고리들(동굴: Dictionary, W: int, H: int) -> Array:
	var 시작맵 := {}          # 시작점(정수 칸 좌표 키) → [끝점, ...]
	for y in H:
		for x in W:
			if 동굴_S.읽기(동굴, x, y) != 동굴_S.빈칸:
				continue
			var tl := Vector2i(x, y)
			var tr := Vector2i(x + 1, y)
			var br := Vector2i(x + 1, y + 1)
			var bl := Vector2i(x, y + 1)
			# 위가 바위 → 위쪽 변을 왼쪽으로 지난다 … 네 변을 한 바퀴 돌면 빈칸을 감싼다
			if 동굴_S.읽기(동굴, x, y - 1) == 동굴_S.암반:
				_변_추가(시작맵, tr, tl)
			if 동굴_S.읽기(동굴, x + 1, y) == 동굴_S.암반:
				_변_추가(시작맵, br, tr)
			if 동굴_S.읽기(동굴, x, y + 1) == 동굴_S.암반:
				_변_추가(시작맵, bl, br)
			if 동굴_S.읽기(동굴, x - 1, y) == 동굴_S.암반:
				_변_추가(시작맵, tl, bl)

	var 칸크기: float = float(동굴["칸크기"])
	var 원점: Vector2 = 동굴["원점"]
	var 고리들: Array = []
	while not 시작맵.is_empty():
		var 시작키 = 시작맵.keys()[0]
		var 고리 := PackedVector2Array()
		var 현재: Vector2i = _키_점(시작키)
		var 처음 := 현재
		var 들어온: Vector2i = Vector2i.ZERO
		var 안전 := 0
		var 닫힘 := false
		while 안전 < 400000:
			안전 += 1
			var 키 := _점_키(현재)
			if not 시작맵.has(키) or (시작맵[키] as Array).is_empty():
				break
			# ★갈림길(대각선으로 맞닿은 자리)에서 아무거나 고르면 안 된다.
			#   처음에는 아무 변이나 집었는데, 그러면 걷다가 **막다른 점**에 도착해 고리가
			#   중간에 끊겼다. 끊긴 고리를 닫으면 동굴을 가로지르는 **가짜 대각선 변**이 생긴다
			#   (미리보기에서 분홍 선이 빈 공간을 가로질러 보였던 것이 이것이다).
			#   → 들어온 방향 기준으로 **가장 오른쪽으로 꺾는 변**을 고른다. 이렇게 하면
			#     맞닿은 두 덩어리가 서로 다른 고리로 깔끔하게 갈린다(표준 경계 추적 규칙).
			var 후보: Array = 시작맵[키]
			var 고른 := 0
			if 들어온 != Vector2i.ZERO and 후보.size() > 1:
				var 최고 := -10.0
				for i in 후보.size():
					var v: Vector2i = (후보[i] as Vector2i) - 현재
					# 오른쪽으로 꺾을수록 점수가 높다. (화면 좌표 y 아래 → 오른쪽 = (-y, x))
					var 오른 := Vector2i(-들어온.y, 들어온.x)
					var 점수 := float(v.x * 오른.x + v.y * 오른.y) * 2.0 \
						+ float(v.x * 들어온.x + v.y * 들어온.y)
					if 점수 > 최고:
						최고 = 점수
						고른 = i
			var 다음: Vector2i = 후보[고른]
			후보.remove_at(고른)
			if 후보.is_empty():
				시작맵.erase(키)
			고리.append(원점 + Vector2(현재) * 칸크기)
			들어온 = 다음 - 현재
			현재 = 다음
			if 현재 == 처음:
				닫힘 = true
				break
		# 닫히지 않은 조각은 버린다 — 이어 붙이면 가짜 변이 생긴다.
		if 닫힘 and 고리.size() >= 4:
			고리들.append(고리)
	return 고리들


static func _변_추가(맵: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var k := _점_키(a)
	if not 맵.has(k):
		맵[k] = []
	(맵[k] as Array).append(b)


static func _점_키(p: Vector2i) -> int:
	return p.x * 100000 + p.y          # 격자가 10만 칸을 넘을 일은 없다


static func _키_점(k: int) -> Vector2i:
	return Vector2i(int(k / 100000), int(k % 100000))


# ============================================================================
# 3 단계 — 껍데기(바깥 사각형 − 동굴) 를 폴리곤 **하나**로
# ============================================================================
static func _껍데기_만들기(테두리: PackedVector2Array, 동굴: Dictionary, W: int, H: int) -> PackedVector2Array:
	var 칸크기: float = float(동굴["칸크기"])
	var 원점: Vector2 = 동굴["원점"]
	var 좌상 := 원점
	var 우하 := 원점 + Vector2(W, H) * 칸크기

	# 동굴에서 **제일 위에 있는 점**을 찾는다. 그 위는 반드시 바위라 절개선이 안전하다.
	var 윗점 := 0
	for i in 테두리.size():
		if 테두리[i].y < 테두리[윗점].y or (테두리[i].y == 테두리[윗점].y and 테두리[i].x < 테두리[윗점].x):
			윗점 = i

	# 구멍(동굴)은 바깥 사각형과 **반대 방향**으로 돌아야 한다. 안 그러면 채우기가 뒤집힌다.
	var 구멍 := 테두리
	if _신발끈(구멍) > 0.0:
		구멍 = _뒤집기(구멍)
		윗점 = 구멍.size() - 1 - 윗점

	var 시작 := 구멍[윗점]
	var 다음 := 구멍[(윗점 + 1) % 구멍.size()]

	var p := PackedVector2Array()
	# 바깥 사각형을 시계 방향으로: 왼위 → (절개 왼다리) … (절개 오른다리) → 오른위 → 오른아래 → 왼아래
	p.append(좌상)
	p.append(Vector2(시작.x, 좌상.y))                  # 절개선 왼다리 (위 테두리에서 내려온다)
	# 구멍을 한 바퀴 — 시작점에서 출발해 **다음 점에서 끝난다**(두 다리가 서로 다른 점에 붙게)
	for k in 구멍.size():
		p.append(구멍[(윗점 + k) % 구멍.size()])
	p.append(Vector2(다음.x, 좌상.y))                  # 절개선 오른다리
	p.append(Vector2(우하.x, 좌상.y))
	p.append(우하)
	p.append(Vector2(좌상.x, 우하.y))
	return p


# ============================================================================
# 4 단계 — 단순화 (계단 → 사선)
# ============================================================================
## 닫힌 고리를 Douglas–Peucker 로 줄인다. 고리는 시작·끝이 같으므로 **가장 먼 두 점**으로
## 잘라 두 조각을 따로 줄인 뒤 다시 잇는다(그냥 돌리면 시작점이 항상 살아남아 찌그러진다).
static func _단순화_고리(고리: PackedVector2Array, 오차: float = 단순화_오차) -> PackedVector2Array:
	if 고리.size() < 8:
		return 고리
	# 가장 먼 두 점 찾기(대충 — 최소/최대 x 로 충분하다)
	var a := 0
	var b := 0
	for i in 고리.size():
		if 고리[i].x < 고리[a].x:
			a = i
		if 고리[i].x > 고리[b].x:
			b = i
	if a == b:
		return 고리
	var 앞 := PackedVector2Array()
	var i2 := a
	while true:
		앞.append(고리[i2])
		if i2 == b:
			break
		i2 = (i2 + 1) % 고리.size()
	var 뒤 := PackedVector2Array()
	i2 = b
	while true:
		뒤.append(고리[i2])
		if i2 == a:
			break
		i2 = (i2 + 1) % 고리.size()

	var out := PackedVector2Array()
	out.append_array(_dp(앞, 오차))
	var 뒷조각 := _dp(뒤, 오차)
	for k in range(1, 뒷조각.size() - 1):
		out.append(뒷조각[k])
	return _격자맞춤(out)


static func _dp(점들: PackedVector2Array, 오차: float) -> PackedVector2Array:
	if 점들.size() < 3:
		return 점들
	var 최대 := 0.0
	var 위치 := 0
	var a := 점들[0]
	var b := 점들[점들.size() - 1]
	for i in range(1, 점들.size() - 1):
		var d := 점들[i].distance_to(Geometry2D.get_closest_point_to_segment(점들[i], a, b))
		if d > 최대:
			최대 = d
			위치 = i
	if 최대 <= 오차:
		return PackedVector2Array([a, b])
	var 왼 := _dp(점들.slice(0, 위치 + 1), 오차)
	var 오른 := _dp(점들.slice(위치), 오차)
	var out := PackedVector2Array(왼)
	for k in range(1, 오른.size()):
		out.append(오른[k])
	return out


## 모든 점을 16 격자에 맞추고, 너무 가까이 붙은 점은 버린다.
## ⚠ 16 격자는 저장소 규약이고, 가까운 점 제거는 SS2D 코너 조각이 깨지는 것을 막는다.
static func _격자맞춤(점들: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in 점들:
		var q := 규격.격자맞춤_벡(p)
		if out.is_empty() or out[out.size() - 1].distance_to(q) >= 규격.격자:
			out.append(q)
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) < 규격.격자:
		out.remove_at(out.size() - 1)
	return out


# ============================================================================
# 도우미
# ============================================================================
static func _신발끈(점들: PackedVector2Array) -> float:
	var s := 0.0
	for i in 점들.size():
		var a := 점들[i]
		var b := 점들[(i + 1) % 점들.size()]
		s += a.x * b.y - b.x * a.y
	return s


static func _넓이(점들: PackedVector2Array) -> float:
	return absf(_신발끈(점들)) * 0.5


static func _뒤집기(점들: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(점들.size() - 1, -1, -1):
		out.append(점들[i])
	return out


## 화면 좌표(y 아래로 증가)에서 시계 방향 = 신발끈 합이 **양수**. 저장소 규약과 같다.
static func 시계방향(점들: PackedVector2Array) -> PackedVector2Array:
	return 점들 if _신발끈(점들) > 0.0 else _뒤집기(점들)


static func _시계방향(점들: PackedVector2Array) -> PackedVector2Array:
	return 시계방향(점들)


## 폴리곤이 자기 자신과 꼬였나. 이웃하지 않은 변끼리 교차하면 true.
## ⚠ 점 수가 수백이라 O(n²) 라도 금방이다. 꼬인 폴리곤을 그대로 구우면
##   SS2D 채우기가 뒤집히고 콜리전 볼록 분해가 엉뚱한 덩어리를 만든다(둘 다 에러가 안 난다).
static func _자기교차(점들: PackedVector2Array) -> bool:
	var n := 점들.size()
	if n < 5:
		return false
	for i in n:
		var a1 := 점들[i]
		var a2 := 점들[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue          # 첫 변과 마지막 변은 붙어 있다
			var b1 := 점들[j]
			var b2 := 점들[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return true
	return false


## 일직선 위의 점(앞뒤 점과 외적 ≈ 0)을 뺀다.
## ⚠ 추적한 윤곽선에는 일직선 점이 잔뜩 생긴다(계단 한 칸이 두 점). 그대로 두면
##   `형태.gd` 가 "퇴화점이 끼어 있다 = 손상됐을 수 있다" 로 잡아 저장을 거부한다.
static func 일직선_제거(점들: PackedVector2Array) -> PackedVector2Array:
	var p := PackedVector2Array(점들)
	var 바뀜 := true
	while 바뀜 and p.size() > 3:
		바뀜 = false
		for i in p.size():
			var a: Vector2 = p[(i - 1 + p.size()) % p.size()]
			var b: Vector2 = p[i]
			var c: Vector2 = p[(i + 1) % p.size()]
			if absf((b - a).cross(c - b)) <= 0.5 or a.is_equal_approx(b):
				p.remove_at(i)
				바뀜 = true
				break
	return p
