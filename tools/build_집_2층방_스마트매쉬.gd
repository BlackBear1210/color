extends SceneTree
## ============================================================================
## [2026-08-22 신규] 집 · 2층 방 — SmartShape 판 빌더 (일관 좌표로 재건)
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/build_집_2층방_스마트매쉬.gd
##
## ▣ 왜 다시 짓나 (도형님 제보)
##   "실행하자마자 땅에 떨어진다 · 시작지점이 딴 곳 · 배경이 짤려 보인다 · 카메라 문제."
##   원인 = 기존 집_2층방.tscn 의 지형 블록 좌표가 **흩어져** 있었다
##   (바닥 x≈3352 · 왼벽 x≈-3363 · 천장 x≈-2164 — 전부 카메라 리밋 -700~2400 바깥).
##   스폰(-150,-40) 아래에 바닥이 없어 즉시 낙하했고, 배경·리밋도 흩어진 지형과 안 맞았다.
##   → build_집_2층방.gd 의 **정상 좌표**(방 안에 모인 값)로 다시 세우되, 지형만
##     브릭구조(9-슬라이스) → **SmartShape(스마트지형)** 로 바꾼다. 스폰·낙사·카메라·배경이
##     한 번에 맞는다.
##
## ▣ 지형 배정 (도형님 결정: "구조물은 안전, 발판만 칠 가능")
##   구조물 {1층바닥,왼벽,천장,시작선반} → 지형_벽돌.tres · 칠하기_허용=false (무색 안전)
##   발판   {발판_A,발판_B,오름_1,오름_2} → 지형_나무.tres · 칠하기_허용=true  (색 퍼즐·사망)
##
## ▣ ★_ready 안 돌게 오프라인 조립 (스마트매쉬_2/3 과 동일)
##   루트를 활성 트리(get_root())에 넣지 않는다 → 스마트지형 _ready 의 재질 깊은복사 방지.
##
## ▣ 좌표·튜닝은 build_집_2층방.gd 와 **동일**(도형님 "현재값 보존"). 지형 종류만 바뀐다.
## ============================================================================
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 실내배경_S := preload("res://scripts/스마트월드/실내배경.gd")
const 스마트지형_S := preload("res://scripts/스마트월드/지형.gd")
const 통로_S := preload("res://scripts/스마트월드/연결통로.gd")
const 챕터_S := preload("res://scripts/스마트월드/챕터.gd")
const 공통 := preload("res://tools/지형공통.gd")
const PLAYER := "res://scenes/player/Player.tscn"
const 저장경로 := "res://scenes/집/집_2층방.tscn"

const 벽돌재질 := "res://assets/textures/smartshape/지형_벽돌.tres"
const 나무재질 := "res://assets/textures/smartshape/지형_나무.tres"

## 점프 튜닝 — build_집_2층방.gd 와 동일.
const 튜닝 := {"move_speed": 390.0, "타일_크기": 16.0, "점프_높이_칸": 10.0, "점프_거리_칸": 15.0}


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 집 · 2층 방 (SmartShape) 빌더 ===")
	var 루트 := _짓기()
	공통.주인_지정(루트, 루트)          # 인스턴스(Player) 내부는 건너뜀(§규약 6)
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("pack 실패: %s" % error_string(e)); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/집"))
	e = ResourceSaver.save(팩, 저장경로)
	print("   저장 %s → %s" % [error_string(e), 저장경로])
	quit(0 if e == OK else 1)


