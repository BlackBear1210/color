extends SceneTree
## ============================================================================
## [2026-09-02 신규] 물 판정이 **그림과 같은 모양**인가
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_유체_판정모양.gd
##
## ▣ 무엇을 고정하나 (성진님 지시: "판정 모양이 유체 이미지와 매우 유사하게")
##   1. 프레임마다 판정 폴리곤이 **실제로 달라진다** (애니메이션을 따라간다)
##   2. 판정 안의 점은 그림에서도 **불투명**하고, 판정 밖의 점은 그림에서도 **투명**하다
##      ← 이게 진짜 검사다. "보이는 것과 닿는 것이 같은가" 를 픽셀로 대조한다
##   3. 유체 크기를 달리해도 각자 자기 크기의 판정을 갖는다
##      (2026-09-02 의 "Shape 리소스를 14 개가 나눠 썼다" 버그가 다시 안 생기게)
##   4. 판정 노드는 **어느 씬에도 저장되지 않는다** (owner 가 없다)
##   5. 연기는 예전 직사각형 판정 그대로다 — 물 실루엣을 기체에 씌우면 안 된다
##
## ▣ 2 번의 허용 오차
##   외곽선을 6px 로 단순화했으므로 경계 근처는 서로 어긋나는 게 정상이다.
##   그래서 경계에서 `여유_px` 만큼 떨어진 점만 본다.
## ============================================================================

const 유체_씬 := "res://scenes/집/스마트월드_장애물/유체.tscn"
const 프레임_경로 := "res://assets/textures/obstacles/liquid/animated_v4/gray/frame_%02d.png"
const 알파_문턱 := 0.35
## 단순화(6px) + 알파 경계의 흐릿함을 감안한 여유. 텍스처 픽셀 기준.
const 여유_px := 9.0

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
		print("  ✔ %s" % 글)
	else:
		실패 += 1
		print("  ✖ %s" % 글)


func _실행() -> void:
	print("\n=== 유체 판정 모양 ===")
	_표_검사()
	_그림_대조()
	_노드_검사()
	await _물리_검사()
	await _변형_검사()
	await _여유_검사()
	await _프레임_바꾸기_검사()
	_크기별_검사()
	_연기_검사()

	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


# ── 1. 표 자체 ──────────────────────────────────────────────────────────────
func _표_검사() -> void:
	print("\n── 프레임마다 다른 폴리곤인가")
	var 지문: Dictionary = {}
	for f in 유체판정모양.프레임_수:
		var 묶음 := 유체판정모양.프레임(f)
		_확인(묶음.size() >= 1, "%d 번 프레임에 폴리곤이 있다 (섬 %d)" % [f, 묶음.size()])
		var 점: PackedVector2Array = 묶음[0]
		_확인(점.size() >= 3, "  점이 %d 개 (볼록 분해가 되려면 3 개 이상)" % 점.size())
		# 점이 너무 많으면 프레임마다 볼록 분해를 다시 하는 비용이 커진다.
		_확인(점.size() <= 80, "  점이 80 개 이하다 (%d)" % 점.size())
		지문[var_to_str(점)] = true
	_확인(지문.size() >= 6, "서로 다른 모양이 %d 가지 (8 프레임 중)" % 지문.size())


