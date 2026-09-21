extends RefCounted
## ============================================================================
## [2026-09-21 신규] 배치 — 파낸 동굴 **안에** 발판·기믹·위험물을 넣는다
## ----------------------------------------------------------------------------
## ▣ 여기서 만드는 것과 껍데기의 차이
##   껍데기(`윤곽.gd`)는 **바위**다 — 칠할 수 없고, 구조이고, 하나로 이어져 있다.
##   여기서 만드는 것은 **플레이어가 만지는 것**이다 — 칠할 수 있고, 조각이고, 색 규칙에 참여한다.
##   두 가지를 섞으면 안 된다. 껍데기를 칠할 수 있게 하면 긴변이 1 만 px 이라
##   `지형.gd 전체_색칠_최대긴변(576)` 에 걸려 "아무리 쏴도 안 굳는 벽" 이 된다.
##
## ▣ 반드시 해야 하는 일 — **세로 갱도에 사다리를 놓는 것**
##   동굴을 파면 세로 통로가 생기는데, 파기만 해서는 **올라갈 수가 없다.**
##   플레이어는 한 번에 160 px(설계값 112)밖에 못 오른다. 갱도가 5 칸(480)이면 못 올라간다.
##   → 세로 통로마다 좌우 엇갈린 발판을 112 px 간격으로 놓는다. 이게 없으면 맵의 절반이 죽는다.
##
## ▣ 색 구간은 **방 단위**로 준다
##   v1 은 진행 거리로 색을 바꿨는데, v2 는 길이 갈라지므로 "거리" 가 의미가 없다.
##   방마다 색을 정하고, 그 방 안의 발판은 그 색으로 둔다. 플레이어는 방을 넘을 때
##   색을 바꾸게 되고, 그게 이 게임의 리듬이 된다.
## ============================================================================

const 규격 := preload("res://tools/생성기/규격.gd")
const 동굴_S := preload("res://tools/생성기/동굴.gd")


## 동굴에 배치물을 채운다.
##   돌려주는 것 = {플랫폼: [...], 위험물: [...], 체크포인트: [Vector2], 사격: [...]}
static func 채우기(동굴: Dictionary, 설정: RefCounted, rng: RandomNumberGenerator) -> Dictionary:
	var 결과 := {"플랫폼": [], "위험물": [], "체크포인트": [], "사격": []}

	# 0) 방마다 색을 정한다. 시작 방은 반드시 검정 — "안 칠한 지형은 검정" 이라
	#    흰색으로 시작하면 첫 바닥에서 바로 죽는다(색규칙.gd).
	var 방색 := {}
	for i in (동굴["방들"] as Array).size():
		var 방: Dictionary = 동굴["방들"][i]
		방색[방["이름"]] = 규격.검정 if i == 0 else (규격.흰색 if rng.randf() < 0.42 else 규격.검정)

	# ★★[2026-09-21] 발판은 **플레이어가 닿는 자리 근처에만** 놓는다.
	#   그 전에는 방 안 아무 데나 놓았는데, 실측해 보니 그렇게 만든 발판 500 개 이상이
	#   어디서도 닿지 않는 공중 섬이었다(동굴 자체는 80 % 이어져 있는데 전체 도달률은 22 %).
	#   보기에도 "작은 발판이 잔뜩 떠 있는" 화면이 된다(도형님 스크린샷).
	#   → 먼저 **동굴만의 도달 가능 칸**을 구하고, 그 근처에만 놓는다.
	var 동굴_설칸 := _설_수_있는_칸들(동굴, {"플랫폼": []})
	var 동굴_닿음 := _격자_BFS(동굴, 동굴_설칸, 동굴["시작칸"])

	_사다리(동굴, 설정, rng, 결과, 방색, 동굴_닿음)
	_방_발판(동굴, 설정, rng, 결과, 방색, 동굴_닿음)
	_위험물(동굴, 설정, rng, 결과)
	_체크포인트(동굴, rng, 결과)
	return 결과


