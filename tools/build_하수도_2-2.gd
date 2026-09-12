extends SceneTree
## ============================================================================
## [2026-09-05 신규] stage_2-2 「구멍 난 바닥」 — 통과 플랫폼 수직 갱도
## ----------------------------------------------------------------------------
## 설계: scenes/world_2_클로드/설계도_하수도_2-1_2-3.html의 2-2 관문 1~5.
##
## 이 빌더는 SS2D 지형만 굽는다. 기능 배관 프리팹은 참조·인스턴스하지 않는다.
## 2-2는 물과 통과 플랫폼의 차이를 배우는 맵이므로 기능 배관은 다음 맵 2-3에서 쓴다.
## ★ SS2D끼리 면적을 겹치지 않는다. 경계가 이어져도 모서리만 맞대며,
##   2-1의 겹침 보정은 쓰지 않는다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const T_벽_검 := 키트 + "WALL_벽체/TEMPLATE_WALL_SOLID.tscn"
const T_벽_흰 := 키트 + "WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn"
const T_시_검 := 키트 + "CEMENT_시멘트/TEMPLATE_CEMENT_SOLID.tscn"
const T_시_흰 := 키트 + "CEMENT_시멘트/TEMPLATE_CEMENT_SOLID_WHITE.tscn"
const S_유체 := "res://scenes/집/스마트월드_장애물/유체.tscn"
const S_통과 := "res://scenes/집/스마트월드_장애물/통과플랫폼.tscn"
const S_플레이어 := "res://scenes/player/Player.tscn"
const 내씬 := "res://scenes/world_2_클로드/stage_2-2.tscn"

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 공통 := preload("res://tools/지형공통.gd")
const 카메라공간배치_S := preload("res://scripts/스마트월드/카메라공간배치.gd")
const 압력버튼_S := preload("res://scripts/스마트월드/압력버튼.gd")

## 지형.gd 상태 enum { 무색=0, 검정=1, 흰색=2, 회색=3 }
const 무색 := 0
const 검정 := 1
const 흰색 := 2
## 유체.gd 물색 enum { 검정색=0, 흰색=1, 회색=2 }
const 물_검 := 0
const 물_흰 := 1


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 루트 := _짓기()
	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var 오류 := 팩.pack(루트)
	if 오류 == OK:
		오류 = ResourceSaver.save(팩, 내씬)
	print("stage_2-2.tscn: %s" % error_string(오류))
	quit(0 if 오류 == OK else 1)


func _짓기() -> Node2D:
	var 루트: Node2D = 월드_S.new()
	루트.name = "stage_2-2"
	루트.set("스테이지_이름", "2-2 · 구멍 난 바닥")
	루트.set("시작_위치", Vector2(480, 1100))
	루트.set("낙사_y", 1620.0)
	루트.set("치명_낙하거리", 520.0)
	루트.set("카메라_리밋", Rect2(-124, -960, 4824, 2680))
	루트.set("카메라_줌", 1.0)
	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)
	var 지형 := Node2D.new()
	지형.name = "지형"
	루트.add_child(지형)
	var 장치 := Node2D.new()
	장치.name = "장치"
	루트.add_child(장치)
	var 위험물 := Node2D.new()
	위험물.name = "위험물"
	루트.add_child(위험물)
	var 오브젝트 := Node2D.new()
	오브젝트.name = "오브젝트"
	루트.add_child(오브젝트)
	_지형들(지형)
	_통과플랫폼들(장치)
	_입구압력버튼(장치)
	_물줄기들(위험물)
	# 벽 콜리전 범위에서 계산하므로 갱도 크기를 바꿔도 카메라 영역이 누적되지 않는다.
	카메라공간배치_S.깔기(루트)
	var 플레이어 := (load(S_플레이어) as PackedScene).instantiate()
	플레이어.name = "Player"
	(플레이어 as Node2D).position = Vector2(480, 1100)
	루트.add_child(플레이어)
	return 루트


