extends Control
## ============================================================================
## [2026-10-06 Claude 신규] 쳅터 2(하수도) 스테이지 지도 — 물·불 게임식 거미줄 선택 화면
## ----------------------------------------------------------------------------
## ▣ 하는 일
##   게임진행.하수도_지도 표를 그대로 그린다: 칸(스테이지) = 원 · 선 = 다음으로 열리는 길.
##     · 잠김  — 어두운 원 + 자물쇠. 앞 칸을 하나도 안 깼다.
##     · 열림  — 밝은 테두리가 천천히 숨 쉰다. 누르면 들어간다.
##     · 클리어 — 흰 원 + 체크.
##   스테이지 출구에 닿으면 장면전환 → 게임진행.통로_가로채기 가 클리어를 적고 이 화면으로 돌아온다.
##   전부 깨면 "쳅터 2 클리어" 띠와 [다음 쳅터 →] 가 나온다(쳅터 3 이 아직 없으면 "준비 중").
##
## ▣ 씬 파일(scenes/lobby/쳅터2_지도.tscn)은 이 스크립트를 단 Control 하나뿐이다.
##   화면은 전부 여기서 조립한다(로비와 같은 방식 — 씬 병합 충돌이 안 난다).
##
## ▣ 개발 편의: 디버그 빌드에서 **Ctrl+클릭** 하면 잠긴 칸도 들어간다(2-11 만 시험할 때).
## ============================================================================

const 기준 := Vector2(1152, 648)       ## 지도 좌표의 기준 해상도(로비와 같다)
const 칸_반지름 := 30.0

var _칸들: Dictionary = {}             ## 이름표 → 칸버튼
var _선판: Control
var _안내: Label
var _진행글: Label
var _시간 := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_바탕()
	var 제목 := _글("쳅터 2  ·  지워지는 물", 44, Vector2(0, 26))
	제목.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	제목.position.y = 26
	var 부제 := _글("하수도 — 길을 골라 내려가라. 한 칸을 깨면 이어진 칸이 열린다.", 18, Vector2(0, 84))
	부제.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	부제.position.y = 84
	부제.modulate = Color(1, 1, 1, 0.6)

	_선판 = Control.new()
	_선판.name = "선"
	_선판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_선판.set_anchors_preset(Control.PRESET_FULL_RECT)
	_선판.draw.connect(_선_그리기)
	add_child(_선판)

	for 칸 in 게임진행.하수도_지도:
		var b := 칸버튼.new()
		b.이름표 = 칸[0]
		b.pressed.connect(_칸_누름.bind(String(칸[0])))
		b.mouse_entered.connect(_칸_안내.bind(String(칸[0])))
		b.focus_entered.connect(_칸_안내.bind(String(칸[0])))
		add_child(b)
		_칸들[칸[0]] = b

	_안내 = _글("", 22, Vector2.ZERO)
	_안내.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_안내.position.y -= 70
	_진행글 = _글("", 20, Vector2.ZERO)
	_진행글.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_진행글.position += Vector2(-200, 30)

	var 뒤로 := Button.new()
	뒤로.text = "←  로비"
	뒤로.add_theme_font_size_override("font_size", 20)
	뒤로.position = Vector2(24, 24)
	뒤로.pressed.connect(_로비로)
	add_child(뒤로)

	get_viewport().size_changed.connect(_배치)
	_배치()
	_상태_갱신()
	# 방금 깬 칸(또는 첫 열린 칸)에 초점 — 키보드로도 고를 수 있다
	var 초점 := 게임진행.마지막_칸
	if 초점.is_empty() or not _칸들.has(초점):
		for 칸 in 게임진행.하수도_지도:
			if 게임진행.열림(칸[0]) and not 게임진행.클리어함(칸[0]):
				초점 = 칸[0]
				break
	if _칸들.has(초점):
		(_칸들[초점] as Button).grab_focus()
		_칸_안내(초점)
	if 게임진행.쳅터2_전부_클리어():
		_완료_띠()


func _process(delta: float) -> void:
	_시간 += delta
	for b in _칸들.values():
		(b as 칸버튼).시간 = _시간
		(b as Control).queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_로비로()