## 이 발판에 **올라설 수 있나** — 닿는 칸에서 점프 한 번에 닿는 자리인가.
## 세로 −1(한 칸 위) ~ +3(아래로 세 칸) · 가로 2 칸까지 본다.
static func _닿는곳_근처인가(동굴: Dictionary, 닿음: Dictionary, 자리: Rect2) -> bool:
	var a: Vector2i = 동굴_S.월드_칸(동굴, 자리.position)
	var b: Vector2i = 동굴_S.월드_칸(동굴, Vector2(자리.end.x, 자리.position.y))
	for x in range(a.x - 2, b.x + 3):
		for dy in range(-1, 4):
			if 닿음.has((a.y + dy) * 10000 + x):
				return true
	return false


# ============================================================================
# 세로 갱도 사다리 — **맵을 살리는 필수 배치**
# ============================================================================
static func _사다리(동굴: Dictionary, 설정: RefCounted, rng: RandomNumberGenerator,
		결과: Dictionary, 방색: Dictionary, 닿음: Dictionary) -> void:
	var 칸크기: float = float(동굴["칸크기"])
	var 번호 := 0
	var 놓인_기둥: Array[int] = []          # 이미 사다리를 놓은 갱도의 x (중복 방지)
	for t in 동굴["통로들"]:
		if not bool(t["세로"]):
			continue
		var 꺾임: Vector2i = t["꺾임"]
		# ★같은 갱도에 여러 통로가 겹치면 사다리가 두 벌 놓여 갱도가 발판으로 꽉 찬다
		#   (처음에 295 개가 나왔던 이유). 2 칸 안에 이미 놓았으면 건너뛴다.
		var 겹침 := false
		for px in 놓인_기둥:
			if absi(px - 꺾임.x) <= 2:
				겹침 = true
				break
		if 겹침:
			continue
		# 갱도의 위·아래 끝을 찾는다(빈칸이 이어지는 범위).
		# ⚠ 끝없이 훑으면 방 전체를 타고 올라가 사다리가 10 단 넘게 생긴다 → 8 칸으로 자른다.
		var 위 := 꺾임.y
		while 동굴_S.읽기(동굴, 꺾임.x, 위 - 1) == 동굴_S.빈칸 and 꺾임.y - 위 < 8:
			위 -= 1
		var 아래 := 꺾임.y
		while 동굴_S.읽기(동굴, 꺾임.x, 아래 + 1) == 동굴_S.빈칸 and 아래 - 꺾임.y < 8:
			아래 += 1
		if 아래 - 위 < 3:
			continue                       # 짧은 갱도는 그냥 뛰어오를 수 있다
		놓인_기둥.append(꺾임.x)

		# 아래에서 위로, 112 px(= 설계 최대 상승)마다 좌우 엇갈리게 놓는다.
		# ⚠ 엇갈리는 이유: 일직선으로 쌓으면 두 칸 위 발판 밑면에 머리(97)가 박힌다.
		var 단수 := int(float(아래 - 위) * 칸크기 / 규격.설계_최대상승)
		var 왼 := true
		for k in range(1, 단수):
			번호 += 1
			# ★칸 좌표를 월드로 바꿀 때 **반드시 `칸_월드()` 를 쓴다.**
			#   처음에 `칸 × 칸크기` 로만 계산했다가 동굴 원점(y −2688)을 빠뜨려
			#   발판이 전부 맵 밖에 놓였고, "자리 비었나" 검사가 전부 실패해 **발판 0 개**가 나왔다.
			var 바닥 := 동굴_S.칸_월드(동굴, 꺾임.x, 아래)
			var y := 바닥.y - float(k) * 규격.설계_최대상승
			var x0 := 바닥.x + (0.0 if 왼 else 칸크기 * 1.2)
			왼 = not 왼
			var 폭 := 칸크기 * 3.0      # 사다리 발판도 288 px 로 — 작으면 그림이 뭉개진다
			var 자리 := Rect2(규격.격자맞춤(x0), 규격.격자맞춤(y), 규격.격자맞춤(폭), 규격.발판_두께)
			if not _자리_비었나(동굴, 자리):
				continue
			if not _닿는곳_근처인가(동굴, 닿음, 자리):
				continue
			결과["플랫폼"].append(_발판("사다리%02d" % 번호, 자리,
				_색_at(동굴, 방색, 자리.get_center()), true))
	return


