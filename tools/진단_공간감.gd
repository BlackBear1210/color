extends SceneTree
## ============================================================================
## [2026-09-08 STEP 15 신규] 공간감 진단 — "맵이 큰가"가 아니라 **"넓게 느껴지는가"**를 잰다
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/진단_공간감.gd -- <씬경로> [--격자=64]
##
## # STEP15:
## # 문제: STAGE 2 는 Bounding Box 8200×4700 · 실제 경로 29,220 px 로 **숫자상으로는**
## #       충분히 큰데, 실제 게임 화면은 "작은 방에서 발판 퍼즐을 푸는" 것처럼 보인다.
## #       기존 진단 도구(플랫폼겹침·레벨검사·지형메시)는 전부 **겹치는가 / 갈 수 있는가**만
## #       보기 때문에 "한 화면에 발판이 몇 개나 몰려 있는가"를 아무도 못 잡았다.
## # 목적: 눈으로 "답답하다"고 느끼는 것을 **숫자**로 바꿔서, 재설계 전후를 비교 가능하게 한다.
## # 해결: 씬을 실제로 띄워 물리 공간을 격자로 찍어(point query) 고체/빈칸 지도를 만들고,
## #       거기서 ① 채움 비율 ② 윗면(밟을 수 있는 면) 길이 분포 ③ 수직 간격
## #       ④ **실제 카메라가 보는 사각형 안에 윗면이 몇 개 들어오는가** 를 잰다.
## #       엔진의 물리를 그대로 쓰므로 TileMapLayer(구 프로토) 와 SmartShape2D(현행)를
## #       **같은 잣대로** 비교할 수 있다 — 이번 STEP 의 레퍼런스가 TileMap 씬이라 이게 중요하다.
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 재기만 한다.
## ============================================================================

var 씬경로 := "res://scenes/집/스테이지_2_복도계단.tscn"
var 격자 := 64.0          ## 표본 간격(px). 64 = 플레이어 폭 정도라 "설 수 있는 면"과 눈금이 맞는다

var _뿌리: Node = null


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--격자="):
			격자 = float(a.substr(4))
		elif not a.begins_with("--"):
			씬경로 = a

	var ps := load(씬경로) as PackedScene
	if ps == null:
		print("✗ 씬을 못 읽었다: %s" % 씬경로)
		quit(1)
		return
	_뿌리 = ps.instantiate()
	root.add_child(_뿌리)
	current_scene = _뿌리
	# SS2D 가 콜리전을 굽고 월드.gd 가 카메라/플레이어를 붙이는 데 몇 프레임이 걸린다.
	for _i in 40:
		await process_frame

	var 영역 := _조사영역()
	var 화면 := _카메라_시야()
	print("")
	print("════════════════════════════════════════════════════════")
	print(" 공간감 진단 — %s" % 씬경로.get_file())
	print("════════════════════════════════════════════════════════")
	print("  조사 영역 : %.0f × %.0f  (x %.0f~%.0f · y %.0f~%.0f)"
		% [영역.size.x, 영역.size.y, 영역.position.x, 영역.end.x, 영역.position.y, 영역.end.y])
	print("  카메라 시야: %.0f × %.0f px  (zoom %.3f · 뷰포트 %d×%d)"
		% [화면.x, 화면.y, _줌, _뷰포트.x, _뷰포트.y])

	var 지도 := await _고체지도(영역)
	_보고(지도, 영역, 화면)

	_뿌리.queue_free()
	for _i in 3:
		await process_frame
	quit(0)


var _줌 := 1.0
var _뷰포트 := Vector2i(1920, 1080)


## # STEP15:
## # 문제: 카메라 줌을 씬 파일에서 눈으로 읽으면, `proto_camera` 가 매 프레임
## #       `기준 × 공간혼합 × 연출배수` 로 다시 계산하는 실제 값과 달라진다.
## # 해결: 실행 중인 Camera2D 의 zoom 을 그대로 읽는다. 시야 = 뷰포트 / zoom.
func _카메라_시야() -> Vector2:
	_뷰포트 = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))
	var cam := _찾기(_뿌리, func(n): return n is Camera2D and (n as Camera2D).enabled) as Camera2D
	if cam == null:
		cam = _찾기(_뿌리, func(n): return n is Camera2D) as Camera2D
	if cam != null and cam.zoom.x > 0.0:
		_줌 = cam.zoom.x
	return Vector2(_뷰포트) / _줌


