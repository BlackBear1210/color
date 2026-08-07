extends Node2D
## ============================================================================
## [2026-08-01 신규] 스마트월드 스테이지 매니저
## ----------------------------------------------------------------------------
## ▣ 이 노드가 스테이지 하나를 굴린다
##   · 카메라(ProtoCamera) 부착 + 리밋 설정
##   · 페인트 총 부착 (Player.tscn 은 손대지 않는다)
##   · 사망 판정 — 발밑 지형 / 유체 접촉
##   · 색 지대 판정 — 식물 B 가 만든 임시 지대
##   · E 키 중재 — 레버가 가까우면 레버 조작, 아니면 페인트 수동 회수
##   · HUD — 남은 페인트 / 회수 대기 / 현재 색
##
## ▣ 왜 stage_lab.gd 를 안 쓰고 새로 만들었나
##   stage_lab 은 PaintPlatform(v3, 384px 덩어리 아트) 전용으로 짜여 있어
##   SS2D 지형·식물·유체를 모른다. 기존 스테이지를 깨지 않으려면 건드리지 않는 게 맞다.
##   대신 **판정 문법(발밑 3점 레이캐스트, 리스폰, 카메라 부착)은 그대로 따랐다.**
## ============================================================================
class_name 스마트월드

const 카메라_스크립트 := preload("res://scripts/proto/proto_camera.gd")
const 총_스크립트 := preload("res://scripts/스마트월드/총.gd")
const 메뉴_스크립트 := preload("res://scripts/스마트월드/일시정지_메뉴.gd")
## [2026-08-06 추가] 낙하 거리 기반 즉사 판정기
const 낙하감시_스크립트 := preload("res://scripts/스마트월드/낙하_감시.gd")

@export var 스테이지_이름: String = "스마트월드 테스트"
## 카메라가 벗어나지 않을 범위. 비워두면(size 0) 리밋 없이 자유롭게 따라간다.
@export var 카메라_리밋: Rect2 = Rect2()
@export var 카메라_줌: float = 0.85
## 플레이어 시작 위치. 사망 시 여기로 돌아온다.
## ★[2026-08-06] 통로를 지나 들어온 경우에는 이 값 대신 입구 통로 위치에서 시작한다.
@export var 시작_위치: Vector2 = Vector2(200, 0)
## 이 y 아래로 떨어지면 사망 (낙사).
## ★[2026-08-06] 이제 **최후의 안전장치**일 뿐이다. 실제 낙사는 아래 `치명_낙하거리` 가 잡는다.
##   (지형이 뚫려 있어도 여기까지 떨어지기 전에 낙하 거리로 먼저 죽는다)
@export var 낙사_y: float = 1800.0

@export_group("낙하 사망")
## ★[2026-08-06 신규] 한 번에 이 거리(px) 이상 떨어지면 **즉시** 사망.
## 점프 높이가 160px 이므로 520 = 점프 3.25 회분. 0 이면 낙하 사망을 끈다.
@export var 치명_낙하거리: float = 520.0
## 낙하 경고 비네트(화면 가장자리 어두워짐)를 쓸지.
@export var 낙하_경고표시: bool = true

@export_group("리스폰")
## 켜면 "마지막으로 안전하게 서 있던 땅"을 자동 체크포인트로 삼는다.
## ★긴 스테이지에서 낙사할 때마다 처음으로 돌아가면 낙하 사망이 벌칙이 아니라 고문이 된다.
##   레인월드의 셸터처럼 "직전에 발 붙였던 곳"으로 돌려보내면 리듬이 끊기지 않는다.
@export var 안전지점_자동저장: bool = true
## 안전지점으로 인정하려면 이만큼(초) 계속 안전한 땅 위에 있어야 한다.
## 너무 짧으면 함정 바로 앞이 체크포인트가 되어 무한 사망 루프가 생긴다.
@export var 안전지점_유예: float = 0.45

