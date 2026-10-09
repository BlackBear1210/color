@tool
extends Area2D
## ============================================================================
## [2026-08-06 신규] 도약대 — 밟으면 위로 튀어 오르는 발판
## [2026-10-08 Claude] 버섯형 → **코일 스프링 점프대**(판 + 코일 + 받침 부품 · 감쇠 스프링 움직임)
## ----------------------------------------------------------------------------
## ▣ 왜 이 게임에 필요한가
##   낙하 사망(`낙하_감시.gd`)을 넣으면서 **아래로 가는 길은 위험**해졌다.
##   그런데 위로 가는 수단이 점프 하나뿐이면 레벨이 옆으로만 길어진다.
##   도약대가 있으면 레인월드처럼 **수직으로 쌓인 방**을 만들 수 있고,
##   "내려갈 땐 계단, 올라갈 땐 도약대" 라는 왕복 동선이 생긴다.
##
## ▣ 낙하 사망과의 관계 (설계 의도)
##   도약대로 튀어 오른 뒤 그대로 떨어지면, 낙하 감시는 **튄 꼭대기**부터 거리를 센다.
##   그래서 세기(`도약속도`)를 치명 거리(520px)보다 크게 잡으면
##   **받아줄 발판이 없는 도약대는 그 자체로 자살 장치**가 된다.
##   → 기본값은 상승 418px 로 잡아 그 아래에 뒀다. 더 세게 만들 거면
##      반드시 위에 받아줄 발판을 두고 `tools/레벨검사.gd` 로 확인할 것.
##
## ▣ 기본값 −1500 이 왜 418px 인가 (실제 플레이어 수치로 역산)
##   스마트월드 플레이어 세팅: 점프_높이_칸 10 · 타일 16px · 상승_배수 4.563 · move_speed 390
##     gravity      = 2·160·390²·k² / 320²  ≈ 589.4      (k = 1/√4.563 + 1/√2.4)
##     상승 중력    = 589.4 × 4.563          ≈ 2689
##     상승 높이    = v² / (2 × 2689)
##   → v = 1500 이면 1500² / 5379 ≈ 418px = 점프 높이(160px)의 2.6 배.
##   플레이어 점프 세팅을 바꾸면 이 값도 달라진다. `tools/레벨검사.gd` 가 실제로 계산해 준다.
##
## ▣ 색 규칙
##   기본은 무색(누구나 사용 가능)이다. `색_제한` 을 켜면 같은 색일 때만 튕겨 올리고
##   반대색이면 그냥 딱딱한 발판처럼 군다 — 색 전환을 강제하는 퍼즐 부품이 된다.
##   (사망 판정은 하지 않는다. 여기서 죽이면 "왜 죽었는지" 읽히지 않는다)
##   색은 **위 판의 색**으로 알린다(검정 판 / 흰 판 · 무색 = 장치 명도 77 근처).
##
## ▣ [2026-10-08] 스프링 그림 (기획 §4-C · 카드 1 · 도형님 결정: 나무 = 쳅터1 / 맨홀 = world_2_클로드)
##   그림은 부품 셋 — 위 **판** · 가운데 **코일** · 아래 **받침**(`tools/생성_신규기믹_게임용.py` 가 시안에서 잘라 낸다).
##   · 코일은 늘이지 않고 **바퀴 사이 간격**을 바꿔 그린다(철선을 늘이면 고무처럼 보인다 — 기획 §4-C).
##     바퀴(코일 그림을 가로로 3 등분)는 0.85~1.12 배까지만 키를 바꾸고 나머지는 간격으로 맞춘다.
##   · 움직임 = 감쇠 스프링: 대기 = 휴지 길이 0.92 중심 ±3% · 1.4초 숨쉬기 /
##     올라탐 = 0.06초에 0.70 까지 눌림 → 튕기며 최대 1.28 → 0.6초 동안 2~3번 출렁이고 대기로.
##   · ★서는 높이: 판 윗면(발 자리) = `서는_높이` **32px = 1칸**. 쳅터1 검사기(tools/쳅터1/검사.py · 기믹.py)가
##     도약대를 '바닥 위 1칸' 으로 놓고 경로를 짜고, 경로 재생 시험이 그 높이에서 출발·착지를 잰다.
##     예전 버섯형은 콜리전 윗면이 23px(높이의 절반)이라 발이 갓 그림 속에 묻혀 보였다.
##     ⚠ 처음엔 46px(=높이)로 올렸다가 경로 재생 4 비행이 '도약대에서 안 튐 / 다른 곳에 내림' 으로 깨졌다(2026-10-08 실측)
##     → 검사기와 같은 32px 로 맞췄다. 스프링 그림은 이 높이에 맞춰 세로를 줄인다(대기 = 살짝 눌린 모양 — 기획 그대로).
##     예전 23px 판정으로 돌리려면 `옛_서는높이` 를 켠다.
##   · 자식 노드는 만들지 않고 `_draw()` 로 그린다(@tool 이 저장 때 자식을 씬에 굽는 문제 — CLAUDE.md 형태검사 항목).
##   · 성능: 화면 밖이면 처리를 멈추고(VisibleOnScreenNotifier2D), 화면 안에서도 그림이 0.25px 넘게
##     달라질 때만 다시 그린다(다음작업 §8 "매 프레임 같은 값 대입 금지").
## ============================================================================
class_name 도약대

