extends RefCounted
## ============================================================================
## [2026-09-21 신규] 동굴 파기 — v2 알고리즘의 1 단계
## ----------------------------------------------------------------------------
## ▣ v1 이 왜 틀렸나 (도형님 지적 2026-09-21)
##   v1 은 **발판을 하나씩 만들어 이어 붙였다.** 그래서 화면이 "도형을 붙여 넣은 것" 으로 보였고,
##   길이 한 줄기라 플레이어가 탐험할 것이 없었다. 지형이 전부 네모/세모인 것도 같은 원인이다 —
##   조각을 만드는 알고리즘은 조각처럼 생긴 결과만 낸다.
##
## ▣ v2 의 생각 뒤집기 — **지형을 만들지 않고, 바위를 판다**
##   Ori·레인월드의 맵이 그렇게 생긴 이유는 그것이 **깎여 나간 공간**이기 때문이다.
##     1. 스테이지 전체를 **꽉 찬 바위**로 시작한다
##     2. 방(챔버)과 통로를 **파낸다**
##     3. 파고 남은 바위의 **경계선**을 그대로 SS2D 로 만든다  ← `윤곽.gd`
##   그래서 바깥 껍데기(바닥+천장+벽)가 자동으로 **하나로 이어진 캡슐**이 되고,
##   벽에서 튀어나온 돌기도 "따로 놓은 물체" 가 아니라 **껍데기의 일부**가 된다.
##   도형님이 말한 "큰 뼈대를 잡고 안에 배치" 가 정확히 이 구조다.
##
## ▣ 탐험이 되게 하는 것 = 그래프에 **고리**를 넣는 것
##   길이 한 줄기면 아무리 길어도 "앞으로 가기" 만 남는다. 방을 잇는 그래프에
##   **최소 신장 트리 + 여분 간선**을 넣으면 고리가 생기고, 고리가 생기는 순간
##   플레이어는 "어느 쪽으로 갈까" 를 고민하게 된다. 막다른 방은 보상을 두는 자리다.
##
## ▣ 격자 한 칸 = 96 px 인 이유
##   · 플레이어 키 97 → 한 칸으로는 못 지나간다. 통로는 최소 3 칸(288)을 판다.
##   · 96 = 16 격자의 6 배라 꼭짓점이 저절로 16 격자에 맞는다(저장소 규약).
##   · 64 로 하면 윤곽선의 한 변이 64 px 이라 SS2D 코너 조각이 깨진다(변 ≥ 90 규약).
## ============================================================================

const 규격 := preload("res://tools/생성기/규격.gd")

const 암반: int = 1
const 빈칸: int = 0


