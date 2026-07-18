extends SceneTree
## [2026-07-18 도형 · 신규] 노멀맵 자동 생성기 (헤드리스 1회 실행용).
## 실행: Godot --headless --path . -s res://tools/generate_normal_maps.gd
##
## 원리: 텍스처의 명도(luminance)를 높이맵으로 보고 소벨(Sobel) 필터로 기울기를
## 구하면 픽셀별 법선(normal)이 나온다 — 포토샵/Laigter 등 노멀맵 도구와 같은 방식.
## 결과 PNG 는 assets/textures/normal/<원본이름>_n.png 로 저장되고,
##  - 타일셋: terrain_tileset.tres 의 CanvasTexture 가 참조 (칠해진 지형이 입체로)
##  - 배경: zone_visuals.gd 가 런타임에 CanvasTexture 로 감싸 주입
## 디자이너가 진짜 타일/배경 그림으로 교체하면 이 스크립트만 다시 돌리면 된다.
## (강도가 안 맞으면 아래 TARGETS 의 strength 값만 조정)

## 대상 텍스처 → 노멀 강도 (클수록 울퉁불퉁이 심해짐)
const TARGETS := {
	"res://assets/textures/tiles/placeholder_tiles.svg": 2.6,
	"res://assets/textures/bg/bg_far.svg": 1.2,
	"res://assets/textures/bg/bg_mid.svg": 1.6,
	"res://assets/textures/bg/bg_near.svg": 2.0,
}
const OUT_DIR := "res://assets/textures/normal"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var fail := 0
	for path: String in TARGETS:
		if not ResourceLoader.exists(path):
			print("SKIP (없음): ", path)
			continue
		var tex: Texture2D = load(path)
		var img := tex.get_image()
		if img == null:
			print("FAIL (이미지 추출 불가): ", path)
			fail += 1
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var normal := _make_normal(img, TARGETS[path])
		var out := "%s/%s_n.png" % [OUT_DIR, path.get_file().get_basename()]
		var err := normal.save_png(ProjectSettings.globalize_path(out))
		print(("OK    " if err == OK else "FAIL  "), out)
		if err != OK:
			fail += 1
	quit(1 if fail > 0 else 0)

## 명도 높이맵 → 소벨 기울기 → 노멀맵 (RGB = 법선 xyz 를 0~1 로 인코딩)
func _make_normal(img: Image, strength: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	# 1) 높이맵: 명도 × 알파 (투명한 곳은 높이 0)
	var height := PackedFloat32Array()
	height.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			height[y * w + x] = c.get_luminance() * c.a
	var normal := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# 2) 소벨 필터로 x/y 기울기 → 법선. 가장자리는 클램프 샘플링.
	for y in h:
		for x in w:
			var xl := height[y * w + maxi(x - 1, 0)]
			var xr := height[y * w + mini(x + 1, w - 1)]
			var yu := height[maxi(y - 1, 0) * w + x]
			var yd := height[mini(y + 1, h - 1) * w + x]
			# Godot 2D 라이팅 관례: +X = 오른쪽, +Y = 위쪽(그린 채널 뒤집힘)
			var n := Vector3((xl - xr) * strength, (yd - yu) * strength, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return normal