## 조사할 사각형. 루트가 `카메라_리밋` 을 들고 있으면 그것이 곧 "설계된 플레이 공간"이고,
## 없으면(구 프로토 씬) 콜리전 전체의 AABB 로 잡는다.
func _조사영역() -> Rect2:
	var 리밋 = _뿌리.get("카메라_리밋")
	if 리밋 is Rect2 and (리밋 as Rect2).size.x > 1.0:
		return 리밋
	# # STEP15:
	# # 문제: 구 프로토 씬(stage_1-1.1)은 지형이 **TileMapLayer** 라서 CollisionPolygon2D
	# #       자식 노드가 하나도 없다. 그래서 처음엔 Player 콜리전만 잡혀 조사 영역이
	# #       300×352 로 나왔다(= 사실상 아무것도 못 잰 것).
	# # 해결: TileMapLayer 는 `get_used_rect()` × 타일 크기로 실제 지형 범위를 따로 구한다.
	var 첫 := true
	var r := Rect2()
	for tl: Node in _모두(_뿌리):
		if not (tl is TileMapLayer):
			continue
		var layer := tl as TileMapLayer
		if layer.tile_set == null:
			continue
		var ur := layer.get_used_rect()
		if ur.size.x <= 0:
			continue
		var ts := Vector2(layer.tile_set.tile_size)
		var b0 := Rect2(layer.to_global(Vector2(ur.position) * ts),
			Vector2(ur.size) * ts * layer.global_scale)
		r = b0 if 첫 else r.merge(b0)
		첫 = false

	var 모음: Array = []
	_콜리전_모으기(_뿌리, 모음)
	for n: Node2D in 모음:
		var b := _노드_AABB(n)
		if b.size == Vector2.ZERO:
			continue
		r = b if 첫 else r.merge(b)
		첫 = false
	if 첫:
		return Rect2(-1000, -1000, 2000, 2000)
	return r.grow(격자 * 2.0)


func _노드_AABB(n: Node2D) -> Rect2:
	var 점: PackedVector2Array = PackedVector2Array()
	if n is CollisionPolygon2D:
		점 = (n as CollisionPolygon2D).polygon
	elif n is CollisionShape2D:
		var sh := (n as CollisionShape2D).shape
		if sh is RectangleShape2D:
			var s := (sh as RectangleShape2D).size * 0.5
			점 = PackedVector2Array([-s, Vector2(s.x, -s.y), s, Vector2(-s.x, s.y)])
		else:
			return Rect2()
	if 점.size() < 3:
		return Rect2()
	var r := Rect2(n.to_global(점[0]), Vector2.ZERO)
	for p in 점:
		r = r.expand(n.to_global(p))
	return r


func _콜리전_모으기(n: Node, 모음: Array) -> void:
	if n is CollisionPolygon2D or n is CollisionShape2D:
		# Area2D(카메라 구역·위험물 판정)는 지형이 아니다 → 공간 크기 계산에서 뺀다.
		var 부모 := n.get_parent()
		if not (부모 is Area2D):
			모음.append(n)
	for c in n.get_children():
		_콜리전_모으기(c, 모음)


## # STEP15:
## # 문제: TileMapLayer 씬과 SmartShape2D 씬은 지형을 만드는 방식이 완전히 달라서
## #       씬 파일을 읽는 방식으로는 두 스테이지를 같은 잣대로 못 잰다.
## # 해결: **물리 공간에 점을 찍어** 고체/빈칸을 판정한다. 무엇으로 만들었든
## #       "플레이어가 부딪히는가"라는 같은 기준이 된다.
func _고체지도(영역: Rect2) -> Dictionary:
	var 공간 := _뿌리.get_viewport().world_2d.direct_space_state
	var 열 := int(영역.size.x / 격자)
	var 행 := int(영역.size.y / 격자)
	var 칸: Array = []           # [행][열] = bool
	var q := PhysicsPointQueryParameters2D.new()
	q.collide_with_bodies = true
	q.collide_with_areas = false
	# 지형 레이어만 본다. 유령 발판(layer 8)은 **칠하기 전에는 발판이 아니다** →
	# 일부러 빼서 "지금 밟을 수 있는 면"만 센다.
	q.collision_mask = 1
	for gy in 행:
		var 줄: Array = []
		줄.resize(열)
		var y := 영역.position.y + (gy + 0.5) * 격자
		for gx in 열:
			q.position = Vector2(영역.position.x + (gx + 0.5) * 격자, y)
			줄[gx] = not 공간.intersect_point(q, 1).is_empty()
		칸.append(줄)
		if gy % 20 == 0:
			await process_frame     # 헤드리스가 한 프레임에 다 돌면 워치독이 물 수 있다
	return {"칸": 칸, "열": 열, "행": 행}


