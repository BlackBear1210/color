extends SceneTree
## ============================================================================
## [2026-08-06 신규] 낙하 사망 · 자동 체크포인트 자동 검사
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_낙하사망.gd
##
## ▣ 무엇을 보나
##   1. 치명 거리보다 **적게** 떨어지면 죽지 않는다        (안 그러면 계단도 못 내려간다)
##   2. 치명 거리를 넘으면 **떨어지는 도중에 바로** 죽는다  (착지를 기다리지 않는다)
##   3. 죽으면 스테이지 처음이 아니라 **마지막 안전지점**으로 돌아온다
##   4. 경고 비네트 세기가 0 → 1 로 올라간다                (죽기 전에 신호가 있다)
##   5. 리스폰 직후 낙하 상태가 초기화된다                  (안 하면 즉사 무한 루프)
##
## ▣ ⚠ 헤드리스 주의 (둘 다 실제로 가짜 실패를 만든 적 있는 함정)
##   1. `Engine.max_fps = 60` — 헤드리스는 fps 무제한이라 "N 프레임 = N/60 초" 가 깨진다
##   2. `_init()` 에서 add_child 한 노드는 그 프레임에 `_ready` 가 안 돈다
## ============================================================================

const 씬 := "res://scenes/스마트월드/_원본/원본_숲_코드생성.tscn"

var _통과 := 0
var _실패 := 0
var _n := 0
var _단계 := 0
var _루트: Node = null
var _p: CharacterBody2D = null
var _낙하: Node = null
var _안전한_땅 := Vector2.ZERO
var _최대위험도 := 0.0


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_tick)


func _확인(조건: bool, 설명: String) -> void:
	if 조건:
		_통과 += 1
		print("  ✔ %s" % 설명)
	else:
		_실패 += 1
		print("  ✖ %s" % 설명)


func _tick() -> void:
	_n += 1
	match _단계:
		0:
			if _n == 1:
				_루트 = (load(씬) as PackedScene).instantiate()
				root.add_child(_루트)
				current_scene = _루트
			elif _n == 4:
				_p = _루트.get_node_or_null("Player") as CharacterBody2D
				_낙하 = _루트.get_node_or_null("낙하감시")
				_확인(_p != null, "Player 를 찾았다")
				_확인(_낙하 != null, "월드가 낙하감시를 붙였다")
				if _p == null or _낙하 == null:
					_끝내기()
					return
				_확인(float(_루트.get("치명_낙하거리")) > 0.0,
					"치명 낙하 거리가 설정돼 있다 (%.0fpx)" % _루트.get("치명_낙하거리"))
				print("")
				print("── 1) 안전한 낙하 (치명 거리의 절반) ──────────")
				# 평평한 시작 지대 위에서 250px 만 떨어뜨린다
				_p.global_position = Vector2(400, 520)
				_p.velocity = Vector2.ZERO
				_단계 = 1
				_n = 0
		1:
			# 착지할 때까지 기다렸다가 "안 죽었는지" 본다
			if _n == 60:
				var 땅에 := bool(_p.call("is_on_floor"))
				_확인(땅에, "250px 낙하 후 착지했다 (y=%.0f)" % _p.global_position.y)
				_확인(_p.global_position.x > 300.0,
					"안 죽었다 — 리스폰되지 않고 그 자리에 있다 (x=%.0f)" % _p.global_position.x)
				_안전한_땅 = _p.global_position
				print("")
				print("── 2) 안전지점 저장 대기 ──────────────────────")
				_단계 = 2
				_n = 0
		2:
			# 안전지점_유예(0.45초 = 27프레임) 를 넘겨 체크포인트가 찍히게 둔다
			if _n == 50:
				print("  · 안전지점 후보 = %s" % str(_안전한_땅.round()))
				print("")
				print("── 3) 치명 낙하 (밑 없는 구덩이로) ────────────")
				# 구덩이(1180~1620) 한가운데 공중에 놓는다. 밑에 아무것도 없다.
				_p.global_position = Vector2(1400, 300)
				_p.velocity = Vector2.ZERO
				_최대위험도 = 0.0
				_단계 = 3
				_n = 0
		3:
			_최대위험도 = maxf(_최대위험도, float(_낙하.call("위험도")))
			if _n % 20 == 0:
				print("     [%3d] pos=%s  낙하거리=%.0f  위험도=%.2f  바닥=%s"
					% [_n, str(_p.global_position.round()), _낙하.call("낙하거리"),
						_낙하.call("위험도"), str(_p.call("is_on_floor"))])
			# 치명 거리 520px 를 넘겨 떨어지면 그 순간 리스폰된다.
			# 리스폰되면 x 가 구덩이(1400)에서 안전지점 쪽(400 근처)으로 확 돌아온다.
			if absf(_p.global_position.x - 1400.0) > 300.0:
				var 낙하거리 := _p.global_position.y - 300.0
				_확인(true, "치명 낙하로 리스폰됐다 (%d 프레임 = %.2f 초)" % [_n, _n / 60.0])
				_확인(_최대위험도 > 0.5,
					"죽기 전에 경고 비네트가 켜졌다 (최대 위험도 %.2f)" % _최대위험도)
				# 리스폰 지점이 "스테이지 처음(240, 600)" 이 아니라 마지막 안전지점이어야 한다
				var 기본시작: Vector2 = _루트.get("시작_위치")
				_확인(_p.global_position.distance_to(_안전한_땅) < 220.0,
					"마지막 안전지점 근처로 돌아왔다 (안전지점 %s / 실제 %s)"
					% [str(_안전한_땅.round()), str(_p.global_position.round())])
				_확인(_p.global_position.distance_to(기본시작) > 60.0
						or _안전한_땅.distance_to(기본시작) < 60.0,
					"스테이지 처음으로 되돌려지지 않았다")
				_확인(float(_낙하.call("낙하거리")) < 100.0,
					"리스폰 직후 낙하 상태가 초기화됐다 (낙하거리 %.0f)"
					% _낙하.call("낙하거리"))
				_단계 = 4
				_n = 0
				return
			if _n > 240:
				_확인(false, "4 초 안에 치명 낙하로 죽는다 (현재 y=%.0f · 위험도 %.2f)"
					% [_p.global_position.y, _최대위험도])
				_끝내기()
				return
		4:
			# 리스폰 직후 즉사 루프에 빠지지 않는지 — 1 초쯤 두고 본다
			if _n == 70:
				_확인(bool(_p.call("is_on_floor")) or _p.global_position.y < 1200.0,
					"리스폰 후 즉사 루프에 빠지지 않았다 (y=%.0f)" % _p.global_position.y)
				_끝내기()
				return


func _끝내기() -> void:
	print("")
	print("[test_낙하사망] 통과 %d / 실패 %d" % [_통과, _실패])
	quit(_실패)
