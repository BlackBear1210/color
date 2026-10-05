@tool
extends 색레이저
## ============================================================================
## [2026-10-05 Claude] 쳅터1 색 빛 — 창문 달빛 · 천장 틈 빛 기둥 · 그을음 기둥
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   도형님: "빛 기둥과 창문에서 빛이 나오는 기믹을 더 자연스럽게 바꿔."
##   공용 `색레이저.gd` 는 하수도용 '장치'(벽에 박힌 원통 + 딱딱한 막대)로 그려진다.
##   저택 안에서는 빛이 **창문이나 무너진 천장 틈에서 들어오는 것**처럼 보여야 자연스럽다.
##
## ▣ 무엇을 바꿨나 — 그림만
##   판정(빛 안에서 몸 색 ≠ 빛 색이면 사망) · 주기 · 점멸 · 예고는 **색레이저.gd 를 그대로 상속**한다.
##   월드.gd 는 그룹 "색레이저" 로 이 노드를 똑같이 찾는다 → 게임 규칙은 한 글자도 안 바뀐다.
##   ⚠ 판정 띠(두께)는 그림에서도 **또렷한 띠**로 남긴다. 바깥 번짐은 띠 밖으로만 번진다
##     — 번짐까지 위험해 보이면 억울하고, 띠가 흐리면 어디까지 위험한지 못 읽는다.
##
## ▣ 근원 3가지
##   창문  : 벽 높은 곳 창문에서 비스듬히 떨어지는 달빛(흰). 창문 그림은 생성기가 배경 가구로 따로 놓는다.
##   천장틈: 무너진 천장 틈에서 곧게 내려오는 빛 기둥(흰). 틈 자국을 직접 그린다.
##   그을음: 천장 틈에서 검은 재가 쏟아지는 기둥(검정) — '검은 빛' 을 저택에서 말이 되게 바꾼 것.
##   점멸(켜짐/꺼짐) = 구름이 달을 가렸다 걷히는 것. 켜지기 직전 예고시간 동안 희미하게 차오른다.
## ============================================================================

@export_enum("창문:0", "천장틈:1", "그을음:2") var 근원: int = 0:
	set(v):
		근원 = v
		queue_redraw()
## 바깥 번짐이 끝쪽으로 갈수록 넓어지는 정도(빛은 퍼진다). 판정 띠에는 영향 없음.
@export_range(1.0, 3.0) var 퍼짐: float = 1.6
## 떠다니는 먼지(달빛) / 떨어지는 재(그을음) 개수
@export_range(0, 80) var 알갱이: int = 28

var _시각: float = 0.0
var _보임: float = 1.0          # 그림 밝기(점멸을 부드럽게) — 판정과는 별개


func _ready() -> void:
	super._ready()
	z_index = 20               # 지형·플레이어 위로 빛이 내려앉는다(연결구 전경 60 보다는 아래)
	_재질()


func _재질() -> void:
	# 달빛은 더하기 섞기(빛처럼 밝아진다), 그을음은 보통 섞기(어둡게 덮는다)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if 시작색 == ColorDefs.WHITE else CanvasItemMaterial.BLEND_MODE_MIX
	material = m


func _process(delta: float) -> void:
	# 부모(색레이저)는 색 고정(주기 0)이면 다시 그리지 않는다 → 먼지가 멈춰 보이므로 매 프레임 그린다
	_시각 += delta
	var 목표 := 1.0 if _켜짐 else 0.0
	if not _켜짐 and 예고시간 > 0.0 and _남은() < 예고시간:
		목표 = 0.35 * (1.0 - _남은() / 예고시간)      # 켜지기 직전: 희미하게 차오른다(예고)
	_보임 = move_toward(_보임, 목표, delta * (6.0 if 목표 < _보임 else 3.0))
	queue_redraw()


func _흰가() -> bool:
	return _색 == ColorDefs.WHITE


