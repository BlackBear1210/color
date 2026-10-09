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

# ============================================================================
# ★[2026-10-07 Claude] 창문 빛 다시 만들기 — 도형님 "빛이 지금은 기둥으로 보여.
#   광원이 창문 레이어에 맞게, 창틀에서 빛이 새어 나오는 느낌으로"
# ----------------------------------------------------------------------------
# 예전: 창문 아래쪽 한 점에서 폭 96px 직사각형 띠가 뻗었다 → 창문에 꽂힌 '기둥'.
# 지금: 참고 그림(Window Floor & Wall Shadow Basics)처럼 **창유리 전체가 빛 방향으로 쓸고 지나간 부피**가 빛이다.
#   · 빛 부피 = 유리 바깥틀 네 꼭짓점 + 두 가장자리 광선이 바닥에 닿은 점의 볼록 껍질.
#     판정(빔판정 Area2D)도 **같은 다각형** → 보이는 빛 = 죽는 범위(억울함 없음).
#     tools/쳅터1/기믹.py 의 빛줄기(근원 창문)가 같은 계산을 해서 시뮬·도면과 맞는다.
#   · 그림: 유리 칸이 빛나고 창틀·창살 가장자리로 빛이 샌다 · 공기 중엔 옅은 빛살과 먼지 ·
#     바닥(2.5D 목재 윗면)에는 창살로 갈라진 **창문 모양 빛**이 평행사변형으로 눕는다.
#   · 창문 원화(창문.png 256×384) 실측: 유리 칸 가로 86–113 / 118–141 / 144–171 · 세로 61–120 / 123–180 / 196–258 / 261–319.
#     빛 원점 = 창문 그림 (128,192) = 도안 원점(만들기.py 창문_가구 가 그 자리에 창문을 건다).
#   · 창문 그림이 근처에 없으면(반사빛길의 빛살처럼) 예전 직사각형 띠 그대로다.
# ============================================================================
const 유리 := Rect2(86, 61, 85, 258)               ## 창문 그림 안 유리 바깥틀(px)
const 유리_가로 := [Vector2(86, 113), Vector2(118, 141), Vector2(144, 171)]
const 유리_세로 := [Vector2(61, 120), Vector2(123, 180), Vector2(196, 258), Vector2(261, 319)]
const 창문_원점 := Vector2(128, 192)
const 창문_최대 := 2400.0                           ## 빛이 닿을 수 있는 최대 거리(px)
var _창문: Sprite2D
var _빛면 := PackedVector2Array()                  ## 빛 부피(노드 로컬, 볼록 다각형) = 판정 모양
var _바닥 := PackedVector2Array()                  ## [최소 가장자리 착지, 최대 가장자리 착지, 가운데 착지](로컬)
var _모서리 := PackedVector2Array()                ## 빛에 수직인 방향으로 [가장 바깥 두 유리 꼭짓점](로컬)


func _ready() -> void:
	super._ready()
	z_index = 20               # 지형·플레이어 위로 빛이 내려앉는다(연결구 전경 60 보다는 아래)
	_재질()
	if not Engine.is_editor_hint() and 근원 == 0:
		_창문_맞추기.call_deferred()


