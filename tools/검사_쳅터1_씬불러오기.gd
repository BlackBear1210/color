extends SceneTree
## [2026-10-09 Claude] 쳅터1 스테이지 씬 전부 불러 보기 — 리소스 id·참조 오류 확인용
func _initialize() -> void:
	var d := DirAccess.open("res://scenes/쳅터1/스테이지/")
	var n := 0
	for f in d.get_files():
		if f.ends_with(".tscn"):
			var s = (load("res://scenes/쳅터1/스테이지/" + f) as PackedScene).instantiate()
			n += 1
			s.free()
	print("불러온 씬 ", n)
	quit()
