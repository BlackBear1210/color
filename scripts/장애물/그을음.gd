@tool
extends CharacterBody2D
## ============================================================================
## [2026-10-09 Claude 신규] 그을음 — 빛에 닿으면 재가 되는 몹 (기획 §4-H · 카드 7)
## ----------------------------------------------------------------------------
## ▣ 세계관: 신이 "색은 오류" 라며 표백한 세상에서, 버티다 검게 그을려 가라앉은 것들. 저택 벽난로 그을음에서 태어난다.
## ▣ 한 바퀴
##   잠복(그을음 얼룩 · 흰 눈만 깜빡) → 깨어남(8칸 안 · 어둠 · 0.5초 예고: 몸이 솟는다) →
##   추적(달리기의 0.68배 · 14칸 밖이면 포기하고 둥지로) → 덮침(2칸 · 0.3초 웅크림 예고 → 앞으로 뛰어듦) →
##   **빛에 닿으면 0.4초 지글거리다 재**(소멸 8프레임) → 6초 뒤 둥지에서 다시 잠복.
## ▣ 규칙
##   · 닿으면 **색 무관 즉사**(hazard 그룹 — 월드.gd `_사망_판정` 0번). 물감총은 안 통한다(몸에 맞아도 아무 일 없음).
##   · **빛 안은 안전지대** — 그을음은 빛 경계 앞에서 멈춘다(들어오지 않는다). 태우는 빛 = "태우는빛" 그룹:
##     창문빛·색레이저(켜진 동안) · 켜진 촛불등 둘레(체크포인트) · (나중에) 빛 장치. 플레이어 보조광은 아니다.
##   · 점멸·주기 빛이 켜지는 순간 그 안에 있던 그을음은 탄다 → "빛을 기다렸다가 지나간다 / 빛으로 태운다" 퍼즐.
##   · 낭떠러지 앞에서 멈춘다(떨어지지 않는다) — 플레이어가 높이 차로 따돌릴 수 있다.
## ▣ 그림: 아스트라 그을음 우선안(왼쪽 열) 세 자세 + 빛 소멸 8프레임(`tools/생성_신규기믹_게임용.py 그을음`).
##   기어가기·숨쉬기·덮침은 세 자세를 코드로 움직인다(늘이기·기울기·출렁) — 정식 동작 시트는 GPT 프롬프트로 주문
##   (docs/프롬프트_특별스테이지_레버_그을음_2026-10-09.md 카드 7-B). 시트가 오면 `_그림_고르기()` 만 바꾸면 된다.
## ▣ 놓는 법: 원점 = 발끝(바닥선). 도안 {"종류": "그을음", "x", "바닥"} → 생성기가 놓는다. 한 화면 최대 3(레벨 규칙).
##
## ▣ [2026-10-09 거미방 · 재정비] 그을음 → **그을음 거미**(디자인은 아스트라가 거미 생김새로 다시 그린다)
##   위 AI(잠복·추적·덮침·빛 경계 앞 멈춤·흰 빛에 탐·다시 태어남)는 **그대로 둔다**. 그 위에 한 가지 일을 더 준다:
##   · 거미줄 치기 — `거미줄들`(레벨이 지정한 자리)이 비어 있으면, 잠복 중 `엮기_간격` 뒤 그 자리 발밑으로 기어가
##     `엮는_시간` 동안 줄을 친다(엮으러감 → 엮음 → 돌아감). 다 쳐진 줄은 빛(반딧불 몹)을 가린다(거미줄.gd).
##     같은 자리에 두 번 치지 않는다 · 한 번에 `한번에_최대` 개까지만 · 플레이어가 다가오면 하던 일을 두고 쫓는다.
##   · 빛에 타면 `타면_줄도_삭음` — 이 거미가 친 줄이 삭아 내린다(빛이 다시 지나간다). 다시 태어나면 다시 친다.
##   → 플레이어는 '거미를 빛으로 꾀어 태워 줄을 걷는다' 또는 '줄이 없는 자리에서 빛을 쓴다' 를 고민한다.
##   거미줄들이 비어 있으면 예전 그을음과 똑같다(13 · 18 은 그대로).
## ============================================================================

