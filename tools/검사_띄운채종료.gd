## [2026-10-09] 씬을 띄운 채 바로 quit — 종료 순서 충돌 확인용
extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var 이름: String = OS.get_cmdline_user_args()[0]
	var s = (load("res://scenes/쳅터1/스테이지/%s.tscn" % 이름) as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	for k in 40: await physics_frame
	quit()
