extends Node2D
## ============================================================================
## [2026-07-24 도형 · 신규] 스테이지 공용 조립 (Stage Lab) — 페인트 v3 스테이지 전용
## ----------------------------------------------------------------------------
## zone_lab.gd 가 "타일맵 존"을 조립했다면, 이 스크립트는 "플랫폼 스테이지"를 조립한다.
## 두 파일은 공존한다 — 기존 zone_01/02/world_1 은 zone_lab 그대로, 새 스테이지는 여기.
##
## ▣ 팀원 코드 무수정 원칙은 그대로 지킨다
##   player.gd / gun.gd / bullet.gd / Player.tscn / project.godot 을 한 줄도 안 고친다.
##   대신 런타임에:
##     · Player 안의 Gun 노드를 제거하고 ProtoGun 을 붙인다
##     · Player.tscn 내장 Camera2D 를 끄고 ProtoCamera 를 붙인다
##     · 사망 판정·체크포인트·클리어는 전부 이 스크립트가 바깥에서 감시한다
##
## ▣ 씬 구조 (tools/build_stages.gd 가 만든다)
##   스테이지_N (Node2D · 이 스크립트)
##   ├─ 배경      Node2D   — 원경/근경 (칠할 수 없는 장식)
##   ├─ 지형      Node2D   — PaintPlatform 들
##   ├─ 장애물    Node2D   — 가시/톱/문/체크포인트/목표문/낙하지대
##   ├─ 스폰      Marker2D (그룹 spawn_point)
##   ├─ Player    (scenes/player/Player.tscn 인스턴스)
##   └─ UI        CanvasLayer → StageHUD
## ============================================================================
class_name StageLab

const PROTO_GUN := preload("res://scripts/proto/proto_gun.gd")
const PROTO_CAMERA := preload("res://scripts/proto/proto_camera.gd")
const PROTO_MOTION := preload("res://scripts/proto/proto_motion.gd")
const PAINT_MANAGER := preload("res://scripts/proto/paint_manager.gd")
const PAINT_FX := preload("res://scripts/proto/paint_fx.gd")
const STAGE_HUD := preload("res://scripts/proto/stage_hud.gd")
const SHOOT_ANIM := preload("res://scripts/proto/player_shoot_anim.gd")
const ZONE_VISUALS := preload("res://scripts/proto/zone_visuals.gd")

## 입(페인트를 뱉는 위치) — 플레이어 로컬 좌표. zone_lab 과 동일 값.
const MOUTH_POS := Vector2(18, -70)
const 사망모션시간: float = 0.55
const 부활무적: float = 0.6
const 카메라여백: float = 96.0

## ★[2026-07-25] 카메라 줌 — 1.0 이 기본, **작을수록 넓게 보인다**.
## 도형님 피드백 "카메라가 너무 플레이어랑 가까워" 반영.
##   1.00 → 1152×648 월드px 가 보임 (플레이어 키 47px = 화면의 7%)
##   0.70 → 1646×926 이 보임 (플레이어 = 화면의 5%) ← 채택
## 리틀 나이트메어·레인월드처럼 "작은 존재가 큰 공간에 있다"는 프레이밍이 되고,
## 포물선 조준(최대 사거리 약 900px)의 착탄점이 화면 안에 들어와 조준이 편해진다.
const 카메라_줌: float = 0.70
## 스테이지 전환 페이드(초). 잉크 와이프가 아니라 **터널을 지나며 어두워지는** 연출.
const 페이드_시간: float = 0.55

@export var 스테이지이름: String = "스테이지"
## 클리어하면 넘어갈 씬 경로. 비우면 로비로 돌아간다.
@export_file("*.tscn") var 다음스테이지: String = ""
## 0 = 셰이더 번짐(zone_04 계열) / 1 = VFX 스탬프(zone_05 계열)
@export_enum("셰이더", "VFX") var 표현모드: int = 0
## 시작 색 (0=검정 1=흰색)
@export_enum("검정", "흰색") var 시작색: int = 0
## 스테이지 시작 시 화면 중앙에 띄울 안내 문구 (레벨이 무엇을 가르치는지)
@export_multiline var 안내문: String = ""

var player: CharacterBody2D
var camera: Node
var 매니저: PaintManager
var 이펙트: PaintFX
var hud: StageHUD

var _스폰위치: Vector2
var _스폰색: int = ColorDefs.BLACK
var _무적: float = 0.0
var _사망중: bool = false
var _사망수: int = 0
var _클리어됨: bool = false

