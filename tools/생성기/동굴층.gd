extends RefCounted
## ============================================================================
## [2026-09-21 신규] 층 기반 동굴 파기 — **걸어 다닐 수 있게 파는** 것이 목적
## ----------------------------------------------------------------------------
## ▣ 앞선 시도가 왜 실패했나 (같은 날 두 번 실패하고 얻은 결론)
##   1차: 방을 아무 높이에 놓고 통로로 이었다 → 공간은 이어졌는데 **못 올라간다**
##        (설 수 있는 칸 637 개 중 시작에서 닿는 것 36 개 = 6 %)
##   2차: 못 닿는 곳마다 계단 터널을 파서 고쳤다 → 터널 76 개가 벽을 다 뚫어
##        **맵이 뻥 뚫린 공동 하나**가 됐다(빈 공간 39 % → 66 %)
##   결론: **통행은 고쳐서 얻는 것이 아니라, 처음부터 그렇게 파야 얻는 것**이다.
##
## ▣ 층(floor band) 구조 — 레인월드·할로우나이트 맵이 실제로 이렇게 생겼다
##   · 바닥 높이를 **몇 개의 층선**으로 고정한다(예: 5 칸 간격). 한 층은 좌우로 이어진 띠다.
##   · 한 층 안에서는 천장 높이만 출렁인다 → 넓은 방·좁은 굴이 번갈아 나와 지루하지 않다.
##   · 층과 층은 **지그재그 계단**으로만 잇는다(한 칸 오르고 옆으로 2 칸). 위아래 양방향 통행 보장.
##   · 바닥 줄은 **누구도 건드리지 않는다**(울퉁불퉁·돌기 제외 대상) → 길이 끊길 수가 없다.
##
## ▣ 장애물은 "길을 끊는 것" 이 아니라 "넘어가는 것"
##   도형님 요구("뼈대에서 튀어나와 하나의 장애물로 작용")를 지키면서 통행을 보장하려면
##   턱 높이가 **1 칸(96 px)** 이어야 한다. 플레이어가 오를 수 있는 한계가 128 px 이기 때문이다.
##   2 칸(192)은 절대 못 넘는다 — 이 숫자 하나가 1·2 차 실패의 공통 원인이었다.
## ============================================================================

const 규격 := preload("res://tools/생성기/규격.gd")

const 암반: int = 1
const 빈칸: int = 0

## ★[2026-09-21] 외곽 바위 두께(칸). `파기()` 가 설정에서 읽어 넣는다.
##   도형님 피드백: "지붕이자 위에 큰 지형이 … 위에 배경이 넘어서 보인다"
##   → 바깥 테두리를 이 두께만큼 **절대 파지 않는다.** 1 칸(96px)이면 카메라가 끝에 붙었을 때
##     지형 너머 배경이 보인다. 6 칸(576px)이면 화면 절반이 바위라 너머가 안 보인다.
static var _외곽: int = 6


