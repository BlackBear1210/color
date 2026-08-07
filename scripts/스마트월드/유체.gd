@tool
extends Area2D
## ============================================================================
## [2026-08-01 신규] 유체 — 물 / 연기 공용
## ----------------------------------------------------------------------------
## ▣ 왜 한 스크립트인가
##   기획서를 보면 물과 연기는 **방향만 반대**고 규칙이 거의 같다.
##     · 흰색/검정/회색이 있다        · 반대색 플레이어와 닿으면 사망
##     · 물리 충돌이 없다(통과)        · 색칠할 수 없다
##     · 서로 섞인다 (검+흰=회 / 검+회=검 / 흰+회=흰)
##   다른 점은 물은 위→아래, 연기는 아래→위로 흐르고, **물만** 반대색 페인트를 지운다.
##   → `종류` 하나로 갈라 쓰는 게 두 파일로 나누는 것보다 규칙이 어긋날 위험이 적다.
##
## ▣ 색 섞임이 왜 저 규칙인가 (기획 그대로)
##   검+흰=회 : 반대색이 만나 중화
##   검+회=검 / 흰+회=흰 : 회색은 "아우르는 색"이라 순색에 흡수된다
##
## ▣ 물리 레이어
##   layer 32 = 유체. 총알(mask 16|32)이 감지해서 반대색이면 막힌다.
##   mask 1|8 = 지형(반대색 페인트를 지우기 위해) + 플레이어(사망 판정)
## ============================================================================
class_name 유체

enum 종류_ { 물, 연기 }

@export var 종류: 종류_ = 종류_.물:
	set(v):
		종류 = v
		queue_redraw()

## ⚠[2026-08-07 버그 수정] 예전에는 `색` 만 바꿨는데, 아래 `_physics_process` 의
##   섞임 계산이 매 프레임 `_원래색` 을 기준으로 색을 다시 정하기 때문에
##   **런타임에 색을 바꾸면 다음 물리 프레임에 원래 색으로 되돌아갔다.**
##   (레버로 물 색을 바꾸거나 도구/테스트가 색을 지정할 때 조용히 무시됐다)
##   → 바깥에서 색을 지정하면 `_원래색` 도 같이 갱신한다. 섞임 계산이 스스로
##     색을 쓸 때만 `_섞는중` 플래그로 그 갱신을 건너뛴다.
@export var 색: int = ColorDefs.WHITE:
	set(v):
		색 = v
		if not _섞는중:
			_원래색 = v
		queue_redraw()

## 유체가 차지하는 사각 영역(px). 폭 좁고 세로로 길면 "떨어지는 물줄기"가 된다.
@export var 크기: Vector2 = Vector2(64, 260):
	set(v):
		크기 = Vector2(maxf(v.x, 8.0), maxf(v.y, 8.0))
		_모양_갱신()
		queue_redraw()

## 흐름 속도(px/s) — 그림이 흐르는 속도. 물리에는 영향 없음.
@export var 흐름속도: float = 130.0

## 이 유체가 켜져 있는가. 제어 배관(레버)이 껐다 켰다 한다.
@export var 켜짐: bool = true:
	set(v):
		켜짐 = v
		_켜짐_반영()

var _흐름: float = 0.0
var _원래색: int = ColorDefs.WHITE
var _코어: 페인트코어 = null
var _지운적: Dictionary = {}         ## 같은 지형을 매 프레임 지우지 않도록 기록
## 섞임 계산이 스스로 `색` 을 쓰는 동안만 true. 이때는 `_원래색` 을 건드리면 안 된다
## (건드리면 "섞인 결과"가 기준색이 되어 물이 원래 색으로 못 돌아온다).
var _섞는중: bool = false


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 8
	monitoring = true
	monitorable = true
	_모양_갱신()
	_원래색 = 색
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("유체")
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
	set_physics_process(true)
	set_process(true)
	_켜짐_반영()


func _모양_갱신() -> void:
	var c := get_node_or_null("모양") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "모양"
		add_child(c)
	var s := c.shape as RectangleShape2D
	if s == null:
		s = RectangleShape2D.new()
		c.shape = s
	s.size = 크기
	# 물은 위에서 아래로 흐르니 원점을 위쪽 끝에 둔다 (배관 출구에 맞추기 쉽게).
	# 연기는 아래에서 위로 흐르므로 원점이 아래쪽 끝.
	c.position = Vector2(0, 크기.y * 0.5) if 종류 == 종류_.물 else Vector2(0, -크기.y * 0.5)


func _켜짐_반영() -> void:
	monitoring = 켜짐
	visible = 켜짐


# ── 규칙 ───────────────────────────────────────────────────────────────────
## 반대색 투사체를 막는다 (기획: "물과 상반되는 색의 투사체를 막는다").
## 회색 유체는 아무것도 안 막는다 — 회색은 두 색을 아우르는 색이라서.
func 총알_막나(총알색: int) -> bool:
	if not 켜짐 or 색 == ColorDefs.GRAY:
		return false
	return 총알색 != 색


## 플레이어가 이 유체에 닿으면 죽는가.
func 반대색인가(플레이어색: int) -> bool:
	if not 켜짐 or 색 == ColorDefs.GRAY:
		return false
	return 플레이어색 != 색


## 유체는 색칠할 수 없다 → 총알이 맞아도 페인트는 회수된다.
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return 색


