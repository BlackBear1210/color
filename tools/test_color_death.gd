extends SceneTree
## [2026-07-14 도형 · 신규] 색 사망 판정(규칙 v1.3) 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_color_death.gd
## 검증 시나리오:
##  1. zone_01: 흑 플레이어가 흰 발판을 밟으면 → 사망 → 스폰 복귀 + 스폰 색(흑) 복원
##  2. zone_02: 회색 발판은 흑 상태로 밟아도 안 죽음 (중립)
##  3. zone_02: 전환 존 안(회색 발판 위)에서 Shift → 백 전환 허용 + 회색 위라 안 죽음
##  4. zone_02: 백 상태로 흑 단상을 밟으면 → 사망 → 스폰 복귀 + 흑 복원
##  5. zone_02: 전환 존 밖에서 색을 바꾸면 → 즉시 되돌려짐 (잠금)

var n := 0
var fails := 0
var zone: Node
var player: Node

const SPAWN := Vector2(96, 445)

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _init() -> void:
	if not _대상_있나(["res://scenes/world_1/zone_01/zone_01.tscn", "res://scenes/world_1/zone_02/zone_02.tscn"]):
		print("[건너뜀] 폐기된 라인의 씬이 없다 — 커밋 df03f3d 참고")
		quit(0)
		return
	# [2026-07-18 도형] FAIL 2건(7/17 발견)의 진짜 원인 수정:
	# 이 테스트는 "프레임 번호"로 진행하는데, 사망 리스폰은 "실시간 0.55초" 타이머다.
	# 헤드리스가 60fps 보다 빨리 돌면(실측 ~145fps) 검사 프레임이 타이머보다 먼저 와서
	# 리스폰 전에 검사해 실패했다 — 게임 로직 회귀가 아니라 테스트의 시간 기준 문제.
	# → 프레임률을 60 으로 고정해 프레임 수 = 시간이 되도록 한다.
	Engine.max_fps = 60
	process_frame.connect(_tick)

func _load_zone(path: String) -> void:
	if zone:
		zone.queue_free()
	zone = (load(path) as PackedScene).instantiate()
	root.add_child(zone)
	player = zone.get_node("Player")

func _tick() -> void:
	n += 1
	match n:
		1:
			_load_zone("res://scenes/world_1/zone_01/zone_01.tscn")
		10:
			# 시나리오 1: 흑 상태로 흰 발판(셀 30~33, y12 → top y=384) 위에 올림
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(1008, 380))
		60:
			check("1) 흰 발판 밟은 흑 → 사망·스폰 복귀",
				player.global_position.distance_to(SPAWN) < 160.0)
			check("1) 사망 후 색 = 스폰 색(흑)", player.get("player_color") == 0)
			_load_zone("res://scenes/world_1/zone_02/zone_02.tscn")
		70:
			# 시나리오 2: 회색 발판(셀 13~16, y8 → top y=256) 위에 흑 상태로 올림
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(480, 250))
		110:
			check("2) 회색 발판 = 흑이 밟아도 생존 (중립)",
				absf(player.global_position.x - 480.0) < 60.0
				and absf(player.global_position.y - 256.0) < 12.0)
			# 시나리오 3: 회색 발판 = 전환 존 안 → Shift 전환 허용되어야 함
			player.call("_toggle_color")
		140:
			check("3) 전환 존 안 Shift → 백 전환 유지", player.get("player_color") == 1)
			check("3) 백 상태로 회색 위 → 생존", absf(player.global_position.y - 256.0) < 12.0)
			# 시나리오 4: 백 상태로 흑 단상1(셀 4~6, y11 → top y=352)을 밟게 이동
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(176, 346))
		190:
			# [2026-07-18] 판정 강화: 예전 기준(<160)은 텔레포트 지점(176,346)과 스폰의
			# 거리가 127 이라 "죽지 않아도 통과"하는 무의미한 검사였다 → <60 으로 조임.
			check("4) 흑 단상 밟은 백 → 사망·스폰 복귀",
				player.global_position.distance_to(SPAWN) < 60.0)
			check("4) 사망 후 색 = 스폰 색(흑)", player.get("player_color") == 0)
		225:
			# 시나리오 5: 스폰(전환 존 밖)에서 색을 바꾸면 잠금이 되돌려야 함
			# [2026-07-18] 프레임 200 → 225 로 이동: 시나리오 4 리스폰(~f180) 후
			# 무적(grace 0.6초=36프레임, ~f216)이 끝나기 전에 토글하면 잠금 감시가
			# (색 복원 오인 방지를 위해) 쉬는 중이라 잠금이 안 걸린다 — grace 이후로 조정.
			player.call("_toggle_color")
		255:
			check("5) 전환 존 밖 Shift → 잠금(흑으로 되돌아옴)", player.get("player_color") == 0)
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			# [2026-07-22 도형] 종료 전 로드했던 존을 동기 해제해 노드 누수를 줄인다.
			# ※ 남는 "ObjectDB instances leaked at exit" 경고는 노드가 아니라 프레임워크
			#   SceneTreeTimer 1개(강제 --quit 시점에 아직 안 끝난 대기 타이머)라 여기서
			#   잡을 수 없다 — 헤드리스 강제종료에서만 뜨는 무해한 경고(실게임 무관).
			if is_instance_valid(zone):
				zone.free()
			quit(1 if fails > 0 else 0)


## ============================================================================
## ⚠[2026-08-20] 이 검사는 **폐기된 라인**(zone_01 · zone_02)을 본다 — 스스로 건너뛴다.
##   커밋 `df03f3d 폐기 라인 정리` 에서 대상 씬이 삭제됐다.
##   빨간 검사를 상주시키면 팀이 "원래 하나는 실패해" 로 넘기기 시작하고,
##   그때부터 **진짜 실패도 안 보인다.** 파일은 남긴다(색 강제 시나리오가 참고 자료다).
##   ★스마트월드의 색 강제는 `test_빛창문` [G]·[H] 가 대신 지키고 있다.
## ============================================================================
func _대상_있나(경로들: Array) -> bool:
	for p in 경로들:
		if ResourceLoader.exists(String(p)):
			return true
	return false