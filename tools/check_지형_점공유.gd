extends SceneTree
## ============================================================================
## [2026-09-02 신규] SS2D 지형 Template 인스턴스가 **점 배열을 나눠 쓰고 있나**
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/check_지형_점공유.gd
##
## ▣ 무엇을 찾나 (성진님 제보 2026-09-02)
##   "TEMPLATE_CEMENT_SOLID 를 stage_2-1 에 한 번 더 인스턴스했는데
##    이미 있던 것과 **똑같은 모양**으로 들어온다. 따로 못 고치나?"
##
##   Godot 은 씬 안의 서브리소스를 **그 씬의 모든 인스턴스가 공유**한다
##   (`resource_local_to_scene` 이 꺼져 있을 때). SS2D 의 점 배열(`_points`)이
##   바로 그 서브리소스라, Template 을 여러 번 꽂으면 **전부 같은 점 배열**을 본다.
##   → 한 곳에서 점을 끌면 **나머지가 전부 같이 움직인다.** 다른 씬에 있는 것까지.
##   (실측으로 확인: 두 인스턴스의 점 배열 instance_id 가 같고, 점 하나를 옮기면
##    둘 다 움직였다. `clone(true)` = SS2D 의 Make Unique 를 하면 독립이 되었다)
##
## ▣ ★[2026-09-02 저녁] 지금은 Template 쪽에서 막아 두었다
##   `tools/생성_템플릿_점독립.gd` 가 키트 Template 26 개의 점 배열과 점 전부에
##   `resource_local_to_scene = true` 를 넣었다 → 인스턴스마다 엔진이 복사본을 만든다.
##   그래서 **그 Template 을 쓰는 인스턴스는 `_points` 덮어쓰기가 없어도 안전하다.**
##   이 검사는 그것을 알고 있어서, 표시가 빠진 Template 만 골라낸다
##   (= 나중에 새로 만든 Template 이 표시를 빠뜨렸을 때 잡으라고 남겨 둔 것이다).
##
## ▣ 표시가 없는 Template 을 만났을 때 고치는 법
##   ① `godot --headless --path . -s res://tools/생성_템플릿_점독립.gd` 를 돌린다 (근본)
##   ② 급하면 그 지형 노드를 고르고 인스펙터 **Geometry → Make Unique → Execute**
##
## ▣ 이 검사가 "실패"를 안 내는 이유
##   공유 자체는 **버그가 아니라 Godot 기본 동작**이다. 여기서는 어디가 묶여 있는지
##   알려만 준다.
## ============================================================================

const 씬_폴더 := "res://scenes"

var 묶음: Dictionary = {}       ## 템플릿 경로 → [ "씬 > 노드", ... ]
var 독립: int = 0


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 파일들: Array[String] = []
	_씬_모으기(씬_폴더, 파일들)
	파일들.sort()
	for f in 파일들:
		_씬_읽기(f)

	print("\n=== SS2D 지형 점 배열 공유 검사 ===")
	print("(같은 Template 을 꽂았는데 `_points` 덮어쓰기가 없는 인스턴스끼리는 점을 나눠 쓴다)")

	var 묶인_템플릿 := 0
	var 묶인_인스턴스 := 0
	var 홀로: Array[String] = []
	for 템플릿 in 묶음:
		var 목록: Array = 묶음[템플릿]
		if 목록.size() < 2:
			# 지금은 하나뿐이라 티가 안 나지만, **같은 Template 을 또 꽂는 순간 묶인다.**
			홀로.append("%s  (%s)" % [목록[0], 템플릿.get_file()])
			continue
		묶인_템플릿 += 1
		묶인_인스턴스 += 목록.size()
		print("\n▣ [이미 묶임] %s — %d 곳이 같은 점 배열을 본다" % [템플릿.get_file(), 목록.size()])
		print("    한 곳에서 점을 끌면 나머지가 전부 같이 움직인다 (다른 씬에 있는 것까지)")
		for 곳 in 목록:
			print("    · %s" % 곳)

	if not 홀로.is_empty():
		print("\n▣ [묶일 예정] 아직 혼자라 티가 안 나는 것 — %d 개" % 홀로.size())
		print("    같은 Template 을 **한 번 더 꽂는 순간** 새 것이 이 모양 그대로 들어오고 묶인다.")
		for 곳 in 홀로:
			print("    · %s" % 곳)

	print("\n────────────────────────────────────────")
	print("  이미 묶여 있는 Template : %d 종 · 인스턴스 %d 개" % [묶인_템플릿, 묶인_인스턴스])
	print("  묶일 예정(혼자·덮어쓰기 없음) : %d 개" % 홀로.size())
	print("  자기 점 배열을 가진 인스턴스 : %d 개 (`_points` 덮어쓰기 있음)" % 독립)
	print("────────────────────────────────────────")
	print("  따로 모양을 고치고 싶은 것은 → 그 노드 선택 → 인스펙터 Geometry → Make Unique")
	print("────────────────────────────────────────\n")
	quit(0)


