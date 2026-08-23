extends SceneTree
## ============================================================================
## [2026-08-23 신규] 색 경계 — 몸 분할 검사 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_색경계_분할.gd
##
## ▣ 왜 필요한가
##   `player_color` 정수 하나로 몸 전체를 칠하던 방식을 버리고, 색을 **위치의 함수**로
##   바꿨다(`scripts/스마트월드/색경계.gd`). 이 규칙에는 자동 검사가 하나도 없었다 —
##   기존 경계 검사 둘(test_color_death · test_world_flow)은 씬이 폐기돼 건너뛴다.
##
## ▣ 검사하는 것
##   A. 몸이 통째로 안/밖일 때 — 조각 1개, 색이 맞다
##   B. 경계선이 몸을 가로/세로/대각으로 가를 때 — 조각 2개, 색이 서로 다르다
##   C. 걸쳐 있으면 색 전환이 막힌다 / 완전히 벗어나면 자유색으로 돌아온다
##   D. 사망 판정이 **부위별**로 간다 (기획이 든 두 예시 그대로)
##        · 상체 흰색으로 검정 천장에 닿으면 죽는다
##        · 하체 검정으로 흰 발판을 밟으면 죽는다 (상체가 흰색인 것과 무관)
##   E. 총알 색 = 총구 부위의 색
##   F. 회색 지대는 강제하지 않는다
##
## ▣ 좌표 규약
##   플레이어 원점은 **발바닥**이다. 몸은 44×97 이라 발바닥 y 기준 −97 이 머리 끝.
##   그래서 발바닥을 (0,0) 에 두면 몸은 y −97 ~ 0 을 차지한다.
## ============================================================================