var _플레이어: CharacterBody2D = null
var _코어: 페인트코어 = null
var _카메라: ProtoCamera = null
var _총: 페인트총 = null
var _낙하: 낙하감시 = null

var _hud_탄약: Label = null
var _hud_안내: Label = null
var _무적: float = 0.0                 ## 리스폰 직후 잠깐 무적 (즉사 반복 방지)
var _안전점: Vector2 = Vector2.ZERO    ## 자동 체크포인트 (마지막으로 안전하게 서 있던 곳)
var _안전_누적: float = 0.0            ## 그 자리에서 안전하게 버틴 시간


func _ready() -> void:
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
	_플레이어 = get_node_or_null("Player") as CharacterBody2D
	if _플레이어 == null:
		push_error("스마트월드: 자식으로 'Player' 가 있어야 한다")
		return

	# ── 시작 위치 결정 ──────────────────────────────────────────────────
	# ★[2026-08-06] 통로를 지나 들어왔다면 그 통로(입구) 안에서 걸어 나와야 한다.
	#   그냥 시작_위치에 세우면 "순간이동해서 나타났다"가 되어 통로를 만든 의미가 없다.
	_플레이어.global_position = _진입_위치_정하기()
	_안전점 = _플레이어.global_position

	# ── 카메라 ── (Player.tscn 안의 기본 Camera2D 는 끄고 ProtoCamera 를 쓴다)
	var 기본캠 := _플레이어.get_node_or_null("Camera2D") as Camera2D
	if 기본캠:
		기본캠.enabled = false
	_카메라 = 카메라_스크립트.new()
	_카메라.name = "카메라"
	add_child(_카메라)
	_카메라.setup(_플레이어)
	_카메라.set_region_zoom(카메라_줌, false)
	if 카메라_리밋.size.length() > 1.0:
		_카메라.set_limit_rect(카메라_리밋, false)

	# ── 총 ──
	_총 = 총_스크립트.new()
	_총.name = "페인트총"
	add_child(_총)
	_총.연결(_플레이어, _코어)

	# ── 플레이어 표시 정리 ──────────────────────────────────────────────
	# [2026-08-02] "플레이어가 파란 박스에 갇혀 보인다"는 제보의 근본 원인은
	# 빌더가 Player 인스턴스 내부를 복제해 Placeholder2 를 만든 것이었고 그건 고쳤다.
	# 다만 Placeholder 는 player.gd 가 색 표시에 계속 쓰는 노드라 씬에서 지울 수 없으므로,
	# 이름이 뭐가 됐든 Polygon2D 플레이스홀더는 여기서 한 번 더 확실히 숨긴다.
	# (player_anim.gd 도 "Placeholder"만 숨긴다 — 이름이 다르면 놓친다)
	for 자식 in _플레이어.get_children():
		if 자식 is Polygon2D:
			(자식 as Polygon2D).visible = false

	# ── 낙하 감시 ──────────────────────────────────────────────────────
	# [2026-08-06] "바닥이 뚫린 건 좋은데 일정 높이 이상 떨어지면 즉사" 규칙.
	# 좌표(낙사_y)가 아니라 **낙하 거리**로 재기 때문에, 깊은 수직 갱도를 만들어도
	# 계단식으로 내려가면 안전하고 한 번에 쭉 떨어지면 죽는다.
	_낙하 = 낙하감시_스크립트.new()
	_낙하.name = "낙하감시"
	_낙하.치명_낙하거리 = 치명_낙하거리
	_낙하.경고_표시 = 낙하_경고표시
	add_child(_낙하)
	_낙하.연결(_플레이어)

	_HUD_만들기()
	_메뉴_만들기()
	if _코어:
		_코어.탄약_변경.connect(_HUD_갱신)
		_HUD_갱신(_코어.남은_탄약, _코어.최대_탄약)


