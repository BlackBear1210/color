extends SceneTree
## ============================================================================
## [2026-08-17 신규] 페인트 HUD(점 방식) 눈 확인용 스크린샷
## ----------------------------------------------------------------------------
## 실행 (헤드리스 아님 — 그려진 걸 봐야 하므로 창모드):
##   Godot --path . -s res://tools/shot_페인트HUD.gd -- <씬경로> <저장.png>
##
## ▣ 왜 필요한가
##   `test_페인트v4` 는 **규칙**만 본다. HUD 는 규칙이 맞아도 화면에 안 나올 수 있다
##   (좌표 변환·레이어 순서·색 대비는 코드로 확인이 안 된다).
##   그래서 실제 씬에서 **찬 점 / 회수 대기 묶음 / 회색 빗금 / E 마커**가
##   한 화면에 다 보이는 상태를 일부러 만들어 놓고 찍는다.
##
## ▣ 만드는 상태
##   대상 A : 2발  (묶음 1)
##   대상 B : 1발  (묶음 2)  ← 묶음 사이 간격이 보이는지 확인용
##   대상 C : 칠한 뒤 반대색 1발 → 회색(빗금)
## ============================================================================

var _n := 0
var _루트: Node


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("사용법: -- <씬경로> <저장.png>")
		quit(1)
		return

	if _n == 1:
		var 씬 := load(args[0]) as PackedScene
		if 씬 == null:
			push_error("씬을 못 읽었다: %s" % args[0])
			quit(1)
			return
		_루트 = 씬.instantiate()
		root.add_child(_루트)
	elif _n == 20:
		_상태_만들기()
	elif _n == 60:
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(args[1])
		print("shot: %s -> %s" % [error_string(err), args[1]])
		quit(0 if err == OK else 1)


func _상태_만들기() -> void:
	var 코어: Node = get_first_node_in_group("페인트코어")
	if 코어 == null:
		print("[shot] 페인트코어 없음 — 타일맵 스테이지로 본다")
		_타일_상태_만들기()
		return

	var 플레이어 := _플레이어_찾기(_루트)
	var 기준: Vector2 = 플레이어.global_position if 플레이어 else Vector2.ZERO
	var 후보 := _가까운_대상들(기준, 3)
	if 후보.size() < 3:
		print("[shot] 칠할 대상이 %d 개뿐 — 상태를 다 못 만든다" % 후보.size())

	var 색 := int(플레이어.get("player_color")) if 플레이어 else ColorDefs.BLACK
	var 반대 := ColorDefs.WHITE if 색 == ColorDefs.BLACK else ColorDefs.BLACK

	# ★명중 좌표는 **플레이어 근처**로 잡는다.
	#   대상의 global_position 을 쓰면 SS2D 지형은 원점이 도형 한쪽 끝이라
	#   마커가 화면 밖으로 나가 "E 마커가 안 나온다"고 오판하게 된다.
	if 후보.size() >= 1:
		_쏘기(코어, 후보[0], 색, 2, _근처(기준, 후보[0], 70.0))
	if 후보.size() >= 2:
		_쏘기(코어, 후보[1], 색, 1, _근처(기준, 후보[1], 130.0))
	if 후보.size() >= 3:
		# 완성시킨 뒤 반대색을 덮어 회색을 만든다 (빗금 칸 확인용)
		var p := _근처(기준, 후보[2], 190.0)
		_쏘기(코어, 후보[2], 색, 4, p)
		_쏘기(코어, 후보[2], 반대, 1, p)

	print("[shot] 탄약 %d/%d · 회수대기(대상) %d · 잠김 %d발" % [
		코어.남은_탄약, 코어.최대_탄약, 코어.회수_대기수(), 코어.잠긴_발수()])
	for 항목 in 코어.회수줄_요약():
		print("   묶음: %s = %d발" % [항목["대상"].name, 항목["발수"]])


