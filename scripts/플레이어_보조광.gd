@tool
extends Node2D
## ============================================================================
## [2026-09-05 STEP 5 신규] 플레이어 보조광 (Player Follow Fill Light)
## ----------------------------------------------------------------------------
## ▣ 이 빛이 하는 일 — **딱 하나**
##   플레이어 주변 지형의 **최소 가시성**을 보조한다.
##
## ▣ 이 빛이 하지 않는 일 (도형님 지시)
##   · 방을 밝히는 것            → 그건 환경 주광(창문·등)의 일이다
##   · 주광원 노릇                → 공간의 방향성은 고정 광원이 만든다
##   · 그림자 만들기              → 켜면 점프할 때마다 그림자·노멀 하이라이트가
##                                  한꺼번에 따라 움직여 화면이 부산스러워진다
##   · 플레이어를 빛나게 하는 것   → 후광이 보이면 실패다
##
##   ★판정 기준: 플레이어가 움직일 때 **빛이 따라오는 게 눈에 띄면 너무 센 것**이다.
##     "손전등"이 아니라 "어두운 공간의 최소 가시성을 주는 ambient fill" 이다.
##
## ▣ 왜 매 프레임 추적 코드가 아니라 자식 노드인가
##   Player 의 자식으로 두면 위치 갱신이 **엔진의 트랜스폼 전파**로 공짜다.
##   추적 코드를 쓰면 물리 프레임과 한 프레임 어긋나 빛이 미세하게 끌려다닌다.
##
## ▣ ⚠ 그런데 Player 는 스케일이 비균등하다
##   `Player.tscn` 루트 scale = (0.7950, 0.3677). 그냥 자식으로 달면 빛이
##   세로로 눌린 **타원**이 된다(`zone_visuals.gd` 가 자식 대신 추적을 쓴 이유가 이것).
##   → 이 노드가 부모의 전역 스케일의 **역수**를 자기 scale 로 잡아서 상쇄한다.
##     그래서 자식 구조를 유지하면서도 빛은 정확히 원형이다.
##
## ▣ Player 핵심 코드는 한 줄도 안 건드린다
##   `player.gd` · `gun.gd` · `bullet.gd` 무수정. 이 노드는 씬에 자식으로만 붙는다.
##   BLACK/WHITE 상태와도 연결하지 않는다 — 보조광은 어느 색에서도 같은 중립광이다.
## ============================================================================

## ⚠ class_name 이 아니라 **경로 preload** — 헤드리스 검사가 전역 클래스 등록보다 먼저 돈다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")

@export var 켜기: bool = true:
	set(v):
		켜기 = v
		if _빛: _빛.visible = v

## 세기. 조명표준의 기준값(0.35)을 쓰되 스테이지마다 인스펙터로 미세조정할 수 있게 둔다.
@export_range(0.0, 1.2, 0.01) var 밝기: float = 조명표준.보조광_세기:
	set(v): 밝기 = v; _다시_만들기()

@export_range(80.0, 900.0, 10.0) var 반경: float = 조명표준.보조광_반경:
	set(v): 반경 = v; _다시_만들기()

## 플레이어 발밑 기준 **전역 px** 로 잰 광원 높이. 가슴께가 자연스럽다.
## (부모 스케일이 비균등해서 로컬 좌표로 적으면 눈으로 가늠이 안 된다)
@export var 눈높이_전역px: float = -48.0:
	set(v): 눈높이_전역px = v; _다시_만들기()

var _빛: PointLight2D = null


func _ready() -> void:
	_다시_만들기()


## 부모 스케일이 바뀔 일은 거의 없지만, 에디터에서 만지면 즉시 반영되어야 한다.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_PARENTED:
		_상쇄_스케일()


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	_빛 = get_node_or_null("PointLight2D") as PointLight2D
	if _빛 == null:
		_빛 = PointLight2D.new()
		_빛.name = "PointLight2D"
		add_child(_빛)
		# 씬에 구워지지 않게 owner 를 주지 않는다 — 런타임 부속이다.
	_빛.texture = 조명표준.방사형_텍스처()
	_빛.color = 조명표준.보조광_색
	_빛.energy = 밝기
	_빛.texture_scale = 반경 / 조명표준.텍스처_반지름
	# ★그림자는 **절대** 켜지 않는다 (§위 주석). 표준 적용이 height/ADD 만 건드린다.
	조명표준.적용(_빛, 밝기)
	_빛.shadow_enabled = false
	_빛.visible = 켜기
	_상쇄_스케일()


## 부모(Player)의 비균등 스케일을 상쇄해서 빛을 정확한 원으로 만든다.
func _상쇄_스케일() -> void:
	var 부모 := get_parent() as Node2D
	if 부모 == null:
		return
	var s := 부모.global_scale
	# 0 으로 나누지 않게 방어. (스케일 0 인 부모는 어차피 안 보인다)
	scale = Vector2(
		1.0 / s.x if absf(s.x) > 0.0001 else 1.0,
		1.0 / s.y if absf(s.y) > 0.0001 else 1.0)
	# 이 노드가 이미 전역 1:1 이므로 오프셋을 전역 px 그대로 쓸 수 있다.
	position = Vector2(0.0, 눈높이_전역px / (s.y if absf(s.y) > 0.0001 else 1.0))
	if _빛:
		_빛.position = Vector2.ZERO
