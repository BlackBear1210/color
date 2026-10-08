@tool
extends Area2D
## ============================================================================
## [2026-08-06 신규] 연결통로 — 스테이지와 스테이지를 잇는 "걸어 들어가는 공간"
## ----------------------------------------------------------------------------
## ▣ 포탈을 없앤 이유 (도형님 요청: "난 이게임에 포탈로 이동하는게 싫어")
##   포탈은 "여기서 저기로 순간이동한다"는 게임 규칙을 드러낸다.
##   우리 게임 톤(LIMBO / 리틀 나이트메어 / 레인월드 계열)에서는
##   **공간이 물리적으로 이어져 있어야** 한다. 그래서 스테이지 끝을
##   지형에 파인 **가로 터널**로 만들었다. 플레이어는 문을 여는 게 아니라
##   그냥 걸어 들어가고, 터널 안이 어두우니 화면이 자연스럽게 까매진다.
##
## ▣ 한 스크립트가 출구와 입구를 둘 다 한다
##   출구(스테이지 끝, 오른쪽으로 파고듦)  : 안쪽 깊이 들어가면 다음 씬으로
##   입구(스테이지 시작, 왼쪽에서 뻗어옴)  : 판정 없음. 여기서 걸어 나오며 화면이 밝아진다
##   같은 스크립트라 **입구와 출구의 그림이 완전히 똑같다.** 그래야 통로를 지난 뒤
##   "방금 그 통로에서 나왔다"고 읽힌다 (VINE 의 이어지는 배경과 같은 원리).
##
## ▣ 스스로 통로를 짓는다 (지형 빌더에 의존하지 않는다)
##   바닥 / 천장 / 막다른 뒷벽을 이 노드가 StaticBody2D 로 직접 만든다.
##   → 지형 폴리곤을 정교하게 파낼 필요 없이 지면 끝에 툭 놓기만 하면 통로가 완성된다.
##   → 천장이 있어서 플레이어가 통로를 **뛰어넘어 갈 수 없다** = 반드시 통로를 지난다.
##
## ▣ 배치 규약
##   · 원점 = 통로 **바닥 중앙**. 지면 높이에 그대로 놓으면 된다.
##   · 출구는 +x 방향(오른쪽)으로 파고들고, 입구는 −x 방향(왼쪽)에서 뻗어온다.
##   · `속빛` = **이어지는 쪽 스테이지의 하늘색**. 통로 저 끝에서 그 색 빛이 새어나오므로
##     지나가기 전에 이미 다음 지역의 분위기가 보인다.
## ============================================================================
class_name 연결통로

## ⚠ class_name 대신 **경로 preload** 로 잡는다 — 새 스크립트의 전역 클래스 이름은
##   에디터가 한 번 훑어야 등록돼서, 그 전에 헤드리스 검사를 돌리면 통째로 죽는다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")

enum 역할_ { 출구, 입구 }

@export var 역할: 역할_ = 역할_.출구:
	set(v): 역할 = v; _재구성()

## 통로 안쪽 높이(px). 플레이어 키가 약 47px 이라 100 이하로는 내리지 말 것.
@export_range(80, 400) var 높이: float = 150.0:
	set(v): 높이 = v; _재구성()

## 통로가 지형 속으로 파고드는 깊이(px). 이 거리를 걷는 동안 화면이 어두워진다.
## 암전시간(0.85초) × 이동속도(390px/s) ≈ 330px 이므로 그보다 넉넉하게 잡는다.
@export_range(160, 1200) var 깊이: float = 420.0:
	set(v): 깊이 = v; _재구성()

## 벽·바닥·천장의 두께(px). 두꺼울수록 "덩어리에서 파낸 굴"로 보인다.
@export_range(24, 200) var 두께: float = 90.0:
	set(v): 두께 = v; _재구성()

## ★[2026-09-28] 통로가 파고드는 쪽을 뒤집는다. **기본값 false 는 지금까지와 완전히 같다.**
## 왜 필요한가: 탐색방은 문이 **왼쪽 벽에도** 생긴다(출구를 시드로 고르기 때문).
## 기존 규약(출구는 +x · 입구는 −x)만으로는 왼쪽 벽 출구·오른쪽 벽 입구를 만들 수 없었다
## (작업지시 2026-09-27 §1 의 원인 4).
@export var 반대방향: bool = false:
	set(v): 반대방향 = v; _재구성()

@export_group("연결")
## 출구 전용 — 걸어 들어가면 넘어갈 다음 스테이지 씬.
@export_file("*.tscn") var 다음_씬: String = ""
## 다음 씬에서 걸어 나올 입구 통로 노드의 이름. 비우면 그 씬의 기본 시작 위치.
@export var 다음_진입점: String = "입구통로"

@export_group("연출")
## 통로 저 끝에서 새어나오는 빛 = **이어지는 지역의 하늘색**.
@export var 속빛: Color = Color(0.31, 0.32, 0.34):
	set(v): 속빛 = v; _속빛_갱신(); queue_redraw()
## 통로 안쪽 어둠의 진하기. 1.0 = 완전한 검정.
@export_range(0.0, 1.0) var 어둠: float = 0.94

## ★통로를 감싼 암반을 위/아래로 얼마나 더 그릴지(px). **그림만** 커진다(콜리전은 그대로).
## [2026-08-06] 스크린샷을 보니 통로가 지면 위에 얹힌 **콘크리트 상자**처럼 보였다.
## 두께(90px)만큼만 그리면 "굴을 판 것" 이 아니라 "구조물을 세운 것" 으로 읽힌다.
## 위로 넉넉히 늘려 천장 매스와 이어 붙이고, 아래로도 늘려 바닥 지형에 파묻으면
## 비로소 **덩어리에서 파낸 구멍**으로 보인다.
@export_range(0, 1200) var 암반_위: float = 340.0
@export_range(0, 1200) var 암반_아래: float = 420.0

