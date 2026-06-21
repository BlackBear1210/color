@tool
extends SceneTree
## ════════════════════════════════════════════════════════════════════════
##  지형 PNG 슬라이서 v2 — "모양 기반" 분할 (2026-06-17)
## ════════════════════════════════════════════════════════════════════════
## 무엇이 바뀌었나(왜):
##   v1 은 픽셀 격자(3x3 등)로 무식하게 잘라 지형 모양을 무시했다.
##   v2 는 **알파(불투명) 픽셀이 연결된 덩어리(connected component)** 를 찾아
##   "지형의 실제 모양"을 따라 조각낸다. 떨어져 있는 바위/발판은 각각 1조각이 된다.
##   그리고 **큰 덩어리는 4방향(좌상/우상/좌하/우하)으로 추가 분할**한다.
##   (요청: "지형의 모양을 보고 잘라줘 / 큰 지형들은 4개의 방향으로 각각")
##
## 동작 원리:
##   1) 원본을 작게 줄인 알파 마스크에서 연결 덩어리를 라벨링(빠름).
##   2) 각 덩어리의 경계상자(bbox)를 원본 해상도로 환산.
##   3) 덩어리가 크면(LARGE_PX 초과) bbox 를 4사분면으로 나눠 각각 저장,
##      작으면 통째로 저장. 저장 직전 투명 여백을 잘라 모양에 딱 맞춘다.
##   ※ 잘린 조각은 흑색 실루엣 + 투명배경 유지 → 그대로 baker 에 넣어 폴리 생성.
##
## 실행: godot --headless --path <proj> --script res://tools/slice_terrain.gd
##
## ── 설정 ────────────────────────────────────────────────────────────────
## 자를 원본들(여러 개 가능). stage_2 동굴이 쓰는 텍스처를 기본값으로.
const SOURCES: Array = [
	"res://scenes/world_1/map2/Platform_Black_01.png",
	"res://scenes/world_1/map2/Platform_Black_02.png",
]
const OUT_DIR: String = "res://scenes/도형_타일셋_최신/sliced/"

const ALPHA_CUT: int = 24        # 이 알파(0~255)보다 크면 "지형" 픽셀로 간주
const LABEL_MAX_DIM: int = 800   # 라벨링용 축소 목표 크기(클수록 정밀/느림)
const LARGE_PX: int = 1000       # bbox 가로/세로가 이보다 크면 4방향으로 쪼갬
const MIN_PIECE_PX: int = 60     # 이보다 작은 조각(노이즈)은 버림
const PAD: int = 6               # bbox 여유 패딩(px)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var total := 0
	for src in SOURCES:
		total += _slice_one(src)
	print("──────── 전체 조각 %d개 저장 완료 → %s" % [total, OUT_DIR])
	print("다음: 에디터를 한 번 열어 조각 임포트(자동) → bake_architecture_tileset.gd ENTRIES 에 추가 → 헤드리스 실행")
	quit()


