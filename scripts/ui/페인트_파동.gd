extends RefCounted
## 33개 수면 스프링의 파동 방정식. 높이와 속도의 평균을 제거해 표시 용량을 보존한다.
const 개수 := 33
var 높이 := PackedFloat32Array()
var 속력 := PackedFloat32Array()
var _누적 := 0.0

func _init() -> void:
	초기화()

func 초기화() -> void:
	높이.resize(개수)
	속력.resize(개수)
	높이.fill(0.0)
	속력.fill(0.0)
	_누적 = 0.0

func 충격(세기: float) -> void:
	# 발사와 착지는 가운데를 눌러 양옆으로 퍼지는 파동을 만든다.
	for i in 개수:
		var x := float(i) / (개수 - 1)
		속력[i] += 세기 * (exp(-pow((x - 0.5) / 0.12, 2.0)) - 0.21) * 1.8

func 갱신(delta: float, 가속: float, 종류: int) -> void:
	if delta <= 0.0:
		return
	# 모든 프로필의 수면은 낮은 복원력과 빠른 이웃 전달을 사용한다. B도 잔파도를 유지한다.
	var 감쇠: float = [0.85, 1.15, 1.5][clampi(종류, 0, 2)]
	var 전달: float = [850.0, 740.0, 640.0][clampi(종류, 0, 2)]
	var dt := minf(delta, 0.1)
	# 프레임률과 무관한 가속도 적분을 양끝에 대칭으로 주어 출발/제동 때 반대 파도를 만든다.
	var 힘 := clampf(가속 / 1800.0, -1.5, 1.5) * 30.0
	for i in 3:
		var 충량 := 힘 * dt * (1.0 - float(i) / 3.0)
		속력[i] -= 충량
		속력[개수 - 1 - i] += 충량
	_누적 += dt
	const H := 1.0 / 240.0
	while _누적 >= H:
		_누적 -= H
		var 다음 := 속력.duplicate()
		for i in 개수:
			# 양끝은 반사 경계. 이웃 차분을 동시에 계산하여 배열 순서에 따른 편향을 막는다.
			var 왼 := 높이[maxi(i - 1, 0)]
			var 오른 := 높이[mini(i + 1, 개수 - 1)]
			다음[i] += (전달 * (왼 + 오른 - 2.0 * 높이[i]) - 8.0 * 높이[i] - 감쇠 * 속력[i]) * H
		속력 = 다음
		var 평균높이 := 0.0
		var 평균속력 := 0.0
		for i in 개수:
			높이[i] = clampf(높이[i] + 속력[i] * H, -0.24, 0.24)
			평균높이 += 높이[i] / 개수
			평균속력 += 속력[i] / 개수
		for i in 개수:
			높이[i] -= 평균높이
			속력[i] -= 평균속력