func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	if player == null:
		push_warning("[stage_lab] Player 노드를 찾지 못했습니다 — 조립을 건너뜁니다.")
		return

	# ── 1) 스폰 위치·색 ─────────────────────────────────────────────
	var 스폰 := get_node_or_null("스폰") as Node2D
	if 스폰:
		player.global_position = 스폰.global_position
	_스폰위치 = player.global_position
	_스폰색 = ColorDefs.BLACK if 시작색 == 0 else ColorDefs.WHITE
	if player.get("player_color") != _스폰색:
		player.call("_toggle_color")

	# ── 2) 페인트 매니저 (회수 FIFO) ────────────────────────────────
	매니저 = PAINT_MANAGER.new()
	매니저.name = "페인트매니저"
	add_child(매니저)

	# ── 3) 기존 총 제거 → 프로토 총(포물선 + 조준 궤적) 부착 ─────────
	var 구총 := player.get_node_or_null("Gun")
	if 구총:
		구총.queue_free()
	var gun: ProtoGun = PROTO_GUN.new()
	gun.name = "ProtoGun"
	gun.position = MOUTH_POS
	player.add_child(gun)
	# 플랫폼 스테이지에는 타일맵이 없다 → PaintSystem/TileMapLayer 는 null.
	# 대신 E 회수를 페인트매니저로 넘긴다(proto_gun.gd 2026-07-24 분기).
	gun.setup(null, null, player)
	gun.페인트매니저 = 매니저

	# ── 4) 카메라 v2 (룩어헤드·플랫폼 스냅) ─────────────────────────
	var 구카메라 := player.get_node_or_null("Camera2D") as Camera2D
	if 구카메라:
		구카메라.enabled = false
	camera = PROTO_CAMERA.new()
	camera.name = "ProtoCamera"
	add_child(camera)
	camera.set_limit_rect(_자동_리밋(), false)
	camera.set_region_zoom(카메라_줌, false)   # ★[2026-07-25] 넓게 보이도록 줌아웃
	camera.setup(player)

	# ── 5) 절차적 모션 (착지 스쿼시·기울임) ─────────────────────────
	var motion: ProtoMotion = PROTO_MOTION.new()
	motion.name = "ProtoMotion"
	player.add_child(motion)

	# ── 6) ★발사 모션 (디자이너가 올린 Shoot 시트) ──────────────────
	var 발사모션 := SHOOT_ANIM.new()
	발사모션.name = "발사모션"
	player.add_child(발사모션)
	발사모션.setup(player, gun)

	# ── 6.5) ★[2026-07-25] 라이팅/분위기 리그 ────────────────────────
	# 환경광 + 플레이어 광원 + 배경 노멀맵 주입 + 비네트.
	# 이게 있어야 배경에 심은 가로등·등불·발광 구슬이 "빛"으로 보인다
	# (CanvasModulate 로 화면을 살짝 가라앉혀야 Light2D 가 대비를 만든다).
	var visuals: ZoneVisuals = ZONE_VISUALS.new()
	visuals.name = "ZoneVisuals"
	# 배경·프롭이 많은 스테이지에서는 기본 환경광(0.82)이면 전체가 너무 어둡다.
	# 광원의 대비는 살리되 지형 가독성(색이 곧 규칙!)이 죽지 않는 선으로 올린다.
	visuals.환경광 = Color(0.93, 0.93, 0.97)
	add_child(visuals)
	visuals.setup(player)

	# ── 7) 페인트 이펙트 (스플래시·물감 흐름·카메라 킥) ─────────────
	이펙트 = PAINT_FX.new()
	이펙트.name = "페인트이펙트"
	add_child(이펙트)
	이펙트.setup(player, camera, 표현모드)

	# ── 8) HUD ──────────────────────────────────────────────────────
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		ui = CanvasLayer.new()
		ui.name = "UI"
		add_child(ui)
	ui.layer = 10
	hud = STAGE_HUD.new()
	hud.name = "StageHUD"
	ui.add_child(hud)
	hud.스테이지이름 = 스테이지이름
	hud.setup(player, 매니저)
	if 안내문 != "":
		hud.메시지(안내문)

	# ── 9) 장애물·트리거 연결 ────────────────────────────────────────
	_트리거_연결()

	# ── 10) ★입장 연출 — 어둠에서 밝아진다 (앞 스테이지의 통로를 지나온 것) ──
	_어둠에서_밝아짐()

## 지형·장애물이 실제로 놓인 범위 → 카메라 리밋
func _자동_리밋() -> Rect2:
	var 사각 := Rect2()
	var 첫번째 := true
	for n in get_tree().get_nodes_in_group("paint_platform"):
		var p := n as PaintPlatform
		if p == null:
			continue
		var r := Rect2(p.global_position - p.크기_px() * 0.5, p.크기_px())
		if 첫번째:
			사각 = r
			첫번째 = false
		else:
			사각 = 사각.merge(r)
	if 첫번째:
		return Rect2(-640, -360, 1280, 720)
	return _여백_적용(사각)

func _여백_적용(r: Rect2) -> Rect2:
	return Rect2(r.position - Vector2(카메라여백, 카메라여백),
		r.size + Vector2(카메라여백, 카메라여백) * 2.0)

