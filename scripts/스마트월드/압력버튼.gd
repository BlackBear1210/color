@tool
extends AnimatableBody2D
## ============================================================================
## 압력 버튼 — 밟기 상호작용과 이동 대상을 인스펙터에서 연결하는 범용 장치
## ----------------------------------------------------------------------------
## 버튼은 직접 길을 만들지 않는다. `대상들`에 움직일 Node2D를 지정하고, 같은
## 순서의 `대상_이동량들`에 이동 벡터를 넣는다. 그래서 벽·발판·문 등 어떤
## Node2D라도 하나의 버튼으로 움직일 수 있다.
##
## 2-2 입구는 버튼에서 내린 뒤에도 통로가 유지되어야 실제로 건널 수 있으므로
## `한 번 누르면 유지`를 쓴다. 다른 퍼즐에서는 `누르는 동안만`으로 바꿔
## 양동이·상자 등을 올려두는 유지형 버튼으로 쓸 수 있다.
## ============================================================================
class_name 압력버튼

# 호퍼와 같은 주철 부품을 분리해서 상판만 눌리고 고정 프레임은 움직이지 않게 한다.
const 주철_부품 = preload("res://assets/textures/obstacles/switch/cast_iron_v1/parts.png")
const 원근_그림 = preload("res://scripts/스마트월드/발판_원근그림.gd")
const 원근_매립 = preload("res://scripts/스마트월드/발판_매립마감.gd")

## 하수도 지형과 같은 윗면/단면을 선택한다. 저장값이 없는 기존 스테이지는 이전 외관을 유지한다.
@export var 챕터1_원근: bool = false:
	set(value):
		챕터1_원근 = value
		_원근_그림준비 = false
		queue_redraw()
		if value and is_node_ready():
			_원근마감_설치()

func 발_그림_깊이() -> float:
	# 8px 솟은 상판과 발 그림을 같이 내린다. 누르는 동안 발이 판 속에 잠기거나 떠 보이는 차이를 줄인다.
	# 실제 몸/충돌은 그대로여서 상자를 밀어 넣을 때 새 턱에 걸리지 않는다.
	return 7.0 - 원근_그림.상판_올림(_눌림_표현) if 챕터1_원근 else 0.0

@export_group("버튼 모양")
@export_range(48.0, 320.0) var 폭: float = 96.0:
	set(v):
		폭 = v
		_재구성()
@export_range(12.0, 80.0) var 높이: float = 24.0:
	set(v):
		높이 = v
		_재구성()
@export_range(12.0, 120.0) var 감지_높이: float = 44.0:
	set(v):
		감지_높이 = v
		_재구성()

## [2026-10-09 Claude · 쳅터1 15] 생김새 — 0 = 하수도 주철(홈에 앉는 버튼 · 예전 그대로) / 1 = 쳅터1 바닥 위 철판.
##   도형님: "발판은 지형 아래로 파서 넣은 것 같은데 기존의 지형 윗면에 설치된 것처럼" → 1 은 원점(바닥선) 위
##   2.5D 목재 윗면 가운데(`그림_깊이` +7)에 얇은 낡은 철판(리벳 넷)을 얹어 그린다. 누르면 윗면과 같은 높이로 내려앉는다.
@export_enum("하수도 주철", "쳅터1 바닥 철판") var 생김새: int = 0:
	set(v):
		생김새 = v
		queue_redraw()
## 2.5D 바닥 윗면 가운데까지의 깊이(px) — 쳅터1 목재는 +7(플레이어 발·도약대·촛불등과 같은 줄).
@export var 그림_깊이: float = 0.0
## [2026-10-09] 밟는 면 충돌을 쓸까. 쳅터1 바닥 위 철판은 끈다 — 얇은 판이라 상자가 턱에 걸리지 않고 그대로 올라앉는다
##   (판정은 위의 '누름감지' 영역이 한다 · 하수도 버튼은 홈 속이라 기본값 true 그대로).
@export var 밟는면_충돌: bool = true:
	set(v):
		밟는면_충돌 = v
		_재구성()

