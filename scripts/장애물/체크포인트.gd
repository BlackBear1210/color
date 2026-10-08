@tool
extends Area2D

## ⚠ class_name 대신 **경로 preload** — 헤드리스에서 전역 클래스 이름이 아직 없을 수 있다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")
## ============================================================================
## 🏮 체크포인트 = 잉크 등불 (Ink Lantern)  —  [2026-07-25 재디자인]
## ----------------------------------------------------------------------------
## 지나가면 부활 지점이 여기로 바뀐다. **그 순간의 플레이어 색도 같이 기억**한다.
##
## ▣ 왜 다시 만들었나
##   구 버전은 "깃대 + 삼각 깃발"이었다. 도형님 지적대로 이 게임 톤과 전혀 안 맞았다 —
##   깃발은 레이싱/플랫포머의 UI 기호지, LIMBO 계열 세계의 사물이 아니다.
##   → **꺼져 있던 등불에 불이 들어오는 것**으로 바꿨다.
##     · 이 게임의 세계는 어둡고, 빛은 이미 핵심 문법이다(가로등·발광 구슬·물 반사).
##       체크포인트가 광원이 되면 **기능과 분위기가 같은 언어를 쓴다.**
##     · "여기서부터 안전하다"를 UI 아이콘이 아니라 **화면이 밝아지는 것**으로 알린다.
##     · 지나온 길을 돌아보면 켜둔 등불이 줄줄이 보인다 = 진행 기록이 세계 안에 남는다.
##
## ▣ 쓰는 법
##   scenes/장애물/체크포인트.tscn 을 안전한 발판 위에 드래그. 그게 전부다.
##   `stage_lab.gd` 가 `checkpoint` 그룹을 자동으로 찾아 연결한다.
##
## ▣ 색을 같이 기억하는 이유 (7/14 에 실제로 겪은 사고)
##   반대색인 채로 부활하면 부활하자마자 발밑 발판에 죽어 **무한 사망 루프**가 된다.
## ============================================================================

const PROPS := "res://assets/textures/props/"
const FLICKER := "res://scripts/proto/light_flicker.gd"

@export_range(16, 200) var 감지폭: int = 56:
	set(v): 감지폭 = v; _재구성()
@export_range(16, 300) var 감지높이: int = 110:
	set(v): 감지높이 = v; _재구성()
## 등불이 걸린 높이(px). 0 이면 바닥에 세운다.
@export_range(0, 200) var 걸이높이: int = 0:
	set(v): 걸이높이 = v; _재구성()

