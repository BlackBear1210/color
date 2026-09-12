extends SceneTree
## ============================================================================
## [2026-09-05 신규] 지형 채우기 텍스처 → 노멀맵 + CanvasTexture(.tres) 굽기
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_지형_노멀맵.gd
##   godot --headless --path . -s res://tools/생성_지형_노멀맵.gd -- --조사
##
## ▣ ★원본 보호 (지시서 §0)
##   **기존 diffuse PNG 는 한 바이트도 안 건드린다.** 읽기만 한다.
##   여기서 만드는 것은 (ㄱ) 새 노멀맵 PNG, (ㄴ) 그 둘을 묶는 CanvasTexture .tres
##   두 가지뿐이고, 전부 **새 폴더**(`<재질>/노멀/`)에 들어간다.
##   타일 그림을 새로 그리거나 AI 로 다시 만들지 않는다 —
##   노멀맵은 **그 diffuse 자신의 명암에서 기울기를 뽑은 파생물**이다.
##
## ▣ 왜 소벨(명도 → 기울기)인가
##   프로젝트에 이미 같은 방식의 `tools/generate_normal_maps.gd` 가 있고
##   (배경·프롭용), 그 결과가 `zone_visuals.gd` 에서 쓰이고 있다.
##   같은 방식을 쓰면 배경과 지형의 요철 느낌이 어긋나지 않는다.
##
## ▣ 크기·UV
##   노멀맵은 **원본과 완전히 같은 픽셀 크기**로 만든다.
##   (2026-09-05 BRICK 작업에서 크기가 다른 노멀맵을 잘못 물려 UV 가 어긋난 적이 있다)
##
## ▣ 흑↔백 짝 (지시서 §5)
##   `지형.gd` 의 `_짝_찾기()` 는 텍스처 `resource_path` 의 파일명에서
##   `black ↔ white` 토큰을 바꿔 반대색 아트를 찾는다.
##   → 만드는 .tres 이름을 `<재질>_노멀_black.tres` / `..._white.tres` 로 맞춘다.
##     같은 폴더에 둘이 나란히 있어야 짝 찾기가 성공한다(실패하면 페인트가
##     밝기 반전 폴백으로 떨어져 칠하기 표현이 달라진다).
## ============================================================================

