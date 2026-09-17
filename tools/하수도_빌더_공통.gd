## ============================================================================
## [2026-09-14 신규] 하수도 빌더 공통 — 2-1·2-2 재제작부터 쓰는 SS2D 붙이기·검산·부품 헬퍼
## ----------------------------------------------------------------------------
## ▣ 왜 따로 뺐나
##   `build_하수도_2-8.gd` 까지의 빌더는 이웃 조각을 48px 씩 **겹쳐** 슬롯을 없앴다.
##   2026-09-12 도형님 지시("겹치게 만들면 내가 수정하기 힘들다. 딱 붙게")와
##   아스트라가 만든 2-9~2-11(꼭짓점 공유 · 겹침 0 · 격자 16 · 콜리전 = 외곽선 그대로)이
##   새 기준이 됐다. 그 기준을 **한 곳**에 적어 두고 스테이지 빌더는 좌표표만 갖게 한다.
##
## ▣ 기준값 (2026-09-14 도형님 확정 — 아스트라 2-10·2-11 을 그대로 따른다)
##   · Player 인스턴스 `점프_높이_칸 10 · 점프_거리_칸 20` → 점프 높이 160 · 거리 320
##   · 씬 루트 `카메라_줌 = 1.0` → 화면 1920×1080 = 시야 그대로
##   · 씬 루트 `치명_낙하거리 = 1500` (도형님이 나중에 손볼 값 — 빌더는 이 숫자만 박는다)
##   ⚠ 2-1~2-8 은 원래 점프 거리 160·줌 1.0·낙하 520 이었다. 이 값들이 스테이지마다
##     제각각이면 같은 폭의 틈이 한 판에서는 건너지고 다른 판에서는 못 건넌다.
##     → 하수도 씬은 전부 이 세 값을 **씬에 명시**한다(기본값에 기대지 않는다).
##
## ▣ SS2D 붙이기 규약 (가이드라인 §6)
##   · 이웃 지형은 꼭짓점을 공유한다. 겹침 0 · 틈 0. → `검산()` 이 16px 격자 래스터로 잡는다.
##   · 모든 꼭짓점 16 격자 · 변 길이 ≥ 90 · 시계 방향 · 곡선 없음.
##   · 콜리전 폴리곤 = 외곽선 그대로(`collision_offset = 0`). 예전 24px 깎임이 있으면
##     이웃끼리 48px 슬롯이 생겨 플레이어가 낀다(2-8 이 겹침으로 때웠던 이유).
##   · Template 은 WALL 4종만. 흰 구간은 **흰색 Template** 을 쓴다(검정판에 시작상태만
##     주면 에디터에서 검게 보여 헷갈린다).
##
## ▣ 쓰는 법 (빌더에서)
##   const 공 := preload("res://tools/하수도_빌더_공통.gd")
##   var b := 공.new()
##   b.지형(부모, "이름", 공.사각(x0,y0,x1,y1), 공.검정)      # 시계 방향 점 목록
##   b.유령(부모, "이름", 점들, 공.흰색)                        # 칠해야 밟히는 발판
##   b.검산(프레임, 빈공간들)                                    # 겹침·구멍·격자·변 길이
##   b.색비율_보고()
## ============================================================================
extends RefCounted

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
## ★[2026-09-17] 옛 집 WALL Template → **하수도 전용 프리팹**(프롬프트 §E · 필독_오퍼스 인계 §3).
##   기본 지형 = masonry_v02 벽돌 본체 + 윗면 마감 + 옆면 마감(하수도_자연발판.gd 가 이웃을 보고 가린다).
##   공중 선반 = ledge_v03 얇은 석조 선반(`공중선반()`). 둘을 서로 대체하지 않는다.
const T_벽_검 := "res://scenes/지형/하수도/하수도_기본지형_검정.tscn"
const T_벽_흰 := "res://scenes/지형/하수도/하수도_기본지형_흰색.tscn"
const T_선반_검 := "res://scenes/지형/하수도/하수도_공중선반_검정.tscn"
const T_선반_흰 := "res://scenes/지형/하수도/하수도_공중선반_흰색.tscn"
const T_관 := 키트 + "PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn"
const S_회전톱 := "res://scenes/장애물/회전톱.tscn"

const S_유체 := "res://scenes/집/스마트월드_장애물/유체.tscn"
const S_웅덩이 := "res://scenes/집/스마트월드_장애물/웅덩이.tscn"
const S_레버 := "res://scenes/집/스마트월드_장애물/제어레버.tscn"
const S_호퍼 := "res://scenes/집/스마트월드_장애물/호퍼.tscn"
const S_통과플랫폼 := "res://scenes/집/스마트월드_장애물/통과플랫폼.tscn"
const S_통로 := "res://scenes/집/스마트월드_장애물/연결통로.tscn"
const S_가시 := "res://scenes/장애물/가시.tscn"
const S_체크포인트 := "res://scenes/장애물/체크포인트.tscn"
const S_플레이어 := "res://scenes/player/Player.tscn"

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")

# ── 지형.gd 의 `enum 상태 { 무색, 검정, 흰색, 회색 }` ────────────────────────
const 무색 := 0
const 검정 := 1
const 흰색 := 2

# ── 유체.gd / 웅덩이.gd 의 `enum 물색_ { 검정색 = 0, 흰색 = 1, 회색 = 2 }` ──────
const 물_검 := 0
const 물_흰 := 1
const 물_회 := 2

# ── 기준값 (머리 주석 참고) ──────────────────────────────────────────────────
const 점프_높이_칸 := 10.0
const 점프_거리_칸 := 20.0
const 카메라_줌 := 1.0
const 치명_낙하거리 := 1500.0
const 격자 := 16.0
const 최소변 := 90.0

