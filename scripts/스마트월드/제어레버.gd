@tool
extends Area2D
## ============================================================================
## [2026-08-01 신규] 제어 배관 — 원형 레버 / 직선 레버
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 플레이어가 가까이 가서 상호작용할 수 있다.
##   · **원형 레버** = 흐름을 멈춘다 (밸브).
##   · **직선 레버** = 흐르는 방향을 바꾼다.
##
## ▣ 조작
##   레버 근처에서 `interact`(기본 E) 를 누른다.
##   ⚠ E 는 페인트 수동 회수와 같은 키다. 레버 범위 안에 있을 때는 **레버가 우선**
##     이며(월드.gd 가 그렇게 중재한다), 범위 밖에서 누르면 평소대로 회수된다.
##     "가까이 가서 상호작용" 이라는 기획 문구를 그대로 지키면서 키를 아끼는 방법.
## ============================================================================
class_name 제어레버

enum 종류_ { 원형, 직선 }

## 호퍼 도안과 같은 주철 손잡이. 원형 밸브의 외관에만 사용한다.
const 주철_손잡이 = preload("res://assets/textures/obstacles/valve/cast_iron_v1/handwheel.png")
const 주철_레버부품 = preload("res://assets/textures/obstacles/switch/cast_iron_v1/parts.png")

@export var 종류: 종류_ = 종류_.원형:
	set(v): 종류 = v; queue_redraw()

## 원형: 이 유체를 켜고 끈다.
@export var 대상_유체: NodePath
## 직선: 켤 쪽 / 끌 쪽 — 레버를 넘길 때마다 둘이 뒤바뀐다.
## ★[2026-10-02] 원형에서 `갈래_B` 를 채우면 "둘 중 하나" 밸브가 된다 — `대상_유체` 와 **반대로** 켜진다.
##   도형님 2-1 도면: "흰색물_2 와 _3 은 밸브로 연결 · 처음엔 _3 · 돌리면 _2 · 한 번 더 돌리면 _3".
##   직선 레버로도 같은 동작이 되지만 도면이 **밸브(원형 손잡이)** 라 원형을 넓혔다. 비워 두면 예전 그대로.
@export var 갈래_A: NodePath
@export var 갈래_B: NodePath
## ★[2026-10-03] 원형 + `갈래_B` 에서 켜면 **세 상태 순환** 밸브가 된다(도형님 2-3 도면 · 벨브_2):
##   "처음에는 검정물과 흰색물이 활성화 → 돌리면 검정물 비활성화·흰색물 활성화 → 한 번 더 돌리면
##    검정물 활성화·흰색물 비활성화 → 한 번 더 돌리면 다 활성화. 이걸 계속 반복."
##   단계 0 = 둘 다(`대상_유체` + `갈래_B`) · 1 = `갈래_B` 만 · 2 = `대상_유체` 만.
##   두 물이 한 호퍼로 들어가면 0 단계에서 출구가 회색이 된다(호퍼.gd 입구_색_합치기).
##   끄면(기본) 예전 "둘 중 하나" 그대로라 2-1 밸브 동작은 안 바뀐다.
@export var 세_상태_순환: bool = false
## ★[2026-10-10 Claude · 2-8] **숨은 밸브** — 이 물(켜짐을 가진 것)이 흐르는 동안은 밸브가 안 보이고 조작도 안 된다.
##   도형님 2-8 도면: "검정물_2를 끄면 그 뒤에 숨겨진 벨브_2가 보이게 됨". 물 뒤에 가려진 손잡이를 표현한다.
##   비워 두면(기본) 예전 그대로 늘 보인다.
@export var 숨김_유체: NodePath

@export var 반응반경: float = 74.0:
	set(v): 반응반경 = maxf(v, 24.0); _모양_갱신(); queue_redraw()

## 레버를 씬에 놓은 순간부터 물이 흐를지, 어느 갈래가 먼저 열릴지 정한다.
## 기본값은 기존 레버와 같은 "켜짐 + A 갈래"라 이전 스테이지의 동작은 바뀌지 않는다.
@export_group("초기 상태")
@export var 시작_켜짐: bool = true
@export var 시작_갈래_A: bool = true
@export_group("")

## ★[2026-09-30] 주철 배관 연결 — 관이 레버/밸브의 어디에, 어느 방향으로 붙는가.
##   도형님 지적: "레버나 밸브가 배관 끝과 연결되어 있지 않다" — 관 경로를 손으로 적은 좌표에 맞췄더니
##   직선 레버 위 48px 에 관이 떠 있었고, 원형 밸브는 축 끝과 24px 벌어져 있었다.
##   → 장치가 포트(자리·방향)를 알려 주고, 배관(`하수도_주철배관.gd` 의 `시작_장치`)이 거기에 스스로 붙는다.
## 직선 레버에서 관이 나가는 쪽. (원형 밸브는 늘 축을 따라 위아래로 관이 지나간다)
@export_enum("오른쪽:0", "왼쪽:1") var 배관_방향: int = 0:
	set(v): 배관_방향 = v; queue_redraw()
