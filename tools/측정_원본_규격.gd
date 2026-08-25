extends SceneTree
## [2026-08-25 신규] 원본 master_*.png 의 규격 실측 — 새 원본을 만들 때 맞춰야 할 값
func _init(): call_deferred("_go")
func _go():
	for 재질 in ["brick_v2", "wood_v2", "iron_v1"]:
		print("\n=== %s ===" % 재질)
		for n in ["top", "side", "bottom", "fill"]:
			var p := "res://tools/%s_pipeline/src/master_%s.png" % [재질, n]
			var b := FileAccess.get_file_as_bytes(p)
			if b.is_empty():
				print("  master_%-7s 없음" % n)
				continue
			var im := Image.new(); im.load_png_from_buffer(b); im.convert(Image.FORMAT_RGBA8)
			var W := im.get_width(); var H := im.get_height()
			# 마젠타다움 = min(R,B) - G  (파생 굽기가 쓰는 판정과 동일)
			var 키 := 0; var 그림 := 0
			var 휘도합 := 0.0
			var 첫행 := PackedInt32Array()
			for x in W:
				var found := false
				for y in H:
					var c := im.get_pixel(x, y)
					var m: float = minf(c.r, c.b) - c.g
					if m > 0.15:
						키 += 1
					else:
						그림 += 1
						휘도합 += c.g
						if not found:
							첫행.push_back(y); found = true
			첫행.sort()
			var 중앙 := 첫행[첫행.size() / 2] if not 첫행.is_empty() else -1
			print("  master_%-7s %5d x %-5d  비율 %.2f  키색 %.1f%%  그림평균휘도 %.0f  실루엣 중앙값 y=%d (%.0f%%)"
				% [n, W, H, float(W)/float(H), 100.0*float(키)/float(W*H),
					휘도합/maxf(그림,1)*255.0, 중앙, 100.0*float(중앙)/float(H)])
	quit()
