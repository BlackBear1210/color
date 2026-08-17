extends Control
## ============================================================================
## [2026-07-24 도형 · 신규] 스테이지 HUD — 플랫폼 색칠(v3) 전용 붓 커서 UI
## ----------------------------------------------------------------------------
## brush_cursor_ui.gd(v2)는 "타일맵 셀"을 가리켰다. v3 는 색칠 단위가 플랫폼이라
## 마우스가 가리키는 **플랫폼 전체**에 남은 횟수를 띄워야 한다 → 별도 파일로 신설.
## (v2 는 zone_01/02/world_1 이 그대로 쓰고 있으므로 건드리지 않는다)
##
## ▣ 표시하는 것
##   · 붓 커서 (마우스 = 붓)
##   · 가리킨 플랫폼 위에 "x2" 처럼 남은 명중 횟수 + 플랫폼 외곽 하이라이트
##   · 반대색 완성 발판 위 = ⚠ (쏘면 회색이 된다는 경고) / 회색 위 = ✕
##   · 다음에 E 로 회수될 플랫폼 위 = 파란 E 마커
##   · 화면 중앙 안내 메시지 / 좌상단 스테이지 이름·사망 횟수
## ============================================================================
class_name StageHUD

const BRUSH_CURSOR_PATH := "res://assets/textures/ui/brush_cursor.svg"
const 팝업수명: float = 0.9
const 메시지수명: float = 2.0

var _player: Node
var _매니저: PaintManager
var 스테이지이름: String = ""
var 사망수: int = 0
## 좌상단 "↩ 회수대기 N" 을 띄울지. 타일맵 페인트 스테이지에서는 꺼야 한다(위 _draw 주석 참고).
var 회수대기_표시: bool = true

var _팝업들: Array[Dictionary] = []      ## { pos:Vector2(월드), text:String, color:Color, age:float }
var _메시지: String = ""
var _메시지나이: float = 0.0

func setup(player: Node, 매니저: PaintManager) -> void:
	_player = player
	_매니저 = 매니저
	for n in get_tree().get_nodes_in_group("paint_platform"):
		var p := n as PaintPlatform
		if p and not p.명중됨.is_connected(_명중):
			p.명중됨.connect(_명중)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var brush := load(BRUSH_CURSOR_PATH)
	if brush:
		# 핫스팟 = 붓끝(좌하단) — 조준점이 붓끝이 되도록
		Input.set_custom_mouse_cursor(brush, Input.CURSOR_ARROW, Vector2(3, 25))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func 메시지(글: String) -> void:
	_메시지 = 글
	_메시지나이 = 0.0

func _명중(플랫폼: PaintPlatform, 결과: String, _색: int, 좌표: Vector2) -> void:
	var 글 := ""
	var c := Color(0.9, 0.9, 0.9)
	match 결과:
		"progress":
			글 = "x%d" % maxi(플랫폼.필요횟수() - 플랫폼._맞은횟수, 0)
		"painted":
			글 = "칠해짐!"
			c = Color(0.35, 0.95, 0.5)
		"mixed_gray":
			글 = "회색 (영구)"
			c = Color(0.85, 0.55, 0.2)
		"wasted":
			글 = "이미 같은 색"
			c = Color(0.7, 0.7, 0.7)
		"blocked":
			글 = "칠할 수 없음"
			c = Color(0.7, 0.4, 0.4)
	_팝업들.append({ "pos": 좌표, "text": 글, "color": c, "age": 0.0 })

func _process(delta: float) -> void:
	for p in _팝업들:
		p["age"] += delta
	_팝업들 = _팝업들.filter(func(p): return p["age"] < 팝업수명)
	if _메시지 != "":
		_메시지나이 += delta
		if _메시지나이 > 메시지수명:
			_메시지 = ""
	queue_redraw()

## 마우스 아래에 있는 칠 가능 플랫폼 찾기 (물리 조회 없이 사각형 포함 검사 —
## 플랫폼 수가 스테이지당 수십 개 규모라 이 편이 단순하고 충분히 빠르다)
func _마우스_아래_플랫폼() -> PaintPlatform:
	var m := get_global_mouse_position()
	for n in get_tree().get_nodes_in_group("paint_platform"):
		var p := n as PaintPlatform
		if p == null or not is_instance_valid(p):
			continue
		var 크기 := p.크기_px()
		var 로컬 := p.to_local(m)
		if absf(로컬.x) <= 크기.x * 0.5 and absf(로컬.y) <= 크기.y * 0.5:
			return p
	return null

func _화면(월드: Vector2) -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform() * 월드