const 지형공통_S := preload("res://tools/지형공통.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 존_씬 := preload("res://scenes/경계/color_zone.tscn")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool, 덧말: String = "") -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름 + ("   " + 덧말 if 덧말 != "" else ""))
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 색 경계 몸 분할 검사 ===")
	await _조각_검사()
	await _전환잠금_검사()
	await _부위별_사망_검사()
	await _총알색_검사()
	await _그림_검사()
	_겹침_규칙_검사()

	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	quit(1 if 실패 > 0 else 0)


# ── 준비물 ──────────────────────────────────────────────────────────────────

func _스테이지() -> Node2D:
	var 월드 := Node2D.new()
	월드.set_script(월드_S)
	월드.name = "테스트월드"
	월드.set("치명_낙하거리", 0.0)
	월드.set("낙사_y", 100000.0)
	월드.set("안전지점_자동저장", false)
	월드.set("시작_위치", Vector2(0, 0))

	var 코어 := Node.new()
	코어.set_script(코어_S)
	코어.name = "페인트코어"
	코어.add_to_group("페인트코어")
	월드.add_child(코어)

	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	월드.add_child(p)

	root.add_child(월드)
	# 스스로 리스폰해 좌표를 흐트러뜨리지 않게 자동 판정을 끈다.
	월드.set_physics_process(false)
	return 월드


## 사각형 경계를 놓는다. `사각` 은 월드 좌표.
func _경계(월드: Node2D, 사각: Rect2, 색: int) -> Node2D:
	var z: Node2D = 존_씬.instantiate()
	z.set("zone_color", 1 if 색 == ColorDefs.WHITE else 0)   # ZoneColor.WHITE=1
	z.position = 사각.get_center()
	var cp := z.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var 반 := 사각.size * 0.5
	cp.polygon = PackedVector2Array([-반, Vector2(반.x, -반.y), 반, Vector2(-반.x, 반.y)])
	월드.add_child(z)
	return z


## 대각선으로 자르는 경계 — 삼각형이면 빗변 하나가 몸을 가른다.
func _대각경계(월드: Node2D, 꼭짓점: PackedVector2Array, 색: int) -> Node2D:
	var z: Node2D = 존_씬.instantiate()
	z.set("zone_color", 1 if 색 == ColorDefs.WHITE else 0)
	z.position = Vector2.ZERO
	(z.get_node("CollisionPolygon2D") as CollisionPolygon2D).polygon = 꼭짓점
	월드.add_child(z)
	return z


func _세우기(월드: Node2D, 발바닥: Vector2) -> Node2D:
	var p: Node2D = 월드.get_node("Player")
	p.set("velocity", Vector2.ZERO)
	p.global_position = 발바닥
	await physics_frame
	p.set("velocity", Vector2.ZERO)
	p.global_position = 발바닥          # 중력으로 흘러내린 만큼 되돌린다
	await physics_frame
	return p


func _색모음(영역들: Array) -> Array:
	var 색들: Array = []
	for 영역 in 영역들:
		if not 색들.has(int(영역["색"])):
			색들.append(int(영역["색"]))
	색들.sort()
	return 색들


func _치우기(월드: Node2D) -> void:
	월드.queue_free()


# ── A·B. 조각 나누기 ────────────────────────────────────────────────────────

func _조각_검사() -> void:
	print("\n[A] 몸이 통째로 안 / 밖")
	var 월드 := _스테이지()
	await physics_frame
	var p := await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)

	# 몸은 y −97 ~ 0. 넉넉히 감싸는 흰 경계.
	var z := _경계(월드, Rect2(-200, -300, 400, 400), ColorDefs.WHITE)
	await physics_frame
	var 영역들: Array = p.call("몸_영역들")
	확인("통째로 경계 안 → 조각 1개", 영역들.size() == 1, "조각 %d" % 영역들.size())
	확인("통째로 경계 안 → 경계색(흰색)", _색모음(영역들) == [ColorDefs.WHITE])
	확인("통째로 경계 안 → 걸친 것으로 친다", bool(p.call("경계에_걸쳤나")))

	z.queue_free()
	await physics_frame
	영역들 = p.call("몸_영역들")
	확인("경계가 없으면 → 조각 1개", 영역들.size() == 1, "조각 %d" % 영역들.size())
	확인("경계가 없으면 → 자유색(검정)", _색모음(영역들) == [ColorDefs.BLACK])
	확인("경계가 없으면 → 안 걸쳤다", not bool(p.call("경계에_걸쳤나")))
	_치우기(월드)
	await process_frame

	print("\n[B] 경계선이 몸을 가른다")
	# ── 가로로 가르기 ── 몸 y −97~0 의 한가운데(−48)에서 자른다.
	월드 = _스테이지()
	await physics_frame
	p = await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)
	_경계(월드, Rect2(-200, -300, 400, 252), ColorDefs.WHITE)   # 아래끝 y = −48
	await physics_frame
	영역들 = p.call("몸_영역들")
	확인("가로 분할 → 조각 2개", 영역들.size() == 2, "조각 %d" % 영역들.size())
	확인("가로 분할 → 두 색이 다르다", _색모음(영역들) == [ColorDefs.BLACK, ColorDefs.WHITE])
	# 위 조각이 흰색이어야 한다 (경계가 위쪽에 있다)
	var 위색 := -1
	var 아래색 := -1
	for 영역 in 영역들:
		var 폴리: PackedVector2Array = 영역["폴리곤"]
		var y합 := 0.0
		for pt in 폴리:
			y합 += pt.y
		if y합 / float(폴리.size()) < -48.0:
			위색 = int(영역["색"])
		else:
			아래색 = int(영역["색"])
	확인("★상체 = 흰 경계색", 위색 == ColorDefs.WHITE, "상체 %d" % 위색)
	확인("★하체 = 자유색(검정)", 아래색 == ColorDefs.BLACK, "하체 %d" % 아래색)
	_치우기(월드)
	await process_frame

	# ── 세로로 가르기 ── 몸 x −22~22 의 한가운데(0)에서 자른다.
	월드 = _스테이지()
	await physics_frame
	p = await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)
	_경계(월드, Rect2(-300, -300, 300, 400), ColorDefs.WHITE)   # 오른끝 x = 0
	await physics_frame
	영역들 = p.call("몸_영역들")
	확인("세로 분할 → 조각 2개", 영역들.size() == 2, "조각 %d" % 영역들.size())
	확인("세로 분할 → 두 색이 다르다", _색모음(영역들) == [ColorDefs.BLACK, ColorDefs.WHITE])
	_치우기(월드)
	await process_frame

	# ── 대각으로 가르기 ── 몸을 비스듬히 지나는 빗변.
	월드 = _스테이지()
	await physics_frame
	p = await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)
	_대각경계(월드, PackedVector2Array([
		Vector2(-400, -400), Vector2(400, -400), Vector2(-400, 400)
	]), ColorDefs.WHITE)                      # 빗변이 원점 부근을 대각으로 지난다
	await physics_frame
	영역들 = p.call("몸_영역들")
	확인("대각 분할 → 조각 2개", 영역들.size() == 2, "조각 %d" % 영역들.size())
	확인("대각 분할 → 두 색이 다르다", _색모음(영역들) == [ColorDefs.BLACK, ColorDefs.WHITE])
	_치우기(월드)
	await process_frame

	# ── 회색 지대는 강제하지 않는다 ──
	print("\n[F] 회색은 강제하지 않는다")
	월드 = _스테이지()
	await physics_frame
	p = await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)
	var 회색존 := _경계(월드, Rect2(-200, -300, 400, 400), ColorDefs.WHITE)
	회색존.set("zone_color", 1)
	# ColorZone 은 흑/백만 있으므로, 회색 강제 금지는 식물B·빛기둥 쪽 계약이다.
	# 여기서는 "경계가 -1 을 주면 자유색이 남는다"를 대신 확인한다.
	회색존.queue_free()
	await physics_frame
	확인("경계가 -1 을 주면 자유색이 남는다",
		int(p.call("색_at", Vector2(0, -48))) == ColorDefs.BLACK)
	_치우기(월드)
	await process_frame


