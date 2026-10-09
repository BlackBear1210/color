@tool
extends Area2D
## ============================================================================
## [2026-10-09 Claude 신규] 벽 레버 — 레버 퍼즐의 한 칸(켬/끔) 또는 빗장 손잡이(당겨서 확인)
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_특별스테이지_레버_그을음_2026-10-09.md §2 (도형님 아이디어 — 마인크래프트식 레버 패턴)
##   · 레버 세 개를 E 로 켰다 껐다 해 패턴을 맞춘다. 패턴은 방 어딘가의 **단서판**(세계 안의 사물)에 그려져 있다.
##   · 다 맞췄다 싶으면 **빗장 손잡이**(이 스크립트 · `손잡이형`)를 당긴다 → `레버퍼즐.gd` 가 맞나 본다.
##     레버를 하나 바꿀 때마다 판정하지 않는 이유: 중간 상태(아직 맞추는 중)마다 샹들리에가 떨어지면 퍼즐이 아니라 벌이다.
## ▣ 조작: 몸이 판정(가로 ±40 · 키 높이)에 닿은 채 E — 월드.gd 의 "상호작용" 그룹이 받는다(페인트 회수보다 먼저).
## ▣ 그림: 임시 코드 그림(놋쇠 받침판 + 리벳 + 레버 막대 + 손잡이 공) — 2.5D 문법(윗면 밝은 테·왼쪽 위 빛·아래 그늘).
##   정식 원화는 GPT 카드 9(같은 문서 §5)로 주문해 두었다. 원화가 오면 `그림_경로` 에 넣으면 코드 그림은 쉰다.
## ▣ 원점 = 레버가 붙은 바닥선(발 닿는 선) 위 가운데. 레버 축은 바닥에서 `축_높이` 위 벽에 있다(손이 닿는 높이).
## ============================================================================

signal 당겨짐(레버: Node)

@export var 켜짐: bool = false:
	set(v): 켜짐 = v; _목표 = (-0.75 if v else 0.75); queue_redraw()
## 켜면 '빗장 손잡이' — 켬/끔 상태가 없고, 당기면 잠깐 내려갔다 돌아온다(확인 버튼).
@export var 손잡이형: bool = false:
	set(v): 손잡이형 = v; queue_redraw()
@export var 축_높이: float = 64.0
## 정식 원화(받침판+레버 두 상태 가로 띠)를 받으면 여기에. 비면 코드 그림.
@export_file("*.png") var 그림_경로: String = ""

## [2026-10-09] Codex 원화 v01(낡은 철판 · 오목한 축 · 둥근 손잡이) — 생성 도구 `레버v01` 이 자른 두 상태.
##   두 그림 모두 축이 가로 가운데 · 위에서 67px(2배 그림) 자리에 오도록 잘렸다 → 축에 맞춰 0.5배로 그린다.
const 원화_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/레버/"
const 원화_축_위 := 67.0
var _원화: Array = [null, null]       ## [꺼짐, 켜짐]

var 잠김 := false            ## 퍼즐이 풀렸거나 함정이 움직이는 동안엔 못 당긴다
var _각 := 0.75              ## 레버 막대 각도(라디안 · 0 = 수평 · 음수 = 위로)
var _목표 := 0.75
var _당김 := 0.0             ## 손잡이형: 당긴 정도 0~1
var _흔들 := 0.0


func _ready() -> void:
	_각 = _목표
	for i in 2:
		var 경로: String = 원화_폴더 + ("벽레버_켜짐.png" if i == 1 else "벽레버_꺼짐.png")
		_원화[i] = load(경로) if ResourceLoader.exists(경로) else null
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(80, 110)
	c.shape = r
	c.position = Vector2(0, -55)
	add_child(c)
	queue_redraw()
	if Engine.is_editor_hint():
		set_process(false)
		return
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	add_to_group("상호작용")
	set_process(true)


func 닿아있나() -> bool:
	if 잠김:
		return false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false


## 월드.gd 가 E 를 넘겨준다.
func 조작() -> void:
	if 잠김:
		덜컥()
		return
	if 손잡이형:
		_당김 = 1.0
	else:
		켜짐 = not 켜짐
	당겨짐.emit(self)


## 잠겨 있을 때 당기면 — 꿈쩍 않고 덜컥(조작이 먹힌 건 알 수 있게)
func 덜컥() -> void:
	_흔들 = 0.25


