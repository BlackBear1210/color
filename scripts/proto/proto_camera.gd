extends Camera2D
## [2026-07-18 도형 · 신규] 플랫포머 전용 카메라 v2 — "전방이 보이는" 카메라.
##
## 기존 문제: Player.tscn 안의 기본 Camera2D 는 플레이어에 딱 고정되어
## 빠르게 달릴 때 진행 방향 앞이 화면의 절반밖에 안 보였고, 반대로
## position_smoothing 을 세게 걸면 카메라가 뒤로 처져 전방 확인이 더 안 됐다.
##
## 설계 근거 (Itay Keren, GDC 2015 "Scroll Back: The Theory and Practice of
## Cameras in Side-Scrollers" — 셀레스트/마리오 등 대부분의 플랫포머가 쓰는 문법):
##  1. 룩어헤드(lookahead): 카메라 중심을 "이동 방향 앞쪽"으로 밀어서
##     달릴수록 전방이 더 넓게 보이게 한다. 방향 전환 시에는 즉시 홱 돌지 않고
##     일정 속도로 부드럽게 옮겨가 멀미를 막는다 (lookahead easing).
##  2. 수평 = 빠른 추적: 스무딩을 약하게(반응 빠르게) 해서 조작 지연감을 없앤다.
##     "부드러움"은 수평 지연이 아니라 룩어헤드 이동의 완만함으로 얻는다.
##  3. 수직 = 플랫폼 스냅(platform snapping): 점프 중에는 카메라 y 를 지면에
##     고정해 화면이 출렁이지 않게 하고, 착지해서 지면 높이가 바뀐 순간에만
##     부드럽게 따라간다. 낙하가 길어지면 아래를 미리 보여준다(낙하 룩다운).
##  4. 구역 리밋 전환: limit_* 를 즉시 바꾸면 화면이 순간이동하므로,
##     리밋 사각형 자체를 트윈해서 '바인(Vane)'처럼 구역이 이어지는 팬 연출을 만든다.
##
## 사용법 (존 조립 스크립트에서 런타임 부착 — Player.tscn 무수정):
##   var cam := ProtoCamera.new()
##   zone.add_child(cam)
##   cam.setup(player)                       # 대상 지정 + 즉시 스냅
##   cam.set_limit_rect(Rect2(...), false)   # 초기 리밋 (즉시)
##   cam.set_limit_rect(Rect2(...), true)    # 구역 전환 시 (부드럽게 팬)
class_name ProtoCamera

# ── 튜닝 상수 (체감 조정은 여기서) ──────────────────────────────────────
## 서 있을 때 기본 룩어헤드(px) — 바라보는 방향이 살짝 더 보임
const LOOK_BASE: float = 70.0
## 최고 속도로 달릴 때 룩어헤드(px) — 전방 확인용. 화면폭(1152)의 약 1/6
const LOOK_MAX: float = 190.0
## 룩어헤드 오프셋이 이동하는 속도(px/s) — 방향 전환 시 홱 돌지 않게
const LOOK_SHIFT_SPEED: float = 420.0
## 수평 추적 반응(1/s) — 클수록 딱 붙음. 지연감을 없애려고 높게 잡음
const H_RESPONSE: float = 10.0
## 수직 추적 반응(1/s) — 착지로 지면 높이가 바뀔 때 따라가는 속도
const V_RESPONSE: float = 6.0
## 카메라 중심을 발밑보다 이만큼 위로 (머리 위 공간 확보)
const EYE_LIFT: float = 60.0
## 공중에서 플레이어가 화면 위/아래로 이만큼 벗어나면 그때만 수직 추적
const AIR_WINDOW_UP: float = 140.0
const AIR_WINDOW_DOWN: float = 110.0
## 빠른 낙하 시 아래를 미리 보여주는 최대 거리(px)와 반응 기준 낙하속도
const FALL_LOOKDOWN_MAX: float = 130.0
const FALL_SPEED_REF: float = 1300.0
## 구역 리밋 전환(팬) 시간(초) — 바인식 "구역이 이어지는" 연출의 핵심
const LIMIT_TWEEN_TIME: float = 1.1
## ── [2026-08-17 도형] 수직 공간(굴뚝·갱도) 모드에서 쓰는 수직 추적 반응(1/s) ──
## 평소(V_RESPONSE=6)는 "착지했을 때만 따라가는" 플랫폼 스냅용이라 느리다.
## 굴뚝은 **오르는 것 자체가 플레이**라서, 올라가는 몸을 화면이 바로 따라와야
## "내가 올라가고 있다"가 읽힌다. 느리면 플레이어가 화면 위로 튀어나간다.
const V_RESPONSE_수직: float = 11.0