# ============================================================================
# 방 안 공중 발판 — 탐험의 재미를 만드는 것
# ============================================================================
static func _방_발판(동굴: Dictionary, 설정: RefCounted, rng: RandomNumberGenerator,
		결과: Dictionary, 방색: Dictionary, 닿음: Dictionary) -> void:
	var 칸크기: float = float(동굴["칸크기"])
	var 번호 := 0
	var 유령번호 := 0
	for 방 in 동굴["방들"]:
		var r: Rect2i = 방["사각"]
		if r.size.y < 4:
			continue                        # 낮은 방은 그냥 걸어 지나가게 둔다
		# 큰 방일수록 발판을 조금 더. 방마다 3 개씩 주면 295 개가 되어 씬이 무거워진다.
		var 개수 := 1 if r.size.x < 8 else rng.randi_range(1, 2)
		for i in 개수:
			var cx := rng.randi_range(r.position.x + 1, r.end.x - 3)
			var cy := rng.randi_range(r.position.y + 1, r.end.y - 2)
			# ★발판을 크게 — 2~4 칸(192~384)은 SS2D 나무 텍스처가 깨진다(도형님 스크린샷).
			#   3~6 칸 = 288~576 px. 576 은 전체칠 한계라 그 위로는 못 간다.
			var 폭칸 := rng.randi_range(3, 6)
			# ★여기도 `칸_월드()` — 원점을 빠뜨리면 발판이 맵 밖에 놓인다(위 사다리 주석 참고).
			var 좌상 := 동굴_S.칸_월드(동굴, cx, cy)
			var 자리 := Rect2(좌상.x, 좌상.y, float(폭칸) * 칸크기, 규격.발판_두께)
			if not _자리_비었나(동굴, 자리):
				continue
			# ★닿지 않는 자리에는 아예 놓지 않는다(위 주석 참고)
			if not _닿는곳_근처인가(동굴, 닿음, 자리):
				continue
			var 색 := _색_at(동굴, 방색, 자리.get_center())

			# 25 % 는 **유령 발판**(칠해야 생긴다). 단 "쏠 수 있는 자리" 가 있어야 성립한다.
			var 유령 := rng.randf() < 0.25
			if 유령:
				var 쏘는자리 := _쏠_수_있는_자리(동굴, 자리)
				if 쏘는자리 == Vector2.INF:
					유령 = false             # 못 쏘면 그냥 단단한 발판으로 둔다
				else:
					유령번호 += 1
					결과["사격"].append({
						"자리": 쏘는자리, "목표": 자리,
						"대상": "유령%02d" % 유령번호,
					})
			번호 += 1
			var 이름 := ("유령%02d" % 유령번호) if 유령 else ("발판%02d" % 번호)
			var p := _발판(이름, 자리, 색, true)
			if 유령:
				p["종류"] = "유령"
			결과["플랫폼"].append(p)


# ============================================================================
# 위험물 · 체크포인트
# ============================================================================
static func _위험물(동굴: Dictionary, 설정: RefCounted, rng: RandomNumberGenerator, 결과: Dictionary) -> void:
	if 설정.위험물.is_empty():
		return
	var 칸크기: float = float(동굴["칸크기"])
	var 종류들: Array = 설정.위험물.keys()
	var 놓음 := 0
	var 시도 := 0
	while 놓음 < int(설정.위험물_개수) and 시도 < 2000:
		시도 += 1
		var x := rng.randi_range(2, int(동굴["폭칸"]) - 3)
		var y := rng.randi_range(2, int(동굴["높이칸"]) - 3)
		# 설 수 있는 바닥 위에만 놓는다. 좌우로 한 칸씩 비어 있어야 **넘어갈 수** 있다.
		if not 동굴_S.설_수_있나(동굴, x, y):
			continue
		if not (동굴_S.설_수_있나(동굴, x - 1, y) and 동굴_S.설_수_있나(동굴, x + 1, y)):
			continue
		if 동굴_S.머리여유(동굴, x, y) < 3:
			continue
		var 종류: String = 종류들[rng.randi() % 종류들.size()]
		결과["위험물"].append({
			"종류": 종류, "씬": 설정.위험물[종류]["씬"],
			"위치": 동굴_S.칸_월드(동굴, x, y) + Vector2(칸크기 * 0.5, 칸크기),
		})
		놓음 += 1


