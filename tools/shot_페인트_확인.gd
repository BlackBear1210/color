extends SceneTree
## ============================================================================
## [2026-08-01 신규] 스마트월드 통합 확인 — 실제 씬에서 색칠이 보이는지 검사
## ----------------------------------------------------------------------------
## 실행:
##   Godot --path . -s res://tools/shot_페인트_확인.gd -- <저장.png> [x] [y] [줌]
##   (헤드리스 아님 — 렌더 결과를 봐야 하므로 창모드로 돌린다)
##
## ▣ test_페인트v4.gd 와 뭐가 다른가
##   저건 **규칙**만 본다(가짜 대상, 헤드리스). 이건 **실제 씬**에서
##   셰이더가 실제로 색을 칠하는지, 유령 발판이 실체가 되는지를 눈으로 확인한다.
##   둘 다 있어야 "규칙은 맞는데 화면에 안 나온다" 같은 사고를 잡을 수 있다.
##
## ▣ 하는 일
##   1. 스마트월드 씬을 띄운다
##   2. 발판 3개를 각각 흰색 / 검정 / 회색(검정→흰색) 으로 칠한다
##   3. 바닥 한 곳에 부분 색칠을 남긴다
##   4. 지정한 위치에서 화면을 찍는다
## ============================================================================

const 씬 := "res://scenes/스마트월드/스마트월드_1-1.tscn"

var _n := 0
var _루트: Node


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if _n == 1:
		_루트 = (load(씬) as PackedScene).instantiate()
		root.add_child(_루트)
	elif _n == 6:
		_색칠()
	elif _n == 8:
		_물길_실험()
	elif _n == 30:
		_물길_결과()
	elif _n == 12:
		# 카메라를 원하는 지점으로 옮긴다 (플레이어 추적 카메라를 잠시 무시)
		var cam := _루트.get_node_or_null("카메라") as Camera2D
		if cam and args.size() >= 3:
			cam.set_physics_process(false)
			cam.global_position = Vector2(float(args[1]), float(args[2]))
			if args.size() >= 4:
				cam.zoom = Vector2.ONE * float(args[3])
	elif _n == 40:
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[0])
		print("shot: %s -> %s" % [error_string(err), args[0]])
		quit(0 if err == OK else 1)


func _색칠() -> void:
	var 코어 := _루트.get_node_or_null("페인트코어")
	var 지형층 := _루트.get_node_or_null("지형")
	if 지형층 == null or 코어 == null:
		push_error("씬 구조가 예상과 다르다")
		quit(1)
		return

	# 발판_1 = 흰색 전체 색칠 / 발판_2 = 검정 / 발판_3 = 회색
	_쏘기(코어, 지형층.get_node_or_null("발판_1"), ColorDefs.WHITE, 4)
	_쏘기(코어, 지형층.get_node_or_null("발판_2"), ColorDefs.BLACK, 4)
	_쏘기(코어, 지형층.get_node_or_null("발판_3"), ColorDefs.BLACK, 4)
	_쏘기(코어, 지형층.get_node_or_null("발판_3"), ColorDefs.WHITE, 1)   # 반대색 → 회색

	# 바닥에 부분 색칠 얼룩 — 큰 지형은 한 발로 안 덮인다는 걸 보여준다
	var 바닥 = 지형층.get_node_or_null("바닥_1")
	if 바닥:
		for i in 3:
			코어.발사_소모()
			코어.명중_처리(바닥, ColorDefs.WHITE, 바닥.to_global(Vector2(560.0 + i * 90.0, 745.0)))

	print("색칠 완료 — 발판1=%s 발판2=%s 발판3=%s" % [
		_상태(지형층.get_node_or_null("발판_1")),
		_상태(지형층.get_node_or_null("발판_2")),
		_상태(지형층.get_node_or_null("발판_3"))])
	print("  탄약 %d/%d · 회수대기 %d · 잠김 %d" % [
		코어.남은_탄약, 코어.최대_탄약, 코어.회수_대기수(), 코어.잠긴_발수()])


## 물길 규칙 검사 — 흰 물이 지나갈 때
##   통과플랫폼(검정)  → 색이 남아야 한다 (물에_안지워짐 = true)
##   일반 발판(검정)   → 색이 지워지고 페인트가 회수돼야 한다
func _물길_실험() -> void:
	var 코어 = _루트.get_node_or_null("페인트코어")
	var 오브 = _루트.get_node_or_null("오브젝트")
	var 지형층 = _루트.get_node_or_null("지형")
	_쏘기(코어, 오브.get_node_or_null("통과플랫폼"), ColorDefs.BLACK, 2)
	_쏘기(코어, 지형층.get_node_or_null("발판_물아래"), ColorDefs.BLACK, 1)
	# 저장고를 흰색으로 칠하면 → 물줄기(위) 켜짐 → 호퍼 → 물줄기(아래) 켜짐
	_쏘기(코어, 오브.get_node_or_null("물저장고"), ColorDefs.WHITE, 3)


func _물길_결과() -> void:
	var 오브 = _루트.get_node_or_null("오브젝트")
	var 지형층 = _루트.get_node_or_null("지형")
	var 물아래 = 오브.get_node_or_null("물줄기_아래")
	print("물길 검사:")
	print("  물줄기(아래) 켜짐 = %s (기대 true)" % str(물아래.켜짐 if 물아래 else "없음"))
	print("  통과플랫폼 = %s (기대 검정 — 물에 안 지워짐)"
		% _상태(오브.get_node_or_null("통과플랫폼")))
	print("  일반 발판  = %s (기대 무색 — 반대색 물에 지워짐)"
		% _상태(지형층.get_node_or_null("발판_물아래")))


func _쏘기(코어, 대상, 색: int, 횟수: int) -> void:
	if 대상 == null:
		return
	for i in 횟수:
		코어.발사_소모()
		코어.명중_처리(대상, 색, 대상.global_position)


func _상태(n) -> String:
	if n == null:
		return "없음"
	match n.현재색():
		ColorDefs.BLACK: return "검정"
		ColorDefs.WHITE: return "흰색"
		ColorDefs.GRAY: return "회색"
	return "무색"