## 타일맵 스테이지(stage_1-1, 1-2)용 — 탄약이 없으므로 회수 묶음만 만든다.
func _타일_상태_만들기() -> void:
	var 타일: Node = _노드_찾기(_루트, "타일페인트")
	if 타일 == null:
		print("[shot] 타일페인트도 없다 — 아무 상태도 못 만든다")
		return
	var 플레이어 := _플레이어_찾기(_루트)
	var 색 := int(플레이어.get("player_color")) if 플레이어 else ColorDefs.BLACK
	var 기준: Vector2 = 플레이어.global_position if 플레이어 else Vector2.ZERO

	# 플레이어에서 가까운 순으로 "칠할 수 있는" 플랫폼을 골라 몇 발 넣는다.
	# ★플레이어 색과 **다른 색**의 플랫폼만 칠할 수 있다(같은 색은 blocked).
	var 후보: Array = []
	for p in 타일._플랫폼들:
		if p.고정 or p.회색 or p.칠해짐 or p.원래색 == 색:
			continue
		# 탄약을 쓰는 스테이지에서는 **작은 플랫폼**을 골라야 여러 묶음을 만들 수 있다
		# (큰 것 하나가 12발을 먹어서 14발 예산으로는 묶음이 하나밖에 안 나온다).
		if 타일.탄약을_쓰나() and int(p.필요) > 3:
			continue
		var 좌표: Vector2 = 타일.대상_좌표(p)
		후보.append({ "p": p, "d": 기준.distance_to(좌표), "pos": 좌표 })
	후보.sort_custom(func(a, b): return a["d"] < b["d"])

	# ⚠ 이 시스템은 **완성된 플랫폼만** 회수줄(_큐)에 넣는다. 부분 색칠은 안 들어간다.
	#   (페인트 코어는 부분도 넣는다 — 두 시스템의 실제 규칙 차이다)
	#   그래서 묶음을 보려면 세 개 다 완성시켜야 한다.
	var 반대 := ColorDefs.WHITE if 색 == ColorDefs.BLACK else ColorDefs.BLACK
	for i in mini(3, 후보.size()):
		var p = 후보[i]["p"]
		var cell: Vector2i = p.레이어.local_to_map(p.레이어.to_local(후보[i]["pos"]))
		for _k in int(p.필요):
			_타일_쏘기(타일, p.레이어, cell, 색)
		if i == 2:
			_타일_쏘기(타일, p.레이어, cell, 반대)   # → 회색(빗금 칸 확인용)

	# 네 번째는 **일부러 미완성**으로 남긴다 — 점선(진행 중) 칸 확인용.
	if 후보.size() >= 4:
		var q = 후보[3]["p"]
		var qcell: Vector2i = q.레이어.local_to_map(q.레이어.to_local(후보[3]["pos"]))
		for _k in maxi(int(q.필요) - 1, 1):
			_타일_쏘기(타일, q.레이어, qcell, 색)

	print("[shot] 탄약 %d/%d · 회수줄 %d 묶음 · 잠김 %d" % [
		타일.남은_탄약, 타일.최대_탄약, 타일.회수줄_요약().size(), 타일.잠긴_발수()])
	for 항목 in 타일.회수줄_요약():
		print("   묶음: %d발" % 항목["발수"])


## ★실제 플레이와 같은 순서로 쏜다 — 탄약을 먼저 깎고 명중을 넘긴다.
## `on_hit` 만 부르면 탄약이 안 줄어 HUD 가 말도 안 되는 상태로 보인다.
func _타일_쏘기(타일: Node, layer: TileMapLayer, cell: Vector2i, 색: int) -> void:
	if not 타일.쏠_수_있나():
		return
	타일.발사_소모()
	타일.on_hit(layer, cell, 색)


func _쏘기(코어, 대상: Node, 색: int, 횟수: int, 좌표: Vector2) -> void:
	if 대상 == null:
		return
	for _i in 횟수:
		코어.발사_소모()
		코어.명중_처리(대상, 색, 좌표)


## 기준에서 대상 쪽으로 거리만큼 나아간 점 (화면 안에 들어오게 하려는 것).
func _근처(기준: Vector2, 대상: Node2D, 거리: float) -> Vector2:
	var 방향 := (대상.global_position - 기준)
	if 방향.length() < 1.0:
		방향 = Vector2.RIGHT
	return 기준 + 방향.normalized() * 거리


## 플레이어에서 가까운 순으로 칠할 수 있는 대상들.
func _가까운_대상들(기준: Vector2, 개수: int) -> Array:
	var 목록: Array = []
	for n in get_nodes_in_group("칠할수있음"):
		var n2 := n as Node2D
		if n2 == null or not is_instance_valid(n2):
			continue
		목록.append({ "n": n2, "d": 기준.distance_to(n2.global_position) })
	목록.sort_custom(func(a, b): return a["d"] < b["d"])
	var 결과: Array = []
	for i in mini(개수, 목록.size()):
		결과.append(목록[i]["n"])
	return 결과


func _플레이어_찾기(뿌리: Node) -> Node2D:
	var p := 뿌리.get_node_or_null("Player") as Node2D
	if p:
		return p
	for 자식 in 뿌리.get_children():
		var r := _플레이어_찾기(자식)
		if r:
			return r
	return null


func _노드_찾기(뿌리: Node, 이름: String) -> Node:
	if 뿌리.name == 이름:
		return 뿌리
	for 자식 in 뿌리.get_children():
		var r := _노드_찾기(자식, 이름)
		if r:
			return r
	return null
