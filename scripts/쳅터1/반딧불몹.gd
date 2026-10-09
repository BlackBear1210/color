@tool
extends Area2D
## ============================================================================
## [2026-10-09 Claude 신규] 반딧불 몹 — 돌아다니다 벽에 붙어 흰 빛을 내는 '움직이는 광원' (거미방 · 도형님 10-09 지시)
## ----------------------------------------------------------------------------
## ▣ 도형님: "반딧불이처럼 불을 밝히는 몹 … 돌아다니며 일정한 거리마다 벽에 붙어서 빛을 내는 거야. 빛은 창문 장치에
##   작용하는 것처럼 흰색으로 나올 거야. 플레이어는 빛의 색을 반전시키거나 몹에게 색을 입힐 수 있는 대신 색이 변한 시간이
##   짧고 그 시간이 지나면 다시 이동하다가 멈춰서 색을 내는 거야."
##   (기존 `반딧불이.gd` 는 길목을 알려 주는 장식 — 판정이 없다. 이것은 별개의 몹이다.)
##
## ▣ 한 바퀴(상태 머신)
##   이동 ─도착→ 붙음(0.35초 · 날개 접기 · 빛이 차오름) → 빛냄(`머묾` 초) → 떠남(빛이 꺼짐 0.4초) → 다음 정지점으로 이동 …
##   · 물감을 맞으면 → 색바뀜: 붙은 채 그 색 빛을 `색_시간` 초 낸다(끝나기 0.6초 전부터 깜빡여 예고).
##     시간이 다 되면 흰색으로 돌아오고, 흰 빛을 0.8초 더 낸 뒤 떠난다 → 다음 정지점에서 다시 흰 빛.
##   · 이동 중에 맞으면 몸 색만 바뀐 채 계속 날아간다(색 시간은 그대로 흐른다 · 경로·정지 시간은 안 바뀐다).
##   · 새장: `새장_멈춤` 정지점에 레버(`새장_레버`)가 켜져 있으면 그 자리에서 떠나지 못한다(레버를 끄면 다시 돈다).
##
## ▣ 빛 = 게임 규칙(판정)과 그림을 나눈다 — 지시서 "Light2D 색만 바꾸고 판정은 안 바꾸는 식 금지"
##   · 판정: `빛_도달(점)` 하나가 전부다. 켜짐(다 차오름) · 반경 안 · **거미줄(그룹 "빛막이")에 안 가림** ·
##     지형(레이어 1)에 안 가림 → 지금 빛 색(논리값 ColorDefs). 아니면 −1.
##       - 월드.gd `_사망_판정`(그룹 "색빛" · `위험한가`) : 빛 안에서 몸 색 ≠ 빛 색 → 사망(창문빛·색레이저와 같은 규칙)
##       - 빛받이(그룹 "광원몹") : 요구색과 같은 빛이 닿으면 켜짐
##       - 그을음 거미(그룹 "태우는빛" · `빛_안인가`) : **흰 빛**만 태운다(검은 빛은 태우지 않는다 — 그을음 기둥과 같은 규칙)
##   · 그림: 같은 판정으로 쏜 광선 부채(40줄)를 그대로 칠한다 → 보이는 빛 = 판정 범위(거미줄 뒤는 그림자).
##     광원 노드(PointLight2D)는 쓰지 않는다 — 한 지형에 겹치는 광원 한계(15) 예산.
##
## ▣ 물감 = 페인트 코어 계약(창문커튼·양동이와 같은 문)
##   총알(Area 레이어 16 을 본다)이 이 Area 의 `명중(색, 좌표)` 를 부른다.
##   · 흰(기본)과 다른 색 → "painted"(코어가 E 회수줄에 올린다) · 시간이 다 되면 `코어.부분_자동회수()` 로 물감을 돌려준다.
##   · 같은 색 · 흰 물감 → "wasted"(물감 환급). 흰 물감은 칠해 둔 색을 바로 되돌린다.
##   · 다시 맞혀도 시간이 늘지 않는다(같은 색 = 낭비) · 타이머는 변수 하나라 겹쳐 돌지 않는다.
##   player.gd · gun.gd · bullet.gd 는 건드리지 않는다.
##
## ▣ 그림: 임시 코드 그림(몸통·빛나는 배·날개). 아스트라 그림이 오면 `그림_폴더` 에 `몸.png`(붙음) · `날개.png` 를 넣으면 그걸 쓴다.
## ▣ 놓는 법: 노드 위치 = 기준점. `멈춤들` = 기준점에서의 정지점(첫 칸이 시작). 도안 {"종류": "반딧불몹", "멈춤": [[x,y], …]}.
## ============================================================================

