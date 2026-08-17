extends SceneTree
## ============================================================================
## [2026-08-08 신규] 스마트월드 체인 빌더 — 챕터 표 하나로 전 스테이지를 굽는다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/스마트월드_체인.gd
##   → scenes/스마트월드/스마트월드_1.tscn … _4.tscn 을 만든다 (덮어쓰기)
##
## ▣ 이게 `스마트월드_연결.gd` 를 대체한다
##   예전 도구는 **1 편과 2 편을 코드에 박아 두고** 통로만 이었다.
##   3 편을 만들려면 도구를 고쳐야 했고, 순서를 바꾸면 목적지 문자열이 어긋났다.
##   → 이제 순서·챕터·통로 위치가 전부 `scripts/스마트월드/챕터.gd` 의 표에 있다.
##     **스테이지를 추가하려면 그 표에 한 줄만 넣고 이 도구를 다시 돌리면 된다.**
##
## ▣ 재료는 두 가지 (챕터표의 `원본` 필드)
##   "타일맵:<셀x최소>:<셀x최대>"
##       `stage_1-1, 1-2.tscn` 의 타일맵을 그 구간만 잘라 스마트 지형으로 **변환**한다.
##       도형님 지시: "맵 레벨 디자인이 끝났기에 씬과 똑같은 지형을 다시 재구현".
##   "res://.../원본_*.tscn"
##       이미 있는 스마트월드 씬을 **읽어서 통로만 얹는다.**
##       ★재생성하지 않는다 — 신우님이 에디터에서 손본 값(칠하기_허용 등)이 날아간다.
##
## ▣ ★owner 규칙 (2026-08-07 에 엔진이 죽었던 그 버그)
##   코드로 **처음부터 만든** 씬은 트리 전체에 owner 를 박아야 저장된다.
##   반대로 **읽어온 씬**은 owner 가 이미 올바르므로 절대 건드리면 안 된다.
##   건드리면 런타임 생성 노드가 씬에 한 벌 더 저장되고, 다음 로드 때 두 벌이 되어
##   씬 교체 시 세그폴트가 난다. → `_저장()` 이 두 경우를 나눠 처리한다.
## ============================================================================

const 타일맵씬 := "res://scenes/world_1/stage_1-1, 1-2.tscn"
const PLAYER := "res://scenes/player/Player.tscn"

