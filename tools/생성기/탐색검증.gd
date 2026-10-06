extends RefCounted
## 라벨 개수 대신 능력을 하나씩 빼고 같은 이동 그래프를 다시 탐색한다.
## 프로토타입의 보수적인 두 칸 몸통/격자 모델이며 Godot 물리 검사를 대신하지 않는다.
const 규격 = preload("res://tools/생성기/규격.gd")
var 방
var 점프: bool
var 칠하기: bool
var 색전환: bool
var 발판칸: Dictionary = {}
var 가시: Dictionary = {}
var 설캐시: Dictionary = {}
var 이웃캐시: Dictionary = {}

func _init(room, jump: bool = true, paint: bool = true, color_switch: bool = true):
	방 = room
	점프 = jump
	칠하기 = paint
	색전환 = color_switch
	for p in 방.플랫폼들:
		for x in range(p.x0, p.x1 + 1):
			발판칸[Vector2i(x, p.몸행)] = p
	for p in 방.가시칸:
		가시[p] = true

func 고체(p: Vector2i) -> bool:
	if 방.읽기(p.x, p.y) == 1:
		return true
	var f = 발판칸.get(p, {})
	return not f.is_empty() and (f.종류 != "유령" or 칠하기)

func 지지(p: Vector2i) -> bool:
	var f = 발판칸.get(p, {})
	if f.get("종류") == "색슬래브":
		return 색전환 or 칠하기
	return 고체(p)

func 설수있나(p: Vector2i) -> bool:
	if not 설캐시.has(p):
		설캐시[p] = not 고체(p) and not 가시.has(p) and not 고체(p + Vector2i.UP) and not 가시.has(p + Vector2i.UP) and 지지(p + Vector2i.DOWN)
	return 설캐시[p]

func 빈상자(a: Vector2i, b: Vector2i) -> bool:
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if 고체(Vector2i(x, y)) or 가시.has(Vector2i(x, y)):
				return false
	return true

func 이웃(p: Vector2i) -> Array:
	if 이웃캐시.has(p):
		return 이웃캐시[p]
	var out = []
	for dx in range(-3, 4):
		for dy in range(-1, 16):
			if dx == 0 and dy == 0:
				continue
			var q = p + Vector2i(dx, dy)
			if not 설수있나(q):
				continue
			var 틈: float = maxf(0, absi(dx) - 1) * 96.0
			if dy < 0:
				var t: float = -규격.점프_초속도() / 규격.중력() + sqrt(2.0 * (규격.점프_높이 - 96.0) / (규격.중력() * 규격.낙하_배수))
				if 점프 and 틈 <= 규격.설계_최대틈 and 96 <= 규격.설계_최대상승 and 틈 + 규격.몸_폭 * 0.5 <= 규격.이동속도 * t and 빈상자(Vector2i(p.x, q.y - 1), q):
					out.append([q, 5, "상승"])
			elif dy == 0:
				if (absi(dx) == 1 or (점프 and 틈 <= 규격.설계_최대틈)) and 빈상자(p + Vector2i.UP, q):
					out.append([q, 1 if absi(dx) == 1 else 4, "걷기" if absi(dx) == 1 else "점프"])
			else:
				if (absi(dx) < 2 or 점프) and dy * 96 <= 규격.치명_낙하 and 빈상자(p + Vector2i.UP, Vector2i(q.x, p.y - 1)) and 빈상자(Vector2i(q.x, p.y - 1), q):
					out.append([q, 2 + dy, "낙하"])
	이웃캐시[p] = out
	return out

func 이동비용(시작: Vector2i) -> Dictionary:
	var s = 시작
	if not 설수있나(s):
		for d in range(1, 20):
			if 설수있나(시작 + Vector2i(0, d)):
				s = 시작 + Vector2i(0, d)
				break
		if not 설수있나(s):
			return {}
	var 거리 = {s: 0}
	var 큐 = [[0, s]]
	while not 큐.is_empty():
		# 작은 방은 수백 정점이다. 비용 최소를 직접 고르면 힙 의존 없이 동일 최단거리를 얻는다.
		var best: int = 0
		for i in 큐.size():
			if 큐[i][0] < 큐[best][0]:
				best = i
		var item = 큐[best]
		큐.remove_at(best)
		if item[0] > 거리[item[1]]:
			continue
		for e in 이웃(item[1]):
			var nd: int = item[0] + e[1]
			if nd < 거리.get(e[0], 1 << 30):
				거리[e[0]] = nd
				큐.append([nd, e[0]])
	return 거리

