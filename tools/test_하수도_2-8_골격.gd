extends SceneTree
## ============================================================================
## [2026-09-07 신규] stage_2-8 「갈래」 골격 검사
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_하수도_2-8_골격.gd
##
## ▣ 여기서 못 박는 것
##   1. **층 간격이 550px 이상**이다 (도형님 지시 2026-09-07).
##   2. 헤드룸이 점프 정점의 머리(256)보다 넉넉하다 — 천장에 닿아 죽지 않는다.
##   3. ★★**L3 에서 떨어져도 안 죽는다.** 층 간격 560 은 치명 낙하거리 520 을 넘으므로,
##      L1 물이 안 받아주면 이 맵은 성립하지 않는다.
##      `유체.gd` 의 `낙하_받아줌` 기본값이 **꺼짐**이라 빌더가 켜 줘야 한다.
##   4. 층마다 색을 따로 줄 수 있다 — 슬래브가 두 장인지 확인한다.
##   5. 하수도 규약: **회색 지형(시작상태 = 3)이 하나도 없다.**
##   6. ★★**끼는 자리가 없다.** (2026-09-07 도형님 제보로 추가)
##      · 갈래점 샤프트에 **정지 지형이 0 개**여야 한다 — 낄 기하를 아예 안 만든다.
##      · 승강기 양옆 여백이 플레이어 폭(44)보다 **넓어야** 한다.
##        좁으면 끼고, 넓으면 그냥 떨어진다. 어중간한 것이 사고를 낸다.
##      · 상하 발판은 꼭대기에서도 사람이 설 자리가 남아야 한다.
##   7. ★승강기를 실제로 타고 올라간다.
## ============================================================================

const 씬경로 := "res://scenes/world_2_클로드/stage_2-8.tscn"
const 플레이어_폭 := 44.0
const 플레이어_키 := 96.0

var 통과 := 0
var 실패 := 0
var _루트: Node2D = null


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
	print("\n=== stage_2-8 골격 ===")
	var 팩 := load(씬경로) as PackedScene
	if 팩 == null:
		_확인(false, "씬을 못 읽었다 — 먼저 build_하수도_2-8.gd 를 돌릴 것")
		_끝()
		return
	_루트 = 팩.instantiate() as Node2D
	root.add_child(_루트)
	await physics_frame
	await physics_frame

	_단면()
	_층_색_독립()
	_회색_지형_없음()
	_물_안전망()
	_끼는_자리_없음()
	await _L3에서_떨어뜨리기()
	await _승강기_타보기()

	_끝()


func _끝() -> void:
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


# ── 조회 도우미 ────────────────────────────────────────────────────────────
func _자식들(부모: String) -> Array:
	var 결과: Array = []
	var n := _루트.get_node_or_null(부모)
	if n == null:
		return 결과
	for c in n.get_children():
		결과.append(c)
	return 결과


func _지형들() -> Array:
	return _자식들("지형")


func _찾기(조각: String) -> Node:
	for n in _지형들():
		if String(n.name).begins_with(조각):
			return n
	return null


## SS2D 지형의 월드 AABB.
func _테두리(n: Node) -> Rect2:
	var 점들: PackedVector2Array = n.get_point_array().get_tessellated_points()
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	var g := (n as Node2D).global_position
	return Rect2(g + 최소, 최대 - 최소)


func _윗면(조각: String) -> float:
	var n := _찾기(조각)
	return NAN if n == null else _테두리(n).position.y


func _오른끝(조각: String) -> float:
	var n := _찾기(조각)
	return NAN if n == null else _테두리(n).end.x


func _왼끝(조각: String) -> float:
	var n := _찾기(조각)
	return NAN if n == null else _테두리(n).position.x


func _아랫면(조각: String) -> float:
	var n := _찾기(조각)
	return NAN if n == null else _테두리(n).end.y


func _승강기들() -> Array:
	var 결과: Array = []
	for n in _자식들("장치"):
		if String(n.name).begins_with("승강기_"):
			결과.append(n)
	return 결과