const 공통 := preload("res://tools/지형공통.gd")
const 변환 := preload("res://tools/타일맵_변환.gd")
const 규칙 := preload("res://scripts/스마트월드/지형규칙.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 통로_S := preload("res://scripts/스마트월드/연결통로.gd")
const 안개_S := preload("res://scripts/스마트월드/안개층.gd")
const 배치_S := preload("res://scripts/스마트월드/장식배치.gd")
## [2026-08-17] 카메라 공간(굴뚝처럼 좁은 수직 통로에서 화면을 조이는 판정 영역) 배치기.
const 배치공간 := preload("res://scripts/스마트월드/카메라공간배치.gd")

## 타일 소스 id → 지형 재질. 타일 그림이 다르면 지형 룩도 달라야 한다.
##   0 brick(벽돌) · 1 grass(풀) · 2 rock · 3 soil · 4 wood(나무)
const 소스_재질 := { 0: "거친암반", 1: "기본", 2: "거친암반", 3: "기본", 4: "기본" }

## 챕터 → 배경 바이옴 (StageBackdrop 의 이름). 시작→끝으로 그라데이션이 걸린다.
const 챕터_바이옴 := {
	1: ["자연", "자연"],
	2: ["물가", "물가"],
	3: ["판자촌", "판자촌"],
}

var _재질: Dictionary = {}       ## 종류이름 → .tres 경로
var _성공 := 0
var _시도 := 0
var _타일층: TileMapLayer = null
var _타일씬루트: Node = null


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 스마트월드 체인 빌더 ===")
	규칙.상수_점검(null)          # 상수가 낡았는지 한 번 훑는다(경고만)

	for 종류 in ["기본", "거친암반", "덩어리"]:
		_재질[종류] = 공통.재질_준비(종류)
		if String(_재질[종류]).is_empty():
			push_error("재질 준비 실패: %s" % 종류)
			quit(1)
			return

	for s in 챕터.스테이지표:
		_시도 += 1
		await _스테이지_굽기(s)

	if _타일씬루트:
		_타일씬루트.queue_free()

	print("---")
	print("[체인] %d / %d 성공" % [_성공, _시도])
	quit(0 if _성공 == _시도 else 1)


# ============================================================================
# 스테이지 하나
# ============================================================================
func _스테이지_굽기(정보: Dictionary) -> void:
	var 번호: int = int(정보["번호"])
	var 챕터번호: int = int(정보["챕터"])
	var 원본: String = String(정보["원본"])
	var 경로 := 챕터.씬경로(번호)
	print("\n── 스마트월드_%d  (챕터 %d · %s)" % [번호, 챕터번호, 정보["이름"]])

	var 루트: Node2D = null
	var 새로만듦 := false

	if 원본.begins_with("타일맵:"):
		var 조각 := 원본.split(":")
		루트 = await _타일맵에서_짓기(정보, int(조각[1]), int(조각[2]))
		새로만듦 = true
	else:
		if not ResourceLoader.exists(원본):
			push_error("  원본 씬이 없다 → %s" % 원본)
			return
		루트 = (load(원본) as PackedScene).instantiate() as Node2D
		root.add_child(루트)
		await physics_frame
		await physics_frame

	if 루트 == null:
		push_error("  루트를 못 만들었다")
		return

	# ── 공통 설정 ──
	루트.name = "스마트월드_%d" % 번호
	루트.set("스테이지_이름", 챕터.표시이름(번호))
	루트.set("낙사_y", float(정보.get("낙사y", 2000.0)))
	루트.set("치명_낙하거리", 520.0)          # 점프 높이 160px × 3.25
	루트.set("낙하_경고표시", true)
	루트.set("안전지점_자동저장", true)
	루트.set("안전지점_유예", 0.45)
	루트.set("몸통_접촉_사망", true)

	# ── 통로 ── 챕터표의 순서대로 앞뒤를 잇는다
	_통로_잇기(루트, 정보)

	# ── 카메라 리밋 ── 씬 내용물에서 매번 새로 계산한다(멱등 — §_카메라리밋_맞추기 주석)
	_카메라리밋_맞추기(루트)

	# ── 장식 ── ★지형이 트리에 들어간 뒤에 깔아야 레이캐스트로 표면을 잴 수 있다
	await physics_frame
	await physics_frame
	_장식_깔기(루트, 번호, 챕터번호)

	# ── 카메라 공간 ── [2026-08-17] 굴뚝·수직 갱도에서 화면을 조이는 판정 영역.
	# ★로직은 `scripts/스마트월드/카메라공간배치.gd` 한 곳에만 있다.
	#   `tools/카메라공간_배치.gd`(구운 씬 후처리)도 **같은 함수**를 부르므로,
	#   여기서 다시 구워도 결과가 완전히 같다(복사본이 없으니 버그도 한 벌뿐이다).
	_카메라공간_깔기(루트)

	_저장(루트, 경로, 새로만듦)
	루트.queue_free()
	await process_frame


# ============================================================================
# 타일맵에서 새로 짓기
# ============================================================================
func _타일맵에서_짓기(정보: Dictionary, 셀최소: int, 셀최대: int) -> Node2D:
	if _타일층 == null:
		if not ResourceLoader.exists(타일맵씬):
			push_error("  타일맵 씬이 없다 → %s" % 타일맵씬)
			return null
		_타일씬루트 = (load(타일맵씬) as PackedScene).instantiate()
		root.add_child(_타일씬루트)
		await process_frame
		_타일층 = _타일씬루트.get_node_or_null("TileMapLayer") as TileMapLayer
	if _타일층 == null:
		push_error("  TileMapLayer 를 못 찾았다")
		return null

	var 조각들 := 변환.지형조각들(_타일층, 셀최소, 셀최대, 6, 6.0)
	if 조각들.is_empty():
		push_error("  변환된 지형이 없다 (셀 %d~%d)" % [셀최소, 셀최대])
		return null

	# 전체 범위 — 배경·안개·카메라가 이 값을 쓴다
	var 전체 := Rect2((조각들[0] as Dictionary)["범위"])
	for f in 조각들:
		전체 = 전체.merge(f["범위"])
	print("   변환: %d 조각 · 범위 %s" % [조각들.size(), 전체])

	var 루트 := 월드_S.new() as Node2D
	루트.set("시작_위치", Vector2(전체.position.x + 200.0, 전체.position.y - 200.0))
	루트.set("카메라_줌", 0.82)

	# ── 페인트 규칙 엔진 (지형보다 먼저 트리에 들어가야 한다) ──
	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 12)
	코어.add_to_group("페인트코어", true)     # true = 씬 파일에 그룹이 저장된다
	루트.add_child(코어)

	# ── 배경 ──
	var 챕터번호: int = int(정보["챕터"])
	var 바이옴: Array = 챕터_바이옴.get(챕터번호, 챕터_바이옴[1])
	StageBackdrop.구성(루트, 루트,
		Rect2(전체.position - Vector2(600, 400), 전체.size + Vector2(1200, 900)),
		바이옴[0], 바이옴[1], 20260808 + int(정보["번호"]))

	_대기층(루트, 전체)
	_안개_전부(루트, 전체)

	# ── 전체 톤 ── ★이 색이 "밝기 100%" 의 기준값이다(ESC 메뉴 밝기 슬라이더 기준)
	var 팔 := 챕터.팔레트(챕터번호)
	var 어둠 := CanvasModulate.new()
	어둠.name = "어둠"
	어둠.color = 팔["어둠"]
	루트.add_child(어둠)

	# ── 지형 ──
	var 지형층 := Node2D.new()
	지형층.name = "지형"
	루트.add_child(지형층)

	var i := 0
	var 위반총 := 0
	for f in 조각들:
		i += 1
		var 소스: int = int(f["소스"])
		var 재질: String = _재질.get(소스_재질.get(소스, "기본"), _재질["기본"])
		# ★칠하기_허용 = true, 무색일때_통과 = false.
		#   원본 타일맵은 전부 "항상 밟히는 단단한 지형" 이었다. 유령 발판으로 바꾸면
		#   레벨 디자인이 통째로 달라진다 — 지금은 **지형을 그대로 옮기는 것**이 목적이다.
		var 지형 := 공통.지형_노드("지형_%d" % i, Vector2.ZERO,
			f["점들"], 재질, true, false, 0, 16.0)
		지형층.add_child(지형)

		# 옮긴 지형이 걸어 다닐 수 있는지 기록만 남긴다(고치지는 않는다 — 원본 보존이 우선)
		for ch in 변환.윗면_체인들(f["점들"]):
			var 체인: PackedVector2Array = ch
			if 체인[체인.size() - 1].x - 체인[0].x < 규칙.최소_발판폭:
				continue
			위반총 += 규칙.위반_찾기(체인, false).size()
	if 위반총 > 0:
		print("   ⚠ 규칙 위반 %d 건 (원본 타일맵 그대로 옮긴 결과 — 필요하면 손으로 다듬을 것)"
			% 위반총)

	# ── 오브젝트 ── 원본 씬의 장애물 중 이 구간에 있는 것만 복사
	var 오브젝트층 := Node2D.new()
	오브젝트층.name = "오브젝트"
	루트.add_child(오브젝트층)
	var 옮김 := _장애물_옮기기(오브젝트층, 전체)
	if 옮김 > 0:
		print("   장애물 %d 개 이식" % 옮김)

	# ── 플레이어 ──
	# ★★[2026-08-08 · 레벨이 통째로 끊기던 진짜 원인] ─────────────────────
	#   처음에는 `Player.tscn` 을 기본값 그대로 넣었다. 그런데 원본 스테이지의
	#   플레이어는 **씬에서 점프를 따로 튜닝해 놓았다**:
	#       stage_1-1,1-2 : move_speed 300 · 높이 8칸(128px) · 거리 15칸(240px)
	#       Player.tscn 기본:  move_speed 390 · 높이 10칸(160px) · 거리 10칸(160px)
	#   레벨 디자인은 **그 튜닝을 전제로 그려져 있다.** 기본값으로 바꾸면
	#   점프 거리가 240px → 160px 로 줄어, 예컨대 x1840~1900 의 160px 구덩이를
	#   못 건너고 **그 뒤 스테이지 전체가 막힌다**(레벨검사: 87개 중 도달 5개).
	#   지형은 1px 도 안 틀렸는데 못 지나가니 원인을 찾기가 매우 어려웠다.
	#   → 원본 씬의 플레이어 설정을 그대로 이어받는다.
	var 플레이어 := (load(PLAYER) as PackedScene).instantiate()
	플레이어.name = "Player"
	_플레이어_튜닝_잇기(플레이어)
	루트.add_child(플레이어)

	# ★코드로 만든 씬이므로 여기서 owner 를 박는다 (읽어온 씬은 절대 하지 않는다)
	공통.주인_지정(루트, 루트)

	루트.set("카메라_리밋", Rect2(
		전체.position - Vector2(700, 800), 전체.size + Vector2(1400, 1600)))

	root.add_child(루트)
	await physics_frame
	await physics_frame

	# 시작 위치를 **지면 위로** 내려놓는다 (좌표를 손으로 적으면 공중에 뜬다)
	var 시작 := _지면_위(루트, 전체.position.x + 220.0, 전체)
	if 시작 != Vector2.INF:
		루트.set("시작_위치", 시작)
		(플레이어 as Node2D).global_position = 시작
	return 루트