# ── [2026-07-22 도형 · 신규] 트라우마 방식 화면 흔들림(Camera Shake) ──────
## GDC 2016 Squirrel Eiserloh "Juicing Your Cameras" 문법:
##  · 외부에서 add_trauma(0~1) 로 "충격"을 쌓고, 매 프레임 일정 비율로 감쇠시킨다.
##  · 실제 흔들림 세기 = trauma² (제곱이라 작은 충격은 거의 안 흔들리고 큰 충격만 확 흔들려
##    자연스럽다). 이 값에 비례해 카메라 offset 을 랜덤하게 튕긴다.
##  · ★리밋으로 클램프하는 global_position 이 아니라 Camera2D 의 offset 을 쓴다 →
##    구역 리밋 밖으로 새지 않으면서도 화면만 흔들린다(리밋 로직과 완전히 독립).
const SHAKE_MAX_OFFSET: float = 14.0   ## trauma=1 일 때 최대 흔들림(px)
const TRAUMA_DECAY: float = 1.6        ## 초당 트라우마 감쇠량(클수록 빨리 잦아듦)
var _trauma: float = 0.0
## Camera2D 는 기본적으로 자기 rotation 을 뷰에 반영하지 않으므로(ignore_rotation=true)
## 회전 흔들림은 효과가 없다 → offset(위치) 흔들림만 사용해 확실하게 동작시킨다.

## ── [2026-08-07 도형] 구역별 시선 보정 ──────────────────────────────────────
## 홀로우 나이트 문법: 구역마다 카메라가 플레이어를 잡는 위치를 조금씩 달리해
## "이 구역에서는 위를 더 보여준다 / 아래를 더 보여준다" 를 디자이너가 정할 수 있게 한다.
## [카메라_연출.gd](카메라_연출.gd) 가 구역을 섞으면서 이 값도 같이 섞어 넣는다.
## ★기본값 0 이라 이 기능을 안 쓰는 기존 씬(zone_01/02, world_1, 스테이지 1~5)은
##   동작이 조금도 바뀌지 않는다.
var 구역_오프셋: Vector2 = Vector2.ZERO

var target: CharacterBody2D = null       # 따라갈 플레이어
var _look_x: float = 0.0                 # 현재 룩어헤드 오프셋 (부드럽게 이동)
var _face: float = 1.0                   # 마지막 바라본 방향 (+1/-1)
var _ground_y: float = 0.0               # 마지막으로 밟았던 지면 y (플랫폼 스냅 기준)
var _fall_look: float = 0.0              # 낙하 룩다운 오프셋 (부드럽게)
var _limits: Rect2 = Rect2()             # 현재 적용 중인 **기준** 리밋 (트윈 대상)
var _has_limits: bool = false
var _limit_tween: Tween = null
var _zoom_tween: Tween = null

## ============================================================================
## [2026-08-17 도형 · 신규] ★"카메라 공간" 덮어쓰기 — 굴뚝/갱도 같은 좁은 수직 공간
## ----------------------------------------------------------------------------
## ▣ 왜 층을 하나 더 두는가
##   지금 카메라 값을 정하는 주인은 두 곳이다.
##     · `월드.gd`      : 스테이지 전체 리밋·줌을 한 번 넣는다
##     · `카메라_연출.gd`: 매 물리 프레임 x 구역을 섞어 리밋·줌을 **다시 넣는다**
##   여기에 "굴뚝에 들어가면 화면을 조인다"를 그냥 얹으면, 다음 프레임에
##   연출가가 자기 값으로 덮어써서 **한 프레임 조였다 풀렸다** 하며 떨린다.
##   → 위 두 곳이 넣는 값을 **기준(base)** 으로 두고, 공간 값을 그 위에 **혼합**한다.
##     혼합 비율(_공간_혼합)만 트윈하므로 누가 기준을 갱신해도 싸우지 않는다.
##
## ▣ 왜 여기서는 시간 트윈을 쓰는가 (카메라_연출.gd 는 위치 보간이라고 못박아 뒀는데)
##   x 구역 전환은 **경계가 없는 연속 이동**이라 위치로 보간해야 조작과 화면이 같이 간다.
##   반면 굴뚝 진입은 **문을 통과하는 이산 사건**이다(Area2D 가 한 번 발동한다).
##   이산 사건을 위치로 보간하려면 "얼마나 들어왔나"를 다시 정의해야 하는데,
##   굴뚝 입구는 아래로도 옆으로도 들어올 수 있어 그 축이 하나로 안 정해진다.
##   → 사건에는 시간 트윈이 맞다. 대신 **되돌아 나오면 즉시 반대 방향으로 트윈**해서
##     "화면이 혼자 흘러가 조작과 어긋나는" Vane 식 실패를 막는다.
##
## ▣ 포탈 감각이 안 나는 이유
##   씬을 갈지 않고, 화면을 끊지 않고, 값만 0→1 로 흐른다. 플레이어 입장에서는
##   "굴뚝에 몸이 들어가니 화면이 굴뚝에 맞게 조여든다" = 공간이 그렇게 생긴 것으로 읽힌다.
## ============================================================================
## 이 공간을 넣은 노드 이름(중첩 방지용 열쇠). 빈 문자열이면 활성 공간이 없다.
var _공간_이름: String = ""
var _공간_리밋: Rect2 = Rect2()
var _공간_줌: float = 1.0
var _공간_시선: Vector2 = Vector2.ZERO
var _공간_수직: bool = false
## 0 = 기준값 그대로 / 1 = 공간값 그대로. 그 사이는 섞인다.
var _공간_혼합: float = 0.0
var _공간_트윈: Tween = null

