extends ZoneLab
## [2026-07-19 도형 · v2] world_1 통합 씬 로직 — zone1 → zone2 → zone3 심리스 연결.
##
## v1 (2026-07-18): zone1+zone2 를 한 씬에 잇고 씬 교체 대신 카메라 리밋 트윈으로
## 구역을 넘어가는 "바인(Vane)식" 전환. (설명은 git 이력 참조)
##
## v2 변경 (2026-07-19):
##  1. ★zone2 색 전환 잠금(SwitchZone 감시-되돌리기) 삭제 —
##     docs/경계_색구역_시스템.md 의 ColorZone(다각형 색 강제 구역)으로 대체.
##     구역 안 = 자동 색 고정 / 구역 밖(복도·다리) = 키보드 자유 전환.
##     색 강제는 ColorZone 스스로 처리하므로 이 스크립트에는 잠금 코드가 없다.
##  2. ★ZONE 3 (수직 도시) 추가 — 구역 3개의 카메라 리밋·줌·체크포인트·타이틀.
##     zone3 는 위로 긴 구역이라 리밋 세로가 매우 크고 줌을 0.9 로 당긴다.
##
## 구역별 규칙:
##  - ZONE 1: 자유 전환. 횟수제 칠하기·회수·색 사망 검증 맵.
##  - ZONE 2: 경계선 위 = 백 구역(자동 白) / 아래 = 흑 구역(자동 黑).
##  - ZONE 3: 높이 밴드마다 흑/백 ColorZone 이 번갈아 — 올라갈수록 색이 뒤집힌다.
##    밴드 사이 회색(중립) 발판 = 안전 전환 지대.
class_name WorldLab

## 구역별 카메라 리밋 (월드 px). 세로 648(뷰포트 높이)/줌 이상이어야 클램프가 산다.
const REGIONS := {
	1: Rect2(-192, -136, 2144, 648),      # x: -192 ~ 1952
	2: Rect2(1600, -168, 2048, 680),      # x: 1600 ~ 3648
	3: Rect2(3520, -1080, 1456, 1768),    # x: 3520 ~ 4976 · y: -1080 ~ 688 (수직 구역)
}
## 구역 경계 x + 히스테리시스(경계에서 서성일 때 리밋이 다다닥 튀는 것 방지)
## 1650 = zone1↔2 복도 중반 (스크린샷 검증으로 조정, v1 그대로).
## 3500 = zone2↔3 다리(y6, x3360~3776) 중반.
const BORDER12_X: float = 1650.0
const BORDER23_X: float = 3500.0
const BORDER_HYST: float = 60.0
## 구역별 카메라 줌 — 넓은/높은 구역일수록 줌아웃해 "새 지역이 펼쳐진다"는 개방감.
const REGION_ZOOM := { 1: 1.0, 2: 0.95, 3: 0.9 }
## 구역별 체크포인트 — 전부 ★회색(중립) 지형 위★라 어느 색으로 리스폰해도 안전
## (반대색 바닥 리스폰 → 즉사 무한 루프가 원천적으로 불가능한 위치).
## zone3 체크포인트 = 진입 다리 위 — 이 지점은 zone2 백 구역 x 범위 안이라
## 리스폰 직후 ColorZone 이 색을 백으로 맞춰 준다.
const CHECKPOINT := { 1: Vector2(96, 445), 2: Vector2(1800, 445), 3: Vector2(3400, 189) }
const TITLES := {
	1: "ZONE 1 — 물감의 규칙",
	2: "ZONE 2 — 흑백의 경계",
	3: "ZONE 3 — 수직 도시",
}
const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"

var _region: int = 1
var _cleared: bool = false
var _title_label: Label

func _ready() -> void:
	super._ready()
	# 통합 씬의 자동 리밋(지형 전체)을 구역 1 리밋으로 좁힌다 (즉시)
	camera.set_limit_rect(REGIONS[1], false)
	camera.setup(player)

	# 골인 지점 (zone3 옥상) → 월드 클리어 연출
	var exit := get_node_or_null("ExitZone") as Area2D
	if exit:
		exit.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _on_world_clear())

	_make_title_label()
	_show_title(TITLES[1])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # 색 사망 판정 (ZoneLab 공통)
	_update_region()
	# (v2) zone2 색 전환 잠금 감시는 삭제됨 — ColorZone 이 구역 색을 스스로 강제한다

## ── 구역 감지 → 카메라 리밋 트윈 + 체크포인트 + 타이틀 ────────────────
## x 좌표 + 히스테리시스로 현재 구역을 정한다. 히스테리시스 밴드 안(경계 부근)에서는
## 구역을 바꾸지 않아 경계에서 서성여도 카메라가 튀지 않는다.
func _update_region() -> void:
	var px := player.global_position.x
	var target := _region
	if px > BORDER23_X + BORDER_HYST:
		target = 3
	elif px > BORDER12_X + BORDER_HYST and px < BORDER23_X - BORDER_HYST:
		target = 2
	elif px < BORDER12_X - BORDER_HYST:
		target = 1
	if target != _region:
		_enter_region(target)

func _enter_region(r: int) -> void:
	_region = r
	# ★심리스 전환의 핵심: 씬 교체가 아니라 카메라 리밋+줌만 부드럽게 트윈
	camera.set_limit_rect(REGIONS[r], true)
	camera.set_region_zoom(REGION_ZOOM[r], true)
	_spawn_pos = CHECKPOINT[r]
	# 리스폰 색: zone1 체크포인트는 흑 바닥이므로 흑 고정(백이면 즉사 루프).
	# zone2/3 체크포인트는 회색(중립)이라 지금 색 유지 — 어차피 ColorZone 구역 안이면
	# 리스폰 다음 물리 프레임에 구역 색으로 자동 교정된다.
	_spawn_color = ColorDefs.BLACK if r == 1 else player.get("player_color")
	_show_title(TITLES[r])

## ── 월드 클리어: 흰 잉크로 로비 복귀 ───────────────────────────────────
func _on_world_clear() -> void:
	if _cleared:
		return
	_cleared = true
	_show_title("WORLD 1 CLEAR")
	brush_ui.show_message("🎉 옥상 도달 — zone1→2→3 심리스 등반 완료!")
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