# ── C. 전환 잠금 ────────────────────────────────────────────────────────────

func _전환잠금_검사() -> void:
	print("\n[C] 걸치면 색을 못 바꾼다")
	var 월드 := _스테이지()
	await physics_frame
	var p := await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)

	# 몸의 위 절반만 덮는 흰 경계 → 걸친 상태
	var z := _경계(월드, Rect2(-200, -300, 400, 252), ColorDefs.WHITE)
	await physics_frame
	확인("(전제) 걸친 상태다", bool(p.call("경계에_걸쳤나")))
	p.call("_toggle_color")
	확인("★걸쳐 있으면 자유색이 안 바뀐다",
		int(p.get("자유색")) == ColorDefs.BLACK, "자유색 %d" % int(p.get("자유색")))

	# 완전히 벗어나면 다시 바꿀 수 있고, 몸 전체가 자유색으로 돌아온다
	z.queue_free()
	await physics_frame
	확인("벗어나면 안 걸친 상태", not bool(p.call("경계에_걸쳤나")))
	p.call("_toggle_color")
	확인("★벗어나면 자유색이 바뀐다",
		int(p.get("자유색")) == ColorDefs.WHITE, "자유색 %d" % int(p.get("자유색")))
	확인("★강제됐던 색이 눌어붙지 않는다 (몸 전체가 자유색)",
		_색모음(p.call("몸_영역들")) == [ColorDefs.WHITE])
	_치우기(월드)
	await process_frame


# ── D. 부위별 사망 판정 ─────────────────────────────────────────────────────

## 지형을 놓고 그 색으로 칠해 둔다. (`필요횟수 1` 이라 한 발이면 완성된다)
func _지형(월드: Node2D, 이름: String, 위치: Vector2, 폭: float, 높이: float, 색: int) -> Node2D:
	var 점들 := PackedVector2Array([
		Vector2(-폭 * 0.5, 0), Vector2(폭 * 0.5, 0),
		Vector2(폭 * 0.5, 높이), Vector2(-폭 * 0.5, 높이),
	])
	var 재질 := 지형공통_S.재질_준비("기본")
	var 지형 := 지형공통_S.지형_노드(이름, 위치, 점들, 재질, true, false, 1, 8.0)
	월드.add_child(지형)
	지형.call("명중", 색, 지형.global_position)
	return 지형