const 폴더 := "res://assets/textures/props/신규기믹_v02/게임용/그을음/"
## [2026-10-09] Codex 원화 v01 거미 6자세(생성 도구 `거미v01` · 2배 · 원점 = 아래 가운데 발끝 · 머리 오른쪽)
const 거미_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/거미/"
const 거미_자세 := ["대기", "걸음A", "걸음B", "웅크림", "엮기", "움찔"]
const 시트정보 := preload("res://scripts/effects/잉크_시트정보.gd")
const C := 32.0

@export_range(2.0, 20.0, 0.5) var 깨어남_칸: float = 8.0
@export_range(4.0, 30.0, 0.5) var 포기_칸: float = 14.0
@export_range(0.3, 1.0, 0.01) var 속도_배: float = 0.68      ## 플레이어 달리기(390) 대비
@export_range(1.0, 4.0, 0.25) var 덮침_칸: float = 2.0
@export_range(1.0, 20.0, 0.5) var 다시_태어남: float = 6.0
## 처음 바라보는 쪽(+1 오른쪽 · −1 왼쪽). 그림 원본은 오른쪽을 본다.
@export_enum("왼쪽:-1", "오른쪽:1") var 방향: int = -1
## [2026-10-09] 생김새 — 거미(새 원화 · 기본) / 그을음(옛 연기 얼룩). AI·판정은 같다(그림만 바뀐다).
@export_enum("거미:0", "그을음:1") var 생김새: int = 0:
	set(v): 생김새 = v; queue_redraw()

@export_group("거미줄")
## [2026-10-09] 이 거미가 칠 거미줄 자리(거미줄.gd 노드). 비어 있으면 줄을 치지 않는다.
@export var 거미줄들: Array[NodePath] = []
@export_range(0.3, 6.0, 0.1) var 엮는_시간: float = 1.5
## 줄 하나를 치고(또는 둥지로 돌아오고) 다음 줄을 치러 가기까지 쉬는 시간(초).
@export_range(0.0, 10.0, 0.1) var 엮기_간격: float = 1.0
@export_range(1, 8) var 한번에_최대: int = 3
@export var 타면_줄도_삭음: bool = true

enum 상태 { 잠복, 깨어남, 추적, 웅크림, 덮침, 돌아감, 탐, 재, 엮으러감, 엮음 }   # 뒤 둘 = [2026-10-09] 거미줄
var 지금: 상태 = 상태.잠복

var _둥지 := Vector2.ZERO
var _t := 0.0             ## 지금 상태에 머문 시간
var _숨 := 0.0
var _그림: Dictionary = {}
var _판정: Area2D
var _발깊이 := 0.0
var _중력 := 1800.0
var _줄: Node2D = null          ## 지금 치러 가는(치는) 거미줄
var _움찔 := 0.0                ## > 0 이면 빛 앞에서 움찔한 그림(초)
var _막힌 := 0.0                ## 줄 자리로 못 가고 멈춰 있던 시간(빛·낭떠러지) — 오래면 포기


