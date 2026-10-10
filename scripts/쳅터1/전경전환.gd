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


## 연결구(쳅터1)와 연결통로(쳅터2 하수도)가 부른다.
## ★[2026-10-08 Claude] 도형님 "쳅터2(world_2_클로드)도 쳅터1 스테이지 전환 방식으로 전부 전환".
##   하수도 씬 파일은 그대로 두고, 하수도 통로(`연결통로.gd`)가 옛 암전(`장면전환`) 대신 이 함수를 부른다.
##   두 노드는 이름이 조금 다르다 — 방향(연결구 = 변수 / 연결통로 = 함수) · 도착 이름(다음_연결 / 다음_진입점).
##   ⚠ 하수도 통로는 되돌아가는 길이 없으므로 떠나는 스테이지를 보관하지 않고 버린다(메모리 · 낡은 상태 방지).
static func 연결로_이동(연결: Node2D, 플레이어: CharacterBody2D) -> void:
	if _진행중 or 플레이어 == null:
		return
	if not is_instance_valid(_마지막씬) or _마지막씬 != 연결.get_tree().current_scene:
		보관_비우기()
	# 하수도 입구 통로는 목적지가 씬에 없고 도착 때 적힌다 → `전환_씬()` 으로 묻는다.
	var 경로: String = String(연결.call("전환_씬")) if 연결.has_method("전환_씬") else String(연결.get("다음_씬"))
	var 도착이름: String = String(연결.call("전환_진입점")) if 연결.has_method("전환_진입점") else _도착이름(연결)
	var 지금 := 연결.get_tree().current_scene
	var 지금경로 := 지금.scene_file_path if 지금 else ""
	# 쳅터2 지도에서 들어온 하수도 스테이지면 출구 = 클리어 기록 → 실제 다음 씬으로(장면전환 이 하던 가로채기를 여기서도).
	#   ⚠ 뒤로 가는 길(입구 통로)은 클리어가 아니다 — 가로채지 않는다.
	var 뒤로: bool = 연결.has_method("되돌아가는_길인가") and bool(연결.call("되돌아가는_길인가"))
	if not 뒤로:
		var 가로챈 := 게임진행.통로_가로채기(지금경로, 경로)
		# 하수도도 선택창으로 보내지 않고 완료 신호만 남겨 사진·시간·사망 기록을 저장한다.
		if 지금경로.begins_with(게임진행.하수도_폴더) and 지금 and 지금.has_method("스테이지_완료") and 게임진행.기록해도_되나():
			지금.call("스테이지_완료")
		if 가로챈 != 경로:
			경로 = 가로챈
			# 옛 로비 출구를 뒤 하수도 맵으로 이을 때도 챕터1과 같은 입구 걷기 연출을 사용한다.
			도착이름 = "입구통로" if 경로.begins_with(게임진행.하수도_폴더) else ""
	# [2026-10-09 Claude] 쳅터1 퍼즐 보드 — 이 스테이지의 '출구'(앞으로 나가는 길목 · 퍼즐보드_쳅터1.json)면 클리어:
	#   진행 기록 + 월드.스테이지_완료(실행 기록 = 시간·사망 · 스냅 = 사진) · 15 출구면 쳅터1 클리어.
	#   선택창에서 들어와도 다음 씬으로 이어진다. 도장은 선택창을 직접 열 때만 보여 준다.
	#   ⚠ 되돌아가는 길목 · 비밀 길목(17 → 18)은 출구가 아니라 그대로 지나간다.
	var 보드표 = load("res://scripts/진행/쳅터1_보드표.gd")
	if 지금 and 보드표.출구인가(지금경로, String(연결.name)):
		게임진행.쳅터1_클리어_기록(지금경로)
		if 지금.has_method("스테이지_완료") and 게임진행.기록해도_되나():     # 시험 실행이면 시간·사망 기록 파일도 안 건드린다
			지금.call("스테이지_완료")
		var 조각: Dictionary = 보드표.경로로_찾기(지금경로)
		if bool(조각.get("쳅터_끝", false)):
			게임진행.쳅터_클리어(1)
		# [2026-10-09 Codex] 클리어 연출은 선택창을 직접 열 때만 재생한다. 걸어 나가는 실제 다음 씬/도착점은 유지한다.
		게임진행.마지막_조각 = String(조각.get("id", ""))
	if not _보관.has(경로) and not ResourceLoader.exists(경로):
		push_error("전경전환: 다음 씬이 없다 → %s" % 경로)
		return
	_진행중 = true
	var 판: CanvasLayer = load("res://scripts/쳅터1/전경전환.gd").new()
	연결.get_tree().root.add_child(판)
	# 떠나는 스테이지를 보관해야 되돌아왔을 때 떠날 때 그대로다(칠한 페인트·체크포인트).
	#   연결구는 되돌아가기 켠 것만 · 하수도 통로는 언제나 · 지도로 갈 때만 버린다(지도에서 다시 들어오면 새로 시작).
	var 보관함: bool = 경로 != 게임진행.지도_씬 and 경로 != 게임진행.보드_씬 and (연결.get("되돌아가기") == true or 연결.has_method("전환_씬"))
	판.call("_진행", 연결, 플레이어, 경로, 도착이름, 보관함, 지금경로, String(연결.name))