## 체크포인트 — v1 에는 아예 없었다(떨어지면 처음부터). 방 몇 개에 하나씩 둔다.
static func _체크포인트(동굴: Dictionary, rng: RandomNumberGenerator, 결과: Dictionary) -> void:
	var 칸크기: float = float(동굴["칸크기"])
	var 방들: Array = 동굴["방들"]
	for i in 방들.size():
		if i % 5 != 2:
			continue
		var r: Rect2i = 방들[i]["사각"]
		var x := r.position.x + r.size.x / 2
		var y := r.end.y - 1
		# 바닥을 찾아 그 위에 놓는다
		while y > r.position.y and 동굴_S.읽기(동굴, x, y) != 동굴_S.빈칸:
			y -= 1
		if 동굴_S.설_수_있나(동굴, x, y):
			결과["체크포인트"].append(동굴_S.칸_월드(동굴, x, y) + Vector2(칸크기 * 0.5, 칸크기))


# ============================================================================
# 도우미
# ============================================================================
static func _발판(이름: String, 자리: Rect2, 색: int, 일방통행: bool) -> Dictionary:
	return {
		"이름": 이름, "사각": 자리, "종류": "발판", "색": 색,
		"칠방식": 0,                  # 전체칠 가능 (폭이 576 이하라 규칙에 안 걸린다)
		"일방통행": 일방통행,
		"의도형태": "직사각형",        # 조립기 자기검증이 이걸 보고 "무너졌나" 를 판단한다
	}


## 그 사각형 자리가 **전부 빈칸**인가. 바위에 겹쳐 발판을 놓으면 그림이 겹쳐 지저분해진다.
static func _자리_비었나(동굴: Dictionary, 자리: Rect2) -> bool:
	var a: Vector2i = 동굴_S.월드_칸(동굴, 자리.position - Vector2(0, 8))
	var b: Vector2i = 동굴_S.월드_칸(동굴, 자리.end + Vector2(0, 8))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if 동굴_S.읽기(동굴, x, y) != 동굴_S.빈칸:
				return false
	return true


## 그 자리가 어느 방인가 → 그 방의 색. 방 밖(통로)이면 검정.
static func _색_at(동굴: Dictionary, 방색: Dictionary, p: Vector2) -> int:
	var c: Vector2i = 동굴_S.월드_칸(동굴, p)
	for 방 in 동굴["방들"]:
		var r: Rect2i = 방["사각"]
		# ⚠ 방색 표가 비어 있을 수 있다(통행 보정은 색 표 없이 부른다) → 없으면 검정.
		if r.has_point(c) and 방색.has(방["이름"]):
			return int(방색[방["이름"]])
	return 규격.검정


## 이 발판을 **쏠 수 있는 자리**가 있나. 없으면 Vector2.INF.
## ⚠ 총알은 직선이 아니라 포물선이다(탄속 1150 · 중력 900). 그리고 바위가 막는다.
##   그래서 격자를 직접 훑으며 궤적을 시뮬레이션한다.
static func _쏠_수_있는_자리(동굴: Dictionary, 목표: Rect2) -> Vector2:
	var 칸크기: float = float(동굴["칸크기"])
	var c: Vector2i = 동굴_S.월드_칸(동굴, 목표.get_center())
	# 목표 주변에서 설 수 있는 자리를 찾아 하나씩 쏴 본다(가까운 곳부터).
	# ⚠ `for 반경 in [2,3,4,5]` 는 원소 타입이 Variant 이라 아래에서 타입 추론이 깨진다.
	#   범위를 명시적 int 로 돈다.
	for 반경 in range(2, 6):
		for dy in range(-반경, 반경 + 1):
			for dx in [-반경, 반경]:
				var x: int = c.x + int(dx)
				var y: int = c.y + dy
				if not 동굴_S.설_수_있나(동굴, x, y):
					continue
				var 눈 := 동굴_S.칸_월드(동굴, x, y) + Vector2(칸크기 * 0.5, 칸크기 - 규격.몸_높이 * 0.5)
				if _맞나(동굴, 눈, 목표):
					return 눈
	return Vector2.INF