func _보고(지도: Dictionary, 영역: Rect2, 화면: Vector2) -> void:
	var 칸: Array = 지도["칸"]
	var 열: int = 지도["열"]
	var 행: int = 지도["행"]

	# ── ① 채움 비율 ──
	var 고체 := 0
	for gy in 행:
		for gx in 열:
			if 칸[gy][gx]:
				고체 += 1
	var 전체 := 열 * 행
	print("")
	print("── ① 공간 채움 ──────────────────────────────────")
	print("  격자 %d × %d (%.0f px)" % [열, 행, 격자])
	print("  고체 %d / %d  =  채움 %.1f%%   ·  빈 공간 %.1f%%"
		% [고체, 전체, 100.0 * 고체 / maxf(전체, 1), 100.0 * (전체 - 고체) / maxf(전체, 1)])

	# ── ② 윗면(밟을 수 있는 면) 찾기 ──
	# 고체이면서 바로 위가 비어 있으면 윗면이다. 가로로 이어지면 한 덩어리(=발판 하나).
	var 윗면: Array = []          # {y, x0, x1, 길이}
	for gy in 행:
		var 시작 := -1
		for gx in 열:
			var 면: bool = bool(칸[gy][gx]) and (gy == 0 or not bool(칸[gy - 1][gx]))
			if 면 and 시작 < 0:
				시작 = gx
			elif not 면 and 시작 >= 0:
				윗면.append(_면(영역, 시작, gx - 1, gy))
				시작 = -1
		if 시작 >= 0:
			윗면.append(_면(영역, 시작, 열 - 1, gy))

	var 길이들: Array = []
	for f: Dictionary in 윗면:
		길이들.append(float(f["길이"]))
	길이들.sort()
	var 합 := 0.0
	for L in 길이들:
		합 += L
	print("")
	print("── ② 밟을 수 있는 윗면(=발판) ──────────────────────")
	print("  개수      : %d" % 윗면.size())
	print("  평균 길이 : %.0f px" % (합 / maxf(길이들.size(), 1)))
	print("  중앙값    : %.0f px" % (길이들[길이들.size() / 2] if not 길이들.is_empty() else 0.0))
	print("  최소/최대 : %.0f / %.0f px"
		% [길이들[0] if not 길이들.is_empty() else 0.0,
			길이들[-1] if not 길이들.is_empty() else 0.0])
	var 통: Dictionary = {"~250": 0, "250~500": 0, "500~900": 0, "900~1600": 0, "1600~": 0}
	for L2: float in 길이들:
		if L2 < 250.0: 통["~250"] += 1
		elif L2 < 500.0: 통["250~500"] += 1
		elif L2 < 900.0: 통["500~900"] += 1
		elif L2 < 1600.0: 통["900~1600"] += 1
		else: 통["1600~"] += 1
	var 줄 := "  길이 분포 : "
	for k: String in 통:
		줄 += "%s=%d  " % [k, 통[k]]
	print(줄)

	# ── ③ 수직 간격 — 같은 x 열에서 윗면이 얼마나 촘촘히 쌓여 있나 ──
	var 기둥: Dictionary = {}      # gx → [y...]
	for f2: Dictionary in 윗면:
		for gx2 in range(int(f2["gx0"]), int(f2["gx1"]) + 1):
			if not 기둥.has(gx2):
				기둥[gx2] = []
			기둥[gx2].append(float(f2["y"]))
	var 간격들: Array = []
	for gx3: int in 기둥:
		var ys: Array = 기둥[gx3]
		ys.sort()
		for i in range(1, ys.size()):
			간격들.append(float(ys[i]) - float(ys[i - 1]))
	간격들.sort()
	var 간합 := 0.0
	for d in 간격들:
		간합 += d
	print("")
	print("── ③ 수직으로 겹쳐 쌓인 정도 ────────────────────────")
	print("  같은 x 위에 윗면이 2개 이상인 열 : %d / %d" % [_겹친열(기둥), 기둥.size()])
	print("  위아래 윗면 간격 평균 : %.0f px  (중앙값 %.0f)"
		% [간합 / maxf(간격들.size(), 1),
			간격들[간격들.size() / 2] if not 간격들.is_empty() else 0.0])
	var 좁음 := 0
	for d2: float in 간격들:
		if d2 < 400.0:
			좁음 += 1
	print("  400px 미만으로 붙은 쌍 : %d / %d  (%.0f%%)"
		% [좁음, 간격들.size(), 100.0 * 좁음 / maxf(간격들.size(), 1)])

	# ── ④ ★한 화면에 발판이 몇 개 보이나 ──
	# # STEP15:
	# # 문제: "답답하다"의 정체가 이것이다. 맵 전체 크기가 아니라 **한 화면의 밀도**다.
	# # 해결: 실제 카메라 시야 사각형을 윗면마다 그 자리에 놓고, 그 안에 들어오는
	# #       다른 윗면 수를 센다. 플레이어가 발판에 섰을 때 보게 될 화면과 같다.
	var 화면당: Array = []
	var 화면_채움: Array = []
	for f3: Dictionary in 윗면:
		var c := Vector2(float(f3["cx"]), float(f3["y"]))
		var 뷰 := Rect2(c - 화면 * 0.5, 화면)
		var n := 0
		for g: Dictionary in 윗면:
			if 뷰.has_point(Vector2(float(g["cx"]), float(g["y"]))):
				n += 1
		화면당.append(float(n))
		화면_채움.append(_뷰_채움(칸, 영역, 뷰, 열, 행))
	화면당.sort()
	var s := 0.0
	for v in 화면당:
		s += v
	var s2 := 0.0
	for v2 in 화면_채움:
		s2 += v2
	print("")
	print("── ④ ★한 화면에 보이는 발판 수 (카메라 %.0f×%.0f) ──" % [화면.x,화면.y])
	print("  평균 %.1f 개  ·  중앙값 %.0f  ·  최대 %.0f"
		% [s / maxf(화면당.size(), 1),
			화면당[화면당.size() / 2] if not 화면당.is_empty() else 0.0,
			화면당[-1] if not 화면당.is_empty() else 0.0])
	print("  화면 안 지형 채움 평균 : %.1f%%  (낮을수록 빈 공간이 넓다)"
		% (100.0 * s2 / maxf(화면_채움.size(), 1)))

	# ── ⑤ 수평 : 수직 비중 ──
	var 가로합 := 0.0
	for L3: float in 길이들:
		가로합 += L3
	print("")
	print("── ⑤ 공간의 모양 ──────────────────────────────────")
	print("  영역 가로/세로 비 : %.2f" % (영역.size.x / maxf(영역.size.y, 1.0)))
	print("  윗면 총 가로 길이 : %.0f px" % 가로합)
	print("  윗면 하나가 차지하는 영역 가로 비율 : %.2f%%"
		% (100.0 * (가로합 / maxf(윗면.size(), 1)) / maxf(영역.size.x, 1.0)))
	print("════════════════════════════════════════════════════════")


