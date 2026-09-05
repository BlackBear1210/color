extends CanvasLayer
## ============================================================================
## [2026-09-05 전면 교체] 페인트 HUD — 캐릭터 초상 + 구형 페인트 게이지
## ----------------------------------------------------------------------------
## ▣ 무엇이 바뀌었나 (STEP 2)
##   이 파일은 예전에 **HUD 를 통째로 코드로 그렸다.**
##     · `_얼굴배지()`      draw_circle + draw_colored_polygon 으로 만든 후드 얼굴
##     · `_탄약줄_그리기()` 스타디움 캡슐 바 + 세그먼트
##   도형님 지적대로 그 얼굴 배지가 인게임에서 보이던 "이상한 캐릭터 UI"의 정체였다.
##   → **두 함수와 그 딸린 그리기 함수를 전부 지웠다.** 숨긴 게 아니라 삭제다.
##   → 대신 이 스크립트는 `scenes/ui/페인트_HUD.tscn` 의 **컨트롤러**가 되었다.
##     모양은 씬(노드 + 셰이더)이 갖고, 이 파일은 **값만 흘려보낸다.**
##
## ▣ 씬 구조 (scenes/ui/페인트_HUD.tscn)
##   페인트HUD (CanvasLayer, layer 100)
##   └ 루트 (Control)
##     ├ 본체 (Control)            ← `여백` 이 여기 위치를 정한다
##     │ ├ 장식   (Control)        ← 초상과 게이지를 잇는 장식선 (이 파일이 그린다)
##     │ ├ 초상   (Control)
##     │ │ ├ 초상_뒤   (ColorRect · HUD_구 back_pass)
##     │ │ ├ 초상_마스크 (Polygon2D · clip_children=ONLY)
##     │ │ │ └ 초상_그림 (AnimatedSprite2D · **실제 player_frames.tres**)
##     │ │ └ 초상_앞   (ColorRect · HUD_구 rim)
##     │ └ 게이지 (Control)
##     │   ├ 게이지_뒤   (ColorRect · HUD_구 back_pass)
##     │   ├ 액체_마스크 (Polygon2D · clip_children=ONLY)  ← 액체가 구 밖으로 못 나간다
##     │   │ └ 액체     (ColorRect · HUD_액체)
##     │   ├ 게이지_앞 (ColorRect · HUD_구 rim)
##     │   └ 눈금     (Control)    ← 25/50/75/100% 눈금 (이 파일이 그린다)
##     └ 월드표식 (Control)        ← E 회수 마커·호버 (예전 기능 그대로 유지)
##
## ▣ 초상은 새로 그린 그림이 아니다
##   `assets/p/player_frames.tres` — **게임이 실제로 쓰는 그 SpriteFrames** 를 그대로 쓴다.
##   원본 픽셀을 한 점도 안 고쳤고, 걷기(walk) 애니메이션을 그대로 재생한다.
##   후드·얼굴·망토 실루엣이 전부 살아 있고, 얼굴만 동그랗게 오려내지 않는다.
##
## ▣ 색의 출처 — `자유색` 하나뿐이다 (STEP 2 결정)
##   `player_color`(대표색)는 몸이 색 경계에 걸칠 때마다 매 물리 프레임 덮어써지는
##   **파생값**이라 HUD 가 읽으면 지형 위에서 깜빡인다.
##   → Shift 로 고른 실제 상태값인 `자유색` 을 읽는다. 창구는 `player.선택색()`.
##
## ▣ 탄약은 어댑터로만 읽는다
##   스마트월드(페인트코어 12발)와 타일맵(TilePaintMap 14발)은 API 가 다르다.
##   이 파일은 어느 쪽인지 **모른 채** `페인트HUD어댑터.탄약()` 만 부른다.
##   → 12 / 14 같은 숫자를 여기에 절대 적지 않는다.
## ============================================================================
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
const 속_밝음: Color = Color(0.78, 0.77, 0.74, 0.92)
const 속_어둠: Color = Color(0.09, 0.09, 0.11, 0.94)
## 금속 테는 **색을 안 뒤집는다.** 뒤집으면 초상과 게이지가 한 물건으로 안 읽힌다.
const 테_금속: Color = Color(0.60, 0.58, 0.54, 1.0)
const 테_그늘: Color = Color(0.05, 0.05, 0.06, 1.0)
## 회수 대기·잠김 표시는 플레이어 색과 무관하게 밝은 저알파로 그린다.
const 대기_링: Color = Color(0.88, 0.88, 0.85, 0.50)