func _ready() -> void:
	for k in ["잠복", "깨어남", "기어감"]:
		var 경로: String = 폴더 + k + ".png"     # k 는 타입 없는 배열 원소 → := 로는 타입 추론이 안 된다
		_그림[k] = load(경로) if ResourceLoader.exists(경로) else null
	var 소 = 시트정보.시트.get("그을음_소멸", {})
	if not 소.is_empty():
		_그림["소멸"] = load(소["경로"])
	for k in 거미_자세:
		var 경로2: String = 거미_폴더 + k + ".png"
		_그림["거미_" + k] = load(경로2) if ResourceLoader.exists(경로2) else null
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_둥지 = global_position
	_숨 = fmod(absf(global_position.x) * 0.01, TAU)
	# 몸 — 지형(레이어 1)만 밟는다. 플레이어와는 서로 밀지 않는다(예외 등록 — 아래 _physics 첫 프레임)
	collision_layer = 0
	collision_mask = 1
	var 몸 := CollisionShape2D.new()
	var 캡 := RectangleShape2D.new()
	캡.size = Vector2(40, 30)
	몸.shape = 캡
	몸.position = Vector2(0, -15)
	add_child(몸)
	# 닿으면 즉사 — hazard 그룹 Area2D(월드.gd 가 겹침만 본다). 잠복 중엔 끈다(얼룩은 밟아도 안 죽는다 — 대신 깨어난다).
	_판정 = Area2D.new()
	_판정.collision_layer = 0
	_판정.collision_mask = 1
	_판정.monitorable = false
	var 판 := CollisionShape2D.new()
	var 판모양 := RectangleShape2D.new()
	# [2026-10-09] 거미 원화(폭 150 · 키 78)에 맞춰 넓혔다 — 다리 끝(얇다)은 빼고 몸통+안쪽 다리까지(억울함 방지)
	판모양.size = Vector2(96, 46) if 생김새 == 0 else Vector2(70, 40)
	판.shape = 판모양
	판.position = Vector2(0, -24)
	_판정.add_child(판)
	add_child(_판정)
	_판정.monitoring = false
	_판정.add_to_group("hazard")
	add_to_group("그을음")
	# 쳅터1 목재 바닥 위에서는 발을 상판 가운데(+7)에 그린다(플레이어와 같은 2.5D 문법)
	var 씬 := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	_발깊이 = 7.0 if 씬.contains("쳅터1") else 0.0


func _플레이어() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _physics_process(delta: float) -> void:
	var p := _플레이어()
	if p and not is_instance_valid(p):
		p = null
	if p and not _예외됨:
		add_collision_exception_with(p)
		_예외됨 = true
	_t += delta
	_숨 += delta
	_움찔 = maxf(_움찔 - delta, 0.0)
	# 멀리 있으면(두 화면 밖) 잠복·재 말고는 생각하지 않는다 — 성능
	var 거리 := global_position.distance_to(p.global_position) if p else INF
	# ── 빛: 깨어 있든 자든, 빛 안에 들어오면(빛이 켜지면) 탄다 ──
	if 지금 != 상태.탐 and 지금 != 상태.재 and _빛에_닿나(global_position):
		_상태(상태.탐)
	match 지금:
		상태.잠복:
			velocity = Vector2.ZERO
			if p and 거리 < 깨어남_칸 * C and _플레이어_살아있나(p) and not _빛에_닿나(p.global_position + Vector2(0, -48)):
				_상태(상태.깨어남)
			elif _t >= 엮기_간격:
				# [2026-10-09] 쉬는 동안 칠 줄이 있으면 치러 간다
				_줄 = _칠_줄()
				if _줄:
					_상태(상태.엮으러감)
		상태.엮으러감:
			if _깨울_만큼_가깝나(p, 거리):
				_상태(상태.추적)
			elif _줄 == null or not is_instance_valid(_줄) or _줄.call("완성"):
				_상태(상태.돌아감)
			else:
				var dx3: float = float(_줄.call("발_x")) - global_position.x
				if absf(dx3) < 8.0:
					_상태(상태.엮음)
				else:
					방향 = 1 if dx3 > 0 else -1
					var 전 := global_position.x
					_걷기(방향 * 390.0 * 속도_배 * 0.6, delta)
					# 빛 경계·낭떠러지에 막혀 못 가면 4초 뒤 포기하고 둥지로(다음 기회에 다시)
					_막힌 = _막힌 + delta if absf(global_position.x - 전) < 0.2 else 0.0
					if _막힌 > 4.0:
						_막힌 = 0.0
						_상태(상태.돌아감)
		상태.엮음:
			velocity = Vector2.ZERO
			if _깨울_만큼_가깝나(p, 거리):
				_상태(상태.추적)
			elif _줄 == null or not is_instance_valid(_줄):
				_상태(상태.돌아감)
			elif _줄.call("엮기", delta / 엮는_시간):
				_상태(상태.돌아감)
		상태.깨어남:
			if _t >= 0.5:
				_상태(상태.추적)
		상태.추적:
			if p == null or 거리 > 포기_칸 * C or not _플레이어_살아있나(p):
				_상태(상태.돌아감)
			else:
				var dx := p.global_position.x - global_position.x
				방향 = 1 if dx > 0 else -1
				if absf(dx) < 덮침_칸 * C and absf(p.global_position.y - global_position.y) < 80.0:
					_상태(상태.웅크림)
				else:
					_걷기(방향 * 390.0 * 속도_배, delta)
		상태.웅크림:
			velocity.x = 0.0
			if _t >= 0.3:
				_상태(상태.덮침)
				velocity = Vector2(방향 * 560.0, -260.0)
		상태.덮침:
			velocity.y += _중력 * delta
			move_and_slide()
			if _t > 0.15 and is_on_floor():
				_상태(상태.추적)
		상태.돌아감:
			var dx2 := _둥지.x - global_position.x
			if absf(dx2) < 8.0:
				_상태(상태.잠복)
			else:
				방향 = 1 if dx2 > 0 else -1
				_걷기(방향 * 390.0 * 속도_배 * 0.6, delta)
				if p and 거리 < 깨어남_칸 * C * 0.75 and _플레이어_살아있나(p):
					_상태(상태.추적)
		상태.탐:
			velocity = Vector2.ZERO
			if _t >= 0.4 + 0.5:          # 0.4초 지글거림 + 소멸 프레임 0.5초
				_상태(상태.재)
		상태.재:
			# 다시 태어나되, 플레이어가 둥지 바로 옆(3칸)에 서 있으면 기다린다 — 몸 위에서 생겨나 억울하게 죽지 않게
			# 둥지가 빛 안이면(누가 촛불을 켜 놓았으면) 다시 태어나지 않는다 — 태어나자마자 또 타는 되풀이를 막는다
			if _t >= 다시_태어남 and (p == null or p.global_position.distance_to(_둥지) > 3.0 * C) and not _빛에_닿나(_둥지):
				global_position = _둥지
				_상태(상태.잠복)
	queue_redraw()


