@tool
extends RefCounted
## 하수도 마감메시의 노출 구간/이웃 가림 방식을 참고한 목재 전용 덮개.
## 모든 마감을 메시 하나로 합친다. 충돌 점 추가·매 프레임 재생성·픽셀별 경계 검색은 없다.

## [v06] 양 끝 깊이선은 같은 방향으로 내려간다. 직각 기둥판으로 사선을 덮지 않는다.
const 투영폭 := 18.0
const 마감폭 := 3.0

## 상판과 본체가 같은 절단선을 사용해야 빈 삼각형을 네모 본체가 다시 채우지 않는다.
## 충돌 점은 그대로 두고, 그림용 메시에서만 이 조각을 뺀다.
##
## ★[2026-10-06 Claude] 깎을 모서리를 한 곳(모서리목록)에서 찾고, 두 방식으로 쓴다.
##   · 모서리절단() = 덮개 메시(상판·옆면)를 자르는 작은 다각형
##   · 깎은_윤곽() = 앞면 채우기의 꼭짓점을 옮긴 윤곽 — Clipper 를 쓰지 않는다.
##     (10-05 밤: Clipper 로 깎으면 방 둘레 액자형 벽이 구멍을 잃어 배경을 덮었고, 구멍이 생기는 모서리를
##      건너뛰게 하자 이번엔 그 벽의 앞면 모서리가 네모로 남아 "튀어나와" 보였다 — 도형님 10-06 지적.)
##   투영: 상자의 뒷면은 앞면에서 (−18, −22) 만큼 왼 위로 밀려 있다(상판 −4…18 · 왼 옆면 18px).
##     → 실루엣은 **오른 위**와 **왼 아래** 두 모서리가 같은 기울기(22/18)로 잘린다.
##        왼 위(옆면이 보이는 곳)와 오른 아래(앞면 모서리)는 직각 그대로다.
static func 모서리목록(points: PackedVector2Array, others: Array[PackedVector2Array]) -> Array:
	var p := 정리(points)
	var out: Array = []
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i+1)%n]
		var c := p[(i+2)%n]
		# ── 오른 위: 윗변(→) 다음이 오른 벽(↓) ─────────────────────────────
		if b.x-a.x >= 12.0 and absf(b.y-a.y) <= 0.01 and c.y > b.y:
			var joined := false
			for other in others:
				if Geometry2D.is_point_in_polygon(b+Vector2(0.5,0.5),other):
					joined = true
			if not joined:
				for interval in 노출(a,b,others):
					if interval.y < 0.9999:
						continue
					var span := (b.x-a.x)*(interval.y-interval.x)
					if span < 12.0:
						continue
					var shift := minf(투영폭,span*0.375)
					# 오른 벽이 상판 앞 단면(18px)보다 짧으면 꼭짓점을 옮길 수 없다 → 덮개만 깎는다
					out.append({"종류": "오른위", "i": (i+1)%n, "shift": shift, "벽": absf(c.x-b.x) < 0.5 and c.y-b.y > 18.5})
		# ── 왼 아래: 아랫변(←, a→b) 다음이 왼 벽(↑, b→c) ──────────────────
		if a.x-b.x >= 12.0 and absf(b.y-a.y) <= 0.01 and absf(c.x-b.x) < 0.5 and c.y < b.y - 12.0:
			# 다른 지형에 얹혀 있거나(아래) 옆에 붙어 있으면(왼쪽) 깎지 않는다 — 접합부에 틈이 생긴다.
			var 붙음 := false
			for other in others:
				if Geometry2D.is_point_in_polygon(b+Vector2(6.0,2.0),other) or Geometry2D.is_point_in_polygon(b+Vector2(-2.0,-6.0),other):
					붙음 = true
			if 붙음:
				continue
			var shift := minf(투영폭,minf((a.x-b.x)*0.375,(b.y-c.y)*0.5*18.0/22.0))
			out.append({"종류": "왼아래", "i": (i+1)%n, "shift": shift, "벽": true})
	return out

