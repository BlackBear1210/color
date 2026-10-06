extends SceneTree
## [2026-10-06 Claude] 쳅터 2(하수도) 지도 진행 검사 — 창 모드로 실행하면 로비·지도 화면도 찍는다.
##   Godot_console --path . -s res://tools/test_쳅터2_지도.gd
## 확인: 처음엔 2-1 만 열림 · 깨면 이어진 칸이 열림 · 출구 가로채기(지도 모드에서만) · 전부 깨면 쳅터 2 클리어
## ⚠ user://진행.cfg 를 쓰므로 시작할 때 백업하고 끝날 때 되돌린다(플레이 기록 보존).
const 폴더 := "res://tools/_진단/쳅터2_지도/"
var 통과 := 0
var 실패 := 0
var _백업 := ""
var _f := 0
var _씬: Node

func _확인(이름: String, 조건: bool) -> void:
	if 조건:
		통과 += 1
	else:
		실패 += 1
		print("  × ", 이름)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	if FileAccess.file_exists(게임진행.저장경로):
		_백업 = FileAccess.get_file_as_string(게임진행.저장경로)
	게임진행.진행_지우기()
	_확인("처음: 2-1 열림", 게임진행.열림("2-1"))
	_확인("처음: 2-2 잠김", not 게임진행.열림("2-2"))
	_확인("처음: 2-11 잠김", not 게임진행.열림("2-11"))
	# 지도 모드가 아니면 출구는 원래 목적지 그대로
	게임진행.지도_모드 = 0
	var 원래 := "res://scenes/world_2_클로드/stage_2-2.tscn"
	_확인("지도 밖: 가로채지 않음", 게임진행.통로_가로채기("res://scenes/world_2_클로드/stage_2-1.tscn", 원래) == 원래)
	_확인("지도 밖: 클리어 안 적힘", not 게임진행.클리어함("2-1"))
	# 지도 모드: 2-1 출구 → 지도로, 2-1 클리어
	게임진행.지도_모드 = 2
	_확인("지도: 출구 → 지도", 게임진행.통로_가로채기("res://scenes/world_2_클로드/stage_2-1.tscn", 원래) == 게임진행.지도_씬)
	_확인("지도: 2-1 클리어", 게임진행.클리어함("2-1"))
	_확인("2-2·2-3 열림", 게임진행.열림("2-2") and 게임진행.열림("2-3"))
	_확인("2-4 아직 잠김", not 게임진행.열림("2-4"))
	_확인("쳅터 1 쪽 씬은 가로채지 않음", 게임진행.통로_가로채기("res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn", 원래) == 원래)
	# 갈림길: 2-3 만 깨도 2-4·2-5 가 열린다
	게임진행.클리어_기록("2-3")
	_확인("2-3 → 2-4·2-5 열림", 게임진행.열림("2-4") and 게임진행.열림("2-5"))
	# 모든 씬 파일이 있다
	for 칸 in 게임진행.하수도_지도:
		_확인("씬 있음 " + 칸[0], ResourceLoader.exists(게임진행.씬경로(칸)))
	# 몇 칸 깬 상태로 지도 화면을 찍는다
	for 이름 in ["2-2", "2-4"]:
		게임진행.클리어_기록(이름)
	게임진행.마지막_칸 = "2-4"
	root.size = Vector2i(1280, 720)
	_씬 = load("res://scenes/lobby/lobby.tscn").instantiate()
	root.add_child(_씬)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 20:
		var 메뉴 = _씬.get_node("UILayer/Menu")
		_확인("로비: 쳅터 2 버튼", 메뉴.get_node_or_null("Chapter2Button") != null)
		_확인("로비: 시작 = 쳅터 1", (메뉴.get_node("StartButton") as Button).text.begins_with("쳅터 1"))
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(폴더 + "로비.png"))
		_씬.queue_free()
		_씬 = load(게임진행.지도_씬).instantiate()
		root.add_child(_씬)
	if _f == 50:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(폴더 + "지도_진행중.png"))
		for 칸 in 게임진행.하수도_지도:
			게임진행.클리어_기록(칸[0])
		_확인("전부 깨면 쳅터 2 클리어", 게임진행.쳅터_클리어함(2))
		_씬.queue_free()
		_씬 = load(게임진행.지도_씬).instantiate()
		root.add_child(_씬)
	if _f == 80:
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(폴더 + "지도_전부클리어.png"))
		# 기록 되돌리기
		if _백업.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(게임진행.저장경로))
		else:
			var f := FileAccess.open(게임진행.저장경로, FileAccess.WRITE)
			f.store_string(_백업)
			f.close()
		게임진행.지도_모드 = 0
		print("쳅터2 지도: 통과 %d · 실패 %d" % [통과, 실패])
		quit(1 if 실패 else 0)
	return false
