extends CanvasLayer
## ============================================================================
## [2026-10-04 신규 · Claude · 같은 날 2차 수정] 전경 전환 — 연결구를 지나 다음 스테이지로
## ----------------------------------------------------------------------------
## ▣ 도형님 지시(2차): "어두운 벽이 너무 두껍지 않게 만들고, 들어가면 카메라를 줌인해서 가깝게 했다가
##   다음 스테이지에서 자동으로 걸어 나오며 천천히 줌아웃을 하자."
##   → 1차의 "화면 전체를 가로지르는 두꺼운 벽" 을 버리고 **줌인 + 가장자리 어둠 + 짧은 암전** 으로 바꿨다.
##
## ▣ 흐름 (연결구가 부른다) — 시간은 아래 상수
##   ① 들어감  : 조작 잠금 · 자동으로 바깥쪽으로 걷는다 · 카메라 줌인(1.0 → 1.35) · 비네트 조임
##               끝 무렵 잠깐 어두워진다(가까운 전경 띠 속으로 들어가 시야가 막히는 느낌)
##   ② 교체    : 화면이 어두운 순간에 스테이지를 바꾼다. 떠나는 스테이지는 **지우지 않고 보관**(최대 3)
##   ③ 나옴    : 새 스테이지는 줌인된 채(1.35) 밝아지고, 도착 길목에서 자동으로 걸어 나온다
##               → 방 안 2칸에서 조작을 돌려주고, 카메라는 **천천히** 1.0 으로 풀린다(1.8초)
##
## ▣ 되돌아가기 = "전경 통과 전으로 돌아간다"
##   보관된 스테이지로 돌아가면 떠날 때 그대로다(칠한 페인트·체크포인트 유지). 그 길목 앞에서 걸어 나온다.
##
## ▣ 기존 `장면전환.gd`(통로 암전)와 별개 — `월드.gd` 는 둘 중 하나라도 진행 중이면 사망 판정을 멈춘다.
## ============================================================================

const 줌_최대 := 1.35          ## 들어갈 때 이만큼 확대(ProtoCamera.연출_줌배수 — 다른 줌과 곱해진다)
const 들어감_시간 := 0.55      ## 줌인·걷기 시간 — 걸음 약 215px, 길목 굴(384px) 안에서 끝난다
const 암전_시작 := 0.30        ## 들어감 중 이 시점부터 어두워지기 시작
const 암전_길이 := 0.25        ## 0.30~0.55 사이에 완전히 어두워진다(짧게 — 두꺼운 벽 느낌 없이)
const 밝아짐_시간 := 0.35
const 줌아웃_시간 := 1.8       ## "천천히 줌아웃"
const 걸어나오기_최대 := 1.6   ## 자동 걷기 안전 상한(초)
const 보관_최대 := 3
const 어둠색 := Color(0.02, 0.019, 0.018, 1.0)

static var _진행중: bool = false
static var _보관: Dictionary = {}          ## 씬 경로 → 트리에서 떼어 둔 스테이지 루트
static var _보관순서: Array = []
## 마지막으로 이 전환이 세운 씬. 지금 씬이 이것과 다르면(로비·다시 시작·스테이지 선택으로 바뀜)
## 보관해 둔 스테이지는 낡은 것이므로 다음 전환 때 버린다.
static var _마지막씬: Node = null

var _판: ColorRect = null


static func 진행중인가() -> bool:
	return _진행중


## 연결구가 부른다.
static func 연결로_이동(연결: Node2D, 플레이어: CharacterBody2D) -> void:
	if _진행중 or 플레이어 == null:
		return
	if not is_instance_valid(_마지막씬) or _마지막씬 != 연결.get_tree().current_scene:
		보관_비우기()
	var 경로: String = 연결.get("다음_씬")
	if not _보관.has(경로) and not ResourceLoader.exists(경로):
		push_error("전경전환: 다음 씬이 없다 → %s" % 경로)
		return
	_진행중 = true
	var 판: CanvasLayer = load("res://scripts/쳅터1/전경전환.gd").new()
	연결.get_tree().root.add_child(판)
	판.call("_진행", 연결, 플레이어)


## 보관한 스테이지를 모두 버린다.
static func 보관_비우기() -> void:
	for k in _보관:
		var n: Node = _보관[k]
		if is_instance_valid(n):
			n.queue_free()
	_보관.clear()
	_보관순서.clear()


func _init() -> void:
	layer = 190                       # 일시정지 메뉴(100) 위, 장면전환(200) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_판 = ColorRect.new()
	_판.name = "암전"
	_판.color = Color(어둠색.r, 어둠색.g, 어둠색.b, 0.0)
	_판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_판.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_판)


static func _카메라(씬: Node) -> Node:
	return 씬.get_node_or_null("카메라") if 씬 else null