var 활성: bool = false
var _펄스: float = 0.0
var _등불: Sprite2D
var _light: PointLight2D
var _촛불형: bool = false
var _촛불시트: Texture2D
var _표시시간: float = 0.0
var _시각: float = 0.0
## ★[2026-10-07 Claude] 촛불등이 공중에 떠 보이던 것 고침(도형님: "지형 타일셋 위에 올라간 느낌이 나야 하는데 공중에 떠 있다").
##   원인 ① 원화 아래 투명 여백 45px(화면 ≈7px) ② 목재 상판은 충돌선 기준 −4…18px 로 그려지는데(2.5D 윗면)
##   등 발을 충돌선 = 윗면 **뒤 모서리**에 맞췄다 ③ 접지 그림자가 없었다.
##   → 그림은 불투명 영역만 잘라 쓰고, 발밑 지형을 찾아 **플레이어와 같은 서는 면**(목재 발_그림_깊이 +7px)에 세우며,
##     발밑에 접지 그림자(켜지면 따뜻한 빛 웅덩이)를 깐다. 판정 영역·저장 위치는 그대로다.
## ★[2026-10-07 Claude] 촛불등 빛 = 은은한 광원(도형님: "지금은 에너지파가 나가는 것 같다.
##   촛대에 불을 켜면 은은하게 밝아지고, 시간이 지나거나 다음 체크포인트로 넘어가면 빛을 좀 잃게").
##   · 퍼지는 고리·눈금(에너지파)을 없애고, 빛 세기 하나(_밝기 0~1)로 광원·후광·바닥 빛 웅덩이·등 밝기를 함께 움직인다.
##   · 켜짐 → 1.0 으로 천천히 차오름(약 1.5초) · 켜진 뒤 밝음_유지 초가 지나면 은은함(0.6) ·
##     다른 체크포인트가 켜지면 남은 불씨(0.35). 예전 체크포인트로 돌아와 다시 저장하면 다시 밝아진다.
##   · 하수도 등불(촛불형 아님)은 예전 연출 그대로.
const 밝음_유지 := 12.0           ## 켜진 뒤 가장 밝게 있는 시간(초)
const 은은함 := 0.6               ## 시간이 지난 뒤 밝기
const 남은불씨 := 0.35            ## 다음 체크포인트가 켜진 뒤 밝기
var _밝기: float = 0.0            ## 지금 빛 세기(0~1) — 그림·광원이 모두 이 값을 따른다
var _목표밝기: float = 0.0
var _켜진시간: float = 0.0
var _발깊이: float = 0.0          ## 노드 원점 → 그림상 서는 면까지(px, 아래 +)
var _바닥: Node2D                 ## 접지 그림자·빛 웅덩이(등 뒤 z)
## 촛불 원화(candle_states.png 1536×1024)에서 불투명한 부분만 — 두 상태가 같은 칸 안에 같은 크기로 있다.
##   알파 실측: 꺼짐 열 89~505·행 35~915 / 켜짐 열 83~506·행 35~916 (각 칸 x 176 / 824, y 32 기준)
const 촛불_칸_x := [176, 824]     ## [꺼짐, 켜짐]
const 촛불_자르기 := Rect2(80, 35, 432, 882)
const 촛불_높이 := 132.0          ## 화면 높이(px) — 몸(97px)보다 조금 큰 가구

## 쳅터1만 가구형으로 바꿔 하수도에서 사용 중인 기존 등불 외형은 보존한다.
func _집_체크인가() -> bool:
	var n: Node = self
	while n:
		if n.scene_file_path.contains("/쳅터1/"):
			return true
		n = n.get_parent()
	return false

func _ready() -> void:
	_촛불형 = _집_체크인가()
	if _촛불형:
		_촛불시트 = load("res://assets/textures/props/chapter1_checkpoint/candle_states.png")
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_재구성()
	if _촛불형 and not Engine.is_editor_hint():
		_바닥_맞추기.call_deferred()


## [2026-10-07] 발밑 지형을 물리로 찾아 그림상 서는 면에 맞춘다(충돌·판정 위치는 그대로).
##   지형이 `발_그림_깊이()` 를 주면(목재 = +7px, 상판 −4…18 의 가운데) 플레이어 발 그림과 같은 높이가 된다.
##   찾지 못하면(공중에 둔 등 · 매단 등) 0 — 원래처럼 노드 원점에 선다.
func _바닥_맞추기() -> void:
	if 걸이높이 > 0 or not is_inside_tree():
		return
	await get_tree().physics_frame
	var 공간 := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -24), global_position + Vector2(0, 96), 1)
	q.collide_with_areas = false
	var r := 공간.intersect_ray(q)
	if r.is_empty():
		return
	var 면 := r["collider"] as Node
	while 면 and not 면.has_method("발_그림_깊이"):
		면 = 면.get_parent()
	var 깊이 := float(면.call("발_그림_깊이")) if 면 else 0.0
	_발깊이 = (Vector2(r["position"]).y - global_position.y) / maxf(absf(global_scale.y), 0.0001) + 깊이
	_재구성()

