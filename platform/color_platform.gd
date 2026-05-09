extends StaticBody2D

enum PlatformColor {
	WHITE,
	BLACK,
	ORANGE
}

@export var platform_color: PlatformColor = PlatformColor.WHITE

@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	update_platform_color()


func update_platform_color() -> void:
	match platform_color:
		PlatformColor.WHITE:
			sprite_2d.modulate = Color.WHITE
		PlatformColor.BLACK:
			sprite_2d.modulate = Color.BLACK
		PlatformColor.ORANGE:
			sprite_2d.modulate = Color.ORANGE
