extends RefCounted
## ============================================================================
## [2026-09-21 신규] 미리보기 PNG — **엔진을 열지 않고 맵 모양을 본다**
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   v1 의 진짜 문제는 "수치는 다 통과하는데 **보기에 재미없다**" 였다. 도달률 100 % 여도
##   도형을 붙여 놓은 것처럼 보이면 실패다. 그런데 그걸 확인하려면 매번 Godot 을 열고
##   스테이지를 훑어야 했다 — 한 번에 1~2 분. 씨앗을 20 개 보려면 하루가 간다.
##   → 격자를 **그대로 PNG 로 찍는다.** 씨앗 하나에 0.2 초. 눈으로 고르고 나서 굽는다.
##
## ▣ 색 약속 (흑백 게임이지만 미리보기는 정보 전달이 우선이라 색을 쓴다)
##   짙은 회색 = 바위(껍데기)   흰색 = 빈 공간   옅은 파랑 = 방 영역
##   초록 = 시작   빨강 = 출구   주황 = 발판   하늘 = 유령 발판   자주 = 위험물
## ============================================================================

const 동굴_S := preload("res://tools/생성기/동굴.gd")

const 색_바위 := Color(0.17, 0.17, 0.20)
const 색_빈칸 := Color(0.96, 0.96, 0.96)
const 색_방 := Color(0.85, 0.90, 0.98)
const 색_시작 := Color(0.15, 0.75, 0.25)
const 색_출구 := Color(0.90, 0.20, 0.20)
const 색_발판 := Color(0.95, 0.60, 0.15)
const 색_유령 := Color(0.35, 0.75, 0.95)
const 색_위험 := Color(0.70, 0.20, 0.75)


## 동굴(+선택적으로 배치 결과)을 PNG 로 저장한다.
##   배율 = 칸 하나를 몇 px 로 그릴 것인가. 8 이면 120×32 칸 → 960×256 px.
static func 저장(동굴: Dictionary, 경로: String, 배치: Dictionary = {}, 배율: int = 8) -> bool:
	var W: int = int(동굴["폭칸"])
	var H: int = int(동굴["높이칸"])
	var img := Image.create(W * 배율, H * 배율, false, Image.FORMAT_RGB8)

	# 1) 바위/빈칸
	for y in H:
		for x in W:
			var c: Color = 색_바위 if 동굴_S.읽기(동굴, x, y) == 동굴_S.암반 else 색_빈칸
			_칸(img, 배율, x, y, c)

	# 2) 방 영역을 옅게 덧칠한다(빈칸인 곳만) — 어디가 방이고 어디가 통로인지 보인다
	for 방 in 동굴["방들"]:
		var r: Rect2i = 방["사각"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if 동굴_S.읽기(동굴, x, y) != 동굴_S.암반:
					_칸(img, 배율, x, y, 색_방)

	# 3) 배치물(있으면) — 월드 좌표를 칸으로 되돌려 찍는다
	if not 배치.is_empty():
		for p in 배치.get("플랫폼", []):
			var 색: Color = 색_유령 if String(p["종류"]) == "유령" else 색_발판
			_사각(img, 동굴, 배율, p["사각"], 색)
		for h in 배치.get("위험물", []):
			var c2: Vector2i = 동굴_S.월드_칸(동굴, h["위치"])
			_칸(img, 배율, c2.x, c2.y, 색_위험)

	# 4) 윤곽선 — **뽑아낸 폴리곤이 진짜로 동굴을 감싸고 있는지** 눈으로 본다.
	#    ★이 확인이 없으면 "점 212 개" 같은 숫자만 보고 통과시키게 된다. 변 잇기가 중간에
	#      끊겨 반쪽만 뽑혀도 숫자는 그럴듯하게 나온다.
	if 배치.has("테두리원본"):
		_선(img, 동굴, 배율, 배치["테두리원본"], Color(0.2, 0.85, 0.35))
	if 배치.has("껍데기"):
		_선(img, 동굴, 배율, 배치["껍데기"], Color(0.95, 0.25, 0.55))
	for s in 배치.get("섬들", []):
		_선(img, 동굴, 배율, s, Color(0.15, 0.55, 0.95))

	# 5) 시작·출구는 제일 위에 크게
	_점(img, 배율, 동굴["시작칸"], 색_시작)
	_점(img, 배율, 동굴["출구칸"], 색_출구)

	var e := img.save_png(경로)
	return e == OK


static func _칸(img: Image, 배율: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0:
		return
	for dy in 배율:
		for dx in 배율:
			var px := x * 배율 + dx
			var py := y * 배율 + dy
			if px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)


## 3×3 칸짜리 표식(시작·출구)
static func _점(img: Image, 배율: int, 칸: Vector2i, c: Color) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_칸(img, 배율, 칸.x + dx, 칸.y + dy, c)


## 월드 사각형을 칸 좌표로 바꿔 칠한다. 발판이 한 칸보다 얇아도 **최소 한 칸**은 보이게 한다.
static func _사각(img: Image, 동굴: Dictionary, 배율: int, r: Rect2, c: Color) -> void:
	var a: Vector2i = 동굴_S.월드_칸(동굴, r.position)
	var b: Vector2i = 동굴_S.월드_칸(동굴, r.end - Vector2(1, 1))
	for y in range(a.y, maxi(b.y, a.y) + 1):
		for x in range(a.x, maxi(b.x, a.x) + 1):
			_칸(img, 배율, x, y, c)


## 닫힌 폴리곤을 선으로 그린다(월드 좌표 → 미리보기 픽셀).
## 칸 단위가 아니라 **픽셀 단위**로 찍어야 사선이 사선으로 보인다.
static func _선(img: Image, 동굴: Dictionary, 배율: int, 점들: PackedVector2Array, c: Color) -> void:
	if 점들.size() < 2:
		return
	var 원점: Vector2 = 동굴["원점"]
	var 칸크기: float = float(동굴["칸크기"])
	for i in 점들.size():
		var a: Vector2 = (점들[i] - 원점) / 칸크기 * float(배율)
		var b: Vector2 = (점들[(i + 1) % 점들.size()] - 원점) / 칸크기 * float(배율)
		var d := a.distance_to(b)
		var n := maxi(int(d), 1)
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(n))
			var px := int(p.x)
			var py := int(p.y)
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)


## ★통행 진단 — 설 수 있는 칸을 **닿는 곳(초록) / 못 닿는 곳(빨강)** 으로 칠한다.
##   숫자만 보면 "왜 안 닿는지" 를 영원히 모른다. 그림으로 보면 3 초면 안다.
static func 통행_덧칠(경로: String, 동굴: Dictionary, 보고: Dictionary, 배율: int = 10) -> bool:
	var img := Image.load_from_file(경로)
	if img == null:
		return false
	var 닿음: Dictionary = 보고.get("닿음", {})
	var 설칸: Dictionary = 보고.get("설칸", {})
	for k in 설칸:
		var x := int(k % 10000)
		var y := int(k / 10000)
		var c := Color(0.15, 0.8, 0.3) if 닿음.has(k) else Color(0.95, 0.15, 0.15)
		# 칸 전체를 덮으면 지형이 안 보인다 → 아래쪽 절반만 얇게 칠한다(= 발 딛는 면)
		for dx in 배율:
			for dy in range(배율 - 3, 배율):
				var px := x * 배율 + dx
				var py := y * 배율 + dy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)
	return img.save_png(경로) == OK
