@tool
extends Node2D
class_name ObstaclePlaceholder
## ───────────────────────────────────────────────────────────────────────────
## 미구현 장애물/기믹 자리표시(Placeholder)   ▼ 2026-06-30 Claude 작성
##
##   stage_6 에서 쓰던 "Label 로 위치만 표시" 방식을 발전시킨 재사용 씬이다.
##   에디터/게임 양쪽에서 점선 박스 + [코드] 이름 + 배치지시(note) 를 그려서,
##   "여기에 이런 장애물이 이 크기로 들어간다" 를 한눈에 보여 준다.
##
## [디자이너 사용법]
##   1) scenes/obstacles/Placeholder.tscn 을 맵(Obstacles 노드)으로 드래그.
##   2) 인스펙터에서 다음을 채운다:
##        code          = 요소 코드 (예: "T6", "H7", "P4")  — 카탈로그 기준
##        obstacle_name = 한글 이름 (예: "점프대", "색 레이저")
##        note          = 배치 지시 (예: "가로 왕복 거리 160 / 주기 2초")
##        box_size      = 예상 충돌 크기(px). 원점 = footprint 중심.
##   3) 박스를 실제 들어갈 위치/크기로 옮긴다(플레이어 약 19x43px 기준으로 잡기).
##
## [프로그래머 사용법]
##   같은 좌표·크기에 실제 장애물 씬을 만들어 끼우고 이 플레이스홀더는 지운다.
##   box_size 가 곧 권장 충돌 크기다.
##
##   ※ 게임 로직/충돌 없음(순수 표시용). collision_layer/mask 도 없으니
##     reach_sim(지형 도달성 시뮬)·플레이 양쪽에 영향 주지 않는다.
## ───────────────────────────────────────────────────────────────────────────

@export var code: String = "T?":
	set(v): code = v; queue_redraw()
@export var obstacle_name: String = "장애물 이름":
	set(v): obstacle_name = v; queue_redraw()
@export_multiline var note: String = "":
	set(v): note = v; queue_redraw()
@export var box_size: Vector2 = Vector2(120, 120):
	set(v): box_size = v; queue_redraw()
@export var box_color: Color = Color(1.0, 0.25, 0.85):
	set(v): box_color = v; queue_redraw()

func _draw() -> void:
	var hs: Vector2 = box_size * 0.5
	var rect := Rect2(-hs, box_size)
	# 반투명 채움 → 면적이 눈에 띄게
	draw_rect(rect, Color(box_color.r, box_color.g, box_color.b, 0.12), true)
	# 점선 테두리
	var line_col := Color(box_color.r, box_color.g, box_color.b, 0.95)
	_dashed_rect(rect, line_col, 2.0, 9.0)
	# 중심 십자(정확한 배치 기준점)
	draw_line(Vector2(-9, 0), Vector2(9, 0), line_col, 1.5)
	draw_line(Vector2(0, -9), Vector2(0, 9), line_col, 1.5)
	# 상단 라벨 [코드] 이름
	var font: Font = ThemeDB.fallback_font
	var title := "[%s] %s" % [code, obstacle_name]
	draw_string(font, Vector2(-hs.x, -hs.y - 10.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, line_col)
	# 하단 배치 지시(note)
	if note != "":
		draw_multiline_string(font, Vector2(-hs.x, hs.y + 20.0), note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, -1, Color(1, 1, 1, 0.9))

func _dashed_rect(r: Rect2, col: Color, w: float, dash: float) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.position + r.size
	var d := r.position + Vector2(0, r.size.y)
	draw_dashed_line(a, b, col, w, dash)
	draw_dashed_line(b, c, col, w, dash)
	draw_dashed_line(c, d, col, w, dash)
	draw_dashed_line(d, a, col, w, dash)
