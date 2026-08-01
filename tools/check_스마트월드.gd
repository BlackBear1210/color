extends SceneTree
## [2026-08-01 신규] 스마트월드 스크립트 일괄 파싱 검사.
## 실행: Godot --headless --path . -s res://tools/check_스마트월드.gd
## GDScript 는 load() 시점에 파싱되므로, 여기서 통과하면 문법·타입 오류는 없다.

func _init() -> void:
	var 실패 := 0
	var 대상 := []
	for 폴더 in ["res://scripts/스마트월드/", "res://shaders/"]:
		var d := DirAccess.open(폴더)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd") or f.ends_with(".gdshader"):
				대상.append(폴더 + f)
	for 경로 in 대상:
		var r := load(경로)
		if r == null:
			push_error("로드 실패: %s" % 경로)
			실패 += 1
		else:
			print("  OK  %s" % 경로)
	print("[check] %d개 중 실패 %d" % [대상.size(), 실패])
	quit(실패)
