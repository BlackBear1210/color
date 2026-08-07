extends SceneTree
## [2026-07-19 도형 · v2 재작성] world_1 심리스 흐름 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_world_flow.gd
##
## v2: zone2 가 SwitchZone(수동 전환 잠금) → ColorZone(자동 색 강제 구역)으로
## 재구축되고 zone3(수직 도시)가 추가되어 시나리오를 전면 갱신했다.
## ⚠ 구역 안으로 순간이동할 때는 반드시 "공중" 좌표로 넣는다 — 발 딛는 순간보다
##   먼저 ColorZone 이 공중에서 색을 교정해야 색 사망 판정과 경합하지 않는다
##   (실제 플레이도 항상 점프/낙하 중에 경계를 넘으므로 같은 조건).
##
## 검증 시나리오:
##  1. 씬 구성: ProtoCamera / ExitZone / ColorZone 6개, SwitchZone 은 없다(폐기)
##  2. 시작 구역 = 1 (자유 전환)
##  3. 복도 → 구역 2 전환 + 체크포인트 = 회색 복도
##  4. 복도(구역 밖) Shift = 자유 전환 유지
##  5. zone2 흑 구역(경계 아래)에 들어가면 백이어도 자동으로 흑
##  6. zone2 백 구역(경계 위) 상층에 착지 → 자동 백 + 사망 없음
##  7. 카메라 리밋이 REGION 2 로 트윈 완료
##  8. 다리 → 구역 3 전환 + 체크포인트 = 다리(회색)
##  9. zone3 밴드 A(흑) → 자동 흑
## 10. zone3 밴드 B(백) → 자동 백
## 11. zone3 밴드 C(흑) 회색 발판 → 자동 흑 + 구역 안 수동 토글은 즉시 되돌려짐
## 12. 카메라 리밋이 REGION 3 로 트윈 완료
## 13. 구역 1 복귀 → 자유 전환 복귀
## 14. 옥상 ExitZone 진입 → 월드 클리어

var n := 0
var fails := 0
var world: Node
var player: Node

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

## 순간이동 헬퍼 — 속도를 0 으로 리셋해 이전 시나리오의 낙하 관성을 끊는다
func warp(pos: Vector2) -> void:
	player.set("velocity", Vector2.ZERO)
	player.set("global_position", pos)

func _init() -> void:
	Engine.max_fps = 60   # 프레임 수 = 시간 이 되도록 고정 (test_color_death 와 동일 이유)
	process_frame.connect(_tick)

