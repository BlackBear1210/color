extends Area2D

@export var speed: float = 600.0

var direction: Vector2 = Vector2.RIGHT
var player_color
var black_tilemap: TileMapLayer
var white_tilemap: TileMapLayer

func _ready() -> void:
	rotation = direction.angle()

	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 10.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.start()

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is TileMapLayer:
		print("타일 충돌: ", body.name, " / player_color: ", player_color)
		var is_target = (player_color == 1 and body == black_tilemap) or \
						(player_color == 0 and body == white_tilemap)
		if is_target:
			var stage = get_tree().get_first_node_in_group("stage")
			print("stage 찾음: ", stage)
			if stage:
				stage.flip_tiles(global_position)
	queue_free()