## 원본 씬의 플레이어 이동/점프 설정을 그대로 옮긴다.
## 옮기는 값은 **레벨 디자인이 전제하는 것들만** — 위치·색 같은 상태는 옮기지 않는다.
func _플레이어_튜닝_잇기(대상: Node) -> void:
	var 원본플레이어 := _타일씬루트.get_node_or_null("Player") if _타일씬루트 else null
	if 원본플레이어 == null:
		push_warning("  원본 씬에 Player 가 없다 — 기본 점프 설정을 쓴다")
		return
	for 키 in ["move_speed", "타일_크기", "점프_높이_칸", "점프_거리_칸",
			"상승_배수", "낙하_가속_증가율", "낙하_최대_배수"]:
		var v: Variant = 원본플레이어.get(키)
		if v != null:
			대상.set(키, v)
	# 물리 바디 자체의 설정도 레벨 감각에 직결된다(경사 스냅·최대 바닥각)
	if 원본플레이어 is CharacterBody2D and 대상 is CharacterBody2D:
		(대상 as CharacterBody2D).floor_snap_length = (원본플레이어 as CharacterBody2D).floor_snap_length
		(대상 as CharacterBody2D).floor_constant_speed = (원본플레이어 as CharacterBody2D).floor_constant_speed
	print("   플레이어 튜닝 이식: 속도 %.0f · 높이 %.0f칸 · 거리 %.0f칸"
		% [float(대상.get("move_speed")), float(대상.get("점프_높이_칸")),
		   float(대상.get("점프_거리_칸"))])


