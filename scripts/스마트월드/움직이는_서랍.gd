@tool
extends AnimatableBody2D
## ============================================================================
## [2026-08-31 신규] 움직이는 서랍 — 주기적으로 열리고 닫히는 가구 발판
## ----------------------------------------------------------------------------
## ▣ 왜 새로 만들었나 (기존 시스템을 먼저 찾아봤다 — 도형님 §12)
##   `scripts/장애물/움직이는발판.gd` 가 이미 있고 `AnimatableBody2D` + `sync_to_physics`
##   문법도 거기서 배웠다. 그런데 그건 **`PaintPlatform`(v3) 을 상속**한다:
##     · v3 의 384px 덩어리 아트를 스스로 그린다 → 이 스테이지의 SS2D·원화 화풍과 안 맞는다
##     · 왕복이 `sin()` 이라 **멈춰 있는 구간이 없다** — 도형님 §5 가 요구한
##       "닫힘 → 여는 중 → 열림 → 닫는 중" 4 단계 주기를 만들 수 없다
##   → 그래서 **이동 로직만 40 줄**로 새로 쓰고, 그림은 SS2D 에 맡긴다.
##     `sync_to_physics = true` · `_physics_process` 에서 이동 — 이 두 가지는
##     움직이는발판.gd 의 검증된 문법을 그대로 따랐다.
##
## ▣ 노드 구조 (빌더가 만든다)
##     서랍 (이 스크립트 · AnimatableBody2D · layer 1 / mask 0)
##     ├── 판정 (CollisionShape2D)          ← 실제로 밟히는 것
##     └── 그림 (스마트지형 SS2D · WOOD)     ← 보이는 것. StaticBody2D 는 빌더가 지운다
##   ★그림과 콜리전이 **한 노드 밑**에 있으므로 언제나 같이 움직인다.
##     "콜리전은 끊겼는데 그림만 이어져 있는" 상태가 구조적으로 불가능하다(도형님 §1).
##
## ▣ ★절대 하지 않는 것
##   `collision.disabled = true` 로 서랍을 껐다 켜지 않는다.
##     · 밟고 선 플레이어가 원인 없이 떨어진다
##     · `레벨검사.gd` 는 물리 프레임 **한 장**만 보므로 시간가변 콜리전을 아예 못 본다
##   → 서랍은 **물리적으로 미끄러져 나온다.** 윗면은 언제나 단단하다.
## ============================================================================
class_name 움직이는서랍

## 닫힘 위치에서 **+x 방향**으로 얼마나 나오나(px).
@export var 열림_거리: float = 300.0
@export_range(0.0, 10.0) var 닫힘_유지: float = 1.0
@export_range(0.05, 5.0) var 여는_시간: float = 0.5
@export_range(0.0, 10.0) var 열림_유지: float = 1.2
@export_range(0.05, 5.0) var 닫는_시간: float = 0.5
## 주기 안의 어디서 시작할지(초). ★기본은 "열림 유지" 의 첫 순간이다 —
## 그래야 스폰 직후·`레벨검사` 의 첫 물리 프레임에서 길이 이어져 보인다.
@export var 시작_위상: float = 1.5
## ★[2026-09-01 도형님] "뒤로 가서 겹쳐졌을 때 안 보였으면 좋겠어."
##   서랍은 빌더에서 `z_index = -1` 로 옷장 뒤에 보내 두었다. 그런데 WOOD 채움이
##   **완전 불투명이 아니라** 완전히 닫힌 상태에서도 서랍 테두리가 옷장 위로 비친다
##   (실제로 찍어 확인했다 — 슬래브 안에 직사각형 윤곽선이 남는다).
##   → 완전히 닫혀 있는 동안만 그림을 끈다. 조금이라도 나와 있으면 켜고,
##     그때는 z 정렬이 알아서 안쪽 부분을 가려 준다.
##   ⚠ **콜리전(`판정`)은 절대 끄지 않는다.** 윗면은 언제나 단단해야 한다(위 §절대 하지 않는 것).
##     끄는 것은 그림뿐이고, 닫혀 있을 때 그 자리는 옷장이 대신 받쳐 준다.
@export var 닫히면_숨김: bool = true

var _시작위치: Vector2 = Vector2.ZERO   ## 씬에 저장된 위치 = **닫힘** 위치
var _t: float = 0.0
var _그림: Node2D = null                ## 매 프레임 get_node 하지 않으려고 잡아 둔다


