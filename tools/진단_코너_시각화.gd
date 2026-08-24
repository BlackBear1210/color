extends SceneTree
## [2026-08-25 신규] 코너 PNG 를 눈으로 보기 위한 패널 생성기.
## 알파가 옅은 후광은 그냥 열어 보면 안 보인다. 그래서 세 가지로 같이 깐다:
##   1) 밝은 배경 위 합성 (후광은 배경보다 어두운 얼룩으로 드러난다)
##   2) 알파맵 (원본 알파)
##   3) 알파 x4 증폭 (0<a<64 인 잔여를 눈에 보이게)
## 실행: --폴더=... [--접두어=] --출력=res://tools/_shots/코너_비교.png

var _폴더들: PackedStringArray = PackedStringArray()
var _이름들: PackedStringArray = PackedStringArray()
var _접두어 := ""
var _출력 := "res://tools/_shots/코너_비교.png"
const 타일 := 256


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--폴더="):
			var v := a.substr("--폴더=".length()).rstrip("/")
			_폴더들.push_back(v)
			_이름들.push_back(v.get_file())
		elif a.begins_with("--접두어="):
			_접두어 = a.substr("--접두어=".length())
		elif a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length())
	call_deferred("_실행")


func _png(경로: String) -> Image:
	var b := FileAccess.get_file_as_bytes(경로)
	if b.is_empty():
		return null
	var im := Image.new()
	if im.load_png_from_buffer(b) != OK:
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _붙임(판: Image, 조각: Image, ox: int, oy: int) -> void:
	판.blit_rect(조각, Rect2i(0, 0, 조각.get_width(), 조각.get_height()), Vector2i(ox, oy))


## 밝은 배경 위 합성 — 배경보다 어두워지는 영역이 곧 후광이다
func _합성(im: Image, 배경: float) -> Image:
	var o := Image.create(타일, 타일, false, Image.FORMAT_RGBA8)
	for y in 타일:
		for x in 타일:
			var c := im.get_pixel(x, y)
			var v: float = c.r * c.a + 배경 * (1.0 - c.a)
			o.set_pixel(x, y, Color(v, v, v, 1.0))
	return o


func _알파맵(im: Image, 증폭: float) -> Image:
	var o := Image.create(타일, 타일, false, Image.FORMAT_RGBA8)
	for y in 타일:
		for x in 타일:
			var a: float = clampf(im.get_pixel(x, y).a * 증폭, 0.0, 1.0)
			o.set_pixel(x, y, Color(a, a, a, 1.0))
	return o


func _실행() -> void:
	var 행 := _폴더들.size()
	var 판 := Image.create(타일 * 6, 타일 * 행, false, Image.FORMAT_RGBA8)
	판.fill(Color(0.15, 0.15, 0.18, 1.0))
	for i in 행:
		var oy := i * 타일
		var col := 0
		for 쌍 in [["corner_outer"], ["corner_inner"]]:
			var c := _png("%s/black/%s%s.png" % [_폴더들[i], _접두어, 쌍[0]])
			if c == null:
				col += 3
				continue
			var s: Image = c.duplicate()
			s.resize(타일, 타일, Image.INTERPOLATE_LANCZOS)
			_붙임(판, _합성(s, 0.72), col * 타일, oy)        # 밝은 배경
			_붙임(판, _알파맵(s, 1.0), (col + 1) * 타일, oy)  # 알파
			_붙임(판, _알파맵(s, 4.0), (col + 2) * 타일, oy)  # 알파 x4
			col += 3
		print("행 %d = %s" % [i, _이름들[i]])
	var 절대 := ProjectSettings.globalize_path(_출력)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	판.save_png(절대)
	print("저장 %s  (%dx%d)  열: OUTER[합성|알파|알파x4] INNER[합성|알파|알파x4]"
		% [_출력, 판.get_width(), 판.get_height()])
	quit(0)
