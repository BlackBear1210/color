extends SceneTree
## ════════════════════════════════════════════════════════════════════════
##  ▼ 2026-06-21 신규 / ▼ 2026-06-22 업그레이드(조각분리+흑백자동)
##  임의 이미지 → "흑/백 실루엣 + 투명배경" PNG 변환기 (헤드리스)
##    실행: godot --headless --path <proj> -s res://tools/silhouette_from_image.gd
## ════════════════════════════════════════════════════════════════════════
## [무엇을 하나]
##   핀터레스트/스프라이트시트 등에서 가져온 지형 이미지의 '배경을 제거(누끼)'하고,
##   ▼ 2026-06-22: 시트 안의 조각들을 '하나씩 분리'해서, 각 조각을 밝기에 따라
##   검정 또는 흰색 실루엣 + 투명배경 PNG 로 저장한다. → baker 가 물리레이어까지 입힌
##   Arch 씬으로 구울 수 있다. (밝은 지형=WHITE, 어두운 지형=BLACK 자동 판정)
##
## [중요 — Godot 의 한계와 역할 분담]
##   · Godot 엔진에는 'AI 누끼(복잡한 배경 자동 분리)' 기능이 없다.
##   · 이 도구는 Image API 로 가능한 3가지 방식만 처리한다:
##       1) alpha      : 입력이 이미 투명PNG(예: rembg/Photopea 결과) → 색만 흑/백으로
##       2) colorkey   : 배경이 단색/근단색(예: 흰 배경 시트) → 모서리색 샘플 후 '연결된 배경'만 제거
##       3) luminance  : 피사체가 배경보다 어둡/밝음 → 밝기 임계로 실루엣 추출
##   · 사진처럼 배경이 복잡하면 먼저 외부 AI 매팅으로 누끼 → 여기서 'alpha' 모드로 색만 바꾼다.
##     (외부 추천: rembg(무료/로컬), Photopea/remove.bg(웹). 자세한 건 타일셋_작업_인수인계.md)
##
## [입력/출력]
##   입력 IN_DIR 의 png/jpg/webp 를 처리. 출력은 OUT_DIR 에 저장.
##   - split=true(기본): 조각마다 "<이름>_01.png, _02.png ..." (시트 → 개별 지형)
##   - split=false      : 통째로 "<이름>.png"
##   이 OUT_DIR 은 baker 의 SCAN_DIRS 에 등록돼 있어 곧바로 Arch 씬으로 구워진다.

const IN_DIR: String  = "res://scenes/지형파일셋/원본이미지/"
const OUT_DIR: String = "res://scenes/지형파일셋/실루엣/"

# 조각 분리 시 이 면적(px²) 미만의 점은 노이즈로 버린다(작은 돌부스러기/외곽 사금파리 제거)
# ▼ 2026-06-28: 8000 으로 상향 — 제미나이 이미지 우하단 흰 ✦ 워터마크(작은 조각)를 버리고
#   큰 지형 덩어리 하나만 남기기 위함. (각 이미지는 큰 지형 1개라 안전)
const MIN_PIECE_AREA: int = 8000

# ── 기본 설정 (개별 지정이 없을 때 폴더 전체에 적용) ─────────────────────
# color    : "AUTO" | "BLACK" | "WHITE"  (AUTO=조각 밝기로 자동: 밝으면 WHITE, 어두우면 BLACK)
# mode     : "auto" | "alpha" | "colorkey" | "luminance"
#            auto = 입력에 투명이 있으면 alpha, 없으면 colorkey
# split    : true=시트를 조각별로 분리 저장 / false=통째로 한 장
# tol      : colorkey 배경색 허용오차(0~1). 클수록 더 많이 지움
# lum      : luminance 임계(0~1). dark_subject 면 이보다 어두운 픽셀을 지형으로
# lum_dark : true=어두운 피사체를 지형으로 / false=밝은 피사체를 지형으로
# lum_split: AUTO 색 판정 임계(조각 평균밝기 ≥ 이 값 → WHITE, 미만 → BLACK)
const DEFAULTS := {
	# ▼ 2026-06-28: 제미나이 지형(마젠타 #FF00FF 배경) 일괄 처리 설정.
	#   color="BLACK": 우선 전부 검정 실루엣(Badland식, stage1/2 기본 톤). 흰 버전은 color="WHITE"로 재실행.
	#   mode="colorkey": 마젠타 단색 배경을 모서리색 기준 flood-fill 제거.
	#   tol=0.2: JPEG 압축으로 생긴 가장자리 마젠타 헤일로까지 넉넉히 제거.
	"color": "BLACK", "mode": "colorkey", "split": true,
	"tol": 0.2, "lum": 0.5, "lum_dark": true, "lum_split": 0.5,
}