## ★[2026-10-08 Claude] 쳅터1 연결구 방식으로 넘어간다(도형님 "쳅터2 도 쳅터1 스테이지 전환 방식으로 전부").
##   켬 = 걸어 들어가며 줌인 → 짧은 암전 → 다음 스테이지 **입구 통로 안에서 걸어 나오며** 천천히 줌아웃(`전경전환.gd`).
##   끔 = 옛 방식(`장면전환` 의 1.4초 암전 · 통로 밖 스폰).
##   하수도 씬 파일은 한 줄도 안 고쳤다 — 기본값이 켬이라 모든 하수도 통로가 새 방식을 탄다.
@export_group("쳅터1 방식 전환")
@export var 쳅터1_전환: bool = true
## 쳅터1 연결구와 같은 **가까운 전경 띠**(타일보다 앞 z 60) — 통로 입구 쪽은 옅고 안쪽으로 갈수록 진하다.
@export var 전경띠: bool = true:
	set(v): 전경띠 = v; _재구성()
## [2026-10-08 밤] 도형님 "전경 그라데이션을 더 어둡게 해서 안쪽 지형이 보이지 않게" → 0.85 → 1.0 · 입구에서 이미 0.8.
@export_range(0.0, 1.0) var 전경_진하기: float = 1.0:
	set(v): 전경_진하기 = v; _재구성()
## 출구 통로 앞에서 길을 알려 주는 반딧불이(쳅터1 `반딧불이.gd` 그대로).
@export var 반딧불이: bool = true:
	set(v): 반딧불이 = v; _재구성()
## 통로 둘레의 직사각형 구멍을 이웃 벽 지형으로 메워 쳅터1 처럼 얇은 벽만 보이게(아래 `_얇은벽_만들기`).
@export var 통로_구멍_메움: bool = true
## [2026-10-08] 벽 뚫기 — 통로 자리에 이미 벽 지형이 있으면(입구 통로가 없던 2-9·2-11 에 새로 넣은 입구)
##   실행 때 그 벽 지형에서 **통로 길만큼만 잘라 낸다**(Geometry2D.clip_polygons). 씬의 지형은 그대로 두고 실행 때만 판다.
@export var 벽_뚫기: bool = false

const 전경전환_스크립트 := preload("res://scripts/쳅터1/전경전환.gd")
const 반딧불이_스크립트 := preload("res://scripts/쳅터1/반딧불이.gd")
const 전경색 := Color(0.03, 0.028, 0.026, 1.0)   ## 쳅터1 연결구 전경색과 같은 값
const 전경_번짐 := 160.0                         ## 통로 입구에서 방 안쪽으로 번지는 폭(px) — 짙어진 만큼 넓게 번져야 경계가 안 생긴다

var _t: float = 0.0
var _띠: Node2D = null
var _빛: Node2D = null
var _광원: PointLight2D = null
var _발동함: bool = false          ## 한 번만 넘어가게 (프레임마다 여러 번 겹칠 수 있다)
## ★[2026-10-08] 되돌아가기(쳅터1 연결구와 같은 왕복) — 도형님 "반대로 갔을 때 돌아갈 수 있어야 한다.
##   쳅터1 15 에서 하수도 2-1 로 넘어갔다가 다시 돌아가는 게 안 된다."
##   입구 통로는 씬에 "어디서 왔는지"가 없다(하수도 씬 무수정) → 전환이 도착할 때 **떠나온 씬·길목 이름**을 적어 준다.
var _되돌아갈_씬: String = ""
var _되돌아갈_진입점: String = ""
var _무시중: bool = false          ## 방금 이 통로로 도착 — 몸이 판정 밖으로 나갈 때까지 무시(왕복 튕김 방지)
var _얇은벽: Node2D = null         ## 실행 때 만든 통로 구멍 메움 지형(없으면 null)
var _메움_위: bool = false
var _메움_아래: bool = false
var 얇은벽_정보: Dictionary = {}    ## 시험·진단용: 잰 구멍 크기와 복제한 지형 이름
## 화면이 통로 쪽으로 넘지 않을 선 = 입구에서 굴 쪽으로 이만큼(px). 쳅터1 연결구 벽 두께(160)와 같다.
const 화면_끝_여유 := 160.0


## 출구는 +1(오른쪽), 입구는 −1(왼쪽). 통로 몸통이 뻗어나가는 방향.
func 방향() -> float:
	var d := 1.0 if 역할 == 역할_.출구 else -1.0
	return -d if 반대방향 else d


func _ready() -> void:
	_재구성()
	if Engine.is_editor_hint():
		return
	add_to_group("연결통로")
	# 판정은 출구만. 입구는 순수한 배경 겸 스폰 지점이다.
	# [2026-10-08] 쳅터1 방식이면 입구도 판정한다 — 되돌아갈 곳이 적힌 때만 넘어간다(`열림()`).
	monitoring = 역할 == 역할_.출구 or 쳅터1_전환
	collision_layer = 0        # 아무도 이걸 감지할 필요 없다
	collision_mask = 1         # 플레이어(레이어 1)만 본다
	if (역할 == 역할_.출구 or 쳅터1_전환) and not body_entered.is_connected(_몸_들어옴):
		body_entered.connect(_몸_들어옴)
	if 쳅터1_전환:
		if not body_exited.is_connected(_몸_나감):
			body_exited.connect(_몸_나감)
		# 카메라는 스테이지 루트(월드)가 _ready 끝에 만든다 → 한 박자 뒤에 등록.
		_카메라_가림_등록.call_deferred()
		# 벽 뚫기는 **플레이어가 통로 안에 놓이기 전**에 끝나야 한다(늦으면 벽 속에 끼어 죽는다 — 2-11 에서 겪음).
		#   물리 질의 대신 지형 점 배열을 직접 비교하므로 콜리전이 공간에 올라오기를 기다리지 않는다.
		if 벽_뚫기:
			_벽_뚫기.call_deferred()
		_얇은벽_만들기.call_deferred()
	set_process(true)


