extends SceneTree
## ════════════════════════════════════════════════════════════════════════
##  ▼ 2026-06-29 v3 — 배드랜드 지형 타일셋 생성기 (민무늬 순수 실루엣 + 한글 이름)
##    실행: Godot --headless --path <proj> -s res://tools/generate_terrain_silhouettes.gd
## ════════════════════════════════════════════════════════════════════════
## [v3 변경 — 사용자 피드백 반영]
##   v2 의 회색 명암 + 베이크 크랙 + 덩굴이 "원하는 순수 검정 실루엣 느낌"과 멀어짐.
##   → v3 는 사용자가 고른 'B·민무늬': 통짜 단색(검/흰/회) 실루엣, 윗면 평탄, 디테일 제거.
##   크랙·가시는 '별도 에셋'으로 분리(이 파일은 가시 PNG 도 생성, 크랙은 map1 데칼 재사용).
##
## [출력 — 이미지/씬 폴더 분리]
##   · 지형 PNG  → res://scenes/지형파일셋/이미지/<카테고리>(<색>)<번호>.png   (검/흰/회)
##   · 가시 PNG  → res://scenes/지형파일셋/이미지/가시/가시<번호>.png            (빨강, 즉사)
##   그 다음 bake_architecture_tileset.gd 가 '이미지/'(가시 하위폴더 제외)를 굽고,
##   생성된 .tscn 은 '씬/' 폴더로 옮긴다(ext_resource 는 res:// 절대경로라 이동 안전).
##
## [한글 이름 규칙]  <카테고리>(<색>)<번호>   예: 바닥(검)1, 경사로(흰)3, 다리(검)1, 회색경사로(회)1
##   비슷하지만 모양이 다른 것은 번호로 구분. (번호↔모양 표는 인수인계 .md 참고)
##
## [형태 재조정] 아래 _specs() 의 파라미터만 고쳐 재실행→(--import)→bake→(씬 이동).

const IMG := "res://scenes/지형파일셋/이미지/"
const THORN_DIR := "res://scenes/지형파일셋/이미지/가시/"
const BIG: float = 1.0e9

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMG))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THORN_DIR))
	var made := 0
	for s in _specs():
		var geo := _build(s)
		var top: PackedFloat32Array = geo["top"]
		var bot: PackedFloat32Array = geo["bot"]
		for c in s.get("colors", ["검", "흰"]):
			var full := _render(int(geo["w"]), int(geo["h"]), top, bot, _fill_color(c))
			var rect := full.get_used_rect()
			if rect.size.x <= 1 or rect.size.y <= 1:
				continue
			var cropped := full.get_region(rect)
			var path := _path_for(str(s["cat"]), int(s["num"]), c)
			if cropped.save_png(path) == OK:
				made += 1
	print("TERRAIN_GEN_DONE  파일=%d 장 생성" % made)
	quit()

func _fill_color(c: String) -> Color:
	match c:
		"흰":  return Color(1, 1, 1, 1)
		"회":  return Color(0.5, 0.5, 0.52, 1)      # 회색 지형(GRAY, 칠해야 밟힘)
		"가시": return Color(0.72, 0.05, 0.05, 1)    # 빨강 즉사 가시
		_:     return Color(0, 0, 0, 1)             # 검(기본)

func _path_for(cat: String, num: int, c: String) -> String:
	if c == "가시":
		return THORN_DIR + "%s%d.png" % [cat, num]
	return IMG + "%s(%s)%d.png" % [cat, c, num]

