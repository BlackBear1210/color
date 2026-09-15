extends SceneTree
## ============================================================================
## [2026-09-14 신규] 하수도 지지구조(쇠사슬·삼각 지지대·체인 고정구) 기능 검사
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/test_하수도_지지구조.gd
## 대상: scenes/테스트/하수도_지지구조/쇠사슬_지지대_시험.tscn (tools/build_하수도_지지구조_시험씬.gd 가 굽는다)
##
## 검사 ID 는 프롬프트(프롬프트_Opus_쇠사슬_삼각지지대_장식키트.md §13) 표와 같다.
##   C01~C07 체인 · B01~B03 지지대 · G01~G05 게임 규칙 · S01~S02 저장/인스턴스.
##   V01~V03(눈으로 보는 것)은 여기서 못 잰다 — `docs/스크린샷_하수도_지지구조_2026-09-14/` 를 본다.
##
## ▣ 원칙
##   · 내부 계산을 다시 계산해 비교하는 데서 끝내지 않는다 — **실제로 움직이는 승강기의 Marker**,
##     **실제로 저장했다 다시 읽은 씬**, **실제 Player·총알**을 붙여 본다.
##   · 실패를 없애려고 충돌·색 사망·승강기 검사를 끄지 않는다. exit 0 인데 ERROR 가 찍히면 통과가 아니다.
## ============================================================================

const 씬경로 := "res://scenes/테스트/하수도_지지구조/쇠사슬_지지대_시험.tscn"
const 재저장경로 := "user://지지구조_재저장_시험.tscn"
const S_쇠사슬 := "res://scenes/장식/하수도_지지구조/쇠사슬.tscn"
const 총알_S := preload("res://scripts/스마트월드/총알.gd")

const 검정 := 0
const 흰색 := 1

var 검사수 := 0
var 실패수 := 0
var _씬: Node2D
var _p: Node2D
var _코어: Node


func _initialize() -> void:
	Engine.max_fps = 0
	call_deferred("_실행")


func 검사(id: String, 이름: String, ok: bool, 덧: String = "") -> void:
	검사수 += 1
	if not ok:
		실패수 += 1
	print("%s %s %s%s" % ["PASS" if ok else "FAIL", id, 이름, ("  — " + 덧) if 덧 != "" else ""])


func 프레임(n: int = 3) -> void:
	for i in n:
		await physics_frame


func _열기() -> void:
	var ps := load(씬경로) as PackedScene
	_씬 = ps.instantiate() as Node2D
	root.add_child(_씬)
	await 프레임(4)
	_p = _씬.get_node("Player")
	_코어 = _씬.get_node("페인트코어")
	# 검사 좌표를 리스폰·안전지점이 바꾸지 않게. 물리 질의는 실제 월드를 쓴다.
	_씬.set("안전지점_자동저장", false)


func _닫기() -> void:
	_씬.free()
	_씬 = null
	await 프레임(2)


func 체인(이름: String) -> Node2D:
	return _씬.get_node("장식/" + 이름) as Node2D


func 정보(c: Node2D) -> Dictionary:
	return c.call("그리기_정보")


## 플레이어를 그 자리에 그 색으로 세우고 월드의 실제 사망 판정을 묻는다.
func 죽나(자리: Vector2, 색: int) -> bool:
	_p.global_position = 자리
	_p.set("자유색", 색)
	_p.set("player_color", 색)
	_p.set("velocity", Vector2.ZERO)
	await 프레임(3)
	return bool(_씬.call("_사망_판정"))


func _실행() -> void:
	print("\n════════ 하수도 지지구조 검사 ════════")
	await _열기()
	await _C_체인()
	await _B_지지대()
	await _G_게임규칙()
	await _S_저장()
	await _닫기()
	await _C07_재진입()
	print("\nSUPPORT_RESULT %d/%d PASS" % [검사수 - 실패수, 검사수])
	quit(1 if 실패수 > 0 else 0)