## 입구 통로에서 플레이어가 걸어 나올 때의 시작 위치(월드 좌표).
## 통로 **가장 깊은 안쪽**에 세워야 "걸어 나오는" 그림이 된다.
func 걸어나올_위치() -> Vector2:
	return global_position + Vector2(방향() * 깊이 * 0.62, 0.0)


# ── 전경전환(쳅터1 연결구) 계약 ── `scripts/쳅터1/전경전환.gd` 가 도착 길목에 묻는 세 가지.
## 다른 스테이지에서 이 통로로 들어올 때 서는 자리 = 통로 안쪽(카메라 줌인된 채 어둠 속).
func 도착_위치() -> Vector2:
	return 걸어나올_위치()


## 걸어 나와 조작을 돌려받는 자리 = 통로 입구에서 방 안쪽 2칸. 자동 안전점도 여기.
func 안쪽_위치() -> Vector2:
	return global_position + Vector2(-방향() * 64.0, 0.0)


## 이 통로로 도착했다 — 플레이어가 판정 밖으로 걸어 나갈 때까지 넘어가지 않는다.
##   (보관했다 되살린 스테이지면 떠날 때 켜 둔 `_발동함` 도 여기서 푼다)
func 도착시킴() -> void:
	_무시중 = true
	_발동함 = false


## 지금 이 통로로 넘어갈 수 있나. 출구 = 다음_씬 이 있으면 · 입구 = 되돌아갈 곳이 적혀 있으면.
func 열림() -> bool:
	if 역할 == 역할_.출구:
		return not 다음_씬.is_empty()
	return not _되돌아갈_씬.is_empty()


## 입구 통로가 "뒤로 가는 길" 인가 — 지도 모드 클리어 가로채기를 하지 않는다.
func 되돌아가는_길인가() -> bool:
	return 역할 == 역할_.입구


## 전환이 묻는 목적지(출구 = 다음_씬 · 입구 = 떠나온 씬).
func 전환_씬() -> String:
	return 다음_씬 if 역할 == 역할_.출구 else _되돌아갈_씬


func 전환_진입점() -> String:
	return 다음_진입점 if 역할 == 역할_.출구 else _되돌아갈_진입점


## 전경전환이 도착 직후 부른다. 입구만 받아 적는다(출구는 씬에 적힌 다음_씬 이 있다).
func 되돌아갈_곳(씬: String, 진입점: String) -> void:
	if 역할 != 역할_.입구:
		return
	_되돌아갈_씬 = 씬
	_되돌아갈_진입점 = 진입점
	_전경_갱신()


func _몸_나감(몸: Node2D) -> void:
	if 몸.is_in_group("player"):
		_무시중 = false


## [2026-10-08] 이 통로 높이 근처에서는 화면이 굴 속을 비추지 않게 카메라에 알린다(`ProtoCamera.통로_가림_추가`).
func _카메라_가림_등록() -> void:
	var n := get_parent()
	while n != null and n.get_node_or_null("카메라") == null:
		n = n.get_parent()
	var 캠 := n.get_node_or_null("카메라") if n else null
	if 캠 and 캠.has_method("통로_가림_추가"):
		var d := 방향()
		캠.call("통로_가림_추가", global_position.x + d * 화면_끝_여유, d, global_position.y - 높이, global_position.y)


# ── 통로 짓기 ───────────────────────────────────────────────────────────────
## 바닥·천장·뒷벽(StaticBody2D) + 판정(CollisionShape2D)을 만들거나 갱신한다.
## 값이 바뀔 때마다 다시 부르므로 **있으면 재사용, 없으면 생성** 구조로 짰다.
func _재구성() -> void:
	if not is_inside_tree():
		return
	var d := 방향()
	var 중심x := d * 깊이 * 0.5

	# ── 판정 영역 ── 통로 안쪽 60% 지점부터. 입구를 스치기만 해도 넘어가면 안 된다.
	var cs := _가져오기("판정", CollisionShape2D) as CollisionShape2D
	var sh := cs.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		cs.shape = sh
	sh.size = Vector2(깊이 * 0.34, 높이 * 0.9)
	cs.position = Vector2(d * 깊이 * 0.66, -높이 * 0.5)

	# ── 통로 몸통 ── 바닥 / 천장 / 막다른 뒷벽
	# 바닥은 통로 입구보다 살짝 앞으로 내밀어(+d*24) 지면과 이가 맞게 한다.
	_벽("바닥", Vector2(중심x + d * 12.0, 두께 * 0.5), Vector2(깊이 + 48.0, 두께))
	_벽("천장", Vector2(중심x + d * 12.0, -높이 - 두께 * 0.5), Vector2(깊이 + 48.0, 두께))
	# 뒷벽 — 출구는 여기 닿기 전에 씬이 바뀌고, 입구는 여기 앞에서 스폰된다.
	_벽("뒷벽", Vector2(d * (깊이 + 두께 * 0.5), -높이 * 0.5), Vector2(두께, 높이 + 두께 * 2.0))

	# ── 속빛 광원 ──
	if _광원 == null:
		_광원 = _가져오기("속빛광원", PointLight2D) as PointLight2D
		if _광원.texture == null:
			_광원.texture = _빛_텍스처()
	_광원.position = Vector2(d * 깊이 * 0.78, -높이 * 0.5)
	_광원.texture_scale = 높이 * 3.4 / 256.0
	# ★[2026-09-05] 프로젝트 조명 표준(height 128 · ADD). 예전에는 height 를 안 줘서
	#   기본값 0 이었고, 그래서 지형 노멀맵이 이 빛에 전혀 반응하지 않았다.
	조명표준.적용(_광원, 0.85)
	_속빛_갱신()
	_전경_갱신()
	queue_redraw()