func _부위별_사망_검사() -> void:
	print("\n[D] 사망 판정이 부위별로 간다")
	var 월드 := _스테이지()
	await physics_frame

	# 바닥(흰색) 위에 서고, 머리 위 천장(검정)에 상체가 닿게 만든다.
	#   플레이어 발바닥 y=0 → 몸 y −97 ~ 0
	#   바닥 윗면 y=0, 천장 아랫면 y=−97 근처
	var 바닥 := _지형(월드, "바닥", Vector2(0, 0), 600.0, 200.0, ColorDefs.WHITE)
	var 천장 := _지형(월드, "천장", Vector2(0, -300), 600.0, 200.0, ColorDefs.BLACK)
	await physics_frame
	await physics_frame

	var p := await _세우기(월드, Vector2(0, -8))
	# 상체만 흰 경계 안 → 상체 흰색 / 하체 자유색(검정)
	p.set("자유색", ColorDefs.BLACK)
	_경계(월드, Rect2(-200, -400, 400, 344), ColorDefs.WHITE)    # 아래끝 y = −56
	await physics_frame

	var 영역들: Array = p.call("몸_영역들")
	확인("(전제) 몸이 두 색으로 갈렸다",
		_색모음(영역들) == [ColorDefs.BLACK, ColorDefs.WHITE], "색 %s" % str(_색모음(영역들)))
	확인("(전제) 지형 두 개가 각각 흰색·검정이다",
		int(바닥.call("현재색")) == ColorDefs.WHITE and int(천장.call("현재색")) == ColorDefs.BLACK,
		"바닥 %d 천장 %d" % [int(바닥.call("현재색")), int(천장.call("현재색"))])
	확인("★부위별 판정 — 흰 바닥을 검정 하체로 밟았으니 죽는다",
		bool(월드.call("_사망_판정")))
	_치우기(월드)
	await process_frame

	# 같은 배치에서 자유색을 흰색으로 바꾸면(=몸 전체 흰색) 흰 바닥은 안전해야 한다.
	월드 = _스테이지()
	await physics_frame
	_지형(월드, "바닥", Vector2(0, 0), 600.0, 200.0, ColorDefs.WHITE)   # 흰 바닥만
	await physics_frame
	await physics_frame
	p = await _세우기(월드, Vector2(0, -8))
	p.set("자유색", ColorDefs.WHITE)
	await physics_frame
	확인("몸 전체가 흰색이면 흰 바닥은 안전하다", not bool(월드.call("_사망_판정")))

	# 상체만 검정으로 만들고 흰 바닥 위에 서면 — 밟은 것은 흰 하체라 안전해야 한다.
	_경계(월드, Rect2(-200, -400, 400, 344), ColorDefs.BLACK)    # 아래끝 y = −56 → 상체만 검정
	await physics_frame
	영역들 = p.call("몸_영역들")
	확인("(전제) 상체 검정 / 하체 흰색으로 갈렸다",
		_색모음(영역들) == [ColorDefs.BLACK, ColorDefs.WHITE], "색 %s" % str(_색모음(영역들)))
	확인("★상체가 검정이어도, 밟은 하체가 흰색이면 흰 바닥은 안전하다",
		not bool(월드.call("_사망_판정")))
	_치우기(월드)
	await process_frame


# ── E. 총알 색 ──────────────────────────────────────────────────────────────