func _draw() -> void:
	var 방향 := Vector2.RIGHT.rotated(deg_to_rad(각도))
	var 수직 := 방향.orthogonal()
	var 흰 := _흰가()
	var 본 := Color(0.93, 0.95, 1.0) if 흰 else Color(0.03, 0.03, 0.035)
	var 세기 := clampf(_보임, 0.0, 1.0)
	if Engine.is_editor_hint():
		세기 = 1.0
	_근원_그리기(방향, 수직, 흰, 본, maxf(세기, 0.25))
	if 세기 <= 0.01:
		return
	var 반 := 두께 * 0.5
	var 마디 := 10
	# ── 1) 바깥 번짐: 판정 띠 밖으로만, 끝으로 갈수록 넓고 옅게 ──
	for i in 마디:
		var u0 := float(i) / 마디
		var u1 := float(i + 1) / 마디
		var 바깥0 := 반 + 두께 * (0.25 + 0.5 * (퍼짐 - 1.0) * u0)
		var 바깥1 := 반 + 두께 * (0.25 + 0.5 * (퍼짐 - 1.0) * u1)
		var a0 := (0.20 if 흰 else 0.28) * 세기 * (1.0 - 0.35 * u0)
		var a1 := (0.20 if 흰 else 0.28) * 세기 * (1.0 - 0.35 * u1)
		var p0 := 방향 * 길이 * u0
		var p1 := 방향 * 길이 * u1
		for s in [-1.0, 1.0]:
			draw_polygon(PackedVector2Array([p0 + 수직 * 반 * s, p0 + 수직 * 바깥0 * s, p1 + 수직 * 바깥1 * s, p1 + 수직 * 반 * s]),
				PackedColorArray([_투명(본, a0), _투명(본, 0.0), _투명(본, 0.0), _투명(본, a1)]))
	# ── 2) 판정 띠: 가운데가 조금 더 진한 또렷한 띠 ──
	for i in 마디:
		var u0 := float(i) / 마디
		var u1 := float(i + 1) / 마디
		var p0 := 방향 * 길이 * u0
		var p1 := 방향 * 길이 * u1
		# 그을음은 기둥처럼 꽉 차 보이지 않게 띠를 옅게 두고, 떨어지는 재·줄기로 채운다
		var 가장 := (0.38 if 흰 else 0.34) * 세기
		var 가운 := (0.55 if 흰 else 0.58) * 세기
		var 흔들 := 1.0 + 0.06 * sin(_시각 * 2.1 + u0 * 5.0)      # 빛이 아주 조금 일렁인다
		for s in [-1.0, 1.0]:
			draw_polygon(PackedVector2Array([p0, p0 + 수직 * 반 * s, p1 + 수직 * 반 * s, p1]),
				PackedColorArray([_투명(본, 가운 * 흔들), _투명(본, 가장), _투명(본, 가장), _투명(본, 가운 * 흔들)]))
	# 띠 가장자리 선 — 어디까지 위험한지 읽히게(그을음은 밝은 테, 달빛은 은은한 흰 테)
	var 테 := Color(1, 1, 1, 0.30 * 세기) if 흰 else Color(0.55, 0.55, 0.60, 0.22 * 세기)
	if 흰:
		draw_line(수직 * 반, 방향 * 길이 + 수직 * 반, 테, 1.5)
		draw_line(-수직 * 반, 방향 * 길이 - 수직 * 반, 테, 1.5)
	else:
		# 그을음 가장자리는 끊긴 점선 — 기둥 윤곽이 아니라 '재가 흩날리는 경계' 로 읽힌다
		var 칸 := 14.0
		var d := fposmod(_시각 * 90.0, 칸 * 2.0)
		while d < 길이:
			var e := minf(d + 칸, 길이)
			draw_line(수직 * 반 + 방향 * d, 수직 * 반 + 방향 * e, 테, 1.2)
			draw_line(-수직 * 반 + 방향 * d, -수직 * 반 + 방향 * e, 테, 1.2)
			d += 칸 * 2.0
	# ── 3) 빛살(달빛) / 흘러내리는 줄기(그을음) ──
	if 흰:
		for k in 3:
			var 위치 := sin(_시각 * (0.35 + k * 0.17) + k * 2.3) * 반 * 0.7
			draw_line(수직 * 위치, 방향 * 길이 + 수직 * 위치 * 1.1, _투명(본, 0.10 * 세기), 2.0 + k)
	else:
		# 재가 줄줄이 쏟아지는 끊긴 줄기 — 아래로 흘러가는 선분들
		for k in 5:
			var 위치 := (float(k) / 4.0 - 0.5) * 반 * 1.5 + sin(_시각 * 0.7 + k) * 3.0
			var 칸 := 26.0 + k * 7.0
			var d := fposmod(_시각 * (160.0 + k * 35.0) + k * 40.0, 칸 * 2.0) - 칸 * 2.0
			while d < 길이:
				var a0 := maxf(d, 0.0)
				var a1 := minf(d + 칸, 길이)
				if a1 > a0:
					draw_line(방향 * a0 + 수직 * 위치, 방향 * a1 + 수직 * 위치, Color(0, 0, 0, 0.45 * 세기), 2.0)
				d += 칸 * 2.0
	# ── 4) 알갱이: 달빛 먼지는 천천히 떠다니고, 재는 빛을 따라 떨어진다 ──
	for n in 알갱이:
		var h := fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(n) * 78.233) * 12543.137, 1.0)
		var 속도 := (0.03 + 0.04 * h2) if 흰 else (0.18 + 0.12 * h2)
		var u := fposmod(h + _시각 * 속도, 1.0)
		var 옆 := (h2 * 2.0 - 1.0) * 반 * 0.9 + sin(_시각 * (0.8 + h) + n) * 반 * (0.15 if 흰 else 0.08)
		var 점 := 방향 * 길이 * u + 수직 * 옆
		var 반짝 := 0.5 + 0.5 * sin(_시각 * (2.0 + 3.0 * h) + n * 1.7)
		var 끝흐림 := clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
		if 흰:
			draw_circle(점, 1.2 + 1.6 * h2, Color(1, 1, 1, (0.25 + 0.55 * 반짝) * 세기 * 끝흐림))
		else:
			draw_circle(점, 1.6 + 2.2 * h2, Color(0.0, 0.0, 0.0, 0.75 * 세기 * 끝흐림))
	# ── 5) 끝: 바닥에 고인 빛 / 재 무더기 ──
	var 끝 := 방향 * 길이
	var 고임 := PackedVector2Array()
	for i in 20:
		var t := TAU * float(i) / 20.0
		고임.append(끝 + Vector2(cos(t) * 두께 * (1.1 if 흰 else 0.7), sin(t) * 7.0 - 3.0))
	draw_colored_polygon(고임, _투명(본, (0.22 if 흰 else 0.55) * 세기))


