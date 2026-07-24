extends Control
## ============================================================================
## [2026-07-24 도형 · 신규] 챕터 1 스테이지 선택 화면
## ----------------------------------------------------------------------------
## 새로 만든 스테이지 1~5 와 셰이더/VFX 비교 실험실(zone_04/05)로 바로 들어가는 입구.
## 버튼을 코드로 만들기 때문에 .tscn 은 노드 1개짜리다 (팀원과 씬 충돌 없음).
##
## ▣ 왜 필요한가
##   스테이지끼리는 목표문으로 이어져 있지만(1→2→3→4→5), **개발 중에는 특정 스테이지만
##   반복해서 확인**해야 한다. 매번 앞 스테이지를 클리어할 수는 없다.
## ============================================================================

const 로비 := "res://scenes/lobby/lobby.tscn"

const 목록 := [
	["스테이지 1 — 첫 붓질", "res://scenes/스테이지/스테이지_1.tscn"],
	["스테이지 2 — 색이 나를 죽인다", "res://scenes/스테이지/스테이지_2.tscn"],
	["스테이지 3 — 되돌리기", "res://scenes/스테이지/스테이지_3.tscn"],
	["스테이지 4 — 회색의 대가", "res://scenes/스테이지/스테이지_4.tscn"],
	["스테이지 5 — 마지막 오르막", "res://scenes/스테이지/스테이지_5.tscn"],
	["", ""],
	["ZONE 4 — 잉크 번짐 셰이더 방식", "res://scenes/world_1/zone_04/zone_04.tscn"],
	["ZONE 5 — VFX 스탬프 방식", "res://scenes/world_1/zone_05/zone_05.tscn"],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var 배경 := ColorRect.new()
	배경.color = Color(0.06, 0.06, 0.07)
	배경.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(배경)

	var 세로 := VBoxContainer.new()
	세로.set_anchors_preset(Control.PRESET_CENTER)
	세로.anchor_left = 0.5; 세로.anchor_right = 0.5
	세로.anchor_top = 0.5; 세로.anchor_bottom = 0.5
	세로.offset_left = -260; 세로.offset_right = 260
	# 창 높이가 648px 인 개발 창모드에서도 "← 로비로"·조작 안내까지 다 보이도록 넉넉히 잡는다
	세로.offset_top = -310; 세로.offset_bottom = 310
	세로.add_theme_constant_override("separation", 7)
	add_child(세로)

	var 제목 := Label.new()
	제목.text = "CHAPTER 1"
	제목.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	제목.add_theme_font_size_override("font_size", 40)
	세로.add_child(제목)

	var 부제 := Label.new()
	부제.text = "칠하고 · 바꾸고 · 되돌려서 나아간다"
	부제.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	부제.modulate = Color(0.65, 0.65, 0.7)
	세로.add_child(부제)
	세로.add_child(_여백(14))

	for 항목 in 목록:
		if String(항목[0]) == "":
			세로.add_child(_여백(16))          # 스테이지 / 실험실 구분선 자리
			continue
		var b := Button.new()
		b.text = 항목[0]
		b.custom_minimum_size = Vector2(0, 38)
		var 경로: String = 항목[1]
		b.disabled = not ResourceLoader.exists(경로)
		b.pressed.connect(func() -> void: StageTransition.change_scene(self, 경로))
		세로.add_child(b)

	세로.add_child(_여백(16))
	var 뒤로 := Button.new()
	뒤로.text = "← 로비로"
	뒤로.custom_minimum_size = Vector2(0, 38)
	뒤로.pressed.connect(func() -> void: StageTransition.change_scene(self, 로비))
	세로.add_child(뒤로)

	var 도움 := Label.new()
	도움.text = "이동 A/D · 점프 Space · 색 전환 Shift · 발사 좌클릭 · 조준 우클릭 · 회수 E"
	도움.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	도움.modulate = Color(0.55, 0.55, 0.6)
	세로.add_child(_여백(10))
	세로.add_child(도움)

func _여백(높이: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 높이)
	return c