## 원본 1장을 모양 기반으로 잘라 저장. 반환: 만든 조각 수.
func _slice_one(src: String) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		push_error("슬라이서: 원본을 못 읽음 → %s" % src)
		return 0
	img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var base := src.get_file().get_basename()   # 파일명(확장자 제외)
	print("● %s : %dx%d, 알파=%s" % [base, W, H, img.detect_alpha() != Image.ALPHA_NONE])

	# 1) 라벨링용 축소 마스크 생성
	var step := int(ceil(max(W, H) / float(LABEL_MAX_DIM)))
	step = max(step, 1)
	var lw := int(ceil(W / float(step)))
	var lh := int(ceil(H / float(step)))
	var small := img.duplicate()
	small.resize(lw, lh, Image.INTERPOLATE_BILINEAR)
	var sdata: PackedByteArray = small.get_data()   # RGBA8 → 4바이트/픽셀
	var mask := PackedByteArray()
	mask.resize(lw * lh)
	for i in lw * lh:
		mask[i] = 1 if sdata[i * 4 + 3] > ALPHA_CUT else 0

	# 2) 연결 덩어리 라벨링(4방향 BFS) + 각 덩어리 bbox 수집
	var labels := PackedInt32Array()
	labels.resize(lw * lh)
	labels.fill(-1)
	var comps: Array = []   # 각 원소 = [minx, miny, maxx, maxy] (축소 좌표)
	for start in lw * lh:
		if mask[start] == 0 or labels[start] != -1:
			continue
		var lbl := comps.size()
		var bb := [lw, lh, 0, 0]   # minx,miny,maxx,maxy
		var stack: Array = [start]
		labels[start] = lbl
		while not stack.is_empty():
			var p: int = stack.pop_back()
			var px := p % lw
			var py := int(p / lw)
			if px < bb[0]: bb[0] = px
			if py < bb[1]: bb[1] = py
			if px > bb[2]: bb[2] = px
			if py > bb[3]: bb[3] = py
			# 4방향 이웃
			for d in [[1,0],[-1,0],[0,1],[0,-1]]:
				var nx: int = px + d[0]
				var ny: int = py + d[1]
				if nx < 0 or ny < 0 or nx >= lw or ny >= lh:
					continue
				var ni := ny * lw + nx
				if mask[ni] == 1 and labels[ni] == -1:
					labels[ni] = lbl
					stack.append(ni)
		comps.append(bb)

	# 3) 덩어리별로 원본 해상도 crop → (크면 4방향) 저장
	var made := 0
	var idx := 0
	for bb in comps:
		# 축소 좌표 → 원본 좌표 + 패딩
		var x0: int = max(int(bb[0]) * step - PAD, 0)
		var y0: int = max(int(bb[1]) * step - PAD, 0)
		var x1: int = min((int(bb[2]) + 1) * step + PAD, W)
		var y1: int = min((int(bb[3]) + 1) * step + PAD, H)
		var bw: int = x1 - x0
		var bh: int = y1 - y0
		if bw < MIN_PIECE_PX and bh < MIN_PIECE_PX:
			continue   # 노이즈 덩어리 버림
		idx += 1
		var full := Rect2i(x0, y0, bw, bh)
		if bw > LARGE_PX or bh > LARGE_PX:
			# ── 큰 덩어리: 4방향(사분면)으로 ──
			var hx: int = bw / 2
			var hy: int = bh / 2
			var quads := {
				"TL": Rect2i(x0, y0, hx, hy),
				"TR": Rect2i(x0 + hx, y0, bw - hx, hy),
				"BL": Rect2i(x0, y0 + hy, hx, bh - hy),
				"BR": Rect2i(x0 + hx, y0 + hy, bw - hx, bh - hy),
			}
			for key in quads:
				made += _save_region(img, quads[key], "%s_shape%02d_%s" % [base, idx, key])
		else:
			# ── 작은 덩어리: 통째로 ──
			made += _save_region(img, full, "%s_shape%02d" % [base, idx])
	print("  → %s : 덩어리 %d개 처리, 조각 %d개" % [base, idx, made])
	return made


## 지정 영역을 잘라 투명여백 트림 후 저장. 내용 없으면 0 반환.
func _save_region(img: Image, rect: Rect2i, name: String) -> int:
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0
	var piece := img.get_region(rect)
	# 투명 여백 잘라 모양에 딱 맞추기
	var used := piece.get_used_rect()
	if used.size == Vector2i.ZERO:
		return 0   # 완전 투명 조각 스킵
	if used.size != piece.get_size():
		piece = piece.get_region(used)
	if piece.get_width() < MIN_PIECE_PX and piece.get_height() < MIN_PIECE_PX:
		return 0
	var out_path := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
	var err := piece.save_png(out_path)
	if err == OK:
		print("    조각: %s.png (%dx%d)" % [name, piece.get_width(), piece.get_height()])
		return 1
	push_warning("슬라이서: 저장 실패 %s err=%d" % [name, err])
	return 0