func _ready() -> void:
	_시작위치 = position
	_그림의_콜리전_떼기()
	_그림 = get_node_or_null("그림") as Node2D
	if Engine.is_editor_hint():
		return
	# ★플레이어를 태우고 가려면 반드시 필요하다. 안 켜면 서랍만 빠져나가고
	#   플레이어는 그 자리에 미끄러진다(움직이는발판.gd 가 남긴 교훈).
	sync_to_physics = true
	collision_layer = 1      # 밟을 수 있는 지형과 같은 레이어 (기존 규약)
	collision_mask = 0       # 아무것도 감지하지 않는다
	_t = 시작_위상
	set_physics_process(true)
	# 첫 프레임부터 제 위치에 있어야 레벨검사가 열린 상태를 본다.
	position = _시작위치 + Vector2(열림_거리 * _진행(_t), 0.0)


func 주기() -> float:
	return maxf(닫힘_유지 + 여는_시간 + 열림_유지 + 닫는_시간, 0.1)


## 주기 안의 시각 t 에서 열린 정도 0(닫힘) ~ 1(열림).
## 여닫는 구간은 `smoothstep` 으로 부드럽게 — 등속으로 밀면 플레이어가 튕긴다.
func _진행(t: float) -> float:
	var s := fposmod(t, 주기())
	if s < 닫힘_유지:
		return 0.0
	s -= 닫힘_유지
	if s < 여는_시간:
		return smoothstep(0.0, 1.0, s / 여는_시간)
	s -= 여는_시간
	if s < 열림_유지:
		return 1.0
	s -= 열림_유지
	return smoothstep(1.0, 0.0, s / maxf(닫는_시간, 0.001))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var 열림 := _진행(_t)
	if 닫히면_숨김 and _그림 != null:
		_그림.visible = 열림 > 0.001      # 완전히 닫힌 동안만 끈다
	var 새자리 := _시작위치 + Vector2(열림_거리 * 열림, 0.0)
	# ★★[2026-08-31] `sync_to_physics` 만으로는 플레이어가 **56 % 밖에 안 실렸다**.
	#   (실측: 서랍이 254px 움직이는 동안 플레이어는 141px 만 따라왔다)
	#   서랍이 닫힐 때 바깥쪽에 서 있으면 그대로 허공에 남아 떨어진다 = 억울한 죽음.
	#   → `constant_linear_velocity` 로 **이 프레임에 실제로 움직인 속도**를 물리 서버에
	#     알려 준다. `move_and_slide()` 가 이 값을 발판 속도로 읽어 플레이어를 정확히 태운다.
	#     (StaticBody2D 계열이 원래 갖고 있는 기능이다 — 새 시스템이 아니다)
	constant_linear_velocity = (새자리 - position) / maxf(delta, 0.0001)
	position = 새자리


## 지금 얼마나 열려 있나(0~1). 시험 도구가 읽는다.
func 열린정도() -> float:
	return _진행(_t)


## ★자식 `그림`(SS2D) 이 들고 있는 StaticBody2D 를 떼어 낸다.
##
## ▣ 왜 런타임에 하나
##   SS2D 는 제 밑에 StaticBody2D + CollisionPolygon2D 를 만든다. 그게 남아 있으면
##     ① 밟히는 면이 **두 개**가 된다(이 노드의 `판정` 과 SS2D 의 것)
##     ② SS2D 쪽은 StaticBody2D 라 `sync_to_physics` 가 없다 → 서랍이 움직여도
##        그 위의 플레이어를 **못 태우고** 미끄러뜨린다
##   빌더에서 지워 봤지만 `그림` 은 **인스턴스된 씬**이라 다시 로드하면 자식이 되살아났다
##   (레벨검사가 "StaticBody2D x 2304~2592" 라는 선반을 실제로 잡아냈다).
##   → 씬이 살아난 뒤, 즉 여기서 지운다.
##
## ⚠ `지형.gd` 는 콜리전 노드가 없으면 `_충돌레이어_갱신()`·`bake_collision()` 이
##   그냥 빠져나가므로(get_collision_polygon_node() 가 null) 안전하다.
func _그림의_콜리전_떼기() -> void:
	var 그림 := get_node_or_null("그림")
	if 그림 == null:
		return
	var 몸 := 그림.get_node_or_null("StaticBody2D")
	if 몸 != null:
		그림.remove_child(몸)
		몸.queue_free()
