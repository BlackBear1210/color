extends RefCounted
## 탐색방_프로토.py의 확정된 기하를 보존한다. 기존 평면 방 생성기와 분리해
## 에디터에서 손본 씬을 덮어쓰지 않고, 생성은 트리/엔진 물리 없이 순수 데이터만 만든다.
const 난수 = preload("res://tools/생성기/난수.gd")
const 버전 = "exploration_v1"
const 칸크기 = 96.0
var 씨앗: int
var 표준: bool
var W: int
var H: int
var L: int = 8
var T: int = 8
var R: int
var B: int
var 안폭: int
var 층수: int
var 칸 = PackedByteArray()
var 구역들: Array = []
var 간선들: Array = []
var 플랫폼들: Array = []
var 가시칸: Array = []
var 관문들: Array = []
var 소켓들: Array = []
var 사격들: Array = []
var 체크포인트: Array = []
var 탐색지점: Array = []
var 계단단: Array = []
var 구멍들: Array = []
var 계단밑통로: Vector2i
var 선반벽: String
var 뒤집기: bool = false
var 지형난수
var 출구난수
var 관문난수
var 장식난수

func _init(seed_value: int = 1, standard: bool = false):
	씨앗 = seed_value
	표준 = standard
	안폭 = 72 if 표준 else 60
	층수 = 4 if 표준 else 3
	W = 안폭 + 16
	H = (36 if 표준 else 24) + 16
	R = W - 8
	B = H - 8
	지형난수 = 난수.new(씨앗, "지형")
	출구난수 = 난수.new(씨앗, "출구")
	관문난수 = 난수.new(씨앗, "관문")
	장식난수 = 난수.new(씨앗, "장식")
	칸.resize(W * H)
	칸.fill(1)

func 읽기(x: int, y: int) -> int:
	return 1 if x < 0 or y < 0 or x >= W or y >= H else 칸[y * W + x]

func 채우기(x0: int, x1: int, y0: int, y1: int, value: int = 1):
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x >= 0 and x < W and y >= 0 and y < H:
				칸[y * W + x] = value

func 구역(id: String) -> Dictionary:
	for z in 구역들:
		if z.id == id:
			return z
	return {}

func 간선(a: String, b: String, 행동: String, 수단: String):
	간선들.append({"from": a, "to": b, "행동": 행동, "수단": 수단})

func 발판(이름: String, x0: int, x1: int, 행: int, 종류: String, 색: int, 번호: int):
	var p = {"이름": 이름, "x0": x0, "x1": x1, "몸행": 행, "종류": 종류, "색": 색, "관문": 번호}
	플랫폼들.append(p)
	return p

func 계단(id: String, 아래행: int, 기준: int, d: int, 자리들: Array) -> Array:
	var out = []
	for k in 3:
		var 행: int = 아래행 - 1 - k
		var x: int = 기준 + d * 자리들[k]
		var x0: int = mini(x, x + d)
		채우기(x0, x0 + 1, 행 + 1, 행 + 2)
		out.append({"x0": x0, "x1": x0 + 1, "서는": 행, "이름": "%s_%d" % [id, k + 1]})
	return out