@export_range(60, 400) var 폭: float = 150.0:
	set(v): 폭 = v; _재구성()
@export_range(20, 120) var 높이: float = 46.0:
	set(v): 높이 = v; _재구성()

## 튕겨 올리는 속도(px/s). 음수가 위쪽이다.
## 상승 높이 ≈ 속도² / (2 × 상승중력). 위 주석의 역산 참고 — 기본값은 약 418px.
@export var 도약속도: float = -1500.0

## 켜면 플레이어 색과 이 도약대 색이 같을 때만 튕긴다.
@export var 색_제한: bool = false
## 색_제한 이 켜졌을 때의 도약대 색.
@export var 색: int = ColorDefs.BLACK

@export_group("스프링 그림 (2026-10-08)")
## 자동 = 씬 경로에 world_2 가 있으면 하수도(주철 맨홀판), 아니면 집(철띠 나무판).
@export_enum("자동", "집", "하수도") var 재질: int = 0:
	set(v): 재질 = v; _텍스처 = {}; queue_redraw()
## 대기 때 코일 길이(자연 길이 = 1). 살짝 눌린 채 숨 쉰다.
@export_range(0.6, 1.0, 0.01) var 휴지_길이: float = 0.92
## 숨쉬기 폭(±) · 주기(초)
@export_range(0.0, 0.1, 0.005) var 숨_폭: float = 0.03
@export_range(0.4, 4.0, 0.05) var 숨_주기: float = 1.4
## 올라탄 순간 눌리는 길이 · 걸리는 시간
@export_range(0.4, 0.95, 0.01) var 눌림_길이: float = 0.70
@export_range(0.02, 0.3, 0.01) var 눌림_시간: float = 0.06
## 튕길 때 최대로 늘어나는 길이(너무 길게는 X — 도형님) · 출렁이는 시간
@export_range(1.0, 1.6, 0.01) var 최대_늘어남: float = 1.28
@export_range(0.2, 1.5, 0.05) var 출렁임_시간: float = 0.6
## 판 윗면(발 자리) 높이(px). 32 = 쳅터1 검사기의 도약대 1칸 — 바꾸면 검사기·경로 재생과 어긋난다.
@export_range(16, 96, 1) var 서는_높이: float = 32.0:
	set(v): 서는_높이 = v; _재구성()
## [2026-10-09] 그림을 아래로 내리는 깊이(px). −1 = 자동 — 발밑 지형의 `발_그림_깊이()`(목재 상판 −4…18 의 가운데 = +7).
##   도형님: "점프대가 지형 윗면의 윗변에 얹혀 있다 → 윗면 이미지 가운데에 놓이게". 판정(서는 높이)은 그대로 두고
##   그림만 내린다 — 플레이어 발 그림도 같은 +7 에 그려지므로(player_anim) 판 위에 선 발과 판이 그대로 맞는다.
@export var 그림_깊이: float = -1.0:
	set(v): 그림_깊이 = v; queue_redraw()
## 켜면 예전처럼 콜리전 윗면 = 높이의 절반(버섯형 시절 판정 — 비교·되돌리기용).
@export var 옛_서는높이: bool = false:
	set(v): 옛_서는높이 = v; _재구성()