## ── 모듈 목록 (한글 카테고리 + 번호) ─────────────────────────────────────
## colors 기본 = ["검","흰"]. 회색지형 = ["회"], 가시 = ["가시"].
func _specs() -> Array:
	return [
		# 바닥 (평탄 윗면) 1~4
		{"cat":"바닥","num":1,"kind":"ground","w":1000,"h":440,"T":130,"thick":190,"spikes":6,"slen":130},
		{"cat":"바닥","num":2,"kind":"ground","w":1450,"h":420,"T":120,"thick":180,"spikes":9,"slen":120},
		{"cat":"바닥","num":3,"kind":"ground","w":560, "h":580,"T":90, "thick":420,"spikes":4,"slen":150},
		{"cat":"바닥","num":4,"kind":"ground","w":820, "h":470,"T":140,"thick":210,"spikes":8,"slen":150},
		# 경사로 1=오르완,2=오르급,3=내리완,4=내리급,5=긴,6=전환
		{"cat":"경사로","num":1,"kind":"slope","w":760, "h":470,"T0":360,"slope":-0.30,"thick":150,"spikes":5,"slen":90},
		{"cat":"경사로","num":2,"kind":"slope","w":640, "h":560,"T0":430,"slope":-0.58,"thick":140,"spikes":5,"slen":90},
		{"cat":"경사로","num":3,"kind":"slope","w":760, "h":470,"T0":110,"slope":0.30, "thick":150,"spikes":5,"slen":90},
		{"cat":"경사로","num":4,"kind":"slope","w":640, "h":560,"T0":80, "slope":0.58, "thick":140,"spikes":5,"slen":90},
		{"cat":"경사로","num":5,"kind":"slope","w":1400,"h":470,"T0":140,"slope":0.17, "thick":150,"spikes":10,"slen":110},
		{"cat":"경사로","num":6,"kind":"trans","w":900, "h":460,"T":140,"slope":0.52,"thick":150,"spikes":6,"slen":100},
		# 회색경사로 (회) 1~2  — color_state GRAY(칠해야 밟힘)
		{"cat":"회색경사로","num":1,"kind":"slope","w":820,"h":470,"T0":120,"slope":0.34,"thick":150,"spikes":6,"slen":100,"colors":["회"]},
		{"cat":"회색경사로","num":2,"kind":"slope","w":820,"h":480,"T0":380,"slope":-0.34,"thick":150,"spikes":6,"slen":100,"colors":["회"]},
		# 발판(지상) 1~2
		{"cat":"발판","num":1,"kind":"ground","w":360,"h":300,"T":70,"thick":150,"spikes":3,"slen":90},
		{"cat":"발판","num":2,"kind":"ground","w":720,"h":340,"T":90,"thick":160,"spikes":6,"slen":100},
		# 공중발판 1~5 (각각 다른 모양)
		{"cat":"공중발판","num":1,"kind":"blob","w":560,"h":380,"rx":250,"ry":120,"flat_top":true,"lump":0.10,"skew":0.0},
		{"cat":"공중발판","num":2,"kind":"blob","w":420,"h":420,"rx":190,"ry":175,"flat_top":true,"lump":0.14,"skew":0.0},
		{"cat":"공중발판","num":3,"kind":"blob","w":340,"h":320,"rx":150,"ry":130,"flat_top":true,"lump":0.26,"skew":0.0},
		{"cat":"공중발판","num":4,"kind":"blob","w":860,"h":540,"rx":390,"ry":225,"flat_top":true,"lump":0.16,"skew":0.0},
		{"cat":"공중발판","num":5,"kind":"blob","w":620,"h":440,"rx":270,"ry":150,"flat_top":true,"lump":0.14,"skew":0.45},
		# 선반(절벽 끝) 1=좌절벽,2=우절벽,3=협곡
		{"cat":"선반","num":1,"kind":"ledge","w":640,"h":500,"T":130,"thick":190,"drop":"left","spikes":5,"slen":120},
		{"cat":"선반","num":2,"kind":"ledge","w":640,"h":500,"T":130,"thick":190,"drop":"right","spikes":5,"slen":120},
		{"cat":"선반","num":3,"kind":"ground","w":820,"h":480,"T":150,"thick":280,"spikes":6,"slen":140,"layered":true},
		# 천장 1=평,2=종유석,3=오버행
		{"cat":"천장","num":1,"kind":"ceiling","w":900,"h":300,"thick":150,"spikes":0,"slen":0},
		{"cat":"천장","num":2,"kind":"ceiling","w":1000,"h":440,"thick":80,"spikes":6,"slen":250},
		{"cat":"천장","num":3,"kind":"ceiling","w":820,"h":380,"thick":130,"spikes":2,"slen":160},
		# 기둥 1=긴,2=굵은
		{"cat":"기둥","num":1,"kind":"pillar","w":360,"h":1040,"hw":0.26,"amp":0.10,"twist":0.16},
		{"cat":"기둥","num":2,"kind":"pillar","w":460,"h":900,"hw":0.36,"amp":0.10,"twist":0.05},
		# 벽 1=절벽,2=동굴
		{"cat":"벽","num":1,"kind":"pillar","w":560,"h":1000,"hw":0.42,"amp":0.12,"twist":0.0},
		{"cat":"벽","num":2,"kind":"pillar","w":460,"h":980,"hw":0.36,"amp":0.17,"twist":0.05},
		# 계단 / 단차
		{"cat":"계단","num":1,"kind":"stairs","w":840,"h":560,"steps":6},
		{"cat":"단차","num":1,"kind":"ground","w":420,"h":260,"T":110,"thick":120,"spikes":2,"slen":70},
		# 다리
		{"cat":"다리","num":1,"kind":"bridge","w":1000,"h":380,"T":120,"arch":68,"thick":78,"support":120,"spikes":4,"slen":90},
		# 크리스탈
		{"cat":"크리스탈발판","num":1,"kind":"ground","w":720,"h":360,"T":80,"thick":230,"spikes":5,"slen":120,"crystal":true},
		{"cat":"크리스탈기둥","num":1,"kind":"pillar","w":420,"h":940,"hw":0.30,"amp":0.04,"twist":0.0,"taper":true},
		# 가시 (빨강 즉사) 1~4 — 위로 솟은 뾰족 가시, map1 Platform_Thorn 참고
		{"cat":"가시","num":1,"kind":"thorn","w":720,"h":300,"base":52,"dense":30,"slen":210,"colors":["가시"]},
		{"cat":"가시","num":2,"kind":"thorn","w":520,"h":260,"base":44,"dense":22,"slen":180,"colors":["가시"]},
		{"cat":"가시","num":3,"kind":"thorn","w":900,"h":240,"base":40,"dense":40,"slen":150,"colors":["가시"]},
		{"cat":"가시","num":4,"kind":"thorn","w":360,"h":300,"base":40,"dense":14,"slen":230,"colors":["가시"]},
	]