func 생성():
	# 인스턴스를 재사용해도 앞선 결과/난수 상태가 누적되지 않게 처음부터 만든다.
	_init(씨앗, 표준)
	for 목록 in [구역들, 간선들, 플랫폼들, 가시칸, 관문들, 소켓들, 사격들,
			체크포인트, 탐색지점, 계단단, 구멍들]:
		목록.clear()
	선반벽 = "좌" if 지형난수.확률(50) else "우"
	for i in range(층수 + 1):
		var 폭: int = 안폭 if i == 0 else 안폭 - 18 - 12 * (i - 1)
		var x0: int = 0 if i == 0 or 선반벽 == "좌" else 안폭 - 폭
		var 컨셉: Array = ["책상단", "책장회랑", "다락서가"] if 선반벽 == "좌" else ["창가단", "창가회랑", "지붕밑"]
		구역들.append({"id": "바닥" if i == 0 else "S%d" % i, "높이단": 4 * i,
			"x0": x0, "x1": x0 + 폭, "벽": "양쪽" if i == 0 else 선반벽,
			"컨셉": "마루" if i == 0 else 컨셉[mini(i - 1, 2)],
			"종류": "바닥" if i == 0 else "선반", "지지행": B - 4 * i, "서는행": B - 4 * i - 1})
	채우기(L, R - 1, T, B - 1, 0)
	for z in 구역들.slice(1):
		채우기(L + z.x0, L + z.x1 - 1, z.지지행, z.지지행 + 1)
	var d벽: int = -1 if 선반벽 == "좌" else 1
	for i in range(1, 층수 + 1):
		var 아래 = 구역("S1" if i == 1 else "S%d" % (i - 1))
		var edge: int = L + 아래.x1 - 1 if 선반벽 == "좌" else L + 아래.x0
		var d: int = -d벽 if i == 1 else d벽
		var steps = 계단("계단_S%d" % i, B - 1 if i == 1 else 아래.서는행,
			edge, d, [5, 3, 1] if i == 1 else [5, 7, 9])
		계단단.append({"구역": "S%d" % i, "단들": steps, "d": d, "종류": "마루계단" if i == 1 else "선반계단"})
		간선("바닥" if i == 1 else "S%d" % (i - 1), "S%d" % i, "점프", "바위 계단")
		간선("S%d" % i, "바닥", "낙하", "가장자리에서 내려서기")
	# 계단 아래로 97px 몸이 지나가려면 마루를 두 칸 파고 양끝에 한 단씩 남겨야 한다.
	var a: int = W
	var b: int = 0
	for st in 계단단[0].단들:
		a = mini(a, st.x0 - 2)
		b = maxi(b, st.x1 + 2)
	계단밑통로 = Vector2i(a, b)
	채우기(a, b, B, B, 0)
	채우기(a + 1, b - 1, B + 1, B + 1, 0)
	for i in range(1, 층수):
		var z = 구역("S%d" % i)
		var 벽끝: int = L + z.x0 if 선반벽 == "좌" else L + z.x1 - 1
		var 끝: int = W if 선반벽 == "좌" else 0
		for st in 계단단[i].단들:
			끝 = mini(끝, st.x0) if 선반벽 == "좌" else maxi(끝, st.x1)
		var 걸음: int = 1 if 끝 > 벽끝 else -1
		var 낮: int = 벽끝 + 걸음 * 4
		var 높: int = 끝 - 걸음 * 3
		var x: int = 낮 + 걸음 * 장식난수.정수(1, absi(높 - 낮) - 1)
		var x0: int = mini(x, x + 걸음)
		채우기(x0, x0 + 1, z.지지행, z.지지행 + 1, 0)
		구멍들.append({"구역": z.id, "x0": x0, "x1": x0 + 1, "행": z.지지행})
		간선(z.id, "바닥" if i == 1 else "S%d" % (i - 1), "낙하", "내려가는 구멍")
	_관문()
	_소켓()
	for z in 구역들:
		var 좌: bool = z.벽 == "좌"
		탐색지점.append({"이름": z.id + "_문앞", "칸": Vector2i(L + z.x0 + 1 if 좌 else L + z.x1 - 2, z.서는행)})
		탐색지점.append({"이름": z.id + "_안쪽", "칸": Vector2i(L + z.x1 - 2 if 좌 else L + z.x0 + 1, z.서는행)})
	for c in 계단단:
		탐색지점.append({"이름": "계단_" + c.구역, "칸": Vector2i(c.단들[1].x0, c.단들[1].서는)})
	뒤집기 = 지형난수.확률(50)
	if 뒤집기:
		_반전()