func _재구성() -> void:
	if not is_inside_tree():
		return
	# ── 판정 영역 ──
	var cs := get_node_or_null("충돌") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "충돌"
		add_child(cs)
	var sh := cs.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		cs.shape = sh
	sh.size = Vector2(감지폭, 감지높이)
	cs.position = Vector2(0, -감지높이 * 0.5)

	# ── 등불 일러스트 ──
	if _등불 == null:
		_등불 = get_node_or_null("등불") as Sprite2D
	if _등불 == null and ResourceLoader.exists(PROPS + "lantern.svg"):
		_등불 = Sprite2D.new()
		_등불.name = "등불"
		_등불.texture = load(PROPS + "lantern.svg")
		_등불.centered = false
		add_child(_등불)
	if _등불:
		if _촛불형 and _촛불시트:
			_촛불_그림()                    # 위치까지 정한다(서는 면 = _발깊이)
			queue_redraw()
		else:
			_등불.scale = Vector2.ONE
			_등불.modulate = Color(0.30, 0.30, 0.32)
			var t: Texture2D = _등불.texture
			# 바닥에 세우면 아랫변이 지면에, 걸이높이가 있으면 그만큼 매단다
			_등불.position = Vector2(-t.get_width() * _등불.scale.x * 0.5,
				-t.get_height() * _등불.scale.y - float(걸이높이))
		# 플레이어 뒤 (지나갈 때 안 가림).
		# [2026-10-07] 촛불등은 z 0 — 목재 상판 덮개(z 0, 씬에서 먼저 그려짐) **위**, 플레이어(z 0, 나중) **아래**.
		#   예전 z −1 이면 상판이 등 받침을 덮어 발이 잘려 '상판 뒤에 떠 있는' 것처럼 보였다.
		_등불.z_index = 0 if _촛불형 else -1
	# [2026-10-07] 접지 그림자 — 등(z −1) 보다 뒤, 목재 상판 위에 깔린다
	if _촛불형 and 걸이높이 == 0:
		if _바닥 == null:
			_바닥 = Node2D.new()
			_바닥.name = "접지그림자"
			_바닥.z_index = 0                # 상판 위(같은 z, 씬 순서가 뒤) · 등보다 먼저(맨 앞 자식)
			_바닥.draw.connect(_바닥_그리기)
			add_child(_바닥)
			move_child(_바닥, 0)
		_바닥.queue_redraw()

	# ── 광원 (꺼진 상태로 시작) ──
	if _light == null:
		_light = get_node_or_null("등불광원") as PointLight2D
	if _light == null:
		_light = PointLight2D.new()
		_light.name = "등불광원"
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 256
		tex.height = 256
		_light.texture = tex
		_light.texture_scale = 360.0 / 256.0
		_light.color = Color(1.0, 0.90, 0.70)
		_light.energy = 0.0                 # 꺼짐
		# ★[2026-09-05] 조명 표준 — height 128 · ADD. energy 는 켜기/끄기가 굴리므로 안 건드린다.
		조명표준.적용(_light)
		add_child(_light)
	_light.position = Vector2(0, -44.0 - float(걸이높이) + _발깊이)
	queue_redraw()

## stage_lab 이 체크포인트 통과 시 호출한다.
func 켜기() -> void:
	if _촛불형 and not Engine.is_editor_hint():
		_촛불_켜기()
		return
	if 활성:
		return
	활성 = true
	_펄스 = 1.0
	_표시시간 = 2.2
	if _등불:
		if _촛불형:
			_촛불_그림()
		var t1 := create_tween()
		t1.tween_property(_등불, "modulate", Color(0.95, 0.93, 0.88), 0.35)
	if _light:
		# 불이 확 붙었다가 안정되는 2단 트윈 — "성냥에 불이 옮겨붙는" 리듬
		var t2 := create_tween()
		t2.tween_property(_light, "energy", 1.6, 0.14).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(_light, "energy", 1.05, 0.45).set_trans(Tween.TRANS_SINE)
		t2.tween_callback(func() -> void:
			# 안정된 뒤부터 촛불처럼 미세하게 흔들린다
			if is_instance_valid(_light) and ResourceLoader.exists(FLICKER):
				_light.set_script(load(FLICKER)))
	queue_redraw()

