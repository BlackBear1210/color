extends SceneTree
## ============================================================================
## stage_2-3 「관을 따라서」 — SS2D 배관과 호퍼의 첫 학습 스테이지
## ----------------------------------------------------------------------------
## 기능 배관 프리팹은 쓰지 않는다. 보이는 관은 모두 TEMPLATE_PIPE_OPEN_GRAY
## SS2D이며, 물의 출발·합류·색 섞임은 유체와 호퍼가 직접 담당한다.
##
## 회색 CEMENT 지형은 만들지 않는다. 회색은 물과 호퍼처럼 색 규칙 밖의 장치에만
## 쓰고, 실제로 밟는 SS2D 바닥은 검정으로 고정한다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const T_벽 := 키트 + "WALL_벽체/TEMPLATE_WALL_SOLID.tscn"
const T_시 := 키트 + "CEMENT_시멘트/TEMPLATE_CEMENT_SOLID.tscn"
const T_관 := 키트 + "PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn"
const S_유체 := "res://scenes/집/스마트월드_장애물/유체.tscn"
const S_호퍼 := "res://scenes/집/스마트월드_장애물/호퍼.tscn"
const S_플레이어 := "res://scenes/player/Player.tscn"

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 공통 := preload("res://tools/지형공통.gd")

const 내씬 := "res://scenes/world_2_클로드/stage_2-3.tscn"
const 검정 := 1
const 물_검 := 0
const 물_흰 := 1
const 물_회 := 2
const 바닥_윗 := 1100.0
const 바닥_아랫 := 1360.0


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 루트 := _짓기()
	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var 오류 := 팩.pack(루트)
	if 오류 == OK:
		오류 = ResourceSaver.save(팩, 내씬)
	print("stage_2-3.tscn: %s" % error_string(오류))
	quit(0 if 오류 == OK else 1)


func _짓기() -> Node2D:
	var 루트: Node2D = 월드_S.new()
	루트.name = "stage_2-3"
	루트.set("스테이지_이름", "2-3 · 관을 따라서")
	루트.set("카메라_리밋", Rect2(-124, -520, 8124, 2400))
	루트.set("카메라_줌", 1.0)
	루트.set("시작_위치", Vector2(470, 바닥_윗))
	루트.set("낙사_y", 1900.0)
	# 관문 4의 호퍼 다리는 최대 120px씩만 내려가므로 기본 낙사 규칙을 유지한다.
	루트.set("치명_낙하거리", 520.0)

	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)

	var 지형 := Node2D.new()
	지형.name = "지형"
	루트.add_child(지형)
	var 관 := Node2D.new()
	관.name = "SS2D 배관"
	루트.add_child(관)
	var 장치 := Node2D.new()
	장치.name = "장치"
	루트.add_child(장치)

	_지형들(지형)
	_장식배관들(관)
	_장치들(장치)

	var 끝 := Marker2D.new()
	끝.name = "끝도달_검사점"
	끝.position = Vector2(7480, 바닥_윗)
	루트.add_child(끝)

	var 플레이어 := (load(S_플레이어) as PackedScene).instantiate()
	플레이어.name = "Player"
	(플레이어 as Node2D).position = Vector2(470, 바닥_윗)
	루트.add_child(플레이어)
	return 루트