static func _맞나(동굴: Dictionary, 눈: Vector2, 목표: Rect2) -> bool:
	var 오른쪽 := 목표.get_center().x >= 눈.x
	for 각 in range(-60, 61, 6):
		var 속도 := Vector2.RIGHT.rotated(deg_to_rad(float(각))) * 규격.탄속
		if not 오른쪽:
			속도.x = -속도.x
		var p := 눈
		var dt := 규격.물리_틱 * 0.5
		for _i in int(1.2 / dt):           # 1.2 초면 충분하다(그 안에 못 맞으면 너무 멀다)
			속도.y += 규격.탄_중력 * dt
			p += 속도 * dt
			if 목표.has_point(p):
				return true
			var c: Vector2i = 동굴_S.월드_칸(동굴, p)
			if 동굴_S.읽기(동굴, c.x, c.y) == 동굴_S.암반:
				break                      # 바위에 막혔다
	return false


# ============================================================================
# ★통행 보정 — **이 단계가 없으면 맵이 안 돌아간다**
# ----------------------------------------------------------------------------
# ▣ 왜 필요한가 (2026-09-21 실측)
#   동굴을 파고 발판을 놓은 뒤 `레벨검사` 를 돌렸더니 **도달 0 / 87** 이 나왔다.
#   원인은 단순하다 — 돌기·울퉁불퉁이 만든 **2 칸(192 px) 단차**다.
#   플레이어가 오를 수 있는 높이는 128 px(점프 160 × 여유 0.8)이라 192 는 절대 못 넘는다.
#   즉 "파면 길이 생긴다" 는 틀렸다. 파낸 공간이 **걸어 다닐 수 있는지**는 따로 봐야 한다.
#
# ▣ 어떻게 고치나
#   1. 격자에서 **설 수 있는 칸**(빈칸 + 아래가 바위/발판)을 모은다
#   2. 시작 칸에서 점프 규칙으로 BFS → 닿는 칸 / 못 닿는 칸이 갈린다
#   3. 못 닿는 덩어리마다, 가장 가까운 닿는 칸에서 **디딤 발판**을 놓아 잇는다
#   4. 1~3 을 몇 번 되풀이한다(새 발판이 또 다른 구역을 열어 준다)
#   바위를 깎지 않고 발판으로 잇는 이유: 깎으면 방과 방을 가르던 벽이 사라져
#   설계(방·고리)가 뭉개진다. 발판은 **플레이어가 칠할 수 있는 것**이라 퍼즐도 된다.
# ============================================================================
const 오름칸: int = 1          ## 한 번에 오를 수 있는 칸 수 (112 px 설계값 ÷ 96 = 1)
## ★한 번에 건널 수 있는 **칸 인덱스 차이**.
##   ⚠ 이 값은 "구덩이 칸 수" 가 아니라 "출발 칸과 착지 칸의 인덱스 차" 다.
##   2 칸짜리 구덩이(192 px)를 건너면 인덱스는 **3** 칸 움직인다(x−1 → x+2).
##   처음에 2 로 두었더니 2 칸 구덩이를 "못 건넌다" 고 판정해서, 도약 관문을 세우는 순간
##   그 너머가 통째로 도달 불가가 됐다(시작 덩어리 671 → 75).
##   실제 판정선은 가장자리 사이 272 px = 2.83 칸이므로 2 칸 구덩이까지가 한계다.
const 건넘칸: int = 3


