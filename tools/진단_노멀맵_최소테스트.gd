extends SceneTree
## ============================================================================
## [2026-09-05 임시 · 노멀맵 검증] 최소 재현 테스트
## ----------------------------------------------------------------------------
## 실행:
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . \
##         -s res://tools/진단_노멀맵_최소테스트.gd -- <저장폴더>
##
## ▣ 왜 이걸 먼저 하나 (지시서 §11-5 · §11-10)
##   SS2D 는 지형을 `RenderingServer.canvas_item_add_mesh(item, mesh, xform, color, texture_rid)`
##   로 그린다(`addons/rmsmartshape/shape_renderer.gd:61`). 여기에 **CanvasTexture 의 RID** 를
##   넘겼을 때 노멀맵이 실제로 먹히는지가 이번 작업 전체의 전제다.
##
## ▣ 비교하는 세 가지
##   ① Sprite2D + CanvasTexture               (Godot 표준 경로)
##   ② RenderingServer + mesh + CanvasTexture (SS2D 와 **똑같은** 경로)
##   ③ RenderingServer + mesh + 그냥 Texture2D (노멀맵 없음 = 대조군)
##
## ▣ 측정 방법 — 패널마다 **같은 조건**으로 잰다
##   ⚠ 처음엔 화면 좌/우 끝에 빛을 한 번씩만 두고 세 패널을 동시에 쟀는데,
##     그러면 패널마다 빛까지의 거리가 달라서 비교가 성립하지 않는다(가운데 패널은
##     양쪽 다 빛이 거의 안 닿아 "반응 0" 으로 나왔다).
##   → 이제 **패널마다** 그 패널의 왼쪽/오른쪽 같은 거리에 빛을 놓고 두 장을 찍는다.
##
## ▣ 판정 지표
##   두 장의 밝기 차에서 **열(column) 평균**을 빼 "빛이 옮겨가서 생긴 완만한 그라데이션"을
##   제거한다. 남는 잔차 = 벽돌 하나하나의 국소 명암 변화 = 노멀맵 반응.
##
## ▣ height 를 같이 재는 이유
##   Godot 2D 라이트는 `height` 가 0 이면 광원이 표면과 **같은 평면**에 있는 것으로 계산한다.
##   그러면 화면 밖(+Z)을 향하는 노멀은 빛을 거의 못 받는다 — 노멀맵을 넣어도 어두워지기만 한다.
##   그래서 height 0 / 0.5 / 1.0 을 나란히 재서 어느 값이 필요한지 같이 확인한다.
## ============================================================================

const 디퓨즈 := "res://assets/tileset/brick_black_seamless_341x307.png"
const 노멀 := "res://assets/png/brick_black_seamless_341x307_normal.png"

const 패널_크기 := Vector2(360, 360)
const 패널_y := 200.0
const 패널_x := [140.0, 620.0, 1100.0]
const 이름 := ["① Sprite2D + CanvasTexture      ",
	"② RS mesh + CanvasTexture (SS2D)",
	"③ RS mesh + 노멀 없음 (대조군)     "]
## 빛을 패널 중심에서 좌/우로 이만큼 떼어 놓는다(비스듬히 들어가게).
const 빛_거리 := Vector2(230.0, -110.0)

var _빛: PointLight2D = null
## ⚠ RenderingServer 에 넘긴 메시는 **여기서 참조를 붙들어야** 한다.
##   지역 변수로 두면 함수가 끝나며 Ref 가 풀려 RID 가 죽고
##   "Parameter mesh is null" 만 뜨면서 아무것도 안 그려진다.
##   (SS2D 도 같은 이유로 `_meshes` 배열에 SS2D_Mesh 를 담아 둔다)
var _메시들: Array[ArrayMesh] = []
var _아이템들: Array[RID] = []
var _저장 := ""


func _init() -> void: call_deferred("_go")


