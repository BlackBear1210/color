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
			check("4) 흑 단상 밟은 백 → 사망·스폰 복귀",
				player.global_position.distance_to(SPAWN) < 160.0)
			check("4) 사망 후 색 = 스폰 색(흑)", player.get("player_color") == 0)
		200:
			# 시나리오 5: 스폰(전환 존 밖)에서 색을 바꾸면 잠금이 되돌려야 함
			player.call("_toggle_color")
		230:
			check("5) 전환 존 밖 Shift → 잠금(흑으로 되돌아옴)", player.get("player_color") == 0)
			print("---")
			print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
			quit(1 if fails > 0 else 0)