func _관문():
	var 선택 = 계단단[관문난수.정수(1, 계단단.size() - 1)]
	var 위 = 선택.단들[2]
	채우기(위.x0, 위.x1, 위.서는 + 1, 위.서는 + 2, 0)
	var p = 발판("관문01_유령단", 위.x0, 위.x1, 위.서는 + 1, "유령", 1, 1)
	var 자리 = Vector2i(선택.단들[1].x0, 선택.단들[1].서는)
	var z = 구역(선택.구역)
	사격들.append({"자리칸": 자리, "대상": p.이름})
	관문들.append({"번호": 1, "종류": "G", "역할": "필수", "이름": "관문01_유령단(%s)" % z.id,
		"보호": [위.x0 - 1, 위.서는 - 1, 위.x1 + 1, 위.서는 + 2],
		"보호대표": Vector2i(L + z.x0 + 1 if z.벽 == "좌" else L + z.x1 - 2, z.서는행), "재시도": 자리})
	체크포인트.append(자리)
	var 왼: int = 계단밑통로.y + 2 if 선반벽 == "좌" else L + 3
	var 오: int = R - 6 if 선반벽 == "좌" else 계단밑통로.x - 4
	var j: int = 왼 + 관문난수.정수(0, 오 - 왼)
	채우기(j, j + 1, B, B + 1, 0)
	가시칸.append(Vector2i(j, B + 1))
	가시칸.append(Vector2i(j + 1, B + 1))
	관문들.append({"번호": 2, "종류": "J", "역할": "필수", "이름": "관문02_도약",
		"보호": [j - 1, B - 2, j + 2, B + 1],
		"보호대표": Vector2i(j + 3 if 선반벽 == "우" else j - 2, B - 1),
		"재시도": Vector2i(j - 3 if 선반벽 == "우" else j + 3, B - 1)})
	체크포인트.append(Vector2i(j - 3, B - 1))
	체크포인트.append(Vector2i(j + 3, B - 1))
	for zone in 구역들.slice(1):
		var 벽끝: int = L + zone.x0 if zone.벽 == "좌" else L + zone.x1 - 1
		var 안끝: int = L + zone.x1 - 1 if zone.벽 == "좌" else L + zone.x0
		var d: int = 1 if 안끝 > 벽끝 else -1
		for i in range(3, maxi(3, absi(안끝 - 벽끝) - 6)):
			var x: int = 벽끝 + d * i
			var x0: int = mini(x, x + d * 4)
			var y: int = zone.서는행
			if not _비었나(x0, x0 + 4, y) or not _비었나(x0, x0 + 4, y - 1) or not _비었나(x0, x0 + 4, y - 2):
				continue
			var 번호: int = 관문들.size() + 1
			발판("관문%02d_색바닥" % 번호, x0, x0 + 4, y, "색슬래브", 2 if 관문난수.확률(70) else 1, 번호)
			var retry = Vector2i(x0 + 6 if zone.벽 == "좌" else x0 - 2, y)
			관문들.append({"번호": 번호, "종류": "C", "역할": "선택", "이름": "관문%02d_색바닥(%s)" % [번호, zone.id],
				"보호": [x0 - 1, y - 2, x0 + 5, y], "보호대표": Vector2i(x0 - 2 if zone.벽 == "좌" else x0 + 6, y), "재시도": retry})
			체크포인트.append(retry)
			break

func _비었나(x0: int, x1: int, y: int) -> bool:
	for x in range(x0, x1 + 1):
		if 읽기(x, y) == 1:
			return false
		for p in 플랫폼들:
			if p.몸행 == y and p.x0 <= x and x <= p.x1:
				return false
	return true

func _소켓():
	for z in 구역들:
		for 쪽 in (["좌", "우"] if z.벽 == "양쪽" else [z.벽]):
			var id: String = "바닥_" + 쪽 if z.높이단 == 0 else z.id
			var 입구: bool = id == ("바닥_우" if 선반벽 == "좌" else "바닥_좌")
			소켓들.append({"id": id, "구역": z.id, "칸": Vector2i(L if 쪽 == "좌" else R - 1, z.서는행),
				"방향": -1 if 쪽 == "좌" else 1, "벽x": L if 쪽 == "좌" else R,
				"높이단": z.높이단, "역할": "입구" if 입구 else "후보"})

func _반전칸(p: Vector2i) -> Vector2i:
	return Vector2i(W - 1 - p.x, p.y)