static func 파기(설정: RefCounted, rng: RandomNumberGenerator) -> Dictionary:
	var W: int = int(설정.폭칸)
	var H: int = int(설정.높이칸)
	var 칸 := PackedByteArray()
	칸.resize(W * H)
	칸.fill(암반)
	# 바닥 줄 보호 마스크 — 여기 적힌 칸은 생김새 단계가 절대 안 건드린다
	var 보호 := PackedByteArray()
	보호.resize(W * H)
	보호.fill(0)
	_외곽 = maxi(int(설정.외곽두께), 1)

	# ── 1) 층선을 잡는다 ────────────────────────────────────────────────────
	var 층간격: int = int(설정.층간격칸)
	var 층들: Array[int] = []
	# ★외곽 두께 안쪽에서만 층을 잡는다. 안 그러면 제일 위/아래 층이 테두리를 먹어
	#   지붕이 얇아지고 그 너머로 배경이 보인다(도형님 피드백).
	var y := H - 1 - _외곽
	while y > _외곽 + int(설정.방_최대높이) + 1:
		층들.append(y)
		y -= 층간격
	층들.reverse()                      # 위 → 아래 순서
	if 층들.size() < 2:
		return {}

	# ── 2) 층마다 띠를 판다 ────────────────────────────────────────────────
	var 방들: Array = []
	var 번호 := 0
	for i in 층들.size():
		var 바닥y: int = 층들[i]
		# 층마다 좌우 끝을 조금씩 다르게 → 맵 실루엣이 네모가 아니게 된다
		var x0: int = _외곽 + rng.randi_range(0, 6)
		var x1: int = W - _외곽 - rng.randi_range(0, 6)
		var x: int = x0
		# ★바닥 높이를 구간마다 ±1 칸씩 흔든다 — 22,000 px 를 완전히 평평하게 두면
		#   "긴 복도" 로 보인다. 단 **이전 구간 대비 1 칸까지만** 바꾼다.
		#   2 칸(192 px)이 되는 순간 오르기 한계(128)를 넘어 그 너머가 통째로 끊긴다.
		var 이전바닥: int = 바닥y
		while x < x1:
			var 길이: int = rng.randi_range(int(설정.방_최소폭), int(설정.방_최대폭))
			길이 = mini(길이, x1 - x)
			if 길이 < 3:
				break
			# ★★바닥은 **한 띠 안에서 절대 흔들지 않는다.**
			#   ±1 칸씩 흔들어 봤더니 구간 이음매에서 서 있는 자리가 3 칸씩 벌어져
			#   (한 칸 올라가는데 가로로 3 칸 떨어짐 = 288 px > 건널 수 있는 272)
			#   띠 중간이 끊기고 그 너머 전부가 도달 불가가 됐다(실측: 1,248 칸 중 95 칸만 도달).
			#   변화는 **천장 높이 · 턱 · 발판**으로 준다 — 그쪽은 끊길 위험이 없다.
			var 이번바닥: int = 바닥y
			var 천장: int = rng.randi_range(int(설정.방_최소높이), int(설정.방_최대높이))
			번호 += 1
			방들.append({
				"이름": "방%02d" % 번호,
				"사각": Rect2i(x, 이번바닥 - 천장, 길이, 천장),
				"벨트": i, "종류": "일반", "바닥y": 이번바닥,
			})
			for xx in range(x, x + 길이):
				_기둥(칸, 보호, W, H, xx, 이번바닥 - 1, 천장)
			# 바닥 높이가 바뀌는 이음매는 **양쪽 천장을 다 파** 준다 — 안 그러면
			# 한 칸 올라선 순간 머리가 천장에 박혀 못 넘어간다.
			if 이번바닥 != 이전바닥 and x > x0:
				for d in range(0, 천장 + 2):
					_비우기(칸, W, H, x, mini(이번바닥, 이전바닥) - 1 - d)
			이전바닥 = 이번바닥
			x += 길이

			# ── 구간 사이의 **턱**(넘어가는 장애물) — 높이는 반드시 1 칸 ──
			#   도형님: "올라갈 수 있으나 올라가고 나서는 막힌 구간을 만들어야지.
			#            아예 올라가지도 못하게 하면 안돼."
			#   → 턱은 **한 칸(96 px)** 만. 오르기 한계가 128 이라 1 칸은 반드시 넘어진다.
			if x < x1 - 2 and rng.randf() < float(설정.턱_확률):
				var 턱폭: int = rng.randi_range(1, 2)
				for xx in range(x, mini(x + 턱폭, x1)):
					_기둥(칸, 보호, W, H, xx, 이번바닥 - 2, maxi(천장 - 1, 2))
					칸[(이번바닥 - 1) * W + xx] = 암반
				x += 턱폭
	if 방들.is_empty():
		return {}

	# ── 3) 층과 층을 지그재그 계단으로 잇는다 ──────────────────────────────
	var 계단들: Array = []
	for i in range(0, 층들.size() - 1):
		var 개수: int = int(설정.층연결_개수)
		for k in 개수:
			# 층 전체에 고루 퍼뜨린다(한쪽에 몰리면 반대쪽이 막다른 길이 된다)
			var 구간폭 := int(float(W - 20) / float(개수))
			var cx := 10 + 구간폭 * k + rng.randi_range(0, maxi(구간폭 - 12, 1))
			계단들.append(_계단_파기(칸, 보호, W, H, cx, 층들[i], 층들[i + 1], rng))

	# ── 4) 생김새 — 바닥 줄은 보호되므로 마음껏 흔들어도 길이 안 끊긴다 ────
	_천장_흔들기(칸, 보호, W, H, 설정, rng)
	_선반(칸, 보호, W, H, 설정, rng)
	_종유석(칸, 보호, W, H, 설정, rng)

	# ── 5) 시작·출구 ───────────────────────────────────────────────────────
	# ★시작은 **제일 아래 층의 왼쪽 끝** 방. 위층에서 시작하면 아래로 떨어지기만 하고
	#   되돌아 올라갈 수 없는 구간이 잔뜩 생긴다(실측: 시작이 20 칸짜리 외딴 덩어리에 있었다).
	var 시작방: Dictionary = 방들[0]
	for 방 in 방들:
		var 더_아래: bool = int(방["바닥y"]) > int(시작방["바닥y"])
		var 같은층_더_왼쪽: bool = int(방["바닥y"]) == int(시작방["바닥y"]) \
			and 방["사각"].position.x < 시작방["사각"].position.x
		if 더_아래 or 같은층_더_왼쪽:
			시작방 = 방
	var 시작칸 := Vector2i(시작방["사각"].position.x + 2, int(시작방["바닥y"]) - 1)
	var 출구방: Dictionary = 방들[방들.size() - 1]
	for 방 in 방들:
		# 출구는 **시작에서 제일 먼 방** — 맵을 다 훑게 만든다
		if Vector2(Vector2i(방["사각"].get_center()) - 시작칸).length() \
				> Vector2(Vector2i(출구방["사각"].get_center()) - 시작칸).length():
			출구방 = 방
	var 출구칸 := Vector2i(출구방["사각"].get_center().x, int(출구방["바닥y"]) - 1)

	return {
		"칸": 칸, "폭칸": W, "높이칸": H, "칸크기": float(설정.칸크기),
		"원점": Vector2(설정.원점_x, 설정.원점_y),
		"방들": 방들, "통로들": 계단들, "층들": 층들,
		"시작칸": 시작칸, "출구칸": 출구칸,
		"시작방": 시작방, "출구방": 출구방,
	}