## [2026-10-08] 쳅터1 연결구의 가까운 전경 띠 + 반딧불이. ⚠ owner 를 주지 않는다 —
##   에디터에서 미리 보이되 **하수도 씬 파일에 저장되지 않게**(씬 무수정 원칙).
func _전경_갱신() -> void:
	if 전경띠:
		if _띠 == null:
			_띠 = Node2D.new()
			_띠.name = "전경띠"
			_띠.z_as_relative = false
			_띠.z_index = 60                     # 타일·플레이어보다 앞(쳅터1 연결구와 같은 층)
			_띠.draw.connect(_띠_그리기)
			add_child(_띠)
		_띠.queue_redraw()
	elif _띠:
		_띠.queue_free()
		_띠 = null
	var 길잡이 := 반딧불이 and 열림()
	if 길잡이:
		if _빛 == null:
			_빛 = Node2D.new()
			_빛.set_script(반딧불이_스크립트)
			_빛.name = "반딧불이"
			add_child(_빛)
		var d := 방향()
		_빛.position = Vector2(-d * 150.0, -높이 * 0.7)
		_빛.z_index = 2
		_빛.set("범위", Vector2(150, maxf(90.0, 높이 * 0.6)))
		_빛.set("씨앗", int(abs(global_position.x + global_position.y)) % 997 + 1)
	elif _빛:
		_빛.queue_free()
		_빛 = null


## 연결구 `_draw` 와 같은 모양: 가로 = 방 안쪽 번짐 → 입구 → 통로 깊은 곳으로 갈수록 진해짐,
## 세로 = 구멍 높이까지는 그대로, 그 위로는 옅어지며 사라진다(각진 상자 금지).
func _띠_그리기() -> void:
	var d := 방향()
	var 위 := -높이 * 1.9
	var 허리 := -높이
	var 아래 := 두께
	# 방 안쪽 번짐 → 입구(이미 0.8) → 입구에서 1/4 지점부터 완전한 어둠 → 굴 끝.
	var xs := [-d * 전경_번짐, 0.0, d * 깊이 * 0.25, d * (깊이 + 두께)]
	var 알파 := [0.0, 전경_진하기 * 0.8, 전경_진하기, 1.0]
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		var ca := Color(전경색.r, 전경색.g, 전경색.b, 알파[i])
		var cb := Color(전경색.r, 전경색.g, 전경색.b, 알파[i + 1])
		var 투명 := Color(전경색.r, 전경색.g, 전경색.b, 0.0)
		_띠.draw_polygon(PackedVector2Array([Vector2(xa, 허리), Vector2(xb, 허리), Vector2(xb, 아래), Vector2(xa, 아래)]),
			PackedColorArray([ca, cb, cb, ca]))
		_띠.draw_polygon(PackedVector2Array([Vector2(xa, 위), Vector2(xb, 위), Vector2(xb, 허리), Vector2(xa, 허리)]),
			PackedColorArray([투명, 투명, cb, ca]))


## 이름으로 자식을 찾고, 없으면 만들어서 붙인다.
## (에디터에서 값만 바꿔도 노드가 계속 늘어나는 사고를 막는다)
func _가져오기(이름: String, 형: Variant) -> Node:
	var n := get_node_or_null(NodePath(이름))
	if n == null:
		n = 형.new()
		n.name = 이름
		add_child(n)
		# 에디터에서 만든 노드는 owner 를 줘야 씬에 저장된다
		if Engine.is_editor_hint() and owner:
			n.owner = owner
	return n


## 사각형 벽 하나(StaticBody2D + CollisionShape2D). 그림은 _draw 가 따로 그린다.
func _벽(이름: String, 위치: Vector2, 크기: Vector2) -> void:
	var 바디 := _가져오기(이름, StaticBody2D) as StaticBody2D
	바디.position = 위치
	바디.collision_layer = 1      # 플레이어가 밟는 일반 지형과 같은 레이어
	바디.collision_mask = 0
	var cs := 바디.get_node_or_null("모양") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "모양"
		# ★오목 폴리곤 기즈모가 에디터 2D 뷰를 뒤덮는 문제(2026-08-02)와 같은 이유로 숨긴다.
		#   visible 은 디버그 그리기만 끄는 것이라 물리 판정에는 영향이 없다.
		cs.visible = false
		바디.add_child(cs)
		if Engine.is_editor_hint() and owner:
			cs.owner = owner
	var r := cs.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		cs.shape = r
	r.size = 크기


func _속빛_갱신() -> void:
	if _광원:
		# 하늘색을 그대로 쓰면 너무 어둡다. 밝기를 끌어올려 "새어나오는 빛"으로 만든다.
		_광원.color = 속빛.lightened(0.55)


## 가운데가 밝고 가장자리가 0 으로 떨어지는 원형 그라데이션.
## 여러 통로가 공유해도 되지만 통로 수가 적어 그냥 매번 만든다.
func _빛_텍스처() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t


# ── 판정 ────────────────────────────────────────────────────────────────────
func _몸_들어옴(몸: Node2D) -> void:
	if _발동함 or Engine.is_editor_hint():
		return
	if not (몸 is CharacterBody2D):
		return
	if 쳅터1_전환:
		# 사망 모션으로 멈춘 본체가 통로에 걸쳐 있어도 넘어가지 않는다(연결구와 같은 규칙).
		if _무시중 or not 열림() or not 몸.is_in_group("player") or not 몸.is_physics_processing():
			return
		if 전경전환_스크립트.진행중인가():
			return
		전경전환_스크립트.연결로_이동(self, 몸 as CharacterBody2D)
		_발동함 = 전경전환_스크립트.진행중인가()
		return
	if 다음_씬.is_empty():
		push_warning("연결통로(%s): 다음_씬 이 비어 있다" % name)
		return
	_발동함 = true
	# 씬 경로는 지금 씬을 기억해 둔다 — 나중에 되돌아가기를 붙일 때 쓴다.
	var 지금 := ""
	var 현재씬 := get_tree().current_scene
	if 현재씬:
		지금 = 현재씬.scene_file_path
	장면전환.통로로_이동(self, 다음_씬, 다음_진입점, 지금)


# ── 그림 ────────────────────────────────────────────────────────────────────
var _에디터_서명 := 0

