extends Control

@onready var button_container: VBoxContainer = $VBoxContainer/ButtonContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel


func _ready() -> void:
	title_label.text = "World 선택"
	_create_world_buttons()


func _create_world_buttons() -> void:
	# 기존 버튼 제거
	for child in button_container.get_children():
		child.queue_free()

	# 월드 수만큼 버튼 자동 생성
	for world_id in GameManager.get_world_list():
		var btn := Button.new()
		btn.text = GameManager.get_world_name(world_id)
		btn.custom_minimum_size = Vector2(200, 50)
		btn.pressed.connect(_on_world_selected.bind(world_id))
		button_container.add_child(btn)


func _on_world_selected(world_id: int) -> void:
	GameManager.go_to_stage_select(world_id)


func _on_back_button_pressed() -> void:
	GameManager.go_to_lobby()