# ── 2. 그림과 판정을 픽셀로 대조 ────────────────────────────────────────────
func _그림_대조() -> void:
	print("\n── 판정 안=그림도 불투명 / 판정 밖=그림도 투명 인가")
	for f in 유체판정모양.프레임_수:
		var 텍스처 := load(프레임_경로 % f) as Texture2D
		if 텍스처 == null:
			_확인(false, "%d 번 프레임 그림을 못 읽었다" % f)
			continue
		var 그림 := 텍스처.get_image()
		var 크기 := 그림.get_size()
		var 묶음 := 유체판정모양.프레임(f)

		var 안_틀림 := 0
		var 안_전체 := 0
		var 밖_틀림 := 0
		var 밖_전체 := 0
		# 4px 격자로 훑는다. 전수 검사는 느리고, 이 정도면 어긋난 곳은 반드시 걸린다.
		for y in range(2, 크기.y, 4):
			for x in range(2, 크기.x, 4):
				var 점 := Vector2(x, y)
				var 정규 := Vector2(float(x) / 크기.x, float(y) / 크기.y)
				var 거리 := _경계까지(정규, 묶음, 크기)
				if absf(거리) < 여유_px:
					continue                      # 경계 근처는 단순화 오차 구간이라 건너뛴다
				var 불투명 := 그림.get_pixel(x, y).a >= 알파_문턱
				if 거리 > 0.0:                     # 판정 안
					안_전체 += 1
					if not 불투명:
						안_틀림 += 1
				else:                              # 판정 밖
					밖_전체 += 1
					if 불투명:
						밖_틀림 += 1

		var 안_비율 := float(안_틀림) / maxf(안_전체, 1.0)
		var 밖_비율 := float(밖_틀림) / maxf(밖_전체, 1.0)
		# 판정 안인데 그림이 투명 = "안 보이는데 죽는다". 가장 나쁜 쪽이라 더 빡빡하게 본다.
		_확인(안_비율 <= 0.02, "%d 번: 판정 안인데 투명한 칸 %.2f%% (%d/%d)"
				% [f, 안_비율 * 100.0, 안_틀림, 안_전체])
		# 판정 밖인데 그림이 불투명 = 버린 물방울들. 그래서 조금 더 너그럽다.
		_확인(밖_비율 <= 0.02, "%d 번: 판정 밖인데 불투명한 칸 %.2f%% (%d/%d)"
				% [f, 밖_비율 * 100.0, 밖_틀림, 밖_전체])


## 정규화 점에서 폴리곤 경계까지의 거리(텍스처 px). 안쪽이면 양수.
func _경계까지(정규: Vector2, 묶음: Array, 크기: Vector2i) -> float:
	var 안 := false
	var 최소 := INF
	for 섬: PackedVector2Array in 묶음:
		var px := PackedVector2Array()
		px.resize(섬.size())
		for i in 섬.size():
			px[i] = 섬[i] * Vector2(크기)
		if Geometry2D.is_point_in_polygon(정규 * Vector2(크기), px):
			안 = true
		for i in px.size():
			var a := px[i]
			var b := px[(i + 1) % px.size()]
			최소 = minf(최소, (정규 * Vector2(크기)).distance_to(
					Geometry2D.get_closest_point_to_segment(정규 * Vector2(크기), a, b)))
	return 최소 if 안 else -최소


# ── 3. 노드가 제대로 붙었나 ─────────────────────────────────────────────────
func _노드_검사() -> void:
	print("\n── 판정 노드")
	var 물 := _유체_만들기(Vector2(120, 600))
	var 폴리들 := _폴리곤들(물)
	_확인(polygons_켜진수(폴리들) >= 1, "켜진 판정 폴리곤이 있다 (%d 개)" % polygons_켜진수(폴리들))
	for p in 폴리들:
		_확인(p.owner == null, "%s 는 owner 가 없다 (어느 씬에도 저장되지 않는다)" % p.name)
		if not p.disabled:
			_확인(p.build_mode == CollisionPolygon2D.BUILD_SOLIDS,
					"%s 는 SOLIDS 다 (안쪽이 있어야 사람을 잡는다)" % p.name)

	# 그림 크기와 판정 크기가 같은 자리에 있나 — 위/아래 끝을 본다.
	var 켜진 := _첫_켜진(폴리들)
	var 최소 := 켜진.polygon[0]
	var 최대 := 켜진.polygon[0]
	for v in 켜진.polygon:
		최소 = 최소.min(v)
		최대 = 최대.max(v)
	_확인(최소.y >= -1.0 and 최소.y < 600.0 * 0.06,
			"판정 윗끝이 물의 윗끝(y=0) 근처다 (%.1f)" % 최소.y)
	_확인(최대.y > 600.0 * 0.94 and 최대.y <= 601.0,
			"판정 아랫끝이 물의 아랫끝(y=600) 근처다 (%.1f)" % 최대.y)
	_확인(absf(최소.x) <= 60.0 and absf(최대.x) <= 60.0,
			"판정 좌우가 폭 120 안에 있다 (%.1f ~ %.1f)" % [최소.x, 최대.x])
	물.free()


