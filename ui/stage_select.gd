extends Control

@onready var button_container: VBoxContainer = $VBoxContainer/ButtonContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel


func _ready() -> void:
	title_label.text = "%s - Stage 선택" % GameManager.get_world_name(GameManager.selected_world)
	_create_stage_buttons()


func _create_stage_buttons() -> void:
	# 기존 버튼 제거
	for child in button_container.get_children():
		child.queue_free()

	# 선택된 월드의 스테이지 수만큼 버튼 자동 생성
	for stage_id in GameManager.get_stage_list(GameManager.selected_world):
		var btn := Button.new()
		btn.text = "Stage %d" % stage_id
		btn.custom_minimum_size = Vector2(200, 50)
		btn.pressed.connect(_on_stage_selected.bind(stage_id))
		button_container.add_child(btn)


func _on_stage_selected(stage_id: int) -> void:
	GameManager.start_stage(stage_id)


func _on_back_button_pressed() -> void:
	GameManager.go_to_world_select()