func _지형들(층: Node2D) -> void:
	# 관문 1: 구덩이는 비워 두고, 검정 출발지와 흰색 착지를 SS2D로 분리한다.
	# 지형에 회색 상태를 쓰지 않는다. 시작 플레이어의 기본색(검정)과 벽·천장을
	# 맞춰, 첫 화면에서 반대색 구조물에 스쳐 죽는 함정을 없앤다.
	_지형(층, T_벽_검, "SS_WALL_END_L2", _사각(-124, 140, 300, 1360), 검정)
	_지형(층, T_벽_검, "SS_WALL_CEIL_1", _사각(300, -20, 1700, 140), 검정)
	_지형(층, T_시_검, "SS_CEM_START_1", _사각(300, 1100, 860, 1360), 검정)
	# LAND_1 오른쪽 196px은 승강 발판이 내려갈 입구로 비운다. 바닥을 남겨 두면
	# 발판이 지형 안으로 들어가 플레이어를 벽에 끼우므로, 씬과 빌더 모두 같은 구멍을 쓴다.
	_지형(층, T_시_흰, "SS_CEM_LAND_1", _사각(1400, 1100, 1504, 1360), 흰색)
	_지형(층, T_시_검, "SS_CEM_GHOST_1", _사각(900, 980, 1100, 1100), 무색, true)
	# 관문 2·3: 640px 갱도. 좌·우 벽은 서로 떨어져 있어 SS2D 면적 겹침이 없다.
	# 아래/위 벽을 색 전환 턱(440)에서 나눠, 검정 상승과 흰색 상승 모두에서
	# 몸통이 반대색 벽에 닿아 죽지 않게 한다. 네 조각은 경계선만 공유한다.
	_지형(층, T_벽_검, "갱도아래벽_좌", _사각(1700, 440, 2124, 1360), 검정)
	_지형(층, T_벽_검, "갱도아래벽_우", _사각(2764, 440, 3188, 1360), 검정)
	_지형(층, T_벽_흰, "갱도위벽_좌", _사각(1700, -160, 2124, 440), 흰색)
	_지형(층, T_벽_흰, "갱도위벽_우", _사각(2764, -160, 3188, 440), 흰색)
	# 승강 발판이 왼쪽 벽 아래를 지난 뒤 위로 올라오는 출구(2124~2360)다.
	# 나머지 바닥은 그대로 두어 관문 2의 출발면과 색 규칙은 유지한다.
	_지형(층, T_시_검, "SS_CEM_SHAFT_BOT", _사각(2360, 1100, 2764, 1360), 검정)
	_지형(층, T_시_검, "SS_CEM_LEDGE_2", _사각(2124, 320, 2424, 440), 검정)
	_지형(층, T_시_검, "SS_CEM_LEDGE_3", _사각(2124, 60, 2364, 180), 검정)
	# 관문 4: 아래는 갱도로 되돌아가는 열린 구멍이며 다리는 유령 SS2D 세 장이다.
	_지형(층, T_벽_검, "SS_WALL_CEIL_4", _사각(3190, -300, 4300, -140), 검정)
	_지형(층, T_시_검, "SS_CEM_IN_4", _사각(3190, 320, 3390, 440), 검정)
	_지형(층, T_시_흰, "SS_CEM_OUT_4", _사각(4090, 320, 4300, 440), 흰색)
	var 다리이름 := ["A", "B", "C"]
	for i in range(다리이름.size()):
		var x: float = 3430.0 + float(i) * 240.0
		_지형(층, T_시_검, "SS_CEM_BR_4%s" % 다리이름[i], _사각(x, 200, x + 180, 320), 무색, true)
	# 관문 5: 두 천장 구멍은 물 색과 탄약 잔량에 따라 양쪽 모두 출구가 된다.
	_지형(층, T_벽_흰, "SS_WALL_TOP_L", _사각(2124, -700, 2464, -160), 흰색)
	_지형(층, T_벽_흰, "SS_WALL_TOP_R", _사각(2660, -700, 3188, -160), 흰색)
	# 관문 3 착지와 관문 5 바닥을 한 장으로 합친다. 두 SS2D 바닥을 포개지 않아도
	# 같은 흰색 평지가 두 관문의 역할을 모두 한다.
	_지형(층, T_시_흰, "SS_CEM_TOP_5", _사각(2124, -160, 2764, -40), 흰색)


func _통과플랫폼들(층: Node2D) -> void:
	# 아래 7장은 검정일 때 무탄약 상승, 위 3장은 흰색 2발씩의 비용을 가르친다.
	for i in 7:
		_통과(층, "통과플랫폼_2_%02d" % (i + 1), Vector2(2290 if i % 2 == 0 else 2600, 990 - i * 110))
	for i in 3:
		_통과(층, "통과플랫폼_3_%02d" % (i + 1), Vector2(2600 if i % 2 == 0 else 2290, 210 - i * 110))
	_통과(층, "통과플랫폼_1", Vector2(1230, 990))
	_통과(층, "통과플랫폼_4A", Vector2(3550, 20))
	_통과(층, "통과플랫폼_4B", Vector2(3900, 20))
	_통과(층, "통과플랫폼_5", Vector2(2560, -300))