func 복귀(도달: Dictionary, 목표: Vector2i) -> Dictionary:
	var 역 = {}
	for p in 도달:
		for e in 이웃(p):
			if 도달.has(e[0]):
				if not 역.has(e[0]):
					역[e[0]] = []
				역[e[0]].append(p)
	var 본 = {}
	if not 도달.has(목표):
		return 본
	var 큐 = [목표]
	본[목표] = true
	while not 큐.is_empty():
		for p in 역.get(큐.pop_back(), []):
			if not 본.has(p):
				본[p] = true
				큐.append(p)
	return 본

func 스폰안전(p: Vector2i) -> bool:
	if not 설수있나(p):
		return false
	for dx in range(-3, 4):
		if 발판칸.has(p + Vector2i(dx, 1)):
			return false
		if absi(dx) <= 2 and (가시.has(p + Vector2i(dx, 0)) or 가시.has(p + Vector2i(dx, 1))):
			return false
	return true

func 출구고르기() -> Dictionary:
	var 시작: Vector2i = 방.입구().칸
	var 거리 = 이동비용(시작)
	var 무점프 = get_script().new(방, false).이동비용(시작)
	var 돌아옴 = 복귀(거리, 시작)
	var 후보 = []
	var 유효 = []
	for s in 방.소켓들:
		if s.역할 == "입구":
			continue
		var c = s.duplicate(true)
		c["비용"] = 거리.get(s.칸, -1)
		c["제외"] = ""
		if not 거리.has(s.칸):
			c.제외 = "도달 불가"
		elif c.비용 < 40:
			c.제외 = "입구에서 너무 가까움"
		elif 무점프.has(s.칸):
			c.제외 = "걸어서만 도달"
		elif not 돌아옴.has(s.칸):
			c.제외 = "일방 함정"
		elif not 스폰안전(s.칸):
			c.제외 = "스폰 불안전"
		후보.append(c)
		if c.제외 == "":
			유효.append(c)
	if 유효.is_empty():
		return {"출구": {}, "후보": 후보, "실패": "쓸 수 있는 출구 후보가 없다"}
	유효.sort_custom(func(a, b): return a.비용 > b.비용)
	var 뽑이 = []
	for c in 유효:
		if c.비용 >= 유효[0].비용 * 0.55:
			뽑이.append(c)
	for c in 유효:
		if 뽑이.size() >= mini(2, 유효.size()):
			break
		if not 뽑이.has(c):
			뽑이.append(c)
	뽑이.sort_custom(func(a, b): return a.id < b.id)
	var 선택 = 뽑이[방.출구난수.정수(0, 뽑이.size() - 1)]
	for s in 방.소켓들:
		if s.id == 선택.id:
			s.역할 = "출구"
			return {"출구": s, "후보": 후보, "비용": 선택.비용}
	return {}

func _항목(보고: Dictionary, 이름: String, 통과: bool, 설명: String = ""):
	보고.항목.append({"이름": 이름, "통과": 통과, "설명": 설명})
	if not 통과:
		보고.실패.append(이름 + ": " + 설명)

