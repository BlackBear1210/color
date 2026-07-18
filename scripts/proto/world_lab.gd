extends ZoneLab
## [2026-07-18 도형 · 신규] world_1 통합 씬 로직 — zone1 → zone2 "바인(Vane)식" 심리스 연결.
##
## 기존 문제: 존마다 씬이 따로라 이동 시 로딩/암전이 끼어 흐름이 끊겼다.
## '바인'의 구역 전환(1구역 클리어 → 카메라가 다음 구역으로 자연스럽게 흘러가고
## 캐릭터는 계속 앞으로 걷는다)을 재현하기 위해:
##  1. zone1 지형과 zone2 지형을 ★한 씬 안에★ 복도로 이어 배치 (tools/build_world.gd)
##  2. 씬 교체 대신 "카메라 리밋 사각형"만 구역별로 두고, 경계를 넘는 순간
##     ProtoCamera.set_limit_rect(..., true) 로 리밋을 트윈 → 화면이 끊김 없이
##     다음 구역 프레이밍으로 미끄러져 간다 (플레이어 조작은 한 순간도 안 멈춤)
##  3. 구역 진입 시 체크포인트 갱신 + 구역 타이틀이 잠깐 떠올랐다 사라짐
##
## 구역별 규칙 (기존 테스트 존 규칙 그대로):
##  - ZONE 1 구역: 자유 전환. 횟수제 칠하기·회수·색 사망 검증 맵.
##  - ZONE 2 구역: 색 전환 잠금 — SwitchZone(밝은 사각형) 안에서만 Shift 허용.
##    (zone02_lab.gd 의 감시-되돌리기 프로토 방식을 구역 한정으로 이식)
class_name WorldLab

## 구역별 카메라 리밋 (월드 px). 세로 648(뷰포트 높이) 이상이어야 클램프가 산다.
## zone2 는 위로 높은 맵(row -4)이라 리밋 상단이 더 높다 → 전환 트윈 때
## 화면이 위로 스르륵 열리는 것이 그대로 "구역이 바뀌었다"는 연출이 된다.
const REGION_1 := Rect2(-192, -136, 2144, 648)     # x: -192 ~ 1952
const REGION_2 := Rect2(1600, -168, 2048, 680)     # x: 1600 ~ 3648
## 구역 경계 x + 히스테리시스(경계에서 서성일 때 리밋이 다다닥 튀는 것 방지)
## 1650 = 복도 중반. 이보다 늦으면(1750) 플레이어가 화면 오른쪽 끝에 닿은 뒤에야
## 카메라가 풀려서 전방이 안 보이는 순간이 생긴다 (스크린샷 검증으로 조정).
const BORDER_X: float = 1650.0
const BORDER_HYST: float = 60.0
## 구역별 카메라 줌 — zone2 는 위로 높은 구역이라 살짝 줌아웃(0.95)해서
## 진입 순간 "넓은 새 지역이 펼쳐진다"는 개방감을 준다 (리밋 트윈과 한 호흡).
const REGION_ZOOM := { 1: 1.0, 2: 0.95 }
## 구역별 체크포인트 (사망 시 구역 시작점에서 리스폰 — 존 간 강제 이동 없음)
## zone2 체크포인트는 ★회색 복도 바닥★ 위 — 회색은 어느 색이든 안전하므로
## "반대색 바닥에 리스폰 → 즉사 → 무한 루프" 사고가 원천적으로 불가능한 위치다.
const CHECKPOINT := { 1: Vector2(96, 445), 2: Vector2(1800, 445) }
const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var _region: int = 1
## ── zone2 색 전환 잠금 상태 (zone02_lab.gd 프로토 이식) ─────────────────
var _in_switch_zone: bool = false
var _prev_color: int = ColorDefs.BLACK
var _reverting: bool = false
var _cleared: bool = false
var _title_label: Label

