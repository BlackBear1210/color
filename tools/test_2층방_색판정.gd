extends SceneTree
## ============================================================================
## [2026-08-30 신규] 2층방 — **화면에 물감이 있는 자리는 판정도 그 색인가**
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_2층방_색판정.gd
##
## ▣ 왜 만들었나 (실측으로 잡은 구멍)
##   지형은 노드 하나가 통째로 한 색이다. 그래서 나무를 전부 칠하면 연결 페인트가
##   옆 벽돌 바닥까지 하얗게 그리는데, 벽돌의 판정은 **무색 = 아무에게도 안 위험**이었다.
##     나무 판정: 흰색 / 벽돌 판정: 무색  (화면에는 흰 물감이 번져 보인다)
##   플레이어는 하얀 바닥을 흰색이라 믿는데 검정으로 밟아도 안 죽는다.
##   색이 곧 규칙인 게임에서 가장 나쁜 거짓말이라, 자리별 판정을 넣고 여기서 고정한다.
##
## ▣ 합격 기준
##   1. 물감이 닿은 자리는 그 색으로 판정된다 (반대색 플레이어는 죽는다)
##   2. 안 칠해진 자리는 여전히 안전하다 (아무 데서나 죽으면 그것도 거짓말이다)
##   3. 같은 색 플레이어는 물감 위에서 안전하다
##   4. 안 칠한 지형은 **검정**이다 — 흰색 플레이어는 그 위에서 죽는다
##      (2026-08-30 지시: "플레이어와 지형의 색이 다르면 죽어")
## ============================================================================

const 씬 := preload("res://scenes/집/스테이지_1_2층방.tscn")
const 색상 := preload("res://scripts/color_defs.gd")

var _n := 0
var _방: Node2D = null
var _통과 := 0
var _실패 := 0


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)


func _확인(조건: bool, 설명: String) -> void:
	if 조건:
		_통과 += 1
		print("  ✔ %s" % 설명)
	else:
		_실패 += 1
		print("  ✖ %s" % 설명)


