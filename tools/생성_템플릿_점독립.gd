extends SceneTree
## ============================================================================
## [2026-09-02 신규] 지형 Template 의 **점을 인스턴스마다 독립**시킨다 (멱등)
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_템플릿_점독립.gd -- --확인만
##   godot --headless --path . -s res://tools/생성_템플릿_점독립.gd
##
## ▣ 왜 (성진님 지시 2026-09-02: "템플릿을 독립적하게 만들어")
##   Godot 은 씬에 박힌 **서브리소스를 그 씬의 모든 인스턴스가 공유**한다.
##   SS2D 의 점 배열(`SS2D_Point_Array`)과 점(`SS2D_Point`)이 바로 그 서브리소스라,
##   Template 을 맵에 두 번 꽂으면 **둘이 같은 점을 본다** — 한쪽 점을 끌면 다른 쪽도 끌린다.
##   다른 씬에 있는 것까지 같이 움직인다(리소스 캐시는 프로젝트 전체에서 하나다).
##
## ▣ 무엇을 넣나
##   `resource_local_to_scene = true` 한 줄. 그러면 엔진이 **인스턴스마다 복사본**을 만든다.
##
##   ⚠ 점 배열에만 넣으면 **부족하다.** 실측으로 확인했다 —
##     배열은 갈라지는데 안의 `SS2D_Point` 는 그대로 공유돼서 점이 같이 움직인다.
##     → 배열 **과** 점 전부에 넣어야 완전히 독립된다.
##
## ▣ 대가 (알고 쓸 것)
##   인스턴스마다 복사본이 생기므로, 맵 씬을 저장하면 그 복사본이 **씬 파일에 저장된다.**
##   모양을 안 고칠 인스턴스까지 불어난다. 성진님이 이 대가를 알고 지시한 것이다.
##
## ▣ 안 건드리는 것
##   · `_meshes`(SS2D_Mesh) — 구운 렌더 메시다. `지형.gd::_ready()` 가 어차피 비우고 다시 굽는다
##   · `shape_material`(.tres ExtResource) — 재질은 **공유가 맞다**. 키트가 한 벌이어야 한다
## ============================================================================

const 대상_폴더 := "res://scenes/집/스마트 매쉬 assets"
## 이 스크립트를 쓰는 서브리소스에 줄을 넣는다.
const 점_스크립트들 := [
	"res://addons/rmsmartshape/shapes/point.gd",
	"res://addons/rmsmartshape/shapes/point_array.gd",
]
const 넣을_줄 := "resource_local_to_scene = true"

var 확인만 := false
var 고친_파일 := 0
var 넣은_줄수 := 0
var 이미_된_파일 := 0


func _init() -> void:
	확인만 = OS.get_cmdline_user_args().has("--확인만")
	call_deferred("_실행")


func _실행() -> void:
	var 파일들: Array[String] = []
	_모으기(대상_폴더, 파일들)
	파일들.sort()

	print("\n=== 지형 Template 점 독립시키기%s ===" % (" (확인만)" if 확인만 else ""))
	for f in 파일들:
		_한파일(f)

	print("\n────────────────────────────────────────")
	if 확인만:
		print("  고칠 파일 %d 개 · 넣을 줄 %d 개" % [고친_파일, 넣은_줄수])
		print("  이미 되어 있는 파일 %d 개" % 이미_된_파일)
		print("  (--확인만 이라 아무것도 안 썼다)")
	else:
		print("  고친 파일 %d 개 · 넣은 줄 %d 개" % [고친_파일, 넣은_줄수])
		print("  이미 되어 있던 파일 %d 개" % 이미_된_파일)
	print("────────────────────────────────────────\n")
	quit(0)


## Template 로 쓰이는 씬만 고른다.
## `TEMPLATE_*` 말고도 BRICK 폴더의 4 개가 실제로 키트 부품으로 꽂혀 쓰인다
## (`build_스테이지_1_2층방.gd` · `test_사방재질_칠하기.gd` 가 그것들을 Template 으로 다룬다).
func _템플릿인가(경로: String) -> bool:
	var 이름 := 경로.get_file()
	if 이름.begins_with("TEMPLATE_"):
		return true
	return 이름 in ["벽돌 계단.tscn", "벽돌 계단_흰색.tscn", "벽돌 테스.tscn", "벽돌 테스_흰색.tscn"]