func _면(영역: Rect2, gx0: int, gx1: int, gy: int) -> Dictionary:
	var x0 := 영역.position.x + gx0 * 격자
	var x1 := 영역.position.x + (gx1 + 1) * 격자
	return {"y": 영역.position.y + gy * 격자, "x0": x0, "x1": x1,
		"cx": (x0 + x1) * 0.5, "길이": x1 - x0, "gx0": gx0, "gx1": gx1}


func _겹친열(기둥: Dictionary) -> int:
	var n := 0
	for k: int in 기둥:
		if (기둥[k] as Array).size() >= 2:
			n += 1
	return n


func _뷰_채움(칸: Array, 영역: Rect2, 뷰: Rect2, 열: int, 행: int) -> float:
	var gx0 := int((뷰.position.x - 영역.position.x) / 격자)
	var gx1 := int((뷰.end.x - 영역.position.x) / 격자)
	var gy0 := int((뷰.position.y - 영역.position.y) / 격자)
	var gy1 := int((뷰.end.y - 영역.position.y) / 격자)
	var 고 := 0
	var 전 := 0
	for gy in range(maxi(gy0, 0), mini(gy1, 행)):
		for gx in range(maxi(gx0, 0), mini(gx1, 열)):
			전 += 1
			if 칸[gy][gx]:
				고 += 1
	return float(고) / maxf(전, 1)


## 트리 전체를 배열로. (TileMapLayer 탐색·카메라 탐색이 같이 쓴다)
func _모두(n: Node, 모음: Array = []) -> Array:
	모음.append(n)
	for c in n.get_children():
		_모두(c, 모음)
	return 모음


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 조건.call(뿌리):
		return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null:
			return r
	return null