@export_group("상호작용 설정")
## 0=버튼 위에 무게가 있는 동안만, 1=처음 밟은 뒤 계속 켜짐.
@export_enum("누르는 동안만", "한 번 누르면 유지") var 작동방식: int = 0
## 기본 player 외에 양동이·상자 그룹을 추가하면 그 물체도 버튼을 누를 수 있다.
@export var 누름_가능_그룹: PackedStringArray = PackedStringArray(["player"])
## 이 버튼과 동시에 눌려야 할 다른 버튼들. 이 버튼만 `대상들`을 움직이면 된다.
## 따라서 두 버튼이 같은 벽을 서로 다른 위치로 덮어쓰는 충돌을 막는다.
@export var 동시_버튼들: Array[NodePath] = []

@export_group("움직일 대상")
## 대상들과 이동량들은 같은 번호끼리 짝이다. NodePath는 인스펙터의 노드 선택기로 넣는다.
@export var 대상들: Array[NodePath] = []
## 예: Vector2(0, 800)은 아래 800px, Vector2(320, 0)은 오른쪽 320px 이동이다.
@export var 대상_이동량들: Array[Vector2] = []
@export_range(40.0, 1200.0) var 이동속도: float = 360.0
## ★[2026-10-08 Claude · 2-5] 대상마다 "켜진 뒤 몇 초 있다가 움직이기 시작하나". 비워 두면 전부 0(예전처럼 한꺼번에).
##   왜: 2-5 도면 "발판_1 이 홀드가 되면 맨 아래 검은지형_1 부터 _5 까지 하나씩 튀어나와 큰 계단을 이룬다".
##   꺼질 때는 거꾸로(지연이 큰 것부터) 들어간다 — 맨 위 계단이 먼저 들어가야 아래 계단이 위 계단을 뚫고 지나가 보이지 않는다.
@export var 대상_지연들: Array[float] = []
## ★[2026-10-09 Claude · 2-7] 대상마다 "꺼진 뒤 몇 초 있다가 들어가기 시작하나". 비워 두면 위의 거꾸로 순서(예전 동작).
##   왜: 2-7 도면 "발판_2 를 쭉 홀드할 수가 없는 상태 … 검은지형 다시 벽으로 들어가는 순서는 _1 부터 들어감".
##   플레이어가 발판에서 내려 계단을 오르는 동안 **아래 계단부터** 차례로 들어가야 오르는 사람을 뒤쫓는 긴장이 생긴다.
##   계단은 서로 다른 높이 띠에서 옆으로만 움직이므로 아래부터 들어가도 서로 겹쳐 보이지 않는다.
@export var 대상_꺼짐_지연들: Array[float] = []
## ★[2026-10-09 Claude · 2-7] 대상이 벽 속(숨는 자리)에 다 들어가 있으면 감춘다. −1 = 안 감춤(예전) · 0 = 시작 자리가 벽 속 · 1 = 나간 자리가 벽 속.
##   왜: Codex 원근 지형(챕터1_원근)은 본체가 비쳐 보여서, 벽 속에 넣어 둔 계단의 윗면 덮개가 벽 위에 그대로 그려졌다
##   (2-7 실화면 · z −1 그릇이어도 보인다). 다 들어간 동안만 숨기므로 나오고 들어가는 움직임은 그대로 보인다.
@export_range(-1, 1) var 숨는_자리: int = -1

var _감지: Area2D
var _대상_노드들: Array[Node2D] = []
var _대상_시작위치들: Array[Vector2] = []
var _기억된_눌림 := false
var _활성 := false
var _눌림_표현 := 0.0
# 편집 중 스크립트 재연결 뒤에는 _ready가 다시 오지 않아 그림이 비어 있을 수 있다.
var _편집_그림서명: int = 0
var _원근_그림준비 := false
## 대상마다 지금 "나가 있어야 하나" — `대상_지연들` 이 있을 때만 활성과 달라진다.
var _대상_켜짐: Array[bool] = []
## 활성이 마지막으로 바뀐 뒤 흐른 시간(초). 지연 판정에 쓴다.
var _전환_경과 := 0.0


func _ready() -> void:
	_재구성()
	_대상_연결_갱신()
	if 챕터1_원근:
		_원근마감_설치()
	if Engine.is_editor_hint():
		return
	set_physics_process(true)


