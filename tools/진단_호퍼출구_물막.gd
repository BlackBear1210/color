extends SceneTree
## ============================================================================
## [2026-09-27] 호퍼 출구 물막 진단 — 읽기만 한다(씬 저장 안 함).
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/진단_호퍼출구_물막.gd -- <씬경로> [<씬경로> ...]
##
## ▣ 왜 만들었나
##   물 너비를 호퍼 출구(관 안지름)에 맞춰 줄이면, 넓은 물막이 하던 "벽" 역할이 사라져
##   물 옆으로 지나가는 우회로가 생길 수 있다. 그 대안으로 "물막 위에 가로 배관을 걸어
##   배관 길이만큼 물이 떨어지게" 하려면 물막 윗부분에 배관(두께 69px) 자리가 있어야 한다.
##   둘 다 눈대중이 아니라 실제 콜리전(레이어 1 = 지형)으로 잰다.
##
## ▣ 재는 것 (출구 물마다)
##   · 옆 틈: 물막 높이를 따라 32px 마다, 물 가운데에서 좌우로 지형을 만날 때까지 빈 폭.
##     물 가장자리 밖 빈 폭의 **최솟값**(왼/오)을 준다. 둘 다 0 에 가까우면 물이 통로를 꽉 채운 "벽".
##   · 좁히면 생기는 틈: 물을 출구 폭(기본 48)으로 줄였을 때 물 밖 빈 폭(가장 좁은 높이 기준).
##     플레이어 몸폭(약 40)보다 넓으면 **물을 안 건드리고 지나갈 수 있다.**
##   · 배관 자리: 물 폭 전체에 걸쳐, 물 윗끝에서 위로 지형·호퍼를 만날 때까지 빈 높이의 최솟값.
##     69 이상이면 물 위에 가로 배관을 걸 수 있다(물 판정은 안 건드림).
## ============================================================================

const 배관_두께 := 69.0
const 출구_폭 := 48.0
const 몸폭 := 40.0
const 옆_최대 := 640.0

func _init() -> void:
	call_deferred("_go")

func _go() -> void:
	var 씬들 := OS.get_cmdline_user_args()
	for 경로 in 씬들:
		await _씬_하나(경로)
	quit(0)

