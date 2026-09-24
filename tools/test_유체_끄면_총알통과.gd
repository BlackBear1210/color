extends SceneTree
## ============================================================================
## [2026-09-21 Claude] 물을 끄면 총알이 지나가나 — 레버(밸브)로 잠근 물이 총알을 막던 문제의 회귀 검사
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_유체_끄면_총알통과.gd
##
## ▣ 무엇이 문제였나 (2-5 에서 도형님이 발견 · 아스트라가 원인 추정 · 여기서 실측)
##   ① `유체._켜짐_반영()` 이 monitoring 만 껐다 → Area2D 는 monitorable 이 남아 **다른 Area(총알)에는 계속 잡힌다.**
##   ② `총알.gd` 가 `총알_막나()` 가 false 라고 답한 물도 그 다음 `has_method("명중")` 가지로 떨어뜨렸다 —
##      유체에도 `명중()`(= "blocked") 이 있어서 **꺼진 물 · 같은 색 물 · 회색 물** 전부 총알을 삼켰다.
##   고침: 유체는 끄면 collision_layer 0 + monitorable off · 총알은 `총알_막나` 가 있는 것은 그 답만 따른다.
##
## ▣ 검사 방법 — 진짜 `유체.tscn` 과 진짜 `총알.gd` 를 쓴다(검사용 더미 없음). 물 뒤에 StaticBody2D 과녁을 두고
##   총알이 과녁까지 가면 "통과", 물 앞에서 사라지면 "막힘". 과녁 명중은 총알의 레이캐스트(레이어 1)로 잡힌다.
## ============================================================================

const 유체_씬 := preload("res://scenes/집/스마트월드_장애물/유체.tscn")
const 총알_S := preload("res://scripts/스마트월드/총알.gd")

var _실패 := 0
var _통과 := 0


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	# 켜진 반대색 물 → 막힌다 (기존 규칙이 그대로인지)
	await _한_번("켜진 흰 물 · 검정 총알", 1, true, 0, false)
	await _한_번("켜진 검정 물 · 흰 총알", 0, true, 1, false)
	# 꺼진 물 → 통과 (밸브로 잠근 물)
	await _한_번("꺼진 흰 물 · 검정 총알", 1, false, 0, true)
	await _한_번("꺼진 검정 물 · 흰 총알", 0, false, 1, true)
	# 같은 색 · 회색 → 통과 (총알.gd ② 의 회귀)
	await _한_번("켜진 흰 물 · 흰 총알", 1, true, 1, true)
	await _한_번("켜진 회색 물 · 검정 총알", 2, true, 0, true)
	# 켜 두었다가 물리 중에 끄고, 다시 켜기 — 레버가 하는 일 그대로
	await _한_번("켰다 끈 흰 물 · 검정 총알", 1, true, 0, true, [false])
	await _한_번("껐다 다시 켠 흰 물 · 검정 총알", 1, false, 0, false, [true])
	print("\n================ 결과: 통과 %d · 실패 %d ================" % [_통과, _실패])
	quit(1 if _실패 > 0 else 0)


## 물(폭 128 · 길이 400)을 x 0 에 세우고, 왼쪽 -300 에서 오른쪽으로 총알을 쏜다. 과녁은 x +300.
## `토글` 은 발사 직전에 `켜짐` 을 차례로 덮어쓰는 값들(레버 조작 흉내).
func _한_번(이름: String, 물색: int, 처음켜짐: bool, 총알색: int, 통과해야: bool, 토글: Array = []) -> void:
	var 월드 := Node2D.new()
	root.add_child(월드)
	var 물 := 유체_씬.instantiate() as Node2D
	물.set("색", 물색)
	물.set("켜짐", 처음켜짐)
	물.set("크기", Vector2(128, 400))
	물.position = Vector2(0, -200)
	월드.add_child(물)
	var 과녁 := StaticBody2D.new()
	과녁.collision_layer = 1
	var 모양 := CollisionShape2D.new()
	var 상자 := RectangleShape2D.new()
	상자.size = Vector2(40, 600)
	모양.shape = 상자
	과녁.add_child(모양)
	과녁.position = Vector2(300, 0)
	월드.add_child(과녁)
	for i in 3:
		await physics_frame
	for v in 토글:
		물.set("켜짐", v)
	# 레버는 물리 콜백 안에서 켜짐을 뒤집을 수 있다 — 지연 반영이 끝나도록 한 프레임 준다.
	await physics_frame
	var 총알 := Area2D.new()
	총알.set_script(총알_S)
	월드.add_child(총알)
	총알.set("최대_수명", 3.0)
	총알.call("시작", Vector2(-300, 0), Vector2.RIGHT, 900.0, 총알색, null)
	총알.set("중력", 0.0)
	var 마지막x := -300.0
	for i in 120:
		await physics_frame
		if not is_instance_valid(총알):
			break
		마지막x = 총알.global_position.x
	var 도달 := 마지막x > 200.0
	var ok := 도달 == 통과해야
	print("  %s %-28s 물=%s 켜짐=%s 총알=%s → 마지막 x=%.0f (%s)" % [
		"✔" if ok else "✖", 이름, ["검정", "흰색", "회색"][물색], str(물.get("켜짐")),
		["검정", "흰색"][총알색], 마지막x, "통과" if 도달 else "막힘"])
	if ok:
		_통과 += 1
	else:
		_실패 += 1
	월드.queue_free()
	await physics_frame
	await physics_frame