## [이름, 검정 diffuse, 흰색 diffuse, 세기, 저장 폴더]
##   세기 = 소벨 기울기 배율. 클수록 요철이 심하다.
##   ★값은 조명 실험실에서 화면을 보고 골랐다 — 벽돌(수제 노멀맵)과 같은 정도로
##     보이는 지점이 기준이고, 넘기면 돌이 아니라 플라스틱처럼 번들거린다.
const 대상 := [
	{
		# ★벽돌만 노멀맵을 **새로 굽지 않는다.** 2026-09-05 에 texturemap.app 으로 만든
		#   수제 노멀맵이 이미 있고, 그게 실런타임 검증을 통과한 기준선이다.
		#   여기서 소벨로 다시 뽑으면 그 기준선이 사라진다 → `노멀_직접` 으로 재사용한다.
		#   흑·백 두 디퓨즈가 같은 요철을 그린 그림이라 노멀맵도 같은 것을 쓴다.
		"이름": "벽돌", "세기": 0.0,
		"노멀_직접": "res://assets/png/brick_black_seamless_341x307_normal.png",
		"black": "res://assets/tileset/brick_black_seamless_341x307.png",
		"white": "res://assets/tileset/brick_white_seamless_341x307.png",
		"폴더": "res://assets/textures/smartshape/brick_v2_opaque/노멀",
	},
	{
		"이름": "나무", "세기": 1.6,   ## 2.0 은 넓은 발판에서 반복 패턴(타일 이음)이 눈에 띄었다
		"black": "res://assets/textures/smartshape/wood_v2/black/fill_detail.png",
		"white": "res://assets/textures/smartshape/wood_v2/white/fill_detail.png",
		"폴더": "res://assets/textures/smartshape/wood_v2/노멀",
	},
	{
		"이름": "잔디", "세기": 0.9,   ## 잔디 채우기는 고주파 노이즈라 세기를 올리면 사포처럼 자글거린다
		"black": "res://assets/textures/smartshape/grass_v4/black/grass_fill_detail.png",
		"white": "res://assets/textures/smartshape/grass_v4/white/grass_fill_detail.png",
		"폴더": "res://assets/textures/smartshape/grass_v4/노멀",
	},
	{
		"이름": "철판", "세기": 1.4,   ## 1.8 은 리벳/이음매가 번들거려 "반짝이는 금속판"으로 읽혔다
		"black": "res://assets/textures/smartshape/metal_v1/black/fill_patchwork.png",
		"white": "res://assets/textures/smartshape/metal_v1/white/fill_patchwork.png",
		"폴더": "res://assets/textures/smartshape/metal_v1/노멀",
	},
]


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	var 조사만 := 인자.has("--조사")
	# ★세기 비교용 CLI 덮어쓰기: `-- --세기=나무:1.2 --만=나무`
	#   표를 매번 고쳐서 다시 돌리면 어떤 값으로 찍은 그림인지 헷갈린다.
	var 덮기: Dictionary = {}
	var 만: String = ""
	for a: String in 인자:
		if a.begins_with("--세기="):
			var kv := a.substr(5).split(":")
			if kv.size() == 2:
				덮기[kv[0]] = float(kv[1])
		elif a.begins_with("--만="):
			만 = a.substr(4)
	var 실패 := 0
	for 줄: Dictionary in 대상:
		if 만 != "" and String(줄["이름"]) != 만:
			continue
		if 덮기.has(줄["이름"]):
			줄 = 줄.duplicate()
			줄["세기"] = 덮기[줄["이름"]]
		print("· %s (세기 %.1f)" % [줄["이름"], 줄["세기"]])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(줄["폴더"]))
		for 색 in ["black", "white"]:
			var 원본: String = 줄[색]
			if not ResourceLoader.exists(원본):
				print("    ✗ 원본 없음: %s" % 원본)
				실패 += 1
				continue
			var tex: Texture2D = load(원본)
			var img := tex.get_image()
			if img == null:
				print("    ✗ 이미지 추출 불가: %s" % 원본)
				실패 += 1
				continue
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)

			var 직접: String = String(줄.get("노멀_직접", ""))
			var 노멀경로 := 직접 if 직접 != "" \
				else "%s/%s_노멀_%s.png" % [줄["폴더"], 줄["이름"], 색]
			var tres경로 := "%s/%s_노멀_%s.tres" % [줄["폴더"], 줄["이름"], 색]

			# 크기 확인 — diffuse 와 노멀맵의 픽셀 크기가 다르면 UV 가 어긋난다(§크기·UV).
			var 노멀크기 := Vector2i(img.get_width(), img.get_height())
			if 직접 != "":
				var nt: Texture2D = load(직접)
				if nt == null:
					print("    ✗ 지정한 노멀맵이 없다: %s" % 직접)
					실패 += 1
					continue
				노멀크기 = Vector2i(nt.get_size())
			if 노멀크기 != Vector2i(img.get_width(), img.get_height()):
				print("    ✗ 크기 불일치: diffuse %dx%d vs normal %dx%d" % [
					img.get_width(), img.get_height(), 노멀크기.x, 노멀크기.y])
				실패 += 1
				continue

			print("    %s  %dx%d → %s%s" % [색, img.get_width(), img.get_height(),
				노멀경로.get_file(), "  (수제 노멀맵 재사용)" if 직접 != "" else ""])
			if 조사만:
				continue

			if 직접 == "":
				var 노멀 := _노멀맵(img, float(줄["세기"]))
				var e := 노멀.save_png(ProjectSettings.globalize_path(노멀경로))
				if e != OK:
					print("    ✗ 노멀맵 저장 실패: %s" % error_string(e))
					실패 += 1
					continue
			_tres_쓰기(tres경로, 원본, 노멀경로, 줄["이름"], 색)
	print("지형 노멀맵 %s (실패 %d)" % ["조사만" if 조사만 else "생성", 실패])
	quit(1 if 실패 > 0 else 0)


