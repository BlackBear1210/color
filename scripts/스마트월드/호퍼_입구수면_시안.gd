extends "res://scripts/스마트월드/호퍼_입구수면.gd"
## [2026-09-30 Claude] 호퍼 입구 "물이 담겨 있고 물줄기가 그 안으로 들어가는" 시안 v4.
## ★[2026-09-30 도형님 승인] 하수도(world_2_클로드/stage_*) 호퍼 전부에 기본으로 붙는다.
##   호퍼 인스펙터 `입구_시안_사용` 을 끄면 그 호퍼만 예전 입구 수면(호퍼_입구수면.gd)으로 돌아간다.
##
## 도형님 지적 이력(2026-09-30):
##   v2 — 입구는 사다리꼴인데 물은 직사각형(잘라 붙인 느낌) · 물줄기와 수면 사이 윤곽선
##        → v3: 원화 구멍을 줄마다 실측한 사다리꼴에만 물을 채우고 윤곽선 없앰.
##   v3 — 전체 폭 밝은 물테·가로 결이 "회색 줄" → 없애고 벽 쪽 접촉 그늘만.
##   v3b — ⓐ 물은 입구 **앞뒤 가운데**에 떨어지는데 수면 한 판이 물줄기 앞을 통째로 덮어 "판" 처럼 보였다.
##          ⓑ 흰 물 끝에 **회색 직사각형** — 물줄기 셰이더는 굴절(뒤를 비춤) + 끝 14px 을 흐리게 지운다.
##             물줄기를 호퍼 그림 위로 올리자 흐려진 끝이 뒤의 금속을 비춰 회색 사각형이 됐다.
## v4 (지금):
##   ① 수면을 두 겹으로 — **뒤 겹**(뒤 벽 ~ 가운데, 물줄기 뒤) · **앞 겹**(가운데 ~ 앞 띠, 물줄기 앞).
##      물줄기는 입구 가운데 깊이에서 앞 겹 속으로 사라진다 = 수면 속으로 들어간다.
##   ② 호퍼로 들어오는 물줄기는 끝을 딱 끊는다(셰이더 hard_end) — 끊긴 끝은 앞 겹이 덮는다. 회색 사각형 없음.
##   ③ 물결 고리: 뒤 반원은 뒤 겹, 앞 반원은 앞 겹 → 물줄기를 실제로 둘러싼다.
## 색 규칙: 검정만 → 검정 · 흰색만 → 흰색 · 둘 다 → 회색(부모의 받은색 그대로). 판정·호퍼 로직은 안 바꾼다(그림만).
##
## 그리는 순서(절대 z): 호퍼 그림 3 → 뒤 겹 4 → 물줄기 5 → 앞 겹(이 노드 · 호퍼 3 + 4 = 7)

## 원화(hopper_atlas_flat.png · 직하 칸) 입구 구멍 실측.
## y266 에서 왼쪽 x83 · y285 에서 x77 로 벌어진다(아래 = 앞쪽이 넓은 사다리꼴). 오른쪽은 x432 거의 수직.
const 구멍_위 := 266.0
const 구멍_아래 := 287.0
const 구멍_왼쪽_위 := 83.0
const 구멍_왼쪽_아래 := 77.0
const 구멍_오른쪽 := 432.0
const 수위 := 270.5         ## 원화 y — 이 위(266~270)는 물 위로 드러난 안쪽 뒤 벽
const 떨어지는_깊이 := 0.5  ## 물줄기가 수면에 닿는 곳 = 수위(뒤)와 구멍 아래(앞) 사이 비율 — 입구 앞뒤 가운데
const 줄수 := 64
const 번짐_배수 := 1.2
const 거품_높이 := 4.0      ## 물줄기 옆 거품이 수면에서 솟는 높이(px)
const 방울_높이 := 16.0

## ★ 물줄기 그림을 수면까지 늘리고 끝을 딱 끊는다(판정은 그대로).
##   물(유체_흰물v2)은 호퍼 윗면 충돌을 바닥으로 보고 그림을 호퍼 맨 윗선에서 잘랐다.
##   촬영 도구가 "지금" 판을 찍을 때는 끈다(원래대로 돌려놓는다).
var 물줄기_늘리기 := true
var _원래 := {}           ## 물 인스턴스 id → [보이는_높이, z_index, z_as_relative]
var _유입_물들: Array = []
var _뒤겹: Node2D