var _예외됨 := false


## [2026-10-09] 줄 치는 중에도 플레이어가 깨어남 거리 안 · 어둠에 들어오면 쫓는다(잠복의 깨어남과 같은 조건).
func _깨울_만큼_가깝나(p: CharacterBody2D, 거리: float) -> bool:
	return p != null and 거리 < 깨어남_칸 * C and _플레이어_살아있나(p) and not _빛에_닿나(p.global_position + Vector2(0, -48))


## [2026-10-09] 다음에 칠 줄 — 목록 순서대로 아직 안 쳐진 첫 줄. 이미 다 쳐진 줄 수가 한번에_최대 이상이면 없음.
func _칠_줄() -> Node2D:
	var 쳐짐 := 0
	var 빈: Node2D = null
	for 경로 in 거미줄들:
		var w := get_node_or_null(경로) as Node2D
		if w == null or not w.has_method("엮기"):
			continue
		if w.call("완성"):
			쳐짐 += 1
		elif 빈 == null:
			빈 = w
	if 쳐짐 >= 한번에_최대:
		return null
	return 빈


## [2026-10-09] 이 거미의 줄들(시험·탈 때)
func _내_줄들() -> Array:
	var r := []
	for 경로 in 거미줄들:
		var w := get_node_or_null(경로)
		if w:
			r.append(w)
	return r


func _플레이어_살아있나(p: CharacterBody2D) -> bool:
	return p.is_physics_processing()


## 바닥을 따라 걷는다 — 앞이 낭떠러지거나 빛이면 멈춘다(그을음은 빛 경계 앞에서 머뭇거린다).
func _걷기(vx: float, delta: float) -> void:
	velocity.y += _중력 * delta
	var 앞 := global_position + Vector2(signf(vx) * 30.0, 0)
	var 막힘 := false
	if is_on_floor():
		var q := PhysicsRayQueryParameters2D.create(앞 + Vector2(0, -8), 앞 + Vector2(0, 40), 1)
		q.exclude = [get_rid()]
		if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
			막힘 = true                  # 낭떠러지
		if _빛에_닿나(앞 + Vector2(signf(vx) * 12.0, -16)):
			막힘 = true                  # 빛 경계
			_움찔 = 0.35                 # [2026-10-09] 그림: 빛 앞에서 움찔(거미 원화 '움찔')
	velocity.x = 0.0 if 막힘 else vx
	move_and_slide()


