extends Node
## ============================================================================
## [2026-07-24 도형 · 신규] 페인트 매니저 v3 (플랫폼 단위)
## ----------------------------------------------------------------------------
## paint_system.gd(v2, 타일맵 셀 단위)의 "회수 FIFO" 부분만 플랫폼 단위로 옮긴 것.
## 나머지(내구도·색별 부분 진행)는 각 PaintPlatform 이 스스로 들고 있으므로
## 여기는 **순수하게 '칠한 순서'만 기억**한다.
##
## ▣ 회수(E) 규칙 — v2 그대로 유지
##   · 색과 무관하게 "가장 먼저 칠한 플랫폼"부터 무색으로 되돌린다.
##   · 장애물 상호작용으로 회색이 된 플랫폼만 큐에서 빠진다.
##   · 회수는 자원 회수가 아니라 "칠한 길을 되돌리는 지형 조작 도구"다.
##
## ▣ 왜 별도 노드인가
##   플랫폼끼리는 서로를 몰라야 한다(독립적으로 드래그해 쓰는 부품이므로).
##   "순서"라는 전역 정보만 이 노드가 대신 들고 있어 결합도를 낮춘다.
## ============================================================================
class_name PaintManager

signal 상태변경                                   ## UI 갱신용 (칠한 수·다음 회수 대상)

var _큐: Array[PaintPlatform] = []                 ## 칠한 순서 (앞이 가장 오래된 것)
var _연결된: Array[PaintPlatform] = []

func _ready() -> void:
	연결_갱신()

## 씬 안의 모든 PaintPlatform 을 찾아 신호에 연결한다.
## 스테이지가 런타임에 플랫폼을 더 만들면 다시 호출하면 된다.
func 연결_갱신() -> void:
	for n in get_tree().get_nodes_in_group("paint_platform"):
		var p := n as PaintPlatform
		if p == null or _연결된.has(p):
			continue
		_연결된.append(p)
		p.칠해짐.connect(_칠해짐)
		p.회색됨.connect(_회색됨)
		p.되돌려짐.connect(_되돌려짐)

func _칠해짐(플랫폼: PaintPlatform, _색: int) -> void:
	if not _큐.has(플랫폼):
		_큐.append(플랫폼)
	상태변경.emit()

func _회색됨(플랫폼: PaintPlatform) -> void:
	_큐.erase(플랫폼)                               # 회색은 영구 → 회수 대상에서 제외
	상태변경.emit()

func _되돌려짐(플랫폼: PaintPlatform) -> void:
	_큐.erase(플랫폼)
	상태변경.emit()

## E 회수 — 가장 먼저 칠한 플랫폼을 무색으로. 되돌릴 게 없으면 false.
func 되돌리기() -> bool:
	while not _큐.is_empty():
		var p: PaintPlatform = _큐[0]
		if not is_instance_valid(p):
			_큐.remove_at(0)
			continue
		return p.되돌리기()                          # 되돌려짐 시그널이 큐에서 빼준다
	return false

## 다음에 회수될 플랫폼 (붓 커서 UI 의 파란 E 마커용). 없으면 null.
func 다음_회수_대상() -> PaintPlatform:
	for p in _큐:
		if is_instance_valid(p):
			return p
	return null

func 큐_크기() -> int:
	return _큐.size()

## 스테이지 클리어 판정 등에 쓰는 통계
func 통계() -> Dictionary:
	var 무색 := 0
	var 칠함 := 0
	var 회색 := 0
	for p in _연결된:
		if not is_instance_valid(p):
			continue
		match p.현재상태:
			PaintPlatform.상태.무색: 무색 += 1
			PaintPlatform.상태.회색: 회색 += 1
			_: 칠함 += 1
	return { "무색": 무색, "칠함": 칠함, "회색": 회색, "전체": _연결된.size() }
