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

## ColorDefs의 고정값(검정=0, 흰색=1, 회색=2)을 그대로 쓰되,
## 인스펙터에서는 숫자가 아닌 물 색 이름을 선택하게 한다.
enum 물색_ { 흰색 = 1, 회색 = 2, 검정색 = 0 }

## 유체의 물리·혼합 규칙은 그대로 두고, 물만 같은 실루엣의 SpriteFrames 3종으로 보여 준다.
## 색이 바뀔 때 프레임 묶음도 교체해야 회색으로 섞인 물이 이전 색 그림으로 남지 않는다.
const 물_프레임_흰색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/animated_v4/fluid_white_frames_v4.tres")
const 물_프레임_회색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/animated_v4/fluid_gray_frames_v4.tres")
const 물_프레임_검정색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/animated_v4/fluid_black_frames_v4.tres")
## 본체 물결을 바꾸지 않고, 안쪽 물방울만 아래로 움직여 낙하 방향을 읽게 하는 상세 레이어다.
const 물_상세_프레임_흰색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/flow_details_v1/fluid_white_flow_detail_frames_v1.tres")
const 물_상세_프레임_회색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/flow_details_v1/fluid_gray_flow_detail_frames_v1.tres")
const 물_상세_프레임_검정색: SpriteFrames = preload("res://assets/textures/obstacles/liquid/flow_details_v1/fluid_black_flow_detail_frames_v1.tres")

@export var 종류: 종류_ = 종류_.물:
	set(v):
		종류 = v
		_물_그림_갱신()
		queue_redraw()

## ⚠[2026-08-07 버그 수정] 예전에는 `색` 만 바꿨는데, 아래 `_physics_process` 의
##   섞임 계산이 매 프레임 `_원래색` 을 기준으로 색을 다시 정하기 때문에
##   **런타임에 색을 바꾸면 다음 물리 프레임에 원래 색으로 되돌아갔다.**
##   (레버로 물 색을 바꾸거나 도구/테스트가 색을 지정할 때 조용히 무시됐다)
##   → 바깥에서 색을 지정하면 `_원래색` 도 같이 갱신한다. 섞임 계산이 스스로
##     색을 쓸 때만 `_섞는중` 플래그로 그 갱신을 건너뛴다.
@export var 색: 물색_ = 물색_.흰색:
	set(v):
		색 = v
		if not _섞는중:
			_원래색 = v
		_물_그림_갱신()
		queue_redraw()

## 유체가 차지하는 사각 영역(px). 폭 좁고 세로로 길면 "떨어지는 물줄기"가 된다.
@export var 크기: Vector2 = Vector2(64, 260):
	set(v):
		크기 = Vector2(maxf(v.x, 8.0), maxf(v.y, 8.0))
		# 씬을 읽는 중에는 자식 CollisionShape2D가 아직 들어오기 전이다.
		# 그때 만들면 tscn의 같은 이름 노드와 충돌하므로, 로드 완료 뒤에만 갱신한다.
		if is_node_ready():
			_모양_갱신()
		queue_redraw()

## 물 이미지는 가는 물줄기와 넓게 퍼진 아래 물보라로 구성된다.
## 큰 직사각형 하나를 쓰면 투명한 좌우 공간도 닿은 것으로 판정되므로, 세 구간 폭을 따로 둔다.
@export_group("물 판정 범위")
@export_range(0.10, 1.00, 0.01) var 물줄기_판정_폭_비율: float = 0.332:
	set(v):
		물줄기_판정_폭_비율 = clampf(v, 0.10, 1.00)
		if is_node_ready():
			_모양_갱신()

@export_range(0.10, 1.00, 0.01) var 중간_물보라_판정_폭_비율: float = 0.766:
	set(v):
		중간_물보라_판정_폭_비율 = clampf(v, 0.10, 1.00)
		if is_node_ready():
			_모양_갱신()

@export_range(0.10, 1.00, 0.01) var 바닥_물보라_판정_폭_비율: float = 0.953:
	set(v):
		바닥_물보라_판정_폭_비율 = clampf(v, 0.10, 1.00)
		if is_node_ready():
			_모양_갱신()

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