const C := 32.0
const 광선수 := 40

## 정지점들(노드 기준 로컬 px). 첫 정지점에서 빛을 내며 시작한다.
@export var 멈춤들: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(256, 0)]):
	set(v): 멈춤들 = v; queue_redraw()
## 정지점을 도는 방식 — 고리(0→1→2→0) / 왕복(0→1→2→1→0)
@export_enum("고리:0", "왕복:1") var 순환: int = 0
@export_range(30.0, 600.0) var 속도: float = 150.0
## 붙어서 빛을 내는 시간(초).
@export_range(0.5, 20.0, 0.1) var 머묾: float = 3.0
## 빛 반경(px) — 판정과 그림이 같은 값.
@export_range(64.0, 480.0) var 반경: float = 200.0:
	set(v): 반경 = v; queue_redraw()
## 물감으로 바뀐 색이 유지되는 시간(초).
@export_range(1.0, 30.0, 0.5) var 색_시간: float = 5.0
## 날아다니는 동안에도 빛을 내나(기본 꺼짐 — 붙어 있을 때만 빛).
@export var 이동중_빛: bool = false
## 빛 안의 몸 색을 판정하나(창문빛 규칙). 끄면 순수 광원(빛받이·거미에만 작용).
@export var 색_판정: bool = true

@export_group("새장")
## 이 정지점(번호)에 새장이 있다. −1 = 없음.
@export var 새장_멈춤: int = -1:
	set(v): 새장_멈춤 = v; queue_redraw()
## 새장을 닫는 레버(벽레버). 켜져 있으면 반딧불이 새장 정지점에서 떠나지 못한다.
@export var 새장_레버: NodePath

@export_group("그림")
@export_dir var 그림_폴더: String = "res://assets/textures/props/신규기믹_v02/게임용/반딧불몹/"

enum 상태 { 이동, 붙음, 빛냄, 색바뀜, 떠남 }
var 지금: 상태 = 상태.붙음
var 빛색: int = ColorDefs.WHITE        ## 논리 색(판정용). 그림 색은 여기서 만든다.
const 기본색 := ColorDefs.WHITE

var _기준 := Vector2.ZERO               ## 정지점 기준(전역) — 몸이 움직여도 고정
var _번호 := 0                          ## 지금(또는 향하는) 정지점
var _왕복_방향 := 1
var _t := 0.0                           ## 지금 상태에 머문 시간
var _머문 := 0.0                        ## 빛냄에서 센 시간(새장이면 멈춘다)
var _세기 := 0.0                        ## 빛 차오름 0~1 (1 일 때만 판정)
var _색남음 := 0.0                      ## 물감 색 남은 시간
var _전환 := 0.0                        ## 색이 막 바뀐 뒤 판정을 쉬는 시간(빛이 갈아입는 0.3초)
var _칠한발수 := 0                      ## 코어에 돌려줄 물감
var _부채 := PackedVector2Array()       ## 광선 끝점(로컬) — 그림용(판정과 같은 가림)
var _부채_t := 0.0
var _날개 := 0.0
var _코어: Node = null
var _그림: Dictionary = {}