# ── 3.5 물리 서버가 이 폴리곤을 실제로 받았나 ───────────────────────────────
## ⚠ 폴리곤 데이터가 맞는 것과 **물리가 그걸로 사람을 잡는 것**은 다른 문제다.
##   (`build_mode` 를 SEGMENTS 로 두면 데이터는 멀쩡해도 아무도 안 잡힌다)
##   그래서 진짜 몸을 넣어 보고 `get_overlapping_bodies()` 로 확인한다.
func _물리_검사() -> void:
	print("\n── 물리가 실제로 잡나 (몸을 넣어 본다)")
	var 물 := _유체_만들기(Vector2(200, 600))
	_프레임_고정(물, 0)
	var 묶음 := 유체판정모양.프레임(0)
	# 물보라(아래)와 물기둥(위) 두 군데를 본다. 아래만 보면 "기둥은 안 잡히는" 버그를 놓친다.
	var 물보라 := _가장_안쪽_점(묶음[0], Vector2(200, 600), 0.60, 1.00)
	var 기둥 := _가장_안쪽_점(묶음[0], Vector2(200, 600), 0.05, 0.55)
	# 물기둥 위쪽의 왼쪽 바깥 — 예전 직사각형 판정으로도, 지금 폴리곤으로도 물 밖이다.
	var 바깥 := Vector2(-95.0, 60.0)

	var 몸_물보라 := _몸_만들기(물, 물보라)
	var 몸_기둥 := _몸_만들기(물, 기둥)
	var 몸_밖 := _몸_만들기(물, 바깥)

	# Area2D 의 겹침 목록은 물리 스텝이 끝나야 채워지고, 첫 스텝은 비어 있을 수 있다.
	# 채워질 때까지(최대 8 스텝) 기다린다.
	var 겹친: Array = []
	for i in 8:
		await physics_frame
		겹친 = 물.get_overlapping_bodies()
		if not 겹친.is_empty():
			break
	_확인(몸_물보라 in 겹친, "바닥 물보라(%.0f, %.0f) 안의 몸을 잡는다" % [물보라.x, 물보라.y])
	_확인(몸_기둥 in 겹친, "물기둥(%.0f, %.0f) 안의 몸을 잡는다" % [기둥.x, 기둥.y])
	_확인(not (몸_밖 in 겹친), "물 밖(%.0f, %.0f)에 있는 몸은 안 잡는다" % [바깥.x, 바깥.y])
	물.free()


## 폴리곤 경계에서 가장 멀리 떨어진 점. 경계 근처를 골라 애매하게 판정되는 걸 피한다.
## `v0`~`v1` 로 높이 구간을 좁혀 물기둥/물보라를 따로 고를 수 있다.
func _가장_안쪽_점(정규: PackedVector2Array, 크기: Vector2, v0: float, v1: float) -> Vector2:
	var 로컬 := PackedVector2Array()
	로컬.resize(정규.size())
	for i in 정규.size():
		로컬[i] = Vector2((정규[i].x - 0.5) * 크기.x, 정규[i].y * 크기.y)
	var 최선 := Vector2.ZERO
	var 최선_거리 := -1.0
	for y in range(int(크기.y * v0), int(크기.y * v1), 8):
		for x in range(int(-크기.x * 0.5), int(크기.x * 0.5), 8):
			var p := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(p, 로컬):
				continue
			var 거리 := INF
			for i in 로컬.size():
				거리 = minf(거리, p.distance_to(Geometry2D.get_closest_point_to_segment(
						p, 로컬[i], 로컬[(i + 1) % 로컬.size()])))
			if 거리 > 최선_거리:
				최선_거리 = 거리
				최선 = p
	return 최선


## 플레이어 자리에 세울 작은 몸. 유체의 mask 1 에 걸리도록 layer 1 이다.
func _몸_만들기(부모: Node, 위치: Vector2) -> StaticBody2D:
	var 몸 := StaticBody2D.new()
	몸.collision_layer = 1
	몸.collision_mask = 0
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(6, 6)
	c.shape = s
	몸.add_child(c)
	몸.position = 위치
	부모.add_child(몸)
	return 몸