static func 모서리절단(points: PackedVector2Array, others: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var p := 정리(points)
	var cuts: Array[PackedVector2Array] = []
	for m in 모서리목록(points, others):
		var b: Vector2 = p[m["i"]]
		var shift: float = m["shift"]
		if m["종류"] == "오른위":
			cuts.append(PackedVector2Array([b+Vector2(-shift,-4),b+Vector2(1,-4),b+Vector2(1,18),b+Vector2(0,18)]))
		else:
			# [2026-10-06] 왼 아래 삼각형: (l, 바닥−22) → (l+18, 바닥) 선 아래·왼쪽을 지운다(옆면 띠도 같이).
			var rise := shift*22.0/18.0
			cuts.append(PackedVector2Array([b+Vector2(-2,-rise),b+Vector2(0,-rise),b+Vector2(shift,0),b+Vector2(shift,3),b+Vector2(-2,3)]))
	return cuts

## [2026-10-06 Claude] 앞면 채우기용 윤곽 — 모서리 꼭짓점 하나를 사선 위의 두 꼭짓점으로 바꾼다.
##   점 순서와 액자형 벽의 틈(slit)은 그대로라 구멍이 사라지지 않는다. 충돌(_points)은 건드리지 않는다.
static func 깎은_윤곽(points: PackedVector2Array, others: Array[PackedVector2Array]) -> PackedVector2Array:
	var p := 정리(points)
	var 바꿈 := {}
	for m in 모서리목록(points, others):
		if not m["벽"]:
			continue
		var b: Vector2 = p[m["i"]]
		var shift: float = m["shift"]
		if m["종류"] == "오른위":
			# 사선 (b.x−shift, −4) → (b.x, 18) 이 충돌선(y=0)을 지나는 x = b.x − shift·18/22
			바꿈[m["i"]] = [b+Vector2(-shift*18.0/22.0,0.0), b+Vector2(0.0,18.0)]
		else:
			바꿈[m["i"]] = [b+Vector2(shift,0.0), b+Vector2(0.0,-shift*22.0/18.0)]
	if 바꿈.is_empty():
		return p
	var out := PackedVector2Array()
	for i in p.size():
		if 바꿈.has(i):
			out.append_array(PackedVector2Array(바꿈[i]))
		else:
			out.append(p[i])
	return out

static func 정리(points: PackedVector2Array) -> PackedVector2Array:
	var p := points.duplicate()
	if p.size() > 1 and p[0].is_equal_approx(p[-1]):
		p.remove_at(p.size() - 1)
	var changed := true
	while changed and p.size() > 3:
		changed = false
		for i in p.size():
			var a := p[i] - p[(i - 1 + p.size()) % p.size()]
			var b := p[(i + 1) % p.size()] - p[i]
			if a.length_squared() < 0.0001 or (absf(a.cross(b)) < 0.001 and a.dot(b) > 0.0):
				p.remove_at(i)
				changed = true
				break
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	return p

static func 노출(a: Vector2, b: Vector2, others: Array[PackedVector2Array]) -> Array[Vector2]:
	var v := b - a
	var length := v.length()
	var n := Vector2(v.y, -v.x).normalized()
	var start := a + n * 0.5
	var finish := b + n * 0.5
	var cuts: Array[float] = [0.0, 1.0]
	for polygon in others:
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(start, finish, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				cuts.append(clampf((Vector2(hit) - start).dot(v / length) / length, 0.0, 1.0))
	cuts.sort()
	var result: Array[Vector2] = []
	for i in range(cuts.size() - 1):
		if cuts[i + 1] - cuts[i] < 0.00001:
			continue
		var mid := start.lerp(finish, (cuts[i] + cuts[i + 1]) * 0.5)
		var covered := false
		for polygon in others:
			if Geometry2D.is_point_in_polygon(mid, polygon):
				covered = true
				break
		if not covered:
			result.append(Vector2(cuts[i], cuts[i + 1]))
	return result

static func 가림(parts: Array[PackedVector2Array], others: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	for other in others:
		var next: Array[PackedVector2Array] = []
		for piece in parts:
			for clipped in Geometry2D.clip_polygons(piece, other):
				if not Geometry2D.is_polygon_clockwise(clipped):
					next.append(clipped)
		parts = next
	return parts

## [2026-10-05 Claude v05] 접촉 그림자. c = Vector4(벽 x, 방향, 폭 px, 세기).
##   방향 +1 = 벽이 오른쪽(상자 왼 밑동 — 은은한 틈 그늘) · −1 = 벽이 왼쪽(빛이 왼 위라 벽 그림자가 오른쪽으로 드리운다).
static func 그림자(p: Vector2, contacts: Array) -> float:
	var k := 1.0
	for c in contacts:
		var dist: float = (c.x - p.x) * c.y
		k *= 1.0 - c.w * (1.0 - clampf(dist / c.z, 0.0, 1.0))
	return k

## 그림자가 꼭짓점 사이에서 선형으로 번지도록, 그림자 띠 안쪽 끝(x)에서 조각을 세로로 나눈다.
static func x나누기(parts: Array[PackedVector2Array], cuts: Array[float]) -> Array[PackedVector2Array]:
	const 멀리 := 100000.0
	for x in cuts:
		var next: Array[PackedVector2Array] = []
		var 왼 := PackedVector2Array([Vector2(-멀리,-멀리),Vector2(x,-멀리),Vector2(x,멀리),Vector2(-멀리,멀리)])
		var 오른 := PackedVector2Array([Vector2(x,-멀리),Vector2(멀리,-멀리),Vector2(멀리,멀리),Vector2(x,멀리)])
		for piece in parts:
			for half in [왼, 오른]:
				for clipped in Geometry2D.intersect_polygons(piece, half):
					if not Geometry2D.is_polygon_clockwise(clipped):
						next.append(clipped)
		parts = next
	return parts

## [2026-10-05 Claude] run_l / run_w = 이 상판 구간의 왼쪽 끝 x 와 '맞춘' 판자 폭(px).
##   도형님: "윗면 이미지의 나무판자 타일 크기에 맞추어 끝나는 지점을 맞춰야" — 월드 좌표 64px 반복을 쓰면
##   32px 격자 발판(예: 5칸 = 160px)의 끝에서 판자가 반 장씩 잘린다. 그래서 구간마다 판자 수 n = round(길이/64) 로
##   폭을 살짝 늘이거나 줄여 **왼쪽 끝 사선과 오른쪽 끝이 정확히 이음새**가 되게 한다.
static func 면추가(data: Dictionary, poly: PackedVector2Array, own: PackedVector2Array, others: Array[PackedVector2Array], a: Vector2, b: Vector2, kind: int, inside: bool = true, run_l: float = 0.0, run_w: float = 64.0, contacts: Array = [], run_shift: float = 18.0, clip: bool = true) -> void:
	if Geometry2D.is_polygon_clockwise(poly):
		poly = poly.duplicate()
		poly.reverse()
	var parts: Array[PackedVector2Array] = []
	if not clip:
		# [2026-10-07] 이웃 지형 위로 넘어가는 이음새 쐐기 — 자기·이웃 다각형으로 자르지 않는다(아래 생성() 참고).
		parts.append(poly)
	elif inside:
		for clipped in Geometry2D.intersect_polygons(poly, own):
			if not Geometry2D.is_polygon_clockwise(clipped):
				parts.append(clipped)
	else:
		# 충돌선 위 4px의 뒷모서리만 돌출시킨다. 같은 지형의 벽에 가려진 부분은 뺀다.
		for clipped in Geometry2D.clip_polygons(poly, own):
			if not Geometry2D.is_polygon_clockwise(clipped):
				parts.append(clipped)
	if clip:
		parts = 가림(parts, others)
		parts = 가림(parts, data["corner_cuts"])
	if not contacts.is_empty():
		var cuts: Array[float] = []
		for c in contacts:
			cuts.append(c.x - c.y * c.z)
		parts = x나누기(parts, cuts)
	var inward := Vector2(-(b-a).y, (b-a).x).normalized()
	for piece in parts:
		var triangles := Geometry2D.triangulate_polygon(piece)
		if triangles.is_empty():
			continue
		var offset: int = data["vertices"].size()
		for p in piece:
			data["vertices"].append(p)
			data["colors"].append(Color(1.0, 그림자(p, contacts), 1.0, 1.0))
			var origin: Vector2 = data["origin"]
			var uv := Vector2((p.x+origin.x) / 256.0, (p.y-a.y+4.0)/30.0)
			if kind == 0:
				# 상판(뒤 4px 돌출 포함)·앞 단면: 판자 좌표를 메시에서 미리 굽는다(셰이더는 uv.x*4 를 그대로 판자 번호로 쓴다).
				#   깊이(뒤 0 → 앞 1, 22px)만큼 18px 오른쪽으로 밀린 사선 = 왼쪽 끝 단면과 같은 투영 방향.
				#   상판 사각형 안에서는 선형이라 꼭짓점에만 넣어도 정확하다.
				var depth := clampf((p.y - (a.y - 4.0)) / 22.0, 0.0, 1.0)
				uv.x = ((p.x - run_l - run_shift * depth) / run_w) / 4.0
			elif kind == 2 or kind == 3:
				uv.y = float(kind) + clampf((p.y-a.y+4.0)/30.0, 0.0, 0.999)
			elif kind >= 4:
				var width := run_shift if kind == 4 else 마감폭
				var across := clampf((p-a).dot(inward)/width, 0.0, 0.999)
				var along := 0.0
				if kind == 4:
					# [2026-10-05 Claude] 왼 단면 = 상자의 옆면. 앞면 판자 줄(월드 y 32px)이 모서리를 돌아
					#   옆면으로 이어지도록, 옆면 이음새는 바깥(뒤)으로 갈수록 22px 올라가는 사선이다.
					#   across 0 = 바깥 모서리(뒤) · 1 = 앞면과 만나는 선 → 거기서 앞면 이음새와 정확히 이어진다.
					along = (p.y + origin.y + (1.0 - across) * 22.0) / 32.0
				else:
					along = (p.x + origin.x) / 64.0
				uv = Vector2(along, float(kind) + across)
			data["uvs"].append(uv)
		for index in triangles:
			data["indices"].append(offset + index)

## [2026-10-07] 이 점(끝 바로 옆·충돌선 바로 아래)이 이웃 지형 안인가 — 같은 높이로 붙은 이웃.
static func _옆이웃(점: Vector2, others: Array[PackedVector2Array]) -> bool:
	for other in others:
		if Geometry2D.is_point_in_polygon(점, other):
			return true
	return false


static func 생성(points: PackedVector2Array, others: Array[PackedVector2Array], origin: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var p := 정리(points)
	var mesh := ArrayMesh.new()
	if p.size() < 3:
		return mesh
	# Dictionary 안의 Array를 쓴 뒤 마지막에 PackedArray로 변환한다(값 복사로 정점이 유실되는 것 방지).
	var data := {"vertices": [], "uvs": [], "indices": [], "colors": [], "origin": origin, "corner_cuts": 모서리절단(p,others)}
	# 왼 단면은 18px 폭의 독립된 면, 오른쪽은 3px 모서리선. 상판 그림을 돌려 쓰지 않는다.
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		var t := (b-a).normalized()
		var n := Vector2(t.y,-t.x)
		var kind := 6 if n.y > 0.65 else (4 if n.x < 0.0 else 7)
		if n.y < -0.001 or (absf(n.x) < 0.90 and n.y < 0.65):
			continue
		for interval in 노출(a,b,others):
			var l := a.lerp(b,interval.x)
			var r := a.lerp(b,interval.y)
			var width := 18.0 if kind == 4 else 마감폭
			# 한 칸짜리 좁은 발판도 상판과 옆면이 같은 폭에서 만나야 한다.
			var next := p[(i+2)%p.size()]
			if kind == 4 and absf(next.y-b.y) < 0.01 and next.x-b.x >= 12.0:
				width = minf(투영폭,(next.x-b.x)*0.375)
			면추가(data,PackedVector2Array([l,r,r-n*width,l-n*width]),p,others,a,b,kind,true,0.0,64.0,[],width)
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		# 수평인 발판만 덮는다. 세로벽·모따기·깨진 단면에는 상판을 생성하지 않는다.
		if b.x-a.x < 12.0 or absf(b.y-a.y) > 0.01:
			continue
		var left_end := (a-p[(i-1+p.size())%p.size()]).cross(b-a) > 0.01
		var right_end := (b-a).cross(p[(i+2)%p.size()]-b) > 0.01
		# 같은 높이의 이웃에 붙은 끝은 단면이 아니다. 연결된 상판 안에 사선 틈이 생기지 않게 한다.
		for other in others:
			if Geometry2D.is_point_in_polygon(a+Vector2(-0.5,0.5),other):
				left_end = false
			if Geometry2D.is_point_in_polygon(b+Vector2(0.5,0.5),other):
				right_end = false
		# [v05] 안쪽 모서리(같은 지형의 계단 벽이 위로 솟음)
		var concave_l := p[(i-1+p.size())%p.size()].y < a.y - 0.5
		var concave_r := p[(i+2)%p.size()].y < b.y - 0.5
		for interval in 노출(a,b,others):
			var l := a.lerp(b,interval.x)
			var r := a.lerp(b,interval.y)
			if r.x-l.x < 12.0:
				continue
			# [v05] 접촉 그림자: 왼쪽에 벽(이웃 상자 또는 계단 윗단) → 드리운 그림자 · 오른쪽에 벽 → 밑동 그늘.
			var contacts: Array = []
			if interval.x > 0.0001 or concave_l:
				contacts.append(Vector4(l.x, -1.0, minf(30.0, (r.x-l.x)*0.5), 0.62))
			if interval.y < 0.9999 or concave_r:
				contacts.append(Vector4(r.x, 1.0, minf(18.0, (r.x-l.x)*0.4), 0.52))
			# 왼 끝 단면 폭은 옆벽 단면(18px)과 같게 — 두 면이 한 장의 옆면으로 이어진다. 아주 짧은 발판만 줄인다.
			var shift := minf(투영폭,(r.x-l.x)*0.375)
			var li := shift if left_end and interval.x < 0.0001 else 0.0
			# 판자 맞춤: 이 구간에 들어갈 판자 수 n 과 폭 w. 뒤 왼쪽 모서리(l)와 뒤 오른쪽 모서리(r)가 이음새.
			# 오른 뒤 꼭짓점을 왼쪽으로 당겨 왼 끝과 평행하게 내린다. 본체도 모서리절단으로 함께 깎는다.
			var ri := shift if right_end and interval.y > 0.9999 else 0.0
			# 오목한 계단 밑동에서는 낮은 상판이 옆벽 앞모서리까지 사선으로 물린다.
			# 여기서 수직으로 끊으면 사용자가 표시한 네모 막음 조각이 다시 생긴다.
			var meet := shift if concave_r and interval.y > 0.9999 else 0.0
			# ★[2026-10-07 Claude] 같은 높이 이웃과 붙는 끝(흰·검정 맞물림 등) — 도형님: "윗면이 타일 이미지에 맞게
			#   나뉘지 않고 직선으로 뚝 잘렸다. 윗면 이미지 틈새에 맞게". 윗면 판자 틈은 뒤(−4)에서 앞(18)으로
			#   18px 오른쪽으로 기우는 사선이다 → 경계도 그 사선 = (끝 −18, −4) → (끝, 18).
			#   · 오른쪽에 이웃: 내 상판의 오른 뒤 꼭짓점을 18px 당긴다(사선 왼쪽만 내 것).
			#   · 왼쪽에 이웃: 사선과 세로선 사이 쐐기를 내가 이웃 위에 덮어 그린다(자르지 않음) — 이웃은 그 쐐기를 비워 두었다.
			#   두 지형이 각자 같은 규칙으로 계산하므로 겹치거나 틈이 생기지 않고, 경계 = 내 판자의 첫/마지막 이음새가 된다.
			#   앞 단면(18…26)은 원래대로 세로 경계(앞에서 보면 판자 끝이 세로다).
			var 이음_l := 투영폭 if (not left_end) and interval.x < 0.0001 and _옆이웃(a+Vector2(-0.5,0.5),others) and shift >= 투영폭 else 0.0
			var 이음_r := 투영폭 if (not right_end) and interval.y > 0.9999 and _옆이웃(b+Vector2(0.5,0.5),others) and shift >= 투영폭 else 0.0
			ri += 이음_r
			var run_l := l.x - 이음_l
			var run_n := maxi(1, roundi((r.x-l.x-ri+이음_l)/64.0))
			var run_w := (r.x-l.x-ri+이음_l)/float(run_n)
			# 22px 윗면 + 8px 앞 단면. 볼록 끝은 사다리꼴 상판과 작은 나무 단면으로 닫는다.
			if li > 0.0:
				# [2026-10-05 Claude] 끝 단면을 옆면(kind 4)과 같은 좌표로 그린다 — 사선 윗변이 상판 첫 이음새와 겹치고,
				#   아래로는 왼 벽 단면과 한 면으로 이어진다. 기준선 = 이 끝의 세로선(아래→위, 안쪽 = +x).
				var ea := l + Vector2(0.0, 40.0)
				var eb := l
				var end := PackedVector2Array([l+Vector2(0,-4),l+Vector2(li,18),l+Vector2(li,26),l+Vector2(0,4)])
				면추가(data,end,p,others,ea,eb,4,true,0.0,64.0,[],shift)
				면추가(data,end,p,others,ea,eb,4,false,0.0,64.0,[],shift)
			var top := PackedVector2Array([l+Vector2(0,-4),r+Vector2(-ri,-4),r+Vector2(meet,18),l+Vector2(li,18)])
			면추가(data,top,p,others,a,b,0,true,run_l,run_w,contacts,shift)
			면추가(data,top,p,others,a,b,0,false,run_l,run_w,contacts,shift)
			if 이음_l > 0.0:
				var 쐐기 := PackedVector2Array([l+Vector2(-이음_l,-4),l+Vector2(0,-4),l+Vector2(0,18)])
				면추가(data,쐐기,p,others,a,b,0,true,run_l,run_w,[],shift,false)
			var front := PackedVector2Array([l+Vector2(li,18),r+Vector2(meet,18),r+Vector2(meet,26),l+Vector2(li,26)])
			면추가(data,front,p,others,a,b,0,true,run_l,run_w,contacts,shift)
			if ri > 0.0 and 이음_r == 0.0:
				# 사선 마감은 상판 끝과 평행하고, 앞 단면부터 아래는 수직으로 꺾인다.
				var cap := PackedVector2Array([r+Vector2(-ri-마감폭,-4),r+Vector2(-ri,-4),r+Vector2(0,18),r+Vector2(0,26),r+Vector2(-마감폭,26),r+Vector2(-마감폭,18)])
				면추가(data,cap,p,others,r,r+Vector2(0,40),7)
				면추가(data,cap,p,others,r,r+Vector2(0,40),7,false)
	if data["vertices"].is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(data["vertices"])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(data["uvs"])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(data["colors"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data["indices"])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
