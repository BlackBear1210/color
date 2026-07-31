extends SceneTree
## ============================================================================
## [2026-07-24 도형 · 신규] 스테이지 구조 · 도달 가능성 자동 검사
## 실행: Godot --headless --path . -s res://tools/test_stages.gd
##
## ▣ 무엇을 검사하나
##   1) 씬이 오류 없이 뜨는가 (스폰·목표문·낙하지대·플레이어가 다 있는가)
##   2) 스폰 지점 아래에 실제로 밟을 발판이 있는가
##   3) ★**스폰 발판 → 목표 발판까지 점프로 도달 가능한가** (그래프 BFS 시뮬레이션)
##   4) 각 점프 구간이 물리 한계 / 설계 권장치 안에 있는가
##   5) 반대색(즉사) 구간 앞에 색을 바꿀 회색 발판이 있는가 (경고)
##
## ▣ 점프 모델 (player.gd 실제 상수에서 유도)
##   최대 상승 = jump_velocity² / (2·gravity) = 600²/2400 = **150px**
##   체공 시간 = 0.5s(상승) + 0.32s(하강, 중력 2.4배) ≈ 0.82s
##   최대 수평 = move_speed × 체공 = 390 × 0.82 ≈ **320px**
##   높이 올리는 만큼 수평 여유가 줄어드는 것을 근사식으로 반영한다.
##   ⚠ 이건 "가능한가"만 보는 보수적 근사다. 실제 손맛은 창모드 플레이로 확인해야 한다.
## ============================================================================

const 스테이지들 := [
	"res://scenes/스테이지/스테이지_1.tscn",
	"res://scenes/스테이지/스테이지_2.tscn",
	"res://scenes/스테이지/스테이지_3.tscn",
	"res://scenes/스테이지/스테이지_4.tscn",
	"res://scenes/스테이지/스테이지_5.tscn",
	"res://scenes/world_1/zone_04/zone_04.tscn",
	"res://scenes/world_1/zone_05/zone_05.tscn",
]

# ── 점프 한계 ──────────────────────────────────────────────────────────────
const 물리_최대상승: float = 150.0     ## 이보다 높으면 절대 못 올라간다
const 물리_최대수평: float = 320.0     ## 평지 기준 최대 도약 거리
const 권장_최대상승: float = 96.0      ## 설계 권장(3칸) — 넘으면 경고
const 권장_최대수평: float = 192.0     ## 설계 권장(6칸) — 넘으면 경고

var _통과 := 0
var _실패 := 0
var _경고 := 0

func _init() -> void:
	Engine.max_fps = 60
	_실행()

func _확인(설명: String, 조건: bool) -> void:
	if 조건:
		_통과 += 1
	else:
		_실패 += 1
		printerr("    ✘ %s" % 설명)

func _주의(설명: String) -> void:
	_경고 += 1
	print("    ⚠ %s" % 설명)

func _실행() -> void:
	await process_frame        # 트리 시작을 기다린다 (test_paint_v3 와 같은 이유)
	print("\n=== 스테이지 구조 · 도달 가능성 검사 ===")
	for 경로 in 스테이지들:
		await _검사(경로)
	print("\n=== 결과: %d 통과 / %d 실패 / %d 경고 ===\n" % [_통과, _실패, _경고])
	quit(0 if _실패 == 0 else 1)

