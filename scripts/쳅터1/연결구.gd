@tool
extends Node2D
## ============================================================================
## [2026-10-04 신규 · Claude] 연결구 — 쳅터1 스테이지와 스테이지가 이어지는 길목
## ----------------------------------------------------------------------------
## ▣ 도형님 지시 (2026-10-04 두 번째)
##   "문을 통과해야만 넘어가는 게 아니야. 문은 그냥 길을 알려 주는 표시일 뿐 … 꼭 문을 달 필요는 없어.
##    포탈 대신 자연스럽게 다음 스테이지랑 이어지게 하려면 한 부분은 타일셋보다 가까운 전경이
##    그라데이션으로 명암을 보여 주고 근처에 반딧불이가 깜빡이며 돌아다니는 것이 좋을 거 같아."
##   "어두운 벽이 너무 두껍지 않게 · 들어가면 카메라를 줌인 → 다음 스테이지에서 자동으로 걸어 나오며 천천히 줌아웃"
##
## ▣ 이 노드가 하는 일
##   1) 가까운 전경: 벽 구멍(길목) 위에 **타일보다 앞(z 60)** 에 그리는 얇은 그라데이션 띠.
##      바깥(다음 스테이지 쪽)으로 갈수록 어두워지고 방 안쪽으로는 투명해진다 — "저 너머가 이어진다".
##      PPT 「게임 ui 재설정」 6쪽의 세로 그라데이션 띠 예시와 같은 모양. 두께는 벽 두께 + 짧은 번짐뿐.
##   2) 반딧불이: 길목 바로 안쪽에 `반딧불이.gd` 를 하나 둔다(길 안내).
##   3) 판정: 몸이 벽 안쪽 면을 `발동_깊이` 만큼 넘으면 `전경전환` 이 줌인·암전·교체·줌아웃을 한다.
##   4) 닫힌 길목(`다음_씬` 없음 또는 `되돌아가기` 끔): 투명 벽 + 더 짙은 전경. 반딧불이 없음.
##   문 그림은 선택(도안 "문장식": true 면 생성기가 배경에 열린 문을 그려 준다).
##
## ▣ 배치 규약 (생성기 tools/쳅터1/만들기.py 가 이대로 놓는다)
##   · 원점 = 길목 **바닥선** 과 벽 **안쪽 면** 이 만나는 점.  · `방향` = 바깥쪽(+1 오른쪽 벽 · −1 왼쪽 벽)
##   · 노드 이름 = 연결 이름("왼쪽"/"오른쪽"…). 다른 씬의 `다음_연결` 이 이 이름을 찾는다.
## ============================================================================

const 전경전환_스크립트 := preload("res://scripts/쳅터1/전경전환.gd")
const 반딧불이_스크립트 := preload("res://scripts/쳅터1/반딧불이.gd")

## 바깥 방향. +1 = 오른쪽 벽의 길목, −1 = 왼쪽 벽의 길목.
@export_enum("왼쪽:-1", "오른쪽:1") var 방향: int = 1:
	set(v): 방향 = v; _재구성()
## 길목 구멍 높이(px). 몸 키 97 → 128(4칸) 이상.
@export_range(96, 512, 16) var 높이: float = 160.0:
	set(v): 높이 = v; _재구성()
## 벽 두께(px) — 카메라가 보여 주는 테두리 두께. 생성기 = 도안 벽 칸 × 32.
@export_range(32, 512, 16) var 벽두께: float = 160.0:
	set(v): 벽두께 = v; _재구성()

@export_group("연결")
## 걸어 나가면 넘어갈 씬. 비우면 닫힌 길목.
@export_file("*.tscn") var 다음_씬: String = ""
## 다음 씬에서 도착할 연결구 노드 이름.
@export var 다음_연결: String = "왼쪽"
## 끄면 이 길목으로는 못 나간다(되돌아가기 금지).
@export var 되돌아가기: bool = true:
	set(v): 되돌아가기 = v; _재구성()

