extends SceneTree
## ============================================================================
## [2026-08-27 신규] 창문 3 종을 한 화면에 놓고 **눈으로** 본다
## ----------------------------------------------------------------------------
## 실행(창모드 필요):
##   Godot --path . -s res://tools/시각_창문점검.gd -- <저장.png> [단계]
##     단계 0 = 아무것도 안 칠한 상태
##     단계 1 = 왼쪽만 흰색으로 쏜 상태 (한쪽씩 닫히는 걸 본다)
##     단계 2 = 양쪽 다 닫은 상태
##
## ▣ 왜 필요한가
##   창문은 **상태가 여럿**이라(무색 / 한쪽 닫힘 / 다 닫힘 / 구멍빛) 한 장으로는 못 본다.
##   숫자 검사(`test_빛창문`)는 규칙만 보고 그림은 안 본다.
## ============================================================================

const 창문_S := preload("res://scripts/스마트월드/창문커튼.gd")
const 색상 := preload("res://scripts/color_defs.gd")

var _n := 0
var _루트: Node2D = null
var _창들: Array = []


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)


func _틱() -> void:
	_n += 1
	var a := OS.get_cmdline_user_args()
	var 단계 := int(a[1]) if a.size() > 1 else 0

	if _n == 1:
		_루트 = Node2D.new()
		root.add_child(_루트)
		# 어둡게 눌러야 빛이 보인다(월드.gd 가 하는 것과 같은 이유).
		var 어둠 := CanvasModulate.new()
		어둠.color = Color(0.72, 0.74, 0.70)
		_루트.add_child(어둠)

		# 바닥 — 빛 웅덩이가 어디에 닿는지 보이게
		var 바닥 := ColorRect.new()
		바닥.color = Color(0.13, 0.13, 0.14)
		바닥.position = Vector2(-2400, 700)
		바닥.size = Vector2(4800, 400)
		바닥.z_index = -20
		_루트.add_child(바닥)

		var x := -1950.0
		for 이름 in ["창문_커튼", "창문_빛다리", "창문_구멍커튼", "창문_배경"]:
			var s := load("res://scenes/집/스마트월드_장애물/%s.tscn" % 이름) as PackedScene
			if s == null:
				continue
			var w: Node2D = s.instantiate()
			w.position = Vector2(x, -80)
			_루트.add_child(w)
			_창들.append(w)
			# 이름표 — 어느 게 어느 건지 헷갈리지 않게
			var l := Label.new()
			l.text = 이름
			l.position = Vector2(x - 130, -420)
			l.add_theme_font_size_override("font_size", 34)
			_루트.add_child(l)
			x += 1300.0

		var cam := Camera2D.new()
		cam.position = Vector2(0, 150)
		cam.zoom = Vector2(0.44, 0.44)
		_루트.add_child(cam)
		cam.make_current()

	elif _n == 20:
		# 칠하기 — `명중(색, 월드좌표)` 의 **좌표가 창 중심의 어느 쪽인가**로
		# 왼쪽/오른쪽 커튼이 갈린다(창문커튼.gd 개편 ③).
		for w in _창들:
			if 단계 >= 1:
				w.명중(색상.WHITE, w.global_position + Vector2(-90, 0))   # 왼쪽 커튼
			if 단계 >= 2:
				w.명중(색상.WHITE, w.global_position + Vector2(90, 0))    # 오른쪽 커튼

	elif _n == 110:
		var img := root.get_viewport().get_texture().get_image()
		print("shot: ", error_string(img.save_png(a[0])), " -> ", a[0])
		quit(0)