func _ready() -> void:
	super._ready()
	# 뒤 겹: 물줄기(z 5)보다 아래, 호퍼 그림(z 3)보다 위.
	_뒤겹 = Node2D.new()
	_뒤겹.name = "뒤수면"
	_뒤겹.z_as_relative = false
	_뒤겹.z_index = 4
	add_child(_뒤겹)
	_뒤겹.draw.connect(_뒤겹_그리기)


func 상태_받기(물색: int, 유입들: Array) -> void:
	super.상태_받기(물색, 유입들)
	if not 유입들.is_empty():
		_유입_물들 = 유입들.duplicate()


func _process(delta: float) -> void:
	super._process(delta)
	_물줄기_맞추기()
	# 뒤 겹도 같은 시계로 다시 그린다(앞 겹은 부모가 24fps 로 다시 그린다).
	if is_instance_valid(_뒤겹):
		_뒤겹.queue_redraw()


# ─────────────────────────────── 치수 ───────────────────────────────
func _배율() -> Vector2:
	return _호퍼.call("입구_아트_배율")

## 원화 y → 호퍼 로컬 y. 셀은 원화 240 을 (-높이 - 20×배율.y) 에 그린다.
func _로컬y(원화: float) -> float:
	return -float(_호퍼.get("높이")) + (원화 - 260.0) * _배율().y

## 원화 y 에서의 구멍 왼쪽 끝(로컬 x). 사다리꼴 왼변을 직선으로 잇는다.
func _왼쪽x(원화: float) -> float:
	var t := clampf((원화 - 구멍_위) / (구멍_아래 - 2.0 - 구멍_위), 0.0, 1.0)
	return (lerpf(구멍_왼쪽_위, 구멍_왼쪽_아래, t) + 1.0 - 256.0) * _배율().x

func _오른쪽x() -> float:
	return (구멍_오른쪽 - 1.0 - 256.0) * _배율().x

func _떨어지는_원화y() -> float:
	return lerpf(수위, 구멍_아래, 떨어지는_깊이)


# ─────────────────────────── 물줄기 맞추기 ───────────────────────────
func _물줄기_맞추기() -> void:
	if not is_instance_valid(_호퍼):
		return
	var 들어감 := _호퍼.to_global(Vector2(0.0, _로컬y(_떨어지는_원화y())))
	for 물 in _유입_물들:
		if not is_instance_valid(물):
			continue
		var 그림 := 물.get("_white_visual") as CanvasItem
		if 그림 == null:
			continue
		var id: int = 물.get_instance_id()
		if not _원래.has(id):
			_원래[id] = [그림.get("보이는_높이"), 그림.z_index, 그림.z_as_relative]
		var 원래: Array = _원래[id]
		var 늘림 := 물줄기_늘리기 and _색 >= 0
		var 길이: float = (물 as Node2D).to_local(들어감).y if 늘림 else float(원래[0])
		if 그림.get("보이는_높이") != 길이:
			그림.set("보이는_높이", 길이)
		# 물줄기(원래 z 2)는 호퍼 그림(z 3) 뒤라 입구 뒤 벽 원화에 가려 호퍼 윗선에서 끊겨 보였다 → 뒤 겹(4)과 앞 겹(7) 사이 5.
		그림.z_as_relative = false if 늘림 else bool(원래[2])
		그림.z_index = 5 if 늘림 else int(원래[1])
		var 재질 := 그림.material as ShaderMaterial
		if 재질 != null:
			재질.set_shader_parameter("hard_end", 늘림)


# ─────────────────────────────── 그리기 ───────────────────────────────
## 뒤 겹: 뒤 벽 ~ 떨어지는 깊이. 물줄기 뒤에 보인다.
func _뒤겹_그리기() -> void:
	if _색 < 0 or not is_instance_valid(_호퍼):
		return
	var 위 := _로컬y(수위)
	var 가운데 := _로컬y(_떨어지는_원화y())
	_수면(_뒤겹, 수위, _떨어지는_원화y(), 0.30, 0.12)
	# 벽에 닿는 곳: 밝은 선이 아니라 옅은 접촉 그늘(v3b 회색 줄 지적).
	_뒤겹.draw_line(Vector2(_왼쪽x(수위) + 1.0, 위 + 0.3), Vector2(_오른쪽x() - 1.0, 위 + 0.3), Color(0, 0, 0, 0.28), 1.0, true)
	for 접점 in _접점들:
		_고리(_뒤겹, 접점, 가운데, true)