func _모으기(폴더: String, 담을곳: Array[String]) -> void:
	var d := DirAccess.open(폴더)
	if d == null:
		return
	d.list_dir_begin()
	var 이름 := d.get_next()
	while 이름 != "":
		var 경로 := "%s/%s" % [폴더, 이름]
		if d.current_is_dir():
			if not 이름.begins_with(".") and 이름 != "_ARCHIVE":
				_모으기(경로, 담을곳)
		elif 이름.ends_with(".tscn") and _템플릿인가(경로):
			담을곳.append(경로)
		이름 = d.get_next()
	d.list_dir_end()


func _한파일(경로: String) -> void:
	var f := FileAccess.open(경로, FileAccess.READ)
	if f == null:
		push_error("못 읽었다: %s" % 경로)
		return
	var 줄들 := f.get_as_text().split("\n")
	f.close()

	# ① 점/점배열 스크립트의 ExtResource id 를 모은다
	var 점_id: Dictionary = {}
	for 줄 in 줄들:
		if not 줄.begins_with("[ext_resource"):
			continue
		var p := _따옴표_뒤(줄, " path=\"")
		if p in 점_스크립트들:
			점_id[_따옴표_뒤(줄, " id=\"")] = true
	if 점_id.is_empty():
		return                                   # SS2D 점을 안 쓰는 씬

	# ② 블록 단위로 자른 뒤 **블록 전체를 보고** 결정한다.
	#    ⚠ 줄을 흐르면서 판단하면 안 된다 — 넣는 줄이 `script =` **뒤에** 붙기 때문에,
	#      한 줄씩 보면 "이미 있다"를 만나기 전에 `script =` 를 먼저 만나서 또 넣는다.
	#      (실제로 그렇게 짰다가 두 번 돌리니 260 줄이 두 벌 들어갔다. 규칙 5 위반)
	var 블록들 := _블록_자르기(줄들)
	var 결과: Array[String] = []
	var 이_파일_넣음 := 0
	var 이_파일_이미 := 0

	for 블록: Array in 블록들:
		var 머리: String = 블록[0]
		if not 머리.begins_with("[sub_resource"):
			결과.append_array(블록)
			continue

		var script_자리 := -1
		var 이미_있나 := false
		for i in 블록.size():
			var 줄: String = 블록[i]
			if 줄 == 넣을_줄:
				이미_있나 = true
			elif 줄.begins_with("script = ExtResource(") \
					and 점_id.has(_따옴표_뒤(줄, "ExtResource(\"")):
				script_자리 = i

		if script_자리 < 0:                       # 점/점배열이 아닌 서브리소스
			결과.append_array(블록)
			continue
		if 이미_있나:
			이_파일_이미 += 1
			결과.append_array(블록)
			continue

		for i in 블록.size():
			결과.append(블록[i])
			if i == script_자리:
				결과.append(넣을_줄)
		이_파일_넣음 += 1

	if 이_파일_넣음 == 0:
		if 이_파일_이미 > 0:
			이미_된_파일 += 1
			print("  · %s — 이미 되어 있다 (%d 곳)" % [경로.get_file(), 이_파일_이미])
		return

	고친_파일 += 1
	넣은_줄수 += 이_파일_넣음
	print("  ★ %s — %d 곳에 넣는다%s"
			% [경로.get_file(), 이_파일_넣음,
			(" (이미 된 곳 %d)" % 이_파일_이미) if 이_파일_이미 > 0 else ""])
	if 확인만:
		return

	var w := FileAccess.open(경로, FileAccess.WRITE)
	if w == null:
		push_error("못 썼다: %s" % 경로)
		return
	w.store_string("\n".join(결과))
	w.close()


## `[...]` 머리줄마다 잘라 블록 배열로 만든다. 첫 블록은 머리 앞의 잡동사니일 수 있다.
func _블록_자르기(줄들: PackedStringArray) -> Array:
	var 블록들: Array = []
	var 지금: Array[String] = []
	for 줄 in 줄들:
		if 줄.begins_with("[") and 줄.ends_with("]"):
			if not 지금.is_empty():
				블록들.append(지금)
			지금 = [줄]
		else:
			지금.append(줄)
	if not 지금.is_empty():
		블록들.append(지금)
	return 블록들


## `열쇠` 는 여는 따옴표까지 포함해서 넘긴다(예: ` id="`). 그 다음 따옴표까지를 돌려준다.
## ⚠ ` id="` 처럼 앞 공백을 꼭 붙일 것 — `id="` 로 찾으면 `uid="` 안에도 걸린다.
func _따옴표_뒤(줄: String, 열쇠: String) -> String:
	var 자리 := 줄.find(열쇠)
	if 자리 < 0:
		return ""
	var 뒤 := 줄.substr(자리 + 열쇠.length())
	var 끝 := 뒤.find("\"")
	return 뒤.substr(0, 끝) if 끝 >= 0 else 뒤