# ── 3.6 인스턴스를 옮기고·돌리고·늘려도 판정이 그림을 따라오나 ──────────────
## ★성진님 질문 그대로다: "다른 씬에서 인스턴스 시킨 뒤 x·y 를 옮기거나
##   스케일을 늘렸다 줄였다 해도 판정이 이미지를 잘 따라오는가?"
##
## ▣ 어떻게 확인하나 — **판정 코드를 안 쓰고** 확인해야 의미가 있다
##   기준점을 `물_애니메이션`(그림)의 global_transform 에서 뽑는다.
##   그림이 실제로 그려지는 자리를 그림 노드에게 물어본 것이므로,
##   판정이 거기 있으면 "판정이 그림을 따라왔다" 가 증명된다.
func _변형_검사() -> void:
	print("\n── 옮기고·돌리고·늘려도 그림을 따라오나")
	# 프레임 0 실루엣에서 가장 깊은 안쪽 점과, 확실한 바깥 점(왼쪽 위 모서리)을 정규화로 잡는다
	var 안_uv := _가장_안쪽_uv(유체판정모양.프레임(0)[0])
	var 밖_uv := Vector2(0.06, 0.10)

	var 경우: Array = [
		{"이름": "그대로", "위치": Vector2.ZERO, "회전": 0.0, "배율": Vector2.ONE, "크기": Vector2(200, 600)},
		{"이름": "멀리 옮김", "위치": Vector2(4321, -1234), "회전": 0.0, "배율": Vector2.ONE, "크기": Vector2(200, 600)},
		{"이름": "가로로 2배", "위치": Vector2(700, 200), "회전": 0.0, "배율": Vector2(2.0, 1.0), "크기": Vector2(200, 600)},
		{"이름": "작게 0.4배", "위치": Vector2(-900, 50), "회전": 0.0, "배율": Vector2(0.4, 0.4), "크기": Vector2(200, 600)},
		{"이름": "돌림 30°", "위치": Vector2(300, 300), "회전": deg_to_rad(30.0), "배율": Vector2.ONE, "크기": Vector2(200, 600)},
		{"이름": "돌리고+비대칭 배율", "위치": Vector2(-250, 800), "회전": deg_to_rad(-22.0),
			"배율": Vector2(1.7, 0.6), "크기": Vector2(200, 600)},
		{"이름": "크기만 키움", "위치": Vector2(120, -400), "회전": 0.0, "배율": Vector2.ONE, "크기": Vector2(300, 800)},
	]

	for c in 경우:
		var 물 := _유체_만들기(c["크기"])
		_프레임_고정(물, 0)          # ⚠ 안 고정하면 8fps 로 흘러가서 다른 프레임과 대조하게 된다
		물.position = c["위치"]
		물.rotation = c["회전"]
		물.scale = c["배율"]
		await physics_frame
		await physics_frame
		var 안 := _그림_위의_전역좌표(물, 안_uv)
		var 밖 := _그림_위의_전역좌표(물, 밖_uv)
		_확인(_점이_판정안인가(물, 안), "%s: 그림 안쪽 자리가 판정 안이다" % c["이름"])
		_확인(not _점이_판정안인가(물, 밖), "%s: 그림 바깥 자리는 판정 밖이다" % c["이름"])
		물.free()
		await physics_frame


## 전역 좌표 한 점이 이 유체의 판정 폴리곤 안인가.
##
## ▣ 왜 물리 서버에 안 묻고 기하학으로 보나
##   물리 스텝 사이에 `polygon` 을 다시 넣으면 그 변경이 물리 서버에 반영되는 건
##   **다음 물리 스텝**이다. 그래서 `get_overlapping_bodies()` 도 `intersect_point` 도
##   유체를 만들고 지우기를 반복하는 검사에서는 **어떤 회차에만** 빈 답을 돌려준다
##   (실패하는 경우가 매번 바뀌는 걸로 확인했다 — 코드가 아니라 검사의 문제였다).
##   여기서 보려는 것은 "판정이 그림을 따라오는가" 이고, 그건 **변환의 문제**다.
##   `CollisionPolygon2D.global_transform` 은 물리가 쓰는 바로 그 변환이므로,
##   그림의 변환으로 뽑은 점을 이 폴리곤에 넣어 보면 그대로 증명된다.
##   "물리가 실제로 그 폴리곤으로 사람을 잡는가" 는 위 `_물리_검사()` 가 따로 본다.
func _점이_판정안인가(물: 유체, 전역: Vector2) -> bool:
	for 폴 in _폴리곤들(물):
		if 폴.disabled or 폴.polygon.size() < 3:
			continue
		var 전역폴 := PackedVector2Array()
		for p in 폴.polygon:
			전역폴.append(폴.global_transform * p)
		if Geometry2D.is_point_in_polygon(전역, 전역폴):
			return true
	return false