func _반전():
	var 새칸 = 칸.duplicate()
	for y in H:
		for x in W:
			새칸[y * W + W - 1 - x] = 칸[y * W + x]
	칸 = 새칸
	for 목록 in [플랫폼들, 구멍들]:
		for p in 목록:
			var x: int = p.x0
			p.x0 = W - 1 - p.x1
			p.x1 = W - 1 - x
	for 목록 in [가시칸, 체크포인트]:
		for i in 목록.size():
			목록[i] = _반전칸(목록[i])
	for s in 사격들:
		s.자리칸 = _반전칸(s.자리칸)
	for g in 관문들:
		var p = g.보호
		g.보호 = [W - 1 - p[2], p[1], W - 1 - p[0], p[3]]
		g.재시도 = _반전칸(g.재시도)
		g.보호대표 = _반전칸(g.보호대표)
	for s in 소켓들:
		s.칸 = _반전칸(s.칸)
		s.방향 *= -1
		s.벽x = W - s.벽x
	for p in 탐색지점:
		p.칸 = _반전칸(p.칸)
	for z in 구역들:
		var x: int = z.x0
		z.x0 = 안폭 - z.x1
		z.x1 = 안폭 - x
		z.벽 = {"좌": "우", "우": "좌"}.get(z.벽, z.벽)
	# 보조 메타데이터도 실제 격자에 맞춰 배경/진단이 반대편을 가리키지 않게 한다.
	for c in 계단단:
		c.d *= -1
		for st in c.단들:
			var x: int = st.x0
			st.x0 = W - 1 - st.x1
			st.x1 = W - 1 - x
	계단밑통로 = Vector2i(W - 1 - 계단밑통로.y, W - 1 - 계단밑통로.x)

func 입구() -> Dictionary:
	for s in 소켓들:
		if s.역할 == "입구":
			return s
	return {}

func 월드점(p: Vector2i) -> Vector2:
	return Vector2(p.x + 0.5, p.y + 1) * 칸크기

# ============================================================================
# [2026-09-28 추가] 파이프라인 어댑터 — 윤곽·배치·조립2·미리보기가 읽는 **사전 모양**
# ----------------------------------------------------------------------------
# ▣ 왜 필요한가
#   이 클래스는 순수 데이터(칸·구역·소켓)만 들고 있다. 그런데 뒤 단계
#   (`윤곽.gd` → `조립2.gd` → `미리보기.gd`)는 `동굴층.gd`·`계단층.gd`·`방층.gd` 가
#   돌려주던 **사전 한 벌**을 기대한다. 그 모양으로 옮겨 주는 것이 이 함수다.
#   → 덕분에 뒤 단계는 한 줄도 안 고쳐도 되고, 탐색 전용 정보(구역·관문·소켓·
#     탐색지점)는 키를 더해 얹어 둔다(모르는 소비자는 그냥 무시한다).
#
# ▣ 좌표 약속
#   원점은 (0, 0)이다. `월드점()` 이 이미 원점 없이 계산하므로 둘을 맞춘다.
#   카메라 리밋·낙사선은 `조립2.gd` 가 전체 사각에서 다시 구한다.
# ============================================================================
const 규격_S = preload("res://tools/생성기/규격.gd")

