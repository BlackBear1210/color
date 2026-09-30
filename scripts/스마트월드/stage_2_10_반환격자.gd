@tool
extends "res://scripts/스마트월드/통과플랫폼.gd"

@export_enum("검정", "흰색") var 시작색: int = 0

func _ready() -> void:
	super._ready()
	# 두꺼운 SS2D 처마 대신 아래에서 통과하는 격자로 바꾸되 좌우 경로의 바탕색은 유지한다.
	_상태색 = 시작색
	var 충돌 := get_node("충돌") as CollisionShape2D
	충돌.one_way_collision = true
	충돌.one_way_collision_margin = 4.0
	queue_redraw()

func 강제_초기화() -> void:
	super.강제_초기화()
	# 재시작해도 흰색 경로가 갑자기 검정 발판으로 바뀌지 않게 한다.
	_상태색 = 시작색
	queue_redraw()

func 되돌리기() -> bool:
	if not super.되돌리기():
		return false
	_상태색 = 시작색
	queue_redraw()
	return true
