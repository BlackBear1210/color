extends SceneTree
## ============================================================================
## `스테이지_1_2층방` 전용 SS2D 연결 페인트 통합 검사
## ----------------------------------------------------------------------------
## 이 기능은 공용 총알·지형을 바꾸지 않는다. 2층방에만 붙은 관리자가 실제 BRICK과
## WOOD의 접촉 그래프를 만들고, 접점에서 멀리 시작한 실제 시드도 같은 월드 좌표로
## 공유하는지 확인한다. 공중에 떨어진 SS2D에는 건너뛰지 않아야 한다.
## ============================================================================

const 이층방씬 := preload("res://scenes/집/스테이지_1_2층방.tscn")

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 방 := 이층방씬.instantiate() as Node2D
	root.add_child(방)
	await process_frame

	var 벽돌 := 방.get_node("지형/바닥_STAGE1_BRICK_01") as Node2D
	var 나무 := 방.get_node("지형/SS_WOOD_BED_DESK_01") as Node2D
	var 공중나무 := 방.get_node("지형/SS_WOOD_SHELF_A_01") as Node2D
	var 관리자 := 방.get_node_or_null("2층방_연결페인트")
	확인("2층방에만 연결 페인트 관리자가 있다", 관리자 != null, true)
	확인("실제 BRICK 바닥과 WOOD 침대·책상은 같은 접촉면이다",
		관리자.call("같은_연결면인가", 벽돌, 나무) if 관리자 else false, true)
	확인("공중에 떨어진 WOOD 선반은 바닥 연결면이 아니다",
		관리자.call("같은_연결면인가", 벽돌, 공중나무) if 관리자 else true, false)
	확인("매우 큰 BRICK 바닥은 10발로 완성할 수 없다", int(벽돌.call("필요횟수")) > 10, true)
	확인("큰 WOOD 침대·책상은 임시 탄창 범위 6~10발 안이다",
		int(나무.call("필요횟수")) >= 6 and int(나무.call("필요횟수")) <= 10, true)
	확인("BRICK 바닥의 보수적 필요 발수는 68발", 벽돌.call("필요횟수"), 68)
	확인("WOOD 침대·책상의 보수적 필요 발수는 7발", 나무.call("필요횟수"), 7)

	# 서로 크기가 크게 다른 두 지형에 한 발씩 쏜 뒤, 월드에서 보이는 원 면적이
	# 모두 기준의 80~120% 안인지 확인한다.
	var 벽돌한발 := 벽돌.to_global(Vector2(-2000.0, -60.0))
	var 나무한발 := 나무.to_global(Vector2(300.0, -20.0))
	벽돌.call("명중", ColorDefs.WHITE, 벽돌한발)
	나무.call("명중", ColorDefs.WHITE, 나무한발)
	관리자.call("즉시_갱신")
	var 기준면적 := PI * 160.0 * 160.0
	var 벽돌면적 := _첫시드_월드면적(벽돌)
	var 나무면적 := _첫시드_월드면적(나무)
	확인("BRICK 한 발 면적은 기준의 -20%~+20%",
		벽돌면적 >= 기준면적 * 0.8 - 1.0 and 벽돌면적 <= 기준면적 * 1.2 + 1.0, true)
	확인("WOOD 한 발 면적은 기준의 -20%~+20%",
		나무면적 >= 기준면적 * 0.8 - 1.0 and 나무면적 <= 기준면적 * 1.2 + 1.0, true)
	벽돌.call("강제_초기화")
	나무.call("강제_초기화")

	# 나무 접점에서 멀리 떨어진 벽돌 왼쪽을 완성한다. 기존 명중 순간 46px 방식이
	# 아니라, 나중에 커진 완료 전선 자체가 나무로 넘어가는지를 확인하기 위해서다.
	var 먼명중점 := 벽돌.to_global(Vector2(-2000.0, -60.0))
	for i in int(벽돌.call("필요횟수")):
		벽돌.call("명중", ColorDefs.WHITE, 먼명중점)
	벽돌.call("_process", 0.3)
	관리자.call("즉시_갱신")

	var 나무재질들: Array = 나무.get("_셰이더들")
	var 나무재질 := 나무재질들[0] as ShaderMaterial if not 나무재질들.is_empty() else null
	확인("접점 밖에서 시작한 벽돌 전선도 나무 셰이더에 전달된다",
		int(나무재질.get_shader_parameter("seed_count")) if 나무재질 else 0, 1)
	확인("2층방의 큰 반지름 비례 뾰족함은 꺼져 있다",
		float(나무재질.get_shader_parameter("blob_wobble")) if 나무재질 else -1.0, 0.0)
	if 나무재질:
		var 나무시드: PackedVector2Array = 나무재질.get_shader_parameter("seeds")
		var 벽돌시드: PackedVector2Array = 벽돌.get("_시드")
		var 나무쪽월드 := 나무.to_global(나무시드[0])
		var 벽돌쪽월드 := 벽돌.to_global(벽돌시드[0])
		확인("두 재질이 같은 월드 중심의 전선을 사용한다",
			나무쪽월드.distance_to(벽돌쪽월드) < 0.1, true)

	var 공중재질들: Array = 공중나무.get("_셰이더들")
	var 공중재질 := 공중재질들[0] as ShaderMaterial if not 공중재질들.is_empty() else null
	확인("벽돌 물감이 공중 WOOD 선반으로 건너뛰지 않는다",
		int(공중재질.get_shader_parameter("seed_count")) if 공중재질 else -1, 0)

	print("\n[test_SS2D_경계번짐] 통과 %d / 실패 %d" % [통과, 실패])
	방.queue_free()
	await process_frame
	quit(1 if 실패 > 0 else 0)


func 확인(이름: String, 실제, 기대) -> void:
	if 실제 == 기대:
		통과 += 1
		print("  ✔ %s" % 이름)
	else:
		실패 += 1
		print("  ✘ %s — 기대 %s, 실제 %s" % [이름, str(기대), str(실제)])


func _첫시드_월드면적(지형: Node2D) -> float:
	var 시드들: PackedVector2Array = 지형.get("_시드")
	var 목표들: PackedFloat32Array = 지형.get("_목표")
	if 시드들.is_empty() or 목표들.is_empty():
		return 0.0
	var 중심 := 지형.to_global(시드들[0])
	var 끝x := 지형.to_global(시드들[0] + Vector2(목표들[0], 0.0))
	var 끝y := 지형.to_global(시드들[0] + Vector2(0.0, 목표들[0]))
	var 월드반지름 := maxf(중심.distance_to(끝x), 중심.distance_to(끝y))
	return PI * 월드반지름 * 월드반지름
