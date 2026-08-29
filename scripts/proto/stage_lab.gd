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
const TILE_PAINT_MAP := preload("res://scripts/proto/tile_paint_map.gd")
const PAINT_FX := preload("res://scripts/proto/paint_fx.gd")
const STAGE_HUD := preload("res://scripts/proto/stage_hud.gd")
## [2026-08-17] 점(pip) 방식 페인트 HUD + 타일맵용 어댑터.
## ⚠ class_name 이 아니라 경로 preload 로 잡는다 (새 스크립트의 전역 클래스 이름은
##   에디터가 훑기 전까지 등록되지 않아 헤드리스 검사가 죽는다).
const 페인트HUD_스크립트 := preload("res://scripts/ui/페인트_HUD.gd")
const 페인트HUD어댑터_타일 := preload("res://scripts/ui/페인트_HUD_어댑터_타일.gd")
const SHOOT_ANIM := preload("res://scripts/proto/player_shoot_anim.gd")
const ZONE_VISUALS := preload("res://scripts/proto/zone_visuals.gd")

## 입(페인트를 뱉는 위치) — GunRig 아래의 월드 픽셀 좌표.
## Player는 비균등 스케일이라 직접 자식으로 붙이면 (18, -70)이 실제로는
## (14, -26)으로 찌그러져 무릎에서 발사된다. GunRig가 그 배율을 상쇄한다.
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
const 카메라_줌: float = 0.85
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
## ★타일맵 페인트 모드 — 지형을 PaintPlatform 노드가 아니라 TileMapLayer 로 그린 스테이지.
## 켜면 TilePaintMap 이 타일의 아틀라스 좌표로 색을 인지해 플랫폼을 자동 검출한다.
@export var 타일맵_페인트: bool = false

## ★[2026-08-30] 이 스테이지의 SS2D 지형에 **자리별 색 판정**을 켠다.
## 켜면 "안 칠한 것은 검정" + "닿은 자리의 물감 색으로 판정" 이 적용된다.
## 씬마다 지형 노드를 일일이 고치지 않아도 되도록 스테이지가 통째로 켜 준다.
@export var 자리별_색판정: bool = true
## 필요횟수 = ceil(플랫폼 긴 변 칸수 / 이 값). 작을수록 많이 쏴야 한다.
@export var 타일_필요횟수_나눗값: int = 4
## 이 칸수를 넘는 덩어리는 칠할 수 없는 고정 지형으로 본다. 0 = 제한 없음.
@export var 타일_고정_타일수: int = 0
## ★[2026-08-17 신규] 타일맵 페인트 스테이지의 페인트 총량. **0 = 무제한**(예전 동작).
##
## E 로 회수하면 발이 돌아오므로, 이 값은 "총 사용량 제한"이 아니라
## **동시에 칠해둘 수 있는 양의 상한**이다.
## `stage_1-1, 1-2` 실측 참고: 칠할 수 있는 플랫폼 103개 / 전부 칠하면 440발 /
## 가장 큰 플랫폼 하나가 12발. 그래서 12 이하로 두면 큰 것 하나도 못 칠한다.
## 밸런스를 만지려면 **여기 숫자만** 바꾸면 된다(에디터에서도 보인다).
@export var 타일_최대_탄약: int = 14
## 명중 결과(progress/painted/wasted/blocked…)를 화면 중앙에 띄운다 — 레벨 튜닝·디버그 전용.
## ⚠ 기본 끔. 켜면 쏠 때마다 중앙 메시지가 갱신되어 **화면이 번쩍이는 것처럼 보인다**.
@export var 타일_명중_표시: bool = false

