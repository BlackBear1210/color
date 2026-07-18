extends SceneTree
## [2026-07-18 도형 · 신규] world_1 심리스 흐름 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_world_flow.gd
## 검증 시나리오:
##  1. 씬 구성: ProtoCamera / SwitchZone / ExitZone 이 조립되어 있다
##  2. 시작 구역 = 1 (zone1 규칙: 자유 전환)
##  3. 복도를 지나 x>1810 → 구역 2 전환 + 체크포인트가 회색 복도로 갱신
##  4. 구역 2 에서 전환 존 밖 Shift → 잠금(되돌려짐)
##  5. 카메라 리밋이 REGION_2 로 트윈 완료 (씬 교체 없는 바인식 전환의 실체)
##  6. 구역 2 에서 반대색(백) 발판을 밟으면 사망 → ★구역 2 체크포인트★ 리스폰
##     (기존처럼 존 처음(96,445)으로 끌려가지 않는다 = 심리스 유지)
##  7. 구역 1 로 되돌아가면 구역 1 규칙 복귀 (자유 전환)
##  8. 골인(ExitZone) 진입 → 월드 클리어 플래그

var n := 0
var fails := 0
var world: Node
var player: Node

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

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
			check("1) SwitchZone/ExitZone 존재",
				world.get_node_or_null("SwitchZone") != null
				and world.get_node_or_null("ExitZone") != null)
			check("2) 시작 구역 = 1", world.get("_region") == 1)
		10:
			# 복도(회색 바닥)를 지나 구역 경계(x=1750+60)를 넘는다
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(1830, 440))
		40:
			check("3) 경계 통과 → 구역 2", world.get("_region") == 2)
			check("3) 체크포인트 = 회색 복도(1800,445)",
				(world.get("_spawn_pos") as Vector2).distance_to(Vector2(1800, 445)) < 1.0)
			# 구역 2 + 전환 존 밖에서 Shift → 잠금이 되돌려야 함
			player.call("_toggle_color")
		55:
			check("4) 구역2 전환 존 밖 Shift → 잠금(흑 유지)", player.get("player_color") == 0)
		90:
			check("5) 카메라 리밋 = REGION_2 로 트윈 완료",
				(world.get_node("ProtoCamera").get("_limits") as Rect2).position
					.distance_to(Vector2(1600, -168)) < 1.0)
			# 구역 2 의 백 발판(셀 82~84, y6 → top y=192)을 흑 상태로 밟는다
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(2660, 186))
		160:
			check("6) 백 발판 밟은 흑 → 사망 → 구역2 체크포인트 리스폰",
				player.global_position.distance_to(Vector2(1800, 445)) < 60.0)
		170:
			# 구역 1 로 복귀
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(400, 440))
		200:
			check("7) 구역 1 복귀", world.get("_region") == 1)
			player.call("_toggle_color")   # 구역 1 은 자유 전환
		215:
			check("7) 구역1 Shift = 자유 전환(백 유지)", player.get("player_color") == 1)
			player.call("_toggle_color")   # 흑으로 원복
		225:
			# 골인 지점 (백 상층 위 공중) 으로 — ExitZone 통과
			player.set("velocity", Vector2.ZERO)
			player.set("global_position", Vector2(3280, 150))
		255:
			check("8) ExitZone 진입 → 월드 클리어", world.get("_cleared") == true)
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			quit(1 if fails > 0 else 0)
