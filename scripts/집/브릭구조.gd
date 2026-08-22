@tool
extends StaticBody2D
## ============================================================================
## [2026-08-22 신규] 브릭 9-슬라이스 구조 지형 블록
## ----------------------------------------------------------------------------
## ▣ 도형님 지시(그대로)
##   "테두리는 벽돌이나 집 안의 나무 느낌, 플레이어가 닿을 수 없는 안쪽은 그냥 검정.
##    큰 지형을 구축할 때 하나의 큰 바닥을 깐다고 생각하고 만들어."
##   참조 영상(리틀 나이트메어류): 지형은 **겉 테두리만 모양이 있고 안쪽은 검정으로 통일**.
##
## ▣ 무엇인가
##   `assets/tileset/brick.png`(768×768, 2×2=4종)의 **좌하 = 테두리 벽돌 + 검정 안쪽**을
##   NinePatchRect(9-슬라이스)로 늘려, 아무 크기의 바닥·벽·천장·공중 플랫폼을 만든다.
##   9-슬라이스라 **테두리 벽돌은 안 늘어나고 안쪽 검정만 늘어난다** = 참조 영상과 동일.
##
## ▣ 왜 SS2D 가 아니라 이걸 쓰나 (도형님 선택 = "브릭 9-슬라이스 블록")
##   SS2D 지형은 점을 에디터에서 찍어야 하고 테두리가 얇은 띠(strip)다. 이 블록은
##   **사각형 하나 = 큰 지형 하나** 라 스크립트로 깔고 헤드리스로 검증하기 쉽다.
##
## ▣ 색·안전 규칙 (게임 규칙과의 계약)
##   이 블록은 **무색 구조물** — `반대색인가()` 메서드를 두지 않는다.
##   → `월드.gd _발밑_반대색인가` 는 그 메서드가 있는 지형만 죽음으로 판정하므로,
##     이 블록은 **누구나(검/백) 안전하게 딛는 뼈대**가 된다(집 벽·바닥·계단).
##   색 퍼즐(칠해야 밟는 발판·색 전환)은 이 뼈대 **위에** 기존 칠 가능 발판을 얹어 만든다.
##   ⚠ 색 = 검정/흰색은 **그림 톤**만 고른다(둘 다 안전). 게임의 색 판정과는 무관하다.
##
## ▣ owner 주의(§규약 6): 에디터에서 만든 자식에만 owner 를 준다. 런타임 자식엔 안 준다.
## ============================================================================
class_name 브릭구조

## brick.png 아틀라스 4분면(각 384×384).
##   좌하 = 검정 테두리벽돌+검정안쪽(기본) · 우하 = 흰색 테두리+흰안쪽
##   좌상 = 검정 꽉찬벽돌 · 우상 = 흰색 꽉찬벽돌
enum 룩_ { 검정_테두리, 흰색_테두리, 검정_꽉참, 흰색_꽉참 }

const 브릭_경로 := "res://assets/tileset/brick.png"
const 분면 := 384.0

## 블록 크기(px). 콜리전(사각형)과 그림(9-슬라이스)이 이 값을 함께 쓴다. 원점 = 블록 **중심**.
@export var 크기: Vector2 = Vector2(400, 120):
	set(v):
		크기 = Vector2(maxf(v.x, 16.0), maxf(v.y, 16.0))
		_재구성()

## 그림 톤(안전성과 무관 — 위 머리말 참고).
@export var 룩: 룩_ = 룩_.검정_테두리:
	set(v):
		룩 = v
		_재구성()

## 9-슬라이스 테두리 두께(px). 이만큼은 안 늘어나고 안쪽만 늘어난다.
## brick.png 벽돌 프레임 두께에 맞춘 기본값. 에디터에서 미세조정 가능.
@export_range(8.0, 180.0) var 테두리: float = 60.0:
	set(v):
		테두리 = v
		_재구성()

var _np: NinePatchRect = null
var _cs: CollisionShape2D = null


func _ready() -> void:
	# 일반 지형과 같은 레이어(1). 마스크 0 — 이 블록은 아무도 감지할 필요 없다.
	collision_layer = 1
	collision_mask = 0
	_재구성()


## brick.png 안에서 이 룩이 쓰는 384×384 영역.
func _영역() -> Rect2:
	match 룩:
		룩_.흰색_테두리: return Rect2(분면, 분면, 분면, 분면)   # 우하
		룩_.검정_꽉참:   return Rect2(0.0, 0.0, 분면, 분면)     # 좌상
		룩_.흰색_꽉참:   return Rect2(분면, 0.0, 분면, 분면)     # 우상
		_:               return Rect2(0.0, 분면, 분면, 분면)     # 좌하(기본)


## 콜리전(사각형)과 그림(9-슬라이스)을 크기·룩에 맞춘다. **여러 번 불러도 결과 같음**(멱등).
func _재구성() -> void:
	if not is_inside_tree():
		return

	# ── 콜리전 (블록 중심 기준 사각형) ──
	if _cs == null:
		_cs = get_node_or_null("모양") as CollisionShape2D
	if _cs == null:
		_cs = CollisionShape2D.new()
		_cs.name = "모양"
		_cs.visible = false        # 오목 기즈모가 2D 뷰를 덮는 문제 회피(§지형공통 동일)
		add_child(_cs)
		if Engine.is_editor_hint() and owner:
			_cs.owner = owner
	var r := _cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		_cs.shape = r
	r.size = 크기

	# ── 그림 (9-슬라이스 브릭) ──
	if _np == null:
		_np = get_node_or_null("브릭") as NinePatchRect
	if _np == null:
		_np = NinePatchRect.new()
		_np.name = "브릭"
		_np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_np)
		if Engine.is_editor_hint() and owner:
			_np.owner = owner
	if _np.texture == null:
		_np.texture = load(브릭_경로)
	_np.region_rect = _영역()
	_np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 픽셀아트라 필수
	# 테두리는 블록 절반을 못 넘는다(넘으면 9-슬라이스가 겹쳐 깨진다).
	var m := clampf(테두리, 8.0, minf(크기.x, 크기.y) * 0.5 - 1.0)
	_np.patch_margin_left = int(m)
	_np.patch_margin_right = int(m)
	_np.patch_margin_top = int(m)
	_np.patch_margin_bottom = int(m)
	_np.size = 크기
	_np.position = -크기 * 0.5      # 콜리전이 중심 기준이므로 그림도 중심 정렬
	_np.z_index = -1                 # 위에 얹는 발판·오브젝트보다 뒤에 그린다