## 지은 지형 목록 — 검산·색비율 보고용. [이름, 점들(월드), 색, 역할]
## 역할: "플랫폼"(플레이어가 닿는 지형) · "채움"(화면 채우는 덩어리 · 비율 계산에서 뺀다) · "외곽"
var 지형표: Array = []
var 오류: int = 0
## 검산이 남기는 래스터(칸마다 색 · −1 = 빈칸). 색비율_보고 가 "보이는 면" 을 셀 때 쓴다.
var _칸색: PackedInt32Array = PackedInt32Array()
## 인스턴스 안에 있지만 값을 씬에 남겨야 하는 노드(일방통행 콜리전). 저장 때 owner 를 준다.
var _덮어쓸_노드들: Array = []
## ★[2026-09-17] 지형 재질을 스테이지 전용으로 바꿔 끼울 때(절대 UV 로 줄눈을 맞춘 .tres). 비우면 프리팹 기본.
var 재질_검: Resource = null
var 재질_흰: Resource = null
var 재질_선반_검: Resource = null
var 재질_선반_흰: Resource = null
var _칸x: int = 0
var _칸y: int = 0


# ============================================================================
# 모양 헬퍼 — 전부 시계 방향(y 는 아래로 커진다 → 왼위 → 오른위 → 오른아래 → 왼아래)
# ============================================================================
static func 사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## 점 목록을 그대로 받는다(사다리꼴·ㄱ자·계단 등). 시계 방향인지는 검산이 본다.
static func 다각(점들: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in 점들:
		p.append(Vector2(float(v[0]), float(v[1])))
	return p


## 오른쪽으로 내려가는 경사로(직각삼각형 + 아래 덩어리). 윗면이 (x0,y0)→(x1,y1).
## 기울기 = (y1−y0)/(x1−x0). 30° 권장 → run = rise / tan30 ≈ rise × 1.73.
static func 경사로(x0: float, y0: float, x1: float, y1: float, 바닥: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, 바닥), Vector2(x0, 바닥)])


# ============================================================================
# 씬 뼈대
# ============================================================================
## ★★인스턴스는 전부 `instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)` 로 만든다.
##   그냥 `instantiate()` 로 만든 인스턴스는 PackedScene.pack() 이 값을 **스크립트 기본값**과 비교해서,
##   서브씬(유체.tscn 은 회색)과 다르더라도 스크립트 기본값(흰색)과 같으면 저장을 건너뛴다.
##   → 흰 물이 씬에서 회색으로 살아났다(2-2 주행검사에서 잡힘). 편집 상태로 만들면 에디터처럼
##     서브씬 값과 비교하므로 바꾼 값이 전부 남는다.
## 월드 루트. 카메라 줌·치명 낙하거리는 **여기서만** 박는다.
func 루트(이름: String, 스테이지_이름: String, 리밋: Rect2, 시작: Vector2, 낙사_y: float) -> Node2D:
	var r: Node2D = 월드_S.new()
	r.name = 이름
	r.set("스테이지_이름", 스테이지_이름)
	r.set("카메라_리밋", 리밋)
	r.set("카메라_줌", 카메라_줌)
	r.set("시작_위치", 시작)
	r.set("낙사_y", 낙사_y)
	r.set("치명_낙하거리", 치명_낙하거리)

	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)
	r.add_child(코어)

	for n in ["지형", "장치", "위험물", "체크포인트"]:
		var g := Node2D.new()
		g.name = n
		r.add_child(g)
	return r