## 화면 크기에 맞춰 칸 자리를 다시 잡는다(기준 1152×648 비율 그대로 늘인다).
func _배치() -> void:
	var 크기 := get_viewport_rect().size
	var 여백 := Vector2(80, 150)
	var 판 := 크기 - 여백 * 2.0 - Vector2(0, -40)
	for 칸 in 게임진행.하수도_지도:
		var b: Control = _칸들[칸[0]]
		var 위치: Vector2 = 칸[2]
		b.position = 여백 + 위치 * 판 - b.size * 0.5
	_선판.queue_redraw()


func _상태_갱신() -> void:
	for 이름 in _칸들:
		var b: 칸버튼 = _칸들[이름]
		b.상태 = 2 if 게임진행.클리어함(이름) else (1 if 게임진행.열림(이름) else 0)
		b.tooltip_text = "%s · %s" % [이름, 게임진행.하수도_이름.get(이름, "")]
	_진행글.text = "클리어  %d / %d" % [게임진행.클리어_수(), 게임진행.하수도_지도.size()]
	_선판.queue_redraw()


func _칸_안내(이름: String) -> void:
	var 상태글 := "클리어" if 게임진행.클리어함(이름) else ("열림 — 눌러서 들어가기" if 게임진행.열림(이름) else "잠김 — 이어진 앞 칸을 먼저 깨야 한다")
	_안내.text = "%s  「%s」   %s" % [이름, 게임진행.하수도_이름.get(이름, ""), 상태글]


func _칸_누름(이름: String) -> void:
	var 열 := 게임진행.열림(이름)
	if not 열 and not (OS.is_debug_build() and Input.is_key_pressed(KEY_CTRL)):
		_칸_안내(이름)
		(_칸들[이름] as 칸버튼).흔들기 = 0.35
		return
	게임진행.지도_모드 = 2
	게임진행.마지막_칸 = 이름
	StageTransition.change_scene(self, 게임진행.씬경로(게임진행.칸_찾기(이름)))


func _로비로() -> void:
	게임진행.지도_모드 = 0
	StageTransition.change_scene(self, 게임진행.로비_씬)


## 전부 깼을 때 — 다음 쳅터로. 챕터표에 쳅터 3 스테이지가 생기면 바로 그리로 간다.
func _완료_띠() -> void:
	# 화면 아래쪽 가운데. 앵커 없이 트리에 먼저 붙이고 크기·자리를 준다
	#   (앵커 프리셋을 트리 밖에서 걸면 크기 0 으로 남아 안 보였다 — 10-06 촬영에서 확인).
	var 띠 := ColorRect.new()
	띠.color = Color(0.92, 0.92, 0.92, 0.94)
	add_child(띠)
	띠.size = Vector2(620, 128)
	띠.position = Vector2((get_viewport_rect().size.x - 띠.size.x) * 0.5, get_viewport_rect().size.y - 띠.size.y - 14.0)
	_안내.visible = false
	var 글 := Label.new()
	글.text = "쳅터 2 클리어 — 하수도를 빠져나왔다"
	글.add_theme_font_size_override("font_size", 28)
	글.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	글.position = Vector2(30, 18)
	띠.add_child(글)
	var 다음 := Button.new()
	다음.text = "다음 쳅터  →"
	다음.add_theme_font_size_override("font_size", 22)
	다음.position = Vector2(30, 72)
	띠.add_child(다음)
	다음.pressed.connect(func() -> void:
		var 경로 := ""
		for s in 챕터.스테이지표:
			if int(s["챕터"]) == 3:
				경로 = String(s["씬"])
				break
		if 경로.is_empty() or not ResourceLoader.exists(경로):
			글.text = "쳅터 3 「올라가는 도시」 는 아직 준비 중이다"
			다음.text = "로비로"
			다음.pressed.connect(_로비로)
			return
		게임진행.지도_모드 = 0
		StageTransition.change_scene(self, 경로))