func _process(delta: float) -> void:
	# ★[2026-09-30] 에디터에서는 맥동하지 않는다 — 매 프레임 다시 그리면 에디터가 쉬지 못해
	#   (모든 하수도 씬에 통로가 있다) F5 로 켠 게임과 GPU 를 나눠 써 프레임이 떨어졌다. 값이 바뀐 때만 그린다.
	if Engine.is_editor_hint():
		var 서명 := preload("res://scripts/스마트월드/에디터_다시그리기.gd").서명(self)
		if 서명 != _에디터_서명:
			_에디터_서명 = 서명
			queue_redraw()
		return
	# 속빛이 아주 느리게 맥동한다. 정지된 그림은 "벽에 그린 그림"으로 보인다.
	_t += delta
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var d := 방향()
	var h := 높이
	var L := 깊이
	var t := 두께

	# ── 0) 통로를 감싼 암반 ────────────────────────────────────────────────
	# ★[2026-08-06 · 스크린샷 보고 고침] 처음엔 바닥/천장/뒷벽을 콜리전만 만들고
	#   그림을 안 그렸다. 그랬더니 화면에서 통로가 **허공에 뜬 검은 상자**로 보였다
	#   ("지형에 파인 굴" 이라는 게 전혀 안 읽힘 = 결국 포탈처럼 보인다).
	#   → 콜리전과 똑같은 자리에 암반 사각형을 직접 그린다. 지형 아트(black_fill)와
	#     같은 명도(0.09)로 맞춰서 주변 지형에 자연스럽게 이어 붙게 했다.
	# 지형 아트(black_fill)의 실측 명도에 맞춘 값. 밝으면 통로만 떠 보인다.
	var 암반 := Color(0.055, 0.055, 0.062)
	var 중심x := d * L * 0.5 + d * 12.0
	var 몸길이 := L + 48.0
	# ★[2026-10-08 Claude] 쳅터1 방식에서는 암반을 **각진 상자로 그리지 않는다.**
	#   화면 확인(tools/_진단/쳅터2_전환/01) 결과, 하수도 벽돌 위에 가장자리가 딱 떨어진 검은 사각형 + 얇은 테두리선이
	#   "유리관 · 포탈" 처럼 읽혔다. 쳅터1 연결구는 얇은 벽 + 전경 그라데이션이라 상자가 없다.
	#   → 천장·바닥 암반은 통로에 붙은 쪽만 진하고 바깥으로 옅어지게, 테두리선·아치선은 생략(전경 띠가 어둠을 맡는다).
	if 쳅터1_전환:
		# 지형으로 메운 면은 암반 그림이 필요 없다(벽은 진짜 벽돌 지형이 맡는다). 안 메운 면만 그린다.
		_부드러운_암반(d, h, t, 중심x, 몸길이, 암반, not _메움_위, not _메움_아래)
		_통로_속(d, h, L)
		return
	# 바닥 — 콜리전은 두께 t 지만, 그림은 아래로 더 내려 지형에 파묻는다
	draw_rect(Rect2(중심x - 몸길이 * 0.5, 0.0, 몸길이, t + 암반_아래), 암반)
	# 천장 — 위로 더 올려 천장 매스와 이어 붙인다
	draw_rect(Rect2(중심x - 몸길이 * 0.5, -h - t - 암반_위, 몸길이, t + 암반_위), 암반)
	# 막다른 뒷벽 (콜리전 `_벽("뒷벽", ...)` 과 같은 자리). 위아래로 넉넉히 이어 붙인다.
	var 뒷벽중심 := Vector2(d * (L + t * 0.5), -h * 0.5)
	draw_rect(Rect2(뒷벽중심.x - t * 0.5, -h - t - 암반_위,
		t, h + t * 2.0 + 암반_위 + 암반_아래), 암반)

	# ── 1) 통로 안쪽 어둠 ── 입구는 아치, 안쪽으로 갈수록 완전한 검정
	# 세로로 얇은 띠를 여러 장 겹쳐 "안으로 갈수록 어두워지는" 그라데이션을 만든다.
	# (한 장으로 칠하면 평평한 검은 사각형이라 깊이가 안 느껴진다)
	var 띠수 := 16
	for i in 띠수:
		var t0 := float(i) / float(띠수)
		var t1 := float(i + 1) / float(띠수)
		# 안쪽으로 갈수록 진해진다 (0.55 → 어둠)
		var a := lerpf(0.55, 어둠, t0)
		var 폭0 := 1.0 - t0 * 0.10        # 안쪽이 살짝 좁아진다 = 원근
		var 폭1 := 1.0 - t1 * 0.10
		draw_colored_polygon(PackedVector2Array([
			Vector2(d * L * t0, -h * 폭0),
			Vector2(d * L * t1, -h * 폭1),
			Vector2(d * L * t1, 0),
			Vector2(d * L * t0, 0),
		]), Color(0.03, 0.03, 0.035, a))

	# ── 2) 아치 입구 ── 위쪽이 둥근 구멍. 지형에서 파낸 단면처럼 보이게 한다.
	var 아치 := PackedVector2Array()
	var 단계 := 16
	아치.append(Vector2(0, 0))
	for i in 단계 + 1:
		var ang := PI * float(i) / float(단계)
		아치.append(Vector2(d * cos(ang) * 6.0, -h * 0.72 - sin(ang) * h * 0.28))
	아치.append(Vector2(0, 0))

	# ── 3) 저 끝에서 새어나오는 빛 ── 다음 지역의 하늘색
	var 맥동 := 0.86 + 0.14 * sin(_t * 0.9)
	var 빛중심 := Vector2(d * L * 0.80, -h * 0.48)
	for i in range(7, 0, -1):
		var r := h * 0.55 * float(i) / 7.0
		var a := 0.10 * 맥동 * (1.0 - float(i) / 8.0)
		draw_circle(빛중심, r, Color(속빛.r, 속빛.g, 속빛.b, a))

	# ── 4) 통로 테두리 ── 위·아래 두 줄. 지형과 통로의 경계를 또렷하게.
	# 흑백 게임이라 실루엣 경계선 한 줄이 있고 없고가 가독성을 크게 바꾼다.
	var 위 := PackedVector2Array([Vector2(0, -h), Vector2(d * L, -h)])
	var 아래 := PackedVector2Array([Vector2(0, 0), Vector2(d * L, 0)])
	draw_polyline(위, Color(0.02, 0.02, 0.02), 6.0)
	draw_polyline(아래, Color(0.02, 0.02, 0.02), 6.0)
	draw_polyline(위, Color(0.60, 0.60, 0.63, 0.75), 2.0)
	draw_polyline(아래, Color(0.60, 0.60, 0.63, 0.75), 2.0)

	# 입구 아치 윤곽 (구멍의 가장자리)
	draw_polyline(아치, Color(0.66, 0.66, 0.69, 0.55), 2.0)

	# ⚠[2026-08-06] 예전엔 암반 위·아래에 밝은 윤곽선을 한 줄씩 그었는데,
	#   암반을 위아래로 더 크게 그리도록 바꾼 뒤로는 그 선이 **덩어리 한가운데를 가로지르는
	#   가로 줄무늬**가 되어 오히려 지저분해졌다(스크린샷에서 확인).
	#   통로 입구의 아치 윤곽만으로 경계는 충분히 읽힌다 → 삭제.

	# ── 5) 바닥에 깔린 빛 반사 ── 통로 안쪽 빛이 젖은 바닥에 비친다
	draw_line(Vector2(d * L * 0.25, -4), Vector2(d * L * 0.92, -4),
		Color(속빛.r, 속빛.g, 속빛.b, 0.30), 7.0)


