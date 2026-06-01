extends Node2D
## 총알이 지형에 닿는 순간 재생되는 일회성 스플래시 이펙트.
## 0.22초 뒤 자동 삭제된다. bullet.gd 에서 생성.

var _color: int = ColorDefs.BLACK

func _ready() -> void:
	# 랜덤 회전으로 매번 다른 방향으로 튄 느낌
	rotation = randf_range(0.0, TAU)

	# 색에 맞는 스프라이트만 표시
	$Sprite2D_Black.visible = (_color == ColorDefs.BLACK)
	$Sprite2D_White.visible = (_color == ColorDefs.WHITE)

	# 크게 시작해서 빠르게 수축 + 투명해지며 사라짐
	scale = Vector2(1.6, 1.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale",      Vector2(0.6, 0.6), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0,               0.22)
	tw.chain().tween_callback(queue_free)

## bullet.gd 에서 호출: add_child 전에 색 지정
func set_color(c: int) -> void:
	_color = c