## 탄약이 0 일 때 HUD 전체가 천천히 맥동한다 — "지금 못 쏜다"를 몸으로 알린다.
const 맥동_주기: float = 0.9

# ── ★[2026-09-05 STEP 3] 액체 동역학 ────────────────────────────────────────
## ▣ 무엇을 노렸나 (도형님 §5)
##   "물처럼 출렁이는 느낌"이 아니라 **"무거운 잉크가 관성으로 천천히 흔들리는 느낌"**.
##   그래서 값이 전부 작다. 크게 흔들면 다크 판타지가 아니라 젤리가 된다.
##
## ⚠ 이 효과는 **`fill_level` 을 절대 안 건드린다.** 채움 높이는 언제나 어댑터가 준
##   실제 탄약 그대로다(도형님 §7·§9). 여기서 움직이는 것은 수면의 기울기·잔물결뿐이다.

@export_group("액체 동역학")
## 가만히 있을 때의 잔물결. "눈치채면 움직이는" 정도만.
@export var 잔물결_크기: float = 0.006
@export var 잔물결_주기: float = 1.4
@export var 잔물결_속도: float = 0.45
## 좌우 이동으로 수면이 최대 얼마나 기우나(셰이더 단위). 0.10 이면 눈에 겨우 보인다.
@export var 이동_기울기: float = 0.085
## ★기울기 방향. 기본 +1 = **관성**(오른쪽으로 가면 잉크가 왼쪽에 쏠려 왼쪽이 높아진다).
##   도형님 시안의 "오른쪽 이동 시 액체가 왼쪽으로 기울어짐" 과 같은 방향이고,
##   지시서 §7 의 "액체가 아주 조금 **늦게 따라오는** 느낌" 도 관성을 말한다.
##
## ⚠ 부호가 헷갈리기 쉬워서 셰이더 식을 그대로 적어 둔다.
##   `HUD_액체.gdshader` 의 수면 높이는 `surface += (x - 0.5) * slosh_amount * 0.5` 이고
##   UV.y 는 **아래로 갈수록 커진다.** 그래서
##     slosh > 0 → 오른쪽 수면이 아래로 → **왼쪽이 높다**(관성)
##     slosh < 0 → 오른쪽이 높다(진행 방향으로 쏠림)
##   −1 로 바꾸면 즉시 뒤집힌다. 인스펙터에서 두 방향을 다 보고 고르면 된다.
@export_enum("관성 (뒤로 쏠림):1", "따라감 (앞으로 쏠림):-1") var 기울기_방향: int = 1
## 잉크가 목표 기울기를 따라잡는 속도. 낮을수록 무겁고 느리다.
@export var 기울기_추종: float = 3.2
## 발사(탄약 감소)로 생기는 충격의 감쇠 속도. 클수록 짧게 튄다.
@export var 충격_감쇠: float = 5.0
## 플레이어 속도를 1.0 으로 볼 기준(px/s). player.gd 의 move_speed 와 같다.
const 기준_속도: float = 390.0

var _기울기: float = 0.0        ## 지금 수면 기울기 (셰이더로 넘어가는 값)
var _충격: float = 0.0          ## 지금 충격 세기 0~1
var _지난_남은: int = -1        ## 직전 프레임의 실제 남은 탄약 (변화 감지용)

