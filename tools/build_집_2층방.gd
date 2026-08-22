extends SceneTree
## ============================================================================
## [2026-08-22 신규] 집 챕터 1스테이지 — "2층 방" 원본 씬 빌더
## ----------------------------------------------------------------------------
## ▣ 도형님 기획(그대로)
##   "1스테이지는 집에서 시작. 집 안 2층 방에서 시작해 아래 1층까지 내려가는 구성.
##    플랫포머 느낌의 2D 점프맵. 지형은 테두리 벽돌 + 안쪽 검정(브릭 9-슬라이스).
##    하나의 큰 바닥을 먼저 깔고, 중간중간 공중 플랫폼을 얹는다."
##   이 씬은 그 흐름의 **첫 장 = 2층 방**이다(다음: 2층 복도 → 1층 계단 → 굴뚝…).
##
## ▣ 지형 = `브릭구조`(9-슬라이스 블록, 무색 구조물 = 누구나 안전).
##   색 퍼즐(칠해야 밟는 발판)은 나중에 이 뼈대 위에 얹는다 — 지금은 통행 뼈대만.
##
## ▣ 레벨 안전 수치(보존 — 도형님 "현재값 그대로"):
##   튜닝 = build_원본_집.gd 와 동일(점프 높이 160 · 거리 240 · move 390 · 타일 16).
##   올라가는 단차 ≤ 120px · 가로 간격 ≤ 200px · 머리 여유 ≥ 103px · 치명 낙하 520px.
##   내려가는 낙차는 520 미만이면 안 죽는다. 검증: `tools/레벨검사.gd`.
##
## ▣ 실행:  godot --headless --path . -s res://tools/build_집_2층방.gd
##   (재생성 도구 — CLAUDE.md 규칙4대로 평소엔 안 돌린다. 에디터 수정이 날아간다.)
## ============================================================================
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 실내배경_S := preload("res://scripts/스마트월드/실내배경.gd")
const 브릭_S := preload("res://scripts/집/브릭구조.gd")
const 통로_S := preload("res://scripts/스마트월드/연결통로.gd")
const 챕터_S := preload("res://scripts/스마트월드/챕터.gd")
const 공통 := preload("res://tools/지형공통.gd")
const PLAYER := "res://scenes/player/Player.tscn"
const 저장경로 := "res://scenes/집/집_2층방.tscn"

## 점프 튜닝 — build_원본_집.gd 와 동일(도형님 "현재값 보존").
const 튜닝 := {"move_speed": 390.0, "타일_크기": 16.0, "점프_높이_칸": 10.0, "점프_거리_칸": 15.0}


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 집 · 2층 방 빌더 ===")
	var 루트 := _짓기()
	# owner 지정 후 pack (§지형공통.주인_지정 — 인스턴스 내부는 안 건드린다)
	공통.주인_지정(루트, 루트)
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("pack 실패: %s" % error_string(e)); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/집"))
	e = ResourceSaver.save(팩, 저장경로)
	print("   저장 %s → %s" % [error_string(e), 저장경로])
	루트.queue_free()
	quit(0 if e == OK else 1)


func _짓기() -> Node2D:
	# ── 방 범위 ── 2층 방 하나. 카메라가 방 밖(벽 너머)을 안 비추게 리밋을 방에 맞춘다.
	var 리밋 := Rect2(-700, -700, 3100, 1900)      # x −700..2400 · y −700..1200
	var 시작 := Vector2(-150, -40)                 # 시작 선반 위

	var 루트: Node2D = 월드_S.new()
	루트.name = "집_2층방"
	루트.set("스테이지_이름", "2층 방")
	루트.set("카메라_줌", 0.82)
	루트.set("시작_위치", 시작)
	루트.set("낙사_y", 1500.0)
	루트.set("카메라_리밋", 리밋)

	# 페인트 규칙 엔진(지형보다 먼저 트리에)
	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)

	# 실내 배경 — 유럽풍 2층 방 벽지
	var 배경: Node2D = 실내배경_S.new()
	배경.name = "실내배경"
	배경.set("영역", Rect2(리밋.position - Vector2(600, 500), 리밋.size + Vector2(1200, 1000)))
	배경.set("아래_방", 실내배경_S.방_.이층방)
	배경.set("위_방", 실내배경_S.방_.이층방)
	루트.add_child(배경)

	# 전체 톤(챕터1 팔레트)
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

	# ── 큰 바닥 먼저 ── (도형님: "하나의 큰 바닥을 깐다고 생각하고")
	#   윗면 y=640. 중심 = 윗면 + 높이/2. 출구(x2150)까지 덮어 가장자리 낙하를 없앤다.
	_브릭(지형층, "1층바닥", Vector2(830, 640 + 130), Vector2(2920, 260))

	# ── 방 외곽(왼벽·천장) ── 브릭 무색 구조물. 오른쪽은 출구 통로(뒷벽)가 막는다.
	#   벽 윗면을 천장 아랫면(y −220)에 맞춰 "밟을 수 있는 턱"으로 안 잡히게 한다.
	_브릭(지형층, "왼벽", Vector2(-560, 300), Vector2(220, 1040))
	_브릭(지형층, "천장", Vector2(700, -320), Vector2(2600, 200))

	# ── 시작 선반(2층 높이) ── 윗면 y=0. 왼쪽 끝을 왼벽에 붙여 좌측 치명 낙하를 막는다.
	_브릭(지형층, "시작선반", Vector2(-170, 60), Vector2(600, 120))

	# ── 내려가는 공중 플랫폼 ── 아래로 향하는 낙차라 안 죽는다(≤520). 가로 gap≈100px.
	#   시작선반 윗면 0 → A 220 → B 420 → 바닥 640. 각 낙차 200~220px.
	_브릭(지형층, "발판_A", Vector2(320, 220 + 55), Vector2(380, 110))   # 윗면 220
	_브릭(지형층, "발판_B", Vector2(820, 420 + 55), Vector2(380, 110))   # 윗면 420
	# 되돌아 오를 수 있게(소프트락 방지) — 오른쪽에 오름 계단 2칸(단차 120)
	_브릭(지형층, "오름_1", Vector2(1500, 520 + 45), Vector2(320, 90))   # 윗면 520
	_브릭(지형층, "오름_2", Vector2(1900, 400 + 45), Vector2(320, 90))   # 윗면 400

	# ── 출구 통로 ── 1층 바닥 오른쪽 끝. 다음 스테이지(2층 복도)로 이어질 자리.
	#   지금은 다음_씬 비움(단독 검증용). 챕터 체인 편입은 3장(방·복도·계단) 완성 후.
	var 출구: Node2D = 통로_S.new()
	출구.name = "출구통로"
	출구.position = Vector2(2150, 640)              # 바닥 윗면
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


## 브릭 9-슬라이스 구조 블록 하나. 중심·크기로 놓는다(무색 구조물 = 누구나 안전).
func _브릭(층: Node2D, 이름: String, 중심: Vector2, 크기: Vector2, 룩: int = 0) -> void:
	var b: StaticBody2D = 브릭_S.new()
	b.name = 이름
	b.set("크기", 크기)         # 트리 진입 전 설정 → _ready 가 이 크기로 자식을 만든다
	b.set("룩", 룩)
	b.position = 중심
	층.add_child(b)