func _통과(층: Node2D, 이름: String, 위치: Vector2) -> void:
	var 발판 := (load(S_통과) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	발판.name = 이름
	(발판 as Node2D).position = 위치
	# 원본의 200px 기본값 대신 설계도 고정값 224×26·2발을 명시한다.
	발판.set("크기", Vector2(224, 26))
	발판.set("필요횟수", 2)
	층.add_child(발판)


## LAND_1 위 버튼을 밟으면 왼쪽 갱도벽이 아래로 내려가, 관문 2의 검정 발판까지
## 실제 걸어서 갈 수 있는 틈이 열린다. 대상 경로와 이동량은 인스펙터에서도 바꿀 수 있다.
func _입구압력버튼(층: Node2D) -> void:
	var 버튼: Node2D = 압력버튼_S.new()
	버튼.name = "입구압력버튼"
	버튼.position = Vector2(1452, 1100)
	버튼.set("폭", 88.0)
	버튼.set("높이", 24.0)
	# 버튼에서 내려야 통로로 갈 수 있으므로, 2-2는 첫 압력 뒤 열린 상태를 유지한다.
	버튼.set("작동방식", 1)
	버튼.set("대상들", [NodePath("../../지형/갱도아래벽_좌")])
	# 벽 상단이 플레이어 발 높이 아래로 내려가도록 800px 내린다.
	버튼.set("대상_이동량들", [Vector2(0, 800)])
	버튼.set("이동속도", 360.0)
	층.add_child(버튼)


func _물줄기들(층: Node2D) -> void:
	_물(층, "F1", Vector2(1100, 140), 840, 물_검)
	_물(층, "F2", Vector2(1342, 140), 850, 물_검)
	_물(층, "F3", Vector2(2700, 300), 800, 물_검)
	_물(층, "F4", Vector2(2258, -160), 540, 물_흰)
	_물(층, "F5", Vector2(3520, -140), 340, 물_흰)
	_물(층, "F6", Vector2(4000, -140), 340, 물_흰)
	_물(층, "F7", Vector2(2464, -700), 400, 물_흰)
	_물(층, "F8", Vector2(2628, -700), 290, 물_검)


func _물(층: Node2D, 이름: String, 위치: Vector2, 높이: float, 색: int) -> void:
	var 물 := (load(S_유체) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	물.name = 이름
	(물 as Node2D).position = 위치
	물.set("색", 색)
	물.set("크기", Vector2(64, 높이))
	물.set("켜짐", true)
	층.add_child(물)


func _지형(층: Node2D, 템플릿: String, 이름: String, 점들: PackedVector2Array, 시작색: int, 유령: bool = false) -> void:
	var 인스턴스: Node2D = (load(템플릿) as PackedScene).instantiate()
	var 모양 := _모양노드(인스턴스)
	모양.name = 이름
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for 점 in 점들:
		최소 = 최소.min(점)
		최대 = 최대.max(점)
	var 중심 := (최소 + 최대) * 0.5
	모양.position = 중심
	모양.set("칠하기_허용", true)
	모양.set("시작상태", 시작색)
	모양.set("무색일때_통과", 유령)
	모양.set("위치별_판정", true)
	var 배열 := SS2D_Point_Array.new()
	var 로컬 := PackedVector2Array()
	for 점 in 점들:
		로컬.append(점 - 중심)
	배열.add_points(로컬)
	배열.close_shape()
	모양.set_point_array(배열)
	var 폴리 := 모양.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		var 생성기 := SS2D_CollisionGen.new()
		생성기.collision_size = 모양.collision_size
		생성기.collision_offset = 모양.collision_offset
		폴리.polygon = 생성기.generate_filled(배열.get_tessellated_points())
	층.add_child(모양)


func _모양노드(인스턴스: Node2D) -> Node2D:
	if 인스턴스.has_method("get_point_array"):
		return 인스턴스
	for 자식 in 인스턴스.get_children():
		if 자식 is Node2D and 자식.has_method("get_point_array"):
			인스턴스.remove_child(자식)
			# 새 Template 인스턴스의 소유자만 비운다. 껍데기 없이 SS2D만 저장할 때
			# 이전 껍데기 owner가 남으면 pack()이 노드를 누락시킬 수 있기 때문이다.
			자식.owner = null
			인스턴스.queue_free()
			return 자식
	push_error("2-2: Template 안에서 SS2D 노드를 못 찾았다")
	return 인스턴스


func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
