extends SceneTree
## ============================================================================
## [2026-09-02 신규] 물 그림의 **실루엣을 그대로 판정 폴리곤으로 굽는다** (멱등)
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_유체_판정폴리곤.gd
##   godot --headless --path . -s res://tools/생성_유체_판정폴리곤.gd -- --확인만
##   godot --headless --path . -s res://tools/생성_유체_판정폴리곤.gd -- --단순화=6 --미리보기
##   (--확인만 은 표만 찍고 파일을 안 쓴다 · --미리보기 는 그림 위에 딴 선을 겹친 PNG 를 남긴다)
##
## ▣ 왜 만들었나 (성진님 지시 2026-09-02: "판정 모양이 유체 이미지와 매우 유사하게")
##   여태 물 판정은 **직사각형 3 개**였다 — 물줄기 / 중간 물보라 / 바닥 물보라.
##   그림은 좌우로 굽이치는 물기둥인데 판정은 곧은 기둥이라,
##   물줄기가 왼쪽으로 휜 프레임에서는 **오른쪽 빈 공간에서 죽고**
##   휜 쪽 물에는 몸을 스쳐도 안 죽었다. 색이 곧 규칙인 게임에서
##   "보이는 것과 닿는 것이 다른" 것은 가장 나쁜 거짓말이다(지형 `위치별_판정` 과 같은 이유).
##   → 그림의 알파를 그대로 따 와서 **프레임마다 다른 폴리곤**으로 굽는다.
##
## ▣ 어떻게 따나
##   `BitMap.create_from_image_alpha()` + `opaque_to_polygons()`.
##   에디터의 "Sprite2D → CollisionPolygon2D 만들기" 가 쓰는 바로 그 함수다.
##   점은 **0~1 로 정규화**해서 저장한다(u = px/폭, v = py/높이).
##   유체마다 `크기` 가 다른데(56x300 ~ 300x800) 그림도 같은 비율로 늘려 그리므로,
##   판정도 같은 정규화 좌표를 쓰면 크기와 상관없이 그림과 정확히 겹친다.
##
## ▣ 왜 회색 프레임만 읽나
##   흰색·검정·회색 세 벌은 **같은 실루엣에 색만 다르다**(`유체.gd` 주석과 같은 전제).
##   실제로 이 도구가 세 벌의 알파가 같은지 검사하고, 다르면 경고를 찍는다.
##
## ▣ 튀는 물방울은 왜 버리나
##   바닥 물보라 둘레에 3~10px 짜리 물방울이 흩어져 있다. 그것까지 판정에 넣으면
##   **화면에서 안 보이는 점 하나에 죽는다.** 가장 큰 섬 대비 `최소_면적_비율`
##   미만인 섬은 버린다(기본 2%). 버린 개수는 아래 표에 찍힌다.
## ============================================================================

const 프레임_폴더 := "res://assets/textures/obstacles/liquid/animated_v4"
const 색_이름 := ["gray", "white", "black"]        ## 첫 번째가 기준. 나머지는 실루엣 대조용
const 프레임_수 := 8

## 알파가 이 값 이상인 픽셀만 "물"로 친다. 물 그림은 가장자리가 부드럽게 흐려지는데,
## 0.1 로 잡으면 거의 안 보이는 연무까지 판정에 들어와 그림보다 뚱뚱해진다.
const 기본_알파_문턱 := 0.35
## 외곽선 단순화(px). 크게 줄수록 점이 적고 모양이 뭉툭해진다.
## ★ 점 개수가 곧 비용이다 — `CollisionPolygon2D` 는 점을 넣을 때마다 볼록 분해를 다시 한다.
##   프레임이 바뀔 때(8fps)마다 유체 개수만큼 도니, 50 점 안쪽으로 잡는 게 안전하다.
const 기본_단순화 := 6.0
## 가장 큰 섬 대비 이 비율보다 작은 섬은 버린다(튀는 물방울).
const 최소_면적_비율 := 0.02
## 한 프레임에서 남길 섬의 최대 개수. 판정 노드 개수를 씬에서 고정하기 위한 상한이다.
const 최대_섬 := 3

const 출력_경로 := "res://scripts/스마트월드/유체_판정모양.gd"
const 미리보기_폴더 := "user://유체_판정_미리보기"

var 알파_문턱 := 기본_알파_문턱
var 단순화 := 기본_단순화