## 원형 밸브 아래로 관을 더 내리는 길이(px). 밸브 축 끝(+32)보다 바닥이 낮으면 관이 허공에서 끝나 보인다
## (2-5 L4 에서 실측) → 바닥 윗면까지의 차이만큼 넣는다. 0 = 축 끝에서 끝.
@export_range(0.0, 400.0, 1.0) var 배관_아래_연장: float = 0.0:
	set(v): 배관_아래_연장 = v; queue_redraw()
## 주철 배관이 붙으면 배관이 켠다. 원형 밸브는 예전의 가는 축(18px) 그림을 감춘다 — 굵은 관이 대신 지나간다.
var 배관_연결됨: bool = false:
	set(v): 배관_연결됨 = v; queue_redraw()

var 켜짐: bool = true
var _A쪽: bool = true
## 세 상태 순환 밸브의 지금 단계(0 둘 다 · 1 B 만 · 2 대상만). 늘 0 에서 시작한다 — 도면이 "처음에는 둘 다".
var 단계: int = 0
var _각도: float = 0.0
var _목표각도: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1                 # 플레이어 감지
	monitoring = true
	_모양_갱신()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("제어레버")
	# 씬 인스펙터 값으로 먼저 맞춘 뒤 유체에 반영해야, 시작 프레임에 닫힌 밸브가 열리지 않는다.
	켜짐 = 시작_켜짐
	_A쪽 = 시작_갈래_A
	# 세 상태 순환은 `시작_켜짐` 을 보지 않는다 — 늘 "둘 다 흐름" 에서 시작한다(도면 = 회색물_1).
	if _세_상태인가():
		단계 = 0
		켜짐 = true
	# 처음부터 실제 갈래와 손잡이 방향을 맞춰 가운데에 멈춘 잘못된 상태 표시를 없앤다.
	if 종류 == 종류_.직선:
		_목표각도 = 0.6 if _A쪽 else -0.6
		_각도 = _목표각도
	_반영()
	set_process(true)
	queue_redraw()


func _모양_갱신() -> void:
	var c := get_node_or_null("모양") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "모양"
		add_child(c)
	var s := c.shape as CircleShape2D
	if s == null:
		s = CircleShape2D.new()
		c.shape = s
	s.radius = 반응반경


## 배관이 붙는 자리(전역) · 관이 장치에서 나가는 방향 · 관 위에 둘러 줄 칼라(전역 자리들).
##   원형 밸브: 관이 바닥(축 아래 끝 +32)에서 올라와 바퀴 뒤를 지나 위로 나간다 → 바퀴 위아래에 칼라 두 개.
##   직선 레버: 받침 옆면 가운데(±29, +6)에서 옆으로 나간다 — 관 지름 40 = 받침 높이 40 이라 옆면에 꼭 맞는다.
func 배관_포트() -> Dictionary:
	if 종류 == 종류_.원형:
		return {"위치": to_global(Vector2(0, 32.0 + 배관_아래_연장)), "방향": Vector2.UP,
			"칼라": [to_global(Vector2(0, -33)), to_global(Vector2(0, 30))]}
	var s := 1.0 if 배관_방향 == 0 else -1.0
	return {"위치": to_global(Vector2(29.0 * s, 6.0)), "방향": Vector2(s, 0.0),
		"칼라": [to_global(Vector2(35.0 * s, 6.0))]}


## 플레이어가 상호작용 범위 안에 있는가 (월드.gd 가 E 키 중재에 쓴다)
func 닿아있나() -> bool:
	# 숨은 밸브는 가린 물이 흐르는 동안 없는 것과 같다 — E 가 회수로 넘어간다.
	if _숨어있나():
		return false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false


## 월드.gd 가 E 입력을 넘겨준다.
func 조작() -> void:
	if 종류 == 종류_.원형:
		if _세_상태인가():
			# 0 → 1 → 2 → 0 … 가운데 표시등(켜짐)은 `대상_유체` 가 흐르는지를 보여 준다.
			단계 = (단계 + 1) % 3
			켜짐 = 단계 != 1
		else:
			켜짐 = not 켜짐
		_목표각도 += PI * 0.5
	else:
		_A쪽 = not _A쪽
		_목표각도 = 0.6 if _A쪽 else -0.6
	_반영()
	queue_redraw()


func _세_상태인가() -> bool:
	return 세_상태_순환 and 종류 == 종류_.원형 and not 갈래_B.is_empty()