## 동굴 하나를 판다.
##   돌려주는 것 = {칸, 폭칸, 높이칸, 칸크기, 원점, 방들, 시작칸, 출구칸, 통로들}
static func 파기(설정: RefCounted, rng: RandomNumberGenerator) -> Dictionary:
	var 칸크기: float = float(설정.칸크기)
	var W: int = int(설정.폭칸)
	var H: int = int(설정.높이칸)

	# 1) 전부 바위로 시작한다. 여기서부터 **파내기만** 한다.
	var 칸 := PackedByteArray()
	칸.resize(W * H)
	칸.fill(암반)

	# 2) 방을 놓는다 — 층(벨트)을 나눠 놓아야 위아래로도 탐험이 된다.
	var 방들 := _방_놓기(설정, rng, W, H)
	if 방들.size() < 3:
		return {}

	# 3) 방을 잇는다(트리 + 고리) → 통로 목록
	var 간선 := _간선_잇기(방들, 설정, rng)

	# ★보호 마스크 — "여기는 절대 다시 메우면 안 된다" 는 칸.
	#   4·5 단계에서 벽을 울퉁불퉁하게 만들 때, 통로 한가운데까지 메워 버리면 길이 끊긴다.
	#   그러면 `_고립_메우기` 가 그 너머 방을 **통째로 지워** 맵의 절반이 사라진다(실제로 그렇게 된다).
	#   → 통로의 중심선과 방 바닥 위 2 칸은 보호한다. 2 칸인 이유는 플레이어 키가 97 = 한 칸(96)보다
	#     크기 때문이다. 한 칸만 보호하면 "길은 이어져 있는데 사람은 못 지나가는" 맵이 나온다.
	var 보호 := PackedByteArray()
	보호.resize(W * H)
	보호.fill(0)

	# 4) 실제로 판다
	for 방 in 방들:
		_방_파기(칸, W, H, 방, 보호, rng, 설정)
	var 통로들: Array = []
	for e in 간선:
		var t := _통로_파기(칸, W, H, 방들[e[0]], 방들[e[1]], 설정, rng, 보호)
		if not t.is_empty():
			통로들.append(t)

	# 5) 생김새 만들기 — 여기서 "지하철 노선도" 가 "동굴" 이 된다
	_울퉁불퉁(칸, W, H, 보호, 설정, rng)      # 벽면을 흔든다(각진 네모 없애기)
	_선반_내기(칸, W, H, 보호, 설정, rng)      # 방 안에 튀어나온 바닥·처마
	_돌기_내기(칸, W, H, 보호, 설정, rng)      # 석순·종유석

	# 5-b) ★통행 잇기 — 걸어서 못 가는 구역까지 계단 터널을 판다(생김새 단계 뒤에 해야 한다)
	var 시작칸0 := Vector2i(방들[0]["사각"].position.x + 2, 방들[0]["사각"].end.y - 2)
	var 통행보고 := _통행_잇기(칸, W, H, 보호, 시작칸0, int(설정.통로_굵기))

	# 6) 끊어진 빈 공간(파다 만 주머니)은 다시 메운다.
	#    ⚠ 안 하면 플레이어가 갈 수 없는 방이 남고, 윤곽선에 섬이 하나 더 생겨 검사에서 걸린다.
	var 시작방: Dictionary = 방들[0]
	var 시작칸 := Vector2i(시작방["사각"].position.x + 2, 시작방["사각"].end.y - 2)
	_고립_메우기(칸, W, H, 시작칸)

	# 출구는 **시작에서 제일 먼 방**으로 둔다 — 스테이지를 다 훑게 만든다.
	var 출구방: Dictionary = _가장_먼_방(방들, 시작방)
	var 출구칸 := Vector2i(출구방["사각"].end.x - 2, 출구방["사각"].end.y - 2)

	return {
		"칸": 칸, "폭칸": W, "높이칸": H, "칸크기": 칸크기,
		"원점": Vector2(설정.원점_x, 설정.원점_y),
		"방들": 방들, "통로들": 통로들,
		"시작칸": 시작칸, "출구칸": 출구칸,
		"시작방": 시작방, "출구방": 출구방,
		"통행보고": 통행보고,
	}


# ============================================================================
# 방 놓기
# ============================================================================
## 벨트(가로 띠)마다 방을 늘어놓는다. 벨트를 쓰는 이유는 **층이 생겨야 위아래 탐험이 되기** 때문이다.
## 방 크기를 크게 흔드는 것도 중요하다 — 같은 크기 방이 늘어서면 복도처럼 보인다.
static func _방_놓기(설정: RefCounted, rng: RandomNumberGenerator, W: int, H: int) -> Array:
	var 방들: Array = []
	var 벨트수: int = int(설정.벨트수)
	var 벨트높이: int = int(float(H - 4) / float(벨트수))
	var 번호 := 0

	for b in 벨트수:
		var y0: int = 2 + b * 벨트높이
		var y1: int = y0 + 벨트높이 - 1
		var x: int = 3 + rng.randi_range(0, 3)
		while x < W - 8:
			var w: int = rng.randi_range(int(설정.방_최소폭), int(설정.방_최대폭))
			var h: int = rng.randi_range(int(설정.방_최소높이), mini(int(설정.방_최대높이), 벨트높이 - 2))
			if x + w > W - 3:
				break
			# 벨트 안에서 위아래로 흔든다 — 방 바닥 높이가 제각각이어야 "뒤죽박죽" 이 된다.
			var y: int = clampi(y0 + rng.randi_range(0, maxi(벨트높이 - h - 1, 0)), 1, H - h - 2)
			번호 += 1
			방들.append({
				"이름": "방%02d" % 번호,
				"사각": Rect2i(x, y, w, h),
				"벨트": b,
				"종류": "일반",
			})
			# 방 사이 간격 — 최소 3 칸은 남겨야 통로가 "벽을 뚫고 간다" 는 느낌이 난다.
			# 방 사이 간격을 좁게 두면 이웃 방끼리 **붙어서 큰 공동**이 된다 — Ori 처럼 보이려면 이게 필요하다
			x += w + rng.randi_range(2, 5)
	if 방들.is_empty():
		return 방들

	# 시작은 제일 왼쪽 아래, 그 방을 0 번으로 올린다.
	var 시작 := 0
	for i in 방들.size():
		var a: Rect2i = 방들[i]["사각"]
		var b2: Rect2i = 방들[시작]["사각"]
		if a.position.x < b2.position.x or (a.position.x == b2.position.x and a.position.y > b2.position.y):
			시작 = i
	var t = 방들[0]
	방들[0] = 방들[시작]
	방들[시작] = t
	방들[0]["종류"] = "시작"
	return 방들


