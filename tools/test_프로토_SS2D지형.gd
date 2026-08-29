extends SceneTree
## ============================================================================
## [2026-08-29 신규] 프로토 계열 스테이지에 놓은 **SS2D 지형**이 제대로 도는가
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_프로토_SS2D지형.gd
##
## ▣ 왜 만들었나 (성진님 제보)
##   *"stage_2-3 에 벽돌 테스를 넣었는데 총알이 그냥 통과해버린다."*
##
##   원인이 두 겹이었다. 둘 다 "한쪽 계열에서만 되는 것" 이었다.
##     ① `벽돌 테스.tscn` 에 **StaticBody2D/CollisionPolygon2D 가 아예 없었다.**
##        물리 몸이 없으니 총알도 플레이어도 그냥 지나간다.
##     ② `stage_lab.gd _발밑_플랫폼()` 이 콜리전을 **`PaintPlatform` 으로 캐스팅**했다.
##        SS2D 지형은 그 타입이 아니라 null → 칠할 수는 있는데 **밟아도 안 죽었다.**
##
##   두 계열(스마트월드 / 프로토)에 같은 지형을 놓고도 규칙이 다르게 돌면
##   레벨을 옮길 때마다 조용히 깨진다. 그래서 이 조합을 검사로 고정한다.
## ============================================================================

const 스테이지 := "res://scenes/world_2/stage_2-3.tscn"
const 지형경로 := "벽돌테스/SS2D_Shape_Closed"
const 색상 := preload("res://scripts/color_defs.gd")

var _n := 0
var _st: Node = null
var _지형: Node = null
var _윗면: Vector2 = Vector2.INF
var _죽음수_전 := 0
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
		_st = (load(스테이지) as PackedScene).instantiate()
		root.add_child(_st)
		return
	if _n == 120:
		_마무리_검사()
		return
	if _n == 160:
		_죽음_검사()
		return
	if _n != 25:
		if _n > 200:
			_끝내기()
		return

	print("\n── %s 안의 SS2D 지형" % 스테이지.get_file())
	_지형 = _st.get_node_or_null(지형경로)
	if _지형 == null or not _지형.has_method("반대색인가"):
		_확인(false, "SS2D 지형을 찾았다")
		_끝내기()
		return

	# ① 물리 몸 — 이게 없으면 총알이 그냥 통과한다
	var 바디 := _지형.get_node_or_null("StaticBody2D") as CollisionObject2D
	_확인(바디 != null, "StaticBody2D 가 있다")
	var 폴리 := _지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	_확인(폴리 != null and 폴리.polygon.size() >= 3,
		"콜리전 폴리곤이 구워졌다 (%d 점)" % (폴리.polygon.size() if 폴리 else 0))
	if 바디:
		# 총알(ProtoBullet)의 mask 는 1|8 이다. 그 안에 들어와야 맞는다.
		_확인((바디.collision_layer & (1 | 8)) != 0,
			"콜리전 레이어 %d 가 총알 마스크(1|8)에 걸린다" % 바디.collision_layer)

	# ② 총알이 대상을 찾는 방식 그대로 — 콜리전에서 부모를 거슬러 올라간다
	var 찾음 := _칠할대상_찾기(바디)
	_확인(찾음 == _지형, "총알이 콜리전에서 지형을 찾아낸다 (명중·현재색 계약)")

	# ★[2026-08-30] 자리별 색 판정 — 스테이지가 통째로 켜 줬는가
	_확인(bool(_지형.get("위치별_판정")),
		"스테이지가 SS2D 지형에 자리별 색 판정을 켰다 (stage_lab 자리별_색판정)")
	var 안쪽 := PackedVector2Array([_지형.global_position])
	_확인(not _지형.위치_반대색인가(색상.BLACK, 안쪽),
		"안 칠한 지형(검은 아트) → 검정 플레이어는 안전하다")
	_확인(_지형.위치_반대색인가(색상.WHITE, 안쪽),
		"안 칠한 지형(검은 아트) → 흰색 플레이어는 죽는다  ★world_2 로 넓힌 것")

	# ③ 프로토 계열의 규칙 엔진(TilePaintMap)이 이 지형을 칠할 수 있나
	var 타일페인트 = _st.get("타일페인트")
	_확인(타일페인트 != null and 타일페인트.has_method("노드_명중"),
		"스테이지에 TilePaintMap 이 있다")
	if 타일페인트:
		var 결과 := ""
		for i in _지형.필요횟수() + 1:
			결과 = 타일페인트.노드_명중(_지형, 색상.WHITE, _지형.global_position)
			if 결과 == "painted":
				break
		_확인(결과 == "painted" and _지형.현재색() == 색상.WHITE,
			"총알 규칙으로 흰색이 됐다 (결과 '%s')" % 결과)

	# ④ 밟았을 때 죽는가 — `_발밑_플랫폼()` 이 SS2D 지형을 집어야 한다
	var 플레이어 = _st.get("player")
	if 플레이어 != null and 폴리 != null:
		_윗면 = _윗면_한점(폴리)
		플레이어.global_position = _윗면
		var 밟은 = _st._발밑_플랫폼()
		_확인(밟은 == _지형, "발밑 판정이 SS2D 지형을 집는다")
		# ⚠ 여기서 그대로 두면 **검정 플레이어가 흰 지형을 밟은 채**가 되어 곧 죽는다.
		#   죽으면 페인트가 회수되므로, 번짐 판정을 먼저 보고 죽음은 맨 뒤에서 따로 본다.
		플레이어.global_position = _윗면 + Vector2(0, -4000)
		_확인(_지형.반대색인가(색상.BLACK),
			"흰 지형은 검정 플레이어에게 반대색이다 (= 밟으면 죽는다)")
		_확인(not _지형.반대색인가(색상.WHITE), "흰 플레이어에게는 안전하다")

	else:
		_확인(false, "플레이어를 찾았다")

	# 자리별 판정은 **번짐이 다 자란 뒤**에 본다.
	# ★얼룩이 자라는 중에는 아직 안 덮인 자리가 검정으로 읽히는 게 맞다 —
	#   화면이 거기서 검정이기 때문이다. 판정이 화면을 앞질러 가면 그것도 거짓말이다.
	return