## 앞 겹(이 노드): 떨어지는 깊이 ~ 앞 띠. 물줄기 끝을 덮는다. 그 위에 거품·방울, 마지막에 앞 금속 띠.
func _draw() -> void:
	if _색 < 0 or not is_instance_valid(_호퍼):
		return
	var 가운데 := _로컬y(_떨어지는_원화y())
	var 배율 := _배율()
	_수면(self, _떨어지는_원화y(), 구멍_아래, 0.12, 0.0)
	for 접점 in _접점들:
		_고리(self, 접점, 가운데, false)
		_거품(접점, 가운데, 배율.x)
	# 앞 금속 띠(원화 재사용) — 수면 아랫부분과 떨어지는 방울을 가린다.
	var 출구방향: int = _호퍼.get("출구방향")
	var 원본 := Rect2(출구방향 * 512 + 52, 286, 408, 58)
	var 목적 := Rect2(Vector2(-204.0 * 배율.x, _로컬y(286.0)), Vector2(408, 58) * 배율)
	draw_texture_rect_region(아틀라스, 목적, 원본)


## 수면 한 겹(원화 y 위~아래). 세로 띠마다 가까운 물줄기 색을 섞는다. 위쪽이 더 어둡다(뒤 벽 그늘).
func _수면(그릴곳: CanvasItem, 원화위: float, 원화아래: float, 위_어둡게: float, 아래_어둡게: float) -> void:
	var 위 := _로컬y(원화위)
	var 아래 := _로컬y(원화아래)
	var 왼위 := _왼쪽x(원화위)
	var 왼아래 := _왼쪽x(원화아래)
	var 오 := _오른쪽x()
	var 본색 := 수면색(_색)
	# ★[2026-10-02 실측 · 프레임 드랍 원인] 예전엔 세로 띠 64 개를 draw_polygon 64 번으로 그렸다.
	#   그리기 명령 하나하나가 OpenGL 드로우 콜이 되어, 호퍼 7 개인 2-3 에서 매 프레임 1,000 개가 넘었다
	#   → GPU 는 8ms 로 한가한데 드라이버 CPU 비용으로 프레임이 24ms(41FPS). 입구 노드를 빼면 8.1ms.
	#   → 띠 꼭짓점을 한 삼각형 배열로 묶어 **한 번에** 그린다(색은 꼭짓점마다 섞으므로 모양·색은 같다).
	var 점들 := PackedVector2Array()
	var 색들 := PackedColorArray()
	for i in 줄수 + 1:
		var t := float(i) / 줄수
		# 띠의 x 는 위·아래 각각 사다리꼴 폭 안에서 나눈다 → 왼변이 비스듬히 맞는다.
		var 위점 := Vector2(lerpf(왼위, 오, t), 위)
		var 아래점 := Vector2(lerpf(왼아래, 오, t), 아래)
		var 색 := _섞인색((위점.x + 아래점.x) * 0.5, 본색)
		점들.append(위점)
		색들.append(색.darkened(위_어둡게))
		점들.append(아래점)
		색들.append(색.darkened(아래_어둡게))
	var 번호 := PackedInt32Array()
	for i in 줄수:
		var k := i * 2
		번호.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
	RenderingServer.canvas_item_add_triangle_array(그릴곳.get_canvas_item(), 번호, 점들, 색들)


## 물줄기 둘레 납작한 물결 고리. 뒤=true 면 위 반원(뒤 겹), false 면 아래 반원(앞 겹).
func _고리(그릴곳: CanvasItem, 접점: Dictionary, 중심y: float, 뒤: bool) -> void:
	var x: float = (접점["끝"] as Vector2).x
	var 반폭 := float(접점["폭"]) * 0.5 * 0.85   # 보이는 물줄기 폭(물 v3 가 가장자리를 약 8% 조인다)
	var 대비 := _대비색(int(접점["색"]))
	var 위y := _로컬y(수위)
	var 아래y := _로컬y(구멍_아래)
	var 왼 := _왼쪽x(수위)
	var 오 := _오른쪽x()
	for r in 3:
		var t := fposmod(_시간 * 0.7 + r / 3.0, 1.0)
		var rx := 반폭 * (1.05 + t * 0.9)
		var ry := minf(rx * 0.12, minf(중심y - 위y, 아래y - 중심y) - 0.3)
		var 색 := 대비
		색.a *= (1.0 - t) * (0.35 if 뒤 else 0.55)
		var 점들 := PackedVector2Array()
		for i in 21:
			var a := (PI + PI * i / 20.0) if 뒤 else (PI * i / 20.0)
			var p := Vector2(x + cos(a) * rx, 중심y + sin(a) * ry)
			if p.x < 왼 or p.x > 오:
				if 점들.size() > 1:
					그릴곳.draw_polyline(점들, 색, 1.0, false)
				점들 = PackedVector2Array()
				continue
			점들.append(p)
		# 계단 보정(antialiased)을 끈다 — 켜면 선마다 테두리 삼각형이 더 붙어 그리기 비용이 는다(1px 선이라 차이 거의 없음).
		if 점들.size() > 1:
			그릴곳.draw_polyline(점들, 색, 1.0, false)


