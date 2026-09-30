extends SceneTree
## 배경의 잔무늬를 줄인 높이 추정값으로 약한 기술용 노멀맵을 한 번 생성한다.
func _initialize() -> void:
	var texture := load("res://assets/background/stage_2/brick_wall_v04/wall.png") as Texture2D
	var source := texture.get_image() if texture != null else null
	if source == null:
		quit(1)
		return
	# 명도를 높이로 추정하므로 정확한 기하 복원은 아니다. 작은 요철만 표현한다.
	source.resize(768, 512, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGB8)
	source.bump_map_to_normal_map(0.8)
	var result := source.save_png("res://assets/background/stage_2/brick_wall_v04/wall_normal.png")
	if result == OK:
		result = ResourceSaver.save(ImageTexture.create_from_image(source), "res://assets/background/stage_2/brick_wall_v04/wall_normal.res")
	print("WALL_NORMAL_RESULT ", result)
	quit(0 if result == OK else 1)
