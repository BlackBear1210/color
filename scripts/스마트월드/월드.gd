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

@export var 스테이지_이름: String = "스마트월드 테스트"
## 카메라가 벗어나지 않을 범위. 비워두면(size 0) 리밋 없이 자유롭게 따라간다.
@export var 카메라_리밋: Rect2 = Rect2()
@export var 카메라_줌: float = 0.85
## 플레이어 시작 위치. 사망 시 여기로 돌아온다.
@export var 시작_위치: Vector2 = Vector2(200, 0)
## 이 y 아래로 떨어지면 사망 (낙사).
@export var 낙사_y: float = 1800.0

var _플레이어: CharacterBody2D = null
var _코어: 페인트코어 = null
var _카메라: ProtoCamera = null
var _총: 페인트총 = null

var _hud_탄약: Label = null
var _hud_안내: Label = null
var _무적: float = 0.0                 ## 리스폰 직후 잠깐 무적 (즉사 반복 방지)


func _ready() -> void:
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
	_플레이어 = get_node_or_null("Player") as CharacterBody2D
	if _플레이어 == null:
		push_error("스마트월드: 자식으로 'Player' 가 있어야 한다")
		return

	_플레이어.global_position = 시작_위치

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

	_HUD_만들기()
	_메뉴_만들기()
	if _코어:
		_코어.탄약_변경.connect(_HUD_갱신)
		_HUD_갱신(_코어.남은_탄약, _코어.최대_탄약)


func _physics_process(delta: float) -> void:
	if _플레이어 == null:
		return
	_무적 = maxf(_무적 - delta, 0.0)

	_지대_적용()

	if _무적 <= 0.0 and _사망_판정():
		_리스폰()
		return
	if _플레이어.global_position.y > 낙사_y:
		_리스폰()


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
	_플레이어.global_position = 시작_위치
	_무적 = 0.6
	if _카메라:
		_카메라.setup(_플레이어)
	# 사망은 "스테이지 재시도" 다 → 규칙대로 모든 페인트를 회수한다.
	if _코어:
		_코어.리셋()


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