func _ready() -> void:
	_그림_읽기()
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_기준 = global_position
	global_position = _정지점(0)
	_번호 = 0
	_상태(상태.붙음)
	# 총알이 찾는 문 — 레이어 16(칠할 수 있는 통과형 오브젝트 · 총알.gd 물리 레이어 약속). 몸은 아무것도 안 민다.
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	var 모양 := CollisionShape2D.new()
	var 원 := CircleShape2D.new()
	원.radius = 26.0
	모양.shape = 원
	add_child(모양)
	add_to_group("광원몹")      # 빛받이가 묻는다
	add_to_group("색빛")        # 월드 사망 판정(창문빛 규칙)
	add_to_group("태우는빛")    # 그을음 거미(흰 빛만)
	add_to_group("부활복구")
	z_index = 15
	_코어 = get_tree().get_first_node_in_group("페인트코어")


func _그림_읽기() -> void:
	# [2026-10-09] Codex 원화 v01 4상태(생성 도구 `반딧불v01` · 2배 · 원점 = 그림 가운데 · 머리 위)
	for k in ["붙음_흰", "붙음_검", "비행_흰", "비행_검"]:
		var 경로: String = 그림_폴더.path_join(k + ".png")
		_그림[k] = load(경로) if ResourceLoader.exists(경로) else null


func _정지점(i: int) -> Vector2:
	if 멈춤들.is_empty():
		return _기준
	return _기준 + 멈춤들[clampi(i, 0, 멈춤들.size() - 1)]


func _다음_번호() -> int:
	var n := 멈춤들.size()
	if n <= 1:
		return 0
	if 순환 == 0:
		return (_번호 + 1) % n
	var 다음 := _번호 + _왕복_방향
	if 다음 < 0 or 다음 >= n:
		_왕복_방향 = -_왕복_방향
		다음 = _번호 + _왕복_방향
	return 다음


func _상태(새: 상태) -> void:
	지금 = 새
	_t = 0.0
	if 새 == 상태.빛냄:
		_머문 = 0.0


func _새장_닫힘() -> bool:
	if 새장_멈춤 < 0 or _번호 != 새장_멈춤:
		return false
	var l := get_node_or_null(새장_레버)
	return l != null and bool(l.get("켜짐"))


func _physics_process(delta: float) -> void:
	_t += delta
	_날개 += delta
	_전환 = maxf(_전환 - delta, 0.0)
	# ── 물감 색 시계(상태와 따로 흐른다 — 이동 중에 맞아도 줄어든다) ──
	if 빛색 != 기본색:
		_색남음 -= delta
		if _색남음 <= 0.0:
			_원래대로(true)
			if 지금 == 상태.색바뀜:
				# 흰 빛을 0.8초 더 낸 뒤 떠난다(새장이면 계속 빛냄) — 돌아온 흰 빛이 '보이게'
				_상태(상태.빛냄)
				_머문 = maxf(머묾 - 0.8, 0.0)
	match 지금:
		상태.이동:
			var 목표 := _정지점(_번호)
			var 남은 := 목표 - global_position
			var 걸음 := 속도 * delta
			if 남은.length() <= 걸음:
				global_position = 목표
				_상태(상태.붙음)
			else:
				global_position += 남은.normalized() * 걸음
			_세기 = move_toward(_세기, 1.0 if 이동중_빛 else 0.0, delta / 0.4)
		상태.붙음:
			# 붙는 연출과 상관없이 0.35초면 반드시 다음 상태로(애니메이션 때문에 영원히 멈추지 않게)
			_세기 = move_toward(_세기, 1.0, delta / 0.5)
			if _t >= 0.35:
				_상태(상태.색바뀜 if 빛색 != 기본색 else 상태.빛냄)
		상태.빛냄:
			_세기 = move_toward(_세기, 1.0, delta / 0.5)
			if not _새장_닫힘():
				_머문 += delta
			if _머문 >= 머묾:
				_상태(상태.떠남)
		상태.색바뀜:
			_세기 = move_toward(_세기, 1.0, delta / 0.5)
		상태.떠남:
			_세기 = move_toward(_세기, 0.0, delta / 0.4)
			if _t >= 0.4:
				_번호 = _다음_번호()
				_상태(상태.이동)
	# 광선 부채(그림용) — 빛이 있을 때만 0.2초마다. 거미줄이 쳐지거나 문이 움직여도 곧 따라간다.
	_부채_t -= delta
	if _세기 > 0.01 and _부채_t <= 0.0:
		_부채_t = 0.2
		_부채_만들기()
	queue_redraw()