var player: CharacterBody2D
var camera: Node
var 매니저: PaintManager
var 타일페인트: TilePaintMap
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

	# ── 1.5) ★[2026-08-30] 자리별 색 판정 켜기 ──────────────────────
	# 지형 노드를 씬마다 손으로 고치지 않아도 되도록 스테이지가 통째로 켠다.
	# 나중에 지형을 더 놓아도 이 줄 하나로 같이 켜진다.
	if 자리별_색판정:
		for 지형 in get_tree().get_nodes_in_group("스마트지형"):
			if 지형.is_inside_tree() and is_ancestor_of(지형):
				지형.set("위치별_판정", true)

	# ── 2) 페인트 매니저 (회수 FIFO) ────────────────────────────────
	매니저 = PAINT_MANAGER.new()
	매니저.name = "페인트매니저"
	add_child(매니저)

	# ── 2.5) ★타일맵 페인트 — 아틀라스 좌표로 색을 인지해 플랫폼을 자동 검출 ──
	# 이게 켜지면 디자이너는 TileMapLayer 로 맵을 찍기만 하면 되고,
	# 플랫폼 노드를 하나하나 배치하거나 새 씬으로 복붙할 필요가 없다.
	if 타일맵_페인트:
		타일페인트 = TILE_PAINT_MAP.new()
		타일페인트.name = "타일페인트"
		타일페인트.필요횟수_나눗값 = 타일_필요횟수_나눗값
		타일페인트.칠하기_최대_타일수 = 타일_고정_타일수
		타일페인트.최대_탄약 = 타일_최대_탄약     # setter 가 잔량도 같이 채운다
		add_child(타일페인트)          # _ready() 에서 부모(=이 스테이지)를 훑어 자동 등록

	# ── 3) 기존 총 제거 → 프로토 총(포물선 + 조준 궤적) 부착 ─────────
	# [2026-08-23] Gun 이 GunRig 아래로 내려갔다. 옛 경로도 함께 본다.
	var 구총 := player.get_node_or_null("GunRig/Gun")
	if 구총 == null:
		구총 = player.get_node_or_null("Gun")
	if 구총:
		구총.queue_free()
	var gun: ProtoGun = PROTO_GUN.new()
	gun.name = "ProtoGun"
	gun.position = MOUTH_POS
	# ★입 좌표는 월드 픽셀 기준이다. Player 아래가 아니라 역스케일 GunRig 아래에
	# 붙여야 실제 발사 원점도 (18, -70) = 입에 남는다.
	var 총받침 := player.get_node_or_null("GunRig") as Node2D
	if 총받침:
		총받침.add_child(gun)
	else:
		# 오래된 Player 씬에는 GunRig가 없을 수 있다. 그 경우만 기존 경로를 유지한다.
		player.add_child(gun)
	# 플랫폼 스테이지에는 타일맵이 없다 → PaintSystem/TileMapLayer 는 null.
	# 대신 E 회수를 페인트매니저로 넘긴다(proto_gun.gd 2026-07-24 분기).
	# ★타일맵 페인트 모드면 총알의 TileMapLayer 명중을 TilePaintMap 이 받고,
	#   E 회수도 그쪽으로 보낸다 (on_hit / 되돌리기 이름이 같아 총 코드는 그대로).
	gun.setup(타일페인트, null, player)
	gun.페인트매니저 = 타일페인트 if 타일페인트 != null else 매니저

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

	# ── 4-2) ★[2026-08-07 도형] 구역 카메라 연출 (바인식 전환) ──────────
	# 씬 안에 `카메라연출` 노드가 있으면 그쪽이 카메라를 몰고 간다.
	# 없으면 위에서 잡은 `_자동_리밋()` 한 장으로 계속 간다 → **기존 씬은 회귀 없음.**
	#
	# 왜 여기서 연결하나: 카메라와 플레이어가 둘 다 준비된 시점이 여기뿐이다.
	# 연출가는 매 프레임 플레이어 x 를 읽어 구역을 섞으므로 늦게 붙으면
	# 첫 프레임에 엉뚱한 화면이 한 번 보인다(그래서 연결() 안에서 즉시 1회 적용한다).
	var 연출 := _카메라연출_찾기(self)
	if 연출:
		연출.연결(camera, player)
		print("[stage_lab] 카메라 연출 연결됨 — 구역 %d 개" % 연출.구역수())

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
	# 환경광 + 플레이어 광원 + 배경 노멀맵 주입. 비네트는 ProtoCamera 한 곳에서 그린다.
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
	# 스테이지 이름·사망 횟수도 핵심 HUD이므로 비네트(50) 위, 페인트 HUD와 같은 높이에 둔다.
	ui.layer = 100
	hud = STAGE_HUD.new()
	hud.name = "StageHUD"
	ui.add_child(hud)
	hud.스테이지이름 = 스테이지이름
	hud.setup(player, 매니저)
	if 안내문 != "":
		hud.메시지(안내문)

	# ── 8.2) ★[2026-08-17] 페인트 HUD (점 방식) — 타일맵 페인트 스테이지 전용 ──
	#
	# 왜 타일맵 모드에만 붙이나:
	#   `StageHUD` 는 `매니저`(PaintManager) 를 보고 회수 대기·E 마커를 그린다.
	#   그런데 타일맵 모드에서는 색칠을 `타일페인트`(TilePaintMap)가 처리하고
	#   매니저 큐는 **항상 비어 있다.** 그래서 stage_1-1, 1-2 에서는 StageHUD 의
	#   회수 관련 표시가 전부 죽어 있었다(회수대기 0 고정 · E 마커 안 뜸).
	#   → 그 빈자리를 점 HUD 가 채운다.
	#
	#   PaintPlatform 을 쓰는 옛 스테이지(스테이지_1~5)는 StageHUD 가 지금도 제대로
	#   동작하므로 **건드리지 않는다** — 회귀를 만들 이유가 없다.
	#
	# ⚠ 이 시스템에는 탄약(전역 자원)이 없다. 타일 어댑터의 `탄약()` 이 빈 사전을
	#   돌려주므로 점 HUD 가 12칸 줄을 스스로 건너뛰고 회수 묶음만 그린다.
	if 타일페인트 != null:
		hud.회수대기_표시 = false          # 매니저 큐가 항상 0 이라 거짓말이 된다
		var 점HUD: CanvasLayer = 페인트HUD_스크립트.new()
		점HUD.name = "페인트HUD"
		# StageHUD 가 좌상단 한 줄(스테이지 이름·사망 수)을 이미 쓰고 있다 → 그 아래로 내린다.
		점HUD.여백 = Vector2(30, 64)
		add_child(점HUD)
		점HUD.연결(player, 페인트HUD어댑터_타일.new(타일페인트))

	# ── 8.5) ★타일맵 페인트 디버그 — 명중 결과를 눈으로 볼 수 있게 한다 ──────
	# 이게 없으면 blocked/wasted 처럼 "아무 일도 안 일어나는" 판정이 화면에 전혀 안 보여
	# 색칠 자체가 고장난 것처럼 오해하게 된다(실제로 그 혼란이 있었다).
	if 타일페인트 != null and 타일_명중_표시:
		var 통계: Dictionary = 타일페인트.통계()
		hud.메시지("타일 플랫폼 %d개 (칠가능 %d)" % [통계["전체"], 통계["칠가능"]])
		타일페인트.명중됨.connect(_타일_명중_표시)

