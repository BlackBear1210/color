extends SceneTree
## ============================================================================
## [2026-08-22 신규] 2층 방 SmartShape 전환 런타임 검증 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/test_2층방_스마트매쉬.gd
##
## ▣ 무엇을 확인하나 (도형님 지시: "색칠까지 잘 작동하고 사망 판정까지 확인")
##   실제 집_2층방.tscn 을 **트리에 올려 _ready 를 돌린 상태**로 검사한다:
##   1. 지형이 스마트지형(색 지님)으로 바뀌었나 (반대색인가/명중 메서드)
##   2. 페인트 셰이더가 흑↔백 짝으로 설치됐나 = **색칠 작동**의 증거
##   3. 콜리전이 구워졌고 레이어=1 인가 = 밟힘 + 사망 질의 대상
##   4. 구조물(벽돌)은 칠 거부·항상 안전 (결정: "구조물은 안전")
##   5. 발판(나무)은 색칠되면 반대색 플레이어에게 치명
##   6. **월드._사망_판정()** 실제 경로로 죽음/안전이 갈리는가
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 씬경로 := "res://scenes/집/집_2층방.tscn"

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool) -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름)
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 2층 방 SmartShape 검증 ===")
	var 팩: PackedScene = load(씬경로)
	var 씬: Node2D = 팩.instantiate()
	root.add_child(씬)                 # _ready 실행 → 스마트지형 색칠·콜리전 세팅
	# 물리 프레임을 몇 번 흘려 콜리전 베이크/딴짓이 정착하게 둔다.
	await process_frame
	await physics_frame
	await physics_frame
	# 월드가 스스로 사망→리스폰(순간이동)하면 우리가 세운 좌표가 날아간다 → 물리 끈다.
	씬.set_physics_process(false)

	var 지형층: Node = 씬.get_node("지형")
	var 발판: Node = 지형층.get_node("발판_A")     # 나무 · 칠 가능
	var 구조: Node = 지형층.get_node("1층바닥")     # 벽돌 · 구조물(안전)

	# ── 1. 타입 ──────────────────────────────────────────────────────────
	확인("발판_A 가 스마트지형(색 지님)", 발판.has_method("반대색인가") and 발판.has_method("명중"))
	확인("1층바닥 가 스마트지형", 구조.has_method("반대색인가"))

	# ── 2. 색칠 셰이더(흑↔백 짝) 설치 = 색칠 작동 증거 ──────────────────────
	# _셰이더_설치 가 white_ 짝을 못 찾으면 fill_mesh_material 이 null 로 남는다.
	var mat: SS2D_Material_Shape = 발판.shape_material
	확인("발판 채움 페인트 셰이더 설치됨", mat != null and mat.fill_mesh_material is ShaderMaterial)
	var 테두리셰이더 := false
	if mat != null:
		for 메타 in mat.get_all_edge_meta_materials():
			if 메타 and 메타.edge_material and 메타.edge_material.material is ShaderMaterial:
				테두리셰이더 = true
				break
	확인("발판 테두리 페인트 셰이더 설치됨", 테두리셰이더)

	# ── 3. 콜리전 베이크 + 레이어 ───────────────────────────────────────────
	var poly: CollisionPolygon2D = 발판.get_node("StaticBody2D/CollisionPolygon2D")
	var body: StaticBody2D = poly.get_parent()
	확인("발판 콜리전 폴리곤 채워짐", poly.polygon.size() >= 3)
	확인("발판 콜리전 레이어=1(밟힘·사망질의 대상)", body.collision_layer == 1)

	# ── 4. 구조물(벽돌) = 칠 거부 · 항상 안전 ───────────────────────────────
	var r: String = 구조.명중(ColorDefs.BLACK, 구조.global_position)
	확인("구조물 칠 거부(blocked)", r == "blocked")
	확인("구조물 무색 유지", int(구조.현재상태) == 지형_S.상태.무색)
	확인("구조물 흑·백 둘 다 안전",
		not 구조.반대색인가(ColorDefs.WHITE) and not 구조.반대색인가(ColorDefs.BLACK))

	# ── 5. 발판(나무) 색칠 → 색-치명 전이 ──────────────────────────────────
	확인("무색 발판은 안전",
		not 발판.반대색인가(ColorDefs.WHITE) and not 발판.반대색인가(ColorDefs.BLACK))
	var 필요: int = 발판.필요횟수()
	for i in 필요:
		발판.명중(ColorDefs.BLACK, 발판.global_position)   # 전체 색칠까지 검정으로 때린다
	확인("발판이 검정으로 전체 색칠됨", int(발판.현재상태) == 지형_S.상태.검정)
	확인("검정 발판 → 흰 플레이어 치명", 발판.반대색인가(ColorDefs.WHITE))
	확인("검정 발판 → 검정 플레이어 안전", not 발판.반대색인가(ColorDefs.BLACK))

	# ── 6. 월드._사망_판정() 실제 경로 ─────────────────────────────────────
	var player: Node2D = 씬.get_node("Player")
	# 발판 중심에 몸을 겹쳐 세운다(겹침 질의가 이 지형을 집게 만든다).
	player.global_position = 발판.global_position
	await physics_frame                       # 물리 서버가 새 위치를 반영하게 한 프레임
	player.set("player_color", ColorDefs.WHITE)
	확인("월드 판정: 검정발판+흰플레이어 = 죽는다", bool(씬._사망_판정()))
	player.set("player_color", ColorDefs.BLACK)
	확인("월드 판정: 검정발판+검정플레이어 = 안 죽는다", not bool(씬._사망_판정()))

	# 구조물 위에서는 어느 색이든 안전해야 한다.
	player.global_position = 구조.global_position
	await physics_frame
	player.set("player_color", ColorDefs.WHITE)
	확인("월드 판정: 벽돌 구조물 위 = 흰플레이어 안전", not bool(씬._사망_판정()))

	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	씬.queue_free()
	quit(1 if 실패 > 0 else 0)
