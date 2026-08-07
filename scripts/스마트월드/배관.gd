@tool
extends Node2D
## ============================================================================
## [2026-08-01 신규] 기본 배관 (직선 / 3갈래 / 4갈래)
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 플랫폼이 아니라 **배경처럼** 존재한다 (밟을 수 없고 충돌도 없다).
##   · 색칠할 수 없다.
##   · **흐르는 것의 색에 따라 배관 색이 바뀐다.**
##   · 직선 / 3갈래 / 4갈래 3종류.
##
## ▣ 색을 어디서 받나
##   `연결_유체` 에 물/연기 노드를 지정하면 매 프레임 그 색을 따라간다.
##   비워두면 무색(어두운 금속)으로 남는다.
##   → 저장고에서 색을 바꾸면 배관 → 물줄기까지 색이 줄줄이 따라오는 게 눈에 보인다.
## ============================================================================
class_name 배관

enum 모양_ { 직선, 삼갈래, 사갈래 }

@export var 모양: 모양_ = 모양_.직선:
	set(v): 모양 = v; queue_redraw()

## 직선일 때만 의미 있음 — true 면 세로 배관.
@export var 세로: bool = false:
	set(v): 세로 = v; queue_redraw()

## 배관 한 칸의 길이(px)와 굵기(px).
@export var 길이: float = 128.0:
	set(v): 길이 = maxf(v, 16.0); queue_redraw()
@export var 굵기: float = 26.0:
	set(v): 굵기 = maxf(v, 6.0); queue_redraw()

## 이 배관을 흐르는 유체. 지정하면 색이 따라온다.
@export var 연결_유체: NodePath

var _색: int = -1
var _유체: 유체 = null


func _ready() -> void:
	z_index = -6                      # 지형보다 뒤 = "배경처럼 존재함"
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not 연결_유체.is_empty():
		_유체 = get_node_or_null(연결_유체) as 유체
	set_process(_유체 != null)
	queue_redraw()


func _process(_delta: float) -> void:
	if _유체 == null:
		return
	var 새색: int = _유체.색 if _유체.켜짐 else -1
	if 새색 != _색:
		_색 = 새색
		queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 금속 := Color(0.26, 0.27, 0.30)
	var 내부 := Color(0.14, 0.15, 0.17)
	match _색:
		ColorDefs.BLACK: 내부 = Color(0.07, 0.07, 0.09)
		ColorDefs.WHITE: 내부 = Color(0.88, 0.90, 0.92)
		ColorDefs.GRAY:  내부 = Color(0.50, 0.50, 0.51)

	var 반 := 굵기 * 0.5
	# ⚠[2026-08-02] 원래 이름이 'ㄹ' 이었는데, Godot 이
	#   "The identifier 'ㄹ' has misleading characters" 경고를 띄운다
	#   (자음 하나짜리 한글은 다른 문자와 헷갈릴 수 있다고 판단). 풀어서 쓴다.
	var 반길이 := 길이 * 0.5

	# 팔(arm) 목록을 모양별로 만든다. 각 팔은 중심에서 바깥으로 뻗는 방향.
	# ⚠ 배열 리터럴은 타입이 없는 Array 라 Array[Vector2] 에 그대로 대입하면 런타임 오류가 난다.
	#    assign() 을 쓰면 원소를 검사하며 타입 배열로 옮겨 담아준다.
	var 팔: Array[Vector2] = []
	match 모양:
		모양_.직선:
			팔.assign([Vector2(0, -1), Vector2(0, 1)] if 세로 else [Vector2(-1, 0), Vector2(1, 0)])
		모양_.삼갈래:
			팔.assign([Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)])
		모양_.사갈래:
			팔.assign([Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)])

	for d in 팔:
		var 끝 := d * 반길이
		# 바깥 금속
		draw_line(Vector2.ZERO, 끝, 금속, 굵기)
		# 내부(흐르는 것의 색)
		draw_line(Vector2.ZERO, 끝, 내부, 굵기 - 9.0)
		# 이음매 링 — 타일셋처럼 이어 보이게 하는 디테일
		draw_circle(끝, 반 + 2.0, 금속)
		draw_circle(끝, 반 - 4.0, 내부)

	# 가운데 이음부
	draw_circle(Vector2.ZERO, 반 + 3.0, 금속)
	draw_circle(Vector2.ZERO, 반 - 4.0, 내부)
	# 위쪽 하이라이트 — 원통처럼 보이게 하는 한 줄
	for d in 팔:
		if absf(d.y) < 0.5:
			draw_line(Vector2(d.x * 반, -반 + 4), d * 반길이 + Vector2(0, -반 + 4),
				Color(1, 1, 1, 0.10), 3.0)