# ── 1. 단면 ────────────────────────────────────────────────────────────────
func _단면() -> void:
	print("\n── 단면 (층 간격 550 이상)")
	var l1 := _윗면("SS_L1_FLOOR_1_")
	var l2 := _윗면("SS_L2_FLOOR_1_")
	var l3 := _윗면("SS_L3_FLOOR_1_")
	_확인(not is_nan(l1) and not is_nan(l2) and not is_nan(l3), "세 층이 다 있다")
	if is_nan(l1) or is_nan(l2) or is_nan(l3):
		return
	var 아래_간격 := l1 - l2
	var 위_간격 := l2 - l3
	_확인(아래_간격 >= 550.0, "L1 ↔ L2 간격 %.0f ≥ 550" % 아래_간격)
	_확인(위_간격 >= 550.0, "L2 ↔ L3 간격 %.0f ≥ 550" % 위_간격)
	_확인(is_equal_approx(아래_간격, 위_간격), "두 간격이 같다 (%.0f)" % 아래_간격)

	var 천장아랫 := _윗면("SS_L1_CEIL_1_") + 60.0
	var 헤드룸 := l1 - 천장아랫
	_확인(헤드룸 > 256.0, "L1 헤드룸 %.0f > 점프 정점의 머리 256" % 헤드룸)


# ── 2. 층 색 독립 ──────────────────────────────────────────────────────────
func _층_색_독립() -> void:
	print("\n── 슬래브가 두 장이라 층마다 색이 다를 수 있다")
	var l3바닥 := _찾기("SS_L3_FLOOR_2_")     # 구간 2(A_고르기): L3 흰색 / L2 검정
	var l2천장 := _찾기("SS_L2_CEIL_2_")
	_확인(l3바닥 != null and l2천장 != null, "L3 바닥과 L2 천장이 **다른 노드**다")
	if l3바닥 == null or l2천장 == null:
		return
	_확인(int(l3바닥.get("시작상태")) == 2, "L3 바닥은 흰색 (실제 %d)" % int(l3바닥.get("시작상태")))
	_확인(int(l2천장.get("시작상태")) == 1, "바로 아래 L2 천장은 검정 (실제 %d)" % int(l2천장.get("시작상태")))


# ── 3. 회색 지형 금지 ──────────────────────────────────────────────────────
func _회색_지형_없음() -> void:
	print("\n── 하수도 규약: 회색 지형은 안 쓴다")
	var 회색 := 0
	for n in _지형들():
		if int(n.get("시작상태")) == 3:
			회색 += 1
	_확인(회색 == 0, "회색 지형 0 개 (실제 %d)" % 회색)


# ── 4. 물 안전망 ───────────────────────────────────────────────────────────
func _물_안전망() -> void:
	print("\n── ★L1 물이 낙하를 받아준다")
	var 물들: Array = []
	for n in _자식들("장치"):
		if String(n.name).begins_with("물_"):
			물들.append(n)
	_확인(물들.size() == 8, "구간마다 물길 한 줄 = 8 개 (실제 %d)" % 물들.size())
	var 안켜짐 := 0
	var 얕음 := 0
	for w in 물들:
		if not bool(w.get("낙하_받아줌")):
			안켜짐 += 1
		if float((w.get("크기") as Vector2).y) < float(w.get("받아주는_최소수심")):
			얕음 += 1
	_확인(안켜짐 == 0, "전부 `낙하_받아줌` 이 켜져 있다 (꺼진 것 %d)" % 안켜짐)
	_확인(얕음 == 0, "전부 최소 수심보다 깊다 (얕은 것 %d)" % 얕음)
	_확인(not _루트.get_tree().get_nodes_in_group("낙하받이").is_empty(),
		"그룹 '낙하받이' 에 등록됐다")