# ── 배치 ────────────────────────────────────────────────────────────────────
## 본체(초상+게이지)의 화면 좌표. 씬마다 다른 HUD 가 이미 있을 수 있어 밖에서 옮길 수 있게 둔다.
## (stage_lab 계열은 StageHUD 가 좌상단 한 줄을 쓰므로 아래로 내린다)
var 여백: Vector2 = Vector2(26, 20):
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
var _장식: Control = null
var _눈금: Control = null
var _월드표식: Control = null
var _초상_그림: AnimatedSprite2D = null
var _초상_뒤: CanvasItem = null
var _초상_앞: CanvasItem = null
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
	_본체 = get_node_or_null("루트/본체")
	_장식 = get_node_or_null("루트/본체/장식")
	_눈금 = get_node_or_null("루트/본체/게이지/눈금")
	_월드표식 = get_node_or_null("루트/월드표식")
	_초상_그림 = get_node_or_null("루트/본체/초상/초상_마스크/초상_그림")
	_초상_뒤 = get_node_or_null("루트/본체/초상/초상_뒤")
	_초상_앞 = get_node_or_null("루트/본체/초상/초상_앞")
	_게이지_뒤 = get_node_or_null("루트/본체/게이지/게이지_뒤")
	_게이지_앞 = get_node_or_null("루트/본체/게이지/게이지_앞")
	_액체 = get_node_or_null("루트/본체/게이지/액체_마스크/액체")

	if _본체:
		_본체.position = 여백
	# 씬에 박힌 재질을 그대로 쓰면 HUD 가 두 개 뜰 때 색이 서로 덮인다 → 인스턴스마다 복제.
	for n in [_초상_뒤, _초상_앞, _게이지_뒤, _게이지_앞, _액체]:
		if n and n.material:
			n.material = n.material.duplicate()
	# 장식·눈금·월드표식은 그림 리소스가 없어서 코드로 그린다(§아래 주석 참고).
	if _장식: _장식.draw.connect(_그리기_장식)
	if _눈금: _눈금.draw.connect(_그리기_눈금)
	if _월드표식: _월드표식.draw.connect(_그리기_월드표식)
	set_process(true)


func _process(delta: float) -> void:
	_시간 += delta
	if _어댑터 == null or not _어댑터.살아있나():
		return

	var 탄약: Dictionary = _어댑터.탄약()
	var 맥동 := 1.0
	if not 탄약.is_empty() and int(탄약.get("남은", 1)) <= 0:
		맥동 = 0.6 + 0.4 * absf(sin(_시간 * TAU / 맥동_주기))

	_액체_동역학(delta, 탄약)
	_초상_갱신(맥동)
	_게이지_갱신(탄약, 맥동)

	# 호버는 물리 조회라 싸지 않다 → 마우스가 실제로 움직였을 때만 다시 판정한다.
	if _월드표식:
		var m := _월드표식.get_global_mouse_position()
		if m.distance_to(_마지막_마우스) > 2.0:
			_마지막_마우스 = m
			_호버대상 = _어댑터.대상_아래(m)
		_월드표식.queue_redraw()
	if _장식: _장식.queue_redraw()
	if _눈금: _눈금.queue_redraw()


# ============================================================================
# 초상 — 실제 플레이어 SpriteFrames 를 그대로 재생한다
# ============================================================================
func _초상_갱신(맥동: float) -> void:
	var 흰색차례 := _잉크색() == 흰색
	# 걷기 애니메이션을 계속 돌린다. 색이 바뀌면 **같은 프레임 번호를 유지한 채** 시트만 바꾼다
	# (안 그러면 Shift 를 누를 때마다 초상이 처음 자세로 튄다).
	var 원하는: String = "white_walk" if 흰색차례 else "black_walk"
	if _초상_그림 and String(_초상_그림.animation) != 원하는:
		var 프레임 := _초상_그림.frame
		var 진행 := _초상_그림.frame_progress
		_초상_그림.play(원하는)
		_초상_그림.set_frame_and_progress(프레임, 진행)
	# 그릇 속은 잉크의 반대 톤이어야 캐릭터가 안 묻힌다.
	_그릇_색(_초상_뒤, _초상_앞, 흰색차례, 맥동, 0.42)