# ── 그림 ─────────────────────────────────────────────────────────────────────
func _바탕() -> void:
	var 판 := ColorRect.new()
	판.name = "바탕"
	판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	판.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	# 하수도 벽돌 + 아래로 갈수록 짙어지는 물빛. TIME 대신 정지 화면(에디터 GPU 상시 사용 금지 규칙 — 09-30 기록).
	sh.code = """
shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 px = UV * vec2(1152.0, 648.0);
	float row = floor(px.y / 28.0);
	vec2 b = vec2(px.x / 64.0 + mod(row, 2.0) * 0.5, px.y / 28.0);
	vec2 f = fract(b);
	float joint = step(f.x, 0.04) + step(f.y, 0.07);
	float tone = 0.11 + 0.035 * h(floor(b));
	tone = mix(tone, 0.05, clamp(joint, 0.0, 1.0));
	float depth = smoothstep(0.0, 1.0, UV.y);
	vec3 c = vec3(tone) * mix(1.0, 0.55, depth) + vec3(0.0, 0.012, 0.02) * depth;
	float v = smoothstep(0.35, 0.95, distance(UV, vec2(0.5)));
	COLOR = vec4(c * (1.0 - v * 0.6), 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	판.material = m
	add_child(판)


func _글(내용: String, 크기: int, 위치: Vector2) -> Label:
	var l := Label.new()
	l.text = 내용
	l.position = 위치
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 크기)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## 칸 사이 선: 앞 칸을 깼으면 밝은 실선(이미 열린 길), 아니면 어두운 점선(아직 닫힌 길).
func _선_그리기() -> void:
	for 칸 in 게임진행.하수도_지도:
		var 끝: Control = _칸들[칸[0]]
		var b := 끝.position + 끝.size * 0.5
		for 앞 in 칸[3]:
			var 시작: Control = _칸들[앞]
			var a := 시작.position + 시작.size * 0.5
			var 방향 := (b - a).normalized()
			a += 방향 * 칸_반지름
			b -= 방향 * 칸_반지름
			if 게임진행.클리어함(String(앞)):
				_선판.draw_line(a, b, Color(0.05, 0.05, 0.05, 0.9), 7.0, true)
				_선판.draw_line(a, b, Color(0.86, 0.86, 0.86, 0.95), 3.0, true)
			else:
				var 길이 := a.distance_to(b)
				var t := 0.0
				while t < 길이:
					_선판.draw_line(a + 방향 * t, a + 방향 * minf(t + 10.0, 길이), Color(0.45, 0.45, 0.45, 0.55), 2.0, true)
					t += 18.0
			b = 끝.position + 끝.size * 0.5


## 지도 위 칸 하나. Button 이라 마우스·키보드·초점이 공짜로 된다 — 그림만 직접 그린다.
class 칸버튼 extends Button:
	var 이름표 := ""
	var 상태 := 0            ## 0 잠김 · 1 열림 · 2 클리어
	var 시간 := 0.0
	var 흔들기 := 0.0

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(76, 96)
		size = custom_minimum_size
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		흔들기 = maxf(흔들기 - delta, 0.0)

	func _draw() -> void:
		var r := 30.0
		var c := Vector2(size.x * 0.5, r + 4.0)
		if 흔들기 > 0.0:
			c.x += sin(흔들기 * 60.0) * 4.0
		var 강조 := has_focus() or is_hovered()
		match 상태:
			0:
				draw_circle(c, r, Color(0.08, 0.08, 0.08))
				draw_arc(c, r, 0, TAU, 40, Color(0.32, 0.32, 0.32), 2.0, true)
				# 자물쇠 — 몸통 + 고리
				draw_rect(Rect2(c + Vector2(-9, -2), Vector2(18, 14)), Color(0.38, 0.38, 0.38))
				draw_arc(c + Vector2(0, -2), 6.0, PI, TAU, 12, Color(0.38, 0.38, 0.38), 2.5, true)
			1:
				var 숨 := 0.5 + 0.5 * sin(시간 * 2.6)
				draw_circle(c, r + 5.0 + 3.0 * 숨, Color(1, 1, 1, 0.08 + 0.10 * 숨))
				draw_circle(c, r, Color(0.16, 0.16, 0.16))
				draw_arc(c, r, 0, TAU, 48, Color(0.92, 0.92, 0.92), 3.0, true)
			2:
				draw_circle(c, r, Color(0.9, 0.9, 0.9))
				draw_arc(c, r, 0, TAU, 48, Color(0.05, 0.05, 0.05), 3.0, true)
				# 체크 표시
				draw_polyline(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-3, 9), c + Vector2(13, -9)]), Color(0.05, 0.05, 0.05), 4.0, true)
		if 강조:
			draw_arc(c, r + 9.0, 0, TAU, 48, Color(1, 1, 1, 0.85), 2.0, true)
		var 글꼴 := get_theme_default_font()
		var 글색 := Color(0.95, 0.95, 0.95) if 상태 > 0 else Color(0.5, 0.5, 0.5)
		draw_string(글꼴, Vector2(0, r * 2.0 + 26.0), 이름표, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 글색)