func _총알색_검사() -> void:
	print("\n[E] 총알 색 = 총구 부위의 색")
	var 월드 := _스테이지()
	await physics_frame
	var p := await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)

	var 총: Node2D = p.get_node_or_null("GunRig/Gun")
	확인("GunRig 아래에 Gun 이 있다", 총 != null)
	if 총 == null:
		_치우기(월드)
		return

	# 총구 받침은 부모의 비균등 스케일을 상쇄해야 한다 → 합성 배율이 (1,1)
	var 받침: Node2D = p.get_node("GunRig")
	var 합성 := 받침.global_scale
	확인("★GunRig 이 부모 스케일을 상쇄한다 (합성 배율 = 1)",
		absf(합성.x - 1.0) < 0.01 and absf(합성.y - 1.0) < 0.01,
		"배율 (%.3f, %.3f)" % [합성.x, 합성.y])

	# 총 회전 중심은 입 높이(발바닥에서 정확히 70px 위)에 있어야 한다.
	# GunRig가 비균등 배율을 지우므로 이 값은 월드에서 그대로 유지된다.
	var 높이 := p.global_position.y - 총.global_position.y
	확인("★총이 입 높이에 있다 (발바닥에서 정확히 70px 위)", absf(높이 - 70.0) < 1.0,
		"%.1fpx 위" % 높이)
	var 총구 := 총.get_node_or_null("Muzzle") as Marker2D
	확인("총구(Muzzle)가 있다", 총구 != null)
	if 총구:
		확인("★총구는 입 앞 18px에 있다", 총구.position == Vector2(18, 0),
			"%s" % str(총구.position))

	# 상체만 흰 경계 → 총구 부위가 흰색이므로 대표색·총알색이 흰색
	_경계(월드, Rect2(-200, -400, 400, 344), ColorDefs.WHITE)    # 아래끝 y = −56
	await physics_frame
	await physics_frame
	# 이 테스트 월드에는 바닥이 없어 대기 중 플레이어가 떨어진다. 총구가 경계 바로
	# 아래로 밀려나 "색 계산"이 아니라 "테스트 위치"가 실패 원인이 되지 않게 복구한다.
	p.set("velocity", Vector2.ZERO)
	p.global_position = Vector2.ZERO
	p.call("_대표색_갱신")
	var 총중심색 := int(p.call("색_at", 총.global_position))
	확인("★상체가 흰색이면 총구 좌표의 색도 흰색",
		총중심색 == ColorDefs.WHITE,
		"총 %s / 색 %d" % [str(총.global_position), 총중심색])
	확인("★대표색(player_color)이 총구 부위를 따라간다",
		int(p.get("player_color")) == ColorDefs.WHITE, "대표색 %d" % int(p.get("player_color")))
	확인("자유색은 검정 그대로다 (대표색과 다른 값)",
		int(p.get("자유색")) == ColorDefs.BLACK)
	_치우기(월드)
	await process_frame

	# 얼굴색은 총의 회전 각도가 아니라 실제 조준 쪽 얼굴 좌표를 쓴다.
	# 왼쪽만 흰 경계에 넣어 두면, 좌·우를 겨눌 때 서로 다른 색이 나와야 한다.
	월드 = _스테이지()
	await physics_frame
	p = await _세우기(월드, Vector2.ZERO)
	p.set("자유색", ColorDefs.BLACK)
	_경계(월드, Rect2(-200, -200, 199, 300), ColorDefs.WHITE)
	await physics_frame
	p.set("velocity", Vector2.ZERO)
	p.global_position = Vector2.ZERO
	var 왼입: Vector2 = p.call("입_월드좌표", -1.0)
	var 오른입: Vector2 = p.call("입_월드좌표", 1.0)
	확인("★왼쪽 조준 입은 왼쪽 얼굴에 있다", 왼입.x < -10.0, str(왼입))
	확인("★오른쪽 조준 입은 오른쪽 얼굴에 있다", 오른입.x > 10.0, str(오른입))
	확인("★총알 색은 왼쪽 얼굴의 흰색을 쓴다", int(p.call("얼굴색", -1.0)) == ColorDefs.WHITE)
	확인("★총알 색은 오른쪽 얼굴의 자유색(검정)을 쓴다", int(p.call("얼굴색", 1.0)) == ColorDefs.BLACK)
	_치우기(월드)
	await process_frame


# ── G. 그림이 판정과 같은 선을 쓴다 ─────────────────────────────────────────
# ★이번 작업의 전부가 이것이다 — 보이는 것과 죽는 것이 어긋나면 안 된다.
#   셰이더 값(`분할_셰이더값`)과 판정 값(`몸_영역들`)이 **같은 분할선**에서 나오는지 본다.