func _트리거_연결() -> void:
	for n in get_tree().get_nodes_in_group("hazard"):
		var a := n as Area2D
		if a and not a.body_entered.is_connected(_위험물_접촉):
			a.body_entered.connect(_위험물_접촉)
	for n in get_tree().get_nodes_in_group("killzone"):
		var a := n as Area2D
		if a and not a.body_entered.is_connected(_낙사):
			a.body_entered.connect(_낙사)
	for n in get_tree().get_nodes_in_group("checkpoint"):
		var a := n as Area2D
		if a and not a.body_entered.is_connected(_체크포인트_접촉.bind(a)):
			a.body_entered.connect(_체크포인트_접촉.bind(a))
	for n in get_tree().get_nodes_in_group("zone_exit"):
		var a := n as Area2D
		if a and not a.body_entered.is_connected(_목표_도달):
			a.body_entered.connect(_목표_도달)

# ── 사망 판정 ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_무적 = maxf(_무적 - delta, 0.0)
	_반대색_밟았나()

## 발밑 플랫폼의 색이 내 색의 반대면 즉사 (규칙 v1.3 — 단위만 타일→플랫폼).
## 무색·회색은 누구에게나 안전하다.
func _반대색_밟았나() -> void:
	if _사망중 or _클리어됨 or _무적 > 0.0 or player == null or not player.is_on_floor():
		return
	var 색: int = player.get("player_color")
	var 밟은 := _발밑_플랫폼()
	if 밟은 and 밟은.반대색인가(색):
		죽기("💀 반대색 지형을 밟았다")

## 발밑 검사 — 중앙 + 좌우 발끝 3점 레이캐스트.
## (플레이어 원점 = 발바닥. 스케일이 비균등이라 로컬 오프셋 대신 월드 오프셋을 쓴다)
func _발밑_플랫폼() -> PaintPlatform:
	var space := get_world_2d().direct_space_state
	for dx in [0.0, -14.0, 14.0]:
		var 시작 := player.global_position + Vector2(dx, -6.0)
		var q := PhysicsRayQueryParameters2D.create(시작, 시작 + Vector2(0, 14.0))
		q.collision_mask = 1
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit and hit.has("collider"):
			var p := hit["collider"] as PaintPlatform
			if p:
				return p
	return null

func _위험물_접촉(body: Node2D) -> void:
	if body == player and not _사망중 and _무적 <= 0.0:
		죽기("💀 장애물에 닿았다")

func _낙사(body: Node2D) -> void:
	if body == player and not _사망중:
		죽기("💀 아래로 떨어졌다")

func _체크포인트_접촉(body: Node2D, 지점: Area2D) -> void:
	if body != player:
		return
	# 위치와 **그 순간의 색**을 함께 저장 — 반대색 부활 무한루프 방지 (7/14 사고 대응)
	_스폰위치 = 지점.global_position + Vector2(0, -2)
	_스폰색 = player.get("player_color")
	if 지점.has_method("켜기"):
		지점.call("켜기")
	if hud:
		hud.메시지("🚩 체크포인트")

func _목표_도달(body: Node2D) -> void:
	if body != player or _클리어됨:
		return
	_클리어됨 = true
	# ★[2026-07-25] 잉크 와이프(포탈 느낌) 대신 **어둠 페이드**.
	# 통로 안으로 걸어 들어가며 어두워졌다가, 다음 스테이지의 입구 통로에서 밝아진다
	# → "화면이 전환됐다"가 아니라 "터널을 지나왔다"로 읽힌다.
	var 목적지 := 다음스테이지 if 다음스테이지 != "" else "res://scenes/lobby/lobby.tscn"
	await _어둠으로_페이드()
	if ResourceLoader.exists(목적지):
		get_tree().change_scene_to_file(목적지)

## 화면을 검게 덮는다. 통로에 들어선 뒤 0.55초.
func _어둠으로_페이드() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60                     # UI(10)·비네트(5)보다 위 = 전부 덮는다
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
	var t := create_tween()
	t.tween_property(rect, "color:a", 1.0, 페이드_시간).set_trans(Tween.TRANS_SINE)
	await t.finished

## 스테이지 시작 시 검은 화면에서 밝아진다 (통로에서 걸어 나오는 연출)
func _어둠에서_밝아짐() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, 페이드_시간 * 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_callback(layer.queue_free)

## 사망 → 사망 모션(player_anim.gd 의 death 훅) → 체크포인트 위치·색으로 부활
func 죽기(사유: String) -> void:
	if _사망중:
		return
	_사망중 = true
	_사망수 += 1
	if hud:
		hud.사망수 = _사망수
		hud.메시지("%s (%d회)" % [사유, _사망수])
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)     # 물리 정지 = player_anim.gd 가 death 재생
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.6)
	await get_tree().create_timer(사망모션시간).timeout
	player.global_position = _스폰위치
	if player.get("player_color") != _스폰색:
		player.call("_toggle_color")
	player.set_physics_process(true)
	_무적 = 부활무적
	_사망중 = false
	if camera and camera.has_method("setup"):
		camera.setup(player)              # 부활 지점으로 카메라 즉시 스냅
