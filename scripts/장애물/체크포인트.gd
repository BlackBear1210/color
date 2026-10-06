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

## ============================================================================
## ★[2026-09-30] 모양 2 — 주철 잉크 성수반 (도형님 시안 A 확정)
## ----------------------------------------------------------------------------
##   · 왜: 등불은 꺼지면 회색 항아리처럼 보였고, 하수도 벽마다 걸린 철창 벽등(장식)과
##     "빛 = 체크포인트" 신호가 겹쳤다. 성수반은 벽등·쇠사슬·밸브 어느 것과도 실루엣이 안 겹친다.
##   · 연출: 꺼진(차가운) 주철 대야 → 플레이어가 닿으면 불빛이 확 붙고 안쪽 홈에 **흰 잉크가 차오른다**
##     → 가득 차면 테 가장자리로 한 방울씩 흘러내린다.
##   · 잉크 색: 기본은 항상 흰색(도형님 지시). `잉크_색_기억` 을 켜면 닿은 순간의 플레이어 색으로 찬다
##     (검정 몸으로 지나가도 흰 잉크면 "흰색으로 부활" 로 오해할 수 있어서 스위치로 남겼다).
##   · 그림: `tools/생성_체크포인트_성수반.py` 가 호퍼 원화 재질로 굽는다(손으로 그리지 말 것).
##     아래 `성수반_*` 상수는 그 도구의 규격과 같아야 한다.
##   · 스스로 켜진다: 하수도 `월드.gd` 는 체크포인트를 켜 주지 않는다(부활은 자동 안전지점).
##     그래서 **닿으면 스스로 켠다**(body_entered). stage_lab·2-5 월드가 부르는 `켜기()` 와 겹쳐도 한 번만 켜진다.
## ============================================================================
const 성수반_그림 := "res://assets/textures/props/checkpoint_font/font_body.png"
const 성수반_크기 := Vector2(96, 108)
const 성수반_바닥y := 104.0                       # 그림에서 발판 윗면이 닿는 y
const 성수반_홈 := Rect2(13, 22, 70, 6)            # 잉크가 차는 안쪽 홈(그림 왼쪽 위 기준)
const 성수반_테아래y := 34.0                        # 윗단 테의 아랫변 — 흘러내린 방울이 여기서 떨어진다

@export_range(16, 200) var 감지폭: int = 56:
	set(v): 감지폭 = v; _재구성()
@export_range(16, 300) var 감지높이: int = 110:
	set(v): 감지높이 = v; _재구성()
## 등불이 걸린 높이(px). 0 이면 바닥에 세운다.
@export_range(0, 200) var 걸이높이: int = 0:
	set(v): 걸이높이 = v; _재구성()
## 0 = 주철 잉크 성수반(기본) · 1 = 예전 잉크 등불. 등불로 되돌리고 싶으면 여기만 바꾼다.
@export_enum("성수반:0", "등불:1") var 모양: int = 0:
	set(v): 모양 = v; _재구성()
## 끄면(기본) 항상 흰 잉크. 켜면 닿은 순간의 플레이어 색(검정/흰)으로 찬다.
@export var 잉크_색_기억: bool = false

var 활성: bool = false
var _펄스: float = 0.0
var _등불: Sprite2D
var _light: PointLight2D
var _채움: float = 0.0          # 0 → 1 : 잉크가 홈을 채운 정도
var _잉크색: int = 1            # ColorDefs.WHITE
var _시각: float = 0.0

func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_재구성()
	if not Engine.is_editor_hint() and not body_entered.is_connected(_닿음):
		body_entered.connect(_닿음)