## 개별 이미지에 다른 설정을 주고 싶을 때만 추가 (없으면 폴더 전체에 DEFAULTS 적용)
## 예: {"file":"cliff.jpg", "color":"WHITE", "split":false, "mode":"luminance", "lum":0.6, "lum_dark":false}
const ENTRIES: Array = [
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var overrides := {}
	for e in ENTRIES:
		overrides[str(e["file"])] = e

	var dir := DirAccess.open(IN_DIR)
	if dir == null:
		print("입력 폴더 없음: ", IN_DIR, "  (여기에 원본 이미지를 넣으세요)")
		quit(0); return

	var total_pieces := 0
	var files_done := 0
	for f in dir.get_files():
		var low := f.to_lower()
		if not (low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp")):
			continue
		var cfg := DEFAULTS.duplicate()
		if overrides.has(f):
			for k in overrides[f]:
				cfg[k] = overrides[f][k]
		var n := _process_one(IN_DIR + f, f.get_basename(), cfg)
		if n > 0:
			files_done += 1
			total_pieces += n
			print("  → ", f, " : 조각 ", n, "개 생성 (mode=", _eff_mode(cfg, IN_DIR + f), ", color=", cfg["color"], ")")
		else:
			print("  → ", f, " : 생성 0 (배경/임계 설정 확인)")

	print("SILHOUETTE_DONE  파일=%d  조각합계=%d" % [files_done, total_pieces])
	if files_done == 0:
		print("→ 원본 이미지를 ", IN_DIR, " 에 넣고 다시 실행. 그 다음 bake_architecture_tileset.gd 로 구우면 됩니다.")
	quit(0)

## 입력 1장 처리 → (조각 N개 또는 1장) 저장. 반환: 저장한 조각 수.
func _process_one(in_path: String, base: String, cfg: Dictionary) -> int:
	var img := Image.load_from_file(in_path)
	if img == null:
		return 0
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	# 1) 배경 제거(마스킹) — 이 시점 이후 배경 픽셀은 alpha=0, 지형은 원본색 유지
	match _eff_mode(cfg, in_path):
		"alpha":     pass
		"colorkey":  _mask_colorkey(img, float(cfg["tol"]))
		"luminance": _mask_luminance(img, float(cfg["lum"]), bool(cfg["lum_dark"]))

	# 2) 분리 저장 / 통짜 저장
	if bool(cfg["split"]):
		return _save_pieces(img, base, cfg)
	else:
		var white := _resolve_white(img, _all_opaque(img), cfg)
		_recolor_all(img, white)
		# ▼ 2026-06-22: 색표기(_W/_B) 파일명으로 저장 → baker 가 물리레이어 결정
		var suffix := "_W" if white else "_B"
		return 1 if img.save_png(OUT_DIR + base + suffix + ".png") == OK else 0

## "auto" 면 입력 투명 유무로 alpha/colorkey 결정
func _eff_mode(cfg: Dictionary, in_path: String) -> String:
	var m := str(cfg["mode"])
	if m != "auto":
		return m
	return "alpha" if _has_transparency(in_path) else "colorkey"

func _has_transparency(in_path: String) -> bool:
	var img := Image.load_from_file(in_path)
	if img == null:
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for p in [Vector2i(0,0), Vector2i(w-1,0), Vector2i(0,h-1), Vector2i(w-1,h-1), Vector2i(w/2,0)]:
		if img.get_pixelv(p).a < 0.5:
			return true
	return false

# ── 마스크 방식 ─────────────────────────────────────────────────────────
## colorkey: 네 모서리 평균색을 배경으로 보고, 테두리에서 '연결된' 배경만 flood-fill 제거.
func _mask_colorkey(img: Image, tol: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := (img.get_pixel(0,0) + img.get_pixel(w-1,0) + img.get_pixel(0,h-1) + img.get_pixel(w-1,h-1)) / 4.0
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		_seed(img, bg, tol, visited, stack, x, 0, w)
		_seed(img, bg, tol, visited, stack, x, h-1, w)
	for y in h:
		_seed(img, bg, tol, visited, stack, 0, y, w)
		_seed(img, bg, tol, visited, stack, w-1, y, w)
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		img.set_pixel(p.x, p.y, Color(0,0,0,0))
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			_seed(img, bg, tol, visited, stack, p.x + d.x, p.y + d.y, w)

func _seed(img: Image, bg: Color, tol: float, visited: PackedByteArray,
		stack: Array, x: int, y: int, w: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= img.get_height():
		return
	var idx := y * w + x
	if visited[idx] == 1:
		return
	var c := img.get_pixel(x, y)
	var dist: float = absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
	if dist <= tol * 3.0:
		visited[idx] = 1
		stack.push_back(Vector2i(x, y))

## luminance: 밝기 임계로 지형/배경 분리.
func _mask_luminance(img: Image, lum_thresh: float, dark_subject: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := _lum(c)
			var is_terrain := (l < lum_thresh) if dark_subject else (l > lum_thresh)
			if not is_terrain:
				img.set_pixel(x, y, Color(0,0,0,0))

# ── 조각 분리(연결요소) 저장 ─────────────────────────────────────────────
## 불투명 픽셀의 연결요소(4방향)를 찾아 조각별로 잘라 흑/백 실루엣 PNG 로 저장.
func _save_pieces(img: Image, base: String, cfg: Dictionary) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var saved := 0
	for sy in h:
		for sx in w:
			var sidx := sy * w + sx
			if visited[sidx] == 1:
				continue
			if img.get_pixel(sx, sy).a <= 0.0:
				visited[sidx] = 1
				continue
			# BFS 로 한 조각 수집
			var comp := PackedInt32Array()
			var stack: Array[Vector2i] = [Vector2i(sx, sy)]
			visited[sidx] = 1
			var minx := sx; var miny := sy; var maxx := sx; var maxy := sy
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				comp.append(p.y * w + p.x)
				minx = mini(minx, p.x); miny = mini(miny, p.y)
				maxx = maxi(maxx, p.x); maxy = maxi(maxy, p.y)
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = p.x + d.x
					var ny: int = p.y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var nidx: int = ny * w + nx
					if visited[nidx] == 1:
						continue
					visited[nidx] = 1
					if img.get_pixel(nx, ny).a > 0.0:
						stack.push_back(Vector2i(nx, ny))
			var area := (maxx - minx + 1) * (maxy - miny + 1)
			if comp.size() < MIN_PIECE_AREA or area < MIN_PIECE_AREA:
				continue   # 노이즈 조각 버림
			# 색 판정(AUTO=조각 평균밝기) 후 잘라서 저장
			var white := _resolve_white(img, comp, cfg)
			# ▼ 2026-06-22: 파일명 끝에 색표기(_W/_B). baker 가 이를 읽어 color_state(물리레이어)를 정한다.
			var suffix := "W" if white else "B"
			if _save_crop(img, comp, w, Vector2i(minx, miny), Vector2i(maxx, maxy), white,
					OUT_DIR + "%s_%02d_%s.png" % [base, saved + 1, suffix]):
				saved += 1
	return saved

## 조각(comp 픽셀들)을 bbox 크기로 잘라 흑/백 실루엣 + 투명 PNG 저장.
func _save_crop(src: Image, comp: PackedInt32Array, w: int,
		mn: Vector2i, mx: Vector2i, white: bool, out_path: String) -> bool:
	var cw := mx.x - mn.x + 1
	var ch := mx.y - mn.y + 1
	var piece := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	piece.fill(Color(0,0,0,0))
	var rgb := Color(1,1,1) if white else Color(0,0,0)
	for idx in comp:
		var x := idx % w
		var y := idx / w
		var a := src.get_pixel(x, y).a
		piece.set_pixel(x - mn.x, y - mn.y, Color(rgb.r, rgb.g, rgb.b, a))
	return piece.save_png(out_path) == OK

# ── 색/밝기 헬퍼 ────────────────────────────────────────────────────────
## cfg.color 가 AUTO 면 대상 픽셀들의 평균밝기로 WHITE/BLACK 결정.
func _resolve_white(img: Image, idxs: PackedInt32Array, cfg: Dictionary) -> bool:
	var c := str(cfg["color"])
	if c == "WHITE": return true
	if c == "BLACK": return false
	# AUTO: 원본색 평균밝기
	var w := img.get_width()
	var sum := 0.0
	var cnt := 0
	for idx in idxs:
		var col := img.get_pixel(idx % w, idx / w)
		if col.a > 0.0:
			sum += _lum(col)
			cnt += 1
	var avg := (sum / cnt) if cnt > 0 else 0.0
	return avg >= float(cfg["lum_split"])

## 전체 불투명 픽셀 인덱스(통짜 모드 AUTO 판정용)
func _all_opaque(img: Image) -> PackedInt32Array:
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedInt32Array()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				out.append(y * w + x)
	return out

## 통짜 모드: 남은 불투명 픽셀을 검정/흰색으로(알파 보존).
func _recolor_all(img: Image, white: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rgb := Color(1,1,1) if white else Color(0,0,0)
	for y in h:
		for x in w:
			var a := img.get_pixel(x, y).a
			if a > 0.0:
				img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))

func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