# ============================================================================
# 빛 판정 — 이 몹의 모든 규칙이 이 함수 하나를 거친다
# ============================================================================
## 그 전역 점에 지금 이 몹의 빛이 닿나 → 닿으면 빛 색(ColorDefs), 아니면 −1.
func 빛_도달(점: Vector2) -> int:
	if Engine.is_editor_hint() or _세기 < 0.999 or _전환 > 0.0:
		return -1
	if global_position.distance_squared_to(점) > 반경 * 반경:
		return -1
	if 가려졌나(global_position, 점):
		return -1
	return 빛색


## 빛이 지나가는 선분이 거미줄·지형에 가렸나. (빛받이·다른 광원도 같은 규칙을 쓰라고 정적 함수처럼 둔다)
func 가려졌나(시작: Vector2, 끝: Vector2) -> bool:
	for w in get_tree().get_nodes_in_group("빛막이"):
		if w.has_method("가리나") and w.call("가리나", 시작, 끝):
			return true
	# 지형(레이어 1) — 물리 레이캐스트는 '처음 맞은 것' 만 준다. 그래서 거미줄은 위에서 선분으로 따로 보고,
	#   여기는 지형만 본다(플레이어 몸은 빼고 — 몸이 빛을 가리면 자기 몸에 빛이 안 닿는다).
	var q := PhysicsRayQueryParameters2D.create(시작, 끝, 1)
	q.collide_with_areas = false
	var p := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if p:
		q.exclude = [p.get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## [2026-10-10 Claude] 이 몹이 **언젠가** 빛을 비출 수 있는 자리인가 — 어느 정지점이든 반경 안(지금 상태·가림은 안 본다).
##   월드.gd 안전지점 자동 저장이 묻는다: 빛이 꺼진 사이 그 아래에 저장되면, 다음에 죽었을 때
##   반딧불이 빛내는 한가운데로 되살아나 또 죽는다(시험_열쇠_반딧불_추가 에서 실제로 잡힘).
func 빛_닿을_수_있나(월드점: Vector2) -> bool:
	if 멈춤들.is_empty():
		return global_position.distance_squared_to(월드점) <= 반경 * 반경
	for i in 멈춤들.size():
		if _정지점(i).distance_squared_to(월드점) <= 반경 * 반경:
			return true
	return false


## 그을음 거미가 묻는다(그룹 "태우는빛") — 흰 빛만 태운다.
func 빛_안인가(월드점: Vector2) -> bool:
	return 빛_도달(월드점) == ColorDefs.WHITE


## 월드.gd `_사망_판정` 이 묻는다(그룹 "색빛") — 몸 어디든 이 빛 안에 있고 몸 색이 빛 색과 다르면 위험.
func 위험한가(플레이어: Node) -> bool:
	if not 색_판정 or not (플레이어 is Node2D):
		return false
	var 몸 := (플레이어 as Node2D).global_position
	for dy in [-8.0, -48.0, -88.0]:          # 발 · 허리 · 머리
		var c := 빛_도달(몸 + Vector2(0, dy))
		if c >= 0:
			return int(플레이어.get("player_color")) != c
	return false


# ============================================================================
# 물감(페인트 코어 계약)
# ============================================================================
func 현재색() -> int:
	return 빛색


func 명중(색: int, _월드좌표: Vector2) -> String:
	if 색 == 빛색:
		return "wasted"                     # 같은 색 — 시간도 안 늘어난다(물감은 돌아간다)
	if 색 == 기본색:
		# 흰 물감 = 칠해 둔 색을 지금 걷어 낸다(그 물감은 돌려준다)
		_원래대로(true)
		if 지금 == 상태.색바뀜:
			_상태(상태.빛냄)
			_머문 = maxf(머묾 - 0.8, 0.0)
		return "wasted"
	빛색 = 색
	_색남음 = 색_시간
	_칠한발수 += 1
	_전환 = 0.3                              # 빛이 갈아입는 동안(0.3초)은 판정을 쉰다 — 쏘자마자 억울하게 죽지 않게
	if 지금 in [상태.붙음, 상태.빛냄]:
		_상태(상태.색바뀜)
	queue_redraw()
	return "painted"


## [2026-10-10] 총 조준선(우클릭)이 묻는다(총.gd `_칠_가능`) — 이 색 물감이 빛을 바꾸나.
##   지금 빛과 같은 색이면 낭비 → 조준선 끝에 빨간 X(흰 빛 안에서 흰 물감을 쏘면 소용없다는 걸 쏘기 전에 보여 준다).
func 칠_가능_미리보기(색: int) -> bool:
	return 색 != 빛색


## E 수동 회수 — 칠해 둔 색을 거둬들인다(코어가 물감을 돌려준다).
func 되돌리기() -> bool:
	if 빛색 == 기본색:
		return false
	_칠한발수 = 0                          # 코어가 회수줄 발수만큼 돌려준다 — 여기서 또 돌려주지 않게
	_원래대로(false)
	if 지금 == 상태.색바뀜:
		_상태(상태.빛냄)
		_머문 = maxf(머묾 - 0.8, 0.0)
	return true


func _원래대로(환급: bool) -> void:
	빛색 = 기본색
	_색남음 = 0.0
	if 환급 and _칠한발수 > 0 and _코어 and is_instance_valid(_코어) and _코어.has_method("부분_자동회수"):
		_코어.call("부분_자동회수", self, _칠한발수)
	_칠한발수 = 0


## 월드 `_리스폰` — 죽으면 칠해 둔 색은 걷힌다(물감도 돌아간다). 도는 길은 그대로 이어 간다.
func 부활_복구() -> void:
	if 빛색 != 기본색:
		_원래대로(true)
		if 지금 == 상태.색바뀜:
			_상태(상태.빛냄)


## 시험·촬영용
func 상태_이름() -> String:
	return 상태.keys()[지금]


func 정지점_번호() -> int:
	return _번호


func 남은_색시간() -> float:
	return maxf(_색남음, 0.0)


# ============================================================================
# 그림
# ============================================================================
func _부채_만들기() -> void:
	var 끝들 := PackedVector2Array()
	var o := global_position
	var 공간 := get_world_2d().direct_space_state
	var p := get_tree().get_first_node_in_group("player") as CollisionObject2D
	var 막이들 := get_tree().get_nodes_in_group("빛막이")
	for i in 광선수:
		var 각 := TAU * float(i) / float(광선수)
		var 끝 := o + Vector2(cos(각), sin(각)) * 반경
		var q := PhysicsRayQueryParameters2D.create(o, 끝, 1)
		q.collide_with_areas = false
		if p:
			q.exclude = [p.get_rid()]
		var hit := 공간.intersect_ray(q)
		if not hit.is_empty():
			끝 = hit.position
		for w in 막이들:
			if not w.has_method("완성") or not w.call("완성"):
				continue
			var a: Vector2 = (w as Node2D).global_position
			var b: Vector2 = (w as Node2D).to_global(w.get("나"))
			var x: Variant = Geometry2D.segment_intersects_segment(o, 끝, a, b)
			if x != null:
				끝 = x
		끝들.append(끝 - o)
	_부채 = 끝들


func _draw() -> void:
	if Engine.is_editor_hint():
		_에디터_그림()
		return
	var 바뀜 := 빛색 != 기본색
	var 깜빡 := 바뀜 and _색남음 < 0.6 and int(_색남음 * 10.0) % 2 == 0     # 끝나기 0.6초 전 예고
	var 그림색 := 빛색
	if 깜빡:
		그림색 = 기본색
	# ── 빛(판정과 같은 가림으로 쏜 광선 부채) ──
	if _세기 > 0.01 and _부채.size() == 광선수:
		var 가운데 := Color(1.0, 0.98, 0.9, 0.30 * _세기) if 그림색 == ColorDefs.WHITE else Color(0.0, 0.0, 0.0, 0.5 * _세기)
		var 바깥 := Color(가운데.r, 가운데.g, 가운데.b, 0.0)
		if _전환 > 0.0:
			가운데.a *= 0.4 + 0.6 * absf(sin(_t * 40.0))
		for i in 광선수:
			var a := _부채[i]
			var b := _부채[(i + 1) % 광선수]
			draw_primitive(PackedVector2Array([Vector2.ZERO, a, b]), PackedColorArray([가운데, 바깥, 바깥]), PackedVector2Array())
		# 판정 경계선 — 어디까지가 빛인지(색 규칙이 걸리는 곳) 또렷하게
		var 선 := _부채.duplicate()
		선.append(_부채[0])
		var 선색 := Color(1, 1, 0.92, 0.35 * _세기) if 그림색 == ColorDefs.WHITE else Color(0.05, 0.05, 0.05, 0.6 * _세기)
		draw_polyline(선, 선색, 2.0, true)
	# ── 새장(정지점에 매달린 유리 등갓) ──
	if 새장_멈춤 >= 0:
		_새장_그리기(to_local(_정지점(새장_멈춤)), _새장_닫힘())
	# ── 몸 ──
	_몸_그리기(Vector2.ZERO, 그림색, 지금 == 상태.이동 or (지금 == 상태.떠남 and _t > 0.2))
	# 물감 시계 — 몸 둘레 고리가 줄어든다
	if 바뀜:
		var k := clampf(_색남음 / 색_시간, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(0.95, 0.85, 0.4, 0.9), 3.0, true)


func _몸_그리기(o: Vector2, 그림색: int, 나는중: bool) -> void:
	var 흔들 := Vector2(0, sin(_날개 * 6.0) * 3.0) if 나는중 else Vector2.ZERO
	var c := o + 흔들
	var 배색 := Color(1.0, 0.97, 0.8) if 그림색 == ColorDefs.WHITE else Color(0.06, 0.06, 0.07)
	var 테두리 := Color(0.2, 0.19, 0.17) if 그림색 == ColorDefs.WHITE else Color(0.85, 0.85, 0.82)
	# [2026-10-09] 원화 — 붙음/비행 × 흰 배/검은 배 를 고른다(몸 전체를 어둡게 하지 않고 배 끝만 다른 그림 · Codex 안내).
	#   날 때는 날개 퍼덕임 대신 세로로 살짝 눌렀다 폈다(날갯짓 박자) + 가는 쪽으로 기운다. 빛이 꺼져 있으면 배를 조금 어둡게.
	var 키 := ("비행_" if 나는중 else "붙음_") + ("흰" if 그림색 == ColorDefs.WHITE else "검")
	var 몸 := _그림.get(키) as Texture2D
	if 몸:
		var 크기 := 몸.get_size() * 0.5
		var 눌 := Vector2(1.0, 1.0 - 0.08 * absf(sin(_날개 * 30.0))) if 나는중 else Vector2.ONE
		var 기울 := 0.0
		if 나는중:
			var 목표 := _정지점(_번호) - global_position
			기울 = clampf(목표.x / 600.0, -0.35, 0.35)
		var 밝 := 0.75 + 0.25 * _세기 if 그림색 == ColorDefs.WHITE else 1.0
		# 배 끝 은은한 빛무리(그림만) — 검은 껍질이 어두운 벽에 묻혀 안 보이던 것을 살린다. 검은 배는 흰 테만 남긴다.
		var 배 := c + Vector2(0, 크기.y * 0.32).rotated(기울)
		if 그림색 == ColorDefs.WHITE:
			draw_circle(배, 22.0, Color(1, 0.98, 0.9, 0.10 + 0.12 * _세기))
			draw_circle(배, 11.0, Color(1, 0.98, 0.9, 0.18 + 0.2 * _세기))
		else:
			draw_arc(배, 13.0, 0, TAU, 20, Color(0.9, 0.9, 0.88, 0.45), 1.5, true)
		draw_set_transform(c, 기울, 눌)
		draw_texture_rect(몸, Rect2(-크기 * 0.5, 크기), false, Color(밝, 밝, 밝))
		draw_set_transform(Vector2.ZERO)
		return
	# 날개 — 날 때는 빠르게 퍼덕이고, 붙으면 접는다
	var 펼침 := (0.5 + 0.5 * sin(_날개 * 40.0)) if 나는중 else 0.1
	for s in [-1.0, 1.0]:
		var 날개끝 := c + Vector2(s * (10.0 + 12.0 * 펼침), -14.0 + 6.0 * (1.0 - 펼침))
		draw_colored_polygon(PackedVector2Array([c + Vector2(s * 2, -6), 날개끝, c + Vector2(s * 6, 2)]), Color(0.75, 0.75, 0.78, 0.55))
	# 가슴·머리(어두운 껍질) + 빛나는 배(빛 색)
	draw_circle(c + Vector2(0, -8), 6.0, Color(0.12, 0.11, 0.1))
	draw_circle(c + Vector2(0, -15), 4.0, Color(0.12, 0.11, 0.1))
	draw_circle(c + Vector2(0, 4), 10.0 + _세기 * 1.5, 테두리)
	draw_circle(c + Vector2(0, 4), 8.5 + _세기 * 1.5, 배색)
	if not 나는중:
		# 붙었을 때 다리 — 벽을 붙잡은 짧은 선
		for s in [-1.0, 1.0]:
			draw_line(c + Vector2(s * 4, -6), c + Vector2(s * 12, -2), Color(0.12, 0.11, 0.1), 2.0)
			draw_line(c + Vector2(s * 5, 2), c + Vector2(s * 13, 8), Color(0.12, 0.11, 0.1), 2.0)


func _새장_그리기(o: Vector2, 닫힘: bool) -> void:
	var 놋 := Color(0.55, 0.45, 0.25)
	draw_rect(Rect2(o + Vector2(-24, -40), Vector2(48, 8)), 놋)
	draw_line(o + Vector2(0, -40), o + Vector2(0, -64), 놋, 3.0)
	var 살수 := 5 if 닫힘 else 2
	for i in 살수:
		var x := -22.0 + 44.0 * float(i) / float(maxi(살수 - 1, 1))
		draw_line(o + Vector2(x, -32), o + Vector2(x, 30), 놋.darkened(0.2), 2.0)
	draw_rect(Rect2(o + Vector2(-24, 28), Vector2(48, 6)), 놋)


func _에디터_그림() -> void:
	# 정지점·길·반경을 보여 준다(값이 바뀔 때만 다시 그림)
	var 앞 := Vector2.ZERO
	for i in 멈춤들.size():
		var p := 멈춤들[i]
		if i > 0:
			draw_dashed_line(앞, p, Color(1, 0.9, 0.5, 0.6), 2.0, 8.0)
		draw_arc(p, 반경, 0, TAU, 48, Color(1, 1, 0.85, 0.25), 1.5)
		draw_circle(p, 9.0, Color(1, 0.97, 0.8))
		draw_string(ThemeDB.fallback_font, p + Vector2(12, -10), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))
		if i == 새장_멈춤:
			_새장_그리기(p, true)
		앞 = p