func _진행(연결: Node2D, 플레이어: CharacterBody2D) -> void:
	var 트리 := get_tree()
	var 방향: float = float(연결.get("방향"))
	var 경로: String = 연결.get("다음_씬")
	var 다음_연결: String = 연결.get("다음_연결")
	var 옛씬 := 트리.current_scene

	# ① 들어감 — 걷기 · 줌인 · 비네트 · 끝 무렵 짧은 암전
	플레이어.set("자동_걷기", 방향)
	var 캠 := _카메라(옛씬)
	if 캠:
		var tz := create_tween()
		tz.tween_property(캠, "연출_줌배수", 줌_최대, 들어감_시간).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if 캠.has_method("비네트_강도"):
			캠.call("비네트_강도", 0.8, 들어감_시간)
	var ta := create_tween()
	ta.tween_interval(암전_시작)
	ta.tween_property(_판, "color:a", 1.0, 암전_길이).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ta.finished

	# ② 교체
	플레이어.set("자동_걷기", 0.0)
	플레이어.velocity = Vector2.ZERO
	if 캠:
		캠.set("연출_줌배수", 1.0)               # 보관했다 돌아왔을 때 줌인된 채로 남지 않게
		if 캠.has_method("비네트_강도") and 캠.has_method("비네트_기본값"):
			캠.call("비네트_강도", 캠.call("비네트_기본값"), 0.0)
	var 새씬: Node = null
	if _보관.has(경로) and is_instance_valid(_보관[경로]):
		새씬 = _보관[경로]
		_보관.erase(경로)
		_보관순서.erase(경로)
	else:
		새씬 = (load(경로) as PackedScene).instantiate()
	if 옛씬:
		_보관하기(옛씬.scene_file_path, 옛씬)
		트리.root.remove_child(옛씬)
	트리.root.add_child(새씬)
	트리.current_scene = 새씬
	_마지막씬 = 새씬
	await 트리.process_frame
	await 트리.physics_frame

	# 하수도처럼 연결구 계약이 없는 씬은 빈 이름으로 검색하지 않고 기본 시작점을 쓴다.
	var 도착 := 새씬.find_child(다음_연결, true, false) as Node2D if not 다음_연결.is_empty() else null
	var 새플레이어 := 새씬.get_node_or_null("Player") as CharacterBody2D
	var 안쪽 := Vector2.ZERO
	var 안쪽방향 := -방향
	if 도착 and 새플레이어:
		안쪽방향 = -float(도착.get("방향"))
		안쪽 = 도착.call("안쪽_위치")
		도착.call("도착시킴")
		if 새씬.has_method("연결_도착"):
			새씬.call("연결_도착", 도착.call("도착_위치"), 안쪽)
		else:
			새플레이어.global_position = 도착.call("도착_위치")
		새플레이어.set("자동_걷기", 안쪽방향)
	elif not 다음_연결.is_empty():
		push_warning("전경전환: 도착 연결구 '%s' 또는 Player 를 못 찾음 — 씬 기본 시작 위치" % 다음_연결)

	# ③ 나옴 — 줌인된 채 밝아지고, 걸어 나오며 천천히 줌아웃
	var 새캠 := _카메라(새씬)
	if 새캠:
		새캠.set("연출_줌배수", 줌_최대)
		# ⚠ 이 트윈은 카메라에 묶는다 — 전환 판(self)은 조작을 돌려준 뒤 곧 사라지므로
		#   판에 묶으면 1.8초짜리 줌아웃이 도중에 끊긴다.
		var tz2 := (새캠 as Node).create_tween()
		tz2.tween_property(새캠, "연출_줌배수", 1.0, 줌아웃_시간).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if 새캠.has_method("비네트_강도") and 새캠.has_method("비네트_기본값"):
			새캠.call("비네트_강도", 0.8, 0.0)
			새캠.call("비네트_강도", 새캠.call("비네트_기본값"), 줌아웃_시간)
	var tb := create_tween()
	tb.tween_property(_판, "color:a", 0.0, 밝아짐_시간).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var 남은 := 걸어나오기_최대
	while 새플레이어 and 남은 > 0.0:
		if (새플레이어.global_position.x - 안쪽.x) * 안쪽방향 >= 0.0:
			break
		await 트리.physics_frame
		남은 -= 1.0 / 60.0
	if 새플레이어:
		새플레이어.set("자동_걷기", 0.0)
	if tb.is_running():
		await tb.finished
	_진행중 = false          # 조작은 돌려주고, 줌아웃 트윈은 카메라 쪽에서 계속 흐른다
	queue_free()


func _보관하기(경로: String, 씬: Node) -> void:
	if 경로.is_empty():
		씬.queue_free()
		return
	if _보관.has(경로) and is_instance_valid(_보관[경로]) and _보관[경로] != 씬:
		(_보관[경로] as Node).queue_free()
	_보관[경로] = 씬
	_보관순서.erase(경로)
	_보관순서.append(경로)
	while _보관순서.size() > 보관_최대:
		var 옛: String = _보관순서.pop_front()
		var n: Node = _보관.get(옛)
		_보관.erase(옛)
		if is_instance_valid(n):
			n.queue_free()
