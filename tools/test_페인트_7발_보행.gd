extends SceneTree
## 실행 허용 후 사용할 회귀 검사. 실제 코어와 보행 관성 모델을 검사하며 그림이나 엔진 캡처는 대체하지 않는다.
const 코어형 := preload("res://scripts/스마트월드/페인트_코어.gd")
const 관성형 := preload("res://scripts/ui/페인트_관성.gd")
var _실패: int = 0

func _init() -> void:
	call_deferred("_검사")

func _확인(조건: bool, 설명: String) -> void:
	if not 조건:
		_실패 += 1
		push_error(설명)

func _검사() -> void:
	var 코어 := 코어형.new()
	root.add_child(코어)
	_확인(코어.최대_탄약 == 7 and 코어.남은_탄약 == 7, "초기 용량은 7발이어야 한다")
	for i in range(7):
		_확인(코어.발사_소모(), "7번째 발까지 발사 가능")
		_확인(코어.남은_탄약 == 6 - i, "머리/HUD가 읽는 실제 잔량이 한 발씩 감소")
	_확인(not 코어.발사_소모() and 코어.남은_탄약 == 0, "8번째 발은 차단하고 음수 잔량을 만들지 않는다")
	for i in range(7):
		코어.명중_처리(null, 0, Vector2.ZERO)
	_확인(코어.남은_탄약 == 7, "실제 환급은 최대 7발까지 복원")
	코어.발사_소모()
	코어.리셋()
	_확인(코어.남은_탄약 == 7, "사망 리셋 뒤 7발로 충전")
	코어.queue_free()
	# 출발 가속이 없는 일정한 속도에서도 발걸음이 수면을 흔들고, 정지하면 기울기가 사라져야 한다.
	for fps in [30, 60, 144]:
		var 관성 := 관성형.new()
		관성.초기화(Vector2(320, 0), true)
		var 최소 := INF
		var 최대 := -INF
		for i in range(fps * 4):
			관성.갱신(1.0 / fps, Vector2(320, 0), true, float(i) / fps * TAU * 2.5)
			if i > fps * 2:
				최소 = minf(최소, 관성.기울기)
				최대 = maxf(최대, 관성.기울기)
			var 평균 := 0.0
			for 높이 in 관성.파동.높이:
				평균 += 높이 / 관성.파동.개수
			_확인(absf(평균) < 0.00001, "보행 파동이 평균 용량을 바꾸지 않는다")
			_확인(absf(관성.기울기) <= 1.05 and is_finite(관성.기울기), "프레임률별 기울기가 안정 범위 안")
		_확인(최대 - 최소 > 0.008, "일정 속도 보행에도 발걸음 출렁임이 남는다")
		for i in range(fps * 4):
			관성.갱신(1.0 / fps, Vector2.ZERO, true)
		_확인(absf(관성.기울기) < 0.005, "정지 후 수평 복귀")
	print("7발/환급/리스폰/보행/감쇠/프레임률 검사 실패: ", _실패)
	quit(1 if _실패 > 0 else 0)
