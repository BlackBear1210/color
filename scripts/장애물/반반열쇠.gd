@tool
extends Area2D
## ============================================================================
## [2026-10-08 Claude 신규] 반반 열쇠 조각 — 세로로 반 쪼개진 열쇠의 한쪽(왼쪽 = 검정 · 오른쪽 = 흰)
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-A (v3 확정)
##   · 검정 조각은 플레이어가 **검정일 때만** 보이고 주울 수 있다. 흰 조각은 흰색일 때만.
##     기준 = `player.선택색()`(Shift 로 고른 색). 안 보이면 **주울 수도 없다** → "색을 바꿔 봐야 찾는다".
##   · 보이는 순간 0.15초 페이드 · 보일 때 은은한 후광 + 가는 밝은 테두리.
##   · 공중 Shift 줍기(규칙 8): 겹쳐 있는 동안 색을 바꾸면 그 프레임에 줍는다(들어오는 순간만 보지 않는다).
##   · 주우면 `반반열쇠_관리` 가 획득빛(0.35초) · HUD 로 날아감(0.35초) · HUD 채움(0.4초)을 한다.
##
## ▣ 배치
##   ① 표(`반반열쇠_관리.gd` 의 `표`)에 적으면 스테이지가 열릴 때 만들어진다(씬 파일 무수정 — 하수도 씬 원칙).
##   ② 씬에 직접 놓아도 된다(`scenes/장애물/반반열쇠_조각.tscn`). 둘 다 같은 관리자가 맡는다.
##   원점 = 조각 그림의 가운데. 감지 반지름 34px(조각 40×72 · 몸 44×97 이 스치면 줍는다).
##
## ▣ 성능: 그림은 보임 정도(알파)가 바뀔 때만 다시 그린다. 둥실거림은 position 만 바꾼다.
## ============================================================================

const 폴더 := "res://assets/textures/props/신규기믹_v02/게임용/열쇠/"

## 왼쪽 반 = 검정 조각 · 오른쪽 반 = 흰 조각(기획 고정 — 색과 쪽은 늘 같이 간다).
@export_enum("왼쪽(검정)", "오른쪽(흰)") var 쪽: int = 0:
	set(v): 쪽 = v; _그림 = null; queue_redraw()
## 안 보일 때도 그 자리에 아주 옅은 먼지 반짝임을 남긴다(세계 안의 단서 — 기획 §4-A 레벨 규칙).
@export var 단서: bool = true
@export_range(16.0, 80.0) var 감지_반지름: float = 34.0
## [2026-10-09] 이 조각이 여는 문이 있는 스테이지(비우면 이 씬). 특별 스테이지에서 주운 조각이 본 스테이지 문을 열 때.
@export_file("*.tscn") var 주인_씬: String = ""

var 주움 := false
var _관리: Node = null
var _보임 := 0.0          ## 0 = 안 보임 · 1 = 보임 (0.15초 페이드)
var _그린_보임 := -1.0
var _기준: Vector2
var _t := 0.0
var _그림: Texture2D = null
var _테: Texture2D = null
static var _후광: Texture2D = null


func 색() -> int:
	return ColorDefs.BLACK if 쪽 == 0 else ColorDefs.WHITE


func 쪽_이름() -> String:
	return "왼쪽" if 쪽 == 0 else "오른쪽"


func _ready() -> void:
	if Engine.is_editor_hint():
		_보임 = 1.0
		queue_redraw()
		return
	add_to_group("반반열쇠_조각")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	var c := CollisionShape2D.new()
	var 원 := CircleShape2D.new()
	원.radius = 감지_반지름
	c.shape = 원
	add_child(c)
	_기준 = position
	_t = fmod(absf(global_position.x) * 0.01, TAU)
	z_index = 20


## 관리자가 붙인다(줍기 연출·진행 저장은 관리자 몫).
func 관리_연결(관리: Node) -> void:
	_관리 = 관리


func _physics_process(delta: float) -> void:
	# 에디터에서는 그림만 보인다(@tool — 씬에 직접 놓을 때 자리를 보려고). 판정·둥실거림은 실행 때만.
	if 주움 or Engine.is_editor_hint():
		return
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var 맞음 := false
	if p and p.has_method("선택색"):
		맞음 = int(p.call("선택색")) == 색()
	_보임 = move_toward(_보임, 1.0 if 맞음 else 0.0, delta / 0.15)
	if absf(_보임 - _그린_보임) > 0.02:
		queue_redraw()
	# 둥실거림 — position 만(다시 그리지 않는다)
	_t += delta
	position = _기준 + Vector2(0, sin(_t * 2.2) * 4.0)
	# 줍기 — 색이 맞고(보이는 쪽) 몸이 겹쳐 있으면. 겹친 채 Shift 한 프레임에도 줍는다(공중 줍기).
	if 맞음 and p and p.is_physics_processing() and overlaps_body(p):
		_줍기(p)


func _줍기(p: Node2D) -> void:
	주움 = true
	set_deferred("monitoring", false)
	if _관리 and _관리.has_method("조각_주움"):
		_관리.조각_주움(self, p)
	visible = false


func _텍스처() -> void:
	if _그림 == null:
		_그림 = load(폴더 + 쪽_이름() + ".png")
		_테 = load(폴더 + 쪽_이름() + "_HUD.png")
	if _후광 == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_후광 = gt


func _draw() -> void:
	_그린_보임 = _보임
	_텍스처()
	if _그림 == null:
		return
	var 크기 := Vector2(_그림.get_size()) * 0.5        # 2배 저장 → 게임 40×72
	var 검정 := 쪽 == 0
	# 단서 — 안 보일 때도 남는 옅은 먼지 반짝(검정 화면에서 겨우 보이는 정도)
	if 단서:
		var 먼지 := Color(0.75, 0.74, 0.70, 0.10 * (1.0 - _보임))
		for i in 5:
			var a := TAU * float(i) / 5.0 + 0.6
			draw_circle(Vector2(cos(a) * 22.0, sin(a) * 30.0), 1.6, 먼지)
	if _보임 <= 0.01:
		return
	# 은은한 후광 — 검정 조각은 회색 빛(검정 바탕에서 실루엣이 떠 보이게), 흰 조각은 흰 빛
	var 후광색 := Color(0.62, 0.62, 0.60, 0.30 * _보임) if 검정 else Color(0.92, 0.92, 0.88, 0.22 * _보임)
	draw_texture_rect(_후광, Rect2(-크기 * 1.1, 크기 * 2.2), false, 후광색)
	# 가는 밝은 테두리 — 같은 실루엣을 살짝 크게 밝게 깔고 그 위에 조각(검정 조각일수록 중요)
	if _테:
		var 테색 := Color(0.70, 0.70, 0.68, 0.85 * _보임) if 검정 else Color(0.35, 0.35, 0.35, 0.6 * _보임)
		var 큰 := 크기 * 1.08
		draw_texture_rect(_테, Rect2(-큰 * 0.5, 큰), false, Color(테색.r * 4.0, 테색.g * 4.0, 테색.b * 4.0, 테색.a) if 검정 else 테색)
	draw_texture_rect(_그림, Rect2(-크기 * 0.5, 크기), false, Color(1, 1, 1, _보임))
