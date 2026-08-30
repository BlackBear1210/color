extends SceneTree
## [2026-08-30 신규] 원화 PNG 의 **명도 지도**를 ASCII 로 찍는다.
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   레벨을 원화 픽셀로 설계하려면 "가구 윗면이 원화 몇 px 이냐" 를 알아야 한다.
##   지금까지는 눈으로 재서 빌더 주석에 적어 왔는데(옷장 끝 779 · 침대 806…1356),
##   **세로 좌표는 아무도 안 재 놨다.** 원화가 너무 어두워 그냥 열어 봐선 안 보인다.
##   → 격자로 평균 명도를 내어 문자로 찍는다. 밝은 벽 / 어두운 가구가 갈려 보인다.
##
## 실행: Godot --headless --path . -s res://tools/측정_원화_명도지도.gd -- <png> [칸수x] [칸수y]
## ⚠ 아무것도 고치지 않는다. 재서 보고만 한다.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("사용법: -- <png> [칸수x=64] [칸수y=32]"); quit(2); return
	var img := Image.load_from_file(ProjectSettings.globalize_path(a[0]))
	if img == null:
		print("못 읽음: ", a[0]); quit(2); return
	var W := img.get_width()
	var H := img.get_height()
	var nx := int(a[1]) if a.size() > 1 else 64
	var ny := int(a[2]) if a.size() > 2 else 32
	# ★[추가] 볼 구역만 잘라 본다. 창문(가장 밝은 면)이 들어오면 정규화가 그쪽에
	#   쏠려 나머지가 전부 공백으로 뭉개진다 — 실제로 그렇게 나왔다.
	var rx := int(a[3]) if a.size() > 3 else 0
	var ry := int(a[4]) if a.size() > 4 else 0
	var rw := int(a[5]) if a.size() > 5 else W
	var rh := int(a[6]) if a.size() > 6 else H
	print("원본 %d x %d · 격자 %d x %d (칸 %.1f x %.1f px)" % [W, H, nx, ny, float(W)/nx, float(H)/ny])

	# 칸마다 평균 명도. 0..1 을 10 단계 문자로 — 어두울수록 진한 글자.
	var 단계 := " .:-=+*#%@"      # 왼쪽이 어둡다
	var 값: Array = []
	var 최소 := 1.0
	var 최대 := 0.0
	for gy in ny:
		var 줄: Array = []
		for gx in nx:
			var x0 := rx + int(float(gx) * rw / nx)
			var x1 := rx + int(float(gx + 1) * rw / nx)
			var y0 := ry + int(float(gy) * rh / ny)
			var y1 := ry + int(float(gy + 1) * rh / ny)
			var 합 := 0.0
			var 수 := 0
			# 칸 안을 4px 간격으로만 훑는다 — 정확도는 충분하고 훨씬 빠르다
			var y := y0
			while y < y1:
				var x := x0
				while x < x1:
					합 += img.get_pixel(x, y).get_luminance()
					수 += 1
					x += 4
				y += 4
			var v := 합 / maxf(float(수), 1.0)
			최소 = minf(최소, v)
			최대 = maxf(최대, v)
			줄.append(v)
		값.append(줄)

	print("명도 범위 %.4f … %.4f  (원화가 어두워 아래 지도는 이 범위로 정규화했다)" % [최소, 최대])
	# 가로 눈금 — 원화 px
	var 눈금 := "     "
	for gx in nx:
		눈금 += "|" if gx % 10 == 0 else " "
	print(눈금)
	for gy in ny:
		var s := ""
		for gx in nx:
			var t := (float(값[gy][gx]) - 최소) / maxf(최대 - 최소, 0.0001)
			# 감마 0.45 — 어두운 쪽을 벌려야 가구 실루엣이 갈린다
			s += 단계[clampi(int(pow(t, 0.45) * 9.999), 0, 9)]
		# 줄머리에 이 줄의 원화 py 를 적는다 (설계에 그대로 쓰는 좌표다)
		print("%4d %s" % [ry + int(float(gy) * rh / ny), s])
	var 끝 := "     "
	for gx in nx:
		끝 += "%d" % ((int(float(gx) * W / nx) / 100) % 10) if gx % 10 == 0 else " "
	print(끝, "   ← 가로 눈금 = 원화 px ÷ 100 의 끝자리")
	quit(0)