## 한 칸 자리에 바닥(바닥y)과 그 위 천장 높이만큼을 판다. **바닥 줄 2 칸을 보호**한다.
static func _기둥(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		x: int, 바닥칸y: int, 높이: int) -> void:
	for d in 높이:
		_비우기(칸, W, H, x, 바닥칸y - d)
	_보호(보호, W, H, x, 바닥칸y)
	_보호(보호, W, H, x, 바닥칸y - 1)


## 위층(y_위)과 아래층(y_아래)을 잇는 지그재그 계단. 한 칸 오르고 옆으로 2 칸.
## ⚠ 양방향 통행이 되어야 한다 — 올라가는 것만 되면 되돌아올 수가 없다.
static func _계단_파기(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		cx: int, y_위: int, y_아래: int, rng: RandomNumberGenerator) -> Dictionary:
	var 단수: int = y_아래 - y_위                       # 올라가야 하는 칸 수
	if 단수 <= 0:
		return {}
	var 방향: int = 1 if rng.randf() < 0.5 else -1
	# 경사로 전체 길이(칸) = 단수 × 2. 맵 밖으로 나가면 반대 방향으로 놓는다.
	var 길이: int = 단수 * 2 + 2
	var x: int = clampi(cx, _외곽 + 1, W - _외곽 - 2)
	if 방향 > 0 and x + 길이 >= W - _외곽:
		방향 = -1
	if 방향 < 0 and x - 길이 <= _외곽:
		방향 = 1
	var 시작x := x

	# ★★계단은 **디딤마다 바닥 바위가 남아 있어야** 한다.
	#   처음에는 한 칸 올라갈 때마다 같은 자리를 3 칸씩 팠는데, 그러면 다음 단이 딛고 설
	#   바위까지 파여 **바닥 없는 대각선 굴**이 됐다(올라갈 수가 없다).
	#   → 한 단은 **가로 2 칸**을 파고, 다음 단은 **파지 않은 2 칸 옆**으로 간다.
	#     그래야 다음 단의 발밑(= 이전 단이 안 판 자리)이 바위로 남는다.
	#   한 단의 높이는 1 칸(96 px) — 오르기 한계 128 안이라 반드시 올라간다.
	var y: int = y_아래 - 1
	for s in range(0, 단수 + 1):
		for k in 2:
			var xx := x + 방향 * k
			if xx <= _외곽 or xx >= W - _외곽:
				continue
			# 서 있는 칸 y 와 그 위 2 칸(머리 여유)을 판다.
			for d in 3:
				_비우기(칸, W, H, xx, y - d)
			# ★★디딤을 **채워 넣는다** — 이것이 없으면 계단이 아니라 그냥 대각선 굴이다.
			#   계단이 지나는 구간은 아래 띠의 **방 안**이라 발밑이 이미 파여 있다
			#   (방 천장이 5~9 칸이라 그 높이까지는 전부 빈 공간이다).
			#   그래서 "안 파면 바위가 남아 있겠지" 라는 가정이 틀렸고, 실제로 계단 전체에
			#   디딤이 하나도 없어 **위층이 통째로 도달 불가**였다(실측: 아래 띠만 초록).
			#   → 한 단마다 발밑 한 줄을 바위로 **채운다.** 띠 바닥(보호 칸)은 건드리지 않는다.
			if not _보호인가(보호, W, H, xx, y + 1) \
					and xx > _외곽 and xx < W - _외곽 and y + 1 < H - _외곽:
				칸[(y + 1) * W + xx] = 암반
				# ★★채운 디딤도 **보호**해야 한다. 안 그러면 바로 뒤 `_천장_흔들기` 가
				#   "주위가 뻥 뚫린 바위" 로 보고 깎아 버린다(이웃 ≤ 2 → 빈칸).
				#   디딤을 채우기만 하고 보호를 안 했더니 결과가 1 칸도 안 달라졌다(실측).
				_보호(보호, W, H, xx, y + 1)
			_보호(보호, W, H, xx, y)
			_보호(보호, W, H, xx, y - 1)
		x += 방향 * 2
		y -= 1
		if x <= _외곽 + 1 or x >= W - _외곽 - 2:
			break
	return {"a": "층", "b": "층", "꺾임": Vector2i(시작x, (y_위 + y_아래) / 2), "세로": true}