func _지형들(층: Node2D) -> void:
	# 바닥 조각은 경계선만 맞닿고 면적이 겹치지 않는다. 2-3의 안전한 주 경로는 검정이다.
	_지형(층, T_시, "SS_CEM_FLOOR_1A", _사각(300, 1100, 1240, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_1B", _사각(1380, 1100, 1900, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_2", _사각(1900, 1100, 3200, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_3", _사각(3200, 1100, 5000, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_4A", _사각(5200, 1100, 5500, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_4B", _사각(6100, 1100, 6300, 바닥_아랫), 검정)
	_지형(층, T_시, "SS_CEM_FLOOR_5", _사각(6300, 1100, 7600, 바닥_아랫), 검정)

	# 천장은 모두 같은 검정 구간이다. 관문 3의 높은 배관만 보이도록 중간 천장을 끊었다.
	_지형(층, T_벽, "SS_WALL_CEIL_1", _사각(300, 140, 1900, 300), 검정)
	_지형(층, T_벽, "SS_WALL_CEIL_2", _사각(1900, 140, 3200, 300), 검정)
	_지형(층, T_벽, "SS_WALL_MID_3", _사각(3200, -400, 5000, -240), 검정)
	_지형(층, T_벽, "SS_WALL_CEIL_4", _사각(5200, 140, 6300, 300), 검정)
	_지형(층, T_벽, "SS_WALL_CEIL_5", _사각(6300, -400, 7600, -240), 검정)
	_지형(층, T_벽, "SS_WALL_END_L", _사각(-124, 140, 300, 바닥_아랫), 검정)
	_지형(층, T_벽, "SS_WALL_END_R", _사각(7600, -400, 8000, 바닥_아랫), 검정)

	# 관문 3은 아래에서 물의 색을 보지 못하게 칸막이만 세운다. 칸막이도 SS2D이고 겹치지 않는다.
	_지형(층, T_벽, "SS_WALL_DIV_3A", _사각(3800, 140, 3920, 1100), 검정)
	_지형(층, T_벽, "SS_WALL_DIV_3B", _사각(4300, 140, 4420, 1100), 검정)


func _장식배관들(층: Node2D) -> void:
	# 기능 배관.tscn을 쓰지 않고, 경로만 가진 SS2D 관으로 흐름의 출처·합류를 읽게 한다.
	_관(층, "SS_PIPE_1A", Vector2(320, 300), Vector2(1310, 300))
	_관(층, "SS_PIPE_1B", Vector2(1310, 300), Vector2(1310, 540))
	_관(층, "SS_PIPE_2", Vector2(2550, 220), Vector2(2550, 644))
	_관(층, "SS_PIPE_3_BLACK", Vector2(3300, -260), Vector2(3600, -260))
	_관(층, "SS_PIPE_3_MIX_A", Vector2(3900, -260), Vector2(4100, -260))
	_관(층, "SS_PIPE_3_MIX_B", Vector2(4100, -260), Vector2(4100, -120))
	_관(층, "SS_PIPE_3_WHITE", Vector2(4700, -320), Vector2(4600, -320))
	_관(층, "SS_PIPE_5_MAIN", Vector2(6520, -160), Vector2(7000, -160))
	_관(층, "SS_PIPE_5_DROP", Vector2(7000, -160), Vector2(7000, -40))
	_관(층, "SS_PIPE_5_LEFT_DUMMY", Vector2(6740, -160), Vector2(6740, -40))
	_관(층, "SS_PIPE_5_RIGHT_DUMMY", Vector2(7300, -160), Vector2(7300, -40))


func _장치들(층: Node2D) -> void:
	# 관문 1: 길 옆 배수구로 흐르는 흰 물. 플레이어의 주 경로에는 닿지 않는다.
	_물(층, "F1_관문1", Vector2(1310, 540), Vector2(64, 260), 물_흰)

	# 관문 2: 한 색이 호퍼로 들어가 그대로 아래로 나온다. 출구는 바닥 바로 위에서 멈춘다.
	_물(층, "F2_H1_입구", Vector2(2550, 140), Vector2(64, 504), 물_흰)
	_호퍼(층, "H1_한색", Vector2(2550, 700), 120.0, 56.0, NodePath("../F3_H1_출구"), 96.0, 220.0)
	_물(층, "F3_H1_출구", Vector2(2550, 700), Vector2(96, 220), 물_흰, false)

	# 관문 3: H3만 검정+흰색을 함께 받아 회색을 낸다. 세 출구는 바닥 120px 위에서 멈춰
	# 아래층의 실제 통행을 막지 않으며, 관을 읽어 회색이 안전하다는 정보를 보여 준다.
	_물(층, "F4_H2_검정", Vector2(3600, -120), Vector2(64, 124), 물_검)
	_물(층, "F5_H3_검정", Vector2(4100, -120), Vector2(64, 124), 물_검)
	_물(층, "F6_H3_흰색", Vector2(4140, -120), Vector2(64, 124), 물_흰)
	_물(층, "F7_H4_흰색", Vector2(4600, -120), Vector2(64, 124), 물_흰)
	_호퍼(층, "H2_검정", Vector2(3600, 60), 120.0, 56.0, NodePath("../F8_H2_출구"))
	_호퍼(층, "H3_회색", Vector2(4100, 60), 120.0, 56.0, NodePath("../F9_H3_출구"))
	_호퍼(층, "H4_흰색", Vector2(4600, 60), 120.0, 56.0, NodePath("../F10_H4_출구"))
	_물(층, "F8_H2_출구", Vector2(3600, 60), Vector2(64, 720), 물_검, false)
	_물(층, "F9_H3_출구", Vector2(4100, 60), Vector2(64, 720), 물_회, false)
	_물(층, "F10_H4_출구", Vector2(4600, 60), Vector2(64, 720), 물_흰, false)

	# 관문 4: 회색 지형 대신 색 규칙 밖 호퍼 두 장을 전환 발판으로 쓴다.
	# 검정 플레이어는 H5의 검정 물을 지나고, H6 왼쪽에 착지해 흰색으로 바꾼 뒤 건넌다.
	_호퍼(층, "H5_검정물_발판", Vector2(5620, 1080), 160.0, 72.0)
	_호퍼(층, "H6_흰물_발판", Vector2(5900, 1080), 160.0, 72.0)
	_물(층, "F11_H5_검정", Vector2(5580, 140), Vector2(64, 868), 물_검)
	_물(층, "F12_H6_흰색", Vector2(5940, 140), Vector2(64, 868), 물_흰)

	# 관문 5: 물든 가운데 관이 정답임을 보여 준다. 양쪽 호퍼는 회색 장치 대기 발판이다.
	_호퍼(층, "H7_대기좌", Vector2(6740, 880), 160.0, 72.0)
	_호퍼(층, "H8_대기우", Vector2(7260, 880), 160.0, 72.0)
	_물(층, "F13_중앙흰물", Vector2(7000, -40), Vector2(64, 760), 물_흰)


func _물(층: Node2D, 이름: String, 위치: Vector2, 크기: Vector2, 색: int, 켜짐: bool = true) -> void:
	var 물 := (load(S_유체) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	물.name = 이름
	물.position = 위치
	물.set("크기", 크기)
	물.set("색", 색)
	물.set("켜짐", 켜짐)
	층.add_child(물)


func _호퍼(층: Node2D, 이름: String, 위치: Vector2, 폭: float, 높이: float,
		출구: NodePath = NodePath(), 물줄기폭: float = 64.0, 물줄기길이: float = -1.0) -> void:
	var 호퍼 := (load(S_호퍼) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	호퍼.name = 이름
	호퍼.position = 위치
	호퍼.set("폭", 폭)
	호퍼.set("높이", 높이)
	호퍼.set("자동_출구_연결", false)
	호퍼.set("출구_유체", 출구)
	# 호퍼에서 물 양을 조절하는 값은 출구 유체의 크기와 맞춰 저장한다.
	호퍼.set("출구_물줄기_폭", 물줄기폭)
	호퍼.set("출구_물줄기_길이", 물줄기길이)
	층.add_child(호퍼)


func _관(층: Node2D, 이름: String, 시작: Vector2, 끝: Vector2) -> void:
	var 관뿌리 := (load(T_관) as PackedScene).instantiate() as Node2D
	관뿌리.name = 이름
	관뿌리.position = Vector2.ZERO
	var 경로 := 관뿌리.get_node_or_null("경로") as Node2D
	if 경로 == null:
		push_error("2-3: SS2D 배관 경로를 찾지 못했다 — %s" % 이름)
		return
	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(PackedVector2Array([시작, 끝]))
	경로.set_point_array(점배열)
	층.add_child(관뿌리)


func _지형(층: Node2D, 템플릿: String, 이름: String, 점들: PackedVector2Array, 시작상태: int) -> void:
	var 인스턴스 := (load(템플릿) as PackedScene).instantiate() as Node2D
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
	모양.set("무색일때_통과", false)
	모양.set("시작상태", 시작상태)
	모양.set("위치별_판정", true)
	var 점배열 := SS2D_Point_Array.new()
	var 로컬 := PackedVector2Array()
	for 점 in 점들:
		로컬.append(점 - 중심)
	점배열.add_points(로컬)
	점배열.close_shape()
	모양.set_point_array(점배열)
	var 폴리 := 모양.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		var 생성기 := SS2D_CollisionGen.new()
		생성기.collision_size = 모양.collision_size
		생성기.collision_offset = 모양.collision_offset
		폴리.polygon = 생성기.generate_filled(점배열.get_tessellated_points())
	층.add_child(모양)


func _모양노드(인스턴스: Node2D) -> Node2D:
	if 인스턴스.has_method("get_point_array"):
		return 인스턴스
	for 자식 in 인스턴스.get_children():
		if 자식 is Node2D and 자식.has_method("get_point_array"):
			인스턴스.remove_child(자식)
			인스턴스.queue_free()
			return 자식 as Node2D
	push_error("2-3: Template 안에서 SS2D 지형 노드를 못 찾았다")
	return 인스턴스


func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])
