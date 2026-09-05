extends SceneTree
## [2026-09-05] 스크린샷의 지정 영역 평균 밝기를 잰다 (눈으로 애매한 차이를 숫자로).
## 실행: -- <x> <y> <w> <h> <이미지...>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 5: push_error("사용법: -- x y w h 이미지..."); quit(1); return
	var r := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	for i in range(4, a.size()):
		var img := Image.load_from_file(a[i])
		if img == null: print("  ✗ %s" % a[i]); continue
		var sub := img.get_region(r)
		var 합 := 0.0
		var 제곱합 := 0.0
		var n := 0
		for y in sub.get_height():
			for x in sub.get_width():
				var v := sub.get_pixel(x, y).get_luminance()
				합 += v; 제곱합 += v * v; n += 1
		var 평균 := 합 / maxf(n, 1)
		# 표준편차 = 그 영역의 **국소 대비**. 노멀맵이 붙으면 같은 밝기라도 대비가 커진다.
		var 분산 := maxf(제곱합 / maxf(n, 1) - 평균 * 평균, 0.0)
		print("%-28s 평균밝기 %.5f  표준편차 %.5f" % [a[i].get_file(), 평균, sqrt(분산)])
	quit()