## 원본 씬(`stage_1-1, 1-2.tscn`)의 `장애물` 노드에서 이 구간에 드는 것만 복제한다.
## ★식물 A/B 는 이미 씬(.tscn) 부품이라 그대로 복제하면 설정이 다 따라온다.
func _장애물_옮기기(부모: Node2D, 범위: Rect2) -> int:
	var 원장애물 := _타일씬루트.get_node_or_null("장애물")
	if 원장애물 == null:
		return 0
	var 셈 := 0
	for c in 원장애물.get_children():
		var n2 := c as Node2D
		if n2 == null:
			continue
		if n2.global_position.x < 범위.position.x or n2.global_position.x > 범위.end.x:
			continue
		# ⚠[2026-08-08] `DUPLICATE_SCRIPTS` 를 주면 안 된다.
		#   장애물 씬 안에는 `그림`(Sprite2D · 아트슬롯.gd) 슬롯이 들어 있는데,
		#   이 플래그는 스크립트를 **노드 순서대로** 다시 붙이려다
		#   "Script inherits from native type 'Sprite2D', so it can't be assigned to
		#    an object of type 'CollisionShape2D'" 로 실패한다.
		#   인스턴스 씬은 `DUPLICATE_USE_INSTANTIATION` 만으로 스크립트까지 그대로 따라온다.
		var 복제 := n2.duplicate(Node.DUPLICATE_USE_INSTANTIATION | Node.DUPLICATE_GROUPS)
		부모.add_child(복제)
		(복제 as Node2D).global_position = n2.global_position
		셈 += 1
	return 셈