func _init() -> void:
	var 인자 := OS.get_cmdline_user_args()
	var 확인만 := 인자.has("--확인만")
	var 미리보기 := 인자.has("--미리보기")
	for a in 인자:
		if a.begins_with("--단순화="):
			단순화 = a.trim_prefix("--단순화=").to_float()
		elif a.begins_with("--문턱="):
			알파_문턱 = a.trim_prefix("--문턱=").to_float()

	var 기준: Array = []          ## [프레임][섬] = PackedVector2Array (정규화)
	var 텍스처_크기 := Vector2i.ZERO
	var 실패 := false

	for f in 프레임_수:
		var 그림 := _프레임_읽기(색_이름[0], f)
		if 그림 == null:
			실패 = true
			break
		if 텍스처_크기 == Vector2i.ZERO:
			텍스처_크기 = 그림.get_size()
		elif 그림.get_size() != 텍스처_크기:
			push_error("프레임 %d 의 크기가 다르다: %s vs %s" % [f, 그림.get_size(), 텍스처_크기])
			실패 = true
			break
		기준.append(_섬들(그림, f))

	if 실패:
		quit(1)
		return

	_실루엣_대조(텍스처_크기)

	print("")
	print("── 굽힌 결과 (텍스처 %dx%d · 알파문턱 %.2f · 단순화 %.1fpx) ──"
			% [텍스처_크기.x, 텍스처_크기.y, 알파_문턱, 단순화])
	print("프레임 | 섬 | 점 | 폭(u) 범위       | 높이(v) 범위")
	for f in 프레임_수:
		var 섬들: Array = 기준[f]
		for i in 섬들.size():
			var p: PackedVector2Array = 섬들[i]
			var 최소 := p[0]
			var 최대 := p[0]
			for v in p:
				최소 = 최소.min(v)
				최대 = 최대.max(v)
			print("  %d    |  %d | %2d | %.3f ~ %.3f | %.3f ~ %.3f"
					% [f, i, p.size(), 최소.x, 최대.x, 최소.y, 최대.y])

	if 미리보기:
		_미리보기_쓰기(기준, 텍스처_크기)

	if 확인만:
		print("\n--확인만 이라 파일은 쓰지 않았다.")
		quit(0)
		return

	_파일_쓰기(기준, 텍스처_크기)
	print("\n★ 썼다: %s" % 출력_경로)
	quit(0)


## 임포트된 텍스처에서 픽셀을 꺼낸다. `Image.load_from_file()` 도 되지만
## "export 에서는 못 읽는다" 경고를 프레임마다 뱉어 로그가 표를 덮는다.
func _프레임_읽기(색: String, 번호: int) -> Image:
	var 경로 := "%s/%s/frame_%02d.png" % [프레임_폴더, 색, 번호]
	var 텍스처 := load(경로) as Texture2D
	if 텍스처 == null:
		push_error("못 읽었다: %s" % 경로)
		return null
	return 텍스처.get_image()