const _결과_이름 := {
	"progress": "🎨 칠하는 중",
	"painted": "✅ 칠해짐",
	"wasted": "· 같은 색이라 변화 없음",
	"mixed_gray": "🩶 회색이 됐다 (영구)",
	"blocked": "🚫 칠할 수 없는 지형",
	"miss": "· 빈 곳",
}

func _타일_명중_표시(결과: String, _색: int, _월드좌표: Vector2) -> void:
	if hud:
		hud.메시지(_결과_이름.get(결과, 결과))

	# ── 9) 장애물·트리거 연결 ────────────────────────────────────────
	_트리거_연결()

	# ── 10) ★입장 연출 — 어둠에서 밝아진다 (앞 스테이지의 통로를 지나온 것) ──
	_어둠에서_밝아짐()

## ★[2026-08-07 도형] 씬 안에서 카메라연출 노드를 찾는다 (자손 전체 탐색).
## 이름이 아니라 **타입**으로 찾는다 — 이름은 작업자마다 다르게 붙이기 마련이다.
func _카메라연출_찾기(노드: Node) -> 카메라연출:
	for c in 노드.get_children():
		if c is 카메라연출:
			return c
		var r := _카메라연출_찾기(c)
		if r:
			return r
	return null


## 지형·장애물이 실제로 놓인 범위 → 카메라 리밋
##
## ⚠[수정] 예전엔 PaintPlatform 만 훑었다. 그래서 지형이 **타일맵으로 그려진**
##   스테이지(stage_1-1 등)에서는 플랫폼 1~2개만 잡혀 리밋이 화면보다 작아지고,
##   proto_camera._clamp_to_limits() 가 "리밋이 화면보다 작으면 중앙 고정" 분기를 타서
##   **카메라가 플레이어를 아예 안 따라가는** 것처럼 보였다.
##   → TileMapLayer 가 실제로 쓰는 범위도 함께 합친다.
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
	for layer in _모든_타일맵(self):
		var 쓰는범위 := layer.get_used_rect()
		if 쓰는범위.size.x <= 0 or 쓰는범위.size.y <= 0:
			continue
		var 타일 := Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
		var r2 := Rect2(
			layer.to_global(Vector2(쓰는범위.position) * 타일),
			Vector2(쓰는범위.size) * 타일 * layer.global_scale)
		if 첫번째:
			사각 = r2
			첫번째 = false
		else:
			사각 = 사각.merge(r2)
	if 첫번째:
		return Rect2(-640, -360, 1280, 720)
	return _여백_적용(사각)