## [2026-10-08] 쳅터1 방식 암반 — 통로 천장/바닥 면에서 멀어질수록 투명해지는 띠(위·아래 각 `두께 × 2.2`).
##   콜리전(천장·바닥 두께 t)이 있는 자리는 진하게 남겨 "막혀 있다" 는 읽히되, 바깥 가장자리 선이 생기지 않는다.
func _부드러운_암반(d: float, h: float, t: float, 중심x: float, 몸길이: float, 암반: Color,
		천장: bool = true, 바닥: bool = true) -> void:
	var x0 := 중심x - 몸길이 * 0.5
	var x1 := 중심x + 몸길이 * 0.5
	var 번짐 := t * 2.2
	var 진 := Color(암반.r, 암반.g, 암반.b, 0.92)
	var 옅 := Color(암반.r, 암반.g, 암반.b, 0.0)
	# 천장: 통로 윗면(-h) → 위로 번짐
	if 천장:
		draw_polygon(PackedVector2Array([Vector2(x0, -h - 번짐), Vector2(x1, -h - 번짐), Vector2(x1, -h), Vector2(x0, -h)]),
			PackedColorArray([옅, 옅, 진, 진]))
	# 바닥: 통로 바닥(0) → 아래로 번짐
	if 바닥:
		draw_polygon(PackedVector2Array([Vector2(x0, 0.0), Vector2(x1, 0.0), Vector2(x1, 번짐), Vector2(x0, 번짐)]),
			PackedColorArray([진, 진, 옅, 옅]))


## [2026-10-08] 쳅터1 방식 통로 속 — 안쪽으로 갈수록 어두워지는 띠 + 저 끝 속빛(다음 지역의 기운)만. 선은 긋지 않는다.
func _통로_속(d: float, h: float, L: float) -> void:
	var 띠수 := 12
	for i in 띠수:
		var t0 := float(i) / float(띠수)
		var t1 := float(i + 1) / float(띠수)
		draw_colored_polygon(PackedVector2Array([
			Vector2(d * L * t0, -h), Vector2(d * L * t1, -h), Vector2(d * L * t1, 0), Vector2(d * L * t0, 0),
		]), Color(0.03, 0.03, 0.035, lerpf(0.35, 어둠, t0)))
	var 맥동 := 0.86 + 0.14 * sin(_t * 0.9)
	var 빛중심 := Vector2(d * L * 0.80, -h * 0.48)
	for i in range(7, 0, -1):
		var r := h * 0.55 * float(i) / 7.0
		draw_circle(빛중심, r, Color(속빛.r, 속빛.g, 속빛.b, 0.10 * 맥동 * (1.0 - float(i) / 8.0)))


# ============================================================================
# [2026-10-08 Claude] 얇은 벽 — 하수도 통로 둘레의 직사각형 구멍을 메운다
# ----------------------------------------------------------------------------
# 도형님(v3): "하수도 지형의 직사각형 통로 구멍을 쳅터1 처럼 얇은 벽으로 다듬어."
#   하수도 빌더는 통로 자리를 지형 없이 비워 두고(예: 2-1 입구 544×400), 옛 통로 그림이 그 구멍을 검은 암반으로 덮었다.
#   쳅터1 방식에서는 그 구멍이 각진 상자로 보였다 → **통로 구멍 = 통로 높이의 길만 남기고 이웃 벽돌 지형으로 메운다.**
#
# ▣ 왜 씬 파일이 아니라 실행 때 메우나
#   하수도 씬은 다른 작업자가 손으로 고친 값이 많다. 스크립트로 씬을 다시 저장하면 편집 불가 인스턴스 안쪽의
#   덮어쓰기가 사라진 적이 있다(작업기록 2026-09-17 · `[editable]`). 씬을 열지 않고 같은 결과를 내려고
#   **구멍 크기를 물리로 재서**(통로 안에서 위·아래·안쪽으로 레이) 맞닿은 벽 지형을 복제해 ㄷ자 모양으로 채운다.
#   → 11 스테이지 전부, 앞으로 새로 짓는 하수도 스테이지에도 같은 규칙이 저절로 붙는다.
# ▣ 안전장치: 구멍이 아니라 탁 트인 공간이면(레이가 900px 안에 지형을 못 만나면) 그쪽은 메우지 않는다.
# ============================================================================
const 얇은벽_최대 := 900.0