func _physics_process(delta: float) -> void:
	if _플레이어 == null:
		return
	# 통로를 지나 화면이 까매지는 동안에는 아무 판정도 하지 않는다.
	# (암전 중에 죽으면 다음 스테이지에서 갑자기 리스폰 지점에 서 있게 된다)
	if 장면전환.진행중인가():
		return
	_무적 = maxf(_무적 - delta, 0.0)

	_지대_적용()

	# 사망 판정은 레이캐스트 3발 + 유체 순회라 싸지 않다.
	# 아래 체크포인트 갱신에서도 같은 답이 필요하므로 **한 프레임에 한 번만** 계산한다.
	var 죽는가 := _사망_판정()

	if _무적 <= 0.0 and 죽는가:
		_리스폰()
		return
	# ★낙하 거리 초과 = 즉사 (착지를 기다리지 않는다)
	if _무적 <= 0.0 and _낙하 and _낙하.치명적인가():
		_리스폰()
		return
	# 최후의 안전장치 — 맵 밖으로 새어나갔을 때
	if _플레이어.global_position.y > 낙사_y:
		_리스폰()
		return

	_안전점_갱신(delta, 죽는가)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# ── E 중재 ── 레버가 손에 닿으면 레버가 우선 (기획: "가까이 다가가서 상호작용")
	for n in get_tree().get_nodes_in_group("제어레버"):
		var 레버 := n as 제어레버
		if 레버 and 레버.닿아있나():
			레버.조작()
			return
	# 레버가 없으면 평소대로 페인트 수동 회수 (FIFO)
	if _코어:
		_코어.수동_회수()


# ── 색 지대 ────────────────────────────────────────────────────────────────
## 식물 B 가 만든 임시 지대 안에 있으면 플레이어 색을 그 색으로 고정한다.
## 회색 지대는 고정하지 않는다 = 플레이어가 자유롭게 전환할 수 있다(기획).
func _지대_적용() -> void:
	var 목표 := -1
	for n in get_tree().get_nodes_in_group("식물B"):
		var b := n as 식물B
		if b == null:
			continue
		var c: int = b.지대색()
		if c < 0 or c == ColorDefs.GRAY:
			continue
		if b.안에_있나(_플레이어.global_position):
			목표 = c                       # 나중에 만난 지대가 이긴다
	if 목표 >= 0 and _플레이어.get("player_color") != 목표:
		# player.gd 무수정 원칙 — 흑/백 2색뿐이라 한 번 토글하면 반드시 목표색이 된다
		_플레이어.call("_toggle_color")


# ── 사망 판정 ──────────────────────────────────────────────────────────────
func _사망_판정() -> bool:
	var 색: int = _플레이어.get("player_color")

	# 1) 유체 접촉 — 반대색 물/연기에 닿으면 즉사
	for n in get_tree().get_nodes_in_group("유체"):
		var f := n as 유체
		if f == null or not f.켜짐 or not f.반대색인가(색):
			continue
		if f.get_overlapping_bodies().has(_플레이어):
			return true

	# 1-2) 색 레이저 — 빔 안에서 빔과 다른 색이면 즉사
	#      [2026-08-06] 유체와 달리 몸 전체가 닿는 판정이라 레이저 노드가 직접 판단한다.
	for n in get_tree().get_nodes_in_group("색레이저"):
		var 빔 := n as 색레이저
		if 빔 and 빔.위험한가(_플레이어):
			return true

	# 2) 발밑 지형 — 중앙 + 좌우 발끝 3점 레이캐스트
	#    (v3 stage_lab.gd 와 같은 문법. 발끝만 걸쳐도 판정되게 3점을 본다)
	var 공간 := _플레이어.get_world_2d().direct_space_state
	var 기준 := _플레이어.global_position
	for dx in [-16.0, 0.0, 16.0]:
		var 시작 := 기준 + Vector2(dx, -6.0)
		var 끝 := 기준 + Vector2(dx, 14.0)
		var q := PhysicsRayQueryParameters2D.create(시작, 끝, 1)
		q.exclude = [_플레이어.get_rid()]
		var r := 공간.intersect_ray(q)
		if not r:
			continue
		var 대상 := _반대색_대상_찾기(r.get("collider"))
		if 대상 != null and 대상.반대색인가(색):
			return true
	return false