# ============================================================================
# 배경 보정 · 안개
# ============================================================================
## ★대기(공기 원근) 레이어.
## [2026-08-01 문제] 배경(0.15~0.36)과 지형 아트(black_fill ≈ 0.10)의 명도가 거의
## 같아서 지형 실루엣이 배경에 먹혀 화면이 통째로 새까맸다.
## [해결] 배경과 지형 **사이**에 밝은 반투명 판을 끼워 배경 명도를 0.55 대로 올린다.
func _대기층(루트: Node2D, 범위: Rect2) -> void:
	var 대기 := ColorRect.new()
	대기.name = "대기"
	대기.color = Color(0.58, 0.60, 0.65, 0.45)
	대기.position = 범위.position - Vector2(1600, 1400)
	대기.size = 범위.size + Vector2(3200, 3600)
	대기.z_index = -7          # 뒷벽(z=-8)보다 앞, 지형(z=0)보다 뒤
	대기.mouse_filter = Control.MOUSE_FILTER_IGNORE
	루트.add_child(대기)


## 서로 다른 속도로 흐르는 안개 3 겹 = 깊이감.
func _안개_전부(루트: Node2D, 범위: Rect2) -> void:
	_안개층(루트, 범위, "안개_원경", 0.30, -26, Vector2(0, -260), 9, 460.0, 10.0,
		Color(0.80, 0.83, 0.88, 0.10), 11)
	_안개층(루트, 범위, "안개_중경", 0.65, -6, Vector2(0, 60), 12, 330.0, 17.0,
		Color(0.76, 0.79, 0.84, 0.13), 22)
	_안개층(루트, 범위, "안개_전경", 1.25, 14, Vector2(0, 320), 7, 280.0, 30.0,
		Color(0.72, 0.75, 0.80, 0.10), 33)


func _안개층(루트: Node2D, 범위: Rect2, 이름: String, 스크롤: float, z: int,
		오프셋: Vector2, 개수: int, 반경: float, 속도: float,
		색: Color, 씨앗보정: int) -> void:
	var par := Parallax2D.new()
	par.name = 이름
	par.scroll_scale = Vector2(스크롤, 스크롤 * 0.55)   # 세로는 덜 움직여야 어지럽지 않다
	par.repeat_size = Vector2(6000, 0)
	par.repeat_times = 3
	par.z_index = z
	루트.add_child(par)

	var 안개 := 안개_S.new()
	안개.name = "안개"
	# 스테이지가 x=0 에서 시작하지 않을 수 있다(스마트월드_2 는 12,576 에서 시작).
	# 범위 한가운데에 놓아야 안개가 스테이지 위를 덮는다.
	안개.position = Vector2(범위.get_center().x, 범위.get_center().y) + 오프셋
	안개.set("영역", Vector2(6000, 900))
	안개.set("덩어리수", 개수)
	안개.set("덩어리_반경", 반경)
	안개.set("흐름속도", 속도)
	안개.set("안개색", 색)
	안개.set("씨앗", 20260808 + 씨앗보정)
	par.add_child(안개)