func _원근마감_설치() -> void:
	if has_node("_원근_매립마감"):
		return
	# 생성 보조 노드는 저장하지 않는다. 기존 씬의 owner를 건드리지 않아 재로드 중복을 막는다.
	var trim := Node2D.new()
	trim.name = "_원근_매립마감"
	trim.set_script(원근_매립)
	add_child(trim)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# 속성이 바뀌거나 오류 수정 후 스크립트가 다시 붙은 첫 순간에만 편집기 그림을 복구한다.
	# 매 프레임 재그리면 2D 작업창이 느려지므로 같은 모양은 그대로 둔다.
	var signature := hash([폭, 높이, 감지_높이, 챕터1_원근])
	if signature == _편집_그림서명:
		return
	_편집_그림서명 = signature
	_재구성()
	if 챕터1_원근:
		_원근마감_설치()


func 원근_그림_준비됨() -> bool:
	# 발판 그림이 그려진 뒤에만 돌 마감을 걷어내 빈자리만 남는 순서를 막는다.
	return 챕터1_원근 and _원근_그림준비


func _physics_process(delta: float) -> void:
	# @tool도 물리 처리가 호출되므로 편집기에서는 연결된 지형을 이동하거나 숨기지 않는다.
	if Engine.is_editor_hint():
		return
	var 지금_눌림 := _누를_수_있는_몸이_올라섰나()
	if 지금_눌림:
		_기억된_눌림 = true
	var 새_활성 := _기억된_눌림 if 작동방식 == 1 else 지금_눌림
	if 새_활성 and not _동시_버튼도_눌렸나():
		새_활성 = false
	if 새_활성 != _활성:
		_활성 = 새_활성
		_전환_경과 = 0.0
		queue_redraw()
	_전환_경과 += delta
	# 활성 전환 한 번만 다시 그리면 눌림/복귀 중간 프레임이 멎으므로 이동 중에도 갱신한다.
	var 이전_표현 := _눌림_표현
	_눌림_표현 = move_toward(_눌림_표현, 1.0 if 지금_눌림 else 0.0, delta * 8.0)
	if 이전_표현 != _눌림_표현:
		queue_redraw()
	_대상_이동(delta)


func _대상_연결_갱신() -> void:
	_대상_노드들.clear()
	_대상_시작위치들.clear()
	_대상_켜짐.clear()
	for 경로 in 대상들:
		var 대상 := get_node_or_null(경로) as Node2D
		if 대상 == null:
			# 아직 씬 트리에 붙지 않은 @tool 편집 순간에는 조용히 건너뛴다.
			# 게임 실행 때도 못 찾으면 그 대상만 움직이지 않아 다른 연결은 안전하게 유지된다.
			continue
		# ★[2026-09-07] 메타 이름은 **ASCII 식별자**여야 한다(`Object::set_meta` 검사).
		#   `_압력버튼_원래위치` 는 밑줄로 시작해서, 밑줄을 뗀 `압력버튼_원래위치` 는
		#   한글이라서 둘 다 거부됐다 — 씬을 열 때마다 "Invalid metadata identifier" 가
		#   뜨고 원래 위치가 한 번도 안 적혔다(하수도 2-2 · 2-7 에서 실제로 났다).
		대상.set_meta("pressure_button_origin", 대상.position)
		_대상_노드들.append(대상)
		_대상_시작위치들.append(대상.position)
		_대상_켜짐.append(false)


## i 번째 대상이 지금 나가 있어야 하나. 지연이 없으면 활성 그대로다(예전 동작).
func _대상_나감(i: int) -> bool:
	if 대상_지연들.is_empty() and 대상_꺼짐_지연들.is_empty():
		return _활성
	# 꺼짐 지연을 따로 준 대상은 그 값만 본다(켜짐 쪽은 아래 예전 규칙 그대로).
	if not _활성 and i < 대상_꺼짐_지연들.size():
		if _전환_경과 >= 대상_꺼짐_지연들[i]:
			_대상_켜짐[i] = false
		return _대상_켜짐[i]
	var 지연 := 대상_지연들[i] if i < 대상_지연들.size() else 0.0
	var 최대 := 0.0
	for v in 대상_지연들:
		최대 = maxf(최대, v)
	if _활성 and _전환_경과 >= 지연:
		_대상_켜짐[i] = true
	elif not _활성 and _전환_경과 >= 최대 - 지연:
		_대상_켜짐[i] = false
	return _대상_켜짐[i]


