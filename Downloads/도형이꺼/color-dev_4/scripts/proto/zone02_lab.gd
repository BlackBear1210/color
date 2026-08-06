extends ZoneLab
## [2026-07-14 도형 · 신규] zone_02 전용 — "색 전환 잠금" 테스트 존.
## 기획서 1-4: Shift 전환은 "전환 허용 구역(SwitchZone)" 안에서만 가능해야 한다.
## 정식 경계 시스템은 P-A 담당(player.gd 수정 필요) — 여기서는 player.gd 를 안 고치고
## "전환이 일어난 것을 감지 → 허용 구역 밖이면 즉시 되돌리기" 방식으로 흉내 낸다(프로토).
##
## 맵 구성 (builder: tools/build_zones.gd):
##  - 경계선(가로 Line2D) 기준 위 = 백 지형만 / 아래 = 흑 지형만 (흑백 혼합 배치 금지 규칙 시연)
##  - SwitchZone(Area2D) = 경계 부근에서만 Shift 허용

var _in_switch_zone: bool = false
var _prev_color: int = ColorDefs.BLACK
var _reverting: bool = false   # 되돌리기 중 재감지 방지

func _ready() -> void:
	super._ready()
	_prev_color = player.get("player_color")
	var zone := get_node_or_null("SwitchZone") as Area2D
	if zone:
		zone.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _in_switch_zone = true)
		zone.body_exited.connect(func(b: Node2D) -> void:
			if b.is_in_group("player"): _in_switch_zone = false)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # 색 사망 판정 (ZoneLab 공통) 먼저 수행
	# 사망 리스폰 직후(grace)엔 감시 쉼 — 사망 시 색 복원을 "불법 전환"으로 오인하지 않도록
	if _grace > 0.0:
		_prev_color = player.get("player_color")
		return
	# player.gd 가 이번 프레임에 색을 바꿨는지 감시
	var col: int = player.get("player_color")
	if col == _prev_color or _reverting:
		return
	if _in_switch_zone:
		_prev_color = col                          # 허용 구역: 전환 승인
		brush_ui.show_message("색 전환!")
	else:
		# 잠김 구역: 전환 취소 — player 의 토글을 한 번 더 호출해 원상복구 (같은 프레임이라 화면에 안 보임)
		_reverting = true
		player.call("_toggle_color")
		_reverting = false
		brush_ui.show_message("⚠ 전환 잠김 — 전환 존(밝은 사각형 구역) 안에서만 가능")