## 닿으면 스스로 켠다 — 플레이어만. (물체·양동이가 굴러 들어와 켜지면 안 된다)
func _닿음(body: Node) -> void:
	if body.is_in_group("player"):
		켜기()

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
	if _등불 and 모양 == 0 and ResourceLoader.exists(성수반_그림):
		# 성수반은 늘 바닥에 선다(걸이높이 무시) — 대야를 공중에 매다는 건 말이 안 된다.
		_등불.texture = load(성수반_그림)
		_등불.position = Vector2(-성수반_크기.x * 0.5, -성수반_바닥y)
		_등불.z_index = -1                  # 부모(잉크 그리기)보다 뒤 → 잉크가 홈 위에 그려진다
		# 꺼진 상태 = 차갑게 식은 주철. 등불(0.30)보다 밝게 — 모양은 읽혀야 "저기 뭔가 있다" 가 된다.
		_등불.modulate = Color(0.50, 0.50, 0.53) if not 활성 else Color(1, 1, 1)
	elif _등불:
		if 모양 == 1 and ResourceLoader.exists(PROPS + "lantern.svg"):
			_등불.texture = load(PROPS + "lantern.svg")
		var t: Texture2D = _등불.texture
		# 바닥에 세우면 아랫변이 지면에, 걸이높이가 있으면 그만큼 매단다
		_등불.position = Vector2(-t.get_width() * 0.5,
			-t.get_height() - float(걸이높이))
		_등불.z_index = -1                  # 플레이어 뒤 (지나갈 때 안 가림)
		_등불.modulate = Color(0.30, 0.30, 0.32)   # 꺼진 상태 = 어둡게

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
	# 성수반 빛은 잉크 수면보다 40 위 — 대야 앞면을 정면으로 때리지 않고 위에서 잉크와 벽을 비춘다.
	_light.position = Vector2(0, _빛_y() - (40.0 if 모양 == 0 else 0.0))
	# 성수반은 흰 잉크의 빛 — 등불의 주황 촛불빛(1,0.9,0.7) 대신 약간 차가운 흰빛. 흑백 화면에서 색이 끼지 않게.
	_light.color = Color(0.96, 0.97, 1.0) if 모양 == 0 else Color(1.0, 0.90, 0.70)
	queue_redraw()


## 성수반 잉크: 홈 바닥에서 차오르는 잉크 · 수면 반짝임 · 가득 차면 테 끝에서 떨어지는 방울.
## 그림(주철 대야)은 자식 Sprite(z −1)라 이 그리기가 그 위, 홈 자리에 얹힌다.
func _잉크_그리기() -> void:
	if _채움 <= 0.001:
		return
	var 원점 := Vector2(-성수반_크기.x * 0.5, -성수반_바닥y)      # 그림 왼쪽 위
	var 홈 := Rect2(원점 + 성수반_홈.position, 성수반_홈.size)
	var 흰 := _잉크색 == ColorDefs.WHITE
	var 몸색 := Color(0.93, 0.93, 0.90) if 흰 else Color(0.05, 0.05, 0.06)
	# 검정 잉크는 검은 홈에서 안 보인다 → 수면선을 밝게 그어 "차 있다" 를 읽히게
	var 수면색 := Color(1, 1, 1, 0.95) if 흰 else Color(0.80, 0.83, 0.90, 0.85)
	var 높이 := 홈.size.y * _채움
	var 잉크 := Rect2(홈.position.x, 홈.end.y - 높이, 홈.size.x, 높이)
	draw_rect(잉크, 몸색)
	draw_line(Vector2(잉크.position.x, 잉크.position.y), Vector2(잉크.end.x, 잉크.position.y), 수면색, 1.0)
	# 수면을 따라 천천히 오가는 반짝임 — 고인 물이 아니라 "살아 있는 잉크"
	var 반짝x := 홈.get_center().x + sin(_시각 * 0.9) * 홈.size.x * 0.35
	draw_line(Vector2(반짝x - 6, 잉크.position.y + 1), Vector2(반짝x + 6, 잉크.position.y + 1),
		Color(수면색.r, 수면색.g, 수면색.b, 0.55), 1.0)
	if _채움 < 0.999:
		return
	# 가득 참 → 오른쪽 테 끝에서 방울이 흘러 떨어진다(1.7 초 주기). 테 앞면 줄기 + 떨어지는 방울 + 바닥 튐.
	var 끝x := 홈.end.x - 3.0
	var 테아래 := 원점.y + 성수반_테아래y
	draw_line(Vector2(끝x, 홈.position.y), Vector2(끝x, 테아래), 몸색, 2.0)
	var 주기 := fmod(_시각, 1.7) / 1.7
	var 방울y := lerpf(테아래, -3.0, 주기 * 주기)          # 중력처럼 점점 빨라진다
	var 투명 := 1.0 - smoothstep(0.85, 1.0, 주기)
	draw_circle(Vector2(끝x, 방울y), 1.8, Color(몸색.r, 몸색.g, 몸색.b, 투명))
	if not 흰:
		draw_arc(Vector2(끝x, 방울y), 2.2, 0.0, TAU, 10, Color(수면색.r, 수면색.g, 수면색.b, 0.6 * 투명), 1.0)
	if 주기 > 0.9:
		var 튐 := (주기 - 0.9) / 0.1
		draw_arc(Vector2(끝x, -1.0), 2.0 + 튐 * 5.0, PI, TAU, 10, Color(수면색.r, 수면색.g, 수면색.b, 1.0 - 튐), 1.0)