# ============================================================================
# 통로
# ============================================================================
## 챕터표의 앞뒤 줄을 보고 입구/출구 통로를 놓는다.
##   · 첫 스테이지의 입구는 **판정 없는 장식**이다(들어올 곳이 없으므로).
##   · 마지막 스테이지의 출구는 지금은 **처음으로 되돌아간다**(순환).
##     5 편이 생기면 표에 한 줄 추가하는 것만으로 자동으로 이어진다.
func _통로_잇기(루트: Node2D, 정보: Dictionary) -> void:
	var 번호: int = int(정보["번호"])
	var 이전 := 챕터.이전_번호(번호)
	var 다음 := 챕터.다음_번호(번호)
	# 마지막이면 처음으로 되돌린다 — 길이 막다른 골목으로 끝나면 테스트가 불편하다
	if 다음 < 0:
		다음 = int(챕터.스테이지표[0]["번호"])

	var 이전챕터 := 챕터.챕터번호(이전) if 이전 > 0 else 챕터.챕터번호(번호)
	var 다음챕터 := 챕터.챕터번호(다음)

	_통로_하나(루트, "입구통로", 연결통로.역할_.입구,
		float(정보["입구x"]), 챕터.팔레트(이전챕터)["하늘_위"], "", "")
	_통로_하나(루트, "출구통로", 연결통로.역할_.출구,
		float(정보["출구x"]), 챕터.팔레트(다음챕터)["하늘_위"],
		챕터.씬경로(다음), "입구통로")


func _통로_하나(루트: Node2D, 이름: String, 역할: int, x: float, 속빛: Color,
		다음씬: String, 진입점: String) -> void:
	# 여러 번 돌려도 결과가 같게 — 이미 있으면 지우고 새로 단다
	var 옛것 := _찾기(루트, 이름)
	if 옛것:
		옛것.get_parent().remove_child(옛것)
		옛것.queue_free()

	var 전체: Rect2 = 루트.get("카메라_리밋")
	var 지면y := _지면_재기(루트, x, 전체)
	if is_inf(지면y):
		push_warning("  %s: x=%.0f 에서 지면을 못 찾음 — 건너뜀" % [이름, x])
		return

	var 통로: 연결통로 = 통로_S.new()
	통로.name = 이름
	통로.역할 = 역할
	통로.position = Vector2(x, 지면y)
	통로.높이 = 170.0
	통로.깊이 = 460.0
	통로.속빛 = 속빛
	통로.암반_위 = 340.0
	통로.암반_아래 = 420.0
	if 역할 == 연결통로.역할_.출구:
		통로.다음_씬 = 다음씬
		통로.다음_진입점 = 진입점

	var 부모: Node = 루트.get_node_or_null("오브젝트")
	if 부모 == null:
		부모 = 루트
	부모.add_child(통로)
	통로.owner = 루트
	# ⚠ 통로가 런타임에 만드는 바닥/천장/뒷벽에는 owner 를 주지 않는다
	#   (주면 씬에 한 벌 더 저장되고 다음 로드 때 두 벌이 된다 — 2026-08-07 세그폴트)

	print("   · %s x=%.0f 지면y=%.0f%s"
		% [이름, x, 지면y, ("  → " + 다음씬.get_file()) if not 다음씬.is_empty() else ""])