# ============================================================================
# 게이지 — 값은 전부 어댑터가 준 실제 탄약이다
# ============================================================================
func _게이지_갱신(탄약: Dictionary, 맥동: float) -> void:
	var 흰색차례 := _잉크색() == 흰색
	_그릇_색(_게이지_뒤, _게이지_앞, 흰색차례, 맥동, 0.62)
	var 재질 := _액체.material as ShaderMaterial if _액체 else null
	if 재질 == null:
		return

	# ⚠ 최대값을 여기서 만들지 않는다. 탄약 시스템이 둘(12발/14발)이라
	#   어느 쪽인지는 어댑터만 안다. 탄약()이 빈 사전이면 그 시스템엔 탄약이 없다.
	var 최대 := float(탄약.get("최대", 0))
	var 남은 := float(탄약.get("남은", 0))
	if 최대 <= 0.0:
		# 탄약 개념이 없는 시스템(옛 PaintSystem) — 그릇을 비워 두고 눈금만 남긴다.
		재질.set_shader_parameter("fill_level", 0.0)
		재질.set_shader_parameter("pending_level", 0.0)
		재질.set_shader_parameter("locked_level", 0.0)
		return

	# 예전 캡슐 바가 세그먼트로 보여주던 세 가지 상태를 게이지 안의 세 층으로 옮겼다.
	# (그래야 캡슐을 없애도 정보가 하나도 안 없어진다)
	var 진행발 := 0.0
	for 항목 in _어댑터.진행줄():
		진행발 += float(maxi(int(항목.get("발수", 0)), 1)) if _어댑터.발수를_센다() else 1.0
	var 대기발 := 0.0
	for 항목 in _어댑터.회수줄():
		대기발 += float(maxi(int(항목.get("발수", 0)), 0)) if _어댑터.발수를_센다() else 1.0
	var 잠김발 := float(_어댑터.잠긴_발수())

	var 채움 := clampf(남은 / 최대, 0.0, 1.0)
	var 대기 := clampf((남은 + 진행발 + 대기발) / 최대, 0.0, 1.0)
	var 잠김 := clampf((남은 + 진행발 + 대기발 + 잠김발) / 최대, 0.0, 1.0)

	# ★채움 높이는 실제 탄약 그대로다. 동역학이 이 값을 건드리지 않는다(§7).
	재질.set_shader_parameter("fill_level", 채움)
	재질.set_shader_parameter("pending_level", 대기)
	재질.set_shader_parameter("locked_level", 잠김)
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
func _액체_동역학(delta: float, 탄약: Dictionary) -> void:
	var 재질 := _액체.material as ShaderMaterial if _액체 else null
	if 재질 == null:
		return

	# ── ① 이동 관성 ──
	#   목표 기울기는 플레이어의 가로 속도에서 나온다. 그 목표로 **천천히** 따라가서
	#   "잉크가 한 박자 늦게 쏠린다"를 만든다. 멈추면 목표가 0 이 되어 스스로 수평이 된다.
	var 목표 := 0.0
	if _플레이어 and is_instance_valid(_플레이어):
		var vx := float(_플레이어.get("velocity").x) if _플레이어.get("velocity") != null else 0.0
		목표 = clampf(vx / 기준_속도, -1.0, 1.0) * 이동_기울기 * float(기울기_방향)
	_기울기 = lerpf(_기울기, 목표, clampf(기울기_추종 * delta, 0.0, 1.0))

	# ── ② 발사(탄약 감소) 충격 ──
	#   ★총·총알을 건드리지 않는다. HUD 가 **실제 탄약 값의 변화를 스스로 알아채서** 튄다.
	#     환급(늘어남)에도 작게 튀게 둔다 — 게이지가 조용히 차오르면 무슨 일이 났는지 모른다.
	var 남은 := int(탄약.get("남은", -1)) if not 탄약.is_empty() else -1
	if 남은 >= 0:
		if _지난_남은 >= 0 and 남은 != _지난_남은:
			var 변화 := absf(float(남은 - _지난_남은))
			var 세기 := 1.0 if 남은 < _지난_남은 else 0.45   # 줄 때 크게, 돌아올 때 작게
			_충격 = clampf(maxf(_충격, 세기 * minf(변화, 2.0) * 0.5 + 세기 * 0.5), 0.0, 1.0)
		_지난_남은 = 남은
	_충격 = lerpf(_충격, 0.0, clampf(충격_감쇠 * delta, 0.0, 1.0))
	if _충격 < 0.002:
		_충격 = 0.0

	# ── ③ 잔물결 ──
	#   평소엔 아주 작고, 흔들릴수록(기울기·충격) 조금 커진다.
	#   그래야 "무거운 잉크가 출렁이다 가라앉는다"로 읽힌다.
	var 흔들림 := clampf(absf(_기울기) / maxf(이동_기울기, 0.001) + _충격, 0.0, 2.0)
	재질.set_shader_parameter("wave_amplitude", 잔물결_크기 * (1.0 + 흔들림 * 1.2))
	재질.set_shader_parameter("wave_frequency", 잔물결_주기)
	재질.set_shader_parameter("wave_speed", 잔물결_속도 * (1.0 + 흔들림 * 0.8))
	재질.set_shader_parameter("slosh_amount", _기울기)
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


