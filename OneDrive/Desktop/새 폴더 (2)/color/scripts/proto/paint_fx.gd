extends Node2D
## ============================================================================
## [2026-07-24 도형 · 신규 / 2026-07-25 개정] 페인트 이펙트 v3 (Paint FX)
## ----------------------------------------------------------------------------
## 16차(effect_spawner.gd)가 "타일맵 셀 색칠"용이었다면, 이건 v3 **플랫폼 색칠**용이다.
## 두 스크립트는 공존한다 — zone_01/02/world_1(타일맵)은 effect_spawner,
## 새 스테이지·zone_04/05(플랫폼)는 이 스크립트를 쓴다.
##
## ▣ 담당하는 연출
##   1. 색칠 스플래시 파티클 (명중 지점에서 물감이 튐)
##   2. ★물감 흐름(PaintDrip) — 벽면·아랫면에 맞으면 아래로 주르륵
##   3. 카메라 킥 / 회색화 히트스톱
##
## ▣ [2026-07-25] ★"얼룩 스탬프" 코드를 전부 걷어냈다
##   구 방식: 명중할 때마다 얼룩 스프라이트를 플랫폼 위에 겹쳐 찍었다.
##   실제로 써보니 도형님 지적대로 두 가지가 무너졌다.
##     ① **실루엣 이탈** — 스프라이트가 플랫폼 그림 밖(투명 여백)까지 덮어
##        "벽돌 옆 마스킹 테이프까지 같이 칠해진" 것처럼 보였다.
##        `clip_children` 은 부모 사각형 기준이라 유기적 가장자리를 못 지킨다.
##     ② **덮임 미보장** — 랜덤 배치라 가운데나 구석이 덜 칠해진 채 남았다.
##   → 얼룩 표현을 **셰이더 프로파일**(ink_spread.gdshader `profile = 1`)로 옮겼다.
##     같은 마스크 안에서 경계만 딱딱하고 뭉텅뭉텅해진다 →
##     **실루엣을 벗어날 수 없고, 진행률 100% 에서 반드시 전부 덮인다.**
##   이 파일에는 이제 "물감이 튀고 흐르는" 물리적 연출만 남는다.
## ============================================================================
class_name PaintFX

const DRIP := preload("res://scripts/proto/paint_drip.gd")

enum 모드 { 스며듦, 얼룩 }        ## zone_04 / zone_05 (이름만 바뀜, 규칙은 동일)

# ── 튜닝 상수 ──────────────────────────────────────────────────────────────
const 스플래시_수: int = 14
const 스플래시_수명: float = 0.5
const 스플래시_속도: float = 190.0
const 흐름_확률_벽: float = 0.85       ## 벽면(세로면) 명중 시 물감이 흐를 확률
const 흐름_확률_아랫면: float = 0.7    ## 아랫면 명중 시
const 흐름_확률_윗면: float = 0.25     ## 윗면 명중 시 (앞쪽 모서리로 조금 넘쳐 흐름)
const 흐름_개수_최소: int = 1
const 흐름_개수_최대: int = 3
const 흐름_동시_최대: int = 40         ## 화면에 동시에 존재할 수 있는 흐름 수(성능 상한)
const 킥_색칠: float = 0.12
const 킥_회색: float = 0.26
const 히트스톱_회색: float = 0.06

var 현재모드: 모드 = 모드.스며듦

var _player: CharacterBody2D
var _camera: Node                       # ProtoCamera (add_trauma 를 가진 노드)
var _흐름들: Array[Node2D] = []

func setup(player: CharacterBody2D, camera: Node, m: int = 모드.스며듦) -> void:
	_player = player
	_camera = camera
	현재모드 = m
	_모든_플랫폼_연결()

## 씬 안의 모든 PaintPlatform 을 찾아 통합 시그널에 붙고, 표현 프로파일을 지정한다.
## (스테이지가 런타임에 플랫폼을 추가하면 재호출하면 된다)
func _모든_플랫폼_연결() -> void:
	for n in get_tree().get_nodes_in_group("paint_platform"):
		var p := n as PaintPlatform
		if p == null:
			continue
		p.표현_모드 = (1 if 현재모드 == 모드.얼룩 else 0)
		p._유니폼_갱신()
		if not p.명중됨.is_connected(_명중_받음):
			p.명중됨.connect(_명중_받음)

