extends RigidBody2D

@export var despawn_y: float = 800.0

func _ready() -> void:
	add_to_group("falling_blocks")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if global_position.y > despawn_y:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.die()
		queue_free()
