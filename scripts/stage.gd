extends Node2D
## 각 스테이지의 베이스 스크립트.
## KillZone 에 빠진 바디에 die() 를 호출하는 역할만 담당.
## 포탈·클리어 연출은 나중에 추가.

@onready var kill_zone: Area2D = $MapPhysics/KillZone

func _ready() -> void:
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)

func _on_kill_zone_entered(body: Node) -> void:
	if body.has_method("die"):
		body.die()