# ── 5. ★★끼는 자리가 없다 ─────────────────────────────────────────────────
func _끼는_자리_없음() -> void:
	print("\n── ★★끼는 자리 감사 (2026-09-07 사고 재발 방지)")

	var 승강기 := _승강기들()
	_확인(승강기.size() == 2, "승강기 샤프트 2 곳 (실제 %d)" % 승강기.size())

	# ⓐ **승강기 샤프트**에는 정지 지형이 하나도 없어야 한다.
	#    (계단 샤프트는 반대다 — 거기는 정지 지형이 있어야 오른다. ⓔ 에서 따로 본다)
	var 샤프트_안_지형 := 0
	for m in 승강기:
		var mx: float = (m as Node2D).global_position.x
		for n in _지형들():
			var r := _테두리(n)
			if r.size.x < 500.0 and absf(r.get_center().x - mx) < 280.0:
				샤프트_안_지형 += 1
	_확인(샤프트_안_지형 == 0,
		"승강기 샤프트 안에 정지 지형 0 개 (실제 %d)" % 샤프트_안_지형)

	# ⓑ 승강기 양옆 여백이 플레이어보다 넓어야 한다.
	#    좁으면 끼고, 넓으면 그냥 떨어진다. 어중간한 것이 사고를 낸다.
	var 좁은여백 := 0
	var 최소여백 := 9999.0
	for m in 승강기:
		var 여백 := (560.0 - float((m.get("크기") as Vector2).x)) * 0.5
		최소여백 = minf(최소여백, 여백)
		if 여백 <= 플레이어_폭:
			좁은여백 += 1
	_확인(좁은여백 == 0,
		"승강기 양옆 여백 %.0fpx > 플레이어 폭 %.0f (좁은 것 %d)" % [최소여백, 플레이어_폭, 좁은여백])

	# ⓒ 승강기가 L1 ↔ L3 을 다 이어야 한다.
	var 짧은것 := 0
	for m in 승강기:
		if float(m.get("이동거리")) < 1120.0:
			짧은것 += 1
	_확인(짧은것 == 0, "승강기 이동거리 1,120 = 두 층 (짧은 것 %d)" % 짧은것)

	# ⓓ 상하 통로 발판은 꼭대기에서도 사람이 설 자리가 남아야 한다.
	var 상하 := 0
	var 천장에_밀림 := 0
	for n in _자식들("장치"):
		if not String(n.name).begins_with("발판_"):
			continue
		if int(n.get("이동방향")) != 1:
			continue
		상하 += 1
		var 윗면: float = (n as Node2D).global_position.y - float((n.get("크기") as Vector2).y) * 0.5
		var 층바닥 := 윗면 + float(n.get("이동거리")) + 40.0    # 대략 그 층의 바닥
		if (층바닥 - 440.0) + 플레이어_키 > 윗면:               # 천장 + 사람 키가 발판을 넘으면 밀린다
			천장에_밀림 += 1
	_확인(상하 >= 2, "상하 움직이는 발판이 통로에도 있다 (%d 대)" % 상하)
	_확인(천장에_밀림 == 0, "상하 발판 꼭대기에 사람이 설 자리가 남는다 (모자란 것 %d)" % 천장에_밀림)

	# ⓔ ★계단 — 단조롭게 오르므로 처마가 없고, 위층 계단 밑에도 머리가 들어간다
	var 계단수 := 0
	for n in _지형들():
		if String(n.name).begins_with("SS_STAIR_"):
			계단수 += 1
	# 갈래점 2 곳 × (1층 5칸 + 2층 5칸 + 선반 1) = 22
	_확인(계단수 == 22, "계단 조각 22 개 = 갈래점 2 곳 × (5 + 5 + 선반) (실제 %d)" % 계단수)

	for 곳 in ["A", "C"]:
		var 오름 := _윗면("SS_STAIR_%s_1F_1" % 곳)
		var 다음 := _윗면("SS_STAIR_%s_1F_2" % 곳)
		if is_nan(오름) or is_nan(다음):
			_확인(false, "계단 %s 를 못 찾았다" % 곳)
			continue
		var 한칸 := 오름 - 다음
		_확인(한칸 <= 160.0, "계단 %s 한 칸 %.0f ≤ 점프 높이 160 — 오를 수 있다" % [곳, 한칸])

		# 위층 계단(2F)의 밑면과 그 아래 1층 디딤면 사이가 사람 키보다 넓어야 한다.
		var 이층_밑 := _아랫면("SS_STAIR_%s_2F_1" % 곳)
		var 일층_디딤 := _윗면("SS_STAIR_%s_1F_3" % 곳)
		var 머리 := 일층_디딤 - 이층_밑
		_확인(머리 >= 플레이어_키 + 20.0,
			"계단 %s · 2층 계단 밑 머리 공간 %.0f ≥ 키 96 + 여유 (전에 낀 사다리는 88 이었다)"
			% [곳, 머리])

		# 중간 선반이 L3 → 층참 560px 낙하를 절반으로 쪼갠다.
		var 선반 := _윗면("SS_STAIR_%s_선반" % 곳)
		var l3 := _윗면("SS_L3_FLOOR_1_") if 곳 == "A" else _윗면("SS_L3_FLOOR_4_")
		if not is_nan(선반) and not is_nan(l3):
			_확인(선반 - l3 < 520.0,
				"계단 %s · L3 → 중간 선반 %.0fpx < 치명 520 (선반이 없으면 560 이라 죽는다)"
				% [곳, 선반 - l3])