func _go() -> void:
	_저장 = OS.get_cmdline_user_args()[0]
	var 뿌리 := Node2D.new()
	root.add_child(뿌리)
	current_scene = 뿌리

	# 환경광을 낮춰야 라이트가 보인다 (게임의 `어둠` CanvasModulate 과 같은 역할)
	var 어둠 := CanvasModulate.new()
	어둠.color = Color(0.22, 0.22, 0.22)
	뿌리.add_child(어둠)

	var d := load(디퓨즈) as Texture2D
	var n := load(노멀) as Texture2D
	print("디퓨즈 = %s %s" % [d.resource_path.get_file(), d.get_size()])
	print("노멀   = %s %s" % [n.resource_path.get_file(), n.get_size()])

	var ct := CanvasTexture.new()
	ct.diffuse_texture = d
	ct.normal_texture = n

	var s := Sprite2D.new()
	s.texture = ct
	s.centered = false
	s.position = Vector2(패널_x[0], 패널_y)
	s.scale = 패널_크기 / d.get_size()
	뿌리.add_child(s)

	_사각_메시(뿌리, Vector2(패널_x[1], 패널_y), ct)
	_사각_메시(뿌리, Vector2(패널_x[2], 패널_y), d)

	_빛 = PointLight2D.new()
	_빛.texture = _빛_텍스처()
	_빛.energy = 3.0
	_빛.texture_scale = 2.6
	뿌리.add_child(_빛)
	for _i in 20: await process_frame

	# ── 빛을 멀리 치운 "무조명" 기준 사진 ──
	#   ★이게 있어야 **조명 성분만** 뽑아낼 수 있다.
	#     밝기 차이를 그냥 재면 텍스처 자체의 밝고 어두움에 지표가 오염된다
	#     (밝은 줄눈은 크게, 검은 벽돌은 작게 변해서 노멀맵 없이도 잔차가 나온다).
	#   → 각 사진을 이 기준 사진으로 나누면 남는 것은 "그 픽셀이 받은 빛의 배수"뿐이다.
	_빛.global_position = Vector2(-9000, -9000)
	for _i in 12: await process_frame
	var 기준사진 := root.get_texture().get_image()

	for 높이 in [0.0, 32.0, 128.0, 400.0]:
		_빛.height = 높이
		print("\n════ PointLight2D.height = %.0f ════" % 높이)
		var 값: Array[float] = []
		for i in 3:
			var 틀 := Rect2i(int(패널_x[i]) + 20, int(패널_y) + 20,
				int(패널_크기.x) - 40, int(패널_크기.y) - 40)
			var 중심 := Vector2(패널_x[i], 패널_y) + 패널_크기 * 0.5
			var 사진: Array[Image] = []
			for 쪽 in [-1.0, 1.0]:
				_빛.global_position = 중심 + Vector2(빛_거리.x * 쪽, 빛_거리.y)
				for _i2 in 10: await process_frame
				var img := root.get_texture().get_image()
				사진.append(img)
				if 높이 == 128.0:   # 대표 스크린샷 한 장씩 남긴다
					img.get_region(_넉넉히(틀)).save_png("%s/probe_h128_panel%d_%s.png" % [
						_저장, i + 1, ("L" if 쪽 < 0.0 else "R")])
			var r := _조명_잔차_RMS(사진[0], 사진[1], 기준사진, 틀)
			var 밝기 := (_평균밝기(사진[0], 틀) + _평균밝기(사진[1], 틀)) * 0.5
			값.append(r)
			print("  %s  평균밝기 %.4f   조명잔차 = %.5f" % [이름[i], 밝기, r])
		var 기준 := maxf(값[2] * 2.0, 0.01)
		print("  기준선(대조군×2, 최소 0.01) = %.5f" % 기준)
		print("    ① 표준 경로 : %s" % ("반응함 ✔" if 값[0] > 기준 else "반응 없음 ✗"))
		print("    ② SS2D 경로 : %s" % ("반응함 ✔" if 값[1] > 기준 else "반응 없음 ✗"))
	quit()


func _넉넉히(틀: Rect2i) -> Rect2i:
	return Rect2i(틀.position - Vector2i(20, 20), 틀.size + Vector2i(40, 40))


