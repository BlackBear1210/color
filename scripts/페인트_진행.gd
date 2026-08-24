extends RefCounted
## 흑·백 부분 색칠의 횟수와 자동 회수 시간만 맡는 공용 규칙.
## 대상의 그림과 최종 상태는 각 지형이 소유하고, 여기서는 두 색이 섞여 회색이 되지 않게 분리한다.

var 유지시간: float = 4.0
var 감쇠시간: float = 1.0

var _횟수: Array[int] = [0, 0]
var _경과: Array[float] = [0.0, 0.0]


func 명중(색: int, 필요: int) -> bool:
	if 색 < ColorDefs.BLACK or 색 > ColorDefs.WHITE:
		return false
	_횟수[색] += 1
	_경과[색] = 0.0
	return 완성가능(색, 필요)


func 완성가능(색: int, 필요: int) -> bool:
	return 횟수(색) >= maxi(필요, 1) and 횟수(_반대(색)) == 0


## 반환값: { "만료": {색: 발수}, "완성색": -1 또는 색 }.
func 진행(delta: float, 필요: int) -> Dictionary:
	var 만료 := {}
	for 색 in 2:
		if _횟수[색] <= 0:
			continue
		_경과[색] += delta
		if _경과[색] >= 유지시간 + 감쇠시간:
			만료[색] = _횟수[색]
			_횟수[색] = 0
			_경과[색] = 0.0
	var 완성색 := -1
	for 색 in 2:
		if 완성가능(색, 필요):
			완성색 = 색
			break
	return { "만료": 만료, "완성색": 완성색 }


func 알파(색: int) -> float:
	if 횟수(색) <= 0:
		return 0.0
	if _경과[색] <= 유지시간:
		return 1.0
	return clampf(1.0 - (_경과[색] - 유지시간) / 감쇠시간, 0.0, 1.0)


func 횟수(색: int) -> int:
	return _횟수[색] if 색 >= ColorDefs.BLACK and 색 <= ColorDefs.WHITE else 0


func 전체횟수() -> int:
	return _횟수[ColorDefs.BLACK] + _횟수[ColorDefs.WHITE]


func 남은횟수(색: int, 필요: int) -> int:
	return maxi(maxi(필요, 1) - 횟수(색), 0)


func 비우기() -> void:
	_횟수 = [0, 0]
	_경과 = [0.0, 0.0]


func _반대(색: int) -> int:
	return ColorDefs.WHITE if 색 == ColorDefs.BLACK else ColorDefs.BLACK
