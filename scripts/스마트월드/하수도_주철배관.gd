@tool
extends Node2D
## ============================================================================
## [2026-09-30 Claude] 하수도 주철 배관 — 점만 찍으면 직관 · 둥근 엘보 · 고정 밴드 · 끝 플랜지가 붙는다
## ----------------------------------------------------------------------------
## ▣ 왜 (도형님: "배관 디자인이 우리 게임 분위기와 조금 다르다")
##   회색 배관 SS2D 키트는 밝은 회색 · 매끈한 강관 · 칼로 자른 직각 모서리 · 조명 무반응이라
##   어두운 주철 세계(호퍼·격자·가시·톱·성수반)와 배경 원화의 검은 주철관 옆에서 따로 놀았다.
##   → 배경 원화의 관을 기준으로 `tools/생성_주철배관.py` 가 부품을 굽고(노멀맵 포함), 여기서 경로대로 잇는다.
##
## ▣ 쓰는 법
##   `점들` 에 경로를 적는다(수평·수직만). 꺾이는 점마다 엘보가 저절로 들어간다.
##   꺾이는 두 점 사이는 엘보 반지름(36) × 2 = 72 px 이상 떨어져야 엘보끼리 안 겹친다.
##
## ▣ 그림뿐이다 — 충돌 없음 · 색 규칙 없음 · 총알 통과(배관 키트와 같다).
## ⚠ 규격 상수는 굽는 도구와 같아야 한다. 부품 그림은 손으로 고치지 말고 도구를 다시 돌린다.
## ============================================================================

const 폴더 := "res://assets/textures/obstacles/pipe/cast_iron_v1/"
const 굽기배율 := 2.0            # 부품은 2 배로 구웠다 → 0.5 배로 그린다
const 관_반지름 := 20.0
const 엘보_반지름 := 36.0         # 엘보 중심선 반지름
const 여백 := 8.0                 # 부품 그림 가장자리 여유(외곽선 자리)

## 경로(이 노드 기준). 수평·수직 선분만.
@export var 점들: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(256, 0)]):
	set(v): 점들 = v; queue_redraw()
## 벽 고정 밴드 간격(px). 0 이면 밴드 없음. 배경 원화 관처럼 드문드문 박는다.
@export_range(0.0, 1200.0, 8.0) var 밴드_간격: float = 256.0:
	set(v): 밴드_간격 = v; queue_redraw()
@export var 시작_플랜지: bool = true:
	set(v): 시작_플랜지 = v; queue_redraw()
@export var 끝_플랜지: bool = true:
	set(v): 끝_플랜지 = v; queue_redraw()
## ★[2026-09-30] 관이 붙을 장치. `배관_포트()` 가 있는 것(제어레버)이면 그 포트에 첫 점을 붙이고,
##   `크기` 가 있는 물(유체·웅덩이)이면 윗면 가운데에 붙는다. 비우면 `점들` 그대로.
##   붙으면 첫/끝 점을 포트로 옮기고, 그 다음 점을 포트와 같은 줄로 당겨 직각을 유지한다
##   → 레버를 옮겨도 관이 따라오고, 손으로 적은 좌표가 어긋나 관이 떠 있는 일이 없다.
@export var 시작_장치: NodePath:
	set(v): 시작_장치 = v; _연결_알리기(); queue_redraw()
@export var 끝_장치: NodePath:
	set(v): 끝_장치 = v; _연결_알리기(); queue_redraw()

## 포트에서 장치 안쪽으로 관을 더 밀어 넣는 길이 — 장치 몸체가 관 끝을 덮어 "안으로 들어간다" 로 보인다.
const 밀어넣기 := 8.0

static var _그림들: Dictionary = {}


func _연결_알리기() -> void:
	if not is_inside_tree():
		return
	for 경로 in [시작_장치, 끝_장치]:
		var n := get_node_or_null(경로)
		if n != null and "배관_연결됨" in n:
			n.set("배관_연결됨", true)


