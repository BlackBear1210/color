extends SceneTree
## ============================================================================
## [2026-08-25 신규] 원본 FILL 의 **무늬 주기만** 바꾼다 (디자인은 그대로)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/보정_원본_스케일.gd -- \
##       --입력=res://.../master_fill.png --세로켜=15 --목표세로켜=19 \
##       --가로칸=13 --목표가로칸=14 [--출력=...]
##
## ▣ 왜 다시 생성하지 않고 이걸 쓰나
##   이미지 생성 모델에 "켜 19개" 를 요청해도 12개, 15개가 나온다. 몇 번을 돌려도
##   ±5% 안에 넣을 수 없고, 다시 그릴 때마다 **승인된 디자인이 조금씩 흔들린다.**
##   여기서 필요한 것은 새 그림이 아니라 같은 그림의 **주기 변경**뿐이므로
##   원본을 주기 단위로 다시 샘플링한다. 그림·톤·질감은 하나도 안 바뀐다.
##
## ▣ 이음매(seamless)를 지키는 조건
##   FILL 은 상하좌우로 타일링된다. 원본이 한 변에 정확히 N 주기를 담고 있다면,
##   출력에 M 주기를 담도록 샘플링해도 **M 이 정수이면** 경계가 다시 주기 경계에
##   떨어지므로 이음매가 유지된다. 그래서 목표를 '정수 주기' 로만 받는다.
##   (가로·세로 배율이 서로 달라도 된다 — 벽돌 비율을 엣지에 맞추는 데 오히려 필요하다)
##
## ▣ 끝나면 이음매를 실제로 검사해서 찍는다 (믿지 말고 확인).
## ============================================================================

var _입력 := ""
var _출력 := ""
var _세로켜 := 0
var _목표세로켜 := 0
var _가로칸 := 0
var _목표가로칸 := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--입력="): _입력 = a.substr("--입력=".length())
		elif a.begins_with("--출력="): _출력 = a.substr("--출력=".length())
		elif a.begins_with("--세로켜="): _세로켜 = a.substr("--세로켜=".length()).to_int()
		elif a.begins_with("--목표세로켜="): _목표세로켜 = a.substr("--목표세로켜=".length()).to_int()
		elif a.begins_with("--가로칸="): _가로칸 = a.substr("--가로칸=".length()).to_int()
		elif a.begins_with("--목표가로칸="): _목표가로칸 = a.substr("--목표가로칸=".length()).to_int()
	call_deferred("_실행")


## 순환 바이리니어 샘플 (경계에서 반대편으로 감는다)
func _샘플(im: Image, u: float, v: float) -> Color:
	var W := im.get_width()
	var H := im.get_height()
	var x := u - 0.5
	var y := v - 0.5
	var x0 := int(floor(x)); var y0 := int(floor(y))
	var fx := x - float(x0); var fy := y - float(y0)
	var x0m := ((x0 % W) + W) % W
	var x1m := (((x0 + 1) % W) + W) % W
	var y0m := ((y0 % H) + H) % H
	var y1m := (((y0 + 1) % H) + H) % H
	var a := im.get_pixel(x0m, y0m).lerp(im.get_pixel(x1m, y0m), fx)
	var b := im.get_pixel(x0m, y1m).lerp(im.get_pixel(x1m, y1m), fx)
	return a.lerp(b, fy)


## 상하좌우 이음매 검사 — 감아 붙였을 때의 차이를 '보통 이웃 열 차이' 와 비교한다.
func _이음매검사(im: Image, 이름: String) -> void:
	var W := im.get_width()
	var H := im.get_height()
	var 감김_가로 := 0.0
	var 보통_가로 := 0.0
	for y in H:
		감김_가로 += absf(im.get_pixel(W - 1, y).r - im.get_pixel(0, y).r)
		보통_가로 += absf(im.get_pixel(W / 2, y).r - im.get_pixel(W / 2 + 1, y).r)
	var 감김_세로 := 0.0
	var 보통_세로 := 0.0
	for x in W:
		감김_세로 += absf(im.get_pixel(x, H - 1).r - im.get_pixel(x, 0).r)
		보통_세로 += absf(im.get_pixel(x, H / 2).r - im.get_pixel(x, H / 2 + 1).r)
	print("  [%s] 이음매 가로 %.2f (보통 %.2f · 비 %.2f)   세로 %.2f (보통 %.2f · 비 %.2f)"
		% [이름,
			감김_가로 / H * 255.0, 보통_가로 / H * 255.0,
			감김_가로 / maxf(보통_가로, 0.0001),
			감김_세로 / W * 255.0, 보통_세로 / W * 255.0,
			감김_세로 / maxf(보통_세로, 0.0001)])


func _실행() -> void:
	if _입력.is_empty() or _세로켜 <= 0 or _목표세로켜 <= 0:
		push_error("--입력= --세로켜= --목표세로켜= 가 필요하다")
		quit(1); return
	if _가로칸 <= 0: _가로칸 = _세로켜
	if _목표가로칸 <= 0: _목표가로칸 = _목표세로켜

	var b := FileAccess.get_file_as_bytes(_입력)
	if b.is_empty():
		push_error("원본 없음: %s" % _입력); quit(1); return
	var src := Image.new()
	src.load_png_from_buffer(b)
	src.convert(Image.FORMAT_RGBA8)
	var W := src.get_width()
	var H := src.get_height()

	var kx: float = float(_목표가로칸) / float(_가로칸)
	var ky: float = float(_목표세로켜) / float(_세로켜)
	print("입력 %s  %dx%d" % [_입력.get_file(), W, H])
	print("  가로 %d칸 -> %d칸 (배율 %.4f)   세로 %d켜 -> %d켜 (배율 %.4f)"
		% [_가로칸, _목표가로칸, kx, _세로켜, _목표세로켜, ky])
	_이음매검사(src, "보정 전")

	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v: float = (float(y) + 0.5) * ky
		for x in W:
			var u: float = (float(x) + 0.5) * kx
			out.set_pixel(x, y, _샘플(src, u, v))
	_이음매검사(out, "보정 후")

	var 경로 := _출력 if not _출력.is_empty() else _입력
	var 절대 := ProjectSettings.globalize_path(경로)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	if out.save_png(절대) != OK:
		push_error("저장 실패"); quit(1); return
	print("저장 %s" % 경로)
	quit(0)