func 검사(출구: Dictionary) -> Dictionary:
	var 보고 = {"항목": [], "실패": [], "엔진검사": "미실행"}
	var 시작: Vector2i = 방.입구().칸
	var 거리 = 이동비용(시작)
	var 무점프 = get_script().new(방, false).이동비용(시작)
	var 무칠 = get_script().new(방, true, false).이동비용(시작)
	var 무색 = get_script().new(방, true, true, false).이동비용(시작)
	var 무색무칠 = get_script().new(방, true, false, false).이동비용(시작)
	_항목(보고, "출구 도달", 거리.has(출구.칸))
	_항목(보고, "무점프 출구 불가", not 무점프.has(출구.칸))
	for p in 방.탐색지점:
		_항목(보고, "탐색지점 " + p.이름, 거리.has(p.칸))
	var 높이 = {}
	var 구역칸 = {}
	for z in 방.구역들:
		for x in range(방.L + z.x0, 방.L + z.x1):
			var p = Vector2i(x, z.서는행)
			구역칸[p] = z.id
			if 거리.has(p):
				높이[z.높이단] = true
	_항목(보고, "높이 다른 구역 3개", 높이.size() >= 3)
	for p in 방.플랫폼들:
		for x in range(p.x0, p.x1 + 1):
			var c = Vector2i(x, p.몸행 - 1)
			if not 구역칸.has(c):
				구역칸[c] = "사슬"
	var 분기 = {}
	var 고리 = {}
	for p in 거리:
		var 갈래 = []
		for e in 이웃(p):
			var id = 구역칸.get(e[0], "")
			if id != "" and id != 구역칸.get(p, "") and not 갈래.has(id):
				갈래.append(id)
			if e[2] == "낙하" and e[0].y >= 방.B - 1 and 구역칸.get(p, "") in ["S1", "S2", "S3", "S4"]:
				고리[구역칸[p]] = true
		갈래.sort()
		if 갈래.size() >= 2:
			분기[str(구역칸.get(p, "?")) + str(갈래)] = true
	_항목(보고, "의미 있는 분기 2개", 분기.size() >= 2, str(분기.size()))
	_항목(보고, "복귀 고리", not 고리.is_empty())
	_항목(보고, "갇히는 칸 0", 복귀(거리, 시작).size() == 거리.size())
	var 종류수 = {"J": 0, "G": 0, "C": 0}
	for g in 방.관문들:
		종류수[g.종류] += 1
		var p: Vector2i = g.보호대표
		var 제외 = 무칠 if g.종류 == "G" else (무점프 if g.종류 == "J" else 무색무칠)
		g["필수"] = 거리.has(p) and not 제외.has(p)
		_항목(보고, g.이름 + " 강제", g.필수)
		if g.종류 == "C":
			_항목(보고, g.이름 + " 칠하기 대안", 무색.has(p))
	for key in 종류수:
		_항목(보고, key + " 관문 존재", 종류수[key] >= 1)
	for s in 방.사격들:
		for p in 방.플랫폼들:
			if p.이름 == s.대상:
				_항목(보고, "사격 " + s.대상, 무칠.has(s.자리칸) and 탄도(s.자리칸, p))
	var 찬칸 = {}
	for p in 방.플랫폼들:
		var 폭: float = (p.x1 - p.x0 + 1) * 96.0
		_항목(보고, "발판 규격 " + p.이름, 폭 >= 규격.최소_착지폭 and 폭 <= 규격.전체칠_최대긴변 and 규격.필요_발수(폭) <= 규격.탄창)
		for x in range(p.x0, p.x1 + 1):
			var c = Vector2i(x, p.몸행)
			_항목(보고, "발판 겹침 " + str(c), not 찬칸.has(c) and 방.읽기(x, p.몸행) == 0)
			찬칸[c] = true
	var 긴낙하: int = 0
	for p in 거리:
		for dx in [-1, 1]:
			if 설수있나(p + Vector2i(dx, 0)):
				continue
			for d in range(1, 41):
				var q = p + Vector2i(dx, d)
				if (지지(q + Vector2i.DOWN) and not 고체(q)) or 고체(q) or d == 40:
					if d * 96 > 규격.치명_낙하:
						긴낙하 += 1
					break
	_항목(보고, "치명 낙하 없음", 긴낙하 == 0)
	보고["체크포인트"] = 체크솎기()
	_항목(보고, "광원 예산", 보고.체크포인트.size() + 3 <= 규격.한계_겹친광원)
	보고["출구비용"] = 거리.get(출구.칸, -1)
	보고["도달칸수"] = 거리.size()
	보고["통과"] = 보고.실패.is_empty()
	return 보고

func 탄도(자리: Vector2i, 목표: Dictionary) -> bool:
	var 원 = 방.월드점(자리) - Vector2(0, 규격.몸_높이 * 0.5)
	var rect = Rect2(목표.x0 * 96.0, 목표.몸행 * 96.0, (목표.x1 - 목표.x0 + 1) * 96.0, 규격.발판_두께)
	var d: float = 1 if rect.get_center().x >= 원.x else -1
	for angle in [0.0, -0.12, 0.12, -0.25, 0.25]:
		var v = Vector2(cos(angle) * 규격.탄속 * d, sin(angle) * 규격.탄속)
		var p: Vector2 = 원
		for tick in 180:
			v.y += 규격.탄_중력 / 60.0
			p += v / 60.0
			if p.x >= rect.position.x and p.x <= rect.end.x and p.y >= rect.position.y and p.y <= rect.end.y:
				return true
			var c = Vector2i(floori(p.x / 96), floori(p.y / 96))
			if 방.읽기(c.x, c.y) == 1:
				break
			var f = 발판칸.get(c, {})
			if not f.is_empty() and f.이름 != 목표.이름 and f.종류 != "유령":
				break
	return false

func 체크솎기() -> Array:
	var out = []
	for c in 방.체크포인트:
		var p: Vector2 = 방.월드점(c)
		var 가깝다 = false
		for q in out:
			if absf(p.x - q.x) <= 1600 and absf(p.y - q.y) <= 1600:
				가깝다 = true
		if not 가깝다:
			out.append(p)
	return out.slice(0, 10)