func 사전() -> Dictionary:
	var 플랫폼_출력: Array = []
	for p in 플랫폼들:
		# ★밑면을 어디에 두나 — 이 한 줄이 "지형 침투 FAIL" 을 가른다.
		#   발판 두께는 112 px 인데 칸은 96 px 다. 몸행 칸의 **위**에 맞춰 놓으면
		#   16 px 이 아래 칸으로 삐져나간다. 그 아래가 바위면 그대로 **지형을 파고든다**
		#   (실측: 벽_껍데기 ↔ 관문03_색바닥 교집합 7,680 px²).
		#   · 아래가 바위면 → 밑면을 바위 윗면에 딱 맞춘다(윗면이 96+16=112 px 높아진다.
		#     한 번에 올라설 수 있는 높이 = 설계_최대상승 112 · 판정선 128 안이다).
		#   · 아래가 빈칸이면 → 지금처럼 칸 위에 맞춘다(허공에 뜬 발판).
		var 아래바위: bool = 읽기(p.x0, p.몸행 + 1) == 1
		var 윗면: float = (p.몸행 + 1) * 칸크기 - 규격_S.발판_두께 if 아래바위 			else p.몸행 * 칸크기
		플랫폼_출력.append({
			"이름": p.이름,
			"사각": Rect2(p.x0 * 칸크기, 윗면,
				(p.x1 - p.x0 + 1) * 칸크기, 규격_S.발판_두께),
			"종류": p.종류, "색": p.색,
			"칠방식": 0, "일방통행": false, "의도형태": "직사각형",
			"관문": p.관문, "칸": Vector2i(p.x0, p.몸행), "칸끝x": p.x1,
		})

	# 가시는 **노드 하나가 여러 칸을 덮게** 묶는다(hazard 는 매 물리 프레임 전부 순회한다).
	var 위험물: Array = []
	var 정렬 = 가시칸.duplicate()
	정렬.sort_custom(func(a, b): return a.y * 10000 + a.x < b.y * 10000 + b.x)
	var i: int = 0
	while i < 정렬.size():
		var 개수: int = 1
		while i + 개수 < 정렬.size() and 정렬[i + 개수].y == 정렬[i].y \
				and 정렬[i + 개수].x == 정렬[i].x + 개수:
			개수 += 1
		위험물.append({
			"종류": "가시", "씬": "res://scenes/장애물/가시.tscn",
			"위치": 월드점(정렬[i]), "칸수": 개수,
		})
		i += 개수

	var 체크_출력: Array = []
	for c in 체크포인트:
		체크_출력.append(월드점(c))

	var 사격_출력: Array = []
	for s in 사격들:
		var 목표 = Rect2()
		for p2 in 플랫폼_출력:
			if p2.이름 == s.대상:
				목표 = p2.사각
				break
		사격_출력.append({
			"자리": 월드점(s.자리칸) - Vector2(0.0, 규격_S.몸_높이 * 0.5),
			"목표": 목표, "대상": s.대상,
		})

	# 호환용 "방" 목록 — 조립·진단이 방 단위로 훑을 때 쓴다.
	var 방들: Array = []
	for n in 구역들.size():
		var z = 구역들[n]
		방들.append({
			"사각": Rect2i(L + z.x0, z.서는행 - 3, z.x1 - z.x0, 4),
			"이름": z.id, "바닥y": z.서는행 + 1, "천장y": z.서는행 - 3, "번호": n,
		})

	var 바닥줄 = PackedInt32Array()
	바닥줄.resize(W)
	바닥줄.fill(-1)
	for x in range(L, R):
		바닥줄[x] = B

	var 입구소켓 = 입구()
	var 출구소켓 = {}
	for s2 in 소켓들:
		if s2.역할 == "출구":
			출구소켓 = s2
	var 시작칸: Vector2i = 입구소켓.칸 if not 입구소켓.is_empty() else Vector2i(L + 1, B - 1)
	var 출구칸: Vector2i = 출구소켓.칸 if not 출구소켓.is_empty() else 시작칸

	return {
		"칸": 칸, "폭칸": W, "높이칸": H, "칸크기": 칸크기, "원점": Vector2.ZERO,
		"방들": 방들, "통로들": 통로스펙(), "층들": [B] as Array[int], "바닥줄": [바닥줄],
		"시작칸": 시작칸, "출구칸": 출구칸,
		"배치물": {"플랫폼": 플랫폼_출력, "위험물": 위험물,
			"체크포인트": 체크_출력, "사격": 사격_출력},
		# ── 탐색 전용 ────────────────────────────────────────────────────
		"구역들": 구역들, "간선들": 간선들, "관문들": 관문들, "소켓들": 소켓들,
		"탐색지점": 탐색지점, "계단단": 계단단, "구멍들": 구멍들,
		"가시칸": 가시칸, "플랫폼칸": 플랫폼들, "사격들": 사격들,
		"뒤집기": 뒤집기, "선반벽": 선반벽, "씨앗": 씨앗, "버전": 버전,
		"L": L, "R": R, "T": T, "B": B, "바닥행": B,
	}


## 소켓 → `연결통로` 노드 스펙. `조립2.gd` 가 이걸 보고 노드를 만든다.
##   · 입구는 판정이 없다(걸어 나오는 자리). 출구만 다음 씬으로 넘긴다.
##   · 방향 −1 이면 통로가 **왼쪽**으로 파고든다 → `연결통로.반대방향` 을 켠다.
##     (기존 규약은 출구=오른쪽뿐이라 왼쪽 벽 문을 만들 수 없었다)
func 통로스펙() -> Array:
	var out: Array = []
	for s in 소켓들:
		if s.역할 != "입구" and s.역할 != "출구":
			continue
		out.append({
			"이름": "입구통로" if s.역할 == "입구" else "출구통로",
			"역할": s.역할,
			"위치": Vector2(s.벽x * 칸크기, (s.칸.y + 1) * 칸크기),
			"방향": s.방향, "소켓": s.id, "높이단": s.높이단,
			"다음_씬": "", "다음_진입점": "입구통로",
		})
	return out