static func _중심(방: Dictionary) -> Vector2i:
	var r: Rect2i = 방["사각"]
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


static func _가장_먼_방(방들: Array, 기준: Dictionary) -> Dictionary:
	var c0 := _중심(기준)
	var 최고: Dictionary = 방들[0]
	var 최대 := -1.0
	for 방 in 방들:
		var d := Vector2(_중심(방) - c0).length()
		if d > 최대:
			최대 = d
			최고 = 방
	return 최고


# ============================================================================
# 간선(어느 방과 어느 방을 이을 것인가)
# ============================================================================
## ▣ 트리만 만들면 길이 한 줄기다 → **여분 간선**을 넣어 고리를 만든다.
##   고리가 있어야 "돌아서 왔더니 아까 그 방" 이라는 탐험 경험이 생긴다(도형님 요구).
##   여분 비율이 너무 높으면 뻥 뚫린 큰 방 하나처럼 되므로 0.3~0.4 가 적당하다.
static func _간선_잇기(방들: Array, 설정: RefCounted, rng: RandomNumberGenerator) -> Array:
	var n := 방들.size()
	# 가까운 순서대로 후보를 만든다(완전 그래프는 n 이 작아 부담 없다)
	var 후보: Array = []
	for i in n:
		for j in range(i + 1, n):
			var d := Vector2(_중심(방들[i]) - _중심(방들[j])).length()
			후보.append([d, i, j])
	후보.sort_custom(func(a, b): return a[0] < b[0])

	# 최소 신장 트리 (크러스컬) — 모든 방이 반드시 이어지게 한다
	var 부모: Array[int] = []
	for i in n:
		부모.append(i)
	var 찾기 := func(x: int) -> int:
		while 부모[x] != x:
			부모[x] = 부모[부모[x]]
			x = 부모[x]
		return x
	var 간선: Array = []
	var 남은: Array = []
	for c in 후보:
		var a: int = 찾기.call(c[1])
		var b: int = 찾기.call(c[2])
		if a != b:
			부모[a] = b
			간선.append([c[1], c[2]])
		else:
			남은.append(c)

	# 여분 간선 = 고리. 짧은 것부터 넣어야 통로가 꼬여 보이지 않는다.
	var 여분: int = int(round(float(간선.size()) * float(설정.고리_비율)))
	for k in mini(여분, 남은.size()):
		간선.append([남은[k][1],남은[k][2]])
	return 간선