# ── 명중 처리 ──────────────────────────────────────────────────────────────
func _명중_받음(플랫폼: PaintPlatform, 결과: String, 색: int, 좌표: Vector2) -> void:
	match 결과:
		"progress", "painted":
			var c := _물감색(색)
			_스플래시(좌표, c, 결과 == "painted")
			_흐름_시도(플랫폼, 좌표, c)
			if _camera and _camera.has_method("add_trauma"):
				_camera.add_trauma(킥_색칠 * (2.0 if 결과 == "painted" else 1.0))
		"mixed_gray":
			var g := Color(0.5, 0.5, 0.5, 0.95)
			_스플래시(좌표, g, true)
			_흐름_시도(플랫폼, 좌표, g)
			if _camera and _camera.has_method("add_trauma"):
				_camera.add_trauma(킥_회색)
			_히트스톱(히트스톱_회색)
		"wasted", "blocked":
			# 아무 일도 안 일어난 명중 — 아주 작은 튐만 (헛발질 피드백)
			_스플래시(좌표, Color(0.55, 0.55, 0.55, 0.7), false, 0.4)

## 플레이어 색 → 화면에서 잘 보이는 물감색.
## 순수 검정은 검은 지형 위에서 안 보이므로 살짝 올린다(16차 effect_spawner 와 같은 보정).
func _물감색(색: int) -> Color:
	return Color(0.95, 0.95, 0.95, 0.95) if 색 == ColorDefs.WHITE \
		else Color(0.16, 0.16, 0.16, 0.95)

# ── 1) 스플래시 파티클 ─────────────────────────────────────────────────────
func _스플래시(pos: Vector2, 색: Color, 강하게: bool, 배율: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true                       # 부모 변환 무시 = 월드 좌표에 원형 그대로
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(int(스플래시_수 * 배율 * (1.6 if 강하게 else 1.0)), 3)
	p.lifetime = 스플래시_수명
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 스플래시_속도 * 0.3 * 배율
	p.initial_velocity_max = 스플래시_속도 * (1.4 if 강하게 else 1.0) * 배율
	p.gravity = Vector2(0, 620)               # 튄 물감은 금방 떨어진다
	p.scale_amount_min = 1.4 * 배율
	p.scale_amount_max = 3.4 * 배율
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.color = 색
	p.finished.connect(p.queue_free)
	add_child(p)

# ── 2) 물감 흐름 ───────────────────────────────────────────────────────────
## 명중 지점이 플랫폼의 어느 면인지 보고, 확률적으로 흐름을 만든다.
## 벽(세로면)에 맞으면 그 자리에서, 윗면에 맞으면 앞쪽 모서리를 넘어 흐른다.
func _흐름_시도(플랫폼: PaintPlatform, 좌표: Vector2, 색: Color) -> void:
	if _흐름들.size() >= 흐름_동시_최대:
		_흐름_정리()
		if _흐름들.size() >= 흐름_동시_최대:
			return
	var 크기 := 플랫폼.크기_px()
	var 로컬 := 플랫폼.to_local(좌표)
	var 옆면 := absf(로컬.x) > 크기.x * 0.5 - 6.0        # 좌우 세로면 근처인가
	var 아랫면 := 로컬.y > 크기.y * 0.5 - 6.0            # 바닥면 근처인가

	var 확률 := 흐름_확률_윗면
	if 옆면:
		확률 = 흐름_확률_벽
	elif 아랫면:
		확률 = 흐름_확률_아랫면
	if randf() > 확률:
		return

	var 개수 := randi_range(흐름_개수_최소, 흐름_개수_최대)
	for i in 개수:
		var 시작 := 좌표
		if 옆면:
			# 벽면: 맞은 높이에서 바로 흘러내린다.
			# ★[2026-07-25] 콜리전 면보다 살짝 안쪽에서 시작해 "그림 위"를 타고 흐르게 한다
			#   (예전엔 명중 좌표 그대로라 가장자리에 떠 있는 것처럼 보였다)
			var 부호 := signf(로컬.x)
			시작 = 플랫폼.global_position + Vector2(
				부호 * (크기.x * 0.5 - 3.0),
				로컬.y + randf_range(-4.0, 6.0))
		else:
			# 윗면/아랫면: 플랫폼 아래 모서리로 넘쳐 흐른다
			시작 = Vector2(좌표.x + randf_range(-10.0, 10.0),
				플랫폼.global_position.y + 크기.y * 0.5 - 2.0)
		var d := DRIP.new() as Node2D
		add_child(d)
		d.global_position = 시작
		d.시작(색, randf_range(3.0, 6.5),
			PaintDrip.최대길이_기본 * randf_range(0.45, 1.25))
		_흐름들.append(d)

func _흐름_정리() -> void:
	_흐름들 = _흐름들.filter(func(n): return is_instance_valid(n))

# ── 3) 히트스톱 ────────────────────────────────────────────────────────────
## 실시간 타이머(ignore_time_scale=true)로 복구 — 안 그러면 영영 안 풀린다.
func _히트스톱(길이: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(길이, true, false, true).timeout
	Engine.time_scale = 1.0