## 각 애니메이션 프레임에서 실제 알파가 차지하는 폭 비율이다.
## 색만 다른 세 SpriteFrames는 같은 실루엣을 쓰므로, 이 표 하나를 공용으로 쓴다.
const 물_프레임_실루엣_폭: Array[Vector3] = [
	Vector3(0.332, 0.766, 0.953),
	Vector3(0.332, 0.805, 0.953),
	Vector3(0.344, 0.820, 0.953),
	Vector3(0.344, 0.820, 0.953),
	Vector3(0.324, 0.820, 0.961),
	Vector3(0.324, 0.820, 0.961),
	Vector3(0.328, 0.816, 0.953),
	Vector3(0.328, 0.816, 0.953),
]
const 물_기준_프레임_실루엣_폭 := Vector3(0.332, 0.766, 0.953)
## 판정 사각형을 이미 내 것으로 복제했다는 표식. `_직사각_판정()` 참고.
const 내_모양_표식 := &"__유체_전용_판정모양__"
## 바닥 물보라가 충격 때 위로 튀는 높이다. 물줄기 판정의 끝도 같은 높이에서 멈춘다.
const 물_프레임_물보라_시작_비율: Array[float] = [0.750, 0.752, 0.713, 0.688, 0.664, 0.684, 0.703, 0.758]
const 물_바닥_물보라_시작_비율 := 0.875
var _마지막_판정_프레임: int = -1


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 8
	monitoring = true
	monitorable = true
	_모양_갱신()
	_원래색 = 색
	_물_그림_갱신()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("유체")
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
	set_physics_process(true)
	set_process(true)
	_켜짐_반영()


func _모양_갱신() -> void:
	if 종류 == 종류_.물:
		_물_판정_갱신()
	else:
		_물_판정_숨기기()
		var c := _직사각_판정("모양")
		var s := c.shape as RectangleShape2D
		s.size = 크기
		# 연기는 기존 직사각형 판정을 유지한다. 물보라 전용 3분할을 연기에 적용하면
		# 위로 퍼지는 기체의 기존 규칙과 보이는 범위가 달라지기 때문이다.
		c.disabled = false
		c.position = Vector2(0, -크기.y * 0.5)
	# 유체 인스턴스마다 물줄기 길이가 다르다. 그림도 같은 판정 크기로 맞춰야
	# 56x300 기본값 그림이 긴 물줄기 중앙에만 짧게 남지 않는다.
	var 그림 := 아트슬롯.슬롯(self)
	if 그림 != null:
		그림.기준_크기 = 크기
	_물_애니_크기_맞추기()


## 물 그림의 알파 폭(본체 약 35% / 아래로 갈수록 넓어지는 물보라)을 따라
## 충돌을 세 사각형으로 나눈다. 원점은 배관 출구와 맞추기 위한 물의 윗끝이다.
func _물_판정_갱신() -> void:
	var 이전_사각 := get_node_or_null("모양") as CollisionShape2D
	if 이전_사각 != null:
		# 이전 버전 씬에 저장된 전체 사각형이 있더라도 중복 판정되지 않게 끈다.
		이전_사각.disabled = true
	var 프레임_폭 := _현재_프레임_실루엣_폭()
	var 물보라_시작 := _현재_프레임_물보라_시작_비율()
	var 중간_물보라_높이 := 물_바닥_물보라_시작_비율 - 물보라_시작
	# 인스펙터 비율은 0번 프레임의 기준값이다. 이후 프레임은 실제 알파 변화량만
	# 곱해서 보정하므로, 디자이너가 조절한 난이도 폭도 유지한 채 애니메이션을 따른다.
	_판정_사각_설정("물줄기_판정", 물줄기_판정_폭_비율 * 프레임_폭.x / 물_기준_프레임_실루엣_폭.x, 0.00, 물보라_시작)
	_판정_사각_설정("중간_물보라_판정", 중간_물보라_판정_폭_비율 * 프레임_폭.y / 물_기준_프레임_실루엣_폭.y, 물보라_시작, 중간_물보라_높이)
	_판정_사각_설정("바닥_물보라_판정", 바닥_물보라_판정_폭_비율 * 프레임_폭.z / 물_기준_프레임_실루엣_폭.z, 물_바닥_물보라_시작_비율, 0.125)


func _물_판정_숨기기() -> void:
	for 이름 in [&"물줄기_판정", &"중간_물보라_판정", &"바닥_물보라_판정"]:
		var 판정 := get_node_or_null(NodePath(이름)) as CollisionShape2D
		if 판정 != null:
			판정.disabled = true


func _판정_사각_설정(이름: StringName, 폭_비율: float, 시작_비율: float, 높이_비율: float) -> void:
	var 판정 := _직사각_판정(이름)
	var 모양 := 판정.shape as RectangleShape2D
	모양.size = Vector2(크기.x * 폭_비율, 크기.y * 높이_비율)
	판정.position = Vector2(0, 크기.y * (시작_비율 + 높이_비율 * 0.5))
	판정.disabled = false


