extends CanvasLayer
## 구체 하나와 가용 탄 수를 표시한다. 회수 표식은 기존 어댑터를 유지한다.
class_name 페인트HUD

## ⚠ 타입 참조를 class_name 이 아니라 **경로 preload** 로 잡는다.
##   새 스크립트의 전역 클래스 이름은 에디터가 한 번 훑어야 등록된다. 그 전에
##   헤드리스로 검사를 돌리면 통째로 죽는다(2026-08-17 에 검사 3개가 이 이유로 깨졌다).
const 어댑터_기반 := preload("res://scripts/ui/페인트_HUD_어댑터.gd")

## 이 HUD 씬의 경로. 월드.gd · stage_lab.gd 가 **둘 다 이 상수를 통해** 만든다.
const 씬경로 := "res://scenes/ui/페인트_HUD.tscn"

# ── 색 ──────────────────────────────────────────────────────────────────────
const 검정: Color = Color(0.07, 0.07, 0.07)
const 흰색: Color = Color(0.95, 0.95, 0.93)
## 잉크(플레이어 색)가 검정일 때 그릇 속은 밝게, 흰색일 때 어둡게 뒤집는다.
## 안 그러면 검정 잉크가 어두운 유리 속에서 통째로 사라진다.
const 속_밝음: Color = Color(0.34, 0.34, 0.34, 0.96)
const 속_어둠: Color = Color(0.09, 0.09, 0.11, 0.94)
## 금속 테는 **색을 안 뒤집는다.** 뒤집으면 초상과 게이지가 한 물건으로 안 읽힌다.
const 테_금속: Color = Color(0.91, 0.91, 0.89, 1.0)
const 테_그늘: Color = Color(0.05, 0.05, 0.06, 1.0)
## 회수 대기·잠김 표시는 플레이어 색과 무관하게 밝은 저알파로 그린다.
const 대기_링: Color = Color(0.88, 0.88, 0.85, 0.50)

## 탄약이 0 일 때 HUD 전체가 천천히 맥동한다 — "지금 못 쏜다"를 몸으로 알린다.
const 맥동_주기: float = 0.9

# 가속·방향 전환의 관성과 점성 복귀를 같은 모델로 계산해 샘플과 게임의 반응을 일치시킨다.
const 관성형 := preload("res://scripts/ui/페인트_관성.gd")
const 표시설정 := preload("res://scripts/스마트월드/게임설정.gd")
@export_enum("가벼운 페인트", "묵직한 페인트", "높은 점성") var 점성_종류: int = 1
var _관성 := 관성형.new()
var _기울기: float = 0.0
var _충격: float = 0.0
var _지난_남은: int = -1
var _마지막_채움: float = -1.0
var _탄수: Label
var _사망수: Label
var _타이머: Label
const 기록형 := preload("res://scripts/ui/실행_기록.gd")

# ── ★[2026-09-05 비주얼] 크기 · 초상 담기 ──────────────────────────────────
## ▣ 왜 배율을 새로 뒀나
##   씬에 박힌 `본체` 는 168 × 88 px 였다. 1856 × 1044 실화면으로 찍어 보니
##   화면 가로의 9 % 밖에 안 되고, 배경이 어두워서 **거기 있는지도 모른다.**
##   1.0 / 1.25 / 1.5 를 실제로 찍어 비교했고, 그 사이 값인 1.35 가
##   "멀리서도 읽히면서 화면을 안 가리는" 지점이었다(작업기록 §A).
##
## ⚠ 씬의 `본체.scale` 은 (1.0672, 1.0874) 로 **가로세로가 달랐다** — 에디터에서
##   끌다 생긴 값이고, 그래서 구가 미세하게 타원이었다.
##   → 씬은 (1, 1) 로 되돌리고 크기는 여기서 **등방 배율**로만 준다.
@export_group("크기")
@export_range(0.6, 2.5, 0.05) var 배율: float = 1.20:
	set(v):
		배율 = v
		if _본체 != null and is_instance_valid(_본체):
			_본체.scale = Vector2(배율, 배율)

