@tool
extends Area2D
## ============================================================================
## [2026-08-06 신규] 도약대 — 밟으면 위로 튀어 오르는 버섯형 발판
## ----------------------------------------------------------------------------
## ▣ 왜 이 게임에 필요한가
##   낙하 사망(`낙하_감시.gd`)을 넣으면서 **아래로 가는 길은 위험**해졌다.
##   그런데 위로 가는 수단이 점프 하나뿐이면 레벨이 옆으로만 길어진다.
##   도약대가 있으면 레인월드처럼 **수직으로 쌓인 방**을 만들 수 있고,
##   "내려갈 땐 계단, 올라갈 땐 도약대" 라는 왕복 동선이 생긴다.
##
## ▣ 낙하 사망과의 관계 (설계 의도)
##   도약대로 튀어 오른 뒤 그대로 떨어지면, 낙하 감시는 **튄 꼭대기**부터 거리를 센다.
##   그래서 세기(`도약속도`)를 치명 거리(520px)보다 크게 잡으면
##   **받아줄 발판이 없는 도약대는 그 자체로 자살 장치**가 된다.
##   → 기본값은 상승 418px 로 잡아 그 아래에 뒀다. 더 세게 만들 거면
##      반드시 위에 받아줄 발판을 두고 `tools/레벨검사.gd` 로 확인할 것.
##
## ▣ 기본값 −1500 이 왜 418px 인가 (실제 플레이어 수치로 역산)
##   스마트월드 플레이어 세팅: 점프_높이_칸 10 · 타일 16px · 상승_배수 4.563 · move_speed 390
##     gravity      = 2·160·390²·k² / 320²  ≈ 589.4      (k = 1/√4.563 + 1/√2.4)
##     상승 중력    = 589.4 × 4.563          ≈ 2689
##     상승 높이    = v² / (2 × 2689)
##   → v = 1500 이면 1500² / 5379 ≈ 418px = 점프 높이(160px)의 2.6 배.
##   플레이어 점프 세팅을 바꾸면 이 값도 달라진다. `tools/레벨검사.gd` 가 실제로 계산해 준다.
##
## ▣ 색 규칙
##   기본은 무색(누구나 사용 가능)이다. `색_제한` 을 켜면 같은 색일 때만 튕겨 올리고
##   반대색이면 그냥 딱딱한 발판처럼 군다 — 색 전환을 강제하는 퍼즐 부품이 된다.
##   (사망 판정은 하지 않는다. 여기서 죽이면 "왜 죽었는지" 읽히지 않는다)
## ============================================================================
class_name 도약대

@export_range(60, 400) var 폭: float = 150.0:
	set(v): 폭 = v; _재구성()
@export_range(20, 120) var 높이: float = 46.0:
	set(v): 높이 = v; _재구성()

## 튕겨 올리는 속도(px/s). 음수가 위쪽이다.
## 상승 높이 ≈ 속도² / (2 × 상승중력). 위 주석의 역산 참고 — 기본값은 약 418px.
@export var 도약속도: float = -1500.0

## 켜면 플레이어 색과 이 도약대 색이 같을 때만 튕긴다.
@export var 색_제한: bool = false
## 색_제한 이 켜졌을 때의 도약대 색.
@export var 색: int = ColorDefs.BLACK

var _눌림: float = 0.0        ## 밟힌 직후 납작해지는 연출용 (0~1)
var _쿨: float = 0.0          ## 연속 발동 방지


func _ready() -> void:
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("도약대")
	collision_layer = 0
	collision_mask = 1          # 플레이어만 본다
	monitoring = true
	set_physics_process(true)
	set_process(true)


func _재구성() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("판정") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "판정"
		cs.visible = false
		add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	# 판정은 갓 위쪽 얇은 띠 — 옆에서 부딪혀도 튀지 않게 한다
	r.size = Vector2(폭 * 0.92, 높이 * 0.7)
	cs.position = Vector2(0, -높이 * 0.65)

	# 밟고 설 수 있는 실제 바닥 (Area2D 는 밀어내지 못한다)
	var 바디 := get_node_or_null("발판") as StaticBody2D
	if 바디 == null:
		바디 = StaticBody2D.new()
		바디.name = "발판"
		add_child(바디)
		if Engine.is_editor_hint() and owner:
			바디.owner = owner
	바디.collision_layer = 1
	바디.collision_mask = 0
	var bcs := 바디.get_node_or_null("모양") as CollisionShape2D
	if bcs == null:
		bcs = CollisionShape2D.new()
		bcs.name = "모양"
		bcs.visible = false
		바디.add_child(bcs)
		if Engine.is_editor_hint() and owner:
			bcs.owner = owner
	var br := bcs.shape as RectangleShape2D
	if br == null:
		br = RectangleShape2D.new()
		bcs.shape = br
	br.size = Vector2(폭, 높이 * 0.5)
	bcs.position = Vector2(0, -높이 * 0.25)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_쿨 = maxf(_쿨 - delta, 0.0)
	if _쿨 > 0.0:
		return
	for 몸 in get_overlapping_bodies():
		var p := 몸 as CharacterBody2D
		if p == null:
			continue
		# 위에서 내려오는 중일 때만 (아래에서 머리로 받으면 안 튄다)
		var v: Vector2 = p.velocity
		if v.y < -10.0:
			continue
		if 색_제한 and int(p.get("player_color")) != 색:
			continue
		v.y = 도약속도
		p.velocity = v
		_눌림 = 1.0
		_쿨 = 0.18
		break


func _process(delta: float) -> void:
	if _눌림 > 0.0:
		# 납작해졌다 되돌아오는 탄성 — 0.35 초에 걸쳐 회복
		_눌림 = maxf(_눌림 - delta / 0.35, 0.0)
		queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var w := 폭
	var h := 높이 * (1.0 - _눌림 * 0.55)     # 밟히면 납작해진다
	# 갓 — 반원. 위로 튄다는 게 실루엣만으로 읽혀야 한다.
	var 갓 := PackedVector2Array()
	var n := 20
	for i in n + 1:
		var a := PI * float(i) / float(n)
		갓.append(Vector2(-cos(a) * w * 0.5, -sin(a) * h))
	갓.append(Vector2(w * 0.5, 0))
	갓.append(Vector2(-w * 0.5, 0))

	var 본색 := Color(0.10, 0.10, 0.11)
	if 색_제한:
		본색 = Color(0.90, 0.90, 0.92) if 색 == ColorDefs.WHITE else Color(0.07, 0.07, 0.08)
	draw_colored_polygon(갓, 본색)
	draw_polyline(갓, Color(0.72, 0.72, 0.75, 0.9), 2.5, true)

	# 위로 향한 갈매기 표시 3 개 — "여기서 튄다"는 안내
	for i in 3:
		var y := -h - 14.0 - float(i) * 13.0
		var a := 0.55 - float(i) * 0.14 + _눌림 * 0.4
		draw_polyline(PackedVector2Array([
			Vector2(-16, y + 9), Vector2(0, y), Vector2(16, y + 9),
		]), Color(0.85, 0.85, 0.88, a), 3.0)
