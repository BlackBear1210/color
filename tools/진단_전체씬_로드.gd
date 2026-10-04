extends SceneTree
## ============================================================================
## [2026-10-04 Claude] 전체 씬 로드 진단 — "안 켜지는 스테이지 · 지형 누락" 찾기
## ----------------------------------------------------------------------------
## 모든 .tscn 의 의존 파일(ext_resource)이 실제로 있는지 보고, 로드·인스턴스해서
## 지형(SS2D) 노드 수·점 수가 0 인 것을 찾는다. 결과는 UTF-8 파일로 쓴다
## (콘솔은 한글이 깨진다 — color-작업환경-제약 메모).
##
## 실행:  Godot_console --headless --path . -s res://tools/진단_전체씬_로드.gd
## 결과:  res://tools/_진단/전체씬_로드.txt
## ============================================================================

const 출력 := "res://tools/_진단/전체씬_로드.txt"
const 제외 := ["res://addons/", "res://.godot/", "/보관/", "/참고/", "res://tools/"]

var _줄: PackedStringArray = []


func _initialize() -> void:
	var 씬들: Array[String] = []
	_모으기("res://scenes", 씬들)
	씬들.sort()
	var 문제수 := 0
	for p in 씬들:
		var 문제 := _검사(p)
		if 문제 != "":
			문제수 += 1
	_줄.insert(0, "씬 %d개 · 문제 있는 씬 %d개\n" % [씬들.size(), 문제수])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/_진단"))
	var f := FileAccess.open(출력, FileAccess.WRITE)
	f.store_string("\n".join(_줄))
	f.close()
	print("DONE ", 씬들.size(), " ", 문제수)
	quit()


func _모으기(dir: String, out: Array[String]) -> void:
	for 제 in 제외:
		if dir.contains(제) or (dir + "/").contains(제):
			return
	var d := DirAccess.open(dir)
	if d == null:
		return
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for s in d.get_directories():
		_모으기(dir.path_join(s), out)


func _검사(p: String) -> String:
	var 문제: PackedStringArray = []
	# 1) 의존 파일
	for dep in ResourceLoader.get_dependencies(p):
		# 형식: "uid://...::타입::res://경로" 또는 "res://경로"
		var 조각 := dep.split("::")
		var 경로 := 조각[조각.size() - 1]
		var uid := 조각[0] if 조각.size() > 1 else ""
		var 있음 := ResourceLoader.exists(경로) or FileAccess.file_exists(경로)
		if not 있음 and uid.begins_with("uid://"):
			var id := ResourceUID.text_to_id(uid)
			if ResourceUID.has_id(id):
				문제.append("경로 없음(uid 로는 찾음 → %s): %s" % [ResourceUID.get_id_path(id), 경로])
				continue
		if not 있음:
			문제.append("파일 없음: " + 경로)
	# 2) 로드·인스턴스·지형
	var 팩 := ResourceLoader.load(p, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var 요약 := ""
	if 팩 == null:
		문제.append("로드 실패")
	else:
		var n := 팩.instantiate()
		if n == null:
			문제.append("인스턴스 실패")
		else:
			var 지형 := 0
			var 빈지형 := 0
			for c in _모두(n):
				if c.get_script() and c.has_method("get_point_count"):
					지형 += 1
					if int(c.call("get_point_count")) < 3:
						빈지형 += 1
				elif c is Node2D and c.get("_points") != null and c.get("_points") is Resource:
					지형 += 1
			요약 = "지형 %d" % 지형
			if 빈지형 > 0:
				문제.append("점이 3개 미만인 지형 %d개" % 빈지형)
			var 월드 := n.get_script() != null and String(n.get_script().resource_path).ends_with("월드.gd")
			if 월드 and 지형 == 0:
				문제.append("월드 씬인데 지형이 0")
			n.free()
	var 상태 := "○" if 문제.is_empty() else "×"
	_줄.append("%s %s  (%s)" % [상태, p, 요약])
	for m in 문제:
		_줄.append("    - " + m)
	return "" if 문제.is_empty() else p


func _모두(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_모두(c))
	return out
