extends SceneTree
## 2층방의 칠하기 가능한 SS2D 실면적과 기준 반지름별 필요 발수를 비교한다.
## 총알 총량이 확정되기 전에 한 발 면적을 감으로 고르지 않기 위한 읽기 전용 측정 도구다.

const 이층방씬 := preload("res://scenes/집/스테이지_1_2층방.tscn")
const 후보반지름 := [140.0, 160.0, 180.0, 200.0]


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 방 := 이층방씬.instantiate() as Node2D
	root.add_child(방)
	await process_frame
	print("이름 | 면적 | r140 | r160 | r180 | r200")
	for 값 in 방.get_node("지형").get_children():
		var 지형 := 값 as Node2D
		if 지형 == null or not 지형.has_method("필요횟수") or not bool(지형.get("칠하기_허용")):
			continue
		var 면적 := float(지형.get("_면적"))
		var 발수: Array[int] = []
		for 반지름 in 후보반지름:
			발수.append(maxi(int(ceil(면적 / (PI * 반지름 * 반지름))), 1))
		print("%s | %.0f | %d | %d | %d | %d" %
			[지형.name, 면적, 발수[0], 발수[1], 발수[2], 발수[3]])
	방.queue_free()
	await process_frame
	quit()
