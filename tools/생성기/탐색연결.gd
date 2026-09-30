extends RefCounted
## 선택된 문을 껍데기에 실제로 뚫고 연결 정보를 검증한다.
## 사전 복사본만 바꾸므로 내부 그래프/난수/원본 방은 그대로 보존된다.
const 출력루트 = "res://scenes/집/생성/탐색/"

static func 출력허용(폴더: String) -> bool:
	var 경로 := 폴더.trim_suffix("/")
	return 경로 == 경로.simplify_path() and (경로 + "/").begins_with(출력루트)

static func 개구부(원본: Dictionary) -> Dictionary:
	var 방 := 원본.duplicate(true)
	var 칸: PackedByteArray = 방["칸"].duplicate()
	var 크기: float = 방["칸크기"]
	var 원점: Vector2 = 방["원점"]
	var W: int = 방["폭칸"]
	var H: int = 방["높이칸"]
	for t in 방["통로들"]:
		var 위치: Vector2 = (t["위치"] - 원점) / 크기
		var x: int = roundi(위치.x)
		var y: int = roundi(위치.y)
		var d: int = t["방향"]
		if not 위치.is_equal_approx(Vector2(x, y)) or absi(d) != 1:
			push_error("탐색 연결: 격자에 맞지 않는 통로")
			return {}
		t["높이"] = 150.0
		t["깊이"] = 420.0
		t["암반_위"] = 0.0
		t["암반_아래"] = 0.0
		# 깊이420을 담는 5칸을 파고 통로 자체의 뒷벽으로 끝을 막는다.
		var 길이: int = ceili(float(t["깊이"]) / 크기)
		var 높이: int = ceili(float(t["높이"]) / 크기)
		for k in 길이:
			var xx: int = x + k if d > 0 else x - 1 - k
			if xx < 1 or xx >= W - 1 or y - 높이 < 1 or y >= H - 1:
				push_error("탐색 연결: 통로가 외벽을 관통함")
				return {}
			# 바닥을 새로 메우면 관문을 덮을 수 있으므로 원래 지지면이 있는지 검사한다.
			if 칸[y * W + xx] != 1:
				push_error("탐색 연결: 통로 밑 지지면 없음")
				return {}
			for yy in range(y - 높이, y):
				칸[yy * W + xx] = 0
	방["칸"] = 칸
	return 방

static func 출구연결(통로들: Array, 목적지: String) -> void:
	for t in 통로들:
		if t["역할"] == "출구":
			t["다음_씬"] = 목적지
			t["다음_진입점"] = "입구통로"

static func 통로여유(방: Dictionary, 윤: Dictionary) -> bool:
	# 격자가 비어 있어도 윤곽 단순화가 문을 가로지를 수 있다. 최종 폴리곤과
	# 통로 내부 사각형의 교집합을 검사해 벽 속 스폰/진입 불가를 저장 전에 막는다.
	var 지형: Array = [윤["껍데기"]]
	지형.append_array(윤["섬들"])
	for t in 방["통로들"]:
		var d: float = t["방향"]
		var p: Vector2 = t["위치"]
		var a := p + Vector2(-d * 24.0, -149.0)
		var b := p + Vector2(d * 419.0, -1.0)
		var rect := Rect2(a.min(b), (a - b).abs())
		var 내부 := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		for polygon in 지형:
			if not Geometry2D.intersect_polygons(내부, polygon).is_empty():
				push_error("최종 지형이 통로를 막음: " + String(t["이름"]))
				return false
	return true

static func 사슬검사(항목들: Array) -> PackedStringArray:
	var 오류 := PackedStringArray()
	for i in range(항목들.size() - 1):
		var 출구: Dictionary = {}
		var 입구: Dictionary = {}
		for t in 항목들[i]["방"]["통로들"]:
			if t["역할"] == "출구":
				출구 = t
		for t in 항목들[i + 1]["방"]["통로들"]:
			if t["역할"] == "입구":
				입구 = t
		if 출구.is_empty() or 입구.is_empty():
			오류.append("연결할 입구/출구 없음")
		elif 출구.get("다음_씬", "") != 항목들[i + 1]["경로"] or 출구.get("다음_진입점", "") != 입구["이름"]:
			오류.append("목적 씬 또는 진입점 불일치")
		elif int(출구["방향"]) != -int(입구["방향"]):
			오류.append("진행 방향과 다음 입구 방향 불일치")
	return 오류
