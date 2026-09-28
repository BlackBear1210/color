extends SceneTree
## [2026-09-27] 입구 전체 혼합의 순서 독립성과 입구/출구 동기화를 검증한다.
## 사용자 엔진 실행 승인 후 실행할 인계 검사. 작성 세션에서는 실행하지 않는다.
const 호퍼코드 = preload("res://scripts/스마트월드/호퍼_주철.gd")
const 기존코드 = preload("res://scripts/스마트월드/호퍼_주철_기존배치.gd")
const 수면코드 = preload("res://scripts/스마트월드/호퍼_입구수면.gd")
var 실패: int = 0

func _init() -> void:
	call_deferred("_실행")

func _확인(조건: bool, 설명: String) -> void:
	if not 조건:
		실패 += 1
		push_error(설명)
	else:
		print("PASS: ", 설명)

func _실행() -> void:
	for 경우 in [
		[[], -1], [[0], 0], [[1], 1], [[2], 2], [[0, 0], 0], [[1, 1], 1],
		[[0, 1], 2], [[1, 0], 2], [[0, 1, 0], 2], [[1, 0, 1], 2],
		[[2, 0, 1], 2], [[0, 2], 0], [[1, 2], 1]
	]:
		var 색들: Array[int] = []
		색들.assign(경우[0])
		_확인(호퍼.입구_색_합치기(색들) == 경우[1], "전체 유입 혼합 %s" % [색들])
	_확인(수면코드.물결색(1).r < 수면코드.수면색(1).r, "흰 물 거품은 본체보다 어둡다")
	await _실제_입구_검사(호퍼코드)
	await _실제_입구_검사(기존코드)
	print("입구수면 실패: ", 실패)
	quit(1 if 실패 else 0)

func _실제_입구_검사(코드: Script) -> void:
	var 판 := Node2D.new()
	# 실제 대상 폴더의 런타임 초기화 경로를 재현한다. 저장/씬 재생성은 하지 않는다.
	판.scene_file_path = "res://scenes/world_2_클로드/stage_inlet_test.tscn"
	root.add_child(판)
	var h = 코드.new()
	h.name = "H"
	h.폭 = 320.0
	h.높이 = 164.0
	h.자동_출구_연결 = false
	판.add_child(h)
	h.set_physics_process(false)  # 검사가 직접 호출하므로 이중 유예 누적을 막는다.
	_확인(h.has_node("InletWaterSurface"), "대상 스테이지에 수면 부품 생성")
	var 검 := _유입_만들기(판, -60.0, 0)
	var 흰 := _유입_만들기(판, 60.0, 1)
	흰.켜짐 = false
	await physics_frame
	await physics_frame
	await physics_frame
	h._physics_process(0.016)
	# [2026-09-28 Claude] get_node() 는 타입이 없어 := 추론이 Godot 4.6 에서 Parse Error — 타입을 적는다
	var 수면: Node = h.get_node("InletWaterSurface")
	_확인(h._마지막_받은색 == 0 and 수면.get("_색") == 0, "출구 미연결도 검정 입구 표시")
	흰.켜짐 = true
	await physics_frame
	await physics_frame
	await physics_frame
	h._physics_process(0.016)
	_확인(h._마지막_받은색 == 2 and 수면.get("_색") == 2, "흑백 동시 유입은 회색 수면")
	var 출 := 유체.new()
	출.크기 = Vector2(160, 200)
	판.add_child(출)
	var 포트 := h.get_node_or_null("출구_포트") as Marker2D
	if 포트 == null:
		포트 = Marker2D.new()
		포트.name = "출구_포트"
		h.add_child(포트)
	h._다시_만들기()
	출.global_position = 포트.global_position + Vector2(0, 56)
	var 바닥 := 출.global_position.y + 출.크기.y
	h._출구 = 출
	h._출구_물줄기_크기_갱신()
	h._physics_process(0.016)
	_확인(출.색 == 2 and 출.켜짐, "출구와 입구가 같은 회색")
	_확인(is_equal_approx(출.크기.x, 64.0), "출구 폭은 노즐의 20%")
	_확인(출.global_position.is_equal_approx(포트.global_position), "출구에 공중 틈 없음")
	_확인(is_equal_approx(출.global_position.y + 출.크기.y, 바닥), "출구 연결 후 바닥 끝 보존")
	검.켜짐 = false
	await physics_frame
	await physics_frame
	await physics_frame
	h._physics_process(0.016)
	_확인(수면.get("_색") == 1 and 출.색 == 1, "검정 중단 후 흰색만 표시")
	흰.켜짐 = false
	await physics_frame
	await physics_frame
	await physics_frame
	h._physics_process(0.05)
	_확인(수면.visible and 출.켜짐, "짧은 끊김 유예 유지")
	h._physics_process(0.31)
	_확인(not 수면.visible and not 출.켜짐, "유입 중단 후 수면/출구 함께 꺼짐")
	판.queue_free()
	await process_frame

func _유입_만들기(판: Node2D, x: float, 물색: int) -> 유체:
	var 물 := 유체.new()
	물.position = Vector2(x, -300)
	물.크기 = Vector2(48, 160)
	물.색 = 물색
	판.add_child(물)
	return 물