## 부품 그림 — 판 윗면 '발 자리' 가 판 그림 위에서 몇 % 아래인가(그림에서 잰 값: 집 = 윗면 판자 가운데 · 하수도 = 타원 가운데)
const 발자리_비율 := {"집": 0.33, "하수도": 0.37}
const 부품_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/점프대/"
## 코일 그림 안의 바퀴 수 — 가로로 이만큼 잘라 따로 움직인다
const 코일_바퀴 := 3
## 출렁임: x(t) = 휴지 + e^(−t/τ)(a·cos ωt + b·sin ωt) · ω = 2π × 4Hz → 0.6초에 2.4번 · τ = 0.2초
const 출렁_주파수 := 4.0
const 출렁_감쇠 := 0.2

var _눌림: float = 0.0        ## (옛 버섯형 호환) 밟힌 직후 1 → 0.35초에 0
var _쿨: float = 0.0          ## 연속 발동 방지

var _텍스처 := {}             ## {"판": Texture2D, "코일": …, "받침": …} — 재질이 바뀌면 비운다
var _길이: float = 0.92       ## 지금 코일 길이(자연 길이 = 1)
var _그린_길이: float = -1.0  ## 마지막으로 그린 길이 — 0.25px 넘게 달라질 때만 다시 그린다
var _단계: int = 0            ## 0 대기(숨쉬기) · 1 눌림 · 2 출렁임
var _단계_t: float = 0.0
var _숨_t: float = 0.0
var _눌림_시작: float = 0.92
var _출렁_b: float = 0.0      ## 위 식의 b — 최대가 정확히 `최대_늘어남` 이 되도록 시작할 때 찾는다
var _화면안: bool = true
var _잰_깊이: float = -1.0       ## 실행 때 발밑 지형에서 잰 그림 깊이(−1 = 아직 못 잼)


func _ready() -> void:
	_재구성()
	_길이 = 휴지_길이
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return
	add_to_group("도약대")
	collision_layer = 0
	collision_mask = 1          # 플레이어만 본다
	monitoring = true
	set_physics_process(true)
	set_process(true)
	# 숨쉬기 위상을 도약대마다 다르게(한 방의 도약대가 똑같이 숨 쉬면 기계처럼 보인다)
	_숨_t = fmod(absf(global_position.x * 0.013 + global_position.y * 0.007), 숨_주기)
	# 화면 밖에선 숨쉬기를 멈춘다 — 판정(_physics_process)은 계속 돈다
	var 알림 := VisibleOnScreenNotifier2D.new()
	알림.rect = Rect2(-폭 * 0.6, -높이 * 2.2, 폭 * 1.2, 높이 * 2.6)
	add_child(알림)
	알림.screen_entered.connect(func(): _화면안 = true; set_process(true))
	알림.screen_exited.connect(func(): _화면안 = false)
	_깊이_재기.call_deferred()


## 발밑 지형의 발 그림 깊이를 물리로 잰다(체크포인트 `_바닥_맞추기` 와 같은 방법 · 실행 때 한 번).
func _깊이_재기() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -6), global_position + Vector2(0, 48), 1)
	var 몸 := get_node_or_null("발판") as StaticBody2D
	if 몸:
		q.exclude = [몸.get_rid()]
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	var 깊이 := 0.0
	if not r.is_empty():
		var 면 := r["collider"] as Node
		while 면 and not 면.has_method("발_그림_깊이"):
			면 = 면.get_parent()
		if 면 and 면 != self:
			깊이 = float(면.call("발_그림_깊이"))
	_잰_깊이 = 깊이
	queue_redraw()


## 이 도약대 위에 선 몸의 발 그림 깊이(player_anim 이 발밑 콜리전의 조상에서 찾는다) = 그림을 내린 만큼.
func 발_그림_깊이() -> float:
	if 그림_깊이 >= 0.0:
		return 그림_깊이
	if _잰_깊이 >= 0.0:
		return _잰_깊이
	# 에디터(물리 없음)·재기 전: 재질로 짐작 — 집 = 목재 상판(+7) · 하수도 = 벽돌(0)
	return 7.0 if _재질_이름() == "집" else 0.0


func _서는_높이() -> float:
	return 높이 * 0.5 if 옛_서는높이 else 서는_높이