## [2026-10-07] 촛불형 켜기 — 월드가 '여기를 저장했다' 때 부른다(예전 체크포인트로 돌아와 다시 저장할 때도).
func _촛불_켜기() -> void:
	var 처음 := not 활성
	활성 = true
	_펄스 = 0.0                   # 퍼지는 고리(에너지파)는 쓰지 않는다
	_표시시간 = 2.2
	_켜진시간 = 0.0
	_목표밝기 = 1.0
	if 처음 and _등불:
		_촛불_그림()               # 불 켜진 그림으로
	# 다른 촛불등은 빛을 조금 잃는다 — 지나온 길에 남은 불씨가 줄지어 보인다
	for n in get_tree().get_nodes_in_group("checkpoint"):
		if n != self and n.has_method("빛_물러나기"):
			n.call("빛_물러나기")
	queue_redraw()


## 다른 체크포인트가 켜졌을 때 — 꺼지지는 않고 남은 불씨로.
func 빛_물러나기() -> void:
	if 활성 and _촛불형:
		_목표밝기 = minf(_목표밝기, 남은불씨)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_시각 += delta
	_표시시간 = maxf(0.0, _표시시간 - delta)
	if _촛불형 and 활성:
		# 시간이 지나면 은은하게 — 가장 밝은 시간을 지나면 목표를 낮춘다(이미 불씨면 그대로)
		_켜진시간 += delta
		if _켜진시간 > 밝음_유지 and _목표밝기 > 은은함:
			_목표밝기 = 은은함
		# 오를 때는 천천히 차오르고(촛불이 자리 잡는 느낌), 내릴 때는 더 천천히
		var 속도 := 0.7 if _목표밝기 > _밝기 else 0.12
		_밝기 = move_toward(_밝기, _목표밝기, delta * 속도)
		var 일렁 := 0.96 + 0.025 * sin(_시각 * 5.3) + 0.015 * sin(_시각 * 13.1 + 1.7)
		if _light:
			_light.energy = 1.15 * smoothstep(0.0, 1.0, _밝기) * 일렁
		if _등불:
			var v := lerpf(0.78, 1.0, _밝기)
			_등불.modulate = Color(v, v * 0.99, v * 0.96)
	if _촛불형:
		# 지속되는 불꽃·후광과 짧은 저장 문구가 점화 여부를 링이 사라진 뒤에도 알려 준다.
		queue_redraw()
		if _바닥 and 활성:
			_바닥.queue_redraw()          # 빛 웅덩이가 불꽃과 같이 숨 쉰다
	if _펄스 > 0.0:
		_펄스 = maxf(_펄스 - delta * 1.1, 0.0)
		queue_redraw()

func _draw() -> void:
	var y := -44.0 - float(걸이높이)
	if _촛불형:
		_촛불_효과(Vector2(0, -62.0 - float(걸이높이) + _발깊이))
		return
	# 매달린 경우 천장까지 이어지는 줄
	if 걸이높이 > 0:
		draw_line(Vector2(0, y - 44.0), Vector2(0, y - 44.0 - float(걸이높이)),
			Color(0.10, 0.10, 0.10), 2.0)
	# 켜지는 순간의 확산 링 — "저장됐다"를 즉각 알리는 유일한 UI적 신호
	if _펄스 > 0.0:
		draw_arc(Vector2(0, y), 30.0 + (1.0 - _펄스) * 90.0, 0.0, TAU, 32,
			Color(1.0, 0.92, 0.75, _펄스 * 0.55), 2.5, true)
	# 꺼져 있을 때는 아주 흐린 윤곽만 — "저기 뭔가 있다" 정도로만 보이게
	elif not 활성:
		draw_arc(Vector2(0, y), 16.0, 0.0, TAU, 20,
			Color(0.55, 0.55, 0.58, 0.30), 1.5, true)


