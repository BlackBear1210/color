extends Area2D
## ▼ 2026-06-22 신규: 체크포인트.
##   플레이어가 닿으면 그 위치를 부활 지점으로 갱신(긴 스테이지 좌절감 완화).
##   - player.gd 의 respawn_point 를 직접 갱신(플레이어는 죽으면 그 지점에서 부활).
##   - 추격 스테이지에서도 안전: 불벽은 사망 시 시작점으로 리셋되므로, 체크포인트에서
##     부활해도 불은 멀리 뒤(시작점)에서 다시 다가온다.

@export var respawn_offset: Vector2 = Vector2(0, -40)   # 발판 위로 살짝 띄워 부활

var _activated: bool = false
@onready var _flag: Polygon2D = get_node_or_null("Flag")


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1          # 플레이어만 감지
	monitoring      = true
	monitorable     = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _activated or not body.is_in_group("player"):
		return
	_activated = true
	# 부활 지점 갱신
	if "respawn_point" in body:
		body.respawn_point = global_position + respawn_offset
	# 깃발 색을 켜진 색으로(피드백)
	if _flag:
		_flag.color = Color(0.2, 0.9, 0.45, 0.95)
	AudioManager.play_sfx("switch")