## 씬 안의 모든 TileMapLayer (깊이 무관)
func _모든_타일맵(뿌리: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for 자식 in 뿌리.get_children():
		var l := 자식 as TileMapLayer
		if l != null:
			out.append(l)
		out.append_array(_모든_타일맵(자식))
	return out

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

## 발밑 지형의 색이 내 색과 다르면 즉사.
##
## ★[2026-08-30] 규칙이 바뀌었다 — **안 칠한 것은 무색이 아니라 검정**이다.
##   그리고 지형은 노드 전체가 아니라 **닿은 자리**의 물감 색으로 판정한다.
##   자세한 것은 `docs/색판정_규칙_2026-08-30.md` · `scripts/스마트월드/색규칙.gd`.
func _반대색_밟았나() -> void:
	if _사망중 or _클리어됨 or _무적 > 0.0 or player == null or not player.is_on_floor():
		return
	var 색: int = player.get("player_color")
	for 접촉 in _발밑_접촉들():
		var 대상: Node = 접촉["대상"]
		# 자리별 판정을 아는 지형에는 **밟은 그 점**을 넘긴다.
		if 대상.has_method("위치_반대색인가"):
			if 대상.위치_반대색인가(색, PackedVector2Array([접촉["점"]])):
				죽기("💀 색이 다른 지형을 밟았다")
				return
		elif 대상.반대색인가(색):
			죽기("💀 색이 다른 지형을 밟았다")
			return

## 발밑 검사 — 중앙 + 좌우 발끝 3점 레이캐스트.
## (플레이어 원점 = 발바닥. 스케일이 비균등이라 로컬 오프셋 대신 월드 오프셋을 쓴다)
##
## ★[2026-08-29 수정] 예전에는 콜리전을 **`PaintPlatform` 으로 캐스팅**해서, 그 타입이
##   아니면 무조건 null 이었다. 그래서 SS2D 지형(`스마트지형`)을 이 계열 스테이지에
##   놓으면 **총으로 칠할 수는 있는데 밟아도 안 죽었다** — 색이 곧 규칙인 게임에서
##   화면과 판정이 어긋나는 최악의 상태다(stage_2-3 에 벽돌 테스를 넣고 확인).
##   → 타입이 아니라 **계약**으로 찾는다. `반대색인가()` 를 가진 조상을 거슬러 올라가며
##     찾으면 PaintPlatform 도 스마트지형도 같은 규칙을 탄다.
##     (`월드.gd _반대색_대상_찾기()` 와 같은 방식이다 — 두 계열이 같은 말을 쓰게)
## 반환: [{ "대상": Node, "점": Vector2(월드) }] — 발밑에 닿은 **색 가진 것들**.
## ★점을 같이 돌려주는 이유: 지형은 한 노드 안에서도 자리마다 색이 다르다(부분칠).
##   "무엇을 밟았나" 만으로는 판정할 수 없고 "어디를 밟았나" 가 있어야 한다.
func _발밑_접촉들() -> Array[Dictionary]:
	var 결과: Array[Dictionary] = []
	var space := get_world_2d().direct_space_state
	for dx in [0.0, -14.0, 14.0]:
		var 시작 := player.global_position + Vector2(dx, -6.0)
		var q := PhysicsRayQueryParameters2D.create(시작, 시작 + Vector2(0, 14.0))
		q.collision_mask = 1
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not hit.has("collider"):
			continue
		var 대상 := _색가진_조상(hit["collider"])
		if 대상 != null:
			결과.append({ "대상": 대상, "점": hit.get("position", 시작) })
	return 결과


## 예전 이름 — 다른 곳(HUD 등)이 쓸 수 있어 남겨 둔다. 첫 접촉의 대상만 돌려준다.
func _발밑_플랫폼() -> Node:
	var 접촉들 := _발밑_접촉들()
	return 접촉들[0]["대상"] if not 접촉들.is_empty() else null


## 콜리전 바디에서 "색을 가진 것"을 거슬러 올라가 찾는다.
## SS2D 지형은 [스마트지형] → StaticBody2D → CollisionPolygon2D 구조라 부모를 봐야 한다.
## ⚠ 스테이지 루트(self)까지만 올라간다 — 그 위로 새면 엉뚱한 노드를 집을 수 있다.
func _색가진_조상(맞은것: Object) -> Node:
	var n := 맞은것 as Node
	while n != null and n != self:
		if n.has_method("반대색인가"):
			return n
		n = n.get_parent()
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
	# ★[2026-08-17] 사망 = 스테이지 재시도 → 칠한 지형과 페인트를 **함께** 되돌린다.
	#   (스마트월드 `_리스폰()` → `코어.리셋()` 과 같은 규칙)
	#   탄약만 채우면 죽을 때마다 페인트가 공짜로 생기고,
	#   지형만 되돌리면 탄약이 말라 스테이지를 못 깬다. 둘은 같이 가야 한다.
	if 타일페인트 != null and 타일페인트.탄약을_쓰나():
		타일페인트.리셋()
	_무적 = 부활무적
	_사망중 = false
	if camera and camera.has_method("setup"):
		camera.setup(player)              # 부활 지점으로 카메라 즉시 스냅