func _짓기() -> Node2D:
	# ── 방 범위 ── 카메라가 방 밖(벽 너머)을 안 비추게 리밋을 방에 맞춘다.
	var 리밋 := Rect2(-700, -700, 3100, 1900)      # x −700..2400 · y −700..1200
	var 시작 := Vector2(-150, -40)                 # 시작 선반(윗면 y=0) 바로 위

	var 루트: Node2D = 월드_S.new()
	루트.name = "집_2층방"
	루트.set("스테이지_이름", "2층 방")
	루트.set("카메라_줌", 0.82)
	루트.set("시작_위치", 시작)
	루트.set("낙사_y", 1500.0)
	루트.set("카메라_리밋", 리밋)

	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)

	var 배경: Node2D = 실내배경_S.new()
	배경.name = "실내배경"
	# 배경 영역은 카메라 리밋보다 넉넉히 크게 잡아 화면 가장자리가 비지 않게 한다(짤림 방지).
	배경.set("영역", Rect2(리밋.position - Vector2(600, 500), 리밋.size + Vector2(1200, 1000)))
	배경.set("아래_방", 실내배경_S.방_.이층방)
	배경.set("위_방", 실내배경_S.방_.이층방)
	배경.z_index = -60
	배경.z_as_relative = false
	루트.add_child(배경)

	var 팔: Dictionary = 챕터_S.팔레트(1)
	var 어둠 := CanvasModulate.new()
	어둠.name = "어둠"
	어둠.color = 팔["어둠"]
	루트.add_child(어둠)

	var 지형층 := Node2D.new()
	지형층.name = "지형"
	루트.add_child(지형층)

	var 오브젝트층 := Node2D.new()
	오브젝트층.name = "오브젝트"
	루트.add_child(오브젝트층)

	# ── 큰 바닥(윗면 y=640) ── 구조물=벽돌·안전. 출구(x2150)까지 덮어 가장자리 낙하 제거.
	_지형(지형층, "1층바닥", Vector2(830, 640 + 130), Vector2(2920, 260), 벽돌재질, false)
	# ── 방 외곽(왼벽·천장) ── 벽돌 무색 구조물.
	_지형(지형층, "왼벽", Vector2(-560, 300), Vector2(220, 1040), 벽돌재질, false)
	_지형(지형층, "천장", Vector2(700, -320), Vector2(2600, 200), 벽돌재질, false)
	# ── 시작 선반(윗면 y=0) ── 왼끝을 왼벽에 붙여 좌측 낙하 차단. 여기서 스폰한다.
	_지형(지형층, "시작선반", Vector2(-170, 60), Vector2(600, 120), 벽돌재질, false)
	# ── 내려가는 공중 발판 ── 나무·칠 가능(색 퍼즐·사망 판정). 낙차 ≤220(안 죽음).
	_지형(지형층, "발판_A", Vector2(320, 220 + 55), Vector2(380, 110), 나무재질, true)   # 윗면 220
	_지형(지형층, "발판_B", Vector2(820, 420 + 55), Vector2(380, 110), 나무재질, true)   # 윗면 420
	# ── 되돌아 오르는 계단(소프트락 방지) ── 나무·칠 가능. 단차 120.
	_지형(지형층, "오름_1", Vector2(1500, 520 + 45), Vector2(320, 90), 나무재질, true)   # 윗면 520
	_지형(지형층, "오름_2", Vector2(1900, 400 + 45), Vector2(320, 90), 나무재질, true)   # 윗면 400

	# ── 출구 통로 ── 1층 바닥 오른쪽 끝. 다음 스테이지(계단→1층)로 이어질 자리.
	var 출구: Node2D = 통로_S.new()
	출구.name = "출구통로"
	출구.position = Vector2(2150, 640)
	출구.set("역할", 통로_S.역할_.출구)
	출구.set("높이", 160.0)
	출구.set("속빛", Color(0.30, 0.31, 0.34))
	오브젝트층.add_child(출구)

	# ── 플레이어 ──
	var p := (load(PLAYER) as PackedScene).instantiate()
	p.name = "Player"
	(p as Node2D).position = 시작
	for k in 튜닝:
		p.set(k, 튜닝[k])
	루트.add_child(p)

	return 루트


## 중심·크기로 스마트지형 사각형 블록 하나. 오프라인 조립(트리에 안 넣는다).
func _지형(층: Node2D, 이름: String, 중심: Vector2, 크기: Vector2,
		재질경로: String, 칠가능: bool) -> void:
	var 지형: SS2D_Shape_Closed = 스마트지형_S.new()
	지형.name = 이름
	지형.position = 중심
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	지형.set("칠하기_허용", 칠가능)
	지형.set("무색일때_통과", false)

	var w := 크기.x * 0.5
	var h := 크기.y * 0.5
	# 시계방향(TL→TR→BR→BL) — 감김 방향이 섞이면 콜리전 볼록분해가 조용히 깨진다.
	var 점들 := PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h),
	])
	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()

	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	지형.collision_size = 24.0
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime

	var 생성기 := SS2D_CollisionGen.new()
	생성기.collision_size = 지형.collision_size
	생성기.collision_offset = 지형.collision_offset
	폴리.polygon = 생성기.generate_filled(지형.get_point_array().get_tessellated_points())

	층.add_child(지형)
