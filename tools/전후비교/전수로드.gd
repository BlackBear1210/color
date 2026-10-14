extends SceneTree
## [2026-10-14 Claude] 전후비교 ① — 프로젝트 안 모든 씬·리소스·스크립트·셰이더를 하나씩 load() 해 본다.
## 실행은 `python -X utf8 tools/전후비교/전후비교.py` 가 한다(직접 돌릴 때: -s 이 파일 -- --out=<json>).
##
## 왜: 코드를 정리하다가 "파싱 오류가 나는 스크립트"·"없는 파일을 부르는 씬" 이 생기면
##   게임을 켜기 전에는 모른다. 전부 불러 보고 결과를 정리 전 기준과 비교한다.
## ⚠ 스크립트는 파싱 오류가 있어도 load() 가 null 이 아니다 → can_instantiate() 로 "제대로 컴파일됐나" 를 본다.
const 확장자 := ["tscn", "tres", "gd", "gdshader", "gdshaderinc", "res"]
const 뺄_폴더 := [".godot", ".git", "docs", "graphify-out", "node_modules", ".agents", ".claude", "tmp"]

var 결과 := {}


func _init() -> void:
	var 출력 := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			출력 = a.substr(6)
	_훑기("res://")
	var f := FileAccess.open(출력, FileAccess.WRITE)
	f.store_string(JSON.stringify(결과, "", true))
	f.close()
	var 실패 := 0
	for k in 결과:
		if not 결과[k]:
			실패 += 1
	print("전수로드 완료: ", 결과.size(), " 개 · 실패 ", 실패)
	quit()


func _훑기(폴더: String) -> void:
	# .gdignore 폴더는 엔진이 아예 안 본다 → 같이 뺀다
	if FileAccess.file_exists(폴더 + ".gdignore"):
		return
	# 지금 돌고 있는 이 스크립트를 CACHE_MODE_IGNORE 로 다시 불러오면 엔진이 죽는다(10-14 signal 11 겪음)
	# → 이 도구 폴더는 건너뛴다. 게임 코드가 아니라 비교에 필요 없다.
	if 폴더 == "res://tools/전후비교/":
		return
	var d := DirAccess.open(폴더)
	if d == null:
		return
	for 하위 in d.get_directories():
		if 하위 in 뺄_폴더 or 하위.begins_with("백업"):
			continue
		_훑기(폴더 + 하위 + "/")
	for n in d.get_files():
		if n.get_extension().to_lower() in 확장자:
			var p := 폴더 + n
			var r = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
			if r == null:
				결과[p] = false
			elif r is Script or r is PackedScene:
				결과[p] = r.can_instantiate()
			else:
				결과[p] = true
