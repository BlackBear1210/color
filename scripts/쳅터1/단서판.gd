@tool
extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 단서판 — 레버 퍼즐의 답을 방 어딘가 벽에 걸린 '그림' 으로 알려 준다
## ----------------------------------------------------------------------------
## ▣ 원칙(기획 §3): UI 글자 대신 세계 안의 사물로 알린다. 이 판은 액자 속 촛대 셋 — 켜진 초 = 레버 켬, 꺼진 초 = 끔.
##   왼쪽부터 레버 순서와 같다. 레버 퍼즐과 **다른 곳**(한 갈래 위·다른 방 구석)에 걸어 '찾아서 기억하는' 단계를 만든다.
## ▣ 원점 = 액자 가운데. 임시 코드 그림(목재 액자 + 촛대 3) — 정식 원화는 GPT 카드 10(문서 §5)에 주문.
## ============================================================================

## 레버 순서대로 켬(true)/끔(false). 비우면 `퍼즐` 에서 읽는다.
@export var 정답: Array[bool] = []:
	set(v): 정답 = v; queue_redraw()
@export var 퍼즐: NodePath
@export var 크기: Vector2 = Vector2(150, 96)

var _t := 0.0


func _ready() -> void:
	z_index = -5                  # 배경 가구(−90)보다 앞, 지형(0)보다 뒤 — 벽에 걸린 그림
	queue_redraw()
	set_process(not Engine.is_editor_hint())


func _답() -> Array:
	if not 정답.is_empty():
		return 정답
	var p := get_node_or_null(퍼즐)
	if p and p.get("정답") != null:
		return p.get("정답")
	return [true, false, true]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()          # 불꽃 일렁임(촛대 3 개 — 작은 그림이라 매 프레임 그려도 가볍다)


func _draw() -> void:
	var 반 := 크기 * 0.5
	# 액자 — 어두운 나무 테 + 안쪽 벽지, 왼 위 빛
	draw_rect(Rect2(-반 + Vector2(4, 4), 크기), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-반, 크기), Color(0.20, 0.18, 0.16))
	draw_rect(Rect2(-반 + Vector2(7, 7), 크기 - Vector2(14, 14)), Color(0.13, 0.12, 0.12))
	draw_line(-반, Vector2(반.x, -반.y), Color(0.42, 0.38, 0.33), 2.0)
	draw_line(-반, Vector2(-반.x, 반.y), Color(0.36, 0.33, 0.29), 2.0)
	var 답 := _답()
	var n := 답.size()
	for i in n:
		var x := -반.x + 크기.x * (float(i) + 0.5) / float(n)
		var 바닥 := 반.y - 16.0
		# 촛대 받침 + 초
		draw_rect(Rect2(Vector2(x - 9, 바닥), Vector2(18, 5)), Color(0.40, 0.37, 0.33))
		draw_rect(Rect2(Vector2(x - 4, 바닥 - 28), Vector2(8, 28)), Color(0.72, 0.70, 0.66))
		draw_line(Vector2(x, 바닥 - 28), Vector2(x, 바닥 - 33), Color(0.1, 0.1, 0.1), 1.5)
		if bool(답[i]):
			var 일렁 := sin(_t * 9.0 + i * 1.7) * 1.2
			draw_circle(Vector2(x, 바닥 - 40), 12.0, Color(1.0, 0.95, 0.80, 0.12))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, 바닥 - 34), Vector2(x + 3.5, 바닥 - 34),
				Vector2(x + 일렁, 바닥 - 46)]), Color(0.98, 0.94, 0.82))
		else:
			# 꺼진 초 — 가는 연기 한 줄
			draw_line(Vector2(x, 바닥 - 34), Vector2(x + sin(_t * 2.0 + i) * 2.0, 바닥 - 44), Color(0.5, 0.5, 0.5, 0.35), 1.0)