func _씬_하나(경로: String) -> void:
	var ps := load(경로) as PackedScene
	if ps == null:
		print("씬을 못 읽음: ", 경로)
		return
	var 루트 := ps.instantiate()
	root.add_child(루트)
	for _i in 4:
		await physics_frame
	var 공간: PhysicsDirectSpaceState2D = (루트 as Node2D).get_world_2d().direct_space_state
	print("\n=== ", 경로.get_file())
	print("  %-8s %-14s %9s | %-13s | %-17s | %s" % ["호퍼", "출구 물", "물 폭x높이", "(가장 좁은 통로) 지금 옆 틈 L/R", "48로 줄이면 L/R", "위쪽 빈 높이(호퍼 빼고 · 배관 69)"])
	for 호퍼 in _호퍼들(루트):
		var 물 := 호퍼.get("_출구") as Node2D
		if 물 == null and not String(호퍼.get("출구_유체")).is_empty():
			물 = 호퍼.get_node_or_null(호퍼.get("출구_유체")) as Node2D
		if 물 == null:
			continue
		var 크기: Vector2 = 물.get("크기")
		var 윗 := 물.global_position.y
		var cx := 물.global_position.x
		var x0 := cx - 크기.x * 0.5
		var x1 := cx + 크기.x * 0.5
		# ── 옆 틈 ──
		var 최소L := INF
		var 최소R := INF
		var 줄L := INF
		var 줄R := INF
		var y := 윗 + 16.0
		var 잰줄 := 0
		var 통로폭 := INF
		while y < 윗 + 크기.y - 8.0:
			# 물 가운데가 지형 속인 줄(물이 바닥 속까지 내려간 부분)은 통로가 아니다 — 건너뛴다
			if _지형속(공간, Vector2(cx, y), 호퍼):
				y += 32.0
				continue
			잰줄 += 1
			var L := _빈끝(공간, cx, y, -1, 호퍼)
			var R := _빈끝(공간, cx, y, 1, 호퍼)
			최소L = minf(최소L, x0 - L)
			최소R = minf(최소R, R - x1)
			줄L = minf(줄L, (cx - 출구_폭 * 0.5) - L)
			줄R = minf(줄R, R - (cx + 출구_폭 * 0.5))
			통로폭 = minf(통로폭, R - L)
			y += 32.0
		# ── 위쪽 빈 높이 ──
		# 배관 자리는 물 윗부분에서 **지형 밖인 열**만 잰다(물이 벽 속으로 파고든 열은 빼고)
		var 위빈 := INF
		var x := x0 + 4.0
		while x <= x1 - 4.0:
			if not _지형속(공간, Vector2(x, 윗 + 8.0), 호퍼):
				위빈 = minf(위빈, _위로_빈높이(공간, x, 윗 - 1.0, 호퍼))
			x += 16.0
		var 판정 := ""
		if 최소L < 8.0 and 최소R < 8.0:
			판정 = "벽(통로를 꽉 채움)"
		elif 최소L < 8.0 or 최소R < 8.0:
			판정 = "한쪽 벽"
		else:
			판정 = "양옆 빈 곳"
		var 우회 := "우회 위험" if maxf(줄L, 줄R) >= 몸폭 else "틈 좁음"
		print("  %-8s %-14s %4dx%-4d | 통로 %4d | %5d / %-5d | %5d / %-5d %s | %5d %s · %s (잰 줄 %d)" % [
			호퍼.name, 물.name, int(크기.x), int(크기.y), int(통로폭), int(최소L), int(최소R), int(줄L), int(줄R), 우회,
			int(위빈), ("자리 있음" if 위빈 >= 배관_두께 else "자리 없음"), 판정, 잰줄])
	루트.queue_free()
	await process_frame

func _호퍼들(n: Node) -> Array:
	var 결과: Array = []
	if n.get_script() != null and String(n.get_script().resource_path).contains("호퍼"):
		결과.append(n)
	for c in n.get_children():
		결과.append_array(_호퍼들(c))
	return 결과

func _지형속(공간: PhysicsDirectSpaceState2D, p: Vector2, 제외: Node) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	q.collide_with_areas = false
	q.position = p
	if 제외 is CollisionObject2D:
		q.exclude = [(제외 as CollisionObject2D).get_rid()]
	return not 공간.intersect_point(q, 1).is_empty()

## 가운데에서 한쪽으로 가며 지형(레이어 1)에 처음 닿는 x. 못 만나면 옆_최대 끝.
func _빈끝(공간: PhysicsDirectSpaceState2D, cx: float, y: float, 방향: int, 제외: Node) -> float:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	q.collide_with_areas = false
	if 제외 is CollisionObject2D:
		q.exclude = [(제외 as CollisionObject2D).get_rid()]
	var d := 0.0
	while d < 옆_최대:
		q.position = Vector2(cx + 방향 * d, y)
		if not 공간.intersect_point(q, 1).is_empty():
			return cx + 방향 * d
		d += 4.0
	return cx + 방향 * 옆_최대

## 물 윗끝에서 위로 **지형**에 닿을 때까지 빈 높이. 호퍼는 뺀다 — 배관을 걸 때 호퍼는 배관과 함께
## 위로 올리면 되므로, 막는 것은 지형뿐이다.
func _위로_빈높이(공간: PhysicsDirectSpaceState2D, x: float, y: float, 호퍼: Node) -> float:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	q.collide_with_areas = false
	if 호퍼 is CollisionObject2D:
		q.exclude = [(호퍼 as CollisionObject2D).get_rid()]
	var d := 0.0
	while d < 200.0:
		q.position = Vector2(x, y - d)
		if not 공간.intersect_point(q, 1).is_empty():
			return d
		d += 2.0
	return 200.0