func _draw() -> void:
	var 폰트 := ThemeDB.fallback_font
	var 크기_pt := 16

	# ── 좌상단: 스테이지 이름 · 사망 횟수 · 회수 대기 수 ──
	var 머리 := "%s    💀 %d" % [스테이지이름, 사망수]
	# ⚠[2026-08-17] 타일맵 페인트 스테이지에서는 색칠을 TilePaintMap 이 하고 이 매니저의
	#   큐는 **항상 비어 있다** → "회수대기 0" 이 굳어 있어 거짓말이 된다.
	#   그쪽은 점 HUD(페인트_HUD.gd)가 회수 상태를 대신 보여주므로 여기서는 감춘다.
	if _매니저 and 회수대기_표시:
		머리 += "    ↩ 회수대기 %d" % _매니저.큐_크기()
	_글자_외곽(폰트, Vector2(18, 30), 머리, 18, Color(0.95, 0.95, 0.95))

	# ── 마우스가 가리킨 플랫폼 ──
	var 대상 := _마우스_아래_플랫폼()
	if 대상:
		var 색: int = _player.get("player_color") if _player else ColorDefs.BLACK
		var 남 := 대상.남은횟수(색)
		var 중심 := _화면(대상.global_position)
		var 크기 := 대상.크기_px()
		# 플랫폼 외곽 하이라이트 (지금 조준 중인 대상이 무엇인지 명확히)
		var 사각 := Rect2(중심 - 크기 * 0.5, 크기)
		draw_rect(사각, Color(0.2, 0.2, 0.2, 0.9), false, 3.0)
		draw_rect(사각, Color(1, 1, 1, 0.55), false, 1.0)
		var 글 := ""
		var c := Color(1, 1, 1)
		if 남 > 0:
			글 = "x%d" % 남
		elif 대상.현재상태 == PaintPlatform.상태.회색:
			글 = "✕"
			c = Color(0.75, 0.75, 0.75)
		elif 대상.반대색인가(색):
			글 = "⚠"
			c = Color(0.95, 0.65, 0.2)
		else:
			글 = "●"                      # 이미 내 색 = 칠할 이유 없음
			c = Color(0.6, 0.85, 0.6)
		_글자_외곽(폰트, 중심 + Vector2(-10, -크기.y * 0.5 - 12), 글, 22, c)

	# ── 다음 회수 대상 표시 ──
	if _매니저:
		var 다음 := _매니저.다음_회수_대상()
		if 다음 and is_instance_valid(다음):
			var p := _화면(다음.global_position)
			var r := 다음.크기_px()
			draw_rect(Rect2(p - r * 0.5, r), Color(0.35, 0.6, 1.0, 0.55), false, 2.0)
			_글자_외곽(폰트, p + Vector2(-6, 6), "E", 20, Color(0.55, 0.75, 1.0))

	# ── 탄착 팝업 ──
	for pop in _팝업들:
		var t: float = pop["age"] / 팝업수명
		var pos := _화면(pop["pos"]) + Vector2(-14, -18 - t * 26.0)
		var c: Color = pop["color"]
		c.a = 1.0 - t
		_글자_외곽(폰트, pos, pop["text"], 17, c)

	# ── 중앙 메시지 ──
	# ⚠[2026-07-24] Control 의 size 는 런타임에 붙인 직후 0 이라 글자가 화면 왼쪽에 붙어버렸다
	#   (첫 스크린샷에서 확인). 뷰포트 크기를 직접 읽고, 글자 폭만큼 정확히 가운데 정렬한다.
	if _메시지 != "":
		var 화면폭 := get_viewport_rect().size.x
		var 글폭 := 폰트.get_string_size(_메시지, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var a := clampf(1.0 - _메시지나이 / 메시지수명, 0.0, 1.0)
		_글자_외곽(폰트, Vector2((화면폭 - 글폭) * 0.5, 108), _메시지, 22,
			Color(1, 1, 1, a), Color(0, 0, 0, a * 0.9))

## 흑/백 어느 배경에서도 읽히도록 검은 외곽선을 두르고 쓴다 (16차 조준선과 같은 원칙)
func _글자_외곽(폰트: Font, pos: Vector2, 글: String, 크기: int,
		색: Color, 외곽: Color = Color(0, 0, 0, 0.9)) -> void:
	for d in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_string(폰트, pos + d, 글, HORIZONTAL_ALIGNMENT_LEFT, -1, 크기, 외곽)
	draw_string(폰트, pos, 글, HORIZONTAL_ALIGNMENT_LEFT, -1, 크기, 색)