# ── 배치 ────────────────────────────────────────────────────────────────────
## 본체(초상+게이지)의 화면 좌표. 씬마다 다른 HUD 가 이미 있을 수 있어 밖에서 옮길 수 있게 둔다.
## (stage_lab 계열은 StageHUD 가 좌상단 한 줄을 쓰므로 아래로 내린다)
## ★[2026-09-05] 26,20 → 34,26. 배율 1.35 로 키우고 나니 구가 화면 모서리에 거의
##   붙어서 잘린 것처럼 보였다. 1856×1044 실화면에서 찍어 보고 정한 값이다.
var 여백: Vector2 = Vector2(34, 26):
	set(v):
		여백 = v
		if _본체 != null and is_instance_valid(_본체):
			_본체.position = 여백

var _어댑터: 어댑터_기반 = null
var _플레이어: Node = null
var _시간: float = 0.0
## 마우스가 안 움직이면 호버 판정(물리 조회)을 다시 하지 않는다.
var _마지막_마우스: Vector2 = Vector2(-9999, -9999)
var _호버대상: Variant = null

# 씬 노드들
var _본체: Control = null
var _눈금: Control = null
var _월드표식: Control = null
var _게이지_뒤: CanvasItem = null
var _게이지_앞: CanvasItem = null
var _액체: CanvasItem = null


## 스테이지가 부른다. 어댑터가 없으면 아무것도 그리지 않는다.
func 연결(플레이어: Node, 어댑터: 어댑터_기반) -> void:
	_플레이어 = 플레이어
	_어댑터 = 어댑터


func _ready() -> void:
	# 핵심 자원 정보는 비네트(50)에 가려지면 안 되므로 일반 화면 효과보다 위에 고정한다.
	layer = 100
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_숫자_만들기()
	add_to_group("페인트HUD_표시")
	표시_적용(표시설정.HUD_표시_불러오기())
	_본체 = get_node_or_null("루트/본체")
	_눈금 = get_node_or_null("루트/본체/게이지/눈금")
	_월드표식 = get_node_or_null("루트/월드표식")
	_게이지_뒤 = get_node_or_null("루트/본체/게이지/게이지_뒤")
	_게이지_앞 = get_node_or_null("루트/본체/게이지/게이지_앞")
	_액체 = get_node_or_null("루트/본체/게이지/액체_마스크/액체")

	if _본체:
		_본체.position = 여백
		_본체.scale = Vector2(배율, 배율)
	# 씬에 박힌 재질을 그대로 쓰면 HUD 가 두 개 뜰 때 색이 서로 덮인다 → 인스턴스마다 복제.
	for n in [_게이지_뒤, _게이지_앞, _액체]:
		if n and n.material:
			n.material = n.material.duplicate()
	# 장식·눈금·월드표식은 그림 리소스가 없어서 코드로 그린다(§아래 주석 참고).
	# 계기판처럼 보이던 큰 눈금을 제거하고 숫자로 정확한 사용 가능 수를 전달한다.
	if _눈금: _눈금.hide()
	if _월드표식: _월드표식.draw.connect(_그리기_월드표식)
	set_process(true)


func _process(delta: float) -> void:
	_시간 += delta
	_기록_갱신()
	if _어댑터 == null or not _어댑터.살아있나():
		return

	var 탄약: Dictionary = _어댑터.가용_탄약()
	_탄수.text = "× %d" % int(탄약.get("남은", 0)) if not 탄약.is_empty() else "× ∞"
	var 맥동 := 1.0
	if not 탄약.is_empty() and int(탄약.get("남은", 1)) <= 0:
		맥동 = 0.6 + 0.4 * absf(sin(_시간 * TAU / 맥동_주기))

	_액체_동역학(delta, 탄약)
	_게이지_갱신(탄약, 맥동)

	# 호버는 물리 조회라 싸지 않다 → 마우스가 실제로 움직였을 때만 다시 판정한다.
	if _월드표식:
		var m := _월드표식.get_global_mouse_position()
		if m.distance_to(_마지막_마우스) > 2.0:
			_마지막_마우스 = m
			_호버대상 = _어댑터.대상_아래(m)
		_월드표식.queue_redraw()
	if _눈금: _눈금.queue_redraw()