## 물줄기 양옆에서 끓는 거품(물줄기 색 · 윤곽 없음)과 입구 안으로 떨어지는 방울.
func _거품(접점: Dictionary, 수면: float, 크기비: float) -> void:
	var x: float = (접점["끝"] as Vector2).x
	var 반폭 := float(접점["폭"]) * 0.5 * 0.85
	var 물번호 := int(접점["색"])
	var 물색 := 수면색(물번호)
	var 대비 := _대비색(물번호)
	var 왼 := _왼쪽x(수위)
	var 오 := _오른쪽x()
	for 쪽: float in [-1.0, 1.0]:
		var 자락 := PackedVector2Array()
		var 시작 := x + 쪽 * 반폭 * 0.9
		var 끝x := clampf(x + 쪽 * 반폭 * 1.6, 왼, 오)
		자락.append(Vector2(시작, 수면 + 1.5))
		for i in 9:
			var u := float(i) / 8.0
			var 끓음 := 0.6 + 0.4 * sin(_시간 * 8.0 + i * 1.7 + 쪽)
			자락.append(Vector2(lerpf(시작, 끝x, u), 수면 - 거품_높이 * 크기비 * (1.0 - u) * 끓음))
		자락.append(Vector2(끝x, 수면 + 1.5))
		draw_colored_polygon(자락, 물색)
		# 거품 알갱이·방울은 원(draw_circle = 다각형 하나씩 = 드로우 콜 하나씩) 대신 작은 사각형으로 그린다.
		#   사각형은 한 번에 묶여 그려진다. 1~2px 크기라 화면에서는 원과 구별되지 않는다.
		for f in 3:
			var u := fposmod(f * 0.29 + _시간 * 0.9, 1.0)
			_점(Vector2(lerpf(시작, 끝x, u), 수면 - 거품_높이 * 크기비 * (1.0 - u) * 0.6), 0.7 * 크기비 + 0.3, 대비)
	for d in 8:
		var 진행 := fposmod(_시간 * 1.2 + d / 8.0, 1.0)
		var 쪽 := -1.0 if d % 2 else 1.0
		var 거리 := 반폭 * (0.5 + 0.8 * fposmod(d * 0.37, 1.0))
		var 튐 := 방울_높이 * 크기비 * (0.4 + 0.6 * fposmod(d * 0.61, 1.0)) * sin(진행 * PI)
		var p := Vector2(clampf(x + 쪽 * (반폭 * 0.95 + 거리 * 진행), 왼 + 2.0, 오 - 2.0), 수면 - 튐)
		var 방울색 := 물색 if 물번호 == 1 else 물색.lerp(대비, 0.35)
		_점(p, (1.0 - 진행 * 0.4) * 크기비 + 0.3, 방울색)


## 작은 점(반지름 r) — 사각형으로 그려 다른 사각형과 한 번에 묶이게 한다.
func _점(중심: Vector2, r: float, 색: Color) -> void:
	draw_rect(Rect2(중심 - Vector2(r, r), Vector2(r, r) * 2.0), 색)


## 검정 물 → 밝은 회색 거품, 흰 물 → 중간 회색 그늘, 회색 물 → 밝은 회색.
func _대비색(물번호: int) -> Color:
	match 물번호:
		0: return Color(0.55, 0.55, 0.55, 0.95)
		1: return Color(0.55, 0.55, 0.55, 0.85)
		_: return Color(0.78, 0.78, 0.78, 0.9)


## 수면 한 자리의 색: 물줄기 가까이는 그 물줄기 색, 멀어질수록 입구 전체 색(천천히 흔들려 섞이는 중).
func _섞인색(x: float, 본색: Color) -> Color:
	var 색 := 본색
	for 접점 in _접점들:
		var cx: float = (접점["끝"] as Vector2).x + sin(_시간 * 0.8 + x * 0.05) * 5.0
		var 반폭 := float(접점["폭"]) * 0.5 * 번짐_배수
		var w := clampf(1.0 - absf(x - cx) / (반폭 * 2.0), 0.0, 1.0)
		w = w * w * 0.9
		색 = 색.lerp(수면색(int(접점["색"])), w)
	return 색
