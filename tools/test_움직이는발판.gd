extends SceneTree
## ============================================================================
## [2026-09-07 신규] 움직이는 발판 (스마트월드) 검사
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_움직이는발판.gd
##
## ▣ 여기서 못 박는 것
##   1. ★**플레이어를 태우고 간다.** 이게 안 되면 발판이 아니라 장식이다.
##      (`AnimatableBody2D` + `sync_to_physics` + `_physics_process` 안에서 이동)
##   2. 좌우·상하 둘 다 움직이고, **한 바퀴 뒤 제자리로** 돌아온다.
##   3. `시작지연` 동안은 제자리 — 여러 장을 엇갈리게 놓을 수 있어야 한다.
##   4. `원점이_가운데` 를 끄면 **에디터에서 놓은 자리가 곧 출발 자리**다.
##   5. 페인트 계약이 통과플랫폼과 똑같다 — 칠하고, 회수하고, 색 규칙에 참여한다.
##   6. ★**안 칠한 발판은 검정이다.** 흰 플레이어가 올라타면 죽어야 한다(`색규칙.gd`).
## ============================================================================

const 발판_씬 := "res://scenes/집/스마트월드_장애물/움직이는발판.tscn"
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

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


func _같나(a: float, b: float, 허용: float = 1.0) -> bool:
	return absf(a - b) <= 허용


func _실행() -> void:
	print("\n=== 움직이는 발판 ===")
	await _좌우_왕복()
	await _상하_왕복()
	await _시작지연()
	await _원점_기준()
	_페인트_계약()
	_색규칙_참여()
	await _플레이어를_태우나()

	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


## ★값을 먼저 넣고 **그 다음에** 트리에 붙인다.
##   `_ready()` 가 그 자리를 시작 위치로 기억하므로 순서가 뒤바뀌면 안 된다.
func _발판_만들기() -> Node2D:
	return (load(발판_씬) as PackedScene).instantiate() as Node2D


func _치우기(노드들: Array) -> void:
	for n in 노드들:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()


## ★진짜 물리 프레임을 돌린다.
##   `_physics_process` 를 손으로 부르면 안 된다 — `sync_to_physics` 가 켜진 몸은
##   물리 서버가 위치의 주인이라, 프레임 밖에서 옮긴 값이 그대로 남지 않는다.
func _돌리기(초: float) -> void:
	for _i in int(round(초 * 60.0)):
		await physics_frame


# ── 1. 좌우 ─────────────────────────────────────────────────────────────────
func _좌우_왕복() -> void:
	print("\n── 좌우 왕복")
	var p := _발판_만들기()
	p.position = Vector2(1000, 500)
	p.이동방향 = 0
	p.이동거리 = 300.0
	p.왕복시간 = 4.0
	p.시작지연 = 0.0
	root.add_child(p)

	await _돌리기(2.0)                        # 반 바퀴 = 가장 먼 끝
	_확인(_같나(p.position.x, 1300.0, 6.0), "반 바퀴에 +이동거리 끝 (x %.1f)" % p.position.x)
	_확인(_같나(p.position.y, 500.0), "좌우 발판은 y가 안 변한다")
	await _돌리기(2.0)                        # 한 바퀴 = 제자리
	_확인(_같나(p.position.x, 1000.0, 6.0), "한 바퀴에 제자리 (x %.1f)" % p.position.x)
	_치우기([p])


# ── 2. 상하 ─────────────────────────────────────────────────────────────────
func _상하_왕복() -> void:
	print("\n── 상하 왕복")
	var p := _발판_만들기()
	p.position = Vector2(1000, 1140)
	p.이동방향 = 1
	p.이동거리 = 560.0                        # 2-8 의 한 층
	p.왕복시간 = 6.0
	p.시작지연 = 0.0
	root.add_child(p)

	await _돌리기(3.0)
	_확인(_같나(p.position.y, 1700.0, 8.0), "반 바퀴에 한 층 아래 (y %.1f)" % p.position.y)
	_확인(_같나(p.position.x, 1000.0), "상하 발판은 x가 안 변한다")
	_치우기([p])


# ── 3. 시작지연 ─────────────────────────────────────────────────────────────
func _시작지연() -> void:
	print("\n── 시작지연 (여러 장을 엇갈리게)")
	var p := _발판_만들기()
	p.position = Vector2(0, 0)
	p.이동거리 = 200.0
	p.왕복시간 = 4.0
	p.시작지연 = 1.5
	root.add_child(p)
	await _돌리기(1.0)
	_확인(_같나(p.position.x, 0.0), "지연 동안에는 제자리 (x %.1f)" % p.position.x)
	await _돌리기(1.5)                        # 지연을 넘겨 1초 진행
	_확인(p.position.x > 20.0, "지연이 끝나면 움직인다 (x %.1f)" % p.position.x)
	_치우기([p])