## 딴 선을 원본 위에 겹쳐 그린 PNG. "그림과 판정이 정말 같은가"를 눈으로 보려고 남긴다.
func _미리보기_쓰기(표: Array, 크기: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(미리보기_폴더)
	for f in 표.size():
		var 그림 := _프레임_읽기(색_이름[0], f)
		if 그림 == null:
			continue
		그림.convert(Image.FORMAT_RGBA8)
		for 섬: PackedVector2Array in 표[f]:
			for i in 섬.size():
				_선(그림, 섬[i] * Vector2(크기), 섬[(i + 1) % 섬.size()] * Vector2(크기))
		var 경로 := "%s/frame_%02d.png" % [미리보기_폴더, f]
		그림.save_png(경로)
	print("미리보기: %s" % ProjectSettings.globalize_path(미리보기_폴더))


func _선(그림: Image, a: Vector2, b: Vector2) -> void:
	var 칸 := int(maxf(a.distance_to(b), 1.0)) * 2
	var 크기 := 그림.get_size()
	for i in 칸 + 1:
		var p := a.lerp(b, float(i) / float(칸))
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var x := clampi(int(p.x) + dx, 0, 크기.x - 1)
				var y := clampi(int(p.y) + dy, 0, 크기.y - 1)
				그림.set_pixel(x, y, Color(1.0, 0.2, 0.1, 1.0))


## 한 프레임의 알파를 섬(연결된 덩어리)별 외곽선으로 딴다. 좌표는 0~1 정규화.
func _섬들(그림: Image, 번호: int) -> Array:
	var 비트맵 := BitMap.new()
	비트맵.create_from_image_alpha(그림, 알파_문턱)
	var 크기 := 그림.get_size()
	var 날것 := 비트맵.opaque_to_polygons(Rect2i(Vector2i.ZERO, 크기), 단순화)

	# 면적으로 줄 세운 뒤 큰 것부터 남긴다.
	var 재료: Array = []
	for p: PackedVector2Array in 날것:
		if p.size() < 3:
			continue
		재료.append({"점": p, "면적": absf(_면적(p))})
	재료.sort_custom(func(a, b): return a["면적"] > b["면적"])
	if 재료.is_empty():
		push_error("프레임 %d 에서 알파를 못 찾았다" % 번호)
		return []

	var 가장_큰: float = 재료[0]["면적"]
	var 남긴: Array = []
	var 버린 := 0
	for r in 재료:
		if 남긴.size() >= 최대_섬 or r["면적"] < 가장_큰 * 최소_면적_비율:
			버린 += 1
			continue
		남긴.append(_정규화(r["점"], 크기))
	if 버린 > 0:
		print("프레임 %d: 작은 섬 %d 개를 버렸다(물방울)" % [번호, 버린])
	return 남긴


func _면적(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


func _정규화(p: PackedVector2Array, 크기: Vector2i) -> PackedVector2Array:
	var 결과 := PackedVector2Array()
	결과.resize(p.size())
	for i in p.size():
		결과[i] = Vector2(p[i].x / float(크기.x), p[i].y / float(크기.y))
	return 결과


## 흰색·검정 프레임의 알파가 회색과 같은지 본다. 다르면 이 표 하나를 공용으로 쓸 수 없다.
func _실루엣_대조(크기: Vector2i) -> void:
	for 색 in 색_이름.slice(1):
		for f in 프레임_수:
			var 기준 := _프레임_읽기(색_이름[0], f)
			var 비교 := _프레임_읽기(색, f)
			if 기준 == null or 비교 == null or 비교.get_size() != 크기:
				push_warning("%s frame_%02d: 크기가 달라 대조를 건너뛴다" % [색, f])
				continue
			var 다름 := 0
			for y in range(0, 크기.y, 4):        # 4px 격자로 훑는다. 전수 검사는 느리고 불필요하다
				for x in range(0, 크기.x, 4):
					var a := 기준.get_pixel(x, y).a >= 알파_문턱
					var b := 비교.get_pixel(x, y).a >= 알파_문턱
					if a != b:
						다름 += 1
			if 다름 > 0:
				push_warning("%s frame_%02d 의 실루엣이 회색과 %d 칸 다르다" % [색, f, 다름])


func _파일_쓰기(표: Array, 텍스처_크기: Vector2i) -> void:
	var 줄: Array[String] = []
	줄.append("## ⚠ 이 파일은 `tools/생성_유체_판정폴리곤.gd` 가 만든다. **손으로 고치지 말 것.**")
	줄.append("## 물 그림(animated_v4)의 알파 실루엣을 프레임마다 판정 폴리곤으로 딴 것이다.")
	줄.append("##   · 좌표는 0~1 정규화. u = 텍스처x/%d, v = 텍스처y/%d" % [텍스처_크기.x, 텍스처_크기.y])
	줄.append("##   · 노드 로컬로 옮기는 식은 `유체.gd::_정규화_점_옮기기()` 에 있다.")
	줄.append("##   · 알파문턱 %.2f · 단순화 %.1fpx · 작은 섬 버림(가장 큰 섬의 %.0f%% 미만)"
			% [알파_문턱, 단순화, 최소_면적_비율 * 100.0])
	줄.append("class_name 유체판정모양")
	줄.append("")
	줄.append("## [프레임][섬] = 정규화 폴리곤. 프레임마다 섬 개수가 다르다.")
	줄.append("const 프레임_수: int = %d" % 프레임_수)
	줄.append("const 최대_섬: int = %d" % 최대_섬)
	줄.append("")
	줄.append("static var _표: Array = []")
	줄.append("")
	줄.append("")
	줄.append("## 프레임 번호로 정규화 폴리곤 묶음을 준다. 표는 한 번만 만들어 정적으로 나눠 쓴다.")
	줄.append("static func 프레임(번호: int) -> Array:")
	줄.append("\tif _표.is_empty():")
	줄.append("\t\t_표 = _만들기()")
	줄.append("\treturn _표[clampi(번호, 0, 프레임_수 - 1)]")
	줄.append("")
	줄.append("")
	줄.append("static func _만들기() -> Array:")
	줄.append("\treturn [")
	for f in 표.size():
		줄.append("\t\t[  # %d 번 프레임" % f)
		for 섬: PackedVector2Array in 표[f]:
			줄.append("\t\t\tPackedVector2Array([")
			줄.append_array(_점_줄들(섬))
			줄.append("\t\t\t]),")
		줄.append("\t\t],")
	줄.append("\t]")
	줄.append("")

	var 파일 := FileAccess.open(출력_경로, FileAccess.WRITE)
	if 파일 == null:
		push_error("못 썼다: %s" % 출력_경로)
		return
	파일.store_string("\n".join(줄))
	파일.close()


## 한 줄에 4 점씩 끊는다. 한 줄에 다 붙이면 1300 자짜리 줄이 되어 사람이 못 읽는다.
func _점_줄들(p: PackedVector2Array) -> Array[String]:
	var 결과: Array[String] = []
	var 조각: Array[String] = []
	for i in p.size():
		조각.append("Vector2(%.4f, %.4f)," % [p[i].x, p[i].y])
		if 조각.size() == 4 or i == p.size() - 1:
			결과.append("\t\t\t\t" + " ".join(조각))
			조각.clear()
	return 결과