## [2026-10-08] 걸어 들어가는 연결 없이 다른 화면(쳅터2 지도)에서 스테이지로 들어갈 때.
##   짧게 어두워졌다가 → 도착 통로 안에서 걸어 나오며 천천히 줌아웃(연결구로 도착한 것과 같은 그림).
static func 씬으로_들어가기(from: Node, 경로: String, 도착이름: String) -> void:
	if _진행중 or not ResourceLoader.exists(경로):
		return
	보관_비우기()
	_진행중 = true
	var 판: CanvasLayer = load("res://scripts/쳅터1/전경전환.gd").new()
	from.get_tree().root.add_child(판)
	var 떠난 := from.get_tree().current_scene
	판.call("_들어가기", 경로, 도착이름, 떠난.scene_file_path if 떠난 else "")


## 연결구는 `방향` 변수, 연결통로는 `방향()` 함수다.
static func _방향값(연결: Node) -> float:
	return float(연결.call("방향")) if 연결.has_method("방향") else float(연결.get("방향"))


## 연결구는 `다음_연결`, 연결통로는 `다음_진입점`.
static func _도착이름(연결: Node) -> String:
	var v: Variant = 연결.get("다음_연결")
	if v == null:
		v = 연결.get("다음_진입점")
	return String(v) if v != null else ""


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


func _진행(연결: Node2D, 플레이어: CharacterBody2D, 경로: String, 다음_연결: String, 보관함: bool,
		떠난씬: String, 떠난길목: String) -> void:
	var 트리 := get_tree()
	var 방향: float = _방향값(연결)
	var 옛씬 := 트리.current_scene

	# ① 들어감 — 걷기 · 줌인 · 비네트 · 끝 무렵 짧은 암전
	# 복도 옆방 문은 화면 안의 출입구다. 옆으로 걸으면 발판 밖으로 나가므로 제자리에서 암전한다.
	플레이어.set("자동_걷기", 0.0 if 연결.has_method("옆방_문인가") else 방향)
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
	await _교체와_나옴(경로, 다음_연결, 방향, 보관함, 떠난씬, 떠난길목)


## 화면이 다 어두워진 뒤 — 스테이지를 바꾸고 도착 길목에서 걸어 나온다(연결구 · 연결통로 · 지도 입장 공통).
##   떠난씬·떠난길목 = 도착한 하수도 입구 통로에 "되돌아갈 곳" 으로 적어 준다(왕복).
func _교체와_나옴(경로: String, 다음_연결: String, 방향: float, 보관함: bool,
		떠난씬: String = "", 떠난길목: String = "") -> void:
	var 트리 := get_tree()
	var 옛씬 := 트리.current_scene
	var 새씬: Node = null
	if _보관.has(경로) and is_instance_valid(_보관[경로]):
		새씬 = _보관[경로]
		_보관.erase(경로)
		_보관순서.erase(경로)
	else:
		새씬 = (load(경로) as PackedScene).instantiate()
	if 옛씬:
		트리.root.remove_child(옛씬)
		if 보관함:
			_보관하기(옛씬.scene_file_path, 옛씬)
		else:
			옛씬.queue_free()
	트리.root.add_child(새씬)
	트리.current_scene = 새씬
	_마지막씬 = 새씬
	await 트리.process_frame
	await 트리.physics_frame

	# 하수도처럼 연결구 계약이 없는 씬은 빈 이름으로 검색하지 않고 기본 시작점을 쓴다.
	var 도착 := 새씬.find_child(다음_연결, true, false) as Node2D if not 다음_연결.is_empty() else null
	# [2026-10-08] 도착 이름이 비어 있어도(쳅터1 15 → 하수도 2-1 처럼 연결구에 이름을 안 적은 경우)
	#   하수도 스테이지면 입구 통로로 들어온다 — 그래야 걸어 나오고 되돌아갈 수 있다.
	if 도착 == null and 다음_연결.is_empty():
		var 입구 := 새씬.find_child("입구통로", true, false) as Node2D
		if 입구 and 입구.has_method("되돌아갈_곳"):
			도착 = 입구
	if 도착 and 도착.has_method("되돌아갈_곳") and not 떠난씬.is_empty():
		도착.call("되돌아갈_곳", 떠난씬, 떠난길목)
	var 새플레이어 := 새씬.get_node_or_null("Player") as CharacterBody2D
	var 안쪽 := Vector2.ZERO
	var 안쪽방향 := -방향
	if 도착 and 새플레이어:
		안쪽방향 = -_방향값(도착)
		안쪽 = 도착.call("안쪽_위치")
		도착.call("도착시킴")
		if 새씬.has_method("연결_도착"):
			새씬.call("연결_도착", 도착.call("도착_위치"), 안쪽)
		else:
			새플레이어.global_position = 도착.call("도착_위치")
		새플레이어.set("자동_걷기", 안쪽방향)
	elif not 다음_연결.is_empty() and not 트리.get_nodes_in_group("연결구").is_empty():
		# 하수도 2-9~2-11 처럼 입구 통로가 없는 스테이지는 조용히 기본 시작 위치(경고는 쳅터1 연결구 실수만).
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
	# 도착 길목이 없으면(입구 통로 없는 하수도 2-9~2-11 · 지도 화면) 걸어 나올 곳이 없으니 기다리지 않는다.
	while 새플레이어 and 도착 and 남은 > 0.0:
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


## 지도 → 스테이지: 들어감 단계(걷기·줌인)는 없고 짧은 암전만.
func _들어가기(경로: String, 도착이름: String, 떠난씬: String) -> void:
	var ta := create_tween()
	ta.tween_property(_판, "color:a", 1.0, 암전_길이 + 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ta.finished
	# 지도에서 들어왔으면 입구 통로로 되돌아 나가면 지도로 간다(클리어 기록 없이).
	await _교체와_나옴(경로, 도착이름, 1.0, false, 떠난씬, "")


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
