extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 레버 퍼즐 — 레버 N 개 + 빗장 손잡이 + (틀리면) 샹들리에 함정 + (맞으면) 비밀문·카메라 비추기·양초 시계
## ----------------------------------------------------------------------------
## ▣ 도형님 아이디어(10-09) — 마인크래프트식: "레버를 3 개 정도 깔아 두고 각각 작동시켜서 원하는 레버를 켰다 껐다 하다가
##   잘못된 패턴일 때 함정이 발동 … 샹들리에가 떨어진다 … 시간초 … 특별 스테이지로 가는 통로를 카메라 무빙으로 비추어 준 다음
##   닫힌 통로의 길을 열어 준다."
## ▣ 흐름
##   1) 레버를 E 로 켰다 껐다 한다(아무 일도 일어나지 않는다 — 고민할 시간).
##   2) 빗장 손잡이를 당긴다 → 판정.
##      · 틀림: 레버가 잠기고 머리 위 샹들리에가 0.6초 예고 뒤 떨어진다(맞으면 즉사). 샹들리에가 돌아가면(부활 또는
##        피했을 때 2.5초) 레버가 모두 꺼진 상태로 풀린다 → 다시 시도.
##      · 맞음: 레버가 잠기고(정답 상태로 고정) 플레이어 조작을 잠깐 묶은 채 **카메라가 비밀문을 비춘다** →
##        비추는 한가운데에서 비밀문이 열린다 → 카메라가 돌아온다. `제한시간` 이 있으면 타이머 양초가 켜지고,
##        다 타면 비밀문이 닫히고 퍼즐이 처음으로 돌아간다(단, 한 번 지나간 비밀문은 영구 열림 — 비밀문.gd).
##   3) 죽어 부활하면(월드 `_리스폰` → "부활복구" 그룹): 아직 풀지 않았거나 비밀문을 지나가지 않았으면 처음으로 되감는다.
## ▣ 노드: 자식 또는 NodePath 로 레버들 · 손잡이 · 샹들리에 · 비밀문(여러 개 가능) · 양초 · 비출_점(Marker2D)을 잇는다.
##   쳅터1 도안 {"종류": "레버퍼즐", …} → 생성기(tools/쳅터1/기믹.py · 추가기믹.py)가 이 묶음을 통째로 만든다.
## ============================================================================

@export var 레버들: Array[NodePath] = []
@export var 손잡이: NodePath
@export var 정답: Array[bool] = [true, false, true]
@export var 샹들리에: NodePath
@export var 열것들: Array[NodePath] = []
@export var 양초: NodePath
@export var 비출_점: NodePath
## 0 = 한 번 열면 계속 열림. > 0 = 양초가 다 타면(초) 다시 닫힌다.
@export var 제한시간: float = 0.0

signal 풀림
signal 틀림

var 풀었나 := false
var _레버: Array = []
var _바쁨 := false


func _ready() -> void:
	add_to_group("부활복구")
	add_to_group("레버퍼즐")
	for 경로 in 레버들:
		var l := get_node_or_null(경로)
		if l:
			_레버.append(l)
	var h := get_node_or_null(손잡이)
	if h and h.has_signal("당겨짐"):
		h.당겨짐.connect(func(_n): _확인())
	var 샹 := get_node_or_null(샹들리에)
	if 샹 and 샹.has_signal("끝남"):
		샹.끝남.connect(_되감기)
	var 초 := get_node_or_null(양초)
	if 초 and 초.has_signal("다탐"):
		초.다탐.connect(_시간끝)


func 지금_패턴() -> Array:
	var r := []
	for l in _레버:
		r.append(bool(l.get("켜짐")))
	return r


func _확인() -> void:
	if _바쁨 or 풀었나:
		return
	if _같나(지금_패턴(), 정답):
		_맞음()
	else:
		_틀림()


## 원소별 비교 — 타입 있는 배열(Array[bool])과 일반 배열을 == 로 비교하면 타입 때문에 다르게 나올 수 있다
func _같나(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if bool(a[i]) != bool(b[i]):
			return false
	return true


func _잠그기(잠김: bool) -> void:
	for l in _레버:
		l.set("잠김", 잠김)
	var h := get_node_or_null(손잡이)
	if h:
		h.set("잠김", 잠김)


func _틀림() -> void:
	_바쁨 = true
	_잠그기(true)
	틀림.emit()
	var 샹 := get_node_or_null(샹들리에)
	if 샹 and 샹.has_method("떨어뜨리기"):
		샹.call("떨어뜨리기")
	else:
		_되감기()


func _맞음() -> void:
	_바쁨 = true
	풀었나 = true
	_잠그기(true)
	풀림.emit()
	var 카메라 := get_tree().get_first_node_in_group("주카메라")
	var 목표 := get_node_or_null(비출_점) as Node2D
	var 문들 := []
	for 경로 in 열것들:
		var n := get_node_or_null(경로)
		if n:
			문들.append(n)
	if 목표 == null and not 문들.is_empty():
		목표 = 문들[0] as Node2D
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var 걸림 := 0.0
	if 카메라 and 카메라.has_method("비추기") and 목표:
		# 조작을 묶는다 — 비추는 동안 몸이 미끄러지거나 떨어지지 않게(바닥에 선 채 퍼즐을 푼다)
		if p:
			p.velocity = Vector2.ZERO
			p.set_physics_process(false)
		걸림 = float(카메라.call("비추기", 목표.global_position + Vector2(0, -150), 1.4, 0.9, 0.7))
		await get_tree().create_timer(0.9 + 0.2, false).timeout       # 화면이 도착한 뒤 문이 열린다
	for n in 문들:
		if n.has_method("열기"):
			n.call("열기")
	var 초 := get_node_or_null(양초)
	if 제한시간 > 0.0 and 초 and 초.has_method("켜기"):
		초.call("켜기", 제한시간)
	if 걸림 > 0.0:
		await get_tree().create_timer(maxf(걸림 - 1.1, 0.1), false).timeout
	if p and is_instance_valid(p):
		p.set_physics_process(true)
	_바쁨 = false


## 샹들리에가 다시 매달렸다(부활·스스로 복구) → 레버를 모두 끄고 풀어 준다.
func _되감기() -> void:
	if 풀었나:
		return
	for l in _레버:
		l.set("켜짐", false)
	_잠그기(false)
	_바쁨 = false


func _시간끝() -> void:
	# 양초가 다 탔다 — 비밀문을 닫고 처음으로(한 번 지나간 문은 안 닫힌다 · 비밀문.gd 영구)
	var 지나감 := false
	for 경로 in 열것들:
		var n := get_node_or_null(경로)
		if n and bool(n.get("영구")):
			지나감 = true
		elif n and n.has_method("닫기"):
			n.call("닫기")
	if 지나감:
		return
	풀었나 = false
	_되감기()


## 월드 `_리스폰` — 죽으면 퍼즐도 되감는다(이미 비밀문을 지나간 뒤라면 그대로 둔다).
func 부활_복구() -> void:
	for 경로 in 열것들:
		var n := get_node_or_null(경로)
		if n and bool(n.get("영구")):
			return
	if 풀었나:
		풀었나 = false
		var 초 := get_node_or_null(양초)
		if 초 and 초.has_method("끄기"):
			초.call("끄기")
		for 경로 in 열것들:
			var n := get_node_or_null(경로)
			if n and n.has_method("닫기"):
				n.call("닫기")
	_되감기()
