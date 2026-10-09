@tool
extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 거미줄 — 빛의 길을 가리는 '논리' 장애물 (거미방 · 도형님 지시서 §3)
## ----------------------------------------------------------------------------
## ▣ 무엇을 하나
##   거미(그을음 거미)가 지정된 자리에 친다. 다 쳐진(완성) 거미줄은 **빛이 지나가는 선분을 가린다** —
##   반딧불 몹의 빛이 거미줄 너머의 빛받이·플레이어·거미에 닿지 않는다.
## ▣ 그림 · 물리 · 빛 판정을 따로 둔다 (지시서 "주의할 점 1")
##   · 그림  : `_draw` 의 방사형 줄(임시 · 아스트라 그림이 오면 `그림_경로` 로 바꾼다).
##   · 물리  : **없다.** 플레이어·총알·몹은 그대로 지나간다(이동을 막는 벽이 아니다).
##   · 빛 판정: 두 끝점 `가`(= 노드 원점) ~ `나` 를 잇는 **선분 하나**. 그룹 "빛막이" + `가리나(시작, 끝)` 로 묻는다.
##     그림의 투명도·픽셀과 무관하다 — 판정은 이 선분뿐이다.
## ▣ 수명(이번 판 규칙)
##   · 한 번 쳐지면 남는다. 거미가 떠나도 안 사라진다. 같은 줄을 두 번 치지 않는다(노드 하나 = 자리 하나).
##   · 친 거미가 **빛에 타면** 그 거미의 줄도 삭아 내린다(`삭기()`) — 거미가 다시 태어나면 다시 친다.
##   · 씬이 해제되면 노드와 함께 정리된다(따로 만든 전역 목록 없음).
## ▣ 놓는 법: 원점 = 한쪽 끝(보통 위 · 들보 아래) · `나` = 다른 끝(로컬). 거미가 서서 치는 자리 = `발_x`(전역 x).
##   도안 {"종류": "거미", …, "거미줄": [{"가": [x, y], "나": [x, y], "처음부터": true}]} → 생성기가 놓는다.
## ============================================================================

## 다른 끝(노드 로컬 px). 원점이 한 끝이다.
@export var 나: Vector2 = Vector2(0, 320):
	set(v): 나 = v; queue_redraw()
## 씬이 시작될 때 이미 쳐져 있나.
@export var 처음부터: bool = false:
	set(v): 처음부터 = v; queue_redraw()
## 그림이 줄 양옆으로 퍼지는 폭(px) — 판정과 무관(판정은 선분).
@export_range(16.0, 160.0) var 그림_폭: float = 70.0:
	set(v): 그림_폭 = v; queue_redraw()

signal 바뀜(완성: bool)

## [2026-10-09] Codex 원화 v01 — 생성 도구 `거미줄v01` 이 두 묶인 끝(앵커)을 그림 맨 위 가운데 · 맨 아래 가운데에 오게 잘랐다.
##   → 원점(가)~`나` 선분에 그대로 늘여 붙이면 그림의 줄 끝 = 판정 선분 끝이다(그림 폭은 판정과 무관).
const 원화 := "res://assets/textures/props/신규기믹_v02/게임용/거미줄/세로.png"
var _원화: Texture2D = null

## 0 = 없음 ~ 1 = 다 쳐짐. 거미가 `엮기()` 로 올린다.
var 진행: float = 0.0
var _삭는중 := 0.0             ## > 0 이면 삭아 내리는 연출 중(초)


func _ready() -> void:
	_원화 = load(원화) if ResourceLoader.exists(원화) else null
	진행 = 1.0 if 처음부터 else 0.0
	queue_redraw()
	if Engine.is_editor_hint():
		return
	add_to_group("빛막이")
	add_to_group("거미줄")
	set_process(false)


func 완성() -> bool:
	return 진행 >= 1.0


## 빛 판정 — 전역 선분 시작~끝이 이 거미줄(완성된 것만)을 가로지르나.
func 가리나(시작: Vector2, 끝: Vector2) -> bool:
	if not 완성():
		return false
	var a := global_position
	var b := to_global(나)
	return Geometry2D.segment_intersects_segment(시작, 끝, a, b) != null


## 거미가 서서 칠 자리(전역 x) — 두 끝 중 아래쪽 끝의 x(세로 줄이면 같은 x).
func 발_x() -> float:
	var a := global_position
	var b := to_global(나)
	return a.x if a.y > b.y else b.x


## 거미가 한 프레임씩 엮는다. 다 되면 true. (이미 완성이면 아무것도 안 하고 true — 중복 설치 없음)
func 엮기(양: float) -> bool:
	if 완성():
		return true
	_삭는중 = 0.0
	진행 = minf(진행 + 양, 1.0)
	queue_redraw()
	if 완성():
		바뀜.emit(true)
		return true
	return false


## 엮다가 거미가 타 버렸다 — 덜 친 줄은 흩어진다(완성된 줄은 그대로).
func 덜친것_버리기() -> void:
	if 완성() or 진행 <= 0.0:
		return
	진행 = 0.0
	queue_redraw()


