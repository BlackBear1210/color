extends SceneTree
## ============================================================================
## [2026-09-14 신규] 유체 색 진단 — "왜 이 물이 회색이 됐나" 를 프레임 단위로 찍는다
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/진단_유체색.gd -- <씬경로>
##
## ▣ 왜 필요한가
##   유체는 매 물리 프레임 **겹치는 다른 유체와 색을 섞는다**(검+흰=회). 판정 모양이 그림
##   실루엣(프레임마다 다름)이라 명목 사각형이 안 닿아 보여도 실제로는 겹칠 수 있다.
##   2-2 재제작 때 흰 물줄기가 회색으로 찍혀서 만들었다. 씬을 고치지 않는다.
## ============================================================================

func _initialize() -> void:
	Engine.max_fps = 0
	_실행()


func _실행() -> void:
	var 인자: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	if 인자.is_empty():
		print("사용법: -- <씬경로>")
		quit(1)
		return
	var ps := load(String(인자[0])) as PackedScene
	var 씬 := ps.instantiate() as Node2D
	root.add_child(씬)
	for i in 8:
		await physics_frame
	print("── 유체 색 (8 프레임 뒤) ──")
	for n in 씬.get_tree().get_nodes_in_group("유체"):
		var f := n as Area2D
		var 이름들: Array = []
		for a in f.get_overlapping_areas():
			이름들.append(a.name)
		var 몸들: Array = []
		for b in f.get_overlapping_bodies():
			몸들.append(b.name)
		print("  %-16s 색=%d 원래=%s 켜짐=%s 위치=(%.0f,%.0f) 크기=%s  겹친 영역=%s  겹친 몸=%s" % [
			f.name, int(f.get("색")), str(f.get("_원래색")), str(f.get("켜짐")),
			f.global_position.x, f.global_position.y, str(f.get("크기")), str(이름들), str(몸들)])
	quit(0)