## RenderingServer 로 사각형 메시를 하나 그린다 — SS2D 의 `shape_renderer.gd` 와 같은 방식.
func _사각_메시(부모: Node2D, 위치: Vector2, 텍스처: Texture2D) -> void:
	var 노드 := Node2D.new()
	부모.add_child(노드)
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, 노드.get_canvas_item())
	RenderingServer.canvas_item_set_default_texture_repeat(
		item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	_아이템들.append(item)

	var 점 := PackedVector2Array([
		위치, 위치 + Vector2(패널_크기.x, 0), 위치 + 패널_크기, 위치 + Vector2(0, 패널_크기.y)])
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var 색 := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var 인덱스 := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = 점
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv
	arrays[Mesh.ARRAY_COLOR] = 색
	arrays[Mesh.ARRAY_INDEX] = 인덱스

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_메시들.append(mesh)                                   # ★참조를 붙들어 둔다
	RenderingServer.canvas_item_add_mesh(
		item, mesh.get_rid(), Transform2D(), Color.WHITE, 텍스처.get_rid())


## 두 사진의 밝기 차에서 **열 평균(빛 이동으로 생긴 완만한 그라데이션)** 을 뺀 잔차의 RMS.
func _국소_변화_RMS(a: Image, b: Image, 틀: Rect2i) -> float:
	틀 = 틀.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	if 틀.size.x <= 0 or 틀.size.y <= 0:
		return 0.0
	var 차: Array[PackedFloat32Array] = []
	var 열평균 := PackedFloat32Array()
	열평균.resize(틀.size.x)
	for ix in 틀.size.x:
		var 열 := PackedFloat32Array()
		열.resize(틀.size.y)
		var 합 := 0.0
		for iy in 틀.size.y:
			var ca := a.get_pixel(틀.position.x + ix, 틀.position.y + iy)
			var cb := b.get_pixel(틀.position.x + ix, 틀.position.y + iy)
			var dd := (ca.r + ca.g + ca.b) / 3.0 - (cb.r + cb.g + cb.b) / 3.0
			열[iy] = dd
			합 += dd
		차.append(열)
		열평균[ix] = 합 / float(틀.size.y)
	var 제곱합 := 0.0
	for ix in 틀.size.x:
		for iy in 틀.size.y:
			var r := 차[ix][iy] - 열평균[ix]
			제곱합 += r * r
	return sqrt(제곱합 / float(틀.size.x * 틀.size.y))


func _평균밝기(img: Image, 틀: Rect2i) -> float:
	틀 = 틀.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var 합 := 0.0
	var 수 := 0
	for x in range(틀.position.x, 틀.end.x):
		for y in range(틀.position.y, 틀.end.y):
			var c := img.get_pixel(x, y)
			합 += (c.r + c.g + c.b) / 3.0
			수 += 1
	return 합 / float(maxi(수, 1))


## 부드러운 원형 라이트 텍스처 (zone_visuals.gd 와 같은 방식)
func _빛_텍스처() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t


## ★조명 성분만 뽑아 국소 변화를 잰다.
##
## 각 픽셀의 "받은 빛 배수" = 켠 사진 / 무조명 사진.
## 두 빛 위치의 배수 차이에서 **열 평균**(빛이 옮겨가며 생기는 완만한 그라데이션)을 빼면,
## 남는 것은 픽셀마다 방향이 다른 **표면 요철 반응**뿐이다.
##   · 노멀맵 있음 → 벽돌 모서리마다 값이 튀어 잔차가 크다
##   · 노멀맵 없음 → 빛은 모든 픽셀을 똑같은 배수로 밝히므로 잔차가 0 에 가깝다
func _조명_잔차_RMS(a: Image, b: Image, 바탕: Image, 틀: Rect2i) -> float:
	틀 = 틀.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	if 틀.size.x <= 0 or 틀.size.y <= 0:
		return 0.0
	var 차: Array[PackedFloat32Array] = []
	var 열평균 := PackedFloat32Array()
	열평균.resize(틀.size.x)
	for ix in 틀.size.x:
		var 열 := PackedFloat32Array()
		열.resize(틀.size.y)
		var 합 := 0.0
		for iy in 틀.size.y:
			var x := 틀.position.x + ix
			var y := 틀.position.y + iy
			var lb := _밝기(바탕.get_pixel(x, y))
			# 너무 어두운 픽셀은 나눗셈이 폭발하므로 건너뛴다(값 0 으로 둔다).
			var dd := 0.0
			if lb > 0.01:
				dd = _밝기(a.get_pixel(x, y)) / lb - _밝기(b.get_pixel(x, y)) / lb
			열[iy] = dd
			합 += dd
		차.append(열)
		열평균[ix] = 합 / float(틀.size.y)
	var 제곱합 := 0.0
	for ix in 틀.size.x:
		for iy in 틀.size.y:
			var r := 차[ix][iy] - 열평균[ix]
			제곱합 += r * r
	return sqrt(제곱합 / float(틀.size.x * 틀.size.y))


func _밝기(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0