## 명도 높이맵 → 소벨 기울기 → 노멀맵.
## ⚠ `tools/generate_normal_maps.gd` 와 **같은 식**이어야 배경과 지형의 요철이 어긋나지 않는다.
##   Y 부호도 그쪽과 같다(초록 = 위). 2026-09-05 BRICK 수제 노멀맵과 같은 방향임을
##   조명 실험실에서 확인했다.
func _노멀맵(img: Image, 세기: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var 높이 := PackedFloat32Array()
	높이.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			높이[y * w + x] = c.get_luminance() * c.a
	var 결과 := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var xl := 높이[y * w + maxi(x - 1, 0)]
			var xr := 높이[y * w + mini(x + 1, w - 1)]
			var yu := 높이[maxi(y - 1, 0) * w + x]
			var yd := 높이[mini(y + 1, h - 1) * w + x]
			var n := Vector3((xl - xr) * 세기, (yd - yu) * 세기, 1.0).normalized()
			결과.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return 결과


## diffuse + normal 을 묶는 CanvasTexture 를 **파일로** 저장한다.
## 인라인 서브리소스로 만들면 resource_path 가 비어 흑↔백 짝 찾기가 실패한다(§위 주석).
func _tres_쓰기(경로: String, diffuse: String, normal: String, 이름: String, 색: String) -> void:
	var 짝색 := "white" if 색 == "black" else "black"
	var 글 := """[gd_resource type="CanvasTexture" format=3]

; ============================================================================
; [2026-09-05 자동생성] %s %s 아트 + 노멀맵 묶음
;   만든 도구: tools/생성_지형_노멀맵.gd  ← 손으로 고치지 말 것 (다시 돌리면 덮어쓴다)
; ----------------------------------------------------------------------------
; ▣ 왜 CanvasTexture 인가
;   SmartShape2D 애드온에는 normal_texture 슬롯이 없다. 대신
;   `SS2D_Material_Shape.fill_textures` 가 Array[Texture2D] 이고 CanvasTexture 는
;   Texture2D 라서 그대로 들어간다. SS2D 는 canvas_item_add_mesh 로 그리는데
;   CanvasTexture 의 RID 에 diffuse + normal 이 함께 실려 그대로 전달된다.
;   → 애드온을 한 줄도 안 고치고 노멀맵이 들어간다 (2026-09-05 BRICK 에서 실측 확인).
;
; ▣ 왜 인라인이 아니라 별도 파일인가  ★중요
;   `지형.gd` 의 `_짝_찾기()` 가 resource_path 파일명의 black ↔ white 토큰을 보고
;   반대색 아트를 찾는다. 인라인이면 resource_path 가 비어 짝 찾기가 실패하고
;   페인트 셰이더가 밝기 반전 폴백으로 떨어진다.
;   → 짝 = 같은 폴더의 `%s_노멀_%s.tres`
;
; ▣ texture_filter / texture_repeat 를 일부러 안 적는다
;   기본값 "부모를 따름" 이라 SS2D 가 캔버스 아이템에 거는 REPEAT_ENABLED 를
;   그대로 물려받는다. 여기서 값을 박으면 지형 텍스처 반복이 깨진다.
; ============================================================================

[ext_resource type="Texture2D" path="%s" id="1_diffuse"]
[ext_resource type="Texture2D" path="%s" id="2_normal"]

[resource]
diffuse_texture = ExtResource("1_diffuse")
normal_texture = ExtResource("2_normal")
""" % [이름, 색, 이름, 짝색, diffuse, normal]
	var f := FileAccess.open(ProjectSettings.globalize_path(경로), FileAccess.WRITE)
	if f == null:
		print("    ✗ tres 쓰기 실패: %s" % 경로)
		return
	f.store_string(글)
	f.close()
	print("      → %s" % 경로.get_file())