## ⚠[2026-09-21 수정] 이제 **대부분의 연결은 `동굴.gd _통행_잇기()` 가 터널을 파서 해결**한다.
##   여기 남은 역할은 그 뒤에 남는 자잘한 자리(발판 위·1 칸 턱)뿐이다.
##   그래서 되풀이를 1 회로 줄이고 디딤 발판 수에 상한을 뒀다 — 안 그러면 141 개를 놓는다(실측).
static func 통행_보정(동굴: Dictionary, 배치: Dictionary, rng: RandomNumberGenerator,
		되풀이: int = 1) -> Dictionary:
	var 보고 := {"추가발판": 0, "못닿는칸": 0, "닿는칸": 0}
	var 마지막_닿음 := {}
	for _t in 되풀이:
		var 설칸 := _설_수_있는_칸들(동굴, 배치)
		var 닿음 := _격자_BFS(동굴, 설칸, 동굴["시작칸"])
		마지막_닿음 = 닿음
		var 못닿음: Array = []
		for k in 설칸:
			if not 닿음.has(k):
				못닿음.append(k)
		보고["닿는칸"] = 닿음.size()
		보고["못닿는칸"] = 못닿음.size()
		if 못닿음.is_empty():
			break
		var 추가 := _디딤_놓기(동굴, 배치, 닿음, 못닿음, rng)
		보고["추가발판"] += 추가
		if 추가 == 0:
			break            # 더 이상 이을 수 없다 — 남은 구역은 보고만 한다
	# ★★보고는 **전부 끝난 뒤에 다시 잰다.**
	#   처음에는 되풀이 안에서 잰 값을 그대로 보고했는데, 그건 **디딤 발판을 놓기 전** 값이라
	#   실제보다 훨씬 나쁘게 나왔다(실측 44 인데 그림에는 60 개 넘게 닿아 있었다).
	#   잘못된 숫자를 보고 알고리즘을 고치면 엉뚱한 곳을 고치게 된다.
	var 최종_설칸 := _설_수_있는_칸들(동굴, 배치)
	var 최종_닿음 := _격자_BFS(동굴, 최종_설칸, 동굴["시작칸"])
	보고["닿는칸"] = 최종_닿음.size()
	보고["못닿는칸"] = 최종_설칸.size() - 최종_닿음.size()
	보고["닿음"] = 최종_닿음
	보고["설칸"] = 최종_설칸
	return 보고


## 설 수 있는 칸 = 빈칸인데 **바로 아래가 바위이거나 발판**인 칸. 키는 y*10000+x.
static func _설_수_있는_칸들(동굴: Dictionary, 배치: Dictionary) -> Dictionary:
	var W: int = int(동굴["폭칸"])
	var H: int = int(동굴["높이칸"])
	var 발판칸 := {}
	for p in 배치["플랫폼"]:
		var r: Rect2 = p["사각"]
		var a: Vector2i = 동굴_S.월드_칸(동굴, r.position + Vector2(2, 2))
		var b: Vector2i = 동굴_S.월드_칸(동굴, Vector2(r.end.x - 2, r.position.y + 2))
		for x in range(a.x, b.x + 1):
			발판칸[a.y * 10000 + x] = true        # 그 칸 자체가 "발판 윗면" 이다
	var out := {}
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if 동굴_S.읽기(동굴, x, y) != 동굴_S.빈칸:
				continue
			# ★머리 위 한 칸이 비어 있어야 **설 수 있는 자리**로 친다.
			#   이 조건을 빼면 기어들어갈 수도 없는 1 칸 구멍까지 세어서
			#   "못 닿는 칸 300" 같은 허수가 나온다 — `동굴.gd _설칸_모음()` 과 **같은 정의**를 쓴다.
			#   (두 검사기가 다른 잣대를 쓰면 숫자를 믿을 수 없다 — v1 에서 이미 한 번 크게 당했다)
			if 동굴_S.읽기(동굴, x, y - 1) != 동굴_S.빈칸:
				continue
			var 아래바위 := 동굴_S.읽기(동굴, x, y + 1) == 동굴_S.암반
			var 아래발판: bool = 발판칸.has((y + 1) * 10000 + x) or 발판칸.has(y * 10000 + x)
			if 아래바위 or 아래발판:
				out[y * 10000 + x] = true
	return out