func _틱() -> void:
	_n += 1
	if _n == 1:
		_방 = 씬.instantiate() as Node2D
		root.add_child(_방)
		return
	if _n == 4:
		# 나무(침대·책상)를 흰색으로 전부 칠한다. 연결 페인트가 옆 벽돌에도 같은 얼룩을 그린다.
		var 나무 := _찾기("WOOD")
		for i in 나무.필요횟수() + 2:
			if 나무.명중(색상.WHITE, 나무.global_position) == "painted":
				break
		return
	if _n != 8:
		if _n > 20:
			_끝내기()
		return

	print("\n── 나무를 흰색으로 전부 칠한 뒤")
	var 나무 := _찾기("WOOD")
	var 벽돌 := _찾기("BRICK")
	_확인(나무.현재색() == 색상.WHITE, "나무 자체는 흰색이다")

	# 벽돌 위에서 '물감이 묻은 자리'와 '안 묻은 자리'를 실제로 찾는다.
	var 묻은자리 := _색인_자리(벽돌, 색상.WHITE)
	var 빈자리 := _색인_자리(벽돌, -1)
	# ★[2026-08-31] 이웃으로 번지는 것은 **연결 페인트 노드가 있을 때만** 일어난다.
	#   그 노드는 씬에 붙는 것이라, 씬에 없으면 "번진 자리" 자체가 생기지 않는다.
	#   없다고 실패로 세면 안 된다 — 대신 건너뛰었다는 것을 눈에 보이게 남긴다.
	#   (노드를 다시 붙이면 이 검사도 저절로 다시 돈다)
	if _연결페인트_있나():
		_확인(묻은자리 != Vector2.INF, "벽돌 위에 흰 물감이 번진 자리가 있다 (화면에 보이는 그것)")
	else:
		print("  ⏭ 연결 페인트 노드가 씬에 없다 — 이웃 번짐 항목은 건너뛴다")
	_확인(빈자리 != Vector2.INF, "벽돌 위에 안 칠해진 자리도 있다")

	if 묻은자리 != Vector2.INF:
		var 점 := PackedVector2Array([묻은자리])
		_확인(벽돌.위치_반대색인가(색상.BLACK, 점),
			"흰 물감이 묻은 자리 → 검정 플레이어는 죽는다")
		_확인(not 벽돌.위치_반대색인가(색상.WHITE, 점),
			"흰 물감이 묻은 자리 → 흰색 플레이어는 안전하다")
	if 빈자리 != Vector2.INF:
		var 점2 := PackedVector2Array([빈자리])
		_확인(not 벽돌.위치_반대색인가(색상.BLACK, 점2),
			"안 칠해진 자리(검은 아트) → 검정 플레이어는 안전하다")
		# ★[2026-08-30] 안 칠한 지형도 화면에는 검정이다 → 흰색 플레이어는 죽어야 한다.
		_확인(벽돌.위치_반대색인가(색상.WHITE, 점2),
			"안 칠해진 자리(검은 아트) → 흰색 플레이어는 죽는다")

	# 예전 계약(자리 없이 묻기)은 그대로 있어야 한다 — 다른 스테이지가 그걸 쓴다.
	_확인(나무.반대색인가(색상.BLACK), "자리 없이 물어도 전부 칠해진 나무는 검정에게 위험하다")

	# ── 여기까지는 판정 함수. 이제 **플레이어를 실제로 세워서** 월드 판정을 돌린다 ──
	print("
── 플레이어를 바닥에 세우고 월드 사망 판정")
	var 플레이어 := _플레이어_찾기()
	if 플레이어 == null:
		_확인(false, "플레이어를 찾았다")
		_끝내기()
		return
	var 빈_윗면 := _윗면_점(벽돌, 빈자리)
	var 묻은_윗면 := _윗면_점(벽돌, 묻은자리)

	플레이어.global_position = 빈_윗면
	플레이어.set("player_color", 색상.BLACK)
	_확인(not _방._사망_판정(), "검은 바닥 위 · 검정 플레이어 → 안 죽는다")
	플레이어.set("player_color", 색상.WHITE)
	_확인(_방._사망_판정(), "검은 바닥 위 · 흰색 플레이어 → 죽는다  ★이번에 고친 것")

	if 묻은_윗면 != Vector2.INF:
		플레이어.global_position = 묻은_윗면
		플레이어.set("player_color", 색상.WHITE)
		_확인(not _방._사망_판정(), "흰 물감 위 · 흰색 플레이어 → 안 죽는다")
		플레이어.set("player_color", 색상.BLACK)
		_확인(_방._사망_판정(), "흰 물감 위 · 검정 플레이어 → 죽는다")
	_끝내기()


func _플레이어_찾기() -> Node2D:
	for n in root.get_tree().get_nodes_in_group("player"):
		return n as Node2D
	return null


## 그 x 자리의 지형 **윗면**(월드). 플레이어 원점은 발바닥이라 여기 그대로 세운다.
func _윗면_점(지형: Node2D, 월드기준: Vector2) -> Vector2:
	if 월드기준 == Vector2.INF:
		return Vector2.INF
	var 폴리: CollisionPolygon2D = 지형.get_collision_polygon_node()
	var 로컬 := 폴리.to_local(월드기준)
	var 위 := 로컬.y
	for p in 폴리.polygon:
		위 = minf(위, p.y)
	return 폴리.to_global(Vector2(로컬.x, 위))


## 이 지형의 콜리전 안을 훑어 지정한 색인 첫 자리(월드)를 찾는다. 없으면 INF.
func _색인_자리(지형: Node2D, 찾는색: int) -> Vector2:
	var 폴리: CollisionPolygon2D = 지형.get_collision_polygon_node()
	if 폴리 == null or 폴리.polygon.size() < 3:
		return Vector2.INF
	var 최소: Vector2 = 폴리.polygon[0]
	var 최대: Vector2 = 폴리.polygon[0]
	for p in 폴리.polygon:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	var 걸음: float = maxf((최대.x - 최소.x) / 60.0, 8.0)
	var y: float = 최소.y + 6.0
	while y < 최대.y:
		var x: float = 최소.x + 6.0
		while x < 최대.x:
			var 점 := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(점, 폴리.polygon):
				if 지형.위치색_로컬(지형.to_local(폴리.to_global(점))) == 찾는색:
					return 폴리.to_global(점)
			x += 걸음
		y += 걸음
	return Vector2.INF


## 2층방 전용 연결 페인트 관리자가 씬에 붙어 있나.
func _연결페인트_있나() -> bool:
	for n in _방.get_children():
		var sc: Variant = n.get_script()
		if sc != null and String(sc.resource_path).contains("이층방_연결페인트"):
			return true
	return false


func _찾기(이름조각: String) -> Node:
	for t in root.get_tree().get_nodes_in_group("스마트지형"):
		if t.칠하기_허용 and t.name.contains(이름조각):
			return t
	return null


func _끝내기() -> void:
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [_통과, _실패])
	print("════════════════════════════════════════\n")
	quit(1 if _실패 > 0 else 0)
