extends StaticBody2D
## 스파이크 장애물.
## - StaticBody2D 본체(layer 256)로 플레이어를 물리적으로 막음
## - KillArea(Area2D)가 본체보다 약간 크게 설정되어 있어,
##   물리 충돌이 멈추기 직전에 사망 판정이 먼저 발동됨
## - "obstacle" 그룹에 등록되어 총알이 맞아도 PaintMark를 생성하지 않음

@onready var kill_area: Area2D = $KillArea

func _ready() -> void:
	# "obstacle" 그룹 등록 → bullet.gd가 스파이크에 PaintMark를 생성하지 않도록 차단
	add_to_group("obstacle")

	# KillArea의 body_entered 신호를 수신 → 플레이어 접촉 시 사망 판정
	kill_area.body_entered.connect(_on_kill_area_entered)

func _on_kill_area_entered(body: Node) -> void:
	# "player" 그룹인 바디만 처리 (총알·발판 등 다른 오브젝트는 무시)
	if body.is_in_group("player"):
		# body_entered 콜백 내에서 die()를 직접 호출하면 physics flush 오류 발생
		# → call_deferred로 다음 프레임에 호출
		body.call_deferred("die")