## 점프 규칙으로 격자 BFS. `레벨검사` 와 같은 잣대를 **칸 단위**로 옮긴 것이다.
static func _격자_BFS(동굴: Dictionary, 설칸: Dictionary, 시작: Vector2i) -> Dictionary:
	# 시작 칸이 설 수 있는 칸이 아니면 바로 아래로 내려 잡는다(스폰 직후 낙하)
	var s := Vector2i(시작)
	var 안전 := 0
	while not 설칸.has(s.y * 10000 + s.x) and 안전 < 40:
		s.y += 1
		안전 += 1
	var 닿음 := {}
	if not 설칸.has(s.y * 10000 + s.x):
		return 닿음
	닿음[s.y * 10000 + s.x] = true
	var 줄: Array = [s]
	while not 줄.is_empty():
		var p: Vector2i = 줄.pop_back()
		for dx in range(-건넘칸, 건넘칸 + 1):
			for dy in range(-오름칸, 16):        # 위로는 1 칸, 아래로는 낙하로 16 칸까지
				if dx == 0 and dy == 0:
					continue
				var q := Vector2i(p.x + dx, p.y + dy)
				var k := q.y * 10000 + q.x
				if not 설칸.has(k) or 닿음.has(k):
					continue
				# 머리 높이(2 칸)가 비어 있어야 실제로 지나간다
				if 동굴_S.읽기(동굴, q.x, q.y - 1) == 동굴_S.암반:
					continue
				닿음[k] = true
				줄.append(q)
	return 닿음


## 못 닿는 덩어리를 가장 가까운 닿는 칸과 **디딤 발판**으로 잇는다. 놓은 개수를 돌려준다.
static func _디딤_놓기(동굴: Dictionary, 배치: Dictionary, 닿음: Dictionary,
		못닿음: Array, rng: RandomNumberGenerator) -> int:
	var 칸크기: float = float(동굴["칸크기"])
	var 놓음 := 0
	var 처리 := {}
	var 상한 := 16          ## 디딤 발판 상한 — 터널이 이미 이어 놨으므로 많이 놓을 이유가 없다
	for k in 못닿음:
		if 처리.size() > 40 or 놓음 >= 상한:
			break
		var q := Vector2i(int(k % 10000), int(k / 10000))
		# 이미 이 근처를 이었으면 건너뛴다(한 구역에 디딤을 잔뜩 놓지 않게)
		var 가까움 := false
		for pk in 처리:
			var p := Vector2i(int(pk % 10000), int(pk / 10000))
			if absi(p.x - q.x) <= 4 and absi(p.y - q.y) <= 4:
				가까움 = true
				break
		if 가까움:
			continue
		# 가장 가까운 "닿는 칸" 을 찾는다(너무 멀면 포기 — 억지로 이으면 맵이 지저분해진다)
		var 최고 := Vector2i.ZERO
		var 최소 := 1e20
		for rk in 닿음:
			var r := Vector2i(int(rk % 10000), int(rk / 10000))
			var d := Vector2(r - q).length()
			if d < 최소:
				최소 = d
				최고 = r
		if 최소 > 12.0:
			continue
		# 두 칸 사이에 1 칸 간격 계단을 놓는다
		var 단수 := int(maxf(absf(float(q.y - 최고.y)), 1.0))
		for i in range(1, 단수 + 1):
			var t := float(i) / float(단수 + 1)
			var cx := int(round(lerpf(float(최고.x), float(q.x), t)))
			var cy := int(round(lerpf(float(최고.y), float(q.y), t)))
			var 좌상 := 동굴_S.칸_월드(동굴, cx, cy)
			var 자리 := Rect2(좌상.x, 좌상.y, 칸크기 * 2.0, 규격.발판_두께)
			if not _자리_비었나(동굴, 자리):
				continue
			놓음 += 1
			배치["플랫폼"].append(_발판("디딤%02d" % 놓음, 자리,
				_색_at(동굴, {}, 자리.get_center()), true))
		처리[k] = true
	return 놓음