# ── 4. 원점 기준 ────────────────────────────────────────────────────────────
func _원점_기준() -> void:
	print("\n── 원점이_가운데")
	var a := _발판_만들기()
	a.position = Vector2(0, 0); a.이동거리 = 400.0; a.왕복시간 = 4.0
	a.원점이_가운데 = false; root.add_child(a)
	_확인(_같나(a.position.x, 0.0), "끔: 놓은 자리가 곧 출발 자리")
	await _돌리기(2.0)
	_확인(_같나(a.position.x, 400.0, 8.0), "끔: 반대 끝이 +400 (x %.1f)" % a.position.x)

	var b := _발판_만들기()
	b.position = Vector2(0, 0); b.이동거리 = 400.0; b.왕복시간 = 4.0
	b.원점이_가운데 = true; root.add_child(b)
	await _돌리기(0.05)
	_확인(_같나(b.position.x, -200.0, 8.0), "켬: 놓은 자리가 구간 가운데 (x %.1f)" % b.position.x)
	_치우기([a, b])


# ── 5. 페인트 계약 ──────────────────────────────────────────────────────────
func _페인트_계약() -> void:
	print("\n── 페인트 계약 (통과플랫폼과 동일해야 한다)")
	var 코어 := 페인트코어.new()
	코어.최대_탄약 = 10
	코어.add_to_group("페인트코어")
	root.add_child(코어)
	var p := _발판_만들기()
	p.필요횟수 = 2
	root.add_child(p)

	_확인(p.현재색() == -1, "처음에는 안 칠한 상태(-1)")
	코어.발사_소모()
	_확인(코어.명중_처리(p, ColorDefs.WHITE, Vector2.ZERO) == "progress", "1발은 부분 칠")
	코어.발사_소모()
	_확인(코어.명중_처리(p, ColorDefs.WHITE, Vector2.ZERO) == "painted", "2발째에 완성")
	_확인(p.현재색() == ColorDefs.WHITE, "흰색이 되었다")
	_확인(코어.수동_회수(), "E 로 회수된다")
	_확인(p.현재색() == -1, "회수하면 안 칠한 상태로 돌아온다")
	_확인(코어.남은_탄약 == 10, "회수하면 2발 다 돌아온다 (실제 %d)" % 코어.남은_탄약)

	# 분사기가 칠한 경우 — 회수 불가여야 한다
	코어.장치_명중_처리(p, ColorDefs.BLACK, Vector2.ZERO)
	코어.장치_명중_처리(p, ColorDefs.BLACK, Vector2.ZERO)
	_확인(p.현재색() == ColorDefs.BLACK, "분사기도 움직이는 발판을 칠한다")
	_확인(코어.수동_회수() == false, "분사기가 칠한 것은 E 로 못 지운다")
	코어.리셋()
	_확인(p.현재색() == -1, "리셋하면 분사기 페인트도 지워진다")
	_치우기([p, 코어])


# ── 6. 색 규칙 ──────────────────────────────────────────────────────────────
func _색규칙_참여() -> void:
	print("\n── ★안 칠한 발판은 검정이다")
	var p := _발판_만들기()
	root.add_child(p)
	_확인(p.반대색인가(ColorDefs.WHITE), "안 칠한 발판 + 흰 플레이어 = 위험")
	_확인(not p.반대색인가(ColorDefs.BLACK), "안 칠한 발판 + 검정 플레이어 = 안전")
	p.명중(ColorDefs.WHITE, Vector2.ZERO); p.명중(ColorDefs.WHITE, Vector2.ZERO)
	_확인(not p.반대색인가(ColorDefs.WHITE), "흰색으로 칠하면 흰 플레이어가 안전")
	_확인(p.반대색인가(ColorDefs.BLACK), "그러면 검정 플레이어가 위험")
	_치우기([p])


# ── 7. ★플레이어를 태우나 ───────────────────────────────────────────────────
func _플레이어를_태우나() -> void:
	print("\n── ★플레이어를 태우고 간다 (이게 안 되면 발판이 아니다)")
	var 방 := Node2D.new()
	root.add_child(방)

	var p := _발판_만들기()
	p.크기 = Vector2(400, 40)
	p.position = Vector2(0, 600)
	p.이동방향 = 0
	p.이동거리 = 400.0
	p.왕복시간 = 4.0
	p.시작지연 = 0.0
	방.add_child(p)
	_확인(p.sync_to_physics, "sync_to_physics 가 켜져 있다")

	var 플레이어 := 플레이어_씬.instantiate() as CharacterBody2D
	방.add_child(플레이어)
	# 발판 윗면(600-20=580) 바로 위에 세운다. 발이 원점이므로 살짝 띄워 착지시킨다.
	플레이어.global_position = Vector2(0, 570)
	for _i in 40:
		await physics_frame                  # 착지 대기
	var 탄_처음: float = 플레이어.global_position.x
	var 발판_처음: float = p.global_position.x
	_확인(플레이어.is_on_floor(), "발판 위에 섰다")

	for _i in 60:                            # 1초 = 왕복시간 4초의 1/4
		await physics_frame
	var 발판_이동: float = p.global_position.x - 발판_처음
	var 플레이어_이동: float = 플레이어.global_position.x - 탄_처음
	_확인(발판_이동 > 40.0, "발판이 움직였다 (%.1fpx)" % 발판_이동)
	_확인(absf(플레이어_이동 - 발판_이동) < 24.0,
		"플레이어가 같이 실려 갔다 (발판 %.1f · 플레이어 %.1f)" % [발판_이동, 플레이어_이동])

	_치우기([방])