func _대상_이동(delta: float) -> void:
	for i in _대상_노드들.size():
		var 대상 := _대상_노드들[i]
		if not is_instance_valid(대상):
			continue
		var 이동량 := 대상_이동량들[i] if i < 대상_이동량들.size() else Vector2.ZERO
		var 목표 := _대상_시작위치들[i] + (이동량 if _대상_나감(i) else Vector2.ZERO)
		# 물리 프레임에서 Node2D를 움직여 SS2D 자식 충돌도 그림과 같은 위치로 갱신한다.
		# ★[2026-09-30 Claude 실측] 이미 목표에 있으면 **대입하지 않는다.** 같은 값을 넣어도 Godot 는
		#   TRANSFORM_CHANGED 를 보내고, 하수도 지형은 그걸 받아 이웃 지형 전부에 마감 재계산을 퍼뜨렸다
		#   (2-9: 매 틱 지형 27 개 재계산 → 스크립트만 평균 6.7ms · 순간 19ms → 60FPS 미만).
		var 새위치 := 대상.position.move_toward(목표, 이동속도 * delta)
		if 새위치 != 대상.position:
			대상.position = 새위치
		if 숨는_자리 >= 0:
			# 숨는 자리(벽 속)에 다 들어가 있으면 감춘다 — 값이 바뀔 때만 대입한다.
			var 숨을곳 := _대상_시작위치들[i] + (이동량 if 숨는_자리 == 1 else Vector2.ZERO)
			var 보임 := 대상.position != 숨을곳
			if 대상.visible != 보임:
				대상.visible = 보임


func _누를_수_있는_몸이_올라섰나() -> bool:
	if _감지 == null:
		return false
	for 몸 in _감지.get_overlapping_bodies():
		for 그룹 in 누름_가능_그룹:
			if not 몸.is_in_group(그룹):
				continue
			# 양동이는 물을 실어야만 무게추가 된다. 빈 양동이까지 버튼을 누르면
			# "물을 채워 무게를 남긴다"는 퍼즐 규칙이 사라진다.
			if 그룹 == "양동이" and not bool(몸.get("물참")):
				continue
			return true
	return false


## 이 버튼의 현재 유지형/순간형 활성 상태를 다른 버튼이 읽는 안전한 공개 창구다.
func 활성인가() -> bool:
	return _활성


func _동시_버튼도_눌렸나() -> bool:
	for 경로 in 동시_버튼들:
		var 다른버튼 := get_node_or_null(경로)
		if 다른버튼 == null or not 다른버튼.has_method("활성인가"):
			return false
		if not bool(다른버튼.call("활성인가")):
			return false
	return true


func _재구성() -> void:
	if not is_inside_tree():
		return
	# Area2D는 누름만 감지하고, 별도 StaticBody2D가 실제로 밟을 수 있는 단단한 윗면이 된다.
	if _감지 == null:
		_감지 = get_node_or_null("누름감지") as Area2D
	if _감지 == null:
		_감지 = Area2D.new()
		_감지.name = "누름감지"
		add_child(_감지)
		_편집기_주인_지정(_감지)
	_감지.collision_layer = 0
	_감지.collision_mask = 1
	_감지.monitoring = true
	var 감지모양 := _감지.get_node_or_null("모양") as CollisionShape2D
	if 감지모양 == null:
		감지모양 = CollisionShape2D.new()
		감지모양.name = "모양"
		감지모양.visible = false
		_감지.add_child(감지모양)
		_편집기_주인_지정(감지모양)
	var 감지사각 := 감지모양.shape as RectangleShape2D
	if 감지사각 == null:
		감지사각 = RectangleShape2D.new()
		감지모양.shape = 감지사각
	감지사각.size = Vector2(폭 * 0.86, 감지_높이)
	감지모양.position = Vector2(0, -높이 * 0.5 - 감지_높이 * 0.5 + 4.0)

	var 발판 := get_node_or_null("밟는면") as StaticBody2D
	if 발판 == null:
		발판 = StaticBody2D.new()
		발판.name = "밟는면"
		add_child(발판)
		_편집기_주인_지정(발판)
	발판.collision_layer = 1 if 밟는면_충돌 else 0
	발판.collision_mask = 0
	var 발판모양 := 발판.get_node_or_null("모양") as CollisionShape2D
	if 발판모양 == null:
		발판모양 = CollisionShape2D.new()
		발판모양.name = "모양"
		발판모양.visible = false
		발판.add_child(발판모양)
		_편집기_주인_지정(발판모양)
	var 발판사각 := 발판모양.shape as RectangleShape2D
	if 발판사각 == null:
		발판사각 = RectangleShape2D.new()
		발판모양.shape = 발판사각
	발판사각.size = Vector2(폭, 높이)
	발판모양.position = Vector2(0, -높이 * 0.5)
	queue_redraw()