# ── 6. ★L3 에서 떨어뜨리기 ─────────────────────────────────────────────────
func _L3에서_떨어뜨리기() -> void:
	print("\n── ★★L3 에서 L1 까지 떨어뜨린다 (안 죽어야 한다)")
	var p := _루트.get_node_or_null("Player") as CharacterBody2D
	if p == null:
		_확인(false, "Player 를 못 찾았다")
		return

	# 구간 B_앞 / B_뒤 사이의 **80px 색 전환 틈**. 양쪽 L1 물이 다 검정이다.
	var 틈_왼 := _오른끝("SS_L3_FLOOR_3_")
	var 틈_오른 := _왼끝("SS_L3_FLOOR_4_")
	var l3 := _윗면("SS_L3_FLOOR_4_")
	var l1 := _윗면("SS_L1_FLOOR_4_")
	if is_nan(틈_왼) or is_nan(틈_오른) or is_nan(l3) or is_nan(l1):
		_확인(false, "떨어뜨릴 자리를 못 찾았다")
		return
	var 틈_폭 := 틈_오른 - 틈_왼
	_확인(틈_폭 > 플레이어_폭, "색 전환 틈 %.0fpx > 플레이어 폭 44 — 끼지 않고 떨어진다" % 틈_폭)

	p.set("player_color", ColorDefs.BLACK)
	p.global_position = Vector2((틈_왼 + 틈_오른) * 0.5, l3 - 40.0)
	p.velocity = Vector2.ZERO
	await physics_frame

	var 죽었나 := false
	var 도달 := false
	for _i in 240:
		await physics_frame
		if bool(_루트.call("_사망_판정")):
			죽었나 = true
			break
		if p.global_position.y > l1 - 80.0:
			도달 = true
			break

	var 낙차 := l1 - l3
	_확인(도달, "L1 물까지 내려갔다 (낙차 %.0fpx)" % 낙차)
	_확인(not 죽었나, "★%.0fpx 을 떨어졌는데 안 죽는다 — 물이 받아준다" % 낙차)
	_확인(낙차 > 520.0, "이 낙차는 치명 거리(520)를 넘는다 = 물이 없으면 즉사다")


# ── 7. ★승강기 타보기 ──────────────────────────────────────────────────────
func _승강기_타보기() -> void:
	print("\n── ★승강기를 타고 올라간다")
	var p := _루트.get_node_or_null("Player") as CharacterBody2D
	var 승강기 := _승강기들()
	if p == null or 승강기.is_empty():
		_확인(false, "승강기나 Player 를 못 찾았다")
		return
	var m := 승강기[0] as Node2D
	var 꼭대기: float = m.global_position.y
	var 이동거리 := float(m.get("이동거리"))

	var 내려옴 := false
	for _i in 900:
		await physics_frame
		if m.global_position.y > 꼭대기 + 이동거리 - 60.0:
			내려옴 = true
			break
	_확인(내려옴, "승강기가 L1 까지 내려온다")
	if not 내려옴:
		return

	var 두께 := float((m.get("크기") as Vector2).y)
	p.set("player_color", ColorDefs.BLACK)
	p.global_position = Vector2(m.global_position.x, m.global_position.y - 두께 * 0.5 - 20.0)
	p.velocity = Vector2.ZERO
	for _i in 30:
		await physics_frame
	_확인(p.is_on_floor(), "승강기 위에 섰다")

	var 사람_처음 := p.global_position.y
	var 승강기_처음 := m.global_position.y
	var 어긋난_최대 := 0.0
	for _i in 180:                                  # 3초
		await physics_frame
		var 어긋남 := absf((p.global_position.y - 사람_처음) - (m.global_position.y - 승강기_처음))
		어긋난_최대 = maxf(어긋난_최대, 어긋남)
	var 사람_오름 := 사람_처음 - p.global_position.y
	var 승강기_오름 := 승강기_처음 - m.global_position.y

	_확인(승강기_오름 > 300.0, "승강기가 올라갔다 (%.0fpx)" % 승강기_오름)
	_확인(사람_오름 > 300.0, "★플레이어도 같이 올라갔다 (%.0fpx)" % 사람_오름)
	_확인(어긋난_최대 < 40.0, "타는 내내 안 끼고 안 미끄러진다 (최대 어긋남 %.1fpx)" % 어긋난_최대)
	_확인(not bool(_루트.call("_사망_판정")), "타고 가는 동안 안 죽는다")