func _process(delta: float) -> void:
	var 바뀜 := false
	if absf(_각 - _목표) > 0.001:
		_각 = move_toward(_각, _목표, delta * 9.0)
		바뀜 = true
	if _당김 > 0.0:
		_당김 = maxf(_당김 - delta * 2.2, 0.0)
		바뀜 = true
	if _흔들 > 0.0:
		_흔들 = maxf(_흔들 - delta, 0.0)
		바뀜 = true
	if 바뀜:
		queue_redraw()


# ── 그림(임시 코드 그림) ─────────────────────────────────────────────────────
func _draw() -> void:
	var 축 := Vector2(sin(_흔들 * 80.0) * 2.0 * _흔들 / 0.25, -축_높이 + 7.0)
	var 놋 := Color(0.46, 0.43, 0.38)
	var 놋밝 := Color(0.70, 0.66, 0.58)
	var 그늘 := Color(0.0, 0.0, 0.0, 0.45)
	# 받침판 — 2.5D: 앞면 + 위·왼 밝은 테 + 오른·아래 그늘
	var 판 := Rect2(축 + Vector2(-17, -30), Vector2(34, 60))
	draw_rect(Rect2(판.position + Vector2(3, 3), 판.size), 그늘)
	draw_rect(판, 놋 * 0.8)
	draw_line(판.position, 판.position + Vector2(판.size.x, 0), 놋밝, 2.0)
	draw_line(판.position, 판.position + Vector2(0, 판.size.y), 놋밝 * 0.9, 1.5)
	for 리벳 in [Vector2(-11, -24), Vector2(11, -24), Vector2(-11, 24), Vector2(11, 24)]:
		draw_circle(축 + 리벳, 2.2, 놋밝)
		draw_circle(축 + 리벳 + Vector2(0.6, 0.6), 1.2, 놋 * 0.6)
	# [2026-10-09] 원화가 있으면 그것으로(손잡이형은 원화가 없어 코드 그림 그대로).
	#   그림은 두 상태뿐 → 막대가 가운데(각 0)를 지나는 순간 바꿔 끼운다(코드 각도 애니메이션의 반환점과 같은 때).
	if not 손잡이형 and _원화[0] != null and _원화[1] != null:
		var t: Texture2D = _원화[1] if _각 < 0.0 else _원화[0]
		var 크기 := t.get_size() * 0.5
		var 기울 := (absf(_각) - 0.75) * 0.25          # 바뀌는 동안 판이 살짝 덜컥이는 느낌(반환점 근처에서 기운다)
		draw_set_transform(축, 기울, Vector2.ONE)
		draw_texture_rect(t, Rect2(Vector2(-크기.x * 0.5, -원화_축_위 * 0.5), 크기), false)
		draw_set_transform(Vector2.ZERO)
		return
	if 손잡이형:
		# 빗장 손잡이 — 사슬 끝의 둥근 고리. 당기면 아래로 내려왔다 돌아간다
		var 끝 := 축 + Vector2(0, 18 + 26 * _당김)
		for k in 6:
			var a := 축.lerp(끝, float(k) / 6.0)
			draw_arc(a + Vector2(0, 3), 3.0, 0, TAU, 10, 놋밝 * 0.9, 1.6)
		draw_arc(끝 + Vector2(0, 11), 10.0, 0, TAU, 24, Color(0, 0, 0, 0.5), 5.0)
		draw_arc(끝 + Vector2(0, 10), 10.0, 0, TAU, 24, 놋밝, 3.0)
		return
	# 레버 막대 + 손잡이 공 — 켬 = 위, 끔 = 아래
	var 방향 := Vector2(sin(_각), -cos(_각))
	var 끝2 := 축 + 방향 * 30.0
	draw_line(축 + Vector2(2, 2), 끝2 + Vector2(2, 2), 그늘, 5.0)
	draw_line(축, 끝2, Color(0.22, 0.21, 0.20), 5.0)
	draw_line(축, 끝2, 놋밝 * 0.7, 1.4)
	draw_circle(끝2 + Vector2(1.5, 1.5), 6.5, 그늘)
	draw_circle(끝2, 6.5, Color(0.16, 0.15, 0.14))
	draw_circle(끝2 + Vector2(-2, -2), 2.4, Color(0.6, 0.58, 0.55))
	draw_circle(축, 4.0, 놋밝)
	# 켬 표시 — 판 위쪽 작은 홈에 빛이 들면 켬(멀리서도 상태가 읽히게)
	draw_circle(축 + Vector2(0, -21), 3.2, Color(0.92, 0.88, 0.78) if 켜짐 else Color(0.10, 0.10, 0.10))