func _촛불_그림() -> void:
	# 동일 원화의 두 영역을 사용해 점화 순간 가구 크기/발 위치가 바뀌지 않는다.
	# [2026-10-07] 투명 여백을 잘라 낸 영역만 쓴다 → 그림의 아랫변 = 등 받침의 발.
	var atlas := AtlasTexture.new()
	atlas.atlas = _촛불시트
	atlas.region = Rect2(float(촛불_칸_x[1 if 활성 else 0]) + 촛불_자르기.position.x, 32.0 + 촛불_자르기.position.y,
		촛불_자르기.size.x, 촛불_자르기.size.y)
	_등불.texture = atlas
	var k := 촛불_높이 / 촛불_자르기.size.y
	_등불.scale = Vector2.ONE * k
	_등불.modulate = Color.WHITE
	# 받침 가운데(원화 x ≈ 297 → 자른 칸 217)를 노드 x 에, 발을 서는 면(_발깊이)에 둔다.
	# +2px: 받침 발이 상판 결 속으로 살짝 묻혀야 '놓여 있다'로 읽힌다(딱 붙이면 경계선이 떠 보인다).
	_등불.position = Vector2(-217.0 * k, -촛불_높이 - float(걸이높이) + _발깊이 + 2.0)


## [2026-10-07] 접지 그림자 + 켜졌을 때 상판에 번지는 빛 웅덩이.
##   상판은 2.5D 라 그림자도 납작한 타원(가로 : 세로 ≈ 5 : 1)이다. 빛이 왼 위에서 오므로 살짝 오른쪽으로 민다.
func _바닥_그리기() -> void:
	var c := Vector2(3.0, _발깊이 + 1.0)
	_바닥.draw_set_transform(c, 0.0, Vector2(1.0, 0.2))
	for i in range(6, 0, -1):
		_바닥.draw_circle(Vector2.ZERO, 30.0 + i * 5.0, Color(0, 0, 0, 0.12))
	_바닥.draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.5))
	if 활성:
		var 숨 := 0.95 + 0.05 * sin(_시각 * 3.1)
		for i in range(8, 0, -1):
			_바닥.draw_circle(Vector2(-3.0, 0), 40.0 + i * 16.0, Color(1.0, 0.94, 0.80, 0.035 * 숨 * _밝기))
	_바닥.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _촛불_효과(중심: Vector2) -> void:
	if 활성:
		# [2026-10-07] 은은한 후광 — 유리 갓 둘레에 부드럽게 번지고 밝기(_밝기)에 따라 커지고 옅어진다.
		var 숨 := 0.95 + 0.05 * sin(_시각 * 3.1)
		var 크기 := lerpf(0.75, 1.0, _밝기)
		for i in range(12, 0, -1):
			draw_circle(중심, i * 9.0 * 크기, Color(1, 0.95, 0.82, 0.011 * 숨 * _밝기))
		draw_circle(중심, 16.0, Color(1, 0.94, 0.78, 0.10 * 숨 * _밝기))
	if _펄스 > 0.0 and not _촛불형:
		# 220px 확산은 몸(97px) 전체를 감싸며 사라진다. 지형/색 판정에는 관여하지 않는다.
		var t := 1.0 - _펄스
		var 반경 := lerpf(18.0, 220.0, 1.0 - pow(1.0 - t, 3.0))
		for i in range(8, 0, -1):
			draw_circle(중심, 반경 * i / 8.0, Color(1, 0.96, 0.87, 0.018 * _펄스))
		draw_arc(중심, 반경, 0, TAU, 96, Color(1, 0.97, 0.88, _펄스 * 0.85), 4.0, true)
		for i in 16:
			var d := Vector2.RIGHT.rotated(TAU * i / 16.0)
			draw_line(중심 + d * 반경 * 0.78, 중심 + d * 반경, Color(1, 0.96, 0.87, _펄스 * 0.65), 2, true)
	if _표시시간 > 0.0:
		var font := ThemeDB.fallback_font
		var msg := "체크포인트 저장"
		var size := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var p := Vector2(-size.x * 0.5, -162.0 - float(걸이높이))
		draw_string_outline(font, p, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.02, 0.02, 0.02, minf(_표시시간, 1)))
		draw_string(font, p, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.97, 0.87, minf(_표시시간, 1)))