## 친 거미가 탔다 → 삭아 내린다(0.6초 연출). 판정은 **바로** 풀린다(빛이 곧장 지나간다).
func 삭기() -> void:
	if 진행 <= 0.0:
		return
	var 있었나 := 완성()
	진행 = 0.0
	_삭는중 = 0.6
	set_process(true)
	if 있었나:
		바뀜.emit(false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_삭는중 = maxf(_삭는중 - delta, 0.0)
	queue_redraw()
	if _삭는중 <= 0.0:
		set_process(false)


# ── 그림(임시 · 코드) ────────────────────────────────────────────────────────
## 두 끝 사이 큰 줄(뼈대) + 가운데에서 퍼지는 바퀴살 + 나선. 덜 쳐진 줄은 진행만큼만 그린다.
## 삭는 중이면 아래로 늘어지며 흐려진다.
func _draw() -> void:
	var k := 진행
	if Engine.is_editor_hint():
		k = 1.0 if 처음부터 else 0.45       # 에디터: 자리가 보이게(덜 친 줄은 옅게)
	var 삭 := clampf(_삭는중 / 0.6, 0.0, 1.0)
	if k <= 0.0 and 삭 <= 0.0:
		return
	var 알파 := 0.85 if k >= 1.0 else 0.45
	if 삭 > 0.0:
		k = 1.0
		알파 = 0.6 * 삭
	var 색 := Color(0.86, 0.86, 0.84, 알파)
	if _원화:
		_원화_그리기(k, 삭, 알파)
		return
	var a := Vector2.ZERO
	var b := 나
	var 축 := (b - a)
	var 길이 := 축.length()
	if 길이 < 1.0:
		return
	var 방 := 축 / 길이
	var 옆 := 방.orthogonal()
	var 처짐 := Vector2(0, 40.0 * (1.0 - 삭)) if 삭 > 0.0 else Vector2.ZERO
	# 뼈대 줄(두 끝을 잇는 줄) — 진행만큼 위에서부터 자란다
	draw_line(a, a + 축 * minf(k * 1.4, 1.0) + 처짐 * 0.5, 색, 2.0, true)
	if k < 0.3:
		return
	var 가운데 := a + 축 * 0.5 + 처짐
	var 반 := minf(그림_폭, 길이 * 0.5)
	var 살수 := 8
	var 살끝: Array[Vector2] = []
	for i in 살수:
		var 각 := TAU * float(i) / float(살수) + 0.2
		var 끝 := 가운데 + (방 * cos(각) * 길이 * 0.48 + 옆 * sin(각) * 반) * clampf((k - 0.3) / 0.4, 0.0, 1.0)
		살끝.append(끝)
		draw_line(가운데, 끝, 색, 1.2, true)
	# 나선 — 바퀴살 사이를 고리로 잇는다(진행 0.7 이후)
	if k > 0.7:
		var 고리수 := 4
		for r in 고리수:
			var t := (float(r) + 1.0) / float(고리수 + 1) * clampf((k - 0.7) / 0.3, 0.0, 1.0)
			for i in 살수:
				var p1 := 가운데.lerp(살끝[i], t)
				var p2 := 가운데.lerp(살끝[(i + 1) % 살수], t)
				draw_line(p1, p2, Color(색.r, 색.g, 색.b, 색.a * 0.8), 1.0, true)


## [2026-10-09] 원화 그리기 — 위 끝(원점)에서 아래로 진행만큼 드러난다(엮는 중 = 위에서부터 자라는 줄) ·
##   삭는 중이면 아래로 처지며 흐려진다. 축 = 원점 → 나(그림은 세로로 그려져 있어 −90° 돌려 맞춘다).
func _원화_그리기(k: float, 삭: float, 알파: float) -> void:
	var 길이 := 나.length()
	if 길이 < 1.0:
		return
	var tex_크기 := _원화.get_size()
	var 배 := 길이 / tex_크기.y
	var 각 := 나.angle() - PI * 0.5
	var 처짐 := 0.0 if 삭 <= 0.0 else 40.0 * (1.0 - 삭)
	draw_set_transform(Vector2(0, 처짐).rotated(0.0), 각, Vector2(배, 배))
	var 보임 := clampf(k, 0.0, 1.0)
	var 높이 := tex_크기.y * 보임
	var 알 := 1.0 if k >= 1.0 else 0.65
	if 삭 > 0.0:
		알 = 알파 / 0.6
	draw_texture_rect_region(_원화, Rect2(-tex_크기.x * 0.5, 0.0, tex_크기.x, 높이), Rect2(0, 0, tex_크기.x, 높이), Color(1, 1, 1, 알))
	draw_set_transform(Vector2.ZERO)
	if k < 1.0 and 삭 <= 0.0:
		# 덜 친 줄 — 뼈대 실 한 가닥이 끝까지(어디에 칠지 보이게)
		draw_line(Vector2.ZERO, 나, Color(0.86, 0.86, 0.84, 0.35), 1.0, true)