## 기준 줌 — `set_region_zoom` 이 쓰는 값. 실제 `zoom` 은 매 프레임 여기서 계산된다.
## ⚠ 0 이면 "아직 아무도 안 정했다"는 뜻이라 zoom 을 건드리지 않는다
##   (ProtoCamera 를 줌 설정 없이 쓰는 기존 씬 zone_01/02 · world_1 에서 화면이 0 배가 되면 안 된다).
var _기준_줌: float = 0.0

## ★연출용 줌 배수 — **전환 연출(장면전환.gd · 월드.gd 등장연출)이 트윈하는 손잡이.**
##   [2026-08-17] 예전에는 그 두 곳이 `zoom` 을 직접 트윈했다. 그런데 카메라연출가가
##   매 프레임 `set_region_zoom` 으로 zoom 을 다시 써 버리므로, 구역 연출이 있는 씬에서는
##   "짜잔" 줌아웃이 **조용히 사라졌다**(첫 프레임에 지워진다).
##   배수를 따로 두면 구역 줌 · 공간 줌 · 연출 줌이 곱셈으로 공존한다.
var 연출_줌배수: float = 1.0

## ============================================================================
## [2026-08-22 도형 · 신규] 적응형 줌(C) + 화면 비네트(B) + 전환 "빨림"
## ----------------------------------------------------------------------------
## 도형님 요청: "다음 스테이지로 이동할 때 카메라가 플레이어에게 점점 빠르게
##   가져가서 동굴 뒷편으로 빨려들어가는 느낌이나 점점 어두워지게. 메모의 C+B 적용."
## → C(적응형 줌)·B(거리 비네트)는 [작업기록_2026-08-19 §3 카메라 인계 메모]의 설계다.
##
## ▣ 왜 검사를 안 깨나 (가장 중요한 제약)
##   `test_카메라공간`·`test_카메라연출` 은 **플레이어 속도 0** 으로 줌을 잰다.
##   그래서 적응 배수는 **속도 데드존 안(정지)에서 정확히 1.0** 이어야 한다.
##   아래 `_적응_줌_갱신` 은 속도 0 에서 목표 1.0 이고 초기값도 1.0 이라
##   정지 상태에서는 배수가 1.0 에서 한 치도 안 움직인다 = 기존 검사 그대로 통과.
## ============================================================================
## ── C) 적응형 줌 — 빠르게 달리거나 크게 떨어질 때만 화면을 살짝 넓힌다 ──
const 적응_최소배수: float = 0.90    ## 최고속+빠른낙하에서 이만큼까지 넓어진다(<1 = 줌아웃)
const 적응_속도데드존: float = 45.0  ## 이 속도 이하는 '정지' — 배수 1.0 (검사·미세흔들림 보호)
const 적응_반응: float = 3.0         ## 배수가 목표로 수렴하는 속도(1/s). 낮게 잡아 급변 방지
var _적응배수: float = 1.0