func _얇은벽_만들기() -> void:
	if Engine.is_editor_hint() or not 쳅터1_전환 or not 통로_구멍_메움 or not is_inside_tree():
		return
	# SS2D 지형 콜리전은 씬이 뜬 뒤 몇 물리 프레임 지나야 공간에 올라온다 → 잴 때까지 몇 번 더 본다.
	for 시도 in 12:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		if _얇은벽_재고_메우기():
			return


## 한 번 재 보고 메웠으면(또는 메울 구멍이 없다고 확정되면) true.
func _얇은벽_재고_메우기() -> bool:
	var 공간 := get_world_2d().direct_space_state
	var 제외: Array[RID] = []
	for 이름 in ["바닥", "천장", "뒷벽"]:
		var 몸 := get_node_or_null(이름) as CollisionObject2D
		if 몸:
			제외.append(몸.get_rid())
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject2D:
			제외.append((p as CollisionObject2D).get_rid())
	var d := 방향()
	var O := global_position
	var h := 높이
	var L := 깊이
	# 위·아래: 입구 쪽·가운데·안쪽 세 곳에서 재어 가장 가까운 값(구멍이 계단져 있어도 지형을 넘지 않게).
	var 위 := INF
	var 아래 := INF
	var 원본: Node2D = null
	for f in [0.2, 0.5, 0.85]:
		var x: float = O.x + d * L * float(f)
		var r위 := _레이(공간, Vector2(x, O.y - h - 2.0), Vector2(x, O.y - h - 얇은벽_최대), 제외)
		if not r위.is_empty():
			위 = minf(위, O.y - (r위["position"] as Vector2).y)
			if 원본 == null:
				원본 = _복제할_지형(r위["collider"])
		var r아래 := _레이(공간, Vector2(x, O.y + 2.0), Vector2(x, O.y + 얇은벽_최대), 제외)
		if not r아래.is_empty():
			아래 = minf(아래, (r아래["position"] as Vector2).y - O.y)
			if 원본 == null:
				원본 = _복제할_지형(r아래["collider"])
	var r안 := _레이(공간, Vector2(O.x + d * L * 0.5, O.y - h * 0.5), Vector2(O.x + d * (L + 얇은벽_최대), O.y - h * 0.5), 제외)
	var 안 := absf((r안["position"] as Vector2).x - O.x) if not r안.is_empty() else INF
	if 원본 == null or 안 == INF:
		얇은벽_정보 = {"메움": false, "이유": "구멍 경계를 못 찾음"}
		return false
	# ★메우는 것은 **빌더가 통로 때문에 판 자리만**: 위·아래 = 벽 두께(두께) 한 장, 안쪽 = 뒷벽 한 장 (+여유 32).
	#   그보다 크게 재지면 그건 통로 구멍이 아니라 **사람이 다니는 방·수직 수로**다(2-6~2-8 입구 위 = 방, 2-10 출구 = 수로)
	#   → 그쪽은 메우지 않고 통로 높이 그대로 둔다(그 면은 아래 `_부드러운_암반` 이 그린다).
	var 여유 := 두께 + 32.0
	if 위 == INF or 위 > h + 여유:
		위 = h
	if 아래 == INF or 아래 > 여유:
		아래 = 0.0
	if 안 > L + 여유:
		안 = L
	위 = maxf(위, h)
	안 = maxf(안, L)
	_메움_위 = 위 > h + 4.0
	_메움_아래 = 아래 > 4.0
	if not _메움_위 and not _메움_아래 and 안 <= L + 4.0:
		얇은벽_정보 = {"메움": false, "이유": "구멍 없음"}
		return true
	var 점 := _메움_외곽(d, h, L, 위, 아래, 안)
	_얇은벽 = _지형_복제(원본, 점)
	얇은벽_정보 = {"메움": _얇은벽 != null, "위": 위, "아래": 아래, "안": 안, "원본": String(원본.name)}
	queue_redraw()
	return true


## 통로 길(입구 바깥 2px ~ 뒷벽 끝, 통로 높이)과 겹치는 지형에서 그 길을 잘라 낸다. 겹친 지형을 찾았으면 true.
##   스테이지 루트 아래 SS2D 지형의 **점 배열**과 길 사각형을 직접 겹쳐 본다(물리 공간을 쓰지 않는다).
func _벽_뚫기() -> bool:
	if not is_inside_tree():
		return false
	var d := 방향()
	var O := global_position
	var x0 := O.x - d * 2.0
	var x1 := O.x + d * (깊이 + 두께)
	var 길 := PackedVector2Array([
		Vector2(minf(x0, x1), O.y - 높이), Vector2(maxf(x0, x1), O.y - 높이),
		Vector2(maxf(x0, x1), O.y), Vector2(minf(x0, x1), O.y),
	])
	var 루트: Node = get_parent()
	while 루트 != null and 루트.get_node_or_null("Player") == null and 루트.get_parent() != get_tree().root:
		루트 = 루트.get_parent()
	if 루트 == null:
		return false
	var 지형들: Array[Node2D] = []
	for n in 루트.find_children("*", "", true, false):
		if not n.has_method("set_point_array") or not n.has_method("get_point_array") or not (n is Node2D):
			continue
		var 배열: Variant = n.call("get_point_array")
		if 배열 == null:
			continue
		var 전역 := (n as Node2D).global_transform * (배열 as SS2D_Point_Array).get_vertices()
		if 전역.size() >= 3 and not Geometry2D.intersect_polygons(전역, 길).is_empty():
			지형들.append(n as Node2D)
	for 지 in 지형들:
		_지형에서_잘라내기(지, 길)
	벽뚫기_정보 = {"잘라낸_지형": 지형들.map(func(n): return String(n.name))}
	return not 지형들.is_empty()


var 벽뚫기_정보: Dictionary = {}