func _재구성() -> void:
	if not is_inside_tree():
		return
	var 서는 := _서는_높이()
	var cs := get_node_or_null("판정") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "판정"
		cs.visible = false
		add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	# 판정은 판 윗면 위쪽 띠 — 옆에서 부딪혀도 튀지 않게 한다.
	#   예전: −0.3h ~ −1.0h (윗면 −0.5h 기준 위 0.5h · 아래 0.2h) → 지금: 같은 짜임을 윗면 −서는 기준으로 옮겼다.
	r.size = Vector2(폭 * 0.92, 높이 * 0.7)
	cs.position = Vector2(0, -서는 - 높이 * 0.15)

	# 밟고 설 수 있는 실제 바닥 (Area2D 는 밀어내지 못한다)
	var 바디 := get_node_or_null("발판") as StaticBody2D
	if 바디 == null:
		바디 = StaticBody2D.new()
		바디.name = "발판"
		add_child(바디)
		if Engine.is_editor_hint() and owner:
			바디.owner = owner
	바디.collision_layer = 1
	바디.collision_mask = 0
	var bcs := 바디.get_node_or_null("모양") as CollisionShape2D
	if bcs == null:
		bcs = CollisionShape2D.new()
		bcs.name = "모양"
		bcs.visible = false
		바디.add_child(bcs)
		if Engine.is_editor_hint() and owner:
			bcs.owner = owner
	var br := bcs.shape as RectangleShape2D
	if br == null:
		br = RectangleShape2D.new()
		bcs.shape = br
	# 두께는 예전과 같은 높이 × 0.5 — 윗면만 `서는` 으로 옮겼다(옆에서 걸어 들어오면 막히는 것도 예전과 같다)
	br.size = Vector2(폭, 높이 * 0.5)
	bcs.position = Vector2(0, -서는 + 높이 * 0.25)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_쿨 = maxf(_쿨 - delta, 0.0)
	if _쿨 > 0.0:
		return
	for 몸 in get_overlapping_bodies():
		var p := 몸 as CharacterBody2D
		if p == null:
			continue
		# 위에서 내려오는 중일 때만 (아래에서 머리로 받으면 안 튄다)
		var v: Vector2 = p.velocity
		if v.y < -10.0:
			continue
		if 색_제한 and int(p.get("player_color")) != 색:
			continue
		v.y = 도약속도
		p.velocity = v
		_눌림 = 1.0
		_쿨 = 0.18
		_튕김_시작(p)
		break


## 튕겨 올린 순간 — 스프링 움직임 시작 + 점프대 이펙트(파문·물감 가시·속도 줄) + 소리.
func _튕김_시작(p: CharacterBody2D) -> void:
	_단계 = 1
	_단계_t = 0.0
	_눌림_시작 = _길이
	set_process(true)
	var 이펙트색: int = 색 if 색_제한 else int(p.get("player_color"))
	var fx := p.get_node_or_null("ActionFX")
	if fx and fx.has_method("점프대"):
		fx.점프대(이펙트색, global_position + Vector2(0, -_서는_높이() + 발_그림_깊이()), p)
	var 소리 := p.get_node_or_null("효과음")
	if 소리 and 소리.has_method("도약대"):
		소리.도약대()