## ── B) 화면 비네트 — 림보식 가장자리 어둠. 평상시 은은, 전환 때 조여든다 ──
## HUD(100)·전환(200)보다 아래 CanvasLayer(50)에 둔다 → 카메라 이동과 무관히 화면 고정.
const 비네트_기본: float = 0.13      ## 평상시 가장자리 어둠(0=없음, 1=완전 검정)
var _비네트층: CanvasLayer = null
var _비네트: TextureRect = null
var _비네트_트윈: Tween = null

## ── 전환 "빨림" — 다음 스테이지로 걸어들 때 화면이 플레이어에게 급격히 당겨진다 ──
## 0 = 평상시(룩어헤드·반응 그대로) / 1 = 최대(룩어헤드 접힘 + 추적 반응 급상승).
## `장면전환.gd` 가 통로 진입 암전 동안 0→1 로 트윈해 "빨려드는" 감각을 만든다.
var _빨림: float = 0.0
var _빨림_트윈: Tween = null


func _ready() -> void:
	# 스무딩은 우리가 직접 계산하므로 내장 스무딩은 끔 (이중 지연 방지)
	position_smoothing_enabled = false
	# 플레이어 이동(_physics_process)이 끝난 뒤에 따라가도록 우선순위를 뒤로
	process_physics_priority = 100
	# [2026-08-17] 씬에서 이미 zoom 을 정해 둔 카메라라면 그 값을 기준으로 삼는다.
	# (안 하면 set_region_zoom 을 부르지 않는 기존 씬에서 zoom 계산이 0 이 된다)
	if _기준_줌 <= 0.0 and zoom.x > 0.0:
		_기준_줌 = zoom.x
	# 카메라 공간(카메라_공간.gd)이 트리 어디에 있어도 나를 찾을 수 있게 한다.
	# get_viewport().get_camera_2d() 는 make_current 타이밍에 따라 null 이 될 수 있어서
	# 그룹을 보조 경로로 둔다.
	add_to_group("주카메라")
	make_current()
	# [2026-08-22] 화면 비네트(B) 설치 — 평상시 은은한 가장자리 어둠.
	_비네트_설치()

## 대상 지정 + 첫 프레임 순간이동 스냅 (씬 시작 시 카메라가 날아오는 것 방지)
func setup(p_target: CharacterBody2D) -> void:
	target = p_target
	_ground_y = target.global_position.y
	_face = 1.0
	_look_x = LOOK_BASE
	# [2026-08-17] 리스폰으로 이 함수가 다시 불릴 수 있다. 그때 공간 혼합이 남아 있으면
	# 스냅 위치가 공간 기준이라야 한 프레임 튀지 않는다 → 현재 혼합값을 그대로 넘긴다.
	var 공간s := smoothstep(0.0, 1.0, _공간_혼합)
	global_position = _desired_center(공간s)
	if _has_limits or 공간s > 0.0:
		global_position = _clamp_to_limits(global_position, _유효_리밋(공간s))