# ============================================================================
# 게이지 — 값은 전부 어댑터가 준 실제 탄약이다
# ============================================================================
func _게이지_갱신(탄약: Dictionary, 맥동: float) -> void:
	var 흰색차례 := _잉크색() == 흰색
	_그릇_색(_게이지_뒤, _게이지_앞, 흰색차례, 맥동, 0.62)
	var 재질 := _액체.material as ShaderMaterial if _액체 else null
	if 재질 == null:
		return

	# ⚠ 최대값을 여기서 만들지 않는다. 정식·프로토 모두 기본 7발이지만 무제한/검사 설정도
	#   어느 쪽인지는 어댑터만 안다. 탄약()이 빈 사전이면 그 시스템엔 탄약이 없다.
	var 최대 := float(탄약.get("최대", 0))
	var 남은 := float(탄약.get("남은", 0))
	if 최대 <= 0.0:
		# 탄약 개념이 없는 시스템(옛 PaintSystem) — 그릇을 비워 두고 눈금만 남긴다.
		재질.set_shader_parameter("fill_level", 0.0)
		재질.set_shader_parameter("pending_level", 0.0)
		재질.set_shader_parameter("locked_level", 0.0)
		return

	# 최대 용량에도 공기층을 남겨 가득 찬 페인트의 관성을 볼 수 있게 한다.
	# fill_level은 실제 비율 그대로이며 수면 높이는 원의 면적과 84% 용량선에서 계산한다.
	var 채움 := clampf(남은 / 최대, 0.0, 1.0)
	재질.set_shader_parameter("fill_level", 채움)
	if not is_equal_approx(채움, _마지막_채움):
		_마지막_채움 = 채움
		var 아래 := -1.0
		var 위 := 1.0
		for i in 14:
			var y := (아래 + 위) * 0.5
			var 면적 := (acos(y) - y * sqrt(maxf(0.0, 1.0 - y * y))) / PI
			if 면적 > 채움 * 0.84:
				아래 = y
			else:
				위 = y
		재질.set_shader_parameter("surface_height", (아래 + 위) * 0.5)
	_수면_폴리곤_갱신(재질, 채움)
	var 잉크 := _잉크색()
	재질.set_shader_parameter("liquid_color", Color(잉크.r, 잉크.g, 잉크.b, 맥동))
	# 수면 하이라이트는 잉크의 반대 톤 — 검정 잉크에 흰 선, 흰 잉크에 검은 선.
	재질.set_shader_parameter("foam_color",
		Color(0.05, 0.05, 0.06, 0.60 * 맥동) if 흰색차례 else Color(1.0, 1.0, 0.98, 0.55 * 맥동))


# ============================================================================
# 액체 동역학 — 기울기(관성) · 충격 · 잔물결
# ----------------------------------------------------------------------------
# ⚠ 여기서 만드는 값은 전부 **보이는 것**뿐이다. 탄약(fill_level)은 손대지 않는다.
#   실제 자원과 연출을 섞으면 "게이지가 실제 탄약과 다르다"는 최악의 버그가 된다.
# ============================================================================
func _수면_폴리곤_갱신(재질: ShaderMaterial, 채움: float) -> void:
	if not _액체 is Polygon2D:
		return
	# 셰이더와 동일한 33개 실제 수면 정점을 사용한다. 원형 마스크 밖의 하단은 잘린다.
	var 수면 := float(재질.get_shader_parameter("surface_height"))
	var 폭 := sqrt(maxf(0.0, 1.0 - 수면 * 수면))
	var 점 := PackedVector2Array()
	var 각도 := _관성.기울기 * 0.78
	for i in _관성.파동.개수:
		var x := -1.0 + 2.0 * i / (_관성.파동.개수 - 1)
		var 타원 := sqrt(maxf(0.0, 1.0 - pow(x / maxf(폭, 0.01), 2.0))) * 폭 * 0.12
		var q := Vector2(x, 수면 + _관성.파동.높이[i] - 타원 - 0.012)
		점.append((q.rotated(각도) + Vector2.ONE) * 36.0)
	for q in [Vector2(1, 2), Vector2(-1, 2)]:
		점.append((q.rotated(각도) + Vector2.ONE) * 36.0)
	_액체.polygon = 점
	_액체.visible = 채움 > 0.0
	재질.set_shader_parameter("wave_heights", _관성.파동.높이)