## 장치 → {위치(로컬), 방향(관이 장치에서 나가는 쪽), 칼라(로컬 자리들)} · 없으면 빈 사전
func _포트(경로: NodePath, _끝쪽: bool) -> Dictionary:
	var n := get_node_or_null(경로) if not 경로.is_empty() else null
	if n == null:
		return {}
	if n.has_method("배관_포트"):
		var p: Dictionary = n.call("배관_포트")
		var 칼라 := []
		for g in p.get("칼라", []):
			칼라.append(to_local(g))
		return {"위치": to_local(p["위치"]), "방향": (p["방향"] as Vector2), "칼라": 칼라, "밀기": true}
	if "크기" in n and n is Node2D:
		# 물: 노드 원점 = 윗면 가운데. 관은 위에서 내려와 물 윗면에 닿는다(관이 물에서 나가는 쪽 = 위).
		return {"위치": to_local((n as Node2D).global_position), "방향": Vector2.UP, "칼라": [], "밀기": false}
	return {}


## 실제로 그릴 경로 — `점들` 의 양끝을 장치 포트에 붙인 것.
func _경로() -> PackedVector2Array:
	var p := 점들.duplicate()
	if p.size() < 2:
		return p
	for 끝쪽 in [false, true]:
		var 포 := _포트(끝_장치 if 끝쪽 else 시작_장치, 끝쪽)
		if 포.is_empty():
			continue
		var i := p.size() - 1 if 끝쪽 else 0
		var 옆 := p.size() - 2 if 끝쪽 else 1
		var d: Vector2 = 포["방향"]
		var 자리: Vector2 = 포["위치"]
		p[i] = 자리 - d * (밀어넣기 if 포["밀기"] else 0.0)
		# 다음 점을 포트와 같은 줄로 당긴다(가로로 나가면 y 를, 세로로 나가면 x 를 맞춘다)
		if absf(d.x) > 0.5:
			p[옆].y = 자리.y
		else:
			p[옆].x = 자리.x
	return p


## 부품 = 그림 + 노멀맵(CanvasTexture) → 벽등 빛이 관 둥근 면을 따라 흐른다.
static func _부품(이름: String) -> Texture2D:
	if _그림들.has(이름):
		return _그림들[이름]
	var t := CanvasTexture.new()
	t.diffuse_texture = load(폴더 + 이름 + ".png")
	if ResourceLoader.exists(폴더 + 이름 + "_n.png"):
		t.normal_texture = load(폴더 + 이름 + "_n.png")
	t.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_그림들[이름] = t
	return t


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_연결_알리기()
	queue_redraw()


func _꺾임(경로점: PackedVector2Array, i: int) -> bool:
	if i <= 0 or i >= 경로점.size() - 1:
		return false
	var a := (경로점[i] - 경로점[i - 1]).normalized()
	var b := (경로점[i + 1] - 경로점[i]).normalized()
	return absf(a.dot(b)) < 0.5


## ============================================================================
## ★[2026-09-30] 이음점(티·십자) — 도형님: "배관이 갈라지는 부분이 이상하게 끊겨 있다.
##   앞으로 다른 스테이지에서도 갈라지는 부분이 있으면 자연스럽게 붙게 해."
##   예전: 한 관이 엘보로 꺾이는 점에서 다른 관이 따로 시작 → 엘보 모서리와 관 끝이 어긋나 끊겨 보였다.
##   지금: **같은 부모 아래의 주철배관들**을 모아, 한 점에 세 방향 이상이 모이면 이음점으로 본다.
##     · 한 관의 끝점이 다른 관의 선분 한가운데 놓여도(곧은 관에서 가지가 나올 때) 이음점이 된다.
##     · 이음점에서는 엘보·끝 플랜지를 그리지 않고 관을 이음점까지 곧게 그린다.
##     · 그 위에 티(세 방향) / 십자(네 방향) 이음쇠를 **나무 순서상 가장 뒤의 관**이 한 번만 덮어 그린다
##       (앞의 관이 그리면 뒤 관이 그 위를 덮어 버린다).
##   → 맵에 놓을 때는 가지 관의 끝점을 본관 위(꺾임점이든 곧은 구간이든)에 찍기만 하면 된다.
## ============================================================================
const _방향글자 := {Vector2i(-1, 0): "l", Vector2i(1, 0): "r", Vector2i(0, -1): "u", Vector2i(0, 1): "d"}


