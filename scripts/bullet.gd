extends Area2D
## 직선으로 날아가는 총알. 벽에 닿거나 일정 시간이 지나면 사라짐.

@export var speed: float = 900.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	queue_free()