func _ready() -> void:
	super._ready()
	# 통합 씬의 자동 리밋(지형 전체)을 구역 1 리밋으로 좁힌다 (즉시)
	camera.set_limit_rect(REGION_1, false)
	camera.setup(player)

	_prev_color = player.get("player_color")
	var zone := get_node_or_null("SwitchZone") as Area2D
	if zone:
		zone.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _in_switch_zone = true)
		zone.body_exited.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _in_switch_zone = false)

	# 골인 지점 (zone2 상층 우측 끝) → 월드 클리어 연출
	var exit := get_node_or_null("ExitZone") as Area2D
	if exit:
		exit.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _on_world_clear())

	_make_title_label()
	_show_title("ZONE 1 — 물감의 규칙")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # 색 사망 판정 (ZoneLab 공통)
	_update_region()
	_watch_switch_lock()

## ── 구역 감지 → 카메라 리밋 트윈 + 체크포인트 + 타이틀 ────────────────
func _update_region() -> void:
	var px := player.global_position.x
	if _region == 1 and px > BORDER_X + BORDER_HYST:
		_enter_region(2)
	elif _region == 2 and px < BORDER_X - BORDER_HYST:
		_enter_region(1)

func _enter_region(r: int) -> void:
	_region = r
	# ★심리스 전환의 핵심: 씬 교체가 아니라 카메라 리밋+줌만 부드럽게 트윈
	camera.set_limit_rect(REGION_1 if r == 1 else REGION_2, true)
	camera.set_region_zoom(REGION_ZOOM[r], true)
	_spawn_pos = CHECKPOINT[r]
	# 리스폰 색: zone1 체크포인트는 흑 바닥이므로 흑 고정(백이면 즉사 루프),
	# zone2 체크포인트는 회색(중립) 바닥이라 지금 색 그대로 유지해도 안전.
	_spawn_color = ColorDefs.BLACK if r == 1 else player.get("player_color")
	_show_title("ZONE 1 — 물감의 규칙" if r == 1 else "ZONE 2 — 흑백의 경계")

## ── zone2 한정 색 전환 잠금 (허용 구역 밖 전환 즉시 되돌림) ───────────
func _watch_switch_lock() -> void:
	# 사망 리스폰 직후(grace)엔 감시 쉼 — 색 복원을 "불법 전환"으로 오인하지 않도록
	if _grace > 0.0:
		_prev_color = player.get("player_color")
		return
	var col: int = player.get("player_color")
	if col == _prev_color or _reverting:
		return
	if _region != 2 or _in_switch_zone:
		_prev_color = col                        # zone1 은 자유 / zone2 는 존 안에서만 승인
		if _region == 2:
			brush_ui.show_message("색 전환!")
	else:
		# 잠김: player 토글을 한 번 더 호출해 원상복구 (같은 프레임이라 화면엔 안 보임)
		_reverting = true
		player.call("_toggle_color")
		_reverting = false
		brush_ui.show_message("⚠ 전환 잠김 — 전환 존(밝은 사각형 구역) 안에서만 가능")

## ── 월드 클리어: 흰 잉크로 로비 복귀 ───────────────────────────────────
func _on_world_clear() -> void:
	if _cleared:
		return
	_cleared = true
	_show_title("WORLD 1 CLEAR")
	brush_ui.show_message("🎉 zone1 → zone2 심리스 연결 확인 완료!")
	await get_tree().create_timer(1.6).timeout
	StageTransition.change_scene(self, LOBBY_SCENE, Color(0.96, 0.96, 0.96))

## ── 구역 타이틀 (화면 상단 중앙, 떠올랐다 사라짐) ──────────────────────
func _make_title_label() -> void:
	_title_label = Label.new()
	_title_label.name = "RegionTitle"
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position = Vector2(-400, 90)
	_title_label.size = Vector2(800, 60)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
	_title_label.add_theme_constant_override("outline_size", 10)
	_title_label.modulate.a = 0.0
	($UI as CanvasLayer).add_child(_title_label)

func _show_title(text: String) -> void:
	_title_label.text = text
	var tw := create_tween()
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(_title_label, "modulate:a", 0.0, 0.8)