## ── 형태 빌드: 모든 모듈을 '열별 top[x]/bot[x]' 로 환원 (걷는 면=top 평탄, 디테일=bot) ──
func _build(s: Dictionary) -> Dictionary:
	var w := int(s["w"]); var h := int(s["h"])
	var top := PackedFloat32Array(); top.resize(w); top.fill(BIG)
	var bot := PackedFloat32Array(); bot.resize(w); bot.fill(-1.0)
	var n := FastNoiseLite.new()
	n.seed = abs(hash(str(s["cat"]) + str(s["num"])))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	match s["kind"]:
		"ground":  _b_ground(s, n, top, bot)
		"slope":   _b_slope(s, n, top, bot)
		"trans":   _b_trans(s, n, top, bot)
		"ledge":   _b_ledge(s, n, top, bot)
		"ceiling": _b_ceiling(s, n, top, bot)
		"bridge":  _b_bridge(s, n, top, bot)
		"stairs":  _b_stairs(s, n, top, bot)
		"pillar":  _b_pillar(s, n, top, bot)
		"blob":    _b_blob(s, n, top, bot)
		"thorn":   _b_thorn(s, n, top, bot)
	return {"w": w, "h": h, "top": top, "bot": bot}

func _nz(n: FastNoiseLite, t: float, freq: float, off: float) -> float:
	return 0.62 * n.get_noise_2d(t * freq, off) + 0.38 * n.get_noise_2d(t * freq * 2.7, off + 50.0)