## 진단: 설 수 있는 칸을 **연결 덩어리**로 나눠 크기를 본다.
## ▣ 왜 필요한가 — "못 닿는 칸이 479 개" 만으로는 원인을 못 가른다.
##   · 제일 큰 덩어리가 600 인데 시작이 20 짜리 덩어리에 있다 → **시작 위치**가 문제
##   · 덩어리가 50 개로 잘게 쪼개져 있다 → **지형 연결**이 문제
##   이 둘은 고치는 곳이 완전히 다르다.
static func 연결_진단(동굴: Dictionary, 배치: Dictionary) -> Dictionary:
	var 설칸 := _설_수_있는_칸들(동굴, 배치)
	var 본것 := {}
	var 덩어리들: Array = []
	for k in 설칸:
		if 본것.has(k):
			continue
		var 크기 := 0
		var 칸들: Array = []
		var 줄: Array = [k]
		본것[k] = true
		while not 줄.is_empty():
			var cur = 줄.pop_back()
			크기 += 1
			칸들.append(cur)
			var p := Vector2i(int(cur % 10000), int(cur / 10000))
			for dx in range(-건넘칸, 건넘칸 + 1):
				for dy in range(-오름칸, 16):
					var q := Vector2i(p.x + dx, p.y + dy)
					var nk := q.y * 10000 + q.x
					if not 설칸.has(nk) or 본것.has(nk):
						continue
					if 동굴_S.읽기(동굴, q.x, q.y - 1) == 동굴_S.암반:
						continue
					본것[nk] = true
					줄.append(nk)
		덩어리들.append({"크기": 크기, "칸들": 칸들})
	덩어리들.sort_custom(func(a, b): return int(a["크기"]) > int(b["크기"]))
	# 시작이 어느 덩어리에 있나
	var s := Vector2i(동굴["시작칸"])
	var 안전 := 0
	while not 설칸.has(s.y * 10000 + s.x) and 안전 < 40:
		s.y += 1
		안전 += 1
	var 시작덩어리 := -1
	for i in 덩어리들.size():
		if (덩어리들[i]["칸들"] as Array).has(s.y * 10000 + s.x):
			시작덩어리 = i
			break
	return {
		"덩어리수": 덩어리들.size(),
		"최대크기": 0 if 덩어리들.is_empty() else int(덩어리들[0]["크기"]),
		"시작덩어리_순위": 시작덩어리,
		"시작덩어리_크기": 0 if 시작덩어리 < 0 else int(덩어리들[시작덩어리]["크기"]),
		"설칸수": 설칸.size(),
	}


## 진단: 시작 주변을 ASCII 로 찍는다. '#'=바위 '.'=빈칸 'o'=닿는 발판자리 'x'=못 닿는 발판자리 'S'=시작
## ▣ 왜 — 숫자와 그림으로도 원인이 안 보일 때, 칸 하나하나를 보면 3 초 만에 보인다.
static func 진단_그리기(동굴: Dictionary, 배치: Dictionary, 중심: Vector2i,
		폭: int = 60, 높이: int = 22) -> Array:
	var 설칸 := _설_수_있는_칸들(동굴, 배치)
	var 닿음 := _격자_BFS(동굴, 설칸, 동굴["시작칸"])
	var 줄들: Array = []
	var x0 := maxi(중심.x - 폭 / 2, 0)
	var y0 := maxi(중심.y - 높이 / 2, 0)
	for y in range(y0, mini(y0 + 높이, int(동굴["높이칸"]))):
		var s := ""
		for x in range(x0, mini(x0 + 폭, int(동굴["폭칸"]))):
			var k := y * 10000 + x
			if Vector2i(x, y) == Vector2i(동굴["시작칸"]):
				s += "S"
			elif 동굴_S.읽기(동굴, x, y) == 동굴_S.암반:
				s += "#"
			elif 설칸.has(k):
				s += "o" if 닿음.has(k) else "x"
			else:
				s += "."
		줄들.append("%3d %s" % [y, s])
	return 줄들