func 플레이어(루트: Node2D, 위치: Vector2) -> Node2D:
	var p := (load(S_플레이어) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	p.name = "Player"
	p.position = 위치
	# ★스테이지가 기본값을 덮어쓴다 — Player.tscn 기본은 점프 거리 10칸(160px)이라
	#   20칸(320px)으로 설계한 틈을 못 건넌다(다음작업_프롬프트 §5-3 사고 재발 방지).
	p.set("점프_높이_칸", 점프_높이_칸)
	p.set("점프_거리_칸", 점프_거리_칸)
	루트.add_child(p)
	return p


func 끝점(루트: Node2D, 위치: Vector2) -> void:
	var m := Marker2D.new()
	m.name = "끝도달_검사점"
	m.position = 위치
	루트.add_child(m)


## 출구 통로. 원점 = 통로 바닥 중앙(지면 높이). +x 로 `깊이` 만큼 파고든다.
## 지형 빌더는 이 자리를 **비워 둬야** 한다: x [원점, 원점+깊이+두께] × y [원점−높이−두께, 원점+두께].
func 출구(루트: Node2D, 위치: Vector2, 다음_씬: String, 높이: float = 208.0, 깊이: float = 448.0, 두께: float = 96.0) -> Node2D:
	var t := (load(S_통로) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	t.name = "출구통로"
	t.position = 위치
	t.set("역할", 0)
	t.set("높이", 높이)
	t.set("깊이", 깊이)
	t.set("두께", 두께)
	t.set("다음_씬", 다음_씬)
	t.set("다음_진입점", "입구통로")
	# 암반 그림은 지형이 이미 채우므로 0. 켜 두면 옆 지형 위에 콘크리트 상자가 겹쳐 그려진다.
	t.set("암반_위", 0.0)
	t.set("암반_아래", 0.0)
	루트.add_child(t)
	return t


## 입구 통로(판정 없음). 앞 스테이지의 출구에서 넘어오면 여기서 걸어 나온다.
## −x 로 뻗는다: x [원점−깊이−두께, 원점] 을 비워 둔다.
func 입구(루트: Node2D, 위치: Vector2, 높이: float = 208.0, 깊이: float = 448.0, 두께: float = 96.0) -> Node2D:
	var t := (load(S_통로) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	t.name = "입구통로"
	t.position = 위치
	t.set("역할", 1)
	t.set("높이", 높이)
	t.set("깊이", 깊이)
	t.set("두께", 두께)
	t.set("암반_위", 0.0)
	t.set("암반_아래", 0.0)
	루트.add_child(t)
	return t


# ============================================================================
# 지형 (SS2D WALL Template)
# ============================================================================
## 점들은 **월드 좌표 · 시계 방향**. 노드 원점은 점들의 바운딩 중심(아스트라 방식).
##   역할 "플랫폼" = 플레이어가 닿을 수 있는 지형(색 비율 계산 대상)
##   역할 "채움"   = 화면을 메우는 덩어리(플레이어가 못 닿음 · 비율에서 제외)
## 일방통행 = 아래에서 위로는 통과하고 위에서만 밟히는 공중 발판(CollisionPolygon2D.one_way_collision).
##   ★지그재그 사다리에서 두 칸 위 발판이 도약 자리 위에 걸치면 머리(96)+점프(160)가 밑면에 박힌다.
##     2-2 주행검사에서 실제로 났다 → 공중 발판은 일방통행으로 둔다.
func 지형(부모: Node, 이름: String, 점들: PackedVector2Array, 색: int, 역할: String = "플랫폼",
		유령: bool = false, 필요횟수_수동: int = 0, 일방통행: bool = false) -> Node2D:
	var 템플릿 := T_벽_흰 if 색 == 흰색 else T_벽_검
	var 씬 := load(템플릿) as PackedScene
	if 씬 == null:
		push_error("빌더: Template 을 못 읽었다 — %s" % 템플릿)
		오류 += 1
		return null
	var n: Node2D = _모양노드(씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE))
	n.name = 이름

	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	var 중심 := (최소 + 최대) * 0.5
	n.position = 중심

	n.set("칠하기_허용", true)
	n.set("무색일때_통과", 유령)
	n.set("시작상태", 무색 if 유령 else 색)
	n.set("위치별_판정", true)
	if 필요횟수_수동 > 0:
		n.set("필요횟수_수동", 필요횟수_수동)
	# ★콜리전 = 외곽선 그대로. 깎임(24)이 남아 있으면 이웃 조각 사이에 48px 슬롯이 생긴다.
	n.set("collision_offset", 0.0)
	n.set("collision_size", 0.0)

	var 로컬 := PackedVector2Array()
	for p in 점들:
		로컬.append(p - 중심)
	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(로컬)
	점배열.close_shape()
	n.set_point_array(점배열)

	var 재질: Resource = 재질_흰 if 색 == 흰색 else 재질_검
	if 재질 != null:
		n.set("shape_material", 재질)

	var 폴리 := n.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		폴리.polygon = 로컬
		if 일방통행:
			폴리.one_way_collision = true
			폴리.one_way_collision_margin = 4.0
			# Template 안 노드의 값을 씬에 남기려면 owner 를 씬 루트로 줘야 한다(편집 가능한 자식).
			# 런타임 생성 노드가 아니라 Template 이 원래 갖고 있는 노드라 두 벌이 되지 않는다.
			_덮어쓸_노드들.append(폴리)
	n.set_meta("role", 역할)

	부모.add_child(n)
	지형표.append([이름, 점들, 색, 역할, 유령])
	return n


# ============================================================================
# ★[2026-09-17] 내부 반대색 벽돌 무늬(1번 · 필독_오퍼스 인계 §4 · 하수도_흑백벽돌_모듈_사용법 §1)
# ----------------------------------------------------------------------------
# 검정 지형 안에 흰 벽돌 덩어리(또는 그 반대)를 **그림으로만** 합성한다(별도 충돌·사망 없음).
# 줄눈 표(ROWS/JOINTS · masonry_v02 fill.png 실측 · tools/apply_stage22_masonry_joint.py 와 같은 값)에 맞춰
# 줄마다 사각형을 만들고, 모든 외곽에서 24px 이상 안쪽인지 검사한다. 재질은 `재질_검/흰`(절대 UV) 을 노드마다
# 복제해 미리보기 셰이더에도 같은 inlay_rects 를 넣는다(에디터·런타임 둘 다 갱신 규칙).
# ============================================================================
const 무늬_스크립트 := "res://scripts/스마트월드/하수도_내부벽돌.gd"
const 줄눈_배율 := 0.18
const 줄눈_ROWS := [0, 118, 237, 355, 470, 589, 705, 821, 937, 1024]
const 줄눈_JOINTS := [
	[0, 158, 364, 556, 720, 910, 1153, 1350, 1536],
	[0, 43, 248, 462, 635, 820, 1016, 1254, 1440, 1536],
	[0, 138, 340, 537, 719, 910, 1114, 1308, 1536],
	[0, 38, 234, 433, 619, 821, 1009, 1214, 1423, 1536],
	[0, 132, 329, 538, 724, 917, 1118, 1310, 1536],
	[0, 35, 240, 436, 623, 818, 1015, 1205, 1418, 1536],
	[0, 143, 338, 538, 727, 918, 1117, 1308, 1536],
	[0, 24, 232, 430, 618, 825, 1013, 1206, 1408, 1536],
	[0, 130, 326, 534, 716, 909, 1110, 1307, 1536],
]
const 무늬_흔듦_왼 := [32.0, 0.0, 48.0, 16.0, 64.0]
const 무늬_흔듦_오른 := [36.0, 0.0, 18.0, 54.0, 0.0]
## 재질의 fill_texture_offset.y (절대 UV 기준). 재질_검 을 넣을 때 같이 맞춘다.
var 줄눈_원점y := 1792.1


## lo~hi 사이의 줄 경계 y(월드)
func _줄들(lo: float, hi: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for t in range(-2, 25):
		for r in 줄눈_ROWS:
			var y: float = 줄눈_원점y + (t * 1024 + r) * 줄눈_배율
			if y > lo and y < hi:
				out.append(y)
	out.sort()
	return out


## x 에 가장 가까운 줄눈 x (그 높이 줄의 실제 이음새)
func _가까운_줄눈(x: float, y: float) -> float:
	var sy := (y - 줄눈_원점y) / 줄눈_배율
	var 타일 := int(floor(sy / 1024.0))
	var 로컬 := sy - 타일 * 1024.0
	var 행 := 0
	for i in 9:
		if 줄눈_ROWS[i] <= 로컬 and 로컬 < 줄눈_ROWS[i + 1]:
			행 = i
	var 가로타일 := int(floor(x / (1536.0 * 줄눈_배율)))
	var 최고 := x
	var 최소 := 1e20
	for t in range(가로타일 - 1, 가로타일 + 2):
		for j in 줄눈_JOINTS[행]:
			var jx: float = (t * 1536 + j) * 줄눈_배율
			if absf(jx - x) < 최소:
				최소 = absf(jx - x)
				최고 = jx
	return 최고


static func _점_변_거리(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## 이미 만든 지형 노드 n 에 무늬를 넣는다. 왼/오른 x 와 줄 범위(월드) · 흔듦 배율(좁은 벽은 줄인다).
## ⚠ 이 함수는 지형() 바로 뒤에 불러야 한다 — 스크립트를 바꾸면 export 값이 초기화되므로 여기서 다시 넣는다.
func 내부무늬(n: Node2D, 왼: float, 오른: float, lo: float, hi: float, 흔듦: float = 1.0) -> void:
	var 점들: PackedVector2Array = PackedVector2Array()
	for t in 지형표:
		if t[0] == n.name:
			점들 = t[1]
	if 점들.is_empty():
		push_error("빌더: 무늬 대상 %s 이 지형표에 없다" % n.name)
		오류 += 1
		return
	var 흰바탕: bool = false
	for t in 지형표:
		if t[0] == n.name:
			흰바탕 = int(t[2]) == 흰색
	var 줄 := _줄들(lo, hi)
	var 사각들: Array[Rect2] = []
	for i in 줄.size() - 1:
		var a := 줄[i]
		var b := 줄[i + 1]
		var mid := (a + b) * 0.5
		var x0 := _가까운_줄눈(왼 + 무늬_흔듦_왼[i % 5] * 흔듦, mid)
		var x1 := _가까운_줄눈(오른 - 무늬_흔듦_오른[i % 5] * 흔듦, mid)
		var r := Rect2(x0, a, x1 - x0, b - a)
		# 검사: 40 이상 폭 · 모든 꼭짓점·중심이 외곽 안이고 모든 변에서 24px 이상
		if r.size.x < 40.0:
			push_error("빌더: %s 무늬 %d 줄 폭 %.0f < 40" % [n.name, i, r.size.x]); 오류 += 1
		for p in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y), r.get_center()]:
			if not Geometry2D.is_point_in_polygon(p, 점들):
				push_error("빌더: %s 무늬 점 %s 이 외곽 밖" % [n.name, str(p)]); 오류 += 1
			for k in 점들.size():
				if _점_변_거리(p, 점들[k], 점들[(k + 1) % 점들.size()]) < 24.0:
					push_error("빌더: %s 무늬 점 %s 이 외곽에서 24px 안" % [n.name, str(p)]); 오류 += 1
					break
		사각들.append(r)
	if 사각들.size() > 16:
		push_error("빌더: %s 무늬 %d 줄 > 16" % [n.name, 사각들.size()]); 오류 += 1
		return
	# ★스크립트 교체 → SS2D 것까지 **모든 export 가 초기화**된다(처음엔 collision_polygon_node_path 가 비어
	#   콜리전이 사라져 A_바닥_흰을 밟은 몸이 바닥을 뚫고 떨어졌다). 프리팹·지형() 이 넣었던 값을 전부 다시 넣는다.
	var 유령: bool = bool(n.get("무색일때_통과"))
	var 점배열: Resource = n.get_point_array()
	var 콜리전경로: NodePath = n.get("collision_polygon_node_path")
	n.set_script(load(무늬_스크립트))
	n.set("collision_polygon_node_path", 콜리전경로)
	n.set("collision_update_mode", 2)
	n.set("texture_repeat", 2)
	n.set("texture_filter", 2)
	n.set_point_array(점배열)
	n.set("칠하기_허용", true)
	n.set("무색일때_통과", 유령)
	n.set("위치별_판정", true)
	n.set("collision_offset", 0.0)
	n.set("collision_size", 0.0)
	n.set("땅지형", true)
	n.set("옆면마감", true)
	n.set("시작상태", 무색)          # 0 = 초기 페인트 시드 없음. 바탕 접촉색은 전용 스크립트가 돌려준다.
	n.set("내부_바탕흰색", 흰바탕)
	var 로컬: Array[Rect2] = []
	var packed := PackedVector4Array()
	for r in 사각들:
		var lr := Rect2(r.position - n.position, r.size)
		로컬.append(lr)
		packed.append(Vector4(lr.position.x, lr.position.y, lr.end.x, lr.end.y))
	n.set("내부_벽돌영역", 로컬)
	# 에디터 미리보기 재질에도 같은 배열 — 노드 전용 복제(공유 재질을 건드리지 않는다).
	var 원본: Resource = 재질_흰 if 흰바탕 else 재질_검
	if 원본 != null:
		var 재질: Resource = 원본.duplicate()
		var 미리보기: ShaderMaterial = (원본.get("fill_mesh_material") as ShaderMaterial).duplicate()
		packed.resize(16)
		미리보기.set_shader_parameter("inlay_count", 사각들.size())
		미리보기.set_shader_parameter("inlay_rects", packed)
		재질.set("fill_mesh_material", 미리보기)
		n.set("shape_material", 재질)
	n.set_meta("color_inlays_v1", true)


## 칠해야 밟히는 유령 발판. 흰 구간이면 흰색 Template(에디터에서 구분되게).
func 유령(부모: Node, 이름: String, 점들: PackedVector2Array, 구간색: int, 필요횟수_수동: int = 0) -> Node2D:
	return 지형(부모, 이름, 점들, 구간색, "플랫폼", true, 필요횟수_수동)


## 공중 발판(일방통행). ★[2026-09-17] 사각형을 주면 **얇은 석조 선반**(공중선반 프리팹)으로 찍는다.
func 공중발판(부모: Node, 이름: String, 점들: PackedVector2Array, 색: int) -> Node2D:
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	return 공중선반(부모, 이름, 최소.x, 최소.y, 최대.x, 색)


## ★[2026-09-17] 얇은 석조 선반(ledge_v03 · 인계 §2 "두꺼운 벽을 잘라 띄운 느낌이 아닌 얇은 선반").
##   착지면 = (x0~x1, 윗면). 두께는 42~60 으로 밑면이 깨진 돌처럼 들쭉날쭉하다(프리팹 요철을 위상만 돌려 씀).
##   일방통행(두 칸 위 선반 밑면에 머리가 안 박히게). 벽에 붙는 쪽(`벽` = "L"/"R")은 모따기 없이 직각 —
##   벽 앞에 10px 홈이 파여 보이기 때문. 검산·색비율에는 (x0,윗면)~(x1,윗면+96) 사각형으로 올린다(변 ≥ 90 규칙용 명목 두께)
##   (요철 점은 16 격자·변 90 규칙의 대상이 아니다 — 통행 외곽이 아니라 장식 실루엣).
const _선반_요철 := [59.3, 42.4, 46.6, 52.0, 49.2, 53.2, 49.4, 43.8, 59.8, 58.8, 46.1]
var _선반_수 := 0

func 공중선반(부모: Node, 이름: String, x0: float, 윗면: float, x1: float, 색: int, 벽: String = "") -> Node2D:
	# 벽: "L"/"R"/"LR" — 벽에 붙는 쪽(지금은 윗면이 평평해서 모양은 같고, 굴뚝 사다리처럼 양벽에 끼우면 "LR")
	var 템플릿 := T_선반_흰 if 색 == 흰색 else T_선반_검
	var 씬 := load(템플릿) as PackedScene
	if 씬 == null:
		push_error("빌더: 공중선반 프리팹을 못 읽었다 — %s" % 템플릿)
		오류 += 1
		return null
	var n: Node2D = 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	n.name = 이름
	var 반폭 := (x1 - x0) * 0.5
	var 중심 := Vector2((x0 + x1) * 0.5, 윗면 + 48.0)
	n.position = 중심
	n.set("칠하기_허용", true)
	n.set("무색일때_통과", false)
	n.set("시작상태", 색)
	n.set("위치별_판정", true)
	n.set("collision_offset", 0.0)
	n.set("collision_size", 0.0)
	var 재질: Resource = 재질_선반_흰 if 색 == 흰색 else 재질_선반_검
	if 재질 != null:
		n.set("shape_material", 재질)

	# 윗면은 양끝까지 **평평**하게(프리팹의 10px 모따기를 안 쓴다) — 레벨검사가 표면 y 를 8px 간격으로 찍는데
	# 모따기 자리에서 10px 낮게 읽혀 "128 위 발판" 이 138 로 잡혀 도달 불가로 나왔다. 사다리꼴 끝마감은 셰이더가 그린다.
	var 위 := -48.0
	var 로컬 := PackedVector2Array()
	로컬.append(Vector2(-반폭, 위))
	로컬.append(Vector2(반폭, 위))
	로컬.append(Vector2(반폭, 위 + 12.0))
	var 칸 := 반폭 * 2.0 / 12.0
	for i in 11:
		var 깊이: float = _선반_요철[(i + _선반_수) % _선반_요철.size()]
		로컬.append(Vector2(snappedf(반폭 - 칸 * (i + 1), 0.01), 위 + 깊이))
	로컬.append(Vector2(-반폭, 위 + 12.0))
	_선반_수 += 1

	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(로컬)
	점배열.close_shape()
	n.set_point_array(점배열)

	var 폴리 := n.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		폴리.polygon = 로컬
		폴리.one_way_collision = true
		폴리.one_way_collision_margin = 4.0
		_덮어쓸_노드들.append(폴리)
	n.set_meta("terrain_style", "공중")
	n.set_meta("role", "플랫폼")
	부모.add_child(n)
	지형표.append([이름, 사각(x0, 윗면, x1, 윗면 + 96.0), 색, "플랫폼", false])
	return n


func _모양노드(인스턴스: Node2D) -> Node2D:
	if 인스턴스.has_method("get_point_array"):
		return 인스턴스
	for 자식 in 인스턴스.get_children():
		if 자식 is Node2D and 자식.has_method("get_point_array"):
			var 모양: Node2D = 자식
			인스턴스.remove_child(모양)
			모양.owner = null
			인스턴스.queue_free()
			return 모양
	push_error("빌더: Template 안에서 SS2D 지형 노드를 못 찾았다")
	오류 += 1
	return 인스턴스


## 프레임 바깥을 사방으로 `두께` 만큼 검정으로 감싼다(아스트라 2-10 방식 · 모서리 꼭짓점 공유).
## 카메라 리밋이 프레임이라 원래는 안 보이지만, 흔들림 offset 은 리밋 밖으로 나갈 수 있다.
func 외곽(부모: Node, 프레임: Rect2, 두께: float = 1024.0) -> void:
	var L := 프레임.position.x
	var T := 프레임.position.y
	var R := 프레임.end.x
	var B := 프레임.end.y
	지형(부모, "외곽_왼벽", 사각(L - 두께, T, L, B), 검정, "외곽")
	지형(부모, "외곽_오른벽", 사각(R, T, R + 두께, B), 검정, "외곽")
	지형(부모, "외곽_천장", 사각(L - 두께, T - 두께, R + 두께, T), 검정, "외곽")
	지형(부모, "외곽_바닥", 사각(L - 두께, B, R + 두께, B + 두께), 검정, "외곽")


# ============================================================================
# 부품
# ============================================================================
## 떨어지는 물줄기. 원점 = 물의 **윗끝 가운데**, 아래로 `높이` 만큼.
func 유체(부모: Node, 이름: String, x: float, 윗끝: float, 폭: float, 높이: float, 색: int,
		켜짐: bool = true) -> Node2D:
	var f := (load(S_유체) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	f.name = 이름
	f.position = Vector2(x, 윗끝)
	f.set("종류", 0)
	f.set("색", 색)
	f.set("크기", Vector2(폭, 높이))
	f.set("켜짐", 켜짐)
	부모.add_child(f)
	return f


## 바닥에 고인 물. 원점 = **아랫변 가운데**. 수면 = 아랫변 − 깊이.
func 웅덩이(부모: Node, 이름: String, x: float, 바닥: float, 폭: float, 깊이: float, 색: int,
		페인트_지움: bool = false) -> Node2D:
	var w := (load(S_웅덩이) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	w.name = 이름
	w.position = Vector2(x, 바닥)
	w.set("색", 색)
	w.set("크기", Vector2(폭, 깊이))
	w.set("낙하_받아줌", true)
	w.set("페인트_지움", 페인트_지움)
	부모.add_child(w)
	return w


## SS2D 배관(그림만 · 충돌 없음). 점 2개 이상, 월드 좌표.
func 배관(부모: Node, 이름: String, 점들: PackedVector2Array) -> Node2D:
	var 관 := (load(T_관) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	관.name = 이름
	관.position = Vector2.ZERO
	var 경로 := 관.get_node_or_null("경로") as Node2D
	if 경로 == null:
		push_error("빌더: 배관 Template 에 경로 노드가 없다 — %s" % 이름)
		오류 += 1
		return 관
	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(점들)
	경로.set_point_array(점배열)
	var 시작포트 := 관.get_node_or_null("시작_물_포트") as Node2D
	var 끝포트 := 관.get_node_or_null("끝_물_포트") as Node2D
	if 시작포트: 시작포트.position = 점들[0]
	if 끝포트: 끝포트.position = 점들[점들.size() - 1]
	부모.add_child(관)
	return 관


## 제어레버. 종류 0 = 원형(대상 유체 켜고 끔) · 1 = 직선(갈래 A/B 바꿈).
## 대상은 **레버 노드 기준 상대 경로**로 넣어야 하므로 노드를 받아서 계산한다.
func 레버(부모: Node, 이름: String, 위치: Vector2, 종류: int, 대상: Node, 갈래B: Node = null) -> Node2D:
	var l := (load(S_레버) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	l.name = 이름
	l.position = 위치
	l.set("종류", 종류)
	부모.add_child(l)
	if 종류 == 0:
		l.set("대상_유체", l.get_path_to(대상))
	else:
		l.set("갈래_A", l.get_path_to(대상))
		if 갈래B:
			l.set("갈래_B", l.get_path_to(갈래B))
	return l


## 호퍼(밟을 수 있는 집수 발판 · 색 규칙 밖). 원점 = 아랫변 가운데.
## 밟는 면(`윗면` 콜리전 12px)의 **윗변** = 원점 − 높이. 그래서 원점 = 밟는면 + 높이.
##   (처음엔 −높이+6 으로 잡아 실제 밟는 면이 6px 높았고, 그 6px 때문에 128 위 격자 밑면에 머리가 닿아 죽었다)
## ★[2026-09-17] `출구유체` 를 주면 호퍼가 그 물을 켜고 색을 물려준다(관을 따라서 = 2-3). `출구폭` = 출구 물줄기 폭(-1 = 유체 값).
func 호퍼(부모: Node, 이름: String, x: float, 밟는면: float, 폭: float, 높이: float = 56.0,
		출구유체: Node = null, 출구폭: float = -1.0) -> Node2D:
	var h := (load(S_호퍼) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	h.name = 이름
	h.position = Vector2(x, 밟는면 + 높이)
	h.set("폭", 폭)
	h.set("높이", 높이)
	h.set("자동_출구_연결", false)
	if 출구폭 >= 0.0:
		h.set("출구_물줄기_폭", 출구폭)
	# 밟는 면(`윗면`)을 일방통행으로 미리 만들어 둔다 — 호퍼.gd `_다시_만들기()` 가 재사용한다.
	# 허브 호퍼는 갱도 격자 바로 위에 걸치므로, 밑에서 뛰어오르는 몸이 통과해야 한다.
	var c := CollisionShape2D.new()
	c.name = "윗면"
	var r := RectangleShape2D.new()
	r.size = Vector2(폭, 12.0)
	c.shape = r
	c.position = Vector2(0, -높이 + 6.0)
	c.one_way_collision = true
	c.one_way_collision_margin = 4.0
	h.add_child(c)
	_덮어쓸_노드들.append(c)
	부모.add_child(h)
	# 부모에 넣은 뒤에야 상대 경로를 셀 수 있다.
	if 출구유체 != null:
		h.set("출구_유체", h.get_path_to(출구유체))
	return h


## ★[2026-09-17] 회전톱(타이밍 장애물). 원점 = 톱 중심(왕복 시작점). 프롬프트 B-3: 반지름 8~96 · 왕복 ≥ 2.0s ·
##   검정 구간이나 F2 빙 도는 길에만(톱 = 타이밍, 색칠 = 판단 — 한 자리에서 둘을 같이 요구하지 않는다).
func 회전톱(부모: Node, 이름: String, 위치: Vector2, 반지름: float, 이동거리: float, 왕복시간: float, 세로: bool = false) -> Node2D:
	var t := (load(S_회전톱) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	t.name = 이름
	t.position = 위치
	t.set("반지름", 반지름)
	t.set("이동거리", 이동거리)
	t.set("이동방향", 1 if 세로 else 0)
	t.set("왕복시간", maxf(왕복시간, 2.0))
	부모.add_child(t)
	return t


## 통과 플랫폼(하수구 격자). 원점 = 가운데. 물이 통과하고 페인트가 안 지워진다.
## 일방통행(기본): `충돌` 자식을 미리 만들어 두면 통과플랫폼.gd 의 `_다시_만들기()` 가 그 노드를 재사용한다
## (아스트라 2-10 과 같은 수법). 아래에서 뛰어오르면 통과하고 위에서만 밟힌다.
## 두께 20: 128 오름 지그재그에서 두 칸 위 격자 밑면과 머리(96) 사이가 108 남는다(접촉_여유 3 보다 넉넉히).
func 통과플랫폼(부모: Node, 이름: String, x: float, 윗면: float, 폭: float, 필요횟수: int = 1,
		두께: float = 20.0, 일방통행: bool = true) -> Node2D:
	var g := (load(S_통과플랫폼) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	g.name = 이름
	g.position = Vector2(x, 윗면 + 두께 * 0.5)
	g.set("크기", Vector2(폭, 두께))
	g.set("필요횟수", 필요횟수)
	if 일방통행:
		var c := CollisionShape2D.new()
		c.name = "충돌"
		var r := RectangleShape2D.new()
		r.size = Vector2(폭, 두께)
		c.shape = r
		c.one_way_collision = true
		c.one_way_collision_margin = 4.0
		g.add_child(c)
		_덮어쓸_노드들.append(c)
	부모.add_child(g)
	return g


## 가시. 원점 = 띠 가운데(높이의 절반이 바닥 위로 솟는다). 방향 0 = 위.
func 가시(부모: Node, 이름: String, x: float, 바닥: float, 칸수: int, 방향: int = 0, 높이: float = 22.0) -> Node2D:
	var s := (load(S_가시) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	s.name = 이름
	s.position = Vector2(x, 바닥 - 높이 * 0.5 + 4.0)
	s.set("칸수", 칸수)
	s.set("방향", 방향)
	s.set("가시높이", 높이)
	부모.add_child(s)
	return s


func 체크포인트(부모: Node, 이름: String, 위치: Vector2) -> Node2D:
	var c := (load(S_체크포인트) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	c.name = 이름
	c.position = 위치
	부모.add_child(c)
	return c


# ============================================================================
# 검산 — 겹침 0 · 구멍 0 · 격자 16 · 변 ≥ 90 · 시계 방향
# ============================================================================
## 프레임(카메라 리밋) 안을 16px 칸으로 나눠 칸마다 "지형 몇 개가 덮나" 를 센다.
##   2 개 이상 → 겹침. 0 개인데 어느 빈공간 사각형에도 안 들어가면 → 구멍(배경이 비친다).
## 빈공간 = 방·구덩이·틈·통로처럼 **일부러 비운 자리**. 여기 안에 떠 있는 발판은 1 개라 통과.
func 검산(프레임: Rect2, 빈공간들: Array) -> bool:
	var 문제 := 0
	# ── 1. 점 단위 규칙 ──
	for t in 지형표:
		var 이름: String = t[0]
		var 점들: PackedVector2Array = t[1]
		var n := 점들.size()
		var 면적2 := 0.0
		for i in n:
			var a := 점들[i]
			var b := 점들[(i + 1) % n]
			if fmod(a.x, 격자) != 0.0 or fmod(a.y, 격자) != 0.0:
				print("  ✖ %s: 꼭짓점 (%.0f,%.0f) 이 16 격자 밖" % [이름, a.x, a.y]); 문제 += 1
			var 길이 := a.distance_to(b)
			if 길이 < 최소변:
				print("  ✖ %s: 변 (%.0f,%.0f)→(%.0f,%.0f) 길이 %.0f < %.0f" % [이름, a.x, a.y, b.x, b.y, 길이, 최소변]); 문제 += 1
			면적2 += a.x * b.y - b.x * a.y
		# y 가 아래로 커지는 화면 좌표계에서 "왼위→오른위→오른아래" 는 신발끈 합이 **양수**다.
		if 면적2 <= 0.0:
			print("  ✖ %s: 시계 방향이 아니다(신발끈 %.0f)" % [이름, 면적2]); 문제 += 1

	# ── 2. 래스터 겹침·구멍 ──
	var 칸x := int(프레임.size.x / 격자)
	var 칸y := int(프레임.size.y / 격자)
	var 덮음 := PackedByteArray()
	덮음.resize(칸x * 칸y)
	덮음.fill(0)
	_칸색 = PackedInt32Array()
	_칸색.resize(칸x * 칸y)
	_칸색.fill(-1)
	_칸x = 칸x
	_칸y = 칸y
	var 겹침_보고 := {}
	for t in 지형표:
		var 점들: PackedVector2Array = t[1]
		var 최소 := 점들[0]
		var 최대 := 점들[0]
		for p in 점들:
			최소 = 최소.min(p)
			최대 = 최대.max(p)
		var ix0 := maxi(int(floor((최소.x - 프레임.position.x) / 격자)), 0)
		var iy0 := maxi(int(floor((최소.y - 프레임.position.y) / 격자)), 0)
		var ix1 := mini(int(ceil((최대.x - 프레임.position.x) / 격자)), 칸x - 1)
		var iy1 := mini(int(ceil((최대.y - 프레임.position.y) / 격자)), 칸y - 1)
		for iy in range(iy0, iy1 + 1):
			for ix in range(ix0, ix1 + 1):
				var c := 프레임.position + Vector2((ix + 0.5) * 격자, (iy + 0.5) * 격자)
				# ★[2026-09-17] Geometry2D.is_point_in_polygon 이 (1288,1288) 같은 자리에서 사각형 안인데 false 를 준다
				#   (2-4 F_T1위 에서 실제로 났다 · 레이가 꼭짓점을 스치는 경우로 보임). 살짝 비낀 점도 같이 본다.
				if Geometry2D.is_point_in_polygon(c, 점들) or Geometry2D.is_point_in_polygon(c + Vector2(0.37, 0.29), 점들):
					var k := iy * 칸x + ix
					덮음[k] += 1
					_칸색[k] = int(t[2])
					if 덮음[k] >= 2:
						var key := "%s@(%.0f,%.0f)" % [t[0], c.x, c.y]
						if 겹침_보고.size() < 12:
							겹침_보고[key] = true
	for key in 겹침_보고.keys():
		print("  ✖ 겹침: %s" % key); 문제 += 1
	var 구멍 := 0
	var 구멍_예 := []
	for iy in 칸y:
		for ix in 칸x:
			if 덮음[iy * 칸x + ix] != 0:
				continue
			var c := 프레임.position + Vector2((ix + 0.5) * 격자, (iy + 0.5) * 격자)
			var 빈 := false
			for r in 빈공간들:
				if (r as Rect2).has_point(c):
					빈 = true
					break
			if not 빈:
				구멍 += 1
				if 구멍_예.size() < 8:
					구멍_예.append("(%.0f,%.0f)" % [c.x, c.y])
	if 구멍 > 0:
		print("  ✖ 구멍(지형도 빈공간도 아닌 칸) %d 개 — 예: %s" % [구멍, ", ".join(구멍_예)]); 문제 += 1
	if 문제 == 0:
		print("  ✔ 검산 통과 — 지형 %d · 겹침 0 · 구멍 0 · 격자 16 · 변 ≥ 90 · 시계 방향" % 지형표.size())
	오류 += 문제
	return 문제 == 0


## 색 비율 — **보이는 면**으로 잰다. 검산 래스터에서 "지형 칸인데 이웃 하나가 빈칸" 인 칸을
## 색별로 센다 = 플레이어 눈에 들어오는 바닥·벽·천장·발판 테두리 길이.
##   면적으로 재면 바닥 덩어리(프레임 바닥까지)가 전부 검정이라 늘 80 % 가 넘고,
##   "화면이 검정 기준에 흰색이 사이사이" 라는 도형님 지시(가이드라인 §7-1)와 어긋난다.
## 가이드라인 §7-1: 검정 65 % ± 5. 벗어나면 false.
func 색비율_보고() -> bool:
	if _칸색.is_empty():
		print("  ⚠ 검산을 먼저 돌려야 색 비율을 잴 수 있다"); return false
	var 검 := 0
	var 흰 := 0
	for iy in _칸y:
		for ix in _칸x:
			var c := _칸색[iy * _칸x + ix]
			if c < 0:
				continue
			var 노출 := false
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var jx: int = ix + d[0]
				var jy: int = iy + d[1]
				if jx < 0 or jy < 0 or jx >= _칸x or jy >= _칸y:
					continue
				if _칸색[jy * _칸x + jx] < 0:
					노출 = true
					break
			if not 노출:
				continue
			if c == 흰색:
				흰 += 1
			else:
				검 += 1
	var 합 := 검 + 흰
	if 합 <= 0:
		print("  ⚠ 보이는 지형 면이 없다"); return false
	var 검비 := float(검) / float(합) * 100.0
	print("  색 비율(보이는 면 길이) — 검정 %.0f%% · 흰색 %.0f%%  (기준 65 ± 5 · 검정 %.0fm · 흰색 %.0fm)"
		% [검비, 100.0 - 검비, 검 * 격자 / 100.0, 흰 * 격자 / 100.0])
	return 검비 >= 60.0 and 검비 <= 70.0


static func _면적(점들: PackedVector2Array) -> float:
	var a := 0.0
	for i in 점들.size():
		var p := 점들[i]
		var q := 점들[(i + 1) % 점들.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


# ============================================================================
# 저장
# ============================================================================
## 새로 만든 노드에만 owner 를 준다. 인스턴스 씬(Player·유체…)은 루트 한 노드만.
## (CLAUDE.md §6 — 인스턴스 내부까지 박으면 다음 로드 때 노드가 두 벌이 된다)
func 저장(루트: Node, 경로: String) -> bool:
	_주인(루트, 루트)
	for n in _덮어쓸_노드들:
		# ★[2026-09-17] 프리팹이 원래 갖고 있던 노드(공중선반의 CollisionPolygon2D)는 owner 를 뺏지 않고
		#   그 인스턴스를 **편집 가능(editable children)** 으로 표시한다 → `[editable path=]` 로 저장되어
		#   에디터가 다시 저장해도 일방통행 덮어쓰기가 남는다. (2-2 HEAD 에서 owner 만 준 덮어쓰기가 통째로
		#   사라져 탑 발판 일방통행이 없어졌던 사고 · 작업기록 2026-09-17 §3-1)
		#   우리가 새로 만든 노드(통과플랫폼 `충돌` · 호퍼 `윗면`)는 owner 가 비어 있으니 _주인 이 이미 루트를 줬다.
		if n.owner != null and n.owner != 루트 and 루트.is_ancestor_of(n.owner):
			루트.set_editable_instance(n.owner, true)
		elif n.owner == null:
			n.owner = 루트
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("pack 실패: %s" % error_string(e))
		return false
	# ★[2026-09-17] 에디터가 같은 프로젝트를 열어 두고 있으면 방금 바뀐 씬을 다시 읽느라 파일을 잠깐 잠근다 →
	#   "Cannot save file" 이 간헐적으로 났다(2-3 굽기에서 세 번 중 두 번). 잠깐 쉬고 다시 시도한다.
	for 시도 in 6:
		e = ResourceSaver.save(팩, 경로)
		if e == OK:
			break
		OS.delay_msec(500)
	print("   %-24s %s" % [경로.get_file(), error_string(e)])
	return e == OK


## ★[2026-09-14] 인스턴스 **안에 새로 넣은** 노드(발판 밑 지지대, 승강기 자식 고정구)도 저장돼야 한다.
##   인스턴스가 원래 갖고 있던 내부 노드는 owner 가 인스턴스 루트라 건너뛰고(두 벌 방지),
##   owner 가 비어 있는 것 = 우리가 새로 만든 것만 씬 루트를 준다. 그래서 인스턴스 안으로도 내려간다.
func _주인(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		if 자식.owner == null:
			자식.owner = 루트
		_주인(자식, 루트)