@export_group("연출")
## 벽 안쪽 면에서 몸 중심이 이만큼(px) 바깥으로 들어가면 전환 시작.
@export_range(16, 256, 8) var 발동_깊이: float = 56.0
## 방 안쪽으로 번지는 그라데이션 폭(px). "너무 두껍지 않게" → 기본 96.
@export_range(0, 512, 8) var 번짐_폭: float = 96.0:
	set(v): 번짐_폭 = v; queue_redraw()
## 벽 쪽 끝 진하기(0~1). 열린 길목 기본 0.85 → 바깥 끝만 거의 검정.
@export_range(0.0, 1.0) var 진하기: float = 0.85:
	set(v): 진하기 = v; queue_redraw()
@export var 전경색: Color = Color(0.03, 0.028, 0.026, 1.0):
	set(v): 전경색 = v; queue_redraw()
## 반딧불이를 둘지(열린 길목만).
@export var 반딧불이: bool = true:
	set(v): 반딧불이 = v; _재구성()

const 터널_길이 := 384.0     ## 길목 밖 굴 길이(px) = 도안 문_터널 12칸
const 위_여유 := 0.9         ## 전경 띠를 구멍 위로 얼마나 더 올리나(높이 배수) — 위는 세로로 옅어진다

var _판정: Area2D = null
var _막이: StaticBody2D = null
var _빛: Node2D = null
var _무시중 := false         ## 방금 이 길목으로 도착 — 몸이 판정 밖으로 나갈 때까지 무시(왕복 튕김 방지)


func 열림() -> bool:
	return 되돌아가기 and not 다음_씬.is_empty()


## 다른 스테이지에서 이 길목으로 들어올 때 서는 자리(굴 안 — 카메라 리밋 밖).
func 도착_위치() -> Vector2:
	return global_position + Vector2(방향 * (벽두께 + 40.0), 0.0)


## 걸어 들어와 멈추는 자리(방 안쪽 2칸). 자동 체크포인트도 여기.
func 안쪽_위치() -> Vector2:
	return global_position + Vector2(-방향 * 64.0, 0.0)


func 도착시킴() -> void:
	_무시중 = true


func _ready() -> void:
	z_index = 60
	_재구성()
	if not Engine.is_editor_hint():
		add_to_group("연결구")


func _재구성() -> void:
	if not is_inside_tree():
		return
	queue_redraw()
	# ── 반딧불이 ── 길목 바로 안쪽, 구멍 높이 가운데쯤(에디터에서도 보이게)
	if 반딧불이 and 열림():
		if _빛 == null:
			_빛 = Node2D.new()
			_빛.set_script(반딧불이_스크립트)
			_빛.name = "반딧불이"
			add_child(_빛)
		_빛.position = Vector2(-방향 * 150.0, -높이 * 0.75)
		_빛.z_index = 2
		_빛.set("범위", Vector2(150, maxf(90.0, 높이 * 0.6)))
		_빛.set("씨앗", int(abs(global_position.x + global_position.y)) % 997 + 1)
	elif _빛:
		_빛.queue_free()
		_빛 = null
	if Engine.is_editor_hint():
		return
	# ── 판정 ── 벽 안쪽 면 + 발동_깊이 부터 굴 끝까지
	if _판정 == null:
		_판정 = Area2D.new()
		_판정.name = "판정"
		_판정.collision_layer = 0
		_판정.collision_mask = 1
		_판정.monitorable = false
		var 모양 := CollisionShape2D.new()
		모양.shape = RectangleShape2D.new()
		_판정.add_child(모양)
		add_child(_판정)
		_판정.body_entered.connect(_몸_들어옴)
		_판정.body_exited.connect(_몸_나감)
	var 폭 := 벽두께 + 터널_길이 - 발동_깊이
	var 사각 := _판정.get_child(0) as CollisionShape2D
	(사각.shape as RectangleShape2D).size = Vector2(폭, 높이)
	사각.position = Vector2(방향 * (발동_깊이 + 폭 * 0.5), -높이 * 0.5)
	# ── 막이 ── 닫힌 길목은 벽 안쪽 면에 투명 벽
	if not 열림():
		if _막이 == null:
			_막이 = StaticBody2D.new()
			_막이.name = "막이"
			var 벽 := CollisionShape2D.new()
			벽.shape = RectangleShape2D.new()
			(벽.shape as RectangleShape2D).size = Vector2(16.0, 높이 + 64.0)
			_막이.add_child(벽)
			add_child(_막이)
		(_막이.get_child(0) as CollisionShape2D).position = Vector2(방향 * 8.0, -높이 * 0.5 - 32.0)
	elif _막이:
		_막이.queue_free()
		_막이 = null