func _검사(경로: String) -> void:
	print("\n▶ %s" % 경로.get_file())
	if not ResourceLoader.exists(경로):
		_확인("씬 파일이 존재한다", false)
		return
	var scene := (load(경로) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame        # 콜리전 레이어 deferred 반영까지 기다린다

	# ── 1) 필수 구성 요소 ──
	_확인("Player 노드가 있다", scene.get_node_or_null("Player") != null)
	_확인("스폰 마커가 있다", scene.get_node_or_null("스폰") != null)
	_확인("목표문(zone_exit)이 있다", not get_nodes_in_group("zone_exit").is_empty())
	_확인("낙하지대(killzone)가 있다", not get_nodes_in_group("killzone").is_empty())

	var 발판들: Array[PaintPlatform] = []
	for n in get_nodes_in_group("paint_platform"):
		발판들.append(n as PaintPlatform)
	_확인("발판이 1개 이상 있다", 발판들.size() > 0)

	# ── 2) 스폰 아래 발판 ──
	var 스폰 := scene.get_node_or_null("스폰") as Node2D
	var 시작발판 := _아래_발판(발판들, 스폰.global_position) if 스폰 else null
	_확인("스폰 지점 아래에 밟을 수 있는 발판이 있다", 시작발판 != null)

	# ── 3) 목표문 아래 발판 ──
	var 목표문 := get_nodes_in_group("zone_exit")[0] as Node2D
	var 목표발판 := _아래_발판(발판들, 목표문.global_position)
	_확인("목표문 아래에 발판이 있다", 목표발판 != null)

	# ── 4) 도달 가능성 BFS ──
	if 시작발판 != null and 목표발판 != null:
		var 결과 := _도달가능(발판들, 시작발판, 목표발판)
		_확인("스폰 → 목표까지 점프로 도달할 수 있다", 결과["도달"])
		if not 결과["도달"]:
			printerr("      닿을 수 있는 발판 %d / 전체 %d — 끊긴 지점을 확인하세요"
				% [결과["방문"], 발판들.size()])
		if 결과["권장초과_수평"] > 0:
			_주의("권장(6칸=192px)을 넘는 도약 %d 곳 — 실플레이로 체감 확인 필요"
				% 결과["권장초과_수평"])
		if 결과["권장초과_상승"] > 0:
			_주의("권장(3칸=96px)을 넘는 상승 %d 곳" % 결과["권장초과_상승"])

	# ── 5) 즉사 구간 앞의 안전 전환 지대 ──
	var 즉사있음 := false
	var 중립있음 := false
	for p in 발판들:
		if p.현재상태 == PaintPlatform.상태.검정 or p.현재상태 == PaintPlatform.상태.흰색:
			즉사있음 = true
		if p.현재상태 == PaintPlatform.상태.회색:
			중립있음 = true
	if 즉사있음 and not 중립있음:
		_주의("고정색(즉사) 발판이 있는데 회색(안전 전환) 발판이 없다 — 색을 바꿀 자리가 없을 수 있음")

	# ── 6) 유령 발판은 반드시 칠할 수 있어야 한다 ──
	for p in 발판들:
		if not p.밟을_수_있나() and not p.칠하기_허용:
			_확인("밟을 수 없는데 칠할 수도 없는 발판이 없다 (소프트락)", false)

	scene.free()
	await process_frame

## 어떤 좌표 바로 아래(또는 그 좌표를 품은) 발판 찾기
func _아래_발판(발판들: Array[PaintPlatform], 좌표: Vector2) -> PaintPlatform:
	var 최선: PaintPlatform = null
	var 최소거리 := 1e9
	for p in 발판들:
		var 크기 := p.크기_px()
		if absf(좌표.x - p.global_position.x) > 크기.x * 0.5 + 4.0:
			continue
		var 윗면 := p.global_position.y - 크기.y * 0.5
		var d := 윗면 - 좌표.y
		if d >= -8.0 and d < 최소거리:       # 좌표보다 아래(또는 거의 같은 높이)
			최소거리 = d
			최선 = p
	return 최선

## 발판 사이 점프 그래프 BFS.
## 유령(무색) 발판은 "칠하면 밟을 수 있다"고 보고 통행 가능으로 친다.
func _도달가능(발판들: Array[PaintPlatform], 시작: PaintPlatform,
		목표: PaintPlatform) -> Dictionary:
	var 대기: Array[PaintPlatform] = [시작]
	var 방문 := { 시작: true }
	var 초과수평 := 0
	var 초과상승 := 0
	while not 대기.is_empty():
		var 현재: PaintPlatform = 대기.pop_front()
		for 다음 in 발판들:
			if 방문.has(다음) or 다음 == 현재:
				continue
			var 판정 := _점프가능(현재, 다음)
			if not 판정["가능"]:
				continue
			if 판정["수평"] > 권장_최대수평:
				초과수평 += 1
			if 판정["상승"] > 권장_최대상승:
				초과상승 += 1
			방문[다음] = true
			대기.append(다음)
	return {
		"도달": 방문.has(목표),
		"방문": 방문.size(),
		"권장초과_수평": 초과수평,
		"권장초과_상승": 초과상승,
	}

## 발판 A 위에서 발판 B 위로 점프할 수 있는가
func _점프가능(a: PaintPlatform, b: PaintPlatform) -> Dictionary:
	var 크a := a.크기_px()
	var 크b := b.크기_px()
	var a0 := a.global_position.x - 크a.x * 0.5
	var a1 := a.global_position.x + 크a.x * 0.5
	var b0 := b.global_position.x - 크b.x * 0.5
	var b1 := b.global_position.x + 크b.x * 0.5
	var 수평 := maxf(maxf(b0 - a1, a0 - b1), 0.0)          # 겹치면 0

	var a윗 := a.global_position.y - 크a.y * 0.5
	var b윗 := b.global_position.y - 크b.y * 0.5
	var 상승 := a윗 - b윗                                   # 양수 = b 가 더 높다

	if 상승 > 물리_최대상승:
		return { "가능": false, "수평": 수평, "상승": 상승 }
	# 높이 올릴수록 수평 여유가 줄어든다 (체공 시간을 상승에 쓰기 때문)
	var 수평여유 := 물리_최대수평
	if 상승 > 0.0:
		수평여유 = 물리_최대수평 * (1.0 - (상승 / 물리_최대상승) * 0.55)
	return { "가능": 수평 <= 수평여유, "수평": 수평, "상승": maxf(상승, 0.0) }