## 리밋 사각형 지정. animate=true 면 이전 리밋에서 새 리밋으로 트윈(구역 전환 팬)
func set_limit_rect(rect: Rect2, animate: bool = false) -> void:
	if _limit_tween:
		_limit_tween.kill()
		_limit_tween = null
	if not _has_limits or not animate:
		_limits = rect
		_has_limits = true
		return
	# Rect2 를 통째로 보간 — 화면이 순간이동하지 않고 흘러가듯 넘어간다
	var from := _limits
	_limit_tween = create_tween()
	_limit_tween.tween_method(
		func(t: float) -> void:
			_limits = Rect2(from.position.lerp(rect.position, t),
				from.size.lerp(rect.size, t)),
		0.0, 1.0, LIMIT_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## 구역별 줌 (GDC "Scroll Back" / Hollow Knight 식 구역별 카메라 변주).
## 높은 구역에 들어설 때 살짝 줌아웃하면 "새 지역이 눈앞에 펼쳐진다"는 연출이 된다.
## 리밋 트윈과 같은 시간으로 함께 흘러가야 한 호흡의 전환으로 읽힌다.
##
## ★[2026-08-17] 이제 `zoom` 을 직접 쓰지 않고 **기준 줌**만 정한다.
##   실제 zoom 은 매 프레임 `기준 × 공간혼합 × 연출배수` 로 계산된다(§_줌_적용).
##   이렇게 바꾼 이유는 위 `연출_줌배수` 주석 참고 — 세 주인이 zoom 을 서로 덮어썼다.
func set_region_zoom(target_zoom: float, animate: bool = false) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
		_zoom_tween = null
	if not animate:
		_기준_줌 = target_zoom
		_줌_적용()          # 즉시 반영 — 첫 프레임부터 올바른 화면이어야 한다
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "_기준_줌", target_zoom, LIMIT_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


# ============================================================================
# [2026-08-17 도형] 카메라 공간 API — `카메라_공간.gd`(Area2D) 가 부른다
# ============================================================================
## 좁은 수직 공간(굴뚝·갱도)에 들어섰다. 리밋·줌·시선을 이 공간 값으로 **흘러가듯** 바꾼다.
##   리밋   : 월드 좌표. **화면보다 좁게** 주면 `_clamp_to_limits` 가 카메라를 가운데 고정한다
##            → 플레이어가 굴뚝 안에서 좌우로 움직여도 화면이 벽 바깥을 절대 안 비춘다.
##   줌     : 절대값(작을수록 넓게 보인다). 공간 노드가 `기준 줌 × 배수` 로 계산해 넘긴다.
##   시선   : 이 공간에서 화면 중심을 옮길 양. 오를 때는 위(−y)를 더 보여준다.
##   수직   : true 면 룩어헤드를 끄고 플랫폼 스냅 대신 몸을 바로 따라간다(§_desired_center)
##   시간   : 혼합 0→1 에 걸리는 초. 0 이면 즉시(테스트용).
##   이름   : 중첩 방지 열쇠. 다른 공간이 활성이면 새 공간이 이긴다(마지막이 이긴다).
func 공간_들어감(리밋: Rect2, 줌: float, 시선: Vector2, 수직: bool,
		시간: float, 이름: String = "공간") -> void:
	_공간_이름 = 이름
	_공간_리밋 = 리밋
	_공간_줌 = 줌
	_공간_시선 = 시선
	_공간_수직 = 수직
	_공간_혼합_트윈(1.0, 시간)


## 공간을 벗어났다. 기준값으로 되돌아간다(= 줌 아웃되며 전경이 펼쳐진다).
## ⚠ 이름이 다르면 무시한다 — 굴뚝 안에 작은 공간이 겹쳐 있을 때
##   바깥 공간을 빠져나온 신호가 안쪽 공간을 지워버리면 안 된다.
func 공간_나감(시간: float, 이름: String = "공간") -> void:
	if _공간_이름 != 이름:
		return
	_공간_혼합_트윈(0.0, 시간)


## 공간 안에서 시선만 계속 갱신한다 (예: 올라갈수록 위를 더 보여주기).
## 혼합 비율은 건드리지 않으므로 진입 연출 중에 불려도 안전하다.
func 공간_시선_갱신(시선: Vector2) -> void:
	_공간_시선 = 시선


## 지금 공간이 얼마나 적용됐나 (0~1). 테스트·디버그에서 읽는다.
func 공간_혼합() -> float:
	return _공간_혼합


## 지금의 기준 줌(구역/월드가 정한 값). 0 이면 아직 아무도 정하지 않았다.
## ★`카메라_공간.gd` 가 "기준 × 배수" 를 계산할 때 쓴다 —
##   공간 노드가 `_기준_줌` 을 직접 읽으면, 나중에 줌 계산 구조를 바꿀 때
##   호출부까지 같이 고쳐야 한다. 창구를 하나 둔다.
func 기준_줌() -> float:
	return _기준_줌


func _공간_혼합_트윈(목표: float, 시간: float) -> void:
	if _공간_트윈:
		_공간_트윈.kill()
		_공간_트윈 = null
	if 시간 <= 0.0:
		_공간_혼합 = 목표
		_줌_적용()
		return
	# ★남은 거리에 비례해 시간을 줄인다. 절반쯤 들어갔다 되돌아 나올 때
	#   전체 시간을 다시 쓰면 화면이 몸보다 한참 늦게 따라와 "끌려가는" 느낌이 난다.
	var 남음: float = absf(목표 - _공간_혼합)
	_공간_트윈 = create_tween()
	_공간_트윈.tween_property(self, "_공간_혼합", 목표, 시간 * maxf(남음, 0.15)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	# ── 0) [2026-08-17] 줌 먼저 확정한다 ────────────────────────────────
	# ★순서가 중요하다. 리밋 클램프는 "화면 반폭 = 뷰포트/줌" 을 쓰기 때문에,
	#   줌을 나중에 적용하면 이 프레임의 클램프가 **한 프레임 전 줌**으로 계산된다.
	#   좁은 굴뚝에서는 그 한 프레임이 화면이 옆으로 튀는 것으로 보인다.
	# [2026-08-22] 적응 배수(C)를 줌 적용보다 먼저 갱신한다 — _줌_적용 이 이 값을 읽는다.
	_적응_줌_갱신(delta)
	_줌_적용()
	# 공간 혼합 계수 — 시작·끝의 기울기가 0 인 곡선이라 이음매가 안 보인다.
	var 공간s := smoothstep(0.0, 1.0, _공간_혼합)

	# ── 1) 룩어헤드: 이동 방향 앞쪽으로 카메라 중심을 민다 ─────────────
	var vx := target.velocity.x
	if absf(vx) > 5.0:
		_face = signf(vx)
	# 속도가 빠를수록 더 멀리 본다 (LOOK_BASE → LOOK_MAX)
	var speed_ratio: float = clampf(absf(vx) / 390.0, 0.0, 1.0)   # 390 = player move_speed
	var look_target := _face * lerpf(LOOK_BASE, LOOK_MAX, speed_ratio)
	# 목표 오프셋으로 "일정 속도" 이동 — 방향 전환이 부드럽다 (Keren: lookahead easing)
	_look_x = move_toward(_look_x, look_target, LOOK_SHIFT_SPEED * delta)

	# ── 2) 수직: 플랫폼 스냅 ────────────────────────────────────────────
	var py := target.global_position.y
	if target.is_on_floor():
		_ground_y = py            # 착지한 지면을 새 기준으로
	else:
		# 공중이라도 화면 밖으로 벗어나려 하면 그때만 따라간다
		if py < _ground_y - AIR_WINDOW_UP:
			_ground_y = py + AIR_WINDOW_UP
		elif py > _ground_y + AIR_WINDOW_DOWN:
			_ground_y = py - AIR_WINDOW_DOWN

	# 빠른 낙하 중에는 아래를 미리 보여준다 (착지 지점 확인용)
	var fall_target := 0.0
	if not target.is_on_floor() and target.velocity.y > 300.0:
		fall_target = FALL_LOOKDOWN_MAX * clampf(target.velocity.y / FALL_SPEED_REF, 0.0, 1.0)
	_fall_look = lerpf(_fall_look, fall_target, 1.0 - exp(-4.0 * delta))
	# ★수직 공간에서는 낙하 룩다운을 끈다. 굴뚝은 **위로 가는 곳**이라
	#   떨어질 때 아래를 보여주면 시선이 목표(출구)에서 떨어져 나간다.
	if _공간_수직:
		_fall_look *= 1.0 - 공간s

	# ── 3) 목표점으로 지수 스무딩 (프레임률 독립) ───────────────────────
	# [2026-08-22] 전환 "빨림": 룩어헤드를 접고(당김) 추적 반응을 급격히 올려
	#   화면이 플레이어에게 빨려들 듯 당겨진다. _빨림=0 이면 예전과 완전히 같다.
	var desired := _desired_center(공간s, _빨림)
	var kx := 1.0 - exp(-lerpf(H_RESPONSE, H_RESPONSE * 3.2, _빨림) * delta)
	# 수직 공간에서는 세로 반응을 올린다 (등반이 곧 플레이라서 — §V_RESPONSE_수직)
	var v반응 := lerpf(V_RESPONSE, V_RESPONSE_수직, 공간s if _공간_수직 else 0.0)
	# 전환 빨림 때는 세로도 몸에 바짝 붙여 "빨려드는" 감각을 완성한다
	v반응 = lerpf(v반응, v반응 * 2.6, _빨림)
	var ky := 1.0 - exp(-v반응 * delta)
	var pos := global_position
	pos.x = lerpf(pos.x, desired.x, kx)
	pos.y = lerpf(pos.y, desired.y, ky)

	# ── 4) 구역 리밋으로 클램프 (리밋 자체가 트윈되므로 전환도 부드러움) ─
	if _has_limits or 공간s > 0.0:
		pos = _clamp_to_limits(pos, _유효_리밋(공간s))
	global_position = pos

	# ── 5) [2026-07-22 도형] 화면 흔들림: 리밋과 무관한 offset 으로만 튕긴다 ─
	_update_shake(delta)

## 외부(존)에서 충격을 쌓는 공개 API. 예) 착지=약, 회색 페인트=중, 사망=강.
## 여러 번 불리면 누적되며 1.0 에서 포화한다.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO   # 흔들림이 끝나면 offset 을 깔끔히 0 으로 되돌린다
		return
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	var s := _trauma * _trauma   # 제곱 곡선: 작은 충격은 은은, 큰 충격만 강하게
	# 매 프레임 무작위 방향으로 offset 을 튕긴다(고주파 흔들림). 리밋 클램프와 무관.
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * s

## 카메라가 가야 할 이상적 중심점.
##   공간s : 카메라 공간이 얼마나 적용됐나(0~1). 0 이면 예전과 완전히 같은 계산이다.
func _desired_center(공간s: float = 0.0, 당김: float = 0.0) -> Vector2:
	# [2026-08-07] 구역_오프셋 을 더한다. 기본값 0 이라 기존 씬은 결과가 같다.
	# [2026-08-17] 공간이 켜지면 구역 시선은 물러나고 공간 시선이 들어온다(합이 항상 1).
	var 시선 := 구역_오프셋.lerp(_공간_시선, 공간s)

	# [2026-08-22] 전환 빨림: 룩어헤드를 접는다(당김 1 이면 카메라가 몸 정중앙을 잡는다).
	var x := target.global_position.x + _look_x * (1.0 - clampf(당김, 0.0, 1.0)) + 시선.x
	var y := _ground_y - EYE_LIFT + _fall_look + 시선.y

	# ★수직 모드 — 굴뚝/갱도
	#   가로: 룩어헤드를 0 으로 접는다. 좁은 통로에서 앞쪽을 미리 보여줄 게 없고,
	#         오히려 좌우로 흔들려 "벽이 흔들리는" 그림이 된다.
	#   세로: 플랫폼 스냅(_ground_y)을 버리고 **몸을 바로** 따라간다.
	#         스냅은 "평지를 달릴 때 화면이 출렁이지 않게" 하는 장치라,
	#         밟을 지면이 계속 바뀌는 등반에서는 화면이 계단처럼 툭툭 끊긴다.
	if _공간_수직 and 공간s > 0.0:
		x = lerpf(x, target.global_position.x + 시선.x, 공간s)
		y = lerpf(y, target.global_position.y - EYE_LIFT * 0.5 + 시선.y, 공간s)
	return Vector2(x, y)


## 기준 리밋과 공간 리밋을 섞은 **이번 프레임의 리밋**.
## 리밋이 아직 없는 씬(월드가 리밋을 안 준 경우)에서는 공간 리밋만 쓴다.
func _유효_리밋(공간s: float) -> Rect2:
	if 공간s <= 0.0:
		return _limits
	if not _has_limits or 공간s >= 1.0:
		return _공간_리밋
	return Rect2(_limits.position.lerp(_공간_리밋.position, 공간s),
		_limits.size.lerp(_공간_리밋.size, 공간s))


## 이번 프레임의 zoom = 기준 줌 → 공간 줌 (혼합) × 연출 배수.
## 곱셈이라 "구역이 정한 넓이 · 공간이 조인 정도 · 전환 연출" 세 개가 서로를 안 지운다.
func _줌_적용() -> void:
	if _기준_줌 <= 0.0:
		return                      # 아무도 줌을 정하지 않은 씬 — 건드리지 않는다
	var z := _기준_줌
	if _공간_혼합 > 0.0:
		z = lerpf(_기준_줌, _공간_줌, smoothstep(0.0, 1.0, _공간_혼합))
	# [2026-08-22] 적응 배수(C)도 곱한다. 정지 상태에서는 1.0 이라 기존 값과 동일.
	zoom = Vector2.ONE * maxf(z * 연출_줌배수 * _적응배수, 0.01)


# ============================================================================
# [2026-08-22 도형] 적응형 줌(C) · 화면 비네트(B) · 전환 빨림 — 구현부
# ============================================================================
## 속도·낙하에 따라 화면을 살짝 넓히는 배수를 갱신한다(<1 = 줌아웃 = 더 넓게).
## ★정지(속도 0)에서는 목표가 정확히 1.0 이고 초기값도 1.0 이라 배수가 안 움직인다
##   → 속도 0 으로 줌을 재는 카메라 검사 2종이 그대로 통과한다.
func _적응_줌_갱신(delta: float) -> void:
	var vx := absf(target.velocity.x)
	var 아래로 := maxf(target.velocity.y, 0.0)
	# 데드존 위에서만 반응. 데드존 이하는 넓힘 0 → 목표 배수 1.0.
	var 속도량 := clampf((vx - 적응_속도데드존) / (390.0 - 적응_속도데드존), 0.0, 1.0)
	var 낙하량 := clampf((아래로 - 300.0) / (FALL_SPEED_REF - 300.0), 0.0, 1.0)
	var 넓힘 := maxf(속도량, 낙하량)
	var 목표 := lerpf(1.0, 적응_최소배수, 넓힘)
	# 프레임률 독립 지수 수렴 — 급격한 줌 변화로 인한 멀미를 막는다.
	_적응배수 = lerpf(_적응배수, 목표, 1.0 - exp(-적응_반응 * delta))


## 화면 비네트(B) 노드를 만든다. 카메라 이동과 무관히 화면에 고정되도록 CanvasLayer 를 쓴다.
func _비네트_설치() -> void:
	if _비네트층 != null and is_instance_valid(_비네트층):
		return
	_비네트층 = CanvasLayer.new()
	_비네트층.name = "비네트"
	_비네트층.layer = 50                  # 게임 위, HUD(100)·전환(200) 아래
	add_child(_비네트층)                   # ⚠ owner 안 줌 (런타임 노드 — §규약 6)
	_비네트 = TextureRect.new()
	_비네트.name = "가장자리어둠"
	_비네트.texture = _비네트_텍스처()
	_비네트.set_anchors_preset(Control.PRESET_FULL_RECT)
	_비네트.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_비네트.stretch_mode = TextureRect.STRETCH_SCALE
	_비네트.modulate = Color(1, 1, 1, 비네트_기본)
	_비네트층.add_child(_비네트)


## 가운데는 투명, 가장자리로 갈수록 검은 방사형 그라데이션 텍스처.
func _비네트_텍스처() -> GradientTexture2D:
	var g := Gradient.new()
	# 가운데 45% 까지는 완전히 맑고, 거기서부터 가장자리로 어두워진다.
	g.set_offset(0, 0.45); g.set_color(0, Color(0, 0, 0, 0))
	g.set_offset(1, 1.0);  g.set_color(1, Color(0, 0, 0, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


## 평상시 비네트 강도 — 전환이 끝난 뒤 이 값으로 되돌린다.
func 비네트_기본값() -> float:
	return 비네트_기본


## 화면 가장자리 어둠 강도를 부드럽게 바꾼다(0~1). 전환의 "점점 어두워짐" 에 쓴다.
func 비네트_강도(강도: float, 시간: float) -> void:
	if _비네트 == null or not is_instance_valid(_비네트):
		return
	if _비네트_트윈:
		_비네트_트윈.kill()
		_비네트_트윈 = null
	var a := clampf(강도, 0.0, 1.0)
	if 시간 <= 0.0:
		_비네트.modulate.a = a
		return
	_비네트_트윈 = create_tween()
	_비네트_트윈.tween_property(_비네트, "modulate:a", a, 시간).set_trans(Tween.TRANS_SINE)


## 전환 "빨림" 정도를 0~1 로 트윈한다. `장면전환.gd` 가 통로 진입 암전 동안 부른다.
## EASE_IN 이라 처음엔 완만하다 끝에서 확 당겨져 "빨려드는" 가속감이 난다.
func 전환_빨림(정도: float, 시간: float) -> void:
	if _빨림_트윈:
		_빨림_트윈.kill()
		_빨림_트윈 = null
	var v := clampf(정도, 0.0, 1.0)
	if 시간 <= 0.0:
		_빨림 = v
		return
	_빨림_트윈 = create_tween()
	_빨림_트윈.tween_property(self, "_빨림", v, 시간) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 뷰포트 절반 크기를 고려해 카메라 중심을 리밋 안으로.
## ★리밋이 화면보다 작으면 **중앙 고정** — 이 한 줄이 "굴뚝 벽 바깥을 절대 안 비춘다"의 정체다.
##   굴뚝 안쪽 폭(320px)은 화면 폭보다 훨씬 좁으므로 카메라 x 가 굴뚝 중심에 못박히고,
##   플레이어가 좌우 선반을 오가도 화면은 조금도 흐르지 않는다.
func _clamp_to_limits(pos: Vector2, 리밋: Rect2) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom
	if 리밋.size.x > half.x * 2.0:
		pos.x = clampf(pos.x, 리밋.position.x + half.x, 리밋.end.x - half.x)
	else:
		pos.x = 리밋.get_center().x
	if 리밋.size.y > half.y * 2.0:
		pos.y = clampf(pos.y, 리밋.position.y + half.y, 리밋.end.y - half.y)
	else:
		pos.y = 리밋.get_center().y
	return pos