# ============================================================================
# 코드로 그리는 것 — 장식선 · 눈금 · 월드 표식
# ----------------------------------------------------------------------------
# ⚠ 이것들은 **그림 리소스가 없어서** 코드로 그린다. `assets/textures/ui/` 에는
#   brush_cursor.svg 하나뿐이라 재사용할 UI 아트가 프로젝트에 존재하지 않는다.
#   (원화가 들어오면 이 세 함수를 TextureRect 로 갈아끼우면 된다 — 씬만 고치면 끝)
# ============================================================================

## 초상과 게이지를 잇는 장식. 둘이 따로 뜬 아이콘으로 보이지 않게 하는 것이 전부다.
func _그리기_장식() -> void:
	var c := _장식
	var 크기 := c.size
	var y := 크기.y * 0.5
	var 잉크 := _잉크색()
	var 선 := Color(테_금속.r, 테_금속.g, 테_금속.b, 0.75)
	# 가로 이음선 두 줄(위·아래로 살짝 벌려 오래된 금속 띠처럼)
	c.draw_line(Vector2(0, y - 2.5), Vector2(크기.x, y - 2.5), Color(테_그늘.r, 테_그늘.g, 테_그늘.b, 0.8), 3.0, true)
	c.draw_line(Vector2(0, y - 2.5), Vector2(크기.x, y - 2.5), 선, 1.4, true)
	c.draw_line(Vector2(2, y + 3.0), Vector2(크기.x - 2, y + 3.0), Color(선.r, 선.g, 선.b, 0.45), 1.0, true)
	# 가운데 마름모 — 다크 판타지 장식물의 이음쇠
	var 중 := Vector2(크기.x * 0.5, y)
	var r := 5.0
	var 마름모 := PackedVector2Array([중 + Vector2(0, -r), 중 + Vector2(r * 0.62, 0),
		중 + Vector2(0, r), 중 + Vector2(-r * 0.62, 0)])
	c.draw_colored_polygon(마름모, Color(테_그늘.r, 테_그늘.g, 테_그늘.b, 0.9))
	c.draw_polyline(PackedVector2Array([마름모[0], 마름모[1], 마름모[2], 마름모[3], 마름모[0]]), 선, 1.2, true)
	c.draw_circle(중, 1.6, Color(잉크.r, 잉크.g, 잉크.b, 0.9))


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
