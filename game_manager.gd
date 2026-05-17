extends Node

# 현재 선택된 월드/스테이지
var selected_world: int = 1
var selected_stage: int = 1

# -------------------------------------------------------
# 스테이지 데이터
# 새 월드/스테이지 추가 시 여기에만 경로를 추가하면 됨
# -------------------------------------------------------
const STAGE_DATA: Dictionary = {
	1: {
		"name": "World 1",
		1: "res://map/world_1/stage_1.tscn",
		# 2: "res://map_dohyoung/world_1/stage_2.tscn",  # 제작 후 주석 해제
	},
	# 2: {
	# 	"name": "World 2",
	# 	1: "res://map_dohyoung/world_2/stage_1.tscn",
	# },
}

# -------------------------------------------------------
# 씬 전환
# -------------------------------------------------------
func go_to_lobby() -> void:
	get_tree().change_scene_to_file("res://ui/main_lobby.tscn")


func go_to_world_select() -> void:
	get_tree().change_scene_to_file("res://ui/world_select.tscn")


func go_to_stage_select(world_id: int) -> void:
	selected_world = world_id
	get_tree().change_scene_to_file("res://ui/stage_select.tscn")


func start_stage(stage_id: int) -> void:
	selected_stage = stage_id
	var path: String = STAGE_DATA[selected_world][stage_id]
	get_tree().change_scene_to_file(path)


# -------------------------------------------------------
# 데이터 조회
# -------------------------------------------------------
func get_world_list() -> Array:
	return STAGE_DATA.keys()


func get_stage_list(world_id: int) -> Array:
	if not STAGE_DATA.has(world_id):
		return []
	var keys: Array = STAGE_DATA[world_id].keys()
	keys.erase("name")  # name 키는 제외
	return keys


func get_world_name(world_id: int) -> String:
	if STAGE_DATA.has(world_id):
		return STAGE_DATA[world_id]["name"]
	return "Unknown"