## 몸 세 점(발 가운데 · 몸통 · 머리 쪽)이 태우는 빛 안인가.
func _빛에_닿나(기준: Vector2) -> bool:
	var 점들 := [기준 + Vector2(0, -6), 기준 + Vector2(0, -24), 기준 + Vector2(방향 * 30.0, -20)]
	for n in get_tree().get_nodes_in_group("태우는빛"):
		if not n.has_method("빛_안인가"):
			continue
		for q in 점들:
			if n.call("빛_안인가", q):
				return true
	return false


func _상태(새: 상태) -> void:
	지금 = 새
	_t = 0.0
	# 깨어 있는 동안만 죽인다 — 잠복 얼룩·타는 중·재는 안 죽인다(줄 치러 다니는 거미도 깨어 있다)
	_판정.set_deferred("monitoring", 새 in [상태.깨어남, 상태.추적, 상태.웅크림, 상태.덮침, 상태.돌아감, 상태.엮으러감, 상태.엮음])
	visible = 새 != 상태.재
	if 새 != 상태.엮으러감:
		_막힌 = 0.0
	if 새 == 상태.탐:
		_재_뿌리기()
		# [2026-10-09] 치던 줄은 흩어지고, 친 줄은 (설정이면) 삭아 내린다 — 빛이 다시 지나간다
		if _줄 and is_instance_valid(_줄):
			_줄.call("덜친것_버리기")
		if 타면_줄도_삭음:
			for w in _내_줄들():
				if w.has_method("삭기"):
					w.call("삭기")


## 시험·촬영용
func 상태_이름() -> String:
	return 상태.keys()[지금]


# ── 그림 ─────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var 발 := Vector2(0, _발깊이)
	var 뒤집기 := 방향 < 0             # 원본은 오른쪽을 본다
	var 숨 := sin(_숨 * 2.1)
	if 생김새 == 0 and _그림.get("거미_대기") != null:
		_거미_그리기(발, 뒤집기, 숨)
		return
	if Engine.is_editor_hint():
		_자세("잠복", 발, Vector2(1, 1), 0.0, 1.0, 뒤집기)
		return
	match 지금:
		상태.잠복:
			# 숨쉬듯 부풀었다 가라앉는 얼룩 — 흰 눈은 원화에 있다(어둠 속 두 점)
			_자세("잠복", 발, Vector2(1.0 + 숨 * 0.03, 1.0 - 숨 * 0.06), 0.0, 1.0, 뒤집기)
		상태.깨어남:
			# 0.5초 예고: 얼룩이 솟아 선 자세로(겹쳐 바뀜) — "곧 온다"
			var k := clampf(_t / 0.5, 0.0, 1.0)
			_자세("잠복", 발, Vector2(1.0, 1.0 + k * 0.4), 0.0, 1.0 - k, 뒤집기)
			_자세("깨어남", 발, Vector2(0.85 + k * 0.15, 0.6 + k * 0.4), 0.0, k, 뒤집기)
		상태.추적, 상태.돌아감, 상태.엮으러감:
			# 기어가기 — 몸을 앞뒤로 출렁(납작 ↔ 길쭉)하며 살짝 기운다. 걸음 주기 ≈ 0.35초
			var 걸음 := sin(_t * 18.0)
			_자세("기어감", 발, Vector2(1.0 + 걸음 * 0.06, 1.0 - 걸음 * 0.08), 걸음 * 0.04, 1.0, 뒤집기)
		상태.웅크림:
			var k2 := clampf(_t / 0.3, 0.0, 1.0)
			_자세("기어감", 발, Vector2(1.0 - k2 * 0.12, 1.0 - k2 * 0.25), -0.08 * k2, 1.0, 뒤집기)
		상태.덮침:
			_자세("깨어남", 발, Vector2(1.15, 0.9), 0.25, 1.0, 뒤집기)
		상태.엮음:
			# [2026-10-09] 선 자세로 꽁무니에서 줄을 뽑아 올린다 — 줄 가운데까지 실 한 가닥(흔들림)
			var 흔2 := sin(_t * 9.0) * 0.04
			_자세("깨어남", 발, Vector2(1.0, 1.0 + 흔2), 0.0, 1.0, 뒤집기)
			if _줄 and is_instance_valid(_줄):
				var 목표: Vector2 = to_local(_줄.global_position.lerp(_줄.to_global(_줄.get("나")), 0.5))
				draw_line(Vector2(0, -30), 목표, Color(0.9, 0.9, 0.88, 0.7), 1.2, true)
		상태.탐:
			# 0.4초 지글거림(흔들림 + 하얗게 달아오름) → 소멸 8프레임
			if _t < 0.4:
				var 흔 := Vector2(randf_range(-2, 2), randf_range(-1, 1))
				_자세("기어감", 발 + 흔, Vector2.ONE, 0.0, 1.0, 뒤집기, Color(1.6, 1.6, 1.6))
			else:
				_소멸_그리기(clampf((_t - 0.4) / 0.5, 0.0, 0.999), 발, 뒤집기)