## 다른 유체와 섞였을 때의 결과색. 기획의 표를 그대로 옮겼다.
static func 섞기(a: int, b: int) -> int:
	if a == b:
		return a
	# 검 + 흰 = 회
	if (a == ColorDefs.BLACK and b == ColorDefs.WHITE) or (a == ColorDefs.WHITE and b == ColorDefs.BLACK):
		return ColorDefs.GRAY
	# 검 + 회 = 검 / 흰 + 회 = 흰  (순색이 회색을 흡수)
	return a if b == ColorDefs.GRAY else b


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not 켜짐:
		return

	# ── 1) 다른 유체와 섞이기 ──
	var 섞인색 := _원래색
	for 영역 in get_overlapping_areas():
		var f := 영역 as 유체
		if f and f.켜짐 and f.종류 == 종류:
			섞인색 = 유체.섞기(섞인색, f._원래색)
	if 섞인색 != 색:
		_섞는중 = true
		색 = 섞인색
		_섞는중 = false

	# ── 2) 물만: 닿은 지형의 반대색 페인트를 지운다 (지워진 색은 회수된다) ──
	if 종류 != 종류_.물 or 색 == ColorDefs.GRAY:
		return
	for 바디 in get_overlapping_bodies():
		var 대상 := _칠할대상_찾기(바디)
		if 대상 == null:
			continue
		if 대상.has_method("물에_안지워짐") and 대상.물에_안지워짐():
			continue                              # 통과 플랫폼은 물에 안 지워진다
		if not 대상.has_method("현재색") or not 대상.has_method("되돌리기"):
			continue
		var 대상색: int = 대상.현재색()
		# 반대색만 지운다. 같은 색·무색·회색은 그대로 둔다.
		if 대상색 < 0 or 대상색 == ColorDefs.GRAY or 대상색 == 색:
			continue
		if _지운적.has(대상):
			continue
		if 대상.되돌리기():
			_지운적[대상] = true
			if _코어:
				# 지워진 색은 회수된다 = 탄약이 돌아온다
				_코어.부분_자동회수(대상, 1)


func _칠할대상_찾기(바디: Object) -> Node:
	var n := 바디 as Node
	while n != null:
		if n.has_method("되돌리기"):
			return n
		n = n.get_parent()
	return null


# ── 그림 ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not 켜짐:
		return
	_흐름 += delta * 흐름속도
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	if not 켜짐:
		return
	var 기본 := Color(0.55, 0.58, 0.62)
	match 색:
		ColorDefs.BLACK: 기본 = Color(0.10, 0.11, 0.14)
		ColorDefs.WHITE: 기본 = Color(0.90, 0.93, 0.95)
		ColorDefs.GRAY:  기본 = Color(0.50, 0.51, 0.52)

	var 위 := 0.0 if 종류 == 종류_.물 else -크기.y
	var 아래 := 위 + 크기.y
	var 반 := 크기.x * 0.5
	var 방향 := 1.0 if 종류 == 종류_.물 else -1.0

	# ── 본체 ──
	# 예전에는 사각형 + 가로 줄무늬였는데 사다리처럼 보였다.
	# 좌우 가장자리를 사인으로 흔든 폴리곤으로 바꾸니 "흐르는 기둥"으로 읽힌다.
	var 칸 := 16
	var 왼: PackedVector2Array = PackedVector2Array()
	var 오른: PackedVector2Array = PackedVector2Array()
	for i in 칸 + 1:
		var t := float(i) / float(칸)
		var y := lerpf(위, 아래, t)
		# 위치마다 위상이 다른 사인 두 개 → 규칙적이지 않은 물결
		var w := 반 * (1.0 + sin(y * 0.05 + _흐름 * 0.04 * 방향) * 0.10
			+ sin(y * 0.11 - _흐름 * 0.07 * 방향) * 0.06)
		왼.append(Vector2(-w, y))
		오른.append(Vector2(w, y))
	var 본체 := PackedVector2Array(왼)
	for i in range(오른.size() - 1, -1, -1):
		본체.append(오른[i])
	# 연기는 더 옅게 — 기체라서
	var 진하기 := 0.34 if 종류 == 종류_.물 else 0.22
	draw_colored_polygon(본체, Color(기본.r, 기본.g, 기본.b, 진하기))

	# ── 흐름 결 ──
	# 세로로 길게 늘어진 가는 선을 스크롤시킨다. 가로 줄무늬보다 훨씬 "흐른다"는 느낌.
	var 결수 := 5
	for i in 결수:
		var fx := lerpf(-반 * 0.62, 반 * 0.62, float(i) / float(결수 - 1))
		var 길이 := 크기.y * 0.30
		var 시작 := fmod(_흐름 * 방향 * (0.8 + float(i) * 0.13) + float(i) * 97.0, 크기.y + 길이)
		if 시작 < 0.0:
			시작 += 크기.y + 길이
		var y0 := clampf(위 + 시작 - 길이, 위, 아래)
		var y1 := clampf(위 + 시작, 위, 아래)
		if y1 - y0 > 2.0:
			draw_line(Vector2(fx, y0), Vector2(fx, y1),
				Color(기본.r, 기본.g, 기본.b, 0.30), 3.0)

	# ── 가장자리 하이라이트 — 유리 같은 굴절 느낌 ──
	draw_polyline(왼, Color(1, 1, 1, 0.20), 2.0)
	draw_polyline(오른, Color(1, 1, 1, 0.12), 2.0)