## 가장 가까운 창문 그림(배경/가구/창문*)을 찾아 빛 원점을 창문 그림 (128,192) 에 붙인다.
func _창문_맞추기() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var best := 140.0
	for node in scene.find_children("창문*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		var distance := global_position.distance_to(sprite.to_global(창문_원점))
		if distance < best:
			best = distance
			_창문 = sprite
	if _창문:
		_창문_갱신()


## 빛 부피 계산 — 빛에 수직인 방향으로 가장 바깥인 유리 꼭짓점 두 개에서 광선을 쏴 바닥을 찾는다.
##   움직이는 발판 등이 가리면 다음 물리 틱에 다시 계산하고, 바뀌었을 때만 판정 모양을 갈아 끼운다.
func _창문_갱신() -> void:
	if not is_instance_valid(_창문):
		return
	# 판정은 창문의 **원래 자리**(시차 전)에 고정 — 그림만 _창() 으로 움직이는 창문을 따라간다.
	global_position = _창문.get_parent().to_global(_창문_원래() + 창문_원점)
	var 방향 := Vector2.RIGHT.rotated(deg_to_rad(각도))
	var 수직 := 방향.orthogonal()
	var 꼭짓점 := PackedVector2Array()
	for c in [유리.position, Vector2(유리.end.x, 유리.position.y), 유리.end, Vector2(유리.position.x, 유리.end.y)]:
		꼭짓점.append(_창_고정(c))
	var 최소 := 꼭짓점[0]
	var 최대 := 꼭짓점[0]
	for c in 꼭짓점:
		if c.dot(수직) < 최소.dot(수직):
			최소 = c
		if c.dot(수직) > 최대.dot(수직):
			최대 = c
	var 착지 := PackedVector2Array()
	for 시작 in [최소, 최대, (최소 + 최대) * 0.5]:
		착지.append(_광선(시작, 방향))
	var 점들 := 꼭짓점.duplicate()
	점들.append(착지[0])
	점들.append(착지[1])
	var 껍질 := Geometry2D.convex_hull(점들)
	if 껍질.size() > 1 and 껍질[0].is_equal_approx(껍질[-1]):
		껍질.remove_at(껍질.size() - 1)
	var 바뀜 := 껍질.size() != _빛면.size()
	if not 바뀜:
		for i in 껍질.size():
			if 껍질[i].distance_squared_to(_빛면[i]) > 0.25:
				바뀜 = true
				break
	_모서리 = PackedVector2Array([최소, 최대])
	_바닥 = 착지
	if 바뀜:
		_빛면 = 껍질
		_재구성()


## 로컬 점에서 방향으로 지형(레이어 1)까지 — 플레이어는 빛을 가리지 않는다.
func _광선(시작: Vector2, 방향: Vector2) -> Vector2:
	var g := to_global(시작)
	var q := PhysicsRayQueryParameters2D.create(g, g + 방향 * 창문_최대, 1)
	var player := get_tree().current_scene.get_node_or_null("Player") as CollisionObject2D
	if player:
		q.exclude = [player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return to_local(hit.position) if not hit.is_empty() else 시작 + 방향 * 창문_최대


## 창문 모드면 판정 모양 = 빛 부피 다각형. 아니면 부모(색레이저)의 직사각형 띠.
##   (길이·두께·각도 setter 가 이 함수를 부른다 — 창문 모드에서는 띠로 되돌아가지 않게 막는다)
func _재구성() -> void:
	if _창문 == null or _빛면.size() < 3:
		super._재구성()
		return
	if _영역 == null:
		super._재구성()
	var cs := _영역.get_node_or_null("모양") as CollisionShape2D
	if cs == null:
		super._재구성()
		cs = _영역.get_node_or_null("모양") as CollisionShape2D
	var 모양 := cs.shape as ConvexPolygonShape2D
	if 모양 == null:
		모양 = ConvexPolygonShape2D.new()
		cs.shape = 모양
	모양.points = _빛면
	_영역.rotation = 0.0
	cs.position = Vector2.ZERO
	queue_redraw()


## 지금(시차로 움직인) 창문 그림 위의 점 → 노드 로컬. 그림용.
func _창(p: Vector2) -> Vector2:
	return to_local(_창문.to_global(p))


## 시차 전 원래 자리의 창문 그림 위의 점 → 노드 로컬. 판정용(시뮬 기믹.py 와 같은 자리).
##   창문 그림은 회전·크기 없이 centered=false 로 걸린다(만들기.py) — 부모 변환 + 자리만 쓰면 된다.
func _창_고정(p: Vector2) -> Vector2:
	return to_local(_창문.get_parent().to_global(_창문_원래() + p))


func _창문_원래() -> Vector2:
	return _창문.get_meta("parallax_rest", _창문.position)


## [2026-10-09] 그을음(몹)을 태우는 빛인가 — 근원이 '그을음'(검은 그을음 줄기)이면 빛이 아니다.
##   창문 달빛·천장 틈 빛만 태운다(색레이저.빛_안인가 의 판정 모양을 그대로 쓴다).
func 빛_안인가(월드점: Vector2) -> bool:
	if 근원 == 2:
		return false
	return super.빛_안인가(월드점)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _창문:
		_창문_갱신()


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
	if _창문 and _빛면.size() >= 3:
		_창문빛_그리기(방향, 수직, 흰, 본, 세기)      # [2026-10-07] 창문 모드 — 파일 끝 함수
		return
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


# ============================================================================
# [2026-10-07 Claude] 창문 모드 그림
#   ① 창 — 유리 칸이 빛나고 창틀·창살 가장자리로 빛이 샌다(창틀 바깥으로 번지는 빛무리)
#   ② 빛 부피 — 판정 다각형 그대로, 창 쪽은 밝고 바닥 쪽은 옅게(꼭짓점 색 보간)
#   ③ 빛살 — 부피 안 가는 줄기들이 천천히 숨 쉰다 · 창살 그림자 줄이 창 가까이에서 이어진다
#   ④ 바닥 무늬 — 목재 윗면(충돌선 −4…18px, 2.5D)에 창살로 갈라진 창문 모양이 평행사변형으로 눕는다
#   ⑤ 먼지 — 부피 안에서 천천히 떠다닌다
# ============================================================================
func _창문빛_그리기(방향: Vector2, 수직: Vector2, 흰: bool, 본: Color, 세기: float) -> void:
	var 숨 := 0.94 + 0.06 * sin(_시각 * 0.9)
	var 창세기 := maxf(세기, 0.2)          # 꺼져도(구름) 창은 희미하게 남는다
	var 유리사각 := Rect2(_창(유리.position), _창(유리.end) - _창(유리.position))
	# ── ① 창: 창틀 밖으로 번지는 빛무리 → 유리 칸 → 칸 가장자리로 새는 빛 → 창틀 테 ──
	for k in range(6, 0, -1):
		draw_rect(유리사각.grow(4.0 + k * 6.0), _투명(본, 0.03 * 창세기 * 숨))   # 창틀 밖으로 번지는 빛무리
	for gx: Vector2 in 유리_가로:
		for gy: Vector2 in 유리_세로:
			var a := _창(Vector2(gx.x, gy.x))
			var b := _창(Vector2(gx.y, gy.y))
			draw_rect(Rect2(a, b - a), _투명(본, 0.20 * 창세기 * 숨))
			draw_rect(Rect2(a, b - a).grow(1.5), _투명(본, 0.16 * 창세기), false, 1.5)
	draw_rect(유리사각.grow(3.0), _투명(본, 0.34 * 창세기 * 숨), false, 2.0)
	# 창틀과 벽 사이 틈으로 새는 빛 — 바깥틀 둘레를 따라 가늘고 밝게(위·옆은 짧게 번짐)
	for k in 3:
		draw_rect(유리사각.grow(9.0 + k * 3.0), _투명(본, (0.10 - 0.03 * k) * 창세기 * 숨), false, 1.5)
	if 세기 <= 0.01 or _모서리.size() < 2 or _바닥.size() < 3:
		return
	# ── ② 빛 부피: 지금 창문 꼭짓점 + 고정된 바닥 착지점 — 위는 창문을 따라 살짝 기울고 바닥은 그대로 ──
	var 지금 := PackedVector2Array()
	for c in [유리.position, Vector2(유리.end.x, 유리.position.y), 유리.end, Vector2(유리.position.x, 유리.end.y)]:
		지금.append(_창(c))
	var 모서리 := PackedVector2Array([지금[0], 지금[0]])
	for c in 지금:
		if c.dot(수직) < 모서리[0].dot(수직):
			모서리[0] = c
		if c.dot(수직) > 모서리[1].dot(수직):
			모서리[1] = c
	var 보이는 := 지금.duplicate()
	보이는.append(_바닥[0])
	보이는.append(_바닥[1])
	보이는 = Geometry2D.convex_hull(보이는)
	if 보이는.size() > 1 and 보이는[0].is_equal_approx(보이는[-1]):
		보이는.remove_at(보이는.size() - 1)
	var 창중심 := 유리사각.get_center()
	var 멀리 := 1.0
	for p in 보이는:
		멀리 = maxf(멀리, (p - 창중심).dot(방향))
	var 색들 := PackedColorArray()
	for p in 보이는:
		var u := clampf((p - 창중심).dot(방향) / 멀리, 0.0, 1.0)
		색들.append(_투명(본, lerpf(0.16, 0.05, u) * 세기 * 숨))
	draw_polygon(보이는, 색들)
	# 판정 경계가 읽히도록 가장자리 두 광선에 아주 옅은 선
	draw_line(모서리[0], _바닥[0], _투명(본, 0.10 * 세기), 1.5, true)
	draw_line(모서리[1], _바닥[1], _투명(본, 0.10 * 세기), 1.5, true)
	# ── ③ 빛살 + 창살 그림자 ──
	for k in 9:
		var f := (float(k) + 0.5) / 9.0
		var 시작 := 모서리[0].lerp(모서리[1], f)
		var 끝 := _바닥[0].lerp(_바닥[1], f)
		var 굵기 := lerpf(4.0, 14.0, fposmod(sin(k * 7.13) * 91.7, 1.0))
		var a := (0.035 + 0.035 * sin(_시각 * (0.25 + 0.07 * k) + k * 1.9)) * 세기
		draw_line(시작, 끝, _투명(본, maxf(a, 0.0)), 굵기, true)
	var 그림자 := Color(0, 0, 0, 0.10 * 세기) if 흰 else Color(1, 1, 1, 0.06 * 세기)
	for x in [115.5, 142.5]:
		for y in [유리.position.y, 유리.end.y]:
			var p := _창(Vector2(x, y))
			draw_line(p, p + 방향 * 멀리 * 0.45, 그림자, 3.0, true)
	var 가로대 := _창(Vector2(유리.position.x, 188.0))
	var 가로대2 := _창(Vector2(유리.end.x, 188.0))
	var 그림자0 := Color(그림자.r, 그림자.g, 그림자.b, 0.0)
	draw_polygon(PackedVector2Array([가로대, 가로대2, 가로대2 + 방향 * 멀리 * 0.35, 가로대 + 방향 * 멀리 * 0.35]),
		PackedColorArray([그림자, 그림자, 그림자0, 그림자0]))
	# ── ④ 바닥 무늬 ──
	if 방향.y > 0.2:
		_바닥무늬(방향, 본, 세기)
	# ── ⑤ 먼지 ──
	for n in 알갱이:
		var h := fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(n) * 78.233) * 12543.137, 1.0)
		var u := fposmod(h + _시각 * (0.02 + 0.03 * h2), 1.0)
		var 시작 := 모서리[0].lerp(모서리[1], h2)
		var 끝 := _바닥[0].lerp(_바닥[1], h2)
		var 점 := 시작.lerp(끝, u) + 수직 * sin(_시각 * (0.6 + h) + n) * 4.0
		var 반짝 := 0.5 + 0.5 * sin(_시각 * (1.6 + 2.0 * h) + n * 1.7)
		var 끝흐림 := clampf(minf(u, 1.0 - u) * 8.0, 0.0, 1.0)
		draw_circle(점, 1.0 + 1.4 * h2, _투명(Color(1, 1, 1) if 흰 else Color(0, 0, 0), (0.2 + 0.5 * 반짝) * 세기 * 끝흐림))