func _액체_동역학(delta: float, 탄약: Dictionary) -> void:
	var 재질 := _액체.material as ShaderMaterial if _액체 else null
	if 재질 == null:
		return
	var 속도 := Vector2.ZERO
	var 착지 := true
	if is_instance_valid(_플레이어):
		if _플레이어.get("velocity") is Vector2:
			속도 = _플레이어.get("velocity")
		if _플레이어 is CharacterBody2D:
			착지 = _플레이어.is_on_floor()
	_관성.종류 = 점성_종류
	# 실제 걷기 시트의 두 발 주기로 수면을 구동해 고정 속도로 걸을 때도 내부 페인트가 움직인다.
	var 보행위상 := -1.0
	var 시트 := _플레이어.get_node_or_null("CharacterSprite") as AnimatedSprite2D if is_instance_valid(_플레이어) else null
	if 시트 != null and String(시트.animation).ends_with("_walk"):
		var 개수 := 시트.sprite_frames.get_frame_count(시트.animation)
		보행위상 = (시트.frame + 시트.frame_progress) * TAU * 2.0 / maxf(1.0, float(개수))
	_관성.갱신(delta, 속도, 착지, 보행위상)
	var 남은 := int(탄약.get("남은", -1))
	if 남은 >= 0 and _지난_남은 >= 0 and 남은 != _지난_남은:
		_관성.충격_추가(0.65 if 남은 < _지난_남은 else 0.36)
	_지난_남은 = 남은
	_기울기 = _관성.기울기
	_충격 = _관성.충격
	# 자체 시간만 전달하므로 ESC 중 표면·벽면 페인트막·재질 흐름까지 모두 멈춘다.
	재질.set_shader_parameter("animation_time", _관성.위상)
	재질.set_shader_parameter("slosh_amount", _기울기)
	재질.set_shader_parameter("wall_slosh", _관성.벽면_기울기)
	재질.set_shader_parameter("surface_lag", _관성.표면_지연)
	재질.set_shader_parameter("flow_energy", _관성.흐름)
	재질.set_shader_parameter("impact_shock", _충격)


## 그릇(초상 원반 · 게이지 구)의 색을 한 곳에서 정한다.
func _그릇_색(뒤: CanvasItem, 앞: CanvasItem, 흰색차례: bool, 맥동: float, 깊이: float) -> void:
	var 속 := 속_어둠 if 흰색차례 else 속_밝음
	if 뒤 and 뒤.material is ShaderMaterial:
		var m := 뒤.material as ShaderMaterial
		m.set_shader_parameter("inner_color", Color(속.r, 속.g, 속.b, 속.a * 맥동))
		m.set_shader_parameter("depth", 깊이)
	if 앞 and 앞.material is ShaderMaterial:
		var m2 := 앞.material as ShaderMaterial
		m2.set_shader_parameter("rim_color", Color(테_금속.r, 테_금속.g, 테_금속.b, 맥동))
		m2.set_shader_parameter("rim_dark", 테_그늘)
	elif 앞 is TextureRect:
		# 힉스필드 금속 테는 움직이지 않고, 빈 탄창의 맥동만 기존 HUD와 함께 받는다.
		앞.modulate = Color(1, 1, 1, 맥동)


# ============================================================================
# 코드로 그리는 것 — 장식선 · 눈금 · 월드 표식
# ----------------------------------------------------------------------------
# ⚠ 이것들은 **그림 리소스가 없어서** 코드로 그린다. `assets/textures/ui/` 에는
#   brush_cursor.svg 하나뿐이라 재사용할 UI 아트가 프로젝트에 존재하지 않는다.
#   (원화가 들어오면 이 세 함수를 TextureRect 로 갈아끼우면 된다 — 씬만 고치면 끝)
# ============================================================================