## ⚠[2026-09-02] 이 판정 사각형은 **인스턴스마다 자기 것**이어야 한다.
##
## ▣ 무슨 일이 있었나 (stage_2-1 물 판정이 그림과 어긋남)
##   씬 파일에 박힌 서브리소스는 `resource_local_to_scene` 이 꺼져 있으면
##   **그 씬의 모든 인스턴스가 한 개를 공유한다** — Godot 의 기본 동작이다.
##   아래에서 `모양.size` 를 제자리에서 고치기 때문에, 공유된 채로 두면
##   유체 14 개가 사각형 하나에 번갈아 써서 **맨 마지막 것이 이긴다.**
##   실제로 stage_2-1 의 물 14 개가 크기가 제각각(56×300 ~ 300×800)인데도
##   판정은 전부 `18.592 × 675` 한 값이었다(= 마지막 노드 유체6 의 값).
##   `position` 만 멀쩡했던 이유는 그건 리소스가 아니라 **노드 속성**이라서다.
##   → 그림은 각자 크기대로 그려지는데 판정만 딴 데 있으니, 폭 300 짜리 물이
##     18.6px 로만 잡히는 등 "물에 닿았는데 안 죽는" 상태가 된다.
##
## ▣ 두 겹으로 막는다
##   ① `유체.tscn` 의 사각형 3 개에 `resource_local_to_scene = true` 를 줬다.
##      → 엔진이 인스턴스마다 복사본을 만들어 준다. 에디터에서도 판정이 제대로 보이고,
##        **부모 씬에 덮어쓰기가 저장되지 않아** stage 씬이 불어나지 않는다.
##   ② 그래도 공유된 사각형이 들어오면(플래그 없는 새 유체 씬 등) 여기서 복제한다.
##      ⚠ 런타임에서만 복제한다 — 에디터에서 `판정.shape` 에 새 리소스를 넣으면
##        그게 인스턴스 덮어쓰기로 **씬 파일에 저장**되어 파일이 지저분해진다.
func _직사각_판정(이름: StringName) -> CollisionShape2D:
	var 판정 := get_node_or_null(NodePath(이름)) as CollisionShape2D
	if 판정 == null:
		판정 = CollisionShape2D.new()
		판정.name = 이름
		add_child(판정)
	var 모양 := 판정.shape as RectangleShape2D
	if 모양 == null:
		모양 = RectangleShape2D.new()
		판정.shape = 모양
	elif not (Engine.is_editor_hint() or 모양.resource_local_to_scene
			or 판정.has_meta(내_모양_표식)):
		# 남과 나눠 쓰는 사각형이다 → 내 것으로 복제한다. 한 번만 하면 된다.
		모양 = 모양.duplicate() as RectangleShape2D
		판정.shape = 모양
		판정.set_meta(내_모양_표식, true)
	return 판정


func _켜짐_반영() -> void:
	monitoring = 켜짐
	visible = 켜짐


## 물은 반투명 SpriteFrames 3종을 색 규칙과 같은 기준으로 골라 계속 재생한다.
## 연기는 기존 코드 그림을 유지한다. 물 프레임을 억지로 뒤집어 쓰면 기체처럼 안 보이기 때문이다.
func _물_그림_갱신() -> void:
	var 그림 := 아트슬롯.슬롯(self)
	var 애니 := _물_애니()
	var 상세 := _물_상세_애니()
	if 종류 != 종류_.물:
		# 연기용 커스텀 그림은 보존하고, 물 애니메이션만 숨긴다.
		if 그림 != null:
			그림.visible = true
		if 애니 != null:
			애니.stop()
			애니.visible = false
		if 상세 != null:
			상세.stop()
			상세.visible = false
		return
	# 물은 정지 Sprite2D 대신 AnimatedSprite2D가 그린다. 그래야 _draw가 아래에 겹쳐 그리지 않는다.
	if 그림 != null:
		그림.visible = false
	if 애니 == null and 상세 == null:
		return
	match 색:
		ColorDefs.BLACK:
			if 애니 != null: 애니.sprite_frames = 물_프레임_검정색
			if 상세 != null: 상세.sprite_frames = 물_상세_프레임_검정색
		ColorDefs.GRAY:
			if 애니 != null: 애니.sprite_frames = 물_프레임_회색
			if 상세 != null: 상세.sprite_frames = 물_상세_프레임_회색
		_:
			if 애니 != null: 애니.sprite_frames = 물_프레임_흰색
			if 상세 != null: 상세.sprite_frames = 물_상세_프레임_흰색
	if 애니 != null:
		애니.animation = &"흐름"
		애니.visible = true
	if 상세 != null:
		상세.animation = &"흐름"
		상세.visible = true
	_물_애니_크기_맞추기()
	# 에디터에서는 첫 프레임만 보이고, 게임에서는 8fps 루프가 바로 이어서 흐른다.
	if Engine.is_editor_hint():
		if 애니 != null: 애니.frame = 0
		if 상세 != null: 상세.frame = 0
	else:
		if 애니 != null: 애니.play(&"흐름")
		if 상세 != null: 상세.play(&"흐름")


