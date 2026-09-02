extends SceneTree
## ============================================================================
## [2026-09-02 신규] **배관이 물보다 위에 그려지나**
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_배관_유체_높이.gd
##
## ▣ 왜 (성진님 지시 2026-09-02)
##   "배관이 유체보다 위에 있게 하고 싶어. 2D 워크스페이스에서 배관이 물 밑에 있는 게 싫어."
##
## ▣ 무엇이 문제였나
##   유체는 세 겹으로 그려진다 — 본체 z 0 · `물_애니메이션` +1 · `물결_상세_애니메이션` +2.
##   그런데 배관은
##     · SS2D 배관(`TEMPLATE_PIPE_OPEN_GRAY`) : 높이 설정이 **아예 없었다**(0 고정)
##     · 옛 배관(`배관.tscn`)                 : `깊이` 기본 **2** = 물결 상세와 **같은 높이**
##   같은 높이면 누가 위로 갈지 **트리 순서**로 갈린다. 그래서 어떤 배관은 물에 깔리고
##   어떤 것은 안 깔리는, 재현이 안 되는 상태였다.
##
## ▣ 여기서 고정하는 것
##   1. 두 배관 모두 인스펙터에 `깊이` 가 있다 (디자이너가 올리고 내릴 수 있다)
##   2. 기본값으로 **배관의 모든 그려지는 부분이 물의 모든 겹보다 위**다
##   3. 음수를 주면 지형 뒤로도 보낼 수 있다 (예전 용법을 안 막는다)
## ============================================================================

const 유체_씬 := "res://scenes/집/스마트월드_장애물/유체.tscn"
const SS2D_배관 := "res://scenes/집/스마트 매쉬 assets/PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn"
const 옛_배관 := "res://scenes/집/스마트월드_장애물/배관.tscn"

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
		print("  ✔ %s" % 글)
	else:
		실패 += 1
		print("  ✖ %s" % 글)


func _실행() -> void:
	print("\n=== 배관 · 유체 그리기 높이 ===")

	var 물 := _꽂기(유체_씬)
	var 물_최고 := _최고_높이(물)
	print("\n── 유체가 쓰는 높이")
	for 줄 in _높이_목록(물):
		print("    %s" % 줄)
	_확인(물_최고 == 2, "물의 가장 높은 겹이 2 다 (%d)" % 물_최고)

	for 이름 in [["SS2D 배관", SS2D_배관], ["옛 배관", 옛_배관]]:
		print("\n── %s" % 이름[0])
		var 관 := _꽂기(이름[1])
		_확인("깊이" in 관, "인스펙터에 `깊이` 가 있다")
		for 줄 in _높이_목록(관):
			print("    %s" % 줄)

		var 관_최저 := _최저_높이(관)
		_확인(관_최저 > 물_최고,
				"가장 낮은 부분(%d)도 물의 가장 높은 겹(%d)보다 위다" % [관_최저, 물_최고])

		# 디자이너가 내릴 수도 있어야 한다 — 예전 "배경처럼 뒤에 있는 배관" 용법.
		if "깊이" in 관:
			관.set("깊이", -6)
			_확인(_최고_높이(관) < 0,
					"`깊이 = -6` 을 주면 지형 뒤로 내려간다 (최고 %d)" % _최고_높이(관))
			관.set("깊이", 3)
			_확인(_최저_높이(관) > 물_최고, "다시 3 으로 올리면 물 위로 돌아온다")
		관.free()

	물.free()
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


func _꽂기(경로: String) -> Node:
	var 씬 := load(경로) as PackedScene
	var n := 씬.instantiate()
	root.add_child(n)
	return n


## 실제로 그려지는 CanvasItem 들의 **실효 높이**를 모은다.
## 자식 z 는 부모에 더해지는 상대값이다(`z_as_relative` 기본 켜짐) — 그걸 그대로 계산한다.
func _높이들(n: Node, 부모_높이: int = 0, 담을곳: Array[int] = []) -> Array[int]:
	var 나 := 부모_높이
	if n is CanvasItem:
		나 = (부모_높이 + n.z_index) if n.z_as_relative else n.z_index
		# 안 보이는 것(포트 Marker · 꺼진 그림)은 화면에 안 나오니 세지 않는다.
		if n.visible and not (n is Marker2D):
			담을곳.append(나)
	for c in n.get_children():
		_높이들(c, 나, 담을곳)
	return 담을곳


func _최고_높이(n: Node) -> int:
	var 목록 := _높이들(n, 0, [] as Array[int])
	var m := -9999
	for v in 목록:
		m = maxi(m, v)
	return m


func _최저_높이(n: Node) -> int:
	var 목록 := _높이들(n, 0, [] as Array[int])
	var m := 9999
	for v in 목록:
		m = mini(m, v)
	return m


func _높이_목록(n: Node) -> Array[String]:
	var 결과: Array[String] = []
	_모으기(n, 0, "", 결과)
	return 결과


func _모으기(n: Node, 부모_높이: int, 앞: String, 결과: Array[String]) -> void:
	var 나 := 부모_높이
	if n is CanvasItem:
		나 = (부모_높이 + n.z_index) if n.z_as_relative else n.z_index
		if n.visible and not (n is Marker2D):
			결과.append("%s%s : 실효 %d" % [앞, n.name, 나])
	for c in n.get_children():
		_모으기(c, 나, 앞 + "  ", 결과)