## 빛·확산 링의 중심. 성수반은 잉크 홈(대야 입구), 등불은 등 몸통.
func _빛_y() -> float:
	if 모양 == 0:
		return -성수반_바닥y + 성수반_홈.get_center().y
	return -44.0 - float(걸이높이)

## stage_lab 이 체크포인트 통과 시 호출한다.
func 켜기() -> void:
	if 활성:
		return
	활성 = true
	_펄스 = 1.0
	if 모양 == 0:
		# 잉크 색: 기본 흰색. 스위치를 켰을 때만 지금 플레이어가 고른 색(자유색)을 쓴다.
		_잉크색 = ColorDefs.WHITE
		if 잉크_색_기억:
			var p := get_tree().get_first_node_in_group("player")
			if p != null and p.has_method("선택색"):
				_잉크색 = ColorDefs.BLACK if int(p.call("선택색")) == ColorDefs.BLACK else ColorDefs.WHITE
		# 불이 붙는 것과 거의 동시에 차오르기 시작해 0.9 초에 가득 — 빛이 먼저, 잉크가 뒤따른다
		var t0 := create_tween()
		t0.tween_interval(0.08)
		t0.tween_property(self, "_채움", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ★[2026-09-30 실측] 성수반을 등불 값(대야 밝기 1.0 · 빛 1.6→1.05)으로 켰더니 주철이 하얗게 날아가
	#   흰 잉크와 금속이 한 덩어리가 됐다 → 대야는 0.72 까지만 밝히고 빛도 약하게(1.1→0.7).
	#   "흰 지형 바로 위에 1.0 넘는 광원 금지"(STEP 13 §5)와 같은 이유 — 빛은 잉크를 읽히게 하려고 둔다.
	var 성수반 := 모양 == 0
	if _등불:
		var t1 := create_tween()
		t1.tween_property(_등불, "modulate", Color(0.72, 0.72, 0.75) if 성수반 else Color(0.95, 0.93, 0.88), 0.35)
	if _light:
		# 불이 확 붙었다가 안정되는 2단 트윈 — "성냥에 불이 옮겨붙는" 리듬
		var t2 := create_tween()
		t2.tween_property(_light, "energy", 1.1 if 성수반 else 1.6, 0.14).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(_light, "energy", 0.7 if 성수반 else 1.05, 0.45).set_trans(Tween.TRANS_SINE)
		t2.tween_callback(func() -> void:
			# 안정된 뒤부터 촛불처럼 미세하게 흔들린다
			if is_instance_valid(_light) and ResourceLoader.exists(FLICKER):
				_light.set_script(load(FLICKER)))
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _펄스 > 0.0:
		_펄스 = maxf(_펄스 - delta * 1.1, 0.0)
		queue_redraw()
	# 켜진 성수반은 잉크 물결·방울이 움직인다 — 화면에 보일 때만 다시 그린다
	if 모양 == 0 and 활성 and is_visible_in_tree():
		_시각 += delta
		queue_redraw()

func _draw() -> void:
	var y := _빛_y()
	if 모양 == 0:
		_잉크_그리기()
	# 매달린 경우 천장까지 이어지는 줄
	elif 걸이높이 > 0:
		draw_line(Vector2(0, y - 44.0), Vector2(0, y - 44.0 - float(걸이높이)),
			Color(0.10, 0.10, 0.10), 2.0)
	# 켜지는 순간의 확산 링 — "저장됐다"를 즉각 알리는 유일한 UI적 신호
	if _펄스 > 0.0:
		draw_arc(Vector2(0, y), 30.0 + (1.0 - _펄스) * 90.0, 0.0, TAU, 32,
			Color(1.0, 0.92, 0.75, _펄스 * 0.55), 2.5, true)
	# 꺼져 있을 때는 아주 흐린 윤곽만 — "저기 뭔가 있다" 정도로만 보이게 (성수반은 대야 자체가 보여서 필요 없다)
	elif not 활성 and 모양 == 1:
		draw_arc(Vector2(0, y), 16.0, 0.0, TAU, 20,
			Color(0.55, 0.55, 0.58, 0.30), 1.5, true)