# ============================================================================
# 장식
# ============================================================================
func _장식_깔기(루트: Node2D, 번호: int, 챕터번호: int) -> void:
	var 옛것 := 루트.get_node_or_null("장식")
	if 옛것:
		루트.remove_child(옛것)
		옛것.queue_free()

	var 층 := Node2D.new()
	층.name = "장식"
	루트.add_child(층)

	var 리밋: Rect2 = 루트.get("카메라_리밋")
	var 셈 := 배치_S.깔기(루트, 층, 리밋, 챕터번호, 20260808 + 번호 * 17, 0.55)
	print("   장식: 지면 %d · 늘어짐 %d · 전경 %d"
		% [셈["지면"], 셈["천장"], 셈["전경"]])

	# 장식은 우리가 새로 만든 노드다 → owner 를 줘야 씬에 저장된다.
	# ★층 아래만 준다. 루트 전체에 주면 읽어온 씬의 내부까지 건드려 세그폴트가 난다.
	층.owner = 루트
	공통.주인_지정(층, 루트)


# ============================================================================
# 카메라 공간 (굴뚝 등 좁은 수직 통로)
# ============================================================================
## `카메라공간배치.깔기()` 를 부르고 새 노드에만 owner 를 준다.
##
## ⚠ 공간 노드가 런타임에 스스로 만드는 자식(`판정` CollisionShape2D)에는
##   owner 를 주지 않는다. 주면 씬 파일에 한 벌 더 저장되고 다음 로드 때 두 벌이 되어
##   씬을 교체할 때 세그폴트가 난다(2026-08-07 에 실제로 겪은 그 버그).
##   → `공통.주인_지정()` 을 쓰지 않고 **공간 노드 자신에게만** owner 를 준다.
func _카메라공간_깔기(루트: Node2D) -> void:
	var 결과 := 배치공간.깔기(루트)
	var 수: int = int(결과["만든수"])
	if 수 == 0:
		return
	for 이름 in 결과["이름들"]:
		var n := _찾기(루트, String(이름))
		if n:
			n.owner = 루트
	print("   카메라 공간 %d개: %s" % [수, ", ".join(결과["이름들"])])


# ============================================================================
# 도우미
# ============================================================================
## x 위치의 지면 y 를 레이캐스트로 잰다. 못 찾으면 INF.
## 여러 층(천장·발판)을 뚫고 내려가 **가장 아래 지면**을 고른다.
func _지면_재기(루트: Node2D, x: float, 범위: Rect2) -> float:
	var 공간 := 루트.get_viewport().world_2d.direct_space_state
	var y := 범위.position.y - 200.0
	var 아래 := 범위.end.y + 400.0
	var 마지막 := INF
	var 안전 := 0
	while y < 아래 and 안전 < 40:
		안전 += 1
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, 아래), 1)
		q.collide_with_areas = false
		var r := 공간.intersect_ray(q)
		if r.is_empty():
			break
		마지막 = r["position"].y
		y = 마지막 + 4.0
		var 속안전 := 0
		while 속안전 < 600 and _속인가(공간, x, y):
			y += 8.0
			속안전 += 1
		y += 2.0
	return 마지막


## 지면 바로 위 좌표(플레이어를 세울 자리). 못 찾으면 Vector2.INF.
func _지면_위(루트: Node2D, x: float, 범위: Rect2) -> Vector2:
	var y := _지면_재기(루트, x, 범위)
	if is_inf(y):
		return Vector2.INF
	return Vector2(x, y - 6.0)


func _속인가(공간: PhysicsDirectSpaceState2D, x: float, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, y)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1
	return not 공간.intersect_point(q, 1).is_empty()


func _찾기(노드: Node, 이름: String) -> Node:
	for c in 노드.get_children():
		if c.name == 이름:
			return c
		var r := _찾기(c, 이름)
		if r:
			return r
	return null