func _process(delta: float) -> void:
	_눌림 = maxf(_눌림 - delta / 0.35, 0.0)
	var 목표 := _길이
	match _단계:
		0:
			# 대기 — 화면 밖이면 멈춘다(돌아오면 notifier 가 다시 켠다)
			if not _화면안:
				set_process(false)
				return
			_숨_t = fmod(_숨_t + delta, 숨_주기)
			목표 = 휴지_길이 + 숨_폭 * sin(TAU * _숨_t / 숨_주기)
		1:
			# 눌림 — 0.06초에 0.70 까지(부드럽게 들어가는 ease-out)
			_단계_t += delta
			var k := clampf(_단계_t / 눌림_시간, 0.0, 1.0)
			목표 = lerpf(_눌림_시작, 눌림_길이, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_단계 = 2
				_단계_t = 0.0
				_출렁_b = _출렁_계수()
		2:
			# 출렁임 — 감쇠 진동. 끝나면 숨쉬기 위상을 0 에서 다시 시작(휴지 길이에서 끊김 없이 이어진다)
			_단계_t += delta
			var w := TAU * 출렁_주파수
			var a := 눌림_길이 - 휴지_길이
			목표 = 휴지_길이 + exp(-_단계_t / 출렁_감쇠) * (a * cos(w * _단계_t) + _출렁_b * sin(w * _단계_t))
			if _단계_t >= 출렁임_시간:
				_단계 = 0
				_숨_t = 0.0
	_길이 = 목표
	# 그림이 눈에 띄게(코일 높이 기준 0.25px 넘게) 달라질 때만 다시 그린다
	if absf(_길이 - _그린_길이) * _코일_높이() > 0.25:
		queue_redraw()


## 최대 길이가 정확히 `최대_늘어남` 이 되는 b 를 찾는다(이분법 · 튕길 때 한 번 · 150 표본 × 30 번).
func _출렁_계수() -> float:
	var w := TAU * 출렁_주파수
	var a := 눌림_길이 - 휴지_길이
	var 목표 := 최대_늘어남 - 휴지_길이
	var lo := 0.0
	var hi := 3.0
	for _i in 30:
		var b := (lo + hi) * 0.5
		var 최대 := -INF
		for j in 150:
			var t := 출렁임_시간 * float(j) / 149.0
			최대 = maxf(최대, exp(-t / 출렁_감쇠) * (a * cos(w * t) + b * sin(w * t)))
		if 최대 < 목표:
			lo = b
		else:
			hi = b
	return (lo + hi) * 0.5


## 시험·촬영용 — 지금 코일 길이(자연 길이 = 1)
func 코일_길이() -> float:
	return _길이


# ── 그림 ─────────────────────────────────────────────────────────────────────
func _재질_이름() -> String:
	if 재질 == 1:
		return "집"
	if 재질 == 2:
		return "하수도"
	# 자동: 이 도약대가 들어 있는 씬 파일 경로로 판단(하수도 = scenes/world_2_클로드/)
	var 씬 := ""
	if owner and owner.scene_file_path != "":
		씬 = owner.scene_file_path
	elif is_inside_tree() and get_tree().current_scene:
		씬 = get_tree().current_scene.scene_file_path
	return "하수도" if 씬.contains("world_2") else "집"


func _부품(이름: String) -> Texture2D:
	if _텍스처.is_empty():
		var 재 := _재질_이름()
		for n in ["판", "코일", "받침"]:
			var 경로 := 부품_폴더 + "%s_%s.png" % [재, n]
			_텍스처[n] = load(경로) if ResourceLoader.exists(경로) else null
		_텍스처["재질"] = 재
	return _텍스처.get(이름)


## 세로 배율 — 휴지 길이에서 판 윗면(발 자리)이 정확히 `서는 높이` 에 오도록 부품 전체 키를 맞춘다.
##   (부품 그림은 게임 크기 2배로 저장 → 대략 0.5. 판은 가로를 폭에 맞추고, 코일·받침은 이 세로 배율을 가로에도 쓴다)
##   아래 _draw 의 쌓는 식과 같은 식이다: 받침(겹침 3) + 코일 × 휴지(판 겹침 2) + 판 위끝 ~ 발 자리.
func _세로배율() -> float:
	var 판 := _부품("판")
	var 코 := _부품("코일")
	var 받 := _부품("받침")
	if 판 == null or 코 == null or 받 == null:
		return 0.5
	var 발 := float(발자리_비율.get(_텍스처.get("재질", "집"), 0.35))
	var 원키 := 받.get_height() - 3.0 + 코.get_height() * 휴지_길이 - 2.0 + 판.get_height() * (1.0 - 발)
	return _서는_높이() / maxf(원키, 1.0)


func _코일_높이() -> float:
	var 코 := _부품("코일")
	return (코.get_height() if 코 else 40.0) * _세로배율()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	if 아트슬롯.그림_있나(self):
		return
	_그린_길이 = _길이
	var 판 := _부품("판")
	var 코 := _부품("코일")
	var 받 := _부품("받침")
	if 판 == null or 코 == null or 받 == null:
		_버섯_그리기()      # 부품 그림이 없으면(도구를 안 돌렸으면) 예전 그림
		return
	# 그림 전체를 발밑 상판 가운데로 내린다(판정은 그대로 — 위 `그림_깊이` 주석)
	draw_set_transform(Vector2(0.0, 발_그림_깊이()))
	var sy := _세로배율()
	var sx_판 := 폭 / float(판.get_width())       # 판은 판정 폭에 맞춘다(밟는 면 = 보이는 면)
	# 코일·받침 가로 배율 — 세로(sy)만 따르면 32px 높이에서 코일이 판 아래 가늘게 보인다 → 판 배율의 80% 아래로는 안 줄인다.
	#   (세로가 가로보다 덜 늘어나 코일 바퀴가 납작해 보이는데, 대기 = '살짝 눌린 스프링' 이라 오히려 맞는 모양이다)
	var sx := maxf(sy, sx_판 * 0.8)
	# ① 받침 — 바닥(y 0)에 붙는다
	var 받w := 받.get_width() * sx
	var 받h := 받.get_height() * sy
	draw_texture_rect(받, Rect2(-받w * 0.5, -받h, 받w, 받h), false)
	# ② 코일 — 받침 윗면(겹침 3px)에서 위로 `길이` 만큼. 바퀴마다 키는 조금만, 나머지는 간격으로.
	var 코w := 코.get_width() * sx
	var 코h0 := 코.get_height() * sy               # 자연 길이
	var 코바닥 := -받h + 3.0 * sy
	var L := 코h0 * _길이
	var 바퀴h0 := 코h0 / 코일_바퀴
	var 바퀴h := 바퀴h0 * clampf(_길이, 0.85, 1.12)
	var 간격 := L / 코일_바퀴
	var 원바퀴 := 코.get_height() / float(코일_바퀴)
	for i in 코일_바퀴:
		# 아래 바퀴부터 그린다(위 바퀴가 아래 바퀴 위에 겹친다 — 눌렸을 때 철선이 포개지는 모양)
		var 칸 := 코일_바퀴 - 1 - i                  # 그림 안에서의 순번(0 = 맨 위 바퀴)
		var 가운데y := 코바닥 - 간격 * (i + 0.5)
		var src := Rect2(0.0, 원바퀴 * 칸, 코.get_width(), 원바퀴)
		draw_texture_rect_region(코, Rect2(-코w * 0.5, 가운데y - 바퀴h * 0.5, 코w, 바퀴h), src)
	# ③ 판 — 코일 윗끝(겹침 2px)에 얹힌다. 색_제한이면 판 색으로 알린다.
	var 판h := 판.get_height() * sy
	var 판바닥 := 코바닥 - L + 2.0 * sy
	var 판색 := Color(0.82, 0.82, 0.82)            # 무색 = 장치 명도(77 근처 — 판 평균 92 × 0.82)
	if 색_제한:
		판색 = Color(1.7, 1.7, 1.7) if 색 == ColorDefs.WHITE else Color(0.22, 0.22, 0.22)
	draw_texture_rect(판, Rect2(-판.get_width() * sx_판 * 0.5, 판바닥 - 판h, 판.get_width() * sx_판, 판h), false, 판색)
	if 색_제한 and 색 == ColorDefs.BLACK:
		# 검정 판은 어두운 화면에서 사라진다 → 판 위 가장자리에 얇은 밝은 테(카드 0 "black objects … lighter rim")
		draw_line(Vector2(-폭 * 0.47, 판바닥 - 판h + 1.5), Vector2(폭 * 0.47, 판바닥 - 판h + 1.5),
			Color(0.34, 0.34, 0.35, 0.9), 1.5)


## 부품 그림이 없을 때만 쓰는 예전 버섯형(회귀 방지)
func _버섯_그리기() -> void:
	var w := 폭
	var h := 높이 * (1.0 - _눌림 * 0.55)
	var 갓 := PackedVector2Array()
	var n := 20
	for i in n + 1:
		var a := PI * float(i) / float(n)
		갓.append(Vector2(-cos(a) * w * 0.5, -sin(a) * h))
	갓.append(Vector2(w * 0.5, 0))
	갓.append(Vector2(-w * 0.5, 0))
	var 본색 := Color(0.10, 0.10, 0.11)
	if 색_제한:
		본색 = Color(0.90, 0.90, 0.92) if 색 == ColorDefs.WHITE else Color(0.07, 0.07, 0.08)
	draw_colored_polygon(갓, 본색)
	draw_polyline(갓, Color(0.72, 0.72, 0.75, 0.9), 2.5, true)