func _편집기_주인_지정(노드: Node) -> void:
	# 새로 만든 보조 노드에만 owner를 준다. 읽어 온 SS2D 노드는 절대 다시 소유하지 않는다.
	# 씬 로딩 중 export setter가 먼저 호출될 수 있어 트리 진입 전에 get_tree()를 호출하지 않는다.
	if Engine.is_editor_hint() and is_inside_tree():
		노드.owner = get_tree().edited_scene_root


func _draw() -> void:
	# [2026-10-10 병합] 쳅터1 바닥 철판(생김새 1 · Claude 10-09)과 원근 그림(챕터1_원근 · 팀 10-10)은 서로 다른 버튼이 쓴다 — 둘 다 둔다.
	if 생김새 == 1:
		_쳅터1_철판_그리기()
		return
	_원근_그림준비 = false
	if 챕터1_원근:
		# 면별 평면 원본을 투영해 대칭 원근을 제거하고, 상판만 누르므로 고정 프레임과 돌 접합은 남는다.
		원근_그림.압력_그리기(self, 폭, 높이, _눌림_표현, _활성)
		_원근_그림준비 = true
		return
	# 충돌/감지는 보존하고 최대 3px의 시각적 스트로크만 아래로 눌러 기존 점프 거리를 유지한다.
	var 눌림 := _눌림_표현 * minf(3.0, 높이 * 0.125)
	draw_texture_rect_region(주철_부품, Rect2(-폭 * 0.5, -높이 * 0.55, 폭, 높이 * 0.55), Rect2(28, 425, 570, 72))
	draw_texture_rect_region(주철_부품, Rect2(-폭 * 0.455, -높이 + 눌림, 폭 * 0.91, 높이 * 0.55), Rect2(679, 395, 520, 89))
	# 표시창은 실제 출력 활성 상태, 상판은 실제 무게를 표시해 유지형 버튼도 구분한다.
	if _활성:
		draw_rect(Rect2(-폭 * 0.12, -높이 * 0.31, 폭 * 0.24, maxf(1.5, 높이 * 0.09)), Color(0.87, 0.87, 0.85))


## [2026-10-09] 쳅터1 바닥 위 철판 — 레버 원화(낡은 철판 · 리벳)와 같은 재질을 2.5D 윗면 위에 눕힌 모양으로.
##   올라온 두께 10px → 누르면 2px(윗면에 박힌 듯). 앞면(아래 그늘 띠) · 윗면 밝은 테 · 리벳 넷 · 가운데 홈(켜지면 밝게).
func _쳅터1_철판_그리기() -> void:
	var 두께 := lerpf(10.0, 2.0, _눌림_표현)
	var 바닥 := 그림_깊이                       # 2.5D 윗면 가운데
	var 왼 := -폭 * 0.5
	var 위 := 바닥 - 두께
	var 쇠 := Color(0.20, 0.20, 0.19)
	var 쇠밝 := Color(0.42, 0.41, 0.39)
	var 그늘 := Color(0.0, 0.0, 0.0, 0.45)
	draw_rect(Rect2(왼 + 3, 바닥 - 1, 폭, 4), 그늘)                                   # 바닥에 드리운 그늘
	draw_rect(Rect2(왼, 위, 폭, 두께), 쇠)                                            # 앞면
	draw_rect(Rect2(왼 + 2, 위 - 5, 폭 - 4, 6), 쇠밝.darkened(0.15))                   # 윗면(눕힌 판)
	draw_line(Vector2(왼 + 2, 위 - 5), Vector2(왼 + 폭 - 2, 위 - 5), 쇠밝, 1.5)        # 윗면 테
	for fx in [0.08, 0.92]:
		draw_circle(Vector2(왼 + 폭 * fx, 위 - 2), 2.2, 쇠밝)
		draw_circle(Vector2(왼 + 폭 * fx + 0.6, 위 - 1.4), 1.0, Color(0.1, 0.1, 0.1))
	# 가운데 홈 — 켜지면(무게가 있으면) 밝게 — 레버 판의 켬 표시와 같은 말
	var 홈 := Color(0.88, 0.86, 0.80) if _활성 else Color(0.08, 0.08, 0.08)
	draw_rect(Rect2(-폭 * 0.14, 위 - 3.5, 폭 * 0.28, 2.5), 홈)