## 용량 눈금 — 100 / 75 / 50 / 25 / 0 %. **숫자는 안 쓴다.**
## 구 오른쪽 바깥에 짧은 선으로만 둔다(참고 시안과 같은 자리).
func _그리기_눈금() -> void:
	var c := _눈금
	var 크기 := c.size
	var 중심 := 크기 * 0.5
	var r := 크기.x * 0.5
	var 색 := Color(테_금속.r, 테_금속.g, 테_금속.b, 0.75)
	var 그늘 := Color(테_그늘.r, 테_그늘.g, 테_그늘.b, 0.85)
	# 눈금은 **구 안쪽** 오른편에 둔다. 밖에 두면 유리구와 따로 노는 부품처럼 보인다.
	for i in 5:
		var t := float(i) / 4.0                      # 0 = 바닥, 1 = 가득
		var y := 중심.y + r * (0.5 - t) * 1.30        # 액체가 차는 세로 범위에 맞춘다
		# 100 / 50 / 0 % 만 길게 — 눈이 먼저 잡을 기준선을 만든다
		var 긺 := 10.0 if (i == 0 or i == 2 or i == 4) else 6.0
		# 그 높이에서 원의 반너비. 눈금이 유리 밖으로 삐져나가지 않게 끝을 안쪽으로 물린다.
		var dy := absf(y - 중심.y)
		var 반너비 := sqrt(maxf(r * r - dy * dy, 0.0)) * 0.86
		var x1 := 중심.x + 반너비
		var x0 := x1 - 긺
		if x0 <= 중심.x + r * 0.18:
			continue
		c.draw_line(Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), 그늘, 2.4, true)
		c.draw_line(Vector2(x0, y), Vector2(x1, y), 색, 1.4, true)


## 다음에 E 로 회수될 대상 위의 마커 + 마우스를 얹은 대상의 발수.
## ★[유지] 이건 예전 HUD 의 기능 그대로다. 캡슐 바와 얼굴 배지만 지웠다 —
##   이 마커가 없으면 E 는 "무엇이 풀릴지 모르고 누르는 키"가 된다.
func _그리기_월드표식() -> void:
	if _어댑터 == null or not _어댑터.살아있나():
		return
	var 대상: Variant = _어댑터.다음_회수대상()
	if 대상 != null and _어댑터.유효한가(대상):
		var 화면 := _화면좌표(_어댑터.대상_좌표(대상))
		if _화면안(화면):
			var 중심 := 화면 + Vector2(0, -34)
			# 마커는 항상 같은 밝기다 — 플레이어 색을 따라가면 배경에 묻히는 조합이 생긴다.
			_월드표식.draw_circle(중심, 13.0, Color(0.04, 0.04, 0.04, 0.62))
			_월드표식.draw_circle(중심, 11.0, 흰색)
			var 폰트 := ThemeDB.fallback_font
			var 글크기 := 15
			var 폭 := 폰트.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, 글크기).x
			_월드표식.draw_string(폰트, 중심 + Vector2(-폭 * 0.5, 5), "E",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 글크기, 검정)
			_작은점들(중심 + Vector2(0, 17), _어댑터.대상_발수(대상), 대기_링)

	if _호버대상 != null and _어댑터.유효한가(_호버대상):
		var 발수 := _어댑터.대상_발수(_호버대상)
		if 발수 > 0:
			var 화면2 := _화면좌표(_어댑터.대상_좌표(_호버대상))
			if _화면안(화면2):
				_작은점들(화면2 + Vector2(0, -20), 발수, 흰색)


## 작은 점을 가로로 나열한다 (마커·호버 공용). 가운데 정렬.
func _작은점들(중심: Vector2, 개수: int, 색: Color) -> void:
	if 개수 <= 0:
		return
	var r := 3.4
	var 간격 := 10.0
	var 시작 := 중심.x - (개수 - 1) * 간격 * 0.5
	for i in 개수:
		var p := Vector2(시작 + i * 간격, 중심.y)
		_월드표식.draw_circle(p, r + 1.8, Color(0.04, 0.04, 0.04, 0.62))
		_월드표식.draw_circle(p, r, 색)