func _지형에서_잘라내기(지: Node2D, 길_전역: PackedVector2Array) -> void:
	var 배열: Variant = 지.call("get_point_array")
	if 배열 == null:
		return
	var 로컬 := (배열 as SS2D_Point_Array).get_vertices()
	if 로컬.size() > 2 and 로컬[0].is_equal_approx(로컬[로컬.size() - 1]):
		로컬.remove_at(로컬.size() - 1)
	var 변환 := 지.global_transform
	var 길 := PackedVector2Array()
	for p in 길_전역:
		길.append(변환.affine_inverse() * p)
	var 조각들 := Geometry2D.clip_polygons(로컬, 길)
	# 구멍(시계 반대 방향 조각)이 생기면 길이 벽 한가운데에 떠 있다는 뜻 — 통로 입구가 벽 면에 붙어 있지 않다.
	var 바깥: Array[PackedVector2Array] = []
	for 조각 in 조각들:
		if Geometry2D.is_polygon_clockwise(조각) == Geometry2D.is_polygon_clockwise(로컬):
			바깥.append(조각)
	if 바깥.is_empty() or 바깥.size() != 조각들.size():
		push_warning("연결통로(%s): %s 를 깔끔하게 뚫지 못했다(조각 %d)" % [name, 지.name, 조각들.size()])
		return
	for i in 바깥.size():
		var 대상: Node2D = 지 if i == 0 else 지.duplicate() as Node2D
		if i > 0:
			대상.name = String(지.name) + "_뚫림%d" % i
			지.get_parent().add_child(대상)
			대상.global_transform = 변환
		var 새배열 := SS2D_Point_Array.new()
		새배열.add_points(바깥[i])
		새배열.close_shape()
		대상.call("set_point_array", 새배열)
		var 폴리 := 대상.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
		if 폴리:
			폴리.polygon = 바깥[i]


## 통로 길만 비운 메움 외곽(통로 원점 기준 로컬, 한 방향으로 도는 단순 다각형).
##   위·아래 둘 다 = ㄷ자 · 한쪽만 = ㄱ자 · 뒤만 = 사각. 겹치는 변(두께 0)이 생기면 SS2D 삼각분할이 깨지므로 경우를 나눈다.
func _메움_외곽(d: float, h: float, L: float, 위: float, 아래: float, 안: float) -> PackedVector2Array:
	var 상 := 위 > h + 4.0
	var 하 := 아래 > 4.0
	var 뒤 := 안 > L + 4.0
	var 점: Array[Vector2] = []
	if 상 and 하:
		점 = [Vector2(0, -위), Vector2(안, -위), Vector2(안, 아래), Vector2(0, 아래), Vector2(0, 0), Vector2(L, 0), Vector2(L, -h), Vector2(0, -h)]
	elif 상:
		점 = [Vector2(0, -위), Vector2(안, -위), Vector2(안, 0), Vector2(L, 0), Vector2(L, -h), Vector2(0, -h)]
	elif 하:
		점 = [Vector2(0, 0), Vector2(L, 0), Vector2(L, -h), Vector2(안, -h), Vector2(안, 아래), Vector2(0, 아래)]
	elif 뒤:
		점 = [Vector2(L, -h), Vector2(안, -h), Vector2(안, 0), Vector2(L, 0)]
	var 결과 := PackedVector2Array()
	for p in 점:
		var q := Vector2(p.x * d, p.y)
		if 결과.is_empty() or not 결과[결과.size() - 1].is_equal_approx(q):
			결과.append(q)
	# 뒤 메움이 없으면(안 == L) 같은 x 의 점이 일직선으로 겹친다 — 가운데 점을 지운다.
	var 정리 := PackedVector2Array()
	var n := 결과.size()
	for i in n:
		var a := 결과[(i - 1 + n) % n]
		var b := 결과[i]
		var c := 결과[(i + 1) % n]
		if absf((b - a).cross(c - b)) > 0.01:
			정리.append(b)
	if d < 0.0:
		정리.reverse()
	return 정리


func _레이(공간: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2, 제외: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1, 제외)
	q.collide_with_areas = false
	return 공간.intersect_ray(q)


## 맞은 콜리전에서 SS2D 지형 노드로 거슬러 올라간다. 내부 무늬(하수도_내부벽돌)·유령 지형은 복제하지 않는다
##   (무늬 사각형이 원본 자리 기준이라 옮기면 엉뚱한 곳에 흰 벽돌이 생긴다) → 같은 부모의 평범한 검정 지형을 대신 쓴다.
func _복제할_지형(맞은것: Object) -> Node2D:
	var n := 맞은것 as Node
	while n != null and not n.has_method("set_point_array"):
		n = n.get_parent()
	if n == null:
		return null
	if _복제_가능(n):
		return n as Node2D
	for 형제 in n.get_parent().get_children():
		if 형제.has_method("set_point_array") and _복제_가능(형제):
			return 형제 as Node2D
	return null


func _복제_가능(n: Node) -> bool:
	if n.get("내부_벽돌영역") != null or bool(n.get("무색일때_통과")):
		return false
	# ⚠ 지형의 `시작상태` 는 자기 enum(무색 0 · 검정 1 · 흰색 2 · 회색 3)이다 — ColorDefs.BLACK(0)과 다르다.
	var 상태: Variant = n.get("시작상태")
	return 상태 == null or int(상태) == 1


func _지형_복제(원본: Node2D, 로컬점: PackedVector2Array) -> Node2D:
	var 새 := 원본.duplicate() as Node2D
	if 새 == null:
		return null
	새.name = "얇은벽_" + String(name)
	원본.get_parent().add_child(새)
	새.global_position = global_position
	var 배열 := SS2D_Point_Array.new()
	배열.add_points(로컬점)
	배열.close_shape()
	새.call("set_point_array", 배열)
	var 폴리 := 새.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리:
		폴리.polygon = 로컬점
	# 화면을 채우는 벽이다 — 칠하기 대상이 아니다(맵 칠 비율·탄약 계산에 끼지 않게).
	if 새.get("칠하기_허용") != null:
		새.set("칠하기_허용", false)
	새.set_meta("role", "채움")
	return 새