## 물 애니메이션을 한 프레임에 붙잡아 둔다.
## 게임에서는 8fps 로 흐르므로, 어느 프레임과 대조하는지 정해 두지 않으면 검사가 흔들린다.
func _프레임_고정(물: 유체, 번호: int) -> void:
	var 애니 := 물.get_node("물_애니메이션") as AnimatedSprite2D
	애니.stop()
	애니.frame = 번호
	var 상세 := 물.get_node_or_null("물결_상세_애니메이션") as AnimatedSprite2D
	if 상세 != null:
		상세.stop()
		상세.frame = 번호


## 그림(AnimatedSprite2D)의 변환으로 텍스처 좌표를 전역 좌표로 옮긴다.
## ⚠ 일부러 유체의 판정 코드를 안 쓴다 — 그걸 쓰면 "판정이 판정과 같다"는 공허한 검사가 된다.
func _그림_위의_전역좌표(물: 유체, uv: Vector2) -> Vector2:
	var 애니 := 물.get_node("물_애니메이션") as AnimatedSprite2D
	var 텍 := 애니.sprite_frames.get_frame_texture(&"흐름", 애니.frame).get_size()
	return 애니.global_transform * ((uv * 텍) - 텍 * 0.5)


func _가장_안쪽_uv(정규: PackedVector2Array) -> Vector2:
	var 최선 := Vector2(0.5, 0.5)
	var 최선_거리 := -1.0
	for iy in range(2, 100, 2):
		for ix in range(2, 100, 2):
			var p := Vector2(ix / 100.0, iy / 100.0)
			if not Geometry2D.is_point_in_polygon(p, 정규):
				continue
			var 거리 := INF
			for i in 정규.size():
				거리 = minf(거리, p.distance_to(Geometry2D.get_closest_point_to_segment(
						p, 정규[i], 정규[(i + 1) % 정규.size()])))
			if 거리 > 최선_거리:
				최선_거리 = 거리
				최선 = p
	return 최선


## 유체의 자식이 아니라 root 에 붙인다. 유체의 scale 이 몸까지 늘리면 검사가 무의미해진다.
func _몸_전역(전역위치: Vector2) -> StaticBody2D:
	var 몸 := StaticBody2D.new()
	몸.collision_layer = 1
	몸.collision_mask = 0
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(4, 4)
	c.shape = s
	몸.add_child(c)
	root.add_child(몸)
	몸.global_position = 전역위치
	return 몸


# ── 3.7 인스펙터 `판정_여유` 손잡이 ─────────────────────────────────────────
func _여유_검사() -> void:
	print("\n── 인스펙터 `판정_여유` 로 판정을 줄이고 키울 수 있나")
	var 기본 := _유체_만들기(Vector2(200, 600))
	var 얇게 := _유체_만들기(Vector2(200, 600))
	얇게.판정_여유 = -12.0
	var 두껍게 := _유체_만들기(Vector2(200, 600))
	두껍게.판정_여유 = 12.0
	await physics_frame

	var a := _넓이(_첫_켜진(_폴리곤들(얇게)).polygon)
	var b := _넓이(_첫_켜진(_폴리곤들(기본)).polygon)
	var c := _넓이(_첫_켜진(_폴리곤들(두껍게)).polygon)
	_확인(a < b, "-12 는 그림보다 얇다 (%.0f < %.0f)" % [a, b])
	_확인(c > b, "+12 는 그림보다 두껍다 (%.0f > %.0f)" % [c, b])
	# 너무 깎아 판정이 통째로 사라지면 "물에 들어가도 안 죽는" 최악이 된다.
	var 극단 := _유체_만들기(Vector2(30, 120))
	극단.판정_여유 = -24.0
	_확인(polygons_켜진수(_폴리곤들(극단)) >= 1, "아무리 깎아도 판정이 사라지지는 않는다")
	기본.free()
	얇게.free()
	두껍게.free()
	극단.free()