func _형제관들() -> Array:
	var 관들 := []
	if get_parent() == null:
		return [self]
	for n in get_parent().get_children():
		if n.get_script() == get_script() and n.is_visible_in_tree():
			관들.append(n)
	return 관들


static func _열쇠(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))


## 전역 열쇠 → {"방향": Array[Vector2i], "주인": Node}  (세 방향 이상 모인 곳만)
func _이음점들() -> Dictionary:
	var 관들 := _형제관들()
	var 경로들 := {}
	for 관 in 관들:
		var g := PackedVector2Array()
		for p in 관.call("_경로"):
			g.append(관.to_global(p))
		경로들[관] = g
	var 팔 := {}
	var 넣기 := func(p: Vector2, 방향들: Array, 관: Node) -> void:
		var 열 := _열쇠(p)
		if not 팔.has(열):
			팔[열] = {"방향": [], "관": []}
		for d in 방향들:
			var di := Vector2i(roundi(d.x), roundi(d.y))
			if not 팔[열]["방향"].has(di):
				팔[열]["방향"].append(di)
		if not 팔[열]["관"].has(관):
			팔[열]["관"].append(관)
	for 관 in 관들:
		var g: PackedVector2Array = 경로들[관]
		for i in g.size():
			var 방향들 := []
			if i > 0:
				방향들.append((g[i - 1] - g[i]).normalized())
			if i < g.size() - 1:
				방향들.append((g[i + 1] - g[i]).normalized())
			넣기.call(g[i], 방향들, 관)
	# 끝점이 다른 관의 곧은 구간 한가운데 놓인 경우 — 그 관은 그 점에서 양쪽으로 지나간다
	for 관 in 관들:
		var g: PackedVector2Array = 경로들[관]
		for e in [g[0], g[g.size() - 1]]:
			for 다른 in 관들:
				if 다른 == 관:
					continue
				var h: PackedVector2Array = 경로들[다른]
				for j in h.size() - 1:
					var 가까운 := Geometry2D.get_closest_point_to_segment(e, h[j], h[j + 1])
					if 가까운.distance_to(e) < 1.0 and e.distance_to(h[j]) > 1.0 and e.distance_to(h[j + 1]) > 1.0:
						var d := (h[j + 1] - h[j]).normalized()
						넣기.call(e, [d, -d], 다른)
	var 결과 := {}
	for 열 in 팔:
		if 팔[열]["방향"].size() >= 3:
			var 주인: Node = 팔[열]["관"][0]
			for 관 in 팔[열]["관"]:
				if 관.get_index() > 주인.get_index():
					주인 = 관
			결과[열] = {"방향": 팔[열]["방향"], "주인": 주인}
	return 결과