## 바닥(목재 윗면) 위 창문 모양 빛 — 참고 그림 'floor projection, sun angled' 를 2.5D 상판에 눕혔다.
##   가로(창 칸 3 열) = 두 가장자리 광선이 바닥 높이에서 만드는 폭 · 깊이(창 칸 4 줄) = 상판 −4…18px
##   (아래 칸 = 벽 쪽 뒤, 위 칸 = 앞) · 깊이로 갈수록 빛 방향만큼 옆으로 밀린다(평행사변형).
func _바닥무늬(방향: Vector2, 본: Color, 세기: float) -> void:
	var y := _바닥[2].y                       # 가운데 광선이 닿은 바닥(충돌선)
	var x0 := _모서리[0].x + (y - _모서리[0].y) * 방향.x / 방향.y
	var x1 := _모서리[1].x + (y - _모서리[1].y) * 방향.x / 방향.y
	if x1 < x0:
		var t := x0
		x0 = x1
		x1 = t
	var 폭 := x1 - x0
	if 폭 < 8.0:
		return
	var 밀림 := 22.0 * 방향.x / 방향.y          # 깊이 22px 를 지나는 동안 옆으로 밀리는 양
	# 바닥 위 장애물(계단 블록 등)에 막히는 곳까지만 — 가운데 착지점에서 바닥 바로 위를 좌우로 쏴 본다
	var 왼끝 := x0 - 60.0
	var 오른끝 := x1 + 밀림 + 60.0
	var 바닥가운데 := to_global(Vector2(_바닥[2].x, y - 6.0))
	for 쪽 in [-1.0, 1.0]:
		var q := PhysicsRayQueryParameters2D.create(바닥가운데, 바닥가운데 + Vector2(쪽 * (폭 + 140.0), 0), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			if 쪽 < 0.0:
				왼끝 = to_local(hit.position).x
			else:
				오른끝 = to_local(hit.position).x
	var 자르개 := PackedVector2Array([Vector2(왼끝, y - 40.0), Vector2(오른끝, y - 40.0), Vector2(오른끝, y + 40.0), Vector2(왼끝, y + 40.0)])
	for k in range(5, 0, -1):
		var 퍼짐 := k * 10.0
		_잘라그리기(자르개, PackedVector2Array([
			Vector2(x0 - 퍼짐, y - 4.0), Vector2(x1 + 퍼짐, y - 4.0),
			Vector2(x1 + 밀림 + 퍼짐, y + 18.0), Vector2(x0 + 밀림 - 퍼짐, y + 18.0)]), _투명(본, 0.035 * 세기))
	for gx: Vector2 in 유리_가로:
		var u0 := (gx.x - 유리.position.x) / 유리.size.x
		var u1 := (gx.y - 유리.position.x) / 유리.size.x
		for gy: Vector2 in 유리_세로:
			# 위 칸일수록 앞(깊이 1), 아래 칸일수록 벽 쪽(깊이 0)
			var d0 := 1.0 - (gy.y - 유리.position.y) / 유리.size.y
			var d1 := 1.0 - (gy.x - 유리.position.y) / 유리.size.y
			var q := PackedVector2Array()
			for c in [Vector2(u0, d0), Vector2(u1, d0), Vector2(u1, d1), Vector2(u0, d1)]:
				q.append(Vector2(x0 + 폭 * c.x + 밀림 * c.y, y - 4.0 + 22.0 * c.y))
			_잘라그리기(자르개, q, _투명(본, 0.42 * 세기))
	# 앞 단면(상판 앞 8px)에 살짝 흘러내린 빛
	_잘라그리기(자르개, PackedVector2Array([
		Vector2(x0 + 밀림, y + 18.0), Vector2(x1 + 밀림, y + 18.0),
		Vector2(x1 + 밀림, y + 26.0), Vector2(x0 + 밀림, y + 26.0)]), _투명(본, 0.12 * 세기))


## [2026-10-07] 바닥 무늬를 장애물 사이(자르개)로 잘라 그린다 — 계단 블록 앞면에 빛 무늬가 올라타지 않게.
func _잘라그리기(자르개: PackedVector2Array, 다각형: PackedVector2Array, 색: Color) -> void:
	# 둘 다 볼록이라 교집합에 구멍이 생기지 않는다 → 나온 조각을 그대로 그린다
	for 조각 in Geometry2D.intersect_polygons(다각형, 자르개):
		if 조각.size() >= 3:
			draw_colored_polygon(조각, 색)

