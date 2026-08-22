extends SceneTree
## 브릭구조 컴포넌트 스모크 테스트 — 파싱·인스턴스화·콜리전·안전성 확인.
const 브릭 := preload("res://scripts/집/브릭구조.gd")

var _n := 0
var _b: StaticBody2D = null

func _init() -> void:
	process_frame.connect(_tick)

func _tick() -> void:
	_n += 1
	if _n == 1:
		_b = 브릭.new()
		_b.set("크기", Vector2(800, 140))
		_b.set("룩", 0)
		_b.set("테두리", 60.0)
		root.add_child(_b)      # _ready 가 다음 프레임 초에 돈다
		return
	if _n < 3:
		return

	var 통과 := 0
	var 실패 := 0
	var cs := _b.get_node_or_null("모양") as CollisionShape2D
	var np := _b.get_node_or_null("브릭") as NinePatchRect

	if cs != null and (cs.shape as RectangleShape2D) != null:
		var sz := (cs.shape as RectangleShape2D).size
		if is_equal_approx(sz.x, 800.0) and is_equal_approx(sz.y, 140.0):
			print("  ✔ 콜리전 사각형이 크기(800,140)에 맞다"); 통과 += 1
		else:
			print("  ✖ 콜리전 크기 어긋남: %s" % sz); 실패 += 1
	else:
		print("  ✖ 콜리전 모양이 없다"); 실패 += 1

	if np != null and np.texture != null:
		print("  ✔ 브릭 9-슬라이스 (region %s · margin %d · size %s)"
			% [np.region_rect, np.patch_margin_left, np.size]); 통과 += 1
	else:
		print("  ✖ 브릭 그림이 없다"); 실패 += 1

	if _b.collision_layer == 1 and not _b.has_method("반대색인가"):
		print("  ✔ 무색 구조물 — 레이어1 + 반대색인가 없음(누구나 안전)"); 통과 += 1
	else:
		print("  ✖ 안전성 계약 어긋남 (layer=%d)" % _b.collision_layer); 실패 += 1

	print("[test_브릭구조] 통과 %d / 실패 %d" % [통과, 실패])
	quit(실패)