## 번짐이 다 자란 뒤 자리별 판정을 보고, 그 다음 **실제로 밟혀 죽는지**까지 본다.
func _마무리_검사() -> void:
	var 안쪽 := PackedVector2Array([_지형.global_position])
	_확인(_지형.위치_반대색인가(색상.BLACK, 안쪽)
			and not _지형.위치_반대색인가(색상.WHITE, 안쪽),
		"번짐이 다 자란 뒤 → 자리별 판정도 흰색이라고 답한다")
	# 검정 플레이어를 흰 지형 위에 올려 둔다. 스테이지가 스스로 죽여야 한다.
	var 플레이어 = _st.get("player")
	if 플레이어 != null and _윗면 != Vector2.INF:
		플레이어.global_position = _윗면
		플레이어.set("player_color", 색상.BLACK)
		플레이어.set("velocity", Vector2.ZERO)
	_죽음수_전 = int(_st.get("_사망수"))


func _죽음_검사() -> void:
	_확인(int(_st.get("_사망수")) > _죽음수_전 or bool(_st.get("_사망중")),
		"흰 지형 위의 검정 플레이어 → 스테이지가 실제로 죽였다  ★world_2 끝까지")
	_끝내기()


## 콜리전 폴리곤의 윗변 한 지점(월드). 플레이어 원점은 발바닥이라 여기 그대로 세운다.
func _윗면_한점(폴리: CollisionPolygon2D) -> Vector2:
	var 최소 := 폴리.polygon[0]
	var 최대 := 폴리.polygon[0]
	for p in 폴리.polygon:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	return 폴리.to_global(Vector2((최소.x + 최대.x) * 0.5, 최소.y))


## `proto_bullet.gd _칠할대상_찾기()` 와 같은 규약.
func _칠할대상_찾기(맞은것: Node) -> Node:
	var n := 맞은것
	while n != null:
		if n is TileMapLayer:
			return null
		if n.has_method("명중") and n.has_method("현재색"):
			return n
		n = n.get_parent()
	return null


func _끝내기() -> void:
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [_통과, _실패])
	print("════════════════════════════════════════\n")
	quit(1 if _실패 > 0 else 0)