func _자세(이름: String, 발: Vector2, 크기배: Vector2, 기울기: float, 알파: float, 뒤집기: bool, 색: Color = Color.WHITE) -> void:
	var t: Texture2D = _그림.get(이름)
	if t == null or 알파 <= 0.01:
		if t == null:
			draw_circle(발 + Vector2(0, -16), 18.0, Color(0.05, 0.05, 0.05, 알파))
		return
	var 크기 := Vector2(t.get_size()) * 0.5 * 크기배
	var 가로 := -1.0 if 뒤집기 else 1.0
	# 발끝(그림 아래 가운데)을 원점에 두고 그린다 — 기울기는 발을 축으로
	draw_set_transform(발, 기울기 * 가로, Vector2(가로, 1.0))
	draw_texture_rect(t, Rect2(Vector2(-크기.x * 0.5, -크기.y), 크기), false, Color(색.r, 색.g, 색.b, 알파))
	draw_set_transform(Vector2.ZERO)


func _소멸_그리기(진행: float, 발: Vector2, 뒤집기: bool) -> void:
	var t: Texture2D = _그림.get("소멸")
	var 정보: Dictionary = 시트정보.시트.get("그을음_소멸", {})
	if t == null or 정보.is_empty():
		return
	var n: int = 정보["프레임"]
	var 칸: Vector2 = 정보["칸"]
	var 기준: Vector2 = 정보["기준"]
	var f := mini(int(진행 * n), n - 1)
	var 가로 := -1.0 if 뒤집기 else 1.0
	draw_set_transform(발, 0.0, Vector2(0.5 * 가로, 0.5))
	draw_texture_rect_region(t, Rect2(-기준, 칸), Rect2(Vector2(칸.x * f, 0), 칸))
	draw_set_transform(Vector2.ZERO)


## 탈 때 위로 흩날리는 재(잿빛 점) — 소멸 그림과 겹쳐 '빛에 타 버렸다' 를 만든다
func _재_뿌리기() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 18
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(36, 14)
	p.position = Vector2(0, -24)
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.45, 0.44, 0.42, 0.8)
	p.z_index = 3
	p.finished.connect(p.queue_free)
	add_child(p)
	p.emitting = true


