extends SceneTree
## Godot 실행 허가 후 사용한다. 시각적 연결이 아니라 방향과 실제 빈 공간을 확인한다.
const 연결 = preload("res://tools/생성기/탐색연결.gd")
const 조립 = preload("res://tools/생성기/조립2.gd")
const 설정 = preload("res://tools/생성기/설정.gd")
const 윤곽 = preload("res://tools/생성기/윤곽.gd")
const 방_S = preload("res://tools/생성기/탐색방.gd")
const 검증 = preload("res://tools/생성기/탐색검증.gd")
const 난수 = preload("res://tools/생성기/난수.gd")
var 실패: int = 0

func _init():
	call_deferred("_실행")

func _검사(ok: bool, message: String):
	if not ok:
		실패 += 1
		push_error(message)

func _실행():
	if not 난수.자가검사():
		quit(1)
		return
	_검사(연결.출력허용("res://scenes/집/생성/탐색/사슬/"), "정상 출력 거부")
	for path in ["res://scenes/집/", "res://scenes/집/생성/탐색/../", "res://scenes/집/생성/탐색외부/"]:
		_검사(not 연결.출력허용(path), "출력 탈출 허용: " + path)
	# 실제 조립기가 만든 노드로 역할×방향 네 경우를 검사한다.
	var room = 방_S.new(1, false)
	room.생성()
	var checker = 검증.new(room)
	checker.출구고르기()
	var data: Dictionary = room.사전()
	var outline = 윤곽.뽑기(data)
	var placement: Dictionary = data["배치물"].duplicate(true)
	placement["통로들"] = []
	for role in ["입구", "출구"]:
		for direction in [-1, 1]:
			placement["통로들"].append({"이름": "%s_%s" % [role, "좌" if direction < 0 else "우"],
				"역할": role, "방향": direction, "위치": Vector2.ZERO, "다음_씬": ""})
	var root = 조립.new().굽기(data, outline, placement, 설정.집(), "방향검사")
	for spec in placement["통로들"]:
		var node = root.get_node(NodePath(spec["이름"]))
		_검사(node.방향() == spec["방향"], "역할별 방향 불일치: " + spec["이름"])
	root.free()
	# 모든 검증 시드에서 통로 개구부가 원본을 훼손하지 않고 양쪽 외벽 안에 남는지 확인한다.
	for standard in [false, true]:
		for seed_value in range(1, 7 if standard else 11):
			var r = 방_S.new(seed_value, standard)
			r.생성()
			검증.new(r).출구고르기()
			var original: Dictionary = r.사전()
			var before: PackedByteArray = original["칸"].duplicate()
			var opened = 연결.개구부(original)
			_검사(not opened.is_empty(), "개구부 생성 실패")
			_검사(original["칸"] == before, "원본 격자 변경")
			if opened.is_empty():
				continue
			var final_shape := 윤곽.뽑기(opened)
			_검사(not final_shape.is_empty(), "문을 판 뒤 윤곽 생성 실패")
			if not final_shape.is_empty():
				_검사(연결.통로여유(opened, final_shape), "최종 폴리곤이 통로를 막음")
			var cells: PackedByteArray = opened["칸"]
			var W: int = opened["폭칸"]
			for port in opened["통로들"]:
				var x: int = roundi(port["위치"].x / 96)
				var y: int = roundi(port["위치"].y / 96)
				for k in 5:
					var xx: int = x + k if port["방향"] > 0 else x - k - 1
					_검사(cells[(y - 1) * W + xx] == 0 and cells[(y - 2) * W + xx] == 0, "막힌 개구부")
					_검사(cells[y * W + xx] == 1, "지지면 손상")
	print("탐색연결 실패: %d" % 실패)
	quit(0 if 실패 == 0 else 1)