func _그림_검사() -> void:
	print("\n[G] 그림과 판정이 같은 선을 쓴다")
	var 월드 := _스테이지()
	await physics_frame
	var p := await _세우기(월드, Vector2(0, 0))
	p.set("자유색", ColorDefs.BLACK)

	var 시트: AnimatedSprite2D = p.get_node_or_null("CharacterSprite")
	var 겹침: AnimatedSprite2D = p.get_node_or_null("CharacterSprite/색겹침")
	확인("검정 시트가 있다", 시트 != null)
	확인("★반대색 시트(색겹침)가 붙어 있다", 겹침 != null)
	if 시트 == null or 겹침 == null:
		_치우기(월드)
		return
	확인("두 시트가 같은 SpriteFrames 를 쓴다", 시트.sprite_frames == 겹침.sprite_frames)
	확인("겹침 시트는 변형을 상속받는다 (원점에 붙어 있다)",
		겹침.position == Vector2.ZERO and 겹침.scale == Vector2.ONE)
	확인("두 시트에 분할 셰이더가 걸렸다",
		시트.material is ShaderMaterial and 겹침.material is ShaderMaterial)

	# ── 안 갈렸을 때 ──
	await physics_frame
	var m := 시트.material as ShaderMaterial
	확인("경계가 없으면 분할개수 0",
		int(m.get_shader_parameter("split_count")) == 0,
		"개수 %s" % str(m.get_shader_parameter("split_count")))
	var 표: Vector4 = m.get_shader_parameter("color_table")
	확인("경계가 없으면 색표가 전부 자유색(검정)",
		표.x == 0.0 and 표.y == 0.0, "색표 %s" % str(표))

	# ── 가로로 갈렸을 때 ──
	_경계(월드, Rect2(-200, -300, 400, 252), ColorDefs.WHITE)   # 아래끝 y = −48
	await physics_frame
	m = 시트.material as ShaderMaterial
	확인("★갈리면 분할개수 1",
		int(m.get_shader_parameter("split_count")) == 1,
		"개수 %s" % str(m.get_shader_parameter("split_count")))

	# 셰이더가 쓰는 선으로 직접 계산한 색이, 판정이 준 조각 색과 같아야 한다.
	var 선1: Vector4 = m.get_shader_parameter("line_1")
	표 = m.get_shader_parameter("color_table")
	var 점 := Vector2(선1.x, 선1.y)
	var 법선 := Vector2(선1.z, 선1.w)
	var 어긋남 := 0
	for 영역 in p.call("몸_영역들"):
		var 폴리: PackedVector2Array = 영역["폴리곤"]
		var 중심 := Vector2.ZERO
		for pt in 폴리:
			중심 += pt
		중심 /= float(폴리.size())
		# 셰이더와 똑같은 식으로 색을 고른다
		var 셰이더색 := 표.x if (중심 - 점).dot(법선) >= 0.0 else 표.y
		if int(셰이더색) != int(영역["색"]):
			어긋남 += 1
	확인("★★조각마다 셰이더 색 == 판정 색 (보이는 것 = 죽는 것)",
		어긋남 == 0, "어긋난 조각 %d개" % 어긋남)

	# 두 시트가 서로 다른 색을 담당해야 겹쳐서 한 몸이 된다.
	await process_frame
	await process_frame
	var 내색1: float = (시트.material as ShaderMaterial).get_shader_parameter("sheet_color")
	var 내색2: float = (겹침.material as ShaderMaterial).get_shader_parameter("sheet_color")
	확인("★두 시트가 서로 다른 색을 맡는다",
		absf(내색1 - 내색2) > 0.5, "%.0f vs %.0f" % [내색1, 내색2])
	확인("겹침 시트가 반대색 애니메이션을 재생한다",
		String(시트.animation).begins_with("black_") != String(겹침.animation).begins_with("black_"),
		"%s / %s" % [시트.animation, 겹침.animation])
	_치우기(월드)
	await process_frame


# ── H. 경계끼리 면 겹침 금지 ────────────────────────────────────────────────
## 변이나 꼭짓점만 맞닿는 것은 0px²라 허용하고, 실제 면적이 생길 때만 오류여야 한다.
## 이 계산을 ColorZone 에디터 차단과 레벨검사가 같이 쓰므로 독립으로 먼저 못박는다.
func _겹침_규칙_검사() -> void:
	print("\n[H] 경계 면 겹침 규칙")
	var 왼쪽 := PackedVector2Array([
		Vector2(-100, -50), Vector2(0, -50), Vector2(0, 50), Vector2(-100, 50),
	])
	var 맞닿음 := PackedVector2Array([
		Vector2(0, -50), Vector2(100, -50), Vector2(100, 50), Vector2(0, 50),
	])
	var 꼭짓점만 := PackedVector2Array([
		Vector2(0, 50), Vector2(100, 50), Vector2(100, 150), Vector2(0, 150),
	])
	var 겹침 := PackedVector2Array([
		Vector2(-10, -50), Vector2(100, -50), Vector2(100, 50), Vector2(-10, 50),
	])

	확인("★변끼리 정확히 맞닿음 = 허용", not 색경계.면_겹치나(왼쪽, 맞닿음))
	확인("★꼭짓점만 맞닿음 = 허용", not 색경계.면_겹치나(왼쪽, 꼭짓점만))
	var 교집합들 := 색경계.양의_교집합들(왼쪽, 겹침)
	확인("★면적 1px라도 겹치면 = 금지", not 교집합들.is_empty())
	if not 교집합들.is_empty():
		var 면적 := 0.0
		for p in 교집합들:
			# 사각형이라 신발끈 공식을 여기서 직접 재도 1,000px² 여야 한다.
			for i in p.size():
				면적 += absf(p[i].x * p[(i + 1) % p.size()].y - p[(i + 1) % p.size()].x * p[i].y) * 0.5
		확인("겹침 면적이 양수다", 면적 > 0.05, "면적 %.1fpx²" % 면적)