func _endwin(x: int, w: int, edge: float) -> float:
	var d := float(mini(x, w - 1 - x))
	return 1.0 if d >= edge else 0.12 + 0.88 * smoothstep(0.0, 1.0, d / edge)

func _spikes_down(x: int, w: int, n: FastNoiseLite, count: int, slen: float, end_bias: bool) -> float:
	if count <= 0:
		return 0.0
	var best := 0.0
	for i in count:
		var fx := (i + 0.5) / count
		var xc := fx * w
		var sw := w * 0.045 * (0.6 + 0.8 * absf(n.get_noise_2d(i * 13.1, 1.0)))
		var ln := slen * (0.45 + 0.9 * absf(n.get_noise_2d(i * 7.3, 5.0)))
		if end_bias:
			ln *= 0.55 + 0.9 * absf(fx - 0.5) * 2.0
		if absf(x - xc) < sw:
			best = maxf(best, ln * (1.0 - absf(x - xc) / sw))
	return best

func _b_ground(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var T := float(s["T"]); var thick := float(s["thick"])
	var spikes := int(s.get("spikes", 5)); var slen := float(s.get("slen", 110.0))
	var layered := bool(s.get("layered", false)); var crystal := bool(s.get("crystal", false))
	var edge := w * 0.16
	for x in w:
		top[x] = T + 2.0 * sin(x * 0.012)                  # 윗면 거의 평탄(발 안 걸림)
		var body := thick * _endwin(x, w, edge)
		var lump := thick * 0.16 * absf(_nz(n, x, 0.02, 0.0))
		var sp := _spikes_down(x, w, n, spikes, slen, true)
		if layered:
			body += 18.0 * (0.5 + 0.5 * sin(x * 0.04))
		if crystal:
			sp = maxf(sp, slen * 0.9 * absf(sin(x * 0.012 * w / 60.0)))
		bot[x] = minf(top[x] + body + lump + sp, h - 1)

func _b_slope(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var T0 := float(s["T0"]); var slope := float(s["slope"])
	var thick := float(s["thick"]); var spikes := int(s["spikes"]); var slen := float(s["slen"])
	var edge := w * 0.14
	for x in w:
		top[x] = clampf(T0 + slope * x + 1.5 * sin(x * 0.01), 4.0, h - 40.0)
		bot[x] = minf(top[x] + thick * _endwin(x, w, edge) + _spikes_down(x, w, n, spikes, slen, true), h - 1)

func _b_trans(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var T := float(s["T"]); var slope := float(s["slope"])
	var thick := float(s["thick"]); var spikes := int(s["spikes"]); var slen := float(s["slen"])
	var knee := w * 0.42
	for x in w:
		var t := T
		if x > knee:
			var e := float(x - knee)
			t = T + slope * e * (e / (w - knee)) * 1.3
		top[x] = clampf(t, 4.0, h - 40.0)
		bot[x] = minf(top[x] + thick * _endwin(x, w, w * 0.14) + _spikes_down(x, w, n, spikes, slen, true), h - 1)

func _b_ledge(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var T := float(s["T"]); var thick := float(s["thick"])
	var spikes := int(s["spikes"]); var slen := float(s["slen"])
	var drop_left := str(s["drop"]) == "left"
	for x in w:
		top[x] = T + 2.0 * sin(x * 0.012)
		var fx := float(x) / w
		var cliff := (fx < 0.28) if drop_left else (fx > 0.72)
		if cliff:
			bot[x] = h - 1
		else:
			bot[x] = minf(top[x] + thick * _endwin(x, w, w * 0.14) + _spikes_down(x, w, n, spikes, slen, true), h - 1)

func _b_ceiling(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var thick := float(s["thick"]); var spikes := int(s["spikes"]); var slen := float(s["slen"])
	for x in w:
		top[x] = 0.0
		var b := thick + thick * 0.22 * absf(_nz(n, x, 0.018, 0.0))
		b += _spikes_down(x, w, n, spikes, slen, false)
		bot[x] = minf(b, h - 1)

func _b_bridge(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var T := float(s["T"]); var arch := float(s["arch"]); var thick := float(s["thick"])
	var support := float(s["support"]); var spikes := int(s["spikes"]); var slen := float(s["slen"])
	for x in w:
		top[x] = T - arch * sin(PI * float(x) / w)
		if x < support or x > w - support:
			bot[x] = h - 1
		else:
			bot[x] = minf(top[x] + thick + _spikes_down(x, w, n, spikes, slen, false), h - 1)

func _b_stairs(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var steps := int(s["steps"])
	var sw := float(w) / steps; var sh := float(h - 30) / steps
	for x in w:
		var i := int(x / sw)
		top[x] = (h - 20) - (i + 1) * sh
		bot[x] = h - 1

func _b_pillar(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var hw := float(s["hw"]) * w; var amp := float(s["amp"]) * w
	var twist := float(s.get("twist", 0.0)) * w; var taper := bool(s.get("taper", false))
	var cx := w * 0.5
	for y in h:
		var yy := float(y)
		var half := hw + amp * _nz(n, yy, 0.008, 0.0)
		if taper:
			half = hw * (0.10 + 0.90 * clampf(yy / h, 0.0, 1.0))
		var cxx := cx + twist * sin(yy * 0.004)
		_acc(top, bot, w, cxx - half, cxx + half, y)

func _b_blob(s, n, top, bot) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var rx := float(s["rx"]); var ry := float(s["ry"])
	var flat_top := bool(s.get("flat_top", false))
	var lump := float(s.get("lump", 0.14)); var skew := float(s.get("skew", 0.0))
	var cx := w * 0.5; var cy := h * 0.5
	var cut := cy - ry * 0.45
	for y in h:
		var dy := (y - cy) / ry
		if absf(dy) > 1.0:
			continue
		if flat_top and y < cut:
			continue
		var half := rx * sqrt(1.0 - dy * dy) * (1.0 + lump * _nz(n, y, 0.02, 0.0))
		var cxx := cx + skew * (y - cy)        # 기울어진 비대칭 발판
		_acc(top, bot, w, cxx - half, cxx + half, y)

## 가시: 바닥 + 위로 솟은 촘촘한 뾰족 가시 (즉사). map1 Platform_Thorn 참고.
func _b_thorn(s: Dictionary, n: FastNoiseLite, top: PackedFloat32Array, bot: PackedFloat32Array) -> void:
	var w := int(s["w"]); var h := int(s["h"])
	var base := float(s["base"]); var dense := int(s["dense"]); var slen := float(s["slen"])
	for x in w:
		var up := 0.0
		for i in dense:
			var xc := (i + 0.5) / dense * w + 6.0 * n.get_noise_2d(i * 5.0, 2.0)
			var sw := w / float(dense) * (0.28 + 0.22 * absf(n.get_noise_2d(i * 3.1, 8.0)))
			var ln := slen * (0.35 + 0.75 * absf(n.get_noise_2d(i * 9.7, 4.0)))
			if absf(x - xc) < sw:
				up = maxf(up, ln * pow(1.0 - absf(x - xc) / sw, 1.6))  # 뾰족(지수>1)
		top[x] = clampf((h - base) - up, 2.0, h - 1)
		bot[x] = h - 1

func _acc(top, bot, w, x0, x1, y) -> void:
	var a := clampi(int(x0), 0, w - 1); var b := clampi(int(x1), 0, w - 1)
	for xi in range(a, b + 1):
		if y < top[xi]: top[xi] = y
		if y > bot[xi]: bot[xi] = y

## ── 렌더: 통짜 단색(민무늬) ─────────────────────────────────────────────
func _render(w: int, h: int, top: PackedFloat32Array, bot: PackedFloat32Array, col: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in w:
		if top[x] > bot[x]:
			continue
		var t := clampi(int(round(top[x])), 0, h)
		var b := clampi(int(round(bot[x])), 0, h)
		if b > t:
			img.fill_rect(Rect2i(x, t, 1, b - t), col)
	return img