# ── [2026-10-09] 거미 그림 — 상태 → 원화 6자세(대기 · 걸음A/B · 웅크림 · 엮기 · 움찔) ──────────────────────
#   원화는 키포즈 6 장뿐이다(걸음 2 장 = 8 프레임 고리가 아니다 · Codex 기록) → 걸음은 A/B 를 번갈아 끼우고 몸을 살짝 출렁여
#   걷는 느낌을 낸다. 타서 사라지는 시트는 없다 → 움찔 자세가 하얗게 달아올랐다가 작아지며 흐려지고 재가 흩날린다(코드).
func _거미_그리기(발: Vector2, 뒤집기: bool, 숨: float) -> void:
	if Engine.is_editor_hint():
		_자세("거미_웅크림", 발, Vector2.ONE, 0.0, 1.0, 뒤집기, Color(0.75, 0.75, 0.75))
		return
	var 어둠 := Color(0.62, 0.62, 0.62)          # 잠든 거미는 어둠에 묻혀 있다(깨면 제 밝기)
	if _움찔 > 0.0 and 지금 in [상태.추적, 상태.돌아감, 상태.엮으러감]:
		var 떨 := Vector2(sin(_t * 70.0) * 1.5, 0)
		_자세("거미_움찔", 발 + 떨, Vector2.ONE, -0.05, 1.0, 뒤집기)
		return
	match 지금:
		상태.잠복:
			_자세("거미_웅크림", 발, Vector2(1.0 + 숨 * 0.015, 1.0 - 숨 * 0.03), 0.0, 1.0, 뒤집기, 어둠)
		상태.깨어남:
			# 0.5초 예고: 웅크렸다 일어선다(겹쳐 바뀜) + 밝아짐 — "곧 온다"
			var k := clampf(_t / 0.5, 0.0, 1.0)
			var 밝 := 어둠.lerp(Color.WHITE, k)
			_자세("거미_웅크림", 발, Vector2.ONE, 0.0, 1.0 - k, 뒤집기, 밝)
			_자세("거미_대기", 발, Vector2(1.0, 0.9 + k * 0.1), 0.0, k, 뒤집기, 밝)
		상태.추적, 상태.돌아감, 상태.엮으러감:
			# 걸음 A/B 번갈이(0.09초) · 몸통 출렁 — 빠를수록 촘촘(추적 0.68배 기준)
			var 걸음 := int(_t / 0.09) % 2
			var 출렁 := absf(sin(_t * 35.0)) * 0.03
			_자세("거미_걸음A" if 걸음 == 0 else "거미_걸음B", 발, Vector2(1.0, 1.0 - 출렁), 0.0, 1.0, 뒤집기)
		상태.웅크림:
			var k2 := clampf(_t / 0.3, 0.0, 1.0)
			_자세("거미_웅크림", 발, Vector2(1.0 + k2 * 0.05, 1.0 - k2 * 0.12), -0.05 * k2, 1.0, 뒤집기)
		상태.덮침:
			_자세("거미_대기", 발, Vector2(1.1, 0.92), 0.22, 1.0, 뒤집기)
		상태.엮음:
			var 흔2 := sin(_t * 9.0) * 0.03
			_자세("거미_엮기", 발, Vector2(1.0, 1.0 + 흔2), 0.0, 1.0, 뒤집기)
			if _줄 and is_instance_valid(_줄):
				var 목표: Vector2 = to_local(_줄.global_position.lerp(_줄.to_global(_줄.get("나")), 0.5))
				var 꽁무니 := Vector2(-40.0 if not 뒤집기 else 40.0, -46.0)
				draw_line(꽁무니, 목표, Color(0.9, 0.9, 0.88, 0.7), 1.2, true)
		상태.탐:
			# 0.4초 하얗게 달아오르며 지글 → 0.5초 작아지며 흐려짐(재는 _재_뿌리기 입자)
			if _t < 0.4:
				var 흔 := Vector2(randf_range(-2, 2), randf_range(-1, 1))
				var 달 := 1.0 + 0.8 * (_t / 0.4)
				_자세("거미_움찔", 발 + 흔, Vector2.ONE, 0.0, 1.0, 뒤집기, Color(달, 달, 달))
			else:
				var k3 := clampf((_t - 0.4) / 0.5, 0.0, 1.0)
				_자세("거미_움찔", 발, Vector2(1.0 - k3 * 0.35, 1.0 - k3 * 0.6), 0.0, 1.0 - k3, 뒤집기, Color(1.8, 1.8, 1.8))