func _draw() -> void:
	var 경로점 := _경로()
	if 경로점.size() < 2:
		return
	var 시작포트 := _포트(시작_장치, false)
	var 끝포트 := _포트(끝_장치, true)
	var 이음들 := _이음점들()
	var 이음인가 := func(p: Vector2) -> bool: return 이음들.has(_열쇠(to_global(p)))
	var k := 1.0 / 굽기배율
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))     # 이 안에서는 좌표를 2 배로 적는다
	var 두께 := (관_반지름 + 여백) * 2.0
	# 1) 직관 — 꺾이는 끝은 엘보 반지름만큼 줄인다(이음점은 줄이지 않는다 — 이음쇠가 덮는다)
	var 밴드들: Array = []
	for i in 경로점.size() - 1:
		var a := 경로점[i]
		var b := 경로점[i + 1]
		var d := (b - a).normalized()
		if _꺾임(경로점, i) and not 이음인가.call(경로점[i]):
			a += d * 엘보_반지름
		if _꺾임(경로점, i + 1) and not 이음인가.call(경로점[i + 1]):
			b -= d * 엘보_반지름
		var 가로 := absf(d.x) > 0.5
		var 사각 := Rect2(a.min(b), (b - a).abs())
		사각 = 사각.grow_individual(0, 두께 * 0.5, 0, 두께 * 0.5) if 가로 else 사각.grow_individual(두께 * 0.5, 0, 두께 * 0.5, 0)
		draw_texture_rect(_부품("straight_h" if 가로 else "straight_v"), Rect2(사각.position * 굽기배율, 사각.size * 굽기배율), true)
		# 밴드 자리: 선분을 같은 간격으로 나눈 가운데들(끝 부품과 겹치지 않게 양끝 48 비움)
		var 길이 := a.distance_to(b)
		if 밴드_간격 > 0.0 and 길이 > 120.0:
			var 개수 := maxi(1, int(round((길이 - 96.0) / 밴드_간격)))
			for j in 개수:
				밴드들.append([a + d * (48.0 + (길이 - 96.0) * (j + 0.5) / 개수), 가로])
	# 2) 엘보 — 들어오는 방향 a, 나가는 방향 b 이면 원 중심 = 꺾임점 − a·R + b·R, 사분면 = a − b 의 부호
	for i in range(1, 경로점.size() - 1):
		if not _꺾임(경로점, i) or 이음인가.call(경로점[i]):
			continue
		var a := (경로점[i] - 경로점[i - 1]).normalized()
		var b := (경로점[i + 1] - 경로점[i]).normalized()
		var 중심 := 경로점[i] - a * 엘보_반지름 + b * 엘보_반지름
		var q := a - b
		var 크기 := 엘보_반지름 + 관_반지름 + 여백
		var 원점 := Vector2(중심.x if q.x > 0 else 중심.x - 크기, 중심.y if q.y > 0 else 중심.y - 크기)
		var 이름 := "elbow_%s%s" % ["p" if q.x > 0 else "n", "p" if q.y > 0 else "n"]
		draw_texture_rect(_부품(이름), Rect2(원점 * 굽기배율, Vector2(크기, 크기) * 굽기배율), false)
	# 3) 고정 밴드
	for 밴드 in 밴드들:
		_가운데_그리기("band_h" if 밴드[1] else "band_v", 밴드[0])
	# 4) 끝 플랜지 — 관 끝에서 6 안쪽. 장치에 붙은 끝은 장치가 알려 준 칼라 자리에 플랜지를 두른다
	#    (포트 안쪽으로 밀어 넣은 관 끝은 장치 몸체에 가려지므로, 이음 고리는 몸체 바로 바깥에 있어야 보인다).
	var n := 경로점.size()
	var d0 := (경로점[1] - 경로점[0]).normalized()
	var d1 := (경로점[n - 1] - 경로점[n - 2]).normalized()
	for 끝 in [[시작포트, 시작_플랜지, 경로점[0] + d0 * 6.0, d0, 경로점[0]], [끝포트, 끝_플랜지, 경로점[n - 1] - d1 * 6.0, d1, 경로점[n - 1]]]:
		var 포: Dictionary = 끝[0]
		var 이름 := "flange_h" if absf((끝[3] as Vector2).x) > 0.5 else "flange_v"
		if not 포.is_empty() and not (포["칼라"] as Array).is_empty():
			for 자리 in 포["칼라"]:
				_가운데_그리기(이름, 자리)
		elif 끝[1] and not 이음인가.call(끝[4]):
			_가운데_그리기(이름, 끝[2])
	# 5) 이음쇠 — 이 관이 주인인 이음점만. 세 방향 = 빠진 쪽의 반대가 가지(tee_<가지>), 네 방향 = 십자
	for 열 in 이음들:
		var 이음: Dictionary = 이음들[열]
		if 이음["주인"] != self:
			continue
		var 방향들: Array = 이음["방향"]
		var 이름 := "tee_x"
		if 방향들.size() == 3:
			for 빠진 in _방향글자:
				if not 방향들.has(빠진):
					이름 = "tee_" + _방향글자[-빠진]
		_가운데_그리기(이름, to_local(Vector2(열)))
	draw_set_transform(Vector2.ZERO)


func _가운데_그리기(이름: String, 자리: Vector2) -> void:
	var t := _부품(이름)
	var 크기 := t.get_size()
	draw_texture_rect(t, Rect2(자리 * 굽기배율 - 크기 * 0.5, 크기), false)