# ── 잡일 ────────────────────────────────────────────────────────────────────

## ★HUD 가 쓰는 유일한 색 상태. `player_color`(대표색)가 아니라 `자유색` 이다.
##   대표색은 몸이 색 경계에 걸칠 때마다 매 물리 프레임 덮어써지는 파생값이라
##   HUD 가 읽으면 경계 지형 위에서 초상·게이지가 깜빡인다.
func _잉크색() -> Color:
	if _플레이어 == null or not is_instance_valid(_플레이어):
		return 검정
	var 값: int = ColorDefs.BLACK
	if _플레이어.has_method("선택색"):
		값 = int(_플레이어.call("선택색"))
	else:
		# 옛 Player 씬(선택색이 없는 것)도 최소한 돌아가게 둔다.
		값 = int(_플레이어.get("player_color"))
	return 검정 if 값 == ColorDefs.BLACK else 흰색


## 월드 → 화면. 카메라가 움직여도 마커가 대상에 붙어 있어야 한다.
func _화면좌표(월드: Vector2) -> Vector2:
	return _월드표식.get_viewport().get_canvas_transform() * 월드


## 화면 밖 마커는 그리지 않는다 (가장자리에 눌어붙어 보이는 걸 막는다).
func _화면안(화면: Vector2) -> bool:
	var 크기 := _월드표식.get_viewport_rect().size
	return 화면.x > -40.0 and 화면.y > -40.0 and 화면.x < 크기.x + 40.0 and 화면.y < 크기.y + 40.0

## 숫자와 타이머는 화면 크기에 맞춰 위치만 조정하고 글자 크기는 고정해 읽기 쉽게 둔다.
func _숫자_만들기() -> void:
	var 루트 := get_node("루트") as Control
	_탄수 = _라벨(32)
	_사망수 = _라벨(23)
	_타이머 = _라벨(28)
	for 항목 in [_탄수, _사망수, _타이머]:
		루트.add_child(항목)
	_타이머.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_숫자_배치)
	_숫자_배치()

func _라벨(크기: int) -> Label:
	var 결과 := Label.new()
	결과.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 가변 폰트의 기본 굵기는 너무 얇아 어두운 게임 화면에서 숫자가 흐려진다.
	var 숫자폰트 := FontVariation.new()
	숫자폰트.base_font = preload("res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf")
	숫자폰트.variation_opentype = {"wght": 600.0}
	숫자폰트.variation_embolden = 0.5
	결과.add_theme_font_override("font", 숫자폰트)
	결과.add_theme_font_size_override("font_size", 크기)
	결과.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	결과.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	결과.add_theme_constant_override("outline_size", 5)
	return 결과

func _숫자_배치() -> void:
	var 폭 := get_viewport().get_visible_rect().size.x
	_탄수.position = 여백 + Vector2(104, 16)
	_탄수.size = Vector2(110, 50)
	# 작은 화면에서는 사망 수를 탄 수 아래에 두어 중앙 타이머와 충돌하지 않는다.
	_사망수.position = 여백 + (Vector2(218, 27) if 폭 >= 1000 and _탄수.visible else Vector2(104, 62 if _탄수.visible else 27))
	_사망수.size = Vector2(145, 40)
	_타이머.position = Vector2(폭 * 0.5 - 100, 30)
	_타이머.size = Vector2(200, 48)

func _기록_갱신() -> void:
	var 기록 := get_parent().get_node_or_null("실행기록")
	if 기록:
		_사망수.text = "사망  %d" % 기록.사망
		_타이머.text = 기록형.시간_문자(기록.경과)
	else:
		_사망수.text = "사망  —"
		_타이머.text = 기록형.시간_문자(_시간)

## 세 숫자의 표시만 변경한다. 숨긴 동안에도 관성과 실행 기록의 계산은 계속된다.
func 표시_적용(표시: Dictionary) -> void:
	if not is_instance_valid(_탄수):
		return
	_탄수.visible = bool(표시.get("탄수", true))
	_사망수.visible = bool(표시.get("사망수", true))
	_타이머.visible = bool(표시.get("시간", true))
	_숫자_배치()