func _몸_들어옴(몸: Node2D) -> void:
	# 사망 모션으로 멈춘 본체가 길목에 걸쳐 있어도 다음 스테이지로 넘어가지 않는다.
	if 몸 is CharacterBody2D and not 몸.is_physics_processing():
		return
	if _무시중 or not 몸.is_in_group("player") or not 열림():
		return
	if 전경전환_스크립트.진행중인가():
		return
	전경전환_스크립트.연결로_이동(self, 몸 as CharacterBody2D)


func _몸_나감(몸: Node2D) -> void:
	if 몸.is_in_group("player"):
		_무시중 = false


# ── 그림: 가까운 전경 띠 ─────────────────────────────────────────────────────
## 가로 = 바깥으로 갈수록 진해지는 그라데이션(방 안쪽 번짐_폭 → 벽 → 굴 끝).
## 세로 = 구멍 높이까지는 그대로, 그 위로는 위_여유 만큼 옅어지며 사라진다(각진 상자 금지).
func _draw() -> void:
	var d := float(방향)
	var 열 := 열림()
	var 진 := 진하기 if 열 else 1.0
	var 번 := 번짐_폭 if 열 else 번짐_폭 * 1.8
	var 위 := -높이 * (1.0 + 위_여유)
	var 허리 := -높이
	var 아래 := 48.0
	# x 지점들(방 안쪽 → 바깥): 번짐 시작 · 벽 안쪽 면 · 벽 바깥 면 · 굴 끝
	var xs := [-d * 번, 0.0, d * 벽두께, d * (벽두께 + 터널_길이)]
	var 알파 := [0.0, 진 * 0.55, 진, 1.0]
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		var ca := Color(전경색.r, 전경색.g, 전경색.b, 알파[i])
		var cb := Color(전경색.r, 전경색.g, 전경색.b, 알파[i + 1])
		var 투명 := Color(전경색.r, 전경색.g, 전경색.b, 0.0)
		# 구멍 높이 부분(허리 아래): 가로 그라데이션만
		draw_polygon(PackedVector2Array([Vector2(xa, 허리), Vector2(xb, 허리), Vector2(xb, 아래), Vector2(xa, 아래)]),
			PackedColorArray([ca, cb, cb, ca]))
		# 그 위: 세로로도 옅어진다
		draw_polygon(PackedVector2Array([Vector2(xa, 위), Vector2(xb, 위), Vector2(xb, 허리), Vector2(xa, 허리)]),
			PackedColorArray([투명, 투명, cb, ca]))
	if Engine.is_editor_hint():
		draw_line(Vector2(d * 발동_깊이, -높이), Vector2(d * 발동_깊이, 0), Color(1, 0.6, 0.1), 3.0)
		draw_circle(Vector2(d * (벽두께 + 40.0), -48.0), 10.0, Color(0.2, 0.8, 0.3))
		draw_circle(Vector2(-d * 64.0, -48.0), 8.0, Color(0.3, 0.6, 1.0))
		var 글 := "%s → %s" % [name, (다음_씬.get_file().get_basename() + "·" + 다음_연결) if 열 else "닫힘"]
		draw_string(ThemeDB.fallback_font, Vector2(d * 8.0 - (260.0 if d < 0 else 0.0), -높이 - 12.0), 글,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.75, 0.3))