## 원점은 물의 출구(윗끝)다. 프레임 중앙을 판정 사각형 중앙으로 옮긴 뒤 같은 크기로 맞춘다.
func _물_애니_크기_맞추기() -> void:
	var 애니 := _물_애니()
	var 상세 := _물_상세_애니()
	if 종류 != 종류_.물:
		return
	var 배율 := Vector2(크기.x / 256.0, 크기.y / 512.0)
	if 애니 != null:
		애니.position = Vector2(0, 크기.y * 0.5)
		애니.scale = 배율
	if 상세 != null:
		상세.position = Vector2(0, 크기.y * 0.5)
		상세.scale = 배율


func _물_애니() -> AnimatedSprite2D:
	return get_node_or_null("물_애니메이션") as AnimatedSprite2D


func _물_상세_애니() -> AnimatedSprite2D:
	return get_node_or_null("물결_상세_애니메이션") as AnimatedSprite2D


func _물_애니_재생중() -> bool:
	var 애니 := _물_애니()
	return 애니 != null and 애니.visible and 애니.sprite_frames != null


func _현재_프레임_실루엣_폭() -> Vector3:
	var 애니 := _물_애니()
	if 애니 == null:
		return 물_기준_프레임_실루엣_폭
	return 물_프레임_실루엣_폭[clampi(애니.frame, 0, 물_프레임_실루엣_폭.size() - 1)]


func _현재_프레임_물보라_시작_비율() -> float:
	var 애니 := _물_애니()
	if 애니 == null:
		return 물_프레임_물보라_시작_비율[0]
	return 물_프레임_물보라_시작_비율[clampi(애니.frame, 0, 물_프레임_물보라_시작_비율.size() - 1)]


## AnimatedSprite2D의 프레임이 바뀐 때만 충돌 폭을 갱신한다.
## 매 렌더 프레임에 Shape2D를 새로 쓰지 않아도 8fps 물결과 판정이 정확히 같이 움직인다.
func _물_애니_판정_따르기() -> void:
	if 종류 != 종류_.물:
		return
	var 애니 := _물_애니()
	if 애니 == null or not 애니.visible or 애니.frame == _마지막_판정_프레임:
		return
	_마지막_판정_프레임 = 애니.frame
	_물_판정_갱신()


# ── 규칙 ───────────────────────────────────────────────────────────────────
## 반대색 투사체를 막는다 (기획: "물과 상반되는 색의 투사체를 막는다").
## 회색 유체는 아무것도 안 막는다 — 회색은 두 색을 아우르는 색이라서.
func 총알_막나(총알색: int) -> bool:
	if not 켜짐 or 색 == ColorDefs.GRAY:
		return false
	return 총알색 != 색


## 플레이어가 이 유체에 닿으면 죽는가.
func 반대색인가(플레이어색: int) -> bool:
	# 꺼진 유체는 그 자리에 아무것도 없다 → 색 규칙 이전의 문제다.
	if not 켜짐:
		return false
	# ★[2026-08-30] 규칙은 `색규칙.gd` 한 곳에서만 판단한다.
	return 색규칙.위험한가(색, 플레이어색)


## 유체는 색칠할 수 없다 → 총알이 맞아도 페인트는 회수된다.
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return 색


## 물은 원점에서 아래로 시작한다. 호퍼·저장고 포트가 이 점을 기준으로 실제 연결을 찾는다.
func 시작점_월드좌표() -> Vector2:
	return global_position


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
	_물_애니_판정_따르기()
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 또는 물 애니메이션이 보이면 코드 그리기는 쉰다.
	# 둘 다 비었을 때만 기존 도형 그림을 써서, 연기와 커스텀 그림의 회귀를 막는다.
	if 아트슬롯.그림_있나(self) or _물_애니_재생중():
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