func _tick() -> void:
	n += 1
	match n:
		1:
			world = (load("res://scenes/world_1/world_1.tscn") as PackedScene).instantiate()
			root.add_child(world)
			player = world.get_node("Player")
		5:
			check("1) ProtoCamera 조립됨", world.get_node_or_null("ProtoCamera") != null)
			check("1) ExitZone 존재 / SwitchZone 폐기됨",
				world.get_node_or_null("ExitZone") != null
				and world.get_node_or_null("SwitchZone") == null)
			var zones := 0
			for c in world.get_children():
				if c is Area2D and c.get("zone_color") != null:
					zones += 1
			check("1) ColorZone 6개 (zone2 2개 + zone3 밴드 4개)", zones == 6)
			check("2) 시작 구역 = 1", world.get("_region") == 1)
		10:
			warp(Vector2(1830, 440))            # 회색 복도 (구역 경계 1650+60 너머)
		30:
			check("3) 경계 통과 → 구역 2", world.get("_region") == 2)
			check("3) 체크포인트 = 회색 복도(1800,445)",
				(world.get("_spawn_pos") as Vector2).distance_to(Vector2(1800, 445)) < 1.0)
			player.call("_toggle_color")        # 복도 = ColorZone 밖 → 자유 전환
		42:
			check("4) 복도(구역 밖) Shift = 자유 전환(백 유지)", player.get("player_color") == 1)
		45:
			warp(Vector2(2400, 330))            # zone2 흑 구역 공중 (백 상태로 진입)
		80:
			check("5) 흑 구역 진입 → 자동 흑", player.get("player_color") == 0)
			# ★[2026-08-07 도형] 판정을 **좌표 일치**에서 **의도(생존)** 로 바꿨다.
			#   원래는 (2400, 445) 근처인지를 봤는데, 신우님이 Player.tscn 의 콜리전을
			#   키 47px → 97px 로 키우면서 착지 y 가 445 → 289 로 바뀌어 실패했다.
			#   그런데 이 검사의 **목적은 "죽어서 리스폰됐는가"** 지 "몇 px 에 섰는가" 가 아니다.
			#   좌표를 박아 두면 캐릭터를 손볼 때마다 멀쩡한 테스트가 깨진다.
			#   → 리스폰됐는지만 본다: 리스폰되면 체크포인트(1800, 445)로 끌려간다.
			var 체크포인트: Vector2 = world.get("_spawn_pos")
			var 리스폰됨: bool = player.global_position.distance_to(체크포인트) < 80.0
			print("      · 착지 %s / 체크포인트 %s"
				% [str(player.global_position.round()), str(체크포인트.round())])
			check("5) 흑 구역 바닥 착지 = 생존(리스폰 안 됨)",
				not 리스폰됨 and bool(player.call("is_on_floor")))
		85:
			warp(Vector2(3200, 120))            # zone2 백 상층 위 공중 (흑 상태로 진입)
		120:
			check("6) 백 구역 진입 → 자동 백", player.get("player_color") == 1)
			# 위와 같은 이유로 좌표가 아니라 "리스폰 안 됨 + 땅에 서 있음" 으로 본다
			var 체크포인트2: Vector2 = world.get("_spawn_pos")
			check("6) 백 상층 착지 = 생존(리스폰 안 됨)",
				player.global_position.distance_to(체크포인트2) >= 80.0
				and bool(player.call("is_on_floor")))
			check("7) 카메라 리밋 = REGION 2 트윈 완료",
				(world.get_node("ProtoCamera").get("_limits") as Rect2).position
					.distance_to(Vector2(1600, -168)) < 1.0)
		125:
			warp(Vector2(3700, 168))            # 다리 (회색, 탑 내부 = 밴드 A 범위)
		155:
			check("8) 다리 통과 → 구역 3", world.get("_region") == 3)
			check("8) 체크포인트 = 다리(3400,189)",
				(world.get("_spawn_pos") as Vector2).distance_to(Vector2(3400, 189)) < 1.0)
		160:
			warp(Vector2(4000, 380))            # 밴드 A(흑) 공중 → 판자촌 바닥
		190:
			check("9) 밴드 A(흑) → 자동 흑", player.get("player_color") == 0)
		195:
			warp(Vector2(4176, -220))           # 밴드 B(백) 공중 → B3 백 발판
		225:
			check("10) 밴드 B(백) → 자동 백", player.get("player_color") == 1)
		230:
			warp(Vector2(3728, -404))           # 밴드 C(흑) 공중 → G2 회색 발판
		260:
			check("11) 밴드 C(흑) → 자동 흑", player.get("player_color") == 0)
			player.call("_toggle_color")        # 구역 안 수동 토글 시도
		268:
			check("11) 구역 안 토글 → 즉시 되돌려짐(흑 유지·생존)",
				player.get("player_color") == 0
				and player.global_position.distance_to(Vector2(3728, -355)) < 60.0)
			check("12) 카메라 리밋 = REGION 3 트윈 완료",
				(world.get_node("ProtoCamera").get("_limits") as Rect2).position
					.distance_to(Vector2(3520, -1080)) < 1.0)
		275:
			warp(Vector2(400, 440))             # 구역 1 복귀
		300:
			check("13) 구역 1 복귀", world.get("_region") == 1)
			player.call("_toggle_color")        # 구역 1 은 자유 전환
		310:
			check("13) 구역1 Shift = 자유 전환(백 유지)", player.get("player_color") == 1)
		315:
			warp(Vector2(4330, -930))           # zone3 옥상 골인 지점
		350:
			check("14) ExitZone 진입 → 월드 클리어", world.get("_cleared") == true)
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			# [2026-07-22 도형] 종료 전 월드 노드 동기 해제로 노드 누수를 줄인다.
			# ※ 남는 leaked 경고는 프레임워크 SceneTreeTimer(월드 클리어의 1.6초 대기 등
			#   강제 --quit 시점에 안 끝난 타이머)라 노드 해제로는 못 잡는다 — 무해(실게임 무관).
			if is_instance_valid(world):
				world.free()
			quit(1 if fails > 0 else 0)
