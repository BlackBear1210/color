extends SceneTree
## [2026-08-25 신규] 코너 후광 실험용 실렌더 비교판.
## 여러 머티리얼(.tres)을 같은 도형·같은 프레이밍으로 한 화면에 깔고 PNG 로 뽑는다.
## ⚠ --headless 금지 (더미 렌더러라 그림이 안 나온다).
##
## 실행:
##   Godot --path . -s res://tools/실험_코너_렌더.gd -- \
##       --머티=이름:res://..../x.tres  (반복)  --출력=res://tools/_shots/x.png
##       [--줌=2.0] [--배경=0.72] [--칸=512]

var _이름들: PackedStringArray = PackedStringArray()
var _경로들: PackedStringArray = PackedStringArray()
var _출력 := "res://tools/_shots/코너_렌더비교.png"
var _줌 := 2.0
var _배경 := 0.72
var _칸 := 512.0
## 도형: ㄱ자(기본) / 세로벽(세로 반복 확인) / 가로벽 / 원
var _도형 := "ㄱ자"

const 지형_S := preload("res://scripts/스마트월드/지형.gd")


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--머티="):
			var v := a.substr("--머티=".length())
			var i := v.find(":")
			_이름들.push_back(v.substr(0, i))
			_경로들.push_back(v.substr(i + 1))
		elif a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length())
		elif a.begins_with("--줌="):
			_줌 = a.substr("--줌=".length()).to_float()
		elif a.begins_with("--배경="):
			_배경 = a.substr("--배경=".length()).to_float()
		elif a.begins_with("--칸="):
			_칸 = a.substr("--칸=".length()).to_float()
		elif a.begins_with("--도형="):
			_도형 = a.substr("--도형=".length())
	call_deferred("_실행")


## ㄱ 자 — 볼록 코너 5개 + 오목 코너 1개가 한 번에 보인다
func _ㄱ자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


## 도형 선택 — 재질마다 확인해야 할 것이 다르다.
##   세로벽: SIDE 원본이 세로로 반복될 때 이질적인 단이 생기는지 (하수 SIDE 점검용)
##   가로벽: TOP/BOTTOM 이 가로로 반복될 때 이음매가 보이는지
func _점들() -> PackedVector2Array:
	match _도형:
		"세로벽":
			return PackedVector2Array([Vector2(0, 0), Vector2(260, 0),
				Vector2(260, 1500), Vector2(0, 1500)])
		"가로벽":
			return PackedVector2Array([Vector2(0, 0), Vector2(1500, 0),
				Vector2(1500, 260), Vector2(0, 260)])
		"ㄷ자":
			return PackedVector2Array([Vector2(0, 0), Vector2(700, 0), Vector2(700, 250),
				Vector2(250, 250), Vector2(250, 450), Vector2(700, 450),
				Vector2(700, 700), Vector2(0, 700)])
		"1x5":
			return PackedVector2Array([Vector2(0, 0), Vector2(640, 0),
				Vector2(640, 128), Vector2(0, 128)])
		"2x4":
			return PackedVector2Array([Vector2(0, 0), Vector2(512, 0),
				Vector2(512, 256), Vector2(0, 256)])
		"4x4":
			return PackedVector2Array([Vector2(0, 0), Vector2(512, 0),
				Vector2(512, 512), Vector2(0, 512)])
		"원":
			var p := PackedVector2Array()
			for i in 24:
				var ang: float = TAU * float(i) / 24.0
				p.push_back(Vector2(280.0 + cos(ang) * 260.0, 280.0 + sin(ang) * 260.0))
			return p
		_:
			return _ㄱ자(340.0, 340.0, 150.0)


func _실행() -> void:
	var n := _이름들.size()
	if n == 0:
		push_error("--머티=이름:경로 가 필요하다")
		quit(1)
		return
	var 열: int = int(ceil(sqrt(float(n))))
	var 행: int = int(ceil(float(n) / float(열)))
	var 폭: int = int(_칸 * _줌) * 열
	var 높이: int = int(_칸 * _줌) * 행

	root.content_scale_size = Vector2i(폭, 높이)
	DisplayServer.window_set_size(Vector2i(폭, 높이))

	var r := Node2D.new()
	root.add_child(r)

	var bg := ColorRect.new()
	bg.position = Vector2(-_칸, -_칸)
	bg.size = Vector2(_칸 * float(열 + 2), _칸 * float(행 + 2))
	bg.color = Color(_배경, _배경, _배경)
	bg.z_index = -100
	r.add_child(bg)

	for i in n:
		var cx: float = float(i % 열) * _칸
		var cy: float = float(i / 열) * _칸
		var m: Resource = load(_경로들[i])
		if m == null:
			push_warning("머티 로드 실패 %s" % _경로들[i])
			continue
		var s = 지형_S.new()
		s.name = "V%d" % i
		s.position = Vector2(cx + 90.0, cy + 90.0)
		s.shape_material = m
		s.시작상태 = 0
		r.add_child(s)
		var pa: SS2D_Point_Array = s.get_point_array()
		pa.begin_update()
		pa.add_points(_점들())
		pa.end_update()
		pa.close_shape()
		s.force_update()

		var l := Label.new()
		l.position = Vector2(cx + 12.0, cy + 8.0)
		l.text = _이름들[i]
		l.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
		l.add_theme_font_size_override("font_size", 22)
		r.add_child(l)

	var cam := Camera2D.new()
	cam.position = Vector2(_칸 * float(열) * 0.5, _칸 * float(행) * 0.5)
	cam.zoom = Vector2(_줌, _줌)
	r.add_child(cam)
	cam.make_current()

	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = root.get_texture().get_image()
	var 절대 := ProjectSettings.globalize_path(_출력)
	DirAccess.make_dir_recursive_absolute(절대.get_base_dir())
	if img.save_png(절대) != OK:
		push_error("저장 실패")
		quit(1)
		return
	print("[렌더] %s  %dx%d  줌 %.2f  칸 %.0f" % [_출력, img.get_width(), img.get_height(), _줌, _칸])
	quit(0)