## 카메라 리밋을 **씬 내용물에서 다시 계산**한다.
##
## ⚠⚠[2026-08-08 · 이 도구를 두 번 돌리면 레벨이 망가지던 버그]
##   처음에는 기존 리밋에 여유를 **더하는** 방식이었다. 그런데 이 도구는 멱등해야 한다
##   (같은 입력이면 몇 번을 돌려도 같은 결과여야 한다). 더하기만 하면
##   돌릴 때마다 리밋이 700px 씩 커진다. 그게 왜 문제냐면:
##     `tools/레벨검사.gd` 가 **이 리밋을 훑을 범위로 쓴다.** 범위가 위로 넓어지면
##     한 x 에서 세는 층(최대 8층)이 위쪽 지형에 먼저 소모돼 **진짜 바닥을 못 찾는다.**
##   → 실제로 스마트월드_4 의 도달 가능 지형이 43개 → 18개로 떨어졌다.
##     지형은 1px 도 안 바뀌었는데 검사 결과만 무너져서 원인을 찾기 매우 어려웠다.
##
##   지금은 **콜리전의 실제 경계**에서 매번 새로 계산한다. 몇 번을 돌려도 같은 값이 나온다.
##
## ▣ 여유를 왜 주나
##   통로는 지형 밖으로 460px 파고들고, 플레이어는 그 안쪽 62% 지점에서 스폰된다.
##   리밋이 지형 경계에 딱 붙어 있으면 **통로에서 걸어 나오는 장면이 안 보인다**
##   (플레이어만 화면 밖에서 걸어 들어오는 이상한 그림이 된다).
func _카메라리밋_맞추기(루트: Node2D) -> void:
	var 경계 := _콜리전_경계(루트)
	if 경계.size.length() <= 1.0:
		return
	var 여유 := Vector2(760.0, 260.0)      # 통로 깊이(460) + 화면 반폭 여유
	루트.set("카메라_리밋", Rect2(경계.position - 여유, 경계.size + 여유 * 2.0))


## 트리 안의 모든 콜리전 도형을 감싸는 사각형(월드 좌표).
## 지형이 SS2D 곡선이라 점 배열을 직접 보는 게 가장 정확하다.
func _콜리전_경계(노드: Node) -> Rect2:
	var 결과 := Rect2()
	var 처음 := true
	var 대기: Array[Node] = [노드]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			대기.append(c)
		var r := Rect2()
		var 있음 := false
		if n is CollisionPolygon2D:
			var poly := (n as CollisionPolygon2D).polygon
			if poly.size() >= 3:
				var mn := poly[0]
				var mx := poly[0]
				for p in poly:
					mn = mn.min(p)
					mx = mx.max(p)
				r = Rect2((n as Node2D).to_global(mn), Vector2.ZERO)
				r = r.expand((n as Node2D).to_global(mx))
				있음 = true
		elif n is CollisionShape2D and (n as CollisionShape2D).shape:
			var sh := (n as CollisionShape2D).shape
			var box := sh.get_rect() if sh.has_method("get_rect") else Rect2(-Vector2.ONE * 16.0, Vector2.ONE * 32.0)
			var g := (n as Node2D).global_transform
			r = Rect2(g * box.position, Vector2.ZERO)
			r = r.expand(g * box.end)
			있음 = true
		if 있음:
			결과 = r if 처음 else 결과.merge(r)
			처음 = false
	return 결과


# ============================================================================
# 저장
# ============================================================================
func _저장(루트: Node2D, 경로: String, 새로만듦: bool) -> void:
	# 새로 만든 씬은 이미 `_타일맵에서_짓기` 안에서 owner 를 박아 뒀다.
	# 읽어온 씬은 owner 를 절대 건드리지 않는다 (§머리말 owner 규칙).
	if 새로만듦:
		공통.주인_지정(루트, 루트)

	var 팩 := PackedScene.new()
	var err := 팩.pack(루트)
	if err != OK:
		push_error("  pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, 경로)
	if err == OK:
		_성공 += 1
	print("   저장 %s → %s" % [error_string(err), 경로])