func _넓이(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


# ── 3.8 `물_애니메이션.frame` 을 바꾸면 판정이 따라오나 ─────────────────────
## 이게 곧 **에디터에서 프레임별 판정을 보는 방법**이다.
## `물_애니메이션` 을 고르고 인스펙터의 `frame` 을 0~7 로 바꾸면 판정이 그 프레임 것으로 바뀐다.
## (에디터에서는 `@tool` 의 `_process` 가 이 갱신을 돌린다 — 여기서는 그 로직만 확인한다)
func _프레임_바꾸기_검사() -> void:
	print("\n── `물_애니메이션.frame` 을 바꾸면 판정도 바뀌나")
	var 물 := _유체_만들기(Vector2(200, 600))
	var 애니 := 물.get_node("물_애니메이션") as AnimatedSprite2D
	애니.stop()
	var 본것: Dictionary = {}
	for f in 유체판정모양.프레임_수:
		애니.frame = f
		await process_frame                       # `_물_애니_판정_따르기()` 가 도는 틈
		var 폴 := _첫_켜진(_폴리곤들(물))
		_확인(폴 != null and 폴.polygon.size() >= 3, "frame=%d 일 때 판정이 있다" % f)
		if 폴 != null:
			본것[var_to_str(폴.polygon)] = true
	_확인(본것.size() >= 6, "프레임을 바꾸니 판정 모양이 %d 가지로 바뀌었다" % 본것.size())
	물.free()


# ── 4. 크기가 다른 유체끼리 안 섞이나 ───────────────────────────────────────
func _크기별_검사() -> void:
	print("\n── 유체마다 자기 크기의 판정을 갖나")
	var 작은 := _유체_만들기(Vector2(56, 300))
	var 큰 := _유체_만들기(Vector2(300, 800))
	var a := _첫_켜진(_폴리곤들(작은))
	var b := _첫_켜진(_폴리곤들(큰))
	_확인(a != b, "판정 노드가 서로 다른 객체다")
	_확인(_폭(a.polygon) < _폭(b.polygon) * 0.5,
			"작은 물(%.1f) 이 큰 물(%.1f) 보다 좁다" % [_폭(a.polygon), _폭(b.polygon)])
	_확인(_높이(a.polygon) < _높이(b.polygon),
			"작은 물(%.1f) 이 큰 물(%.1f) 보다 짧다" % [_높이(a.polygon), _높이(b.polygon)])
	작은.free()
	큰.free()


# ── 5. 연기는 그대로 ────────────────────────────────────────────────────────
func _연기_검사() -> void:
	print("\n── 연기")
	var 연기 := _유체_만들기(Vector2(80, 400), true)
	var 사각 := 연기.get_node_or_null("모양") as CollisionShape2D
	_확인(사각 != null and not 사각.disabled, "연기는 직사각형 판정을 쓴다")
	if 사각 != null:
		var s := 사각.shape as RectangleShape2D
		_확인(s != null and s.size.is_equal_approx(Vector2(80, 400)),
				"직사각형이 크기(80,400) 그대로다 (%s)" % (s.size if s else "없음"))
	_확인(polygons_켜진수(_폴리곤들(연기)) == 0,
			"켜진 물 실루엣 폴리곤이 없다 (물 모양을 기체에 씌우지 않는다)")
	연기.free()


# ── 거들기 ──────────────────────────────────────────────────────────────────
func _유체_만들기(크기: Vector2, 연기: bool = false) -> 유체:
	var 씬 := load(유체_씬) as PackedScene
	var n := 씬.instantiate() as 유체
	if 연기:
		n.종류 = 유체.종류_.연기
	n.크기 = 크기
	root.add_child(n)
	return n


func _폴리곤들(n: Node) -> Array:
	var 결과: Array = []
	for c in n.get_children():
		if c is CollisionPolygon2D:
			결과.append(c)
	return 결과


func polygons_켜진수(목록: Array) -> int:
	var n := 0
	for p in 목록:
		if not p.disabled:
			n += 1
	return n


func _첫_켜진(목록: Array) -> CollisionPolygon2D:
	for p in 목록:
		if not p.disabled:
			return p
	return null


func _폭(p: PackedVector2Array) -> float:
	var 최소 := p[0].x
	var 최대 := p[0].x
	for v in p:
		최소 = minf(최소, v.x)
		최대 = maxf(최대, v.x)
	return 최대 - 최소


func _높이(p: PackedVector2Array) -> float:
	var 최소 := p[0].y
	var 최대 := p[0].y
	for v in p:
		최소 = minf(최소, v.y)
		최대 = maxf(최대, v.y)
	return 최대 - 최소