func _씬_모으기(폴더: String, 담을곳: Array[String]) -> void:
	var d := DirAccess.open(폴더)
	if d == null:
		return
	d.list_dir_begin()
	var 이름 := d.get_next()
	while 이름 != "":
		var 경로 := "%s/%s" % [폴더, 이름]
		if d.current_is_dir():
			if not 이름.begins_with("."):
				_씬_모으기(경로, 담을곳)
		elif 이름.ends_with(".tscn"):
			담을곳.append(경로)
		이름 = d.get_next()
	d.list_dir_end()


## .tscn 을 **글로** 읽는다. 씬을 열지 않으므로 빠르고, 열다가 나는 부작용도 없다.
func _씬_읽기(경로: String) -> void:
	var f := FileAccess.open(경로, FileAccess.READ)
	if f == null:
		return
	var 줄들 := f.get_as_text().split("\n")
	f.close()

	var 자원: Dictionary = {}      ## ExtResource id → 경로
	var 지금_템플릿 := ""
	var 지금_이름 := ""
	var 점_있나 := false

	for 줄 in 줄들:
		if 줄.begins_with("[ext_resource"):
			# ⚠ 열쇠에 앞 공백을 붙인다. `id="` 로 찾으면 **`uid="` 안에도 걸린다.**
			var id := _따옴표_뒤(줄, " id=\"")
			var p := _따옴표_뒤(줄, " path=\"")
			if id != "" and p != "":
				자원[id] = p
			continue
		if 줄.begins_with("[node "):
			_마무리(지금_템플릿, 경로, 지금_이름, 점_있나)
			지금_템플릿 = ""
			지금_이름 = _따옴표_뒤(줄, "name=\"")
			점_있나 = false
			var inst := 줄.get_slice("instance=ExtResource(\"", 1)
			if inst != 줄:
				var iid := inst.get_slice("\"", 0)
				var 경로2: String = 자원.get(iid, "")
				if 경로2.get_file().begins_with("TEMPLATE_"):
					지금_템플릿 = 경로2
			continue
		if 줄.begins_with("_points = "):
			점_있나 = true
	_마무리(지금_템플릿, 경로, 지금_이름, 점_있나)


func _마무리(템플릿: String, 씬: String, 노드: String, 점_있나: bool) -> void:
	if 템플릿 == "":
		return
	if 점_있나:
		독립 += 1
		return
	if _템플릿이_스스로_독립인가(템플릿):
		# Template 이 `resource_local_to_scene` 을 달고 있다 → 엔진이 인스턴스마다 복사한다.
		# `_points` 덮어쓰기가 없어도 안전하다.
		독립 += 1
		return
	if not 묶음.has(템플릿):
		묶음[템플릿] = []
	묶음[템플릿].append("%s > %s" % [씬.get_file(), 노드])


var _독립_캐시: Dictionary = {}

## Template 파일의 **점 배열 서브리소스**에 `resource_local_to_scene` 이 붙어 있나.
## ⚠ 점 배열에만 붙어 있으면 부족하다(안의 점이 공유된다). 그래서 점 스크립트를 쓰는
##   서브리소스가 **전부** 표시를 달고 있는지 본다.
func _템플릿이_스스로_독립인가(경로: String) -> bool:
	if _독립_캐시.has(경로):
		return _독립_캐시[경로]
	var 답 := false
	var f := FileAccess.open(경로, FileAccess.READ)
	if f != null:
		var 줄들 := f.get_as_text().split("\n")
		f.close()
		var 점_id: Dictionary = {}
		for 줄 in 줄들:
			if 줄.begins_with("[ext_resource"):
				var p := _따옴표_뒤(줄, " path=\"")
				if p.ends_with("/point.gd") or p.ends_with("/point_array.gd"):
					점_id[_따옴표_뒤(줄, " id=\"")] = true
		var 점_블록 := 0
		var 표시된 := 0
		var 이_블록_점 := false
		var 이_블록_표시 := false
		for 줄 in 줄들:
			if 줄.begins_with("[") and 줄.ends_with("]"):
				if 이_블록_점:
					점_블록 += 1
					표시된 += 1 if 이_블록_표시 else 0
				이_블록_점 = 줄.begins_with("[sub_resource")
				이_블록_표시 = false
				if not 이_블록_점:
					continue
				이_블록_점 = false               # script 줄을 봐야 점인지 안다
				continue
			if 줄.begins_with("script = ExtResource(") \
					and 점_id.has(_따옴표_뒤(줄, "ExtResource(\"")):
				이_블록_점 = true
			elif 줄 == "resource_local_to_scene = true":
				이_블록_표시 = true
		if 이_블록_점:
			점_블록 += 1
			표시된 += 1 if 이_블록_표시 else 0
		답 = 점_블록 > 0 and 표시된 == 점_블록
	_독립_캐시[경로] = 답
	return 답


## `열쇠` 는 여는 따옴표까지 포함해서 넘긴다(예: ` id="`). 그 다음 따옴표까지를 돌려준다.
func _따옴표_뒤(줄: String, 열쇠: String) -> String:
	var 자리 := 줄.find(열쇠)
	if 자리 < 0:
		return ""
	var 뒤 := 줄.substr(자리 + 열쇠.length())
	var 끝 := 뒤.find("\"")
	return 뒤.substr(0, 끝) if 끝 >= 0 else 뒤
