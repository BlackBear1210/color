extends Node2D
## ============================================================================
## [2026-08-01 신규] 페인트 총 — 조준 / 발사 / 덤불 내부 판정
## ----------------------------------------------------------------------------
## ▣ Player.tscn 무수정 원칙
##   기존 `scripts/gun.gd` 는 총알을 직접 만들어 쏜다(구 시스템). 그걸 고치면
##   다른 스테이지가 깨진다. 그래서 **런타임에 Gun 노드의 _process 를 꺼두고**
##   조준(look_at)과 발사를 여기서 대신한다.
##   → 동현 테스트월드제작.gd 가 쓰던 것과 똑같은 방식이다.
##
## ▣ 탄약 규칙 (페인트_코어.gd)
##   쏠 때 1발 소모 → 빗나가거나 못 칠하는 대상이면 코어가 그 자리에서 환급한다.
##   그래서 "허공에 쏘면 손해"가 아니라 "맞혀야만 잠긴다" 는 규칙이 성립한다.
##
## ▣ 덤불(식물 B) 안에서 쏠 때 (기획 규칙)
##   총구가 덤불 안이고 **커서도 덤불 안**이면 → 덤불이 칠해진다(투사체 없음).
##   총구가 덤불 안이지만 **커서가 덤불 밖**이면 → 총알이 덤불을 뚫고 나간다.
## ============================================================================
class_name 페인트총

const 총알_스크립트 := preload("res://scripts/스마트월드/총알.gd")

## 총구를 떠나는 속력(px/s). 낮출수록 탄낙차가 커진다.
@export var 탄속: float = 1150.0
## 연사 간격(초).
@export var 발사간격: float = 0.22

var 플레이어: Node2D = null
var 코어: 페인트코어 = null

var _gun: Node2D = null
var _muzzle: Marker2D = null
var _쿨: float = 0.0


func 연결(p_player: Node2D, p_코어: 페인트코어) -> void:
	플레이어 = p_player
	코어 = p_코어
	_gun = 플레이어.get_node_or_null("Gun") as Node2D
	if _gun:
		# 구 gun.gd 의 자동 발사를 끈다 — 조준은 우리가 대신 돌려준다.
		_gun.set_process(false)
		_muzzle = _gun.get_node_or_null("Muzzle") as Marker2D


func _process(delta: float) -> void:
	_쿨 = maxf(_쿨 - delta, 0.0)
	if _gun and is_instance_valid(_gun):
		_gun.look_at(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		발사()


func 발사() -> void:
	if _쿨 > 0.0 or 플레이어 == null or 코어 == null:
		return
	var 시작 := _muzzle.global_position if _muzzle else 플레이어.global_position
	var 커서 := get_global_mouse_position()
	var 색: int = 플레이어.get("player_color")

	# ── 덤불 안에서 쏘는 경우 ──
	var 덤불 := _총구가_속한_덤불(시작)
	if 덤불 != null and 덤불.안에_있나(커서):
		if not 코어.쏠_수_있나():
			return
		_쿨 = 발사간격
		코어.발사_소모()
		코어.명중_처리(덤불, 색, 커서)
		return

	# ── 평범한 발사 ──
	if not 코어.쏠_수_있나():
		return
	var 방향 := 커서 - 시작
	if 방향.length() < 4.0:
		return
	_쿨 = 발사간격
	코어.발사_소모()

	var 총알 := Area2D.new()
	총알.set_script(총알_스크립트)
	get_parent().add_child(총알)
	총알.시작(시작, 방향, 탄속, 색, 코어)


## 총구가 어느 덤불 안에 있는지. 없으면 null.
func _총구가_속한_덤불(총구: Vector2) -> 식물B:
	for n in get_tree().get_nodes_in_group("식물B"):
		var b := n as 식물B
		if b and b.안에_있나(총구):
			return b
	return null