func _반대색_대상_찾기(맞은것: Object) -> Node:
	var n := 맞은것 as Node
	while n != null:
		if n.has_method("반대색인가"):
			return n
		n = n.get_parent()
	return null


func _리스폰() -> void:
	if _카메라:
		_카메라.add_trauma(0.55)
	_플레이어.set("velocity", Vector2.ZERO)
	# [2026-08-06] 자동 체크포인트가 켜져 있으면 마지막 안전지점으로, 아니면 처음으로.
	_플레이어.global_position = _안전점 if 안전지점_자동저장 else 시작_위치
	_무적 = 0.6
	_안전_누적 = 0.0
	if _카메라:
		_카메라.setup(_플레이어)
	# 낙하 상태를 초기화하지 않으면 리스폰하자마자 "아직 떨어지는 중"으로 판정돼 즉사한다.
	if _낙하:
		_낙하.초기화()
	# 사망은 "스테이지 재시도" 다 → 규칙대로 모든 페인트를 회수한다.
	if _코어:
		_코어.리셋()


# ── 진입 / 자동 체크포인트 ──────────────────────────────────────────────────

## 이 스테이지를 어디서 시작할지 정한다.
## 통로를 지나 들어왔다면 그 통로(입구) 안쪽에서 걸어 나오게 하고,
## 그냥 F5 로 실행했다면 `시작_위치` 를 쓴다.
func _진입_위치_정하기() -> Vector2:
	var 정보 := 장면전환.진입_정보()
	장면전환.진입_소비()          # 한 번 쓰고 비운다 (다음 실행에 남으면 안 된다)
	var 이름: String = String(정보.get("진입점", ""))
	if 이름.is_empty():
		return 시작_위치

	# ⚠[2026-08-06] 예전엔 `get_tree().get_nodes_in_group("연결통로")` 로 **트리 전체**를
	#   뒤졌다. 그런데 스테이지마다 입구 통로 이름이 똑같이 "입구통로" 라서,
	#   이전 씬이 아직 트리에 남아 있는 상황(테스트 하네스·씬 중첩)에서는
	#   **엉뚱한 스테이지의 통로**를 집어 플레이어가 화면 밖에 스폰됐다.
	#   → 이 스테이지(self) 아래에서만 찾는다. 이름이 겹쳐도 안전하다.
	var 후보: 연결통로 = null
	for t in _내_통로들():
		if t.역할 != 연결통로.역할_.입구:
			continue
		if 후보 == null:
			후보 = t              # 이름이 안 맞아도 입구가 하나면 그걸 쓴다
		if t.name == 이름:
			후보 = t
			break
	return 후보.걸어나올_위치() if 후보 else 시작_위치


## 이 스테이지가 가진 연결통로만 모은다 (자손 전체 탐색).
func _내_통로들() -> Array[연결통로]:
	var 결과: Array[연결통로] = []
	var 대기: Array[Node] = [self]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			if c is 연결통로:
				결과.append(c)
			else:
				대기.append(c)
	return 결과


