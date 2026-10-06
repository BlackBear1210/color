extends SceneTree
## [2026-10-06 Claude] 우클릭 조준선 X 표시 규칙 검사 — headless 가능.
##   Godot_console --headless --path . -s res://tools/test_조준_X표시.gd
## 확인: 큰 구조(안칠해짐) = X · 내 색과 같은 판 = X · 반대색 판 = 칠됨(빨간 점) · 칠하고 회수 안 한 판 = X
##   총.gd 의 _칠_가능(콜리전) 을 실제 지형의 StaticBody 로 불러 본다(조준선과 같은 경로).
var _씬: Node
var _f := 0
var 통과 := 0
var 실패 := 0

func _initialize() -> void:
	_씬 = load("res://scenes/쳅터1/스테이지/쳅터1_03_방_서재.tscn").instantiate()
	root.add_child(_씬)

func _확인(이름: String, 기대: bool, 실제: bool) -> void:
	if 기대 == 실제:
		통과 += 1
		print("  ○ ", 이름)
	else:
		실패 += 1
		print("  × ", 이름, " 기대=", 기대, " 실제=", 실제)

func _몸(n: Node) -> Object:
	for c in n.find_children("*", "CollisionObject2D", true, false):
		return c
	return n

func _process(_d: float) -> bool:
	_f += 1
	if _f < 10:
		return false
	var 총: Node = null
	for n in _씬.find_children("*", "Node2D", true, false):
		if n.has_method("_칠_가능"):
			총 = n
	var 플: Node = _씬.find_child("Player", true, false)
	if 총 == null or 플 == null:
		print("총/플레이어 없음"); quit(1); return true
	var 지형들 := _씬.get_node("지형")
	var 구조 := 지형들.get_node("구조01")
	var 검정판 := 지형들.get_node("검정판02")
	var 흰판 := 지형들.get_node("흰판01")
	var 원래색 = 플.get("player_color")
	# 색을 직접 고정하려고 얼굴색 대신 player_color 를 쓰도록 메서드 없는 경우와 같은 값을 넣는다
	for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
		플.set("player_color", 색)
		var 이름 := "검정" if 색 == ColorDefs.BLACK else "흰"
		_확인(이름 + " 몸 → 구조 = X", false, 구조.칠_가능_미리보기(색))
		_확인(이름 + " 몸 → 검정판", 색 != ColorDefs.BLACK, 검정판.칠_가능_미리보기(색))
		_확인(이름 + " 몸 → 흰판", 색 != ColorDefs.WHITE, 흰판.칠_가능_미리보기(색))
	_확인("허공 물체(명중 없음) = X", false, 총.call("_칠_가능", Node2D.new()))
	_확인("총 경로로 구조 = X", false, 총.call("_칠_가능", _몸(구조)))
	# 칠하고 회수 안 함: 흰 몸이 검정판을 끝까지 칠하면 흰색이 된다 → 또 쏘면 X
	var 필요: int = 검정판.call("필요횟수")
	for i in 필요 + 2:
		검정판.명중(ColorDefs.WHITE, 검정판.global_position)
	_확인("칠 끝난 판(흰) 에 흰 몸 = X", false, 검정판.칠_가능_미리보기(ColorDefs.WHITE))
	_확인("칠 끝난 판(흰) 에 검정 몸 = 칠됨", true, 검정판.칠_가능_미리보기(ColorDefs.BLACK))
	플.set("player_color", 원래색)
	print("조준 X 표시: 통과 %d · 실패 %d" % [통과, 실패])
	quit(1 if 실패 else 0)
	return true