# ============================================================================
# 생김새 — 천장만 흔든다(바닥은 보호되어 있다)
# ============================================================================
static func _천장_흔들기(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	for _t in int(설정.울퉁불퉁_횟수):
		var 원본 := 칸.duplicate()
		# 외곽 테두리는 흔들지 않는다 — 지붕이 얇아지면 배경이 비친다
		for y in range(_외곽, H - _외곽):
			for x in range(_외곽, W - _외곽):
				if _보호인가(보호, W, H, x, y):
					continue
				var i := y * W + x
				var 이웃 := _이웃수(원본, W, H, x, y)
				if 원본[i] == 빈칸 and 이웃 >= 5:
					칸[i] = 암반
				elif 원본[i] == 암반 and 이웃 <= 2:
					칸[i] = 빈칸


## 벽에서 튀어나온 선반 — **바닥에서 1 칸 위**에만. 그래야 밟고 올라갈 수 있다.
static func _선반(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	var 놓음 := 0
	var 시도 := 0
	while 놓음 < int(설정.선반_개수) and 시도 < int(설정.선반_개수) * 60:
		시도 += 1
		var x := rng.randi_range(3, W - 5)
		var y := rng.randi_range(3, H - 4)
		if _읽기(칸, W, H, x, y) != 빈칸 or _보호인가(보호, W, H, x, y):
			continue
		# 바닥에서 정확히 2 칸 위여야 한다(선반 위에 서면 바닥 기준 1 칸 = 넘어갈 수 있는 높이)
		if _읽기(칸, W, H, x, y + 1) != 빈칸 or _읽기(칸, W, H, x, y + 2) != 암반:
			continue
		if _보호인가(보호, W, H, x, y + 1):
			continue
		var 길이 := rng.randi_range(2, 4)
		var 가능 := true
		for k in 길이:
			if _읽기(칸, W, H, x + k, y) != 빈칸 or _보호인가(보호, W, H, x + k, y):
				가능 = false
				break
			for h in range(1, 3):
				if _읽기(칸, W, H, x + k, y - h) != 빈칸:
					가능 = false
					break
			if not 가능:
				break
		if not 가능:
			continue
		for k in 길이:
			칸[y * W + (x + k)] = 암반
		놓음 += 1


## 천장에서 내려오는 종유석. **바닥에는 안 세운다**(석순은 길을 막는다).
static func _종유석(칸: PackedByteArray, 보호: PackedByteArray, W: int, H: int,
		설정: RefCounted, rng: RandomNumberGenerator) -> void:
	for x in range(_외곽, W - _외곽):
		for y in range(_외곽, H - _외곽):
			if _읽기(칸, W, H, x, y) != 암반:
				continue
			if _읽기(칸, W, H, x, y + 1) != 빈칸:
				continue          # 아래가 빈칸인 바위 = 천장
			if rng.randf() > float(설정.돌기_확률):
				continue
			# 아래로 1 칸만. 그 아래에 최소 2 칸(플레이어 키)이 남아야 한다.
			if _보호인가(보호, W, H, x, y + 1) or _보호인가(보호, W, H, x, y + 2):
				continue
			if _읽기(칸, W, H, x, y + 2) != 빈칸 or _읽기(칸, W, H, x, y + 3) != 빈칸:
				continue
			칸[(y + 1) * W + x] = 암반


# ============================================================================
# 도우미
# ============================================================================
static func _비우기(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> void:
	# ★바깥 `_외곽` 칸은 **절대 파지 않는다.** 껍데기가 뚫리면 캡슐이 아니고,
	#   얇으면 지형 너머로 배경이 보인다(도형님 피드백).
	if x < _외곽 or y < _외곽 or x >= W - _외곽 or y >= H - _외곽:
		return
	칸[y * W + x] = 빈칸


static func _읽기(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return 암반
	return 칸[y * W + x]


static func _보호(보호: PackedByteArray, W: int, H: int, x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	보호[y * W + x] = 1


static func _보호인가(보호: PackedByteArray, W: int, H: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	return 보호[y * W + x] == 1


static func _이웃수(칸: PackedByteArray, W: int, H: int, x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _읽기(칸, W, H, x + dx, y + dy) == 암반:
				n += 1
	return n