func _근원_그리기(방향: Vector2, 수직: Vector2, 흰: bool, 본: Color, 세기: float) -> void:
	var 반 := 두께 * 0.5
	if 근원 == 0:
		# 창문: 창문 그림은 배경에 따로 있다. 창유리 쪽으로 은은한 빛무리만.
		# 고리가 보이지 않게 얇은 원을 여러 겹 — 가운데로 갈수록 조금씩 밝아지는 부드러운 빛무리
		for k in 10:
			draw_circle(Vector2.ZERO, 반 * (2.6 - 0.22 * k), _투명(본, 0.022 * 세기))
		return
	# 천장틈 / 그을음: 들쭉날쭉한 틈 자국(빛줄기에 수직으로 벌어진 금)
	var 틈 := PackedVector2Array()
	var 폭 := 반 * 1.5
	for i in 9:
		var t := float(i) / 8.0
		var 흔들 := (fposmod(sin(float(i) * 91.7) * 1000.0, 1.0) - 0.5) * 6.0
		틈.append(수직 * lerpf(-폭, 폭, t) + 방향 * (-2.0 + 흔들))
	for i in range(8, -1, -1):
		var t := float(i) / 8.0
		var 깊이 := 5.0 + 6.0 * sin(t * PI)
		틈.append(수직 * lerpf(-폭, 폭, t) + 방향 * 깊이)
	var 틈색 := Color(1.0, 1.0, 0.96, 0.85 * 세기) if 흰 else Color(0.0, 0.0, 0.0, 0.92)
	draw_colored_polygon(틈, 틈색)
	if not 흰:
		# 그을음: 틈 가장자리에 매달린 재 덩어리
		for i in 4:
			var x := lerpf(-폭 * 0.8, 폭 * 0.8, float(i) / 3.0)
			draw_circle(수직 * x + 방향 * (8.0 + 3.0 * sin(_시각 + i)), 3.0, Color(0, 0, 0, 0.85))


func _투명(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))