# ============================================================================
# 파기
# ============================================================================
static func _칸_비우기(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> void:
	if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
		return                      # 바깥 한 칸은 **항상 바위** — 껍데기가 뚫리면 캡슐이 아니다
	칸[y * W + x] = 빈칸


static func _칸_읽기(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return 암반
	return 칸[y * W + x]


## 방 하나를 판다.
## ★네모로 파지 않는다. 크기가 다른 덩어리 3~6 개를 **겹쳐서** 판다.
##   네모 한 개로 파면 아무리 흔들어도 네모로 보인다(v1 의 실패와 같은 이유다).
##   덩어리를 겹치면 벽이 들쭉날쭉해지고, 천장 높이도 자리마다 달라진다.
static func _방_파기(칸: PackedByteArray, W: int, H: int, 방: Dictionary,
		보호: PackedByteArray, rng: RandomNumberGenerator, 설정: RefCounted) -> void:
	var r: Rect2i = 방["사각"]
	# ① 본체 — 방 사각형의 가운데 대부분. 가장자리는 아래 덩어리들이 알아서 넓힌다.
	var 덩어리: Array[Rect2i] = []
	덩어리.append(Rect2i(r.position.x + 1, r.position.y + 1, maxi(r.size.x - 2, 2), maxi(r.size.y - 2, 2)))
	# ② 곁가지 — 사방으로 튀어나온 작은 덩어리
	var n := rng.randi_range(3, 6)
	for i in n:
		var w := rng.randi_range(2, maxi(r.size.x / 2, 3))
		var h := rng.randi_range(2, maxi(r.size.y / 2, 2))
		var x := rng.randi_range(r.position.x - 1, r.end.x - w + 1)
		# ★곁가지가 방 바닥보다 **아래로** 내려가면 방 안에 구덩이가 생긴다.
		#   구덩이는 1 칸이면 다시 올라오지만 2 칸이면 못 올라온다(한계 128) → 바닥 위로만 판다.
		var y := rng.randi_range(r.position.y - 1, maxi(r.end.y - h, r.position.y))
		덩어리.append(Rect2i(x, y, w, h))
	for d in 덩어리:
		for y in range(d.position.y, d.end.y):
			for x in range(d.position.x, d.end.x):
				_칸_비우기(칸, W, H, x, y)

	# ③ 방 바닥 위 2 칸을 보호한다 — 방을 가로지를 수는 있어야 한다.
	#    (2 칸 = 192 px. 플레이어 키 97 + 여유)
	var 바닥y: int = r.end.y - 1
	for x in range(r.position.x, r.end.x):
		for k in 2:
			_보호_표시(보호, W, H, x, 바닥y - k)
			_칸_비우기(칸, W, H, x, 바닥y - k)


## 두 방을 L 자로 잇는다. 통로 굵기는 3 칸(288 px) — 플레이어 키 97 에 점프 여유까지.
## ⚠ 세로 통로(수직 갱도)는 **파기만 해서는 못 올라간다.** `배치.gd` 가 지그재그 발판을 넣는다.
static func _통로_파기(칸: PackedByteArray, W: int, H: int, a: Dictionary, b: Dictionary,
		설정: RefCounted, rng: RandomNumberGenerator, 보호: PackedByteArray) -> Dictionary:
	# ★★통로는 방 **한가운데**가 아니라 **바닥 높이**로 뚫는다.
	#   처음에는 중심끼리 이었는데, 그러면 통로가 방 중간 허공에서 시작해
	#   방 바닥과 통로 바닥이 2~4 칸씩 어긋났다. 플레이어는 한 번에 1 칸(96)밖에 못 오르므로
	#   **걸어서 통로에 들어갈 수가 없다** — `레벨검사` 가 "도달 0 / 87" 을 낸 진짜 원인이다.
	#   바닥 높이로 뚫으면 가로 통로는 그대로 걸어 들어가는 굴이 되고,
	#   높이 차이는 세로 구간 한 곳에 모여 **사다리를 놓을 자리**가 된다.
	var ra: Rect2i = a["사각"]
	var rb: Rect2i = b["사각"]
	var ca := Vector2i(ra.position.x + ra.size.x / 2, ra.end.y - 2)
	var cb := Vector2i(rb.position.x + rb.size.x / 2, rb.end.y - 2)
	var 굵기: int = int(설정.통로_굵기)

	# ★★통로는 **계단식**으로 판다 — 이것이 v2 에서 제일 중요한 한 가지다.
	#   곧은 세로 갱도를 파면 공간은 이어지지만 **플레이어가 못 올라간다**(한 번에 1 칸 96px).
	#   그래서 처음엔 갱도에 사다리 발판을 넣어 때우려 했는데, 실측해 보니
	#   설 수 있는 칸이 46 덩어리로 쪼개지고 그중 5 % 만 시작점과 이어졌다.
	#   → "파고 나서 발판으로 고친다" 를 버리고, **애초에 걸어 다닐 수 있게 판다.**
	#     한 칸 올라갈 때마다 옆으로 2~3 칸 파면 계단이 되고, 위아래 양방향 통행이 보장된다.
	#     덤으로 곧은 갱도가 사라져 통로가 유기적으로 보인다.
	var 현재 := ca
	var 안전 := 0
	var 꺾임 := ca
	var 세로있음 := false
	var 지그 := 0                  ## 지그재그 계단의 좌우 번갈이 카운터
	while 현재 != cb and 안전 < 400:
		안전 += 1
		var dy: int = signi(cb.y - 현재.y)
		var dx: int = signi(cb.x - 현재.x)
		if dy != 0:
			# 한 칸 오르내린 뒤, 그 높이에서 옆으로 2~3 칸 — 이게 계단 한 단이다
			현재.y += dy
			세로있음 = true
			꺾임 = 현재
			_기둥_파기(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
			# ★두 방이 **위아래로 나란히** 있으면 dx 가 0 이라 옆으로 안 퍼진다.
			#   그러면 결국 곧은 굴뚝이 되어 또 못 올라간다(실측: 그 굴뚝 너머가 전부 'x' 였다).
			#   → dx 가 0 일 때는 **좌우를 번갈아** 가며 지그재그 계단을 판다.
			#     목표 x 에서 3 칸 넘게 벗어나지 않으므로 굴뚝 폭 안에서 갈지자로 올라간다.
			var 방향 := dx
			if 방향 == 0:
				방향 = 1 if (지그 % 2 == 0) else -1
				지그 += 1
			var 단폭 := rng.randi_range(2, 3)
			for k in 단폭:
				var nx: int = 현재.x + 방향
				if dx == 0 and absi(nx - cb.x) > 3:
					break
				if dx != 0 and 현재.x == cb.x:
					break
				현재.x = nx
				_기둥_파기(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
		elif dx != 0:
			현재.x += dx
			_기둥_파기(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
		else:
			break
	return {"a": a["이름"], "b": b["이름"], "꺾임": 꺾임, "세로": 세로있음}


## 통로 한 칸(세로로 `굵기` 만큼)을 판다. **바닥 쪽 2 칸은 보호**한다.
## 보호하는 이유: 울퉁불퉁·돌기 단계가 통로 바닥을 메우면 그 너머가 통째로 끊긴다.
static func _기둥_파기(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		x: int, y: int, 굵기: int) -> void:
	for d in range(0, 굵기):
		_칸_비우기(칸, W, H, x, y - d)
	_보호_표시(보호, W, H, x, y)
	_보호_표시(보호, W, H, x, y - 1)


# ============================================================================
# 돌기 — 껍데기에서 튀어나온 바위
# ----------------------------------------------------------------------------
# ▣ 이것이 v2 의 "생김새" 를 만든다
#   벽·천장·바닥에서 1~3 칸짜리 바위가 튀어나오게 한다. 플레이어는 그걸 **넘어가야** 한다
#   (도형님: "중간중간 튀어나오게 디자인 되어서 하나의 장애물로 작용").
# ▣ 안전 규칙 — 돌기가 길을 막으면 안 된다
#   돌기를 내기 전에 **그 자리 위아래로 3 칸(288 px) 이상 빈 공간이 남는지** 본다.
#   남지 않으면 그 돌기는 포기한다. 이 검사가 없으면 통로가 막혀 스테이지가 죽는다.
# ============================================================================
## 보호 표시 — 이 칸은 다시 메우지 않는다
static func _보호_표시(보호: PackedByteArray, W: int, H: int, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	보호[y * W + x] = 1


static func _보호인가(보호: PackedByteArray, W: int, H: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	return 보호[y * W + x] == 1


## 이웃 8 칸 중 바위가 몇 개인가 — 울퉁불퉁 단계의 판단 근거
static func _이웃_바위수(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _칸_읽기(칸, W, H, x + dx, y + dy) == 암반:
				n += 1
	return n


# ============================================================================
# 울퉁불퉁 — 벽면을 흔들어 "각진 네모" 를 없앤다 (셀룰러 오토마타)
# ----------------------------------------------------------------------------
# ▣ 규칙 (동굴 생성에서 흔히 쓰는 것을 이 게임에 맞게 고친 것)
#   경계 칸만 본다. 이웃 8 칸 중 바위가 **많으면 바위가 되고, 적으면 빈칸이 된다.**
#   이것을 2~3 번 돌리면 직선 벽이 자연스럽게 무너져 덩어리진 윤곽이 된다.
# ▣ 이 게임만의 제약 두 가지
#   ① 보호 칸은 절대 메우지 않는다 — 길이 끊기면 그 너머 방이 통째로 사라진다
#   ② 바깥 테두리 한 칸은 항상 바위 — 껍데기가 뚫리면 "하나의 캡슐" 이 아니게 된다
# ============================================================================
static func _울퉁불퉁(칸: PackedByteArray, W: int, H: int, 보호: PackedByteArray,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	var 횟수: int = int(설정.울퉁불퉁_횟수)
	for _t in 횟수:
		var 원본 := 칸.duplicate()
		for y in range(2, H - 2):
			for x in range(2, W - 2):
				var i := y * W + x
				var 이웃 := _이웃_바위수(원본, W, H, x, y)
				if 원본[i] == 빈칸:
					# 사방이 바위에 가까운 빈칸은 메운다 = 구석이 둥글어진다
					if 이웃 >= 6 and not _보호인가(보호, W, H, x, y):
						칸[i] = 암반
				else:
					# 바위인데 주위가 뻥 뚫려 있으면 깎는다 = 튀어나온 모서리가 부드러워진다
					if 이웃 <= 2:
						칸[i] = 빈칸


# ============================================================================
# 선반 — 방 안 벽에서 **튀어나온 바닥**
# ----------------------------------------------------------------------------
# 도형님 요구: "뼈대처럼 크게 둘러싼 지형도 중간중간 튀어나오게 디자인 되어서
#              하나의 장애물로 작용되서 캐릭터가 넘어가게 되는거야."
# → 따로 놓는 발판(SS2D 조각)이 아니라 **껍데기에서 자란 바위**다. 그래서 여기서 판다.
# 규칙: 벽에 붙여서 가로로 2~5 칸, 두께 1 칸. 위로 3 칸 여유가 없으면 포기한다.
# ============================================================================
static func _선반_내기(칸: PackedByteArray, W: int, H: int, 보호: PackedByteArray,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	var 개수: int = int(설정.선반_개수)
	var 시도 := 0
	var 놓음 := 0
	while 놓음 < 개수 and 시도 < 개수 * 40:
		시도 += 1
		var x := rng.randi_range(3, W - 5)
		var y := rng.randi_range(3, H - 4)
		if _칸_읽기(칸, W, H, x, y) != 빈칸:
			continue
		# 왼쪽이나 오른쪽이 벽이어야 "벽에서 튀어나온" 선반이 된다
		var 오른쪽 := _칸_읽기(칸, W, H, x - 1, y) == 암반
		var 왼쪽 := _칸_읽기(칸, W, H, x + 1, y) == 암반
		if not (오른쪽 or 왼쪽):
			continue
		# ★★선반은 **바닥에서 한 칸 위**에만 놓는다.
		#   처음에는 방 안 아무 높이에나 놓았는데, 그러면 선반 위가 어디서도 닿지 않는
		#   외딴 섬이 된다(실측: 설 수 있는 칸이 41 덩어리로 쪼개졌고 그중 58 % 만 이어져 있었다).
		#   바닥에서 1~2 칸 위에 붙이면 **걸어와서 한 번 뛰어 올라가는 턱**이 되고,
		#   그게 도형님이 말한 "튀어나와서 넘어가게 되는 장애물" 이다.
		var 바닥깊이 := 0
		while 바닥깊이 < 4 and _칸_읽기(칸, W, H, x, y + 1 + 바닥깊이) == 빈칸:
			바닥깊이 += 1
		if 바닥깊이 < 1 or 바닥깊이 > 2:
			continue
		var 길이 := rng.randi_range(2, 5)
		var dir := 1 if 오른쪽 else -1
		# 놓을 자리가 전부 빈칸이고, 머리 위 3 칸이 비어 있어야 한다(밟고 설 수 있어야 하니까)
		var 가능 := true
		for k in 길이:
			var xx := x + dir * k
			if _칸_읽기(칸, W, H, xx, y) != 빈칸 or _보호인가(보호, W, H, xx, y):
				가능 = false
				break
			for h in range(1, 4):
				if _칸_읽기(칸, W, H, xx, y - h) != 빈칸:
					가능 = false
					break
			if not 가능:
				break
		if not 가능:
			continue
		for k in 길이:
			칸[y * W + (x + dir * k)] = 암반
		놓음 += 1


static func _돌기_내기(칸: PackedByteArray, W: int, H: int, 보호: PackedByteArray,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	var 확률: float = float(설정.돌기_확률)
	var 최대길이: int = int(설정.돌기_최대길이)
	var 최소여유: int = int(설정.통로_굵기)          # 돌기 뒤에 남겨야 할 세로 빈칸

	# 바닥 돌기(석순) · 천장 돌기(종유석) 을 따로 돈다. 벽 돌기는 가로로 낸다.
	for x in range(2, W - 2):
		for y in range(2, H - 2):
			if _칸_읽기(칸, W, H, x, y) != 암반:
				continue
			if rng.randf() > 확률:
				continue
			# 보호 칸(통로 중심선·방 바닥)에는 돌기를 세우지 않는다 — 길이 막힌다
			if _보호인가(보호, W, H, x, y - 1) or _보호인가(보호, W, H, x, y + 1):
				continue
			# 위쪽이 빈칸이면 = 이 바위는 바닥이다 → 위로 석순을 세운다
			if _칸_읽기(칸, W, H, x, y - 1) == 빈칸:
				var 길이 := rng.randi_range(1, 최대길이)
				if _세로여유(칸, W, H, x, y - 1 - 길이, -1) >= 최소여유:
					for k in 길이:
						칸[(y - 1 - k) * W + x] = 암반
			# 아래쪽이 빈칸이면 = 천장이다 → 아래로 종유석을 내린다
			elif _칸_읽기(칸, W, H, x, y + 1) == 빈칸:
				var 길이2 := rng.randi_range(1, 최대길이)
				if _세로여유(칸, W, H, x, y + 1 + 길이2, 1) >= 최소여유:
					for k in 길이2:
						칸[(y + 1 + k) * W + x] = 암반


## (x,y) 에서 dir 방향으로 연속된 빈칸이 몇 칸인가. 돌기가 길을 막는지 보는 데 쓴다.
static func _세로여유(칸: PackedByteArray, W: int, H: int, x: int, y: int, dir: int) -> int:
	var n := 0
	var yy := y
	while yy > 0 and yy < H - 1 and _칸_읽기(칸, W, H, x, yy) == 빈칸:
		n += 1
		yy += dir
		if n > 40:
			break
	return n


# ============================================================================
# 고립 메우기 — 시작 지점에서 못 가는 빈 공간은 바위로 되돌린다
# ============================================================================
static func _고립_메우기(칸: PackedByteArray, W: int, H: int, 시작: Vector2i) -> void:
	var 닿음 := PackedByteArray()
	닿음.resize(W * H)
	닿음.fill(0)
	var 줄: Array = [시작]
	닿음[시작.y * W + 시작.x] = 1
	while not 줄.is_empty():
		var p: Vector2i = 줄.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H:
				continue
			var k := q.y * W + q.x
			if 닿음[k] == 1 or 칸[k] == 암반:
				continue
			닿음[k] = 1
			줄.append(q)
	for i in 칸.size():
		if 칸[i] == 빈칸 and 닿음[i] == 0:
			칸[i] = 암반


# ============================================================================
# 좌표 변환 · 조회 (다른 모듈이 쓴다)
# ============================================================================
static func 칸_월드(동굴: Dictionary, x: int, y: int) -> Vector2:
	return (동굴["원점"] as Vector2) + Vector2(x, y) * float(동굴["칸크기"])


static func 월드_칸(동굴: Dictionary, p: Vector2) -> Vector2i:
	var v := (p - (동굴["원점"] as Vector2)) / float(동굴["칸크기"])
	return Vector2i(int(floor(v.x)), int(floor(v.y)))


static func 읽기(동굴: Dictionary, x: int, y: int) -> int:
	return _칸_읽기(동굴["칸"], int(동굴["폭칸"]), int(동굴["높이칸"]), x, y)


## 빈칸인데 **바로 아래가 바위** = 설 수 있는 자리. 배치·검증이 이걸 기준으로 쓴다.
static func 설_수_있나(동굴: Dictionary, x: int, y: int) -> bool:
	return 읽기(동굴, x, y) == 빈칸 and 읽기(동굴, x, y + 1) == 암반


## (x,y) 위로 머리 여유가 몇 칸인가 — 발판을 놓거나 통로를 볼 때 쓴다.
static func 머리여유(동굴: Dictionary, x: int, y: int) -> int:
	var n := 0
	var yy := y
	while 읽기(동굴, x, yy) == 빈칸 and n < 40:
		n += 1
		yy -= 1
	return n


# ============================================================================
# ★★통행 잇기 — 파낸 공간을 **걸어 다닐 수 있게** 만드는 마지막 단계
# ----------------------------------------------------------------------------
# ▣ 왜 이것이 필요한가 (2026-09-21 · 반나절을 여기서 썼다)
#   "공간이 이어져 있다" 와 "플레이어가 갈 수 있다" 는 **완전히 다른 문제**다.
#   곧은 굴뚝은 공간을 잇지만 못 올라간다. 방 바닥이 통로보다 2 칸 낮으면 들어갈 수만 있다.
#   실측: 파기만 했을 때 설 수 있는 칸 637 개 중 시작에서 닿는 것은 **36 개(6 %)** 였다.
#
# ▣ 왜 "발판을 놓아" 고치지 않고 "터널을 파서" 고치나
#   발판 놓기는 **빈 공간이 있어야** 한다. 막힌 바위 너머 구역은 영영 못 잇는다(실측: 절반만 이어졌다).
#   파기는 **언제나 성공한다.** 그래서 이 방식은 반드시 끝난다.
#   판 자리는 계단(한 칸씩)이라 위아래 양방향으로 걸어 다닐 수 있다.
#
# ▣ 순서가 중요하다
#   울퉁불퉁·선반·돌기(생김새 단계) **뒤에** 부른다. 먼저 부르면 그 단계들이 계단을 다시 메운다.
# ============================================================================
static func _통행_잇기(칸: PackedByteArray, W: int, H: int, 보호: PackedByteArray,
		시작: Vector2i, 굵기: int, 최대횟수: int = 200) -> Dictionary:
	var 보고 := {"터널": 0, "남은구역": 0}
	for _t in 최대횟수:
		var 설칸 := _설칸_모음(칸, W, H)
		var 닿음 := _닿는칸(칸, W, H, 설칸, 시작)
		var 못닿음: Array = []
		for k in 설칸:
			if not 닿음.has(k):
				못닿음.append(k)
		if 못닿음.is_empty() or 닿음.is_empty():
			보고["남은구역"] = 못닿음.size()
			return 보고
		# 못 닿는 칸 중 **닿는 칸과 가장 가까운 것**을 고른다 → 가장 짧은 터널
		var 목표 := -1
		var 출발 := -1
		var 최소 := 1e20
		for k in 못닿음:
			var q := Vector2i(int(k % 10000), int(k / 10000))
			for rk in 닿음:
				var r := Vector2i(int(rk % 10000), int(rk / 10000))
				var d := Vector2(r - q).length()
				if d < 최소:
					최소 = d
					목표 = k
					출발 = rk
		if 목표 < 0:
			break
		_계단_터널(칸, W, H, 보호,
			Vector2i(int(출발 % 10000), int(출발 / 10000)),
			Vector2i(int(목표 % 10000), int(목표 / 10000)), 굵기)
		보고["터널"] += 1
	# 최대 횟수를 다 썼다 — 남은 구역 수를 정직하게 다시 세어 보고한다
	var 설칸2 := _설칸_모음(칸, W, H)
	var 닿음2 := _닿는칸(칸, W, H, 설칸2, 시작)
	보고["남은구역"] = 설칸2.size() - 닿음2.size()
	return 보고


## 두 칸 사이를 **한 칸씩 오르내리는 계단 터널**로 판다. 머리 높이(굵기)만큼 같이 판다.
static func _계단_터널(칸: PackedByteArray, W: int, H: int, 보호: PackedByteArray,
		a: Vector2i, b: Vector2i, 굵기: int) -> void:
	var 현재 := a
	var 안전 := 0
	while 현재 != b and 안전 < 400:
		안전 += 1
		var dy := signi(b.y - 현재.y)
		var dx := signi(b.x - 현재.x)
		if dy != 0:
			현재.y += dy
			_파기_기둥(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
			# 한 칸 오르내렸으면 옆으로 2 칸 — 이래야 **되돌아 내려올 때도** 걸어서 간다
			for _k in 2:
				var nx := 현재.x + (dx if dx != 0 else 1)
				if nx < 1 or nx >= W - 1:
					break
				현재.x = nx
				_파기_기둥(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
		elif dx != 0:
			현재.x += dx
			_파기_기둥(칸, 보호, W, H, 현재.x, 현재.y, 굵기)
		else:
			break


static func _파기_기둥(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		x: int, y: int, 굵기: int) -> void:
	for d in range(0, 굵기):
		_칸_비우기(칸, W, H, x, y - d)
	_보호_표시(보호, W, H, x, y)
	_보호_표시(보호, W, H, x, y - 1)


## 설 수 있는 칸(빈칸 + 아래가 바위 + 머리 위 한 칸 비어 있음). 키 = y*10000+x
static func _설칸_모음(칸: PackedByteArray, W: int, H: int) -> Dictionary:
	var out := {}
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _칸_읽기(칸, W, H, x, y) != 빈칸:
				continue
			if _칸_읽기(칸, W, H, x, y + 1) != 암반:
				continue
			if _칸_읽기(칸, W, H, x, y - 1) != 빈칸:
				continue      # 머리가 안 들어가는 자리는 설 수 있어도 못 지나간다
			out[y * 10000 + x] = true
	return out


## 시작에서 점프 규칙(위 1 칸 · 옆 2 칸 · 낙하 자유)으로 닿는 칸
static func _닿는칸(칸: PackedByteArray, W: int, H: int, 설칸: Dictionary, 시작: Vector2i) -> Dictionary:
	var s := Vector2i(시작)
	var 안전 := 0
	while not 설칸.has(s.y * 10000 + s.x) and 안전 < 60:
		s.y += 1
		안전 += 1
	var 닿음 := {}
	if not 설칸.has(s.y * 10000 + s.x):
		return 닿음
	닿음[s.y * 10000 + s.x] = true
	var 줄: Array = [s]
	while not 줄.is_empty():
		var p: Vector2i = 줄.pop_back()
		for dx in range(-2, 3):
			for dy in range(-1, 16):
				var q := Vector2i(p.x + dx, p.y + dy)
				var k := q.y * 10000 + q.x
				if not 설칸.has(k) or 닿음.has(k):
					continue
				닿음[k] = true
				줄.append(q)
	return 닿음