# ============================================================================
# C. 체인
# ============================================================================
func _C_체인() -> void:
	var c := 체인("체인4_짧은")
	var 간격: float = c.get("고리_간격")
	# C01 — 길이를 여러 단계로 바꿔도 고리 간격(텍스처 반복 단위)이 그대로고 고리 수만 는다
	var ok := true
	var 덧 := ""
	for L in [100.0, 333.0, 777.0, 2000.0]:
		c.set("고정_끝", Vector2(0, L))
		await 프레임(1)
		var i := 정보(c)
		var 겹침: float = minf(float(c.get("끝단_겹침")), float(L) * 0.2)
		var 기대_고리수: float = (float(L) - 겹침 * 2.0) / 간격
		if not bool(i["보임"]) or absf(float(i["고리수"]) - 기대_고리수) > 0.001 or absf(float(i["길이"]) - L) > 0.001:
			ok = false
			덧 += " L=%.0f 고리수 %.2f(기대 %.2f)" % [L, float(i["고리수"]), 기대_고리수]
	검사("C01", "길이 4 단계 — 고리 간격 유지 · 고리 수만 변함", ok, 덧)

	# C02 — 반복 단위 경계(간격의 배수)를 넘어도 위상 기준이 끝점(발판)에 고정 → 튐 없음
	var 위상기준_고정 := true
	for L in [간격 * 2.0 - 1.0, 간격 * 2.0, 간격 * 2.0 + 1.0]:
		c.set("고정_끝", Vector2(0, L))
		await 프레임(1)
		var i := 정보(c)
		if String(i["위상기준"]) != "끝점":
			위상기준_고정 = false
	검사("C02", "반복 경계(95/96/97) 전후 — 위상 기준 = 끝점 고정", 위상기준_고정)
	c.set("고정_끝", Vector2(0, 200))

	# C03 — 실제 승강기 위/중간/아래: 천장점 고정 · 끝점이 Marker 를 따라감
	var cl := 체인("체인5_L")
	var 천장 := _씬.get_node("장식/천장고정구5_L/연결점") as Node2D
	var 발판 := _씬.get_node("장치/승강기5/연결구_L/연결점") as Node2D
	var 승 := _씬.get_node("장치/승강기5") as Node2D
	var 천장_처음 := 천장.global_position
	var 자리들 := []
	var 끊김 := false
	var 위치기록 := []
	for 표본 in 3:
		await 프레임(60)                                   # 6 초 왕복의 1/6 씩
		var i := 정보(cl)
		var a := cl.to_global(i["시작"])
		var b := cl.to_global(i["끝"])
		자리들.append(승.global_position.y)
		위치기록.append("승강기 y=%.0f 체인 %.0f→%.0f" % [승.global_position.y, a.y, b.y])
		if a.distance_to(천장.global_position) > 0.5 or b.distance_to(발판.global_position) > 0.5 or not bool(i["보임"]):
			끊김 = true
	var 움직임 := absf(자리들[0] - 자리들[2]) > 50.0 or absf(자리들[0] - 자리들[1]) > 50.0
	검사("C03", "승강기 이동 중 천장점 고정 · 끝점 추적 · 끊김 없음", not 끊김 and 움직임 and 천장.global_position == 천장_처음, "; ".join(위치기록))

	# C04 — 왕복 3 번: 노드 수·경고 수 그대로, 그리기는 변할 때만
	var 노드수_전 := root.get_child_count() + _씬.get_child_count() + _노드수(_씬)
	var 경고_전: int = cl.get("_경고_횟수")
	var 그리기_전: int = cl.get("_그리기_횟수")
	await 프레임(60 * 18)
	var 노드수_후 := root.get_child_count() + _씬.get_child_count() + _노드수(_씬)
	var i4 := 정보(cl)
	var 오차 := cl.to_global(i4["끝"]).distance_to(발판.global_position)
	var 정적 := 체인("체인4_긴")
	var 정적_그리기_전: int = 정적.get("_그리기_횟수")
	await 프레임(30)
	var 정적_그리기_후: int = 정적.get("_그리기_횟수")
	검사("C04", "왕복 3 회 뒤 노드 수 같음 · 오차 누적 없음 · 경고 반복 없음 · 정적 체인은 다시 안 그림",
		노드수_전 == 노드수_후 and 오차 < 0.5 and int(cl.get("_경고_횟수")) == 경고_전 and 정적_그리기_후 == 정적_그리기_전,
		"노드 %d→%d · 오차 %.2f · 경고 %d · 동적 그리기 %d회 · 정적 그리기 +%d" % [
			노드수_전, 노드수_후, 오차, int(cl.get("_경고_횟수")), int(cl.get("_그리기_횟수")) - 그리기_전, 정적_그리기_후 - 정적_그리기_전])

	# C05 — 옮겨 놓은 부모 밑의 체인: 원점에 남지 않고 두 Marker 사이에 그려진다
	var c6 := 체인("이동된_묶음6/체인6")
	var a6 := _씬.get_node("장식/이동된_묶음6/천장고정구6/연결점") as Node2D
	var e6 := _씬.get_node("장식/이동된_묶음6/발판고정구6/연결점") as Node2D
	var i6 := 정보(c6)
	var a6w := c6.to_global(i6["시작"])
	var b6w := c6.to_global(i6["끝"])
	검사("C05", "이동된 부모(2000,400) 밑 체인 — 월드 Marker 와 일치 · 원점(0,0) 아님",
		bool(i6["보임"]) and a6w.distance_to(a6.global_position) < 0.5 and b6w.distance_to(e6.global_position) < 0.5
		and a6w.length() > 100.0,
		"체인 %s→%s" % [str(a6w), str(b6w)])

	# C06 — 끊긴 경로 · 길이 0 · 텍스처 없음 · 최대 길이 초과: 크래시 없음 · 안 그림 · 경고 1 회
	var 오류1 := 체인("오류7_끊긴경로")
	var 오류2 := 체인("오류7_길이0")
	var i1 := 정보(오류1)
	var i2 := 정보(오류2)
	var 임시 := (load(S_쇠사슬) as PackedScene).instantiate() as Node2D
	_씬.get_node("장식").add_child(임시)
	임시.set("모드", 0)
	임시.set("고정_끝", Vector2(0, 300))
	await 프레임(1)
	임시.set("텍스처", null)
	await 프레임(2)
	var i3 := 정보(임시)
	임시.set("텍스처", load("res://assets/decorations/sewer_support_v01/chain_repeat.png"))
	임시.set("고정_끝", Vector2(0, 9000))
	await 프레임(2)
	var i4b := 정보(임시)
	var 경고1: int = 오류1.get("_경고_횟수")
	await 프레임(30)
	검사("C06", "끊긴 경로·길이 0·텍스처 없음 → 안 그림 · 경고는 한 번 · 최대 길이 초과는 잘라 그림",
		not bool(i1["보임"]) and not bool(i2["보임"]) and not bool(i3["보임"]) and bool(i4b["보임"])
		and absf(float(i4b["그린길이"]) - (float(임시.get("최대_길이")) - 2.0 * float(임시.get("끝단_겹침")))) < 0.01
		and 경고1 == 1 and int(오류1.get("_경고_횟수")) == 1 and int(임시.get("_경고_횟수")) <= 2,
		"끊긴경로 경고 %d회(30프레임 뒤 %d) · 초과 체인 그린길이 %.0f" % [경고1, int(오류1.get("_경고_횟수")), float(i4b["그린길이"])])
	임시.free()


