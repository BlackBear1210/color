extends SceneTree
## ============================================================================
## [2026-09-05 신규] 배경 원화에서 **빛이 그려져 있는 자리**를 찾아 월드 좌표로 준다.
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/측정_원화_광원자리.gd
##
## ▣ 왜 필요한가 (STEP 6 §2)
##   "왜 여기가 밝지?" 를 없애려면 광원을 **화면에 그려진 밝은 곳**에 놓아야 한다.
##   눈대중으로 좌표를 찍으면 원화의 빛과 광원이 어긋나서, 결국 근거 없는 채움광이 된다.
##   → 원화를 격자로 잘라 밝기를 재고, **밝은 칸을 월드 좌표로 변환**해서 보여 준다.
##
## ▣ 좌표 변환
##   `실내배경` 인스펙터의 `영역`(월드 Rect2)과 `그림_원본영역`(원화 픽셀 Rect2)으로
##   원화 픽셀 → 월드 를 만든다. 씬에서 직접 읽으므로 손으로 배율을 적지 않는다.
## ============================================================================

const 씬 := "res://scenes/집/스테이지_1_2층방.tscn"
var 칸 := 24            ## 격자 칸 수(가로). `-- --칸=48` 로 더 잘게 볼 수 있다.


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--칸="):
			칸 = int(a.substr(4))
	var 뿌리 := (load(씬) as PackedScene).instantiate()
	# 배경 노드에서 그림·영역을 읽는다 (인스턴스화만 하고 트리에 안 넣는다 = 게임 로직 안 돈다)
	var 배경: Node = _찾기(뿌리, func(n): return n.get("그림_아래") != null and n.get("영역") != null)
	if 배경 == null:
		print("✗ 실내배경 노드를 못 찾았다")
		quit(1)
		return
	var tex: Texture2D = 배경.get("그림_아래")
	var 영역: Rect2 = 배경.get("영역")
	var 원본영역: Rect2 = 배경.get("그림_원본영역")
	print("배경 '%s'  월드영역 %s  원화영역 %s" % [배경.name, 영역, 원본영역])

	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	print("원화 %dx%d" % [img.get_width(), img.get_height()])

	# 원화 픽셀 → 월드
	var sx := 영역.size.x / maxf(원본영역.size.x, 1.0)
	var sy := 영역.size.y / maxf(원본영역.size.y, 1.0)
	print("배율 x %.4f  y %.4f\n" % [sx, sy])

	var w := int(원본영역.size.x)
	var h := int(원본영역.size.y)
	var cw := int(float(w) / 칸)
	var ch := cw            # 정사각 칸
	var 결과: Array = []
	var 전체합 := 0.0
	var 전체수 := 0
	for gy in range(0, h / ch):
		for gx in range(0, w / cw):
			var x0 := int(원본영역.position.x) + gx * cw
			var y0 := int(원본영역.position.y) + gy * ch
			var 합 := 0.0
			var n := 0
			# 칸 안을 4px 간격으로 훑는다(2135x1200 전체를 다 읽으면 느리다)
			for y in range(y0, mini(y0 + ch, img.get_height()), 4):
				for x in range(x0, mini(x0 + cw, img.get_width()), 4):
					합 += img.get_pixel(x, y).get_luminance()
					n += 1
			if n == 0:
				continue
			var 평균 := 합 / n
			전체합 += 평균
			전체수 += 1
			var 월드 := Vector2(
				영역.position.x + (x0 + cw * 0.5 - 원본영역.position.x) * sx,
				영역.position.y + (y0 + ch * 0.5 - 원본영역.position.y) * sy)
			결과.append({"밝기": 평균, "월드": 월드, "원화": Vector2(x0, y0)})
	결과.sort_custom(func(a, b): return a["밝기"] > b["밝기"])
	var 평균전체 := 전체합 / maxf(전체수, 1)
	print("원화 전체 평균 밝기 %.4f · 칸 %d개 (%dx%d px)\n" % [평균전체, 전체수, cw, ch])

	print("── 가장 밝은 칸 20개 (= 원화가 '여기 빛이 있다'고 말하는 자리) ──")
	for i in mini(20, 결과.size()):
		var r: Dictionary = 결과[i]
		print("  %2d. 밝기 %.4f  월드 (%7.0f, %7.0f)  원화 %s" % [
			i + 1, r["밝기"], r["월드"].x, r["월드"].y, r["원화"]])

	# 왼쪽 절반(월드 x 150~2500)만 따로
	# `--구역=x0,x1,y0,y1` 을 주면 그 사각형 안의 밝은 칸을 따로 뽑는다.
	# (창문 빛기둥이 원화에 **어디까지** 그려져 있나를 재려고 만들었다)
	for a2 in OS.get_cmdline_user_args():
		var s2 := String(a2)
		if not s2.begins_with("--구역="):
			continue
		var v := s2.substr(5).split(",")
		if v.size() != 4:
			continue
		var x0f := float(v[0])
		var x1f := float(v[1])
		var y0f := float(v[2])
		var y1f := float(v[3])
		print("\n── 구역 x %.0f~%.0f · y %.0f~%.0f 의 밝은 칸 16개 ──" % [x0f, x1f, y0f, y1f])
		var 구: Array = 결과.filter(func(r): return r["월드"].x >= x0f and r["월드"].x <= x1f \
			and r["월드"].y >= y0f and r["월드"].y <= y1f)
		for i2 in mini(16, 구.size()):
			var rc: Dictionary = 구[i2]
			print("  %2d. 밝기 %.4f  월드 (%7.0f, %7.0f)" % [
				i2 + 1, rc["밝기"], rc["월드"].x, rc["월드"].y])

	print("\n── ★왼쪽 절반(월드 x 150~2500)에서 가장 밝은 칸 12개 ──")
	var 왼쪽: Array = 결과.filter(func(r): return r["월드"].x >= 150.0 and r["월드"].x <= 2500.0)
	for i in mini(12, 왼쪽.size()):
		var r2: Dictionary = 왼쪽[i]
		print("  %2d. 밝기 %.4f  월드 (%7.0f, %7.0f)" % [
			i + 1, r2["밝기"], r2["월드"].x, r2["월드"].y])
	var 왼합 := 0.0
	for r3 in 왼쪽:
		왼합 += r3["밝기"]
	print("  왼쪽 절반 평균 밝기 %.4f (전체 평균의 %.0f%%)" % [
		왼합 / maxf(왼쪽.size(), 1), 100.0 * (왼합 / maxf(왼쪽.size(), 1)) / maxf(평균전체, 0.0001)])
	뿌리.queue_free()
	quit()


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 조건.call(뿌리):
		return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null:
			return r
	return null
