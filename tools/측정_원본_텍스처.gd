extends SceneTree
## ============================================================================
## [2026-08-24 신규] 타일셋 원본 PNG 측정기 (재질 무관 · 읽기 전용)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/측정_원본_텍스처.gd -- \
##       --그림=res://...png [--그림=... 반복] [--이름=라벨]
##
## ▣ 왜
##   새 재질(BRICK/SEWER/WOOD)을 붙이기 전에 원본이 마스터 템플릿 규격에
##   맞는지 **재고 나서** 판단하려는 것. 눈으로 보고 "비슷하네" 하면 안 된다.
##
## ▣ 재는 것
##   해상도 / 종횡비 / 알파 유무 / 알파 커버리지
##   휘도 평균·p05·p50·p95·min·max (알파 가중)
##   내부 디테일 단계 수 (p05~p95)
##   띠 두께 — 행 평균 알파가 0.5 를 넘는 첫/마지막 행
##   좌우·상하 이음매 (끝 픽셀 차 vs 내부 이웃 차)
##   ★ 원본 PNG 바이트를 직접 디코드한다 (import 설정에 오염되지 않는다)
## ============================================================================

var _그림들: PackedStringArray = PackedStringArray()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--그림="):
			_그림들.push_back(a.substr("--그림=".length()))
	call_deferred("_실행")


func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		push_error("읽기 실패: %s" % 경로)
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		push_error("디코드 실패: %s" % 경로)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _히스토(im: Image, 알파필터: bool) -> PackedInt64Array:
	var h := PackedInt64Array()
	h.resize(256)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if 알파필터 and c.a * 255.0 <= 127.0:
				continue
			h[int(round(c.r * 255.0))] += 1
	return h


func _합(h: PackedInt64Array) -> int:
	var s := 0
	for v in h:
		s += v
	return s


func _평균(h: PackedInt64Array) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var acc := 0.0
	for i in 256:
		acc += float(i) * float(h[i])
	return acc / float(n)


func _분위(h: PackedInt64Array, q: float) -> float:
	var n := _합(h)
	if n == 0:
		return 0.0
	var 목표 := q * float(n)
	var acc := 0.0
	for i in 256:
		acc += float(h[i])
		if acc >= 목표:
			return float(i)
	return 255.0


func _최소(h: PackedInt64Array) -> int:
	for i in 256:
		if h[i] > 0:
			return i
	return -1


func _최대(h: PackedInt64Array) -> int:
	for i in range(255, -1, -1):
		if h[i] > 0:
			return i
	return -1


## 이음매: 끝 픽셀 차이를 내부 이웃 픽셀 차이 평균과 비교한다.
## 비율이 1 근처면 이음매가 평범한 이웃 관계 = 안 보인다.
func _이음매(im: Image, 가로: bool) -> Array:
	var W := im.get_width()
	var H := im.get_height()
	var 끝합 := 0.0; var 끝수 := 0
	var 내부합 := 0.0; var 내부수 := 0
	if 가로:
		for y in H:
			var a := im.get_pixel(W - 1, y)
			var b := im.get_pixel(0, y)
			끝합 += absf(a.r * a.a - b.r * b.a) * 255.0
			끝수 += 1
			for x in range(0, W - 1):
				내부합 += absf(im.get_pixel(x, y).r * im.get_pixel(x, y).a
					- im.get_pixel(x + 1, y).r * im.get_pixel(x + 1, y).a) * 255.0
				내부수 += 1
	else:
		for x in W:
			var a2 := im.get_pixel(x, H - 1)
			var b2 := im.get_pixel(x, 0)
			끝합 += absf(a2.r * a2.a - b2.r * b2.a) * 255.0
			끝수 += 1
			for y in range(0, H - 1):
				내부합 += absf(im.get_pixel(x, y).r * im.get_pixel(x, y).a
					- im.get_pixel(x, y + 1).r * im.get_pixel(x, y + 1).a) * 255.0
				내부수 += 1
	var 끝 := 끝합 / maxf(1.0, float(끝수))
	var 내부 := 내부합 / maxf(1.0, float(내부수))
	return [끝, 내부, 끝 / maxf(0.0001, 내부)]


## 띠 두께 — 행 평균 알파가 0.5 를 넘는 첫 행과 마지막 행.
func _띠(im: Image) -> Array:
	var H := im.get_height()
	var W := im.get_width()
	var 첫 := -1
	var 끝 := -1
	for y in H:
		var a := 0.0
		for x in W:
			a += im.get_pixel(x, y).a
		if a / float(W) >= 0.5:
			if 첫 < 0:
				첫 = y
			끝 = y
	return [첫, 끝]


func _실행() -> void:
	print("=".repeat(100))
	print("타일셋 원본 텍스처 측정 (원본 PNG 바이트 직접)")
	print("=".repeat(100))
	for 경로 in _그림들:
		var im := _png(경로)
		if im == null:
			continue
		var W := im.get_width()
		var H := im.get_height()
		# 알파 유무 / 커버리지
		var 불투명 := 0
		var 반투명 := 0
		var 투명 := 0
		for y in H:
			for x in W:
				var a := im.get_pixel(x, y).a * 255.0
				if a >= 254.0:
					불투명 += 1
				elif a <= 1.0:
					투명 += 1
				else:
					반투명 += 1
		var 전체 := W * H
		var 알파있음: bool = (투명 + 반투명) > 0
		var h := _히스토(im, 알파있음)
		var 띠 := _띠(im)
		var 좌우 := _이음매(im, true)
		var 상하 := _이음매(im, false)

		print("\n[%s]" % 경로.get_file())
		print("  해상도        %d x %d   (종횡비 %.3f)" % [W, H, float(W) / float(H)])
		print("  알파          %s   불투명 %.1f%% / 반투명 %.1f%% / 투명 %.1f%%"
			% ["있음" if 알파있음 else "없음(전부 불투명)",
				float(불투명) / 전체 * 100.0, float(반투명) / 전체 * 100.0,
				float(투명) / 전체 * 100.0])
		print("  휘도          평균 %6.2f  min %3d  p05 %3.0f  p50 %3.0f  p95 %3.0f  max %3d"
			% [_평균(h), _최소(h), _분위(h, 0.05), _분위(h, 0.50), _분위(h, 0.95), _최대(h)])
		print("  내부 디테일    p05~p95 = %.0f ~ %.0f  (%d 단계)"
			% [_분위(h, 0.05), _분위(h, 0.95), int(_분위(h, 0.95) - _분위(h, 0.05))])
		if 띠[0] >= 0:
			print("  불투명 띠      행 %d ~ %d  (두께 %d px = 높이의 %.1f%%)"
				% [띠[0], 띠[1], 띠[1] - 띠[0] + 1,
					float(띠[1] - 띠[0] + 1) / float(H) * 100.0])
		else:
			print("  불투명 띠      없음 (행 평균 알파가 0.5 를 넘는 행이 없다)")
		print("  좌우 이음매    끝 %6.3f / 내부 %6.3f = 비율 %5.2f   %s"
			% [좌우[0], 좌우[1], 좌우[2],
				"PASS" if (좌우[2] <= 3.0 or 좌우[0] < 1.0) else "FAIL"])
		print("  상하 이음매    끝 %6.3f / 내부 %6.3f = 비율 %5.2f   %s"
			% [상하[0], 상하[1], 상하[2],
				"PASS" if (상하[2] <= 3.0 or 상하[0] < 1.0) else "FAIL"])
	print("\n" + "=".repeat(100))
	quit(0)
