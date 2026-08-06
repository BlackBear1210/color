@tool
extends Area2D
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

func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
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
		add_child(_light)
	_light.position = Vector2(0, -44.0 - float(걸이높이))
	queue_redraw()

## stage_lab 이 체크포인트 통과 시 호출한다.
func 켜기() -> void:
	if 활성:
		return
	활성 = true
	_펄스 = 1.0
	if _등불:
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

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _펄스 > 0.0:
		_펄스 = maxf(_펄스 - delta * 1.1, 0.0)
		queue_redraw()

func _draw() -> void:
	var y := -44.0 - float(걸이높이)
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