func _반영() -> void:
	if _세_상태인가():
		_켜기(대상_유체, 단계 != 1)
		_켜기(갈래_B, 단계 != 2)
		return
	if 종류 == 종류_.원형:
		_켜기(대상_유체, 켜짐)
		# ★[2026-10-02] 둘 중 하나 밸브 — 갈래_B 는 대상_유체 와 늘 반대. 빈 경로를 get_node 에 넘기지 않으려고 먼저 거른다.
		if not 갈래_B.is_empty():
			_켜기(갈래_B, not 켜짐)
	else:
		_켜기(갈래_A, _A쪽)
		_켜기(갈래_B, not _A쪽)


## ★[2026-09-07] 예전에는 대상을 `as 유체` 로 못박아서 **웅덩이를 못 물렸다**
##   (`as` 는 형이 다르면 조용히 null 이라, 레버를 당겨도 아무 일도 안 일어났다).
##   → `켜짐` 을 가진 것이면 무엇이든 켠다. 유체·웅덩이 둘 다, 앞으로 생길 것도 그대로.
##   덤으로 켜는 순간 `차오르기_시작()` 도 불러 준다 —
##   "레버를 당기면 물이 차오른다" 가 배선 없이 성립한다.
func _켜기(경로: NodePath, 값: bool) -> void:
	var n := get_node_or_null(경로)
	if n == null or not ("켜짐" in n):
		return
	n.set("켜짐", 값)
	if 값 and n.has_method("차오르기_시작"):
		n.call("차오르기_시작")
	elif not 값 and n.has_method("차오르기_멈춤"):
		n.call("차오르기_멈춤")


## 숨김_유체가 흐르고 있나(= 밸브가 가려져 있나). 경로가 비었거나 대상이 없으면 안 숨는다.
func _숨어있나() -> bool:
	if 숨김_유체.is_empty():
		return false
	var n := get_node_or_null(숨김_유체)
	return n != null and ("켜짐" in n) and bool(n.get("켜짐"))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 숨은 밸브 — 보임은 바뀔 때만 대입한다(같은 값을 매 프레임 넣지 않는다 · 성능 규칙 §8).
	if not 숨김_유체.is_empty():
		var 보임 := not _숨어있나()
		if visible != 보임:
			visible = 보임
	if absf(_목표각도 - _각도) > 0.005:
		_각도 = lerpf(_각도, _목표각도, 1.0 - exp(-10.0 * delta))
		queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	# 상호작용 범위 — 플레이어가 "여기서 누르면 된다"를 알 수 있게 은은하게
	draw_arc(Vector2.ZERO, 반응반경, 0.0, TAU, 40, Color(1, 1, 1, 0.07), 1.5)

	if 종류 == 종류_.원형:
		# 배관/축은 고정하고 바퀴만 돌려 호퍼 도안의 밸브 구조를 유지한다.
		# ★[2026-09-30] 주철 배관이 붙어 있으면 그 관이 축 자리를 지나가므로 가는 축은 그리지 않는다.
		if not 배관_연결됨:
			draw_rect(Rect2(-9, -32, 18, 64), Color(0.13,0.13,0.13))
			draw_line(Vector2(-7,-32), Vector2(-7,32), Color(0.34,0.34,0.34), 2.0)
			for y in [-30.0, 24.0]:
				draw_rect(Rect2(-12, y, 24, 5), Color(0.27, 0.27, 0.27))
				draw_line(Vector2(-11,y), Vector2(11,y), Color(0.45,0.45,0.45), 1.0)
		draw_set_transform(Vector2.ZERO, _각도)
		draw_texture_rect(주철_손잡이, Rect2(-27,-27,54,54), false)
		draw_set_transform(Vector2.ZERO)
		# 손잡이 네 살의 회전만으로는 켜짐을 구분하기 어려워 기존 중심 상태표시를 보존한다.
		var 상태켜짐 := 시작_켜짐 if Engine.is_editor_hint() else 켜짐
		draw_circle(Vector2.ZERO, 2.5, Color(0.85,0.85,0.82) if 상태켜짐 else Color(0.16,0.16,0.16))
	else:
		# 승인된 주철 받침/손잡이를 별도 영역으로 그려 축만 돌리고 받침은 지형에 고정한다.
		# 기존 받침의 바닥 y=26을 보존해 이미 배치한 레버가 지형 위에 뜨지 않게 한다.
		draw_texture_rect_region(주철_레버부품, Rect2(-29.5, -14.0, 58.2, 40.0), Rect2(90, 871, 448, 306))
		var 표시각도 := (0.6 if 시작_갈래_A else -0.6) if Engine.is_editor_hint() else _각도
		draw_set_transform(Vector2.ZERO, 표시각도)
		draw_texture_rect_region(주철_레버부품, Rect2(-7.0, -47.7, 14.0, 54.8), Rect2(877, 684, 125, 489))
		draw_set_transform(Vector2.ZERO)