## "마지막으로 안전하게 서 있던 땅"을 기억해 둔다.
## 조건: 바닥에 붙어 있고 · 죽을 상태가 아니고 · 낙하 위험도 0 · 일정 시간 유지.
func _안전점_갱신(delta: float, 죽는가: bool) -> void:
	if not 안전지점_자동저장:
		return
	# ⚠[2026-08-06 함정] `is_on_floor()` 만 믿으면 안 된다.
	#   CharacterBody2D 의 이 값은 **마지막 move_and_slide() 결과가 그대로 남아 있다.**
	#   그래서 플레이어를 코드로 순간이동시키면(리스폰·도구·테스트) 다음 물리 프레임까지
	#   "아직 땅에 서 있다"고 답한다. 그 한 프레임에 체크포인트가 찍히면
	#   **허공이 안전지점으로 저장**된다 — 죽을 때마다 그 허공으로 돌아가 무한 낙하한다.
	#   (실제로 test_낙하사망.gd 가 이 증상을 잡아냈다)
	#   → 발밑에 진짜 땅이 있는지 레이로 한 번 더 확인한다.
	if 죽는가 or not bool(_플레이어.call("is_on_floor")) or not _발밑에_땅있나():
		_안전_누적 = 0.0
		return
	if _낙하 and _낙하.위험도() > 0.0:
		_안전_누적 = 0.0
		return
	_안전_누적 += delta
	if _안전_누적 >= 안전지점_유예:
		_안전점 = _플레이어.global_position


## 발밑 24px 안에 실제 콜리전이 있는가. (지형 레이어 1 만 본다 — 유령 발판은 제외)
func _발밑에_땅있나() -> bool:
	var 공간 := _플레이어.get_world_2d().direct_space_state
	var 기준 := _플레이어.global_position
	var q := PhysicsRayQueryParameters2D.create(
		기준 + Vector2(0, -4.0), 기준 + Vector2(0, 24.0), 1)
	q.exclude = [_플레이어.get_rid()]
	return not 공간.intersect_ray(q).is_empty()


# ── HUD ────────────────────────────────────────────────────────────────────
func _HUD_만들기() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_hud_탄약 = Label.new()
	_hud_탄약.position = Vector2(28, 22)
	_hud_탄약.add_theme_font_size_override("font_size", 26)
	_hud_탄약.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	_hud_탄약.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hud_탄약.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud_탄약)

	_hud_안내 = Label.new()
	_hud_안내.position = Vector2(28, 60)
	_hud_안내.add_theme_font_size_override("font_size", 17)
	_hud_안내.add_theme_color_override("font_color", Color(0.80, 0.80, 0.78))
	_hud_안내.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hud_안내.add_theme_constant_override("outline_size", 5)
	_hud_안내.text = "A/D 이동  ·  Space 점프  ·  Shift 색전환  ·  좌클릭 발사  ·  E 회수/레버"
	layer.add_child(_hud_안내)


## ESC 메뉴를 붙이고, 저장된 밝기를 화면에 반영한다.
## 밝기는 씬의 CanvasModulate("어둠") 색을 곱해서 만든다 —
## 그래서 이 스테이지가 의도한 **원래 색을 기준값으로 넘겨줘야** 한다.
## (현재 색을 기준으로 삼으면 슬라이더를 만질 때마다 값이 누적돼 점점 어두워진다)
func _메뉴_만들기() -> void:
	var 어둠 := get_node_or_null("어둠") as CanvasModulate
	if 어둠 == null:
		# 이름이 다르더라도 첫 번째 CanvasModulate 를 쓴다 (씬을 손으로 고쳤을 때 대비)
		for 자식 in get_children():
			if 자식 is CanvasModulate:
				어둠 = 자식
				break
	var 메뉴 := 메뉴_스크립트.new()
	메뉴.name = "일시정지메뉴"
	add_child(메뉴)
	if 어둠:
		메뉴.연결(어둠, 어둠.color)


func _HUD_갱신(남은: int, 최대: int) -> void:
	if _hud_탄약 == null or _코어 == null:
		return
	var 잠김 := _코어.잠긴_발수()
	var 문구 := "페인트 %d / %d   (회수대기 %d)" % [남은, 최대, _코어.회수_대기수()]
	if 잠김 > 0:
		문구 += "   [회색으로 잠김 %d발 — 스테이지 이동 시 회수]" % 잠김
	_hud_탄약.text = 문구