func _노드수(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		k += 1 + _노드수(c)
	return k


# ============================================================================
# B. 삼각 지지대
# ============================================================================
func _B_지지대() -> void:
	var br1 := _씬.get_node("지형/발판1_검정/지지대1_왼쪽") as Node2D
	var br2 := _씬.get_node("지형/발판2_흰/지지대2_오른쪽") as Node2D
	var 그림1 := br1.get_node("그림") as Sprite2D
	# B01 — 방향을 바꿔도 부착점(원점)은 그대로, 그림만 뒤집히고 좌우로 옮겨 앉는다. 지형·충돌은 안 뒤집힌다.
	var 원점_전 := br1.global_position
	var 그림x_전 := 그림1.position.x
	var 발판_scale := (br1.get_parent() as Node2D).scale
	br1.set("방향", 1)
	await 프레임(1)
	var 뒤집힘 := 그림1.flip_h and absf(그림1.position.x + 그림x_전) < 0.01
	br1.set("방향", 0)
	await 프레임(1)
	var 충돌없음 := _충돌노드수(br1) == 0 and _충돌노드수(br2) == 0
	var 그룹없음 := not br1.is_in_group("칠할수있음") and not br1.is_in_group("스마트지형") and not br1.is_in_group("player")
	검사("B01", "좌우 변경 — 부착점 유지 · 그림만 flip · 지형 scale 그대로 · 충돌/게임 그룹 없음",
		br1.global_position == 원점_전 and 뒤집힘 and not 그림1.flip_h and (br1.get_parent() as Node2D).scale == 발판_scale
		and 충돌없음 and 그룹없음 and br1.scale == Vector2.ONE)

	# B02 — 넓은 발판의 지지대 두 개: 같은 크기(균일 배율) · 안 겹침 · 폭만 늘린 게 아님
	var a := _씬.get_node("지형/발판3_넓은/지지대3a") as Node2D
	var b := _씬.get_node("지형/발판3_넓은/지지대3b") as Node2D
	var ra: Rect2 = a.call("그림_사각_월드")
	var rb: Rect2 = b.call("그림_사각_월드")
	var sa := (a.get_node("그림") as Sprite2D).scale
	var sb := (b.get_node("그림") as Sprite2D).scale
	a.set("배율", 3.0)          # 범위 밖 → 1.5 로 잘려야 한다
	await 프레임(1)
	# 원본 해상도가 달라도 실제 표시 크기96×배율을 검사해야 고해상도 아트 교체를 검증한다.
	var 실제크기 := (a.get_node("그림") as Sprite2D).texture.get_size() * (a.get_node("그림") as Sprite2D).scale
	var 잘림 := absf(float(a.get("배율")) - 1.5) < 0.001 and 실제크기.is_equal_approx(Vector2(144, 144))
	a.set("배율", 1.0)
	await 프레임(1)
	검사("B02", "지지대 두 개 — 같은 크기 · 겹치지 않음 · 배율은 균일하고 0.75~1.5 로 잘림",
		ra.size == rb.size and not ra.intersects(rb) and sa == sb and sa.x == sa.y and 잘림,
		"a=%s b=%s" % [str(ra), str(rb)])

	# B03 — 고정 발판을 옮기면 부착 장식이 따라오고, 천장 고정구는 승강기 자식이 아니다
	var p1 := _씬.get_node("지형/발판1_검정") as Node2D
	var 전 := br1.global_position
	p1.position += Vector2(0, -50)
	await 프레임(1)
	var 따라옴 := br1.global_position == 전 + Vector2(0, -50)
	p1.position -= Vector2(0, -50)
	await 프레임(1)
	var 천장 := _씬.get_node("장식/천장고정구5_L") as Node2D
	var 독립 := not (_씬.get_node("장치/승강기5") as Node).is_ancestor_of(천장)
	검사("B03", "발판 이동 → 지지대 따라옴 · 천장 고정구는 승강기와 독립", 따라옴 and 독립)


func _충돌노드수(n: Node) -> int:
	var k := 0
	if n is CollisionObject2D or n is CollisionShape2D or n is CollisionPolygon2D:
		k += 1
	for c in n.get_children():
		k += _충돌노드수(c)
	return k


# ============================================================================
# G. 게임 규칙 — 실제 월드 사망 판정 · 실제 총알 · 실제 탑승
# ============================================================================
func _G_게임규칙() -> void:
	var p1 := _씬.get_node("지형/발판1_검정") as Node2D
	# G01 — 흰 플레이어가 검정 장식(지지대·체인)만 겹쳐도 안 죽는다
	var 지지대에서 := await 죽나(Vector2(448, 1450), 흰색)      # 지지대1 그림(400~496 × 1316~1412) 안 · 발판·기둥엔 안 닿음
	var 체인에서 := await 죽나(Vector2(3160, 800), 흰색)        # 체인5_L 위 (허공)
	검사("G01", "흰 몸이 검정 지지대·체인만 통과 — 사망 없음", not 지지대에서 and not 체인에서)
	# G02 — 실제 반대색 지형(검정 발판1 윗면)에 서면 죽는다 (규칙이 그대로다)
	var 발판에서 := await 죽나(Vector2(560, 1200), 흰색)
	검사("G02", "흰 몸이 검정 발판에 닿으면 기존대로 사망", 발판에서)
	# G03 — 체인 앞에서 실제 총알을 쏘면 체인을 통과해 뒤의 발판에 맞는다
	#   발판1 은 320 폭이라 필요횟수 4 → 한 발은 "progress". 흰 발 진행 횟수가 1 오르면 명중한 것이다.
	var 임시체인 := (load(S_쇠사슬) as PackedScene).instantiate() as Node2D
	임시체인.position = Vector2(560, 1000)
	_씬.get_node("장식").add_child(임시체인)
	임시체인.set("모드", 0); 임시체인.set("고정_끝", Vector2(0, 195))
	_p.global_position = Vector2(300, 1600)
	_p.set("자유색", 검정); _p.set("player_color", 검정)
	await 프레임(2)
	var 진행 = p1.get("_진행")
	var 흰발_전: int = 진행.횟수(흰색)
	var 탄약_전: int = _코어.get("남은_탄약")
	_코어.call("발사_소모")
	var 총알 := Area2D.new()
	총알.set_script(총알_S)
	_씬.add_child(총알)
	총알.call("시작", Vector2(560, 990), Vector2.DOWN, 900.0, 흰색, _코어)
	await 프레임(40)
	var 흰발_후: int = 진행.횟수(흰색)
	검사("G03", "총알이 체인(560,1000~1195)을 통과해 뒤 발판1(윗면 1200)에 명중 — 흰 발 진행 +1",
		흰발_후 == 흰발_전 + 1 and not is_instance_valid(총알),
		"흰 발 %d→%d (필요횟수 %d) · 탄약 %d→%d" % [흰발_전, 흰발_후, int(p1.call("필요횟수")), 탄약_전, int(_코어.get("남은_탄약"))])
	임시체인.free()
	# G04 — 지형 칠하기: 필요횟수만큼 코어로 맞혀 흰색이 되게 하고, 지지대는 금속 외관(modulate) 그대로
	var 그림1 := _씬.get_node("지형/발판1_검정/지지대1_왼쪽/그림") as Sprite2D
	var 색조_전 := 그림1.modulate
	var r := ""
	for i in int(p1.call("필요횟수")):
		_코어.call("발사_소모")
		r = String(_코어.call("명중_처리", p1, 흰색, p1.global_position + Vector2(160 + i * 4, 10)))
		if r == "painted":
			break
	await 프레임(2)
	var 칠한색: int = p1.call("현재색")
	검사("G04", "발판1 을 흰색으로 다 칠함 · 지지대 색조 불변 · 지지대는 게임 색 상태가 아님",
		r == "painted" and 칠한색 == 흰색 and 그림1.modulate == 색조_전, "명중_처리=%s 현재색=%d" % [r, 칠한색])
	# G05 — 승강기 탑승: 플레이어가 같이 오르내리고, 체인 달린 승강기와 안 달린 승강기의 움직임이 같다
	var 승 := _씬.get_node("장치/승강기5") as Node2D
	var 비교 := _씬.get_node("장치/승강기5_비교") as Node2D
	승.call("위상_초기화"); 비교.call("위상_초기화")
	_p.global_position = Vector2(3300, 승.global_position.y - 14.0 - 1.0)
	_p.set("자유색", 검정); _p.set("player_color", 검정)
	_p.set("velocity", Vector2.ZERO)
	await 프레임(90)
	var 승y := 승.global_position.y
	var 비교y := 비교.global_position.y
	var 플y := _p.global_position.y
	var 탔다 := absf((플y + 14.0) - 승y) < 6.0 and absf(승y - 1100.0) > 40.0
	var 같이움직임 := absf((승y - 1100.0) - (비교y - 1100.0)) < 0.01
	검사("G05", "승강기 탑승 유지 · 체인이 승강기 움직임을 바꾸지 않음",
		탔다 and 같이움직임 and not bool(_씬.call("_사망_판정")),
		"승강기 %.1f · 비교 %.1f · 플레이어 발 %.1f" % [승y, 비교y, 플y + 14.0])


# ============================================================================
# S. 저장 · 인스턴스
# ============================================================================
func _S_저장() -> void:
	# S01 — 씬을 실제로 다시 저장하고 읽어 노드 수·경로·길이·방향이 같은가
	var 전_수 := _노드수(_씬)
	var 팩 := PackedScene.new()
	var e := 팩.pack(_씬)
	var e2 := ResourceSaver.save(팩, 재저장경로) if e == OK else e
	var ok := e == OK and e2 == OK
	var 덧 := "pack=%s save=%s" % [error_string(e), error_string(e2)]
	if ok:
		var 다시 := (load(재저장경로) as PackedScene).instantiate() as Node2D
		root.add_child(다시)
		await 프레임(3)
		var 후_수 := _노드수(다시)
		var c := 다시.get_node("장식/체인5_L")
		var c4 := 다시.get_node("장식/체인4_긴")
		var br2 := 다시.get_node("지형/발판2_흰/지지대2_오른쪽")
		ok = 후_수 == 전_수 and String(c.get("끝점_경로")) == "../../장치/승강기5/연결구_L/연결점" \
			and c4.get("고정_끝") == Vector2(0, 700) and int(br2.get("방향")) == 1 \
			and bool(정보(c)["보임"])
		덧 += " · 노드 %d→%d · 끝점경로=%s · 긴체인 고정_끝=%s · 지지대2 방향=%d" % [
			전_수, 후_수, String(c.get("끝점_경로")), str(c4.get("고정_끝")), int(br2.get("방향"))]
		다시.free()
	검사("S01", "다시 저장 → 다시 로드: 노드 수·끝점 경로·길이·방향 유지", ok, 덧)

	# S02 — 같은 장식 여러 인스턴스: 하나를 바꿔도 다른 것은 그대로 (공유 텍스처도 안 바뀜)
	var cl := 체인("체인5_L")
	var cr := 체인("체인5_R")
	var 폭_전: float = cr.get("고리_폭")
	cl.set("고리_폭", 40.0)
	cl.set("색조", Color(0.5, 0.5, 0.5))
	var a := _씬.get_node("지형/발판3_넓은/지지대3a") as Node2D
	var b := _씬.get_node("지형/발판3_넓은/지지대3b") as Node2D
	a.set("색조", Color(0.3, 0.3, 0.3))
	await 프레임(1)
	var 독립: bool = absf(float(cr.get("고리_폭")) - 폭_전) < 0.001 and cr.get("색조") == Color(1, 1, 1, 1) \
		and (b.get_node("그림") as Sprite2D).modulate == Color(1, 1, 1, 1) \
		and (a.get_node("그림") as Sprite2D).texture == (b.get_node("그림") as Sprite2D).texture
	cl.set("고리_폭", 폭_전); cl.set("색조", Color(1, 1, 1, 1)); a.set("색조", Color(1, 1, 1, 1))
	검사("S02", "인스턴스 독립 — 한 체인·지지대의 값 변경이 다른 것에 안 퍼짐 · 텍스처는 공유", 독립)


# ============================================================================
# C07 — 대상 삭제 · 씬 재진입
# ============================================================================
func _C07_재진입() -> void:
	await _열기()
	var cl := 체인("체인5_L")
	var 발판고정 := _씬.get_node("장치/승강기5/연결구_L")
	await 프레임(5)
	var 전 := 정보(cl)
	발판고정.free()
	await 프레임(5)
	var 후 := 정보(cl)
	var 삭제_안전 := bool(전["보임"]) and not bool(후["보임"]) and int(cl.get("_경고_횟수")) <= 1
	var 체인수_1 := _체인수(_씬)
	await _닫기()
	await _열기()
	var 체인수_2 := _체인수(_씬)
	var 다시 := 정보(체인("체인5_L"))
	await _닫기()
	검사("C07", "끝점 삭제 → 안 그리고 오류 없음 · 씬 나갔다 들어와도 체인 수 같고 다시 그려짐",
		삭제_안전 and 체인수_1 == 체인수_2 and bool(다시["보임"]), "체인 %d/%d" % [체인수_1, 체인수_2])


func _체인수(n: Node) -> int:
	var k := 0
	if n.has_method("그리기_정보"):
		k += 1
	for c in n.get_children():
		k += _체인수(c)
	return k
