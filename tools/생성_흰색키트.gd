extends SceneTree
## ============================================================================
## [2026-08-29 신규] 검정 키트에서 **흰색 키트**를 파생한다 (멱등)
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_흰색키트.gd
##   godot --headless --path . -s res://tools/생성_흰색키트.gd -- --확인만
##   (이미 있는 것은 건너뛴다. 다시 굽고 싶으면 --덮어쓰기)
##
## ★먼저 흰색 PNG 짝이 있어야 한다:
##   godot --headless --path . -s res://tools/생성_흰색짝.gd
##   godot --headless --path . --import
##
## ▣ 무엇을 만드나
##   1) 흰색 재질(.tres) — 검정 재질의 텍스처 경로만 white 로 바꾼 것
##   2) 흰색 씬(.tscn)   — **모양은 그대로**, 재질만 흰색 + `시작상태 = 흰색`
##
## ▣ 왜 "검정 재질 + 시작상태만 흰색" 으로 안 하나
##   그러면 **에디터에서 검게 보인다.** 페인트 셰이더는 런타임 전용이라
##   (`지형.gd _ready()` 가 `Engine.is_editor_hint()` 로 막는다) 작업자는
##   흰 지형을 놓고도 검은 덩어리를 보며 맵을 찍게 된다. 키트의 존재 이유가 사라진다.
##   → 흰색 씬은 **흰 아트를 기본으로** 든다. 에디터·런타임 둘 다 흰색으로 보인다.
##
## ▣ 칠하기는 그대로 살아 있다 (흑백 공존)
##   `지형.gd _짝_찾기()` 가 **양방향**이라, 흰 아트를 든 지형은 검정 짝을 찾아
##   셰이더에 물린다(`base_is_white = true`). 흰 발판을 검정으로 칠할 수 있다.
##
## ▣ 왜 텍스트를 직접 고치나 (load → duplicate → save 가 아니라)
##   `Resource.duplicate(true)` 는 하위 리소스를 어디까지 복제할지가 애매해
##   텍스처가 .tres 안에 통째로 박히는 사고가 난다. 씬 쪽은 더 심하다 —
##   `지형.gd` 는 `@tool` 이라 트리에 넣는 순간 `_ready()` 가 재질을 깊은 복사해
##   **페인트 셰이더가 박힌 재질이 저장된다**(작업기록 2026-08-25 §2 의 함정).
##   원본 파일은 구조가 단순한 텍스트고, 우리가 바꿀 것은 **경로뿐**이다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"

## [검정 씬, 흰색 씬]
const 할일 := [
	[키트 + "BRICK_벽돌/벽돌 계단.tscn", 키트 + "BRICK_벽돌/벽돌 계단_흰색.tscn"],
	[키트 + "BRICK_벽돌/벽돌 테스.tscn", 키트 + "BRICK_벽돌/벽돌 테스_흰색.tscn"],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn", 키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID_WHITE.tscn"],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS.tscn", 키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS_WHITE.tscn"],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn", 키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID_WHITE.tscn"],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn", 키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS_WHITE.tscn"],
]

## `지형.gd` 의 enum 상태 { 무색, 검정, 흰색, 회색 } 에서 흰색의 값.
const 상태_흰색 := 2
const 지형_스크립트 := "res://scripts/스마트월드/지형.gd"

## ★속성 이름을 **따옴표로 감싸는 이유** (실제로 한 번 터진 것)
##   .tscn 의 속성 이름을 따옴표 없이 쓰면 Godot 의 텍스트 파서가 그 이름을
##   **바이트 단위(Latin-1)로** 읽는다. 한글 이름은 UTF-8 이 한 번 더 씌워져
##   (`시작상태` 12 바이트) **다른 이름이 되고, 조용히 무시된다.**
##   씬에는 값이 적혀 있는데 노드는 기본값인 상태가 된다 — 가장 나쁜 종류의 버그다.
##   Godot 자신도 한글 속성은 따옴표로 저장한다 (집_2층방.tscn 의 `"칠하기_허용" = false`).
const 시작상태_줄 := '"시작상태" = %d'

var _확인만 := false
var _덮어쓰기 := false
var _만듦 := 0
var _건너뜀 := 0
var _실패 := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--확인만":
			_확인만 = true
		elif a == "--덮어쓰기":
			_덮어쓰기 = true
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 흰색 키트 생성%s ===" % ("  (확인만)" if _확인만 else ""))
	for 줄 in 할일:
		_씬_하나(String(줄[0]), String(줄[1]))
	print("--- 만듦 %d · 이미 있음 %d · 실패 %d ---\n" % [_만듦, _건너뜀, _실패])
	quit(1 if _실패 > 0 else 0)


func _씬_하나(검정씬: String, 흰색씬: String) -> void:
	if FileAccess.file_exists(흰색씬) and not _덮어쓰기:
		_건너뜀 += 1
		return
	var 원문 := FileAccess.get_file_as_string(검정씬)
	if 원문.is_empty():
		push_error("씬을 못 읽음: %s" % 검정씬)
		_실패 += 1
		return
	print("● %s" % 흰색씬.get_file())
	var 줄들 := 원문.split("\n")
	# ★시작상태는 **지형.gd 를 든 노드**에 넣는다. 루트가 아닐 수 있다 —
	#   `벽돌 테스.tscn` 은 빈 Node2D 아래에 지형이 자식으로 들어 있다.
	var 지형_id := _지형_스크립트_id(줄들)
	var 결과: PackedStringArray = PackedStringArray()
	var 루트_봤나 := false
	var 루트_블록 := false
	for 줄 in 줄들:
		var 새줄 := 줄
		if 줄.begins_with("[gd_scene"):
			새줄 = _uid_갈기(줄, _새_uid())
		elif 줄.begins_with("[ext_resource"):
			새줄 = _ext_흰색으로(줄)
		elif 줄.begins_with("[node "):
			# 루트 = parent= 가 없는 첫 노드. 여기에만 이름·시작상태를 손댄다.
			루트_블록 = not 루트_봤나 and not 줄.contains("parent=")
			if 루트_블록:
				루트_봤나 = true
				새줄 = _루트_이름_갈기(줄, 흰색씬)
		결과.push_back(새줄)
		# 지형 노드의 script 줄 바로 뒤에 시작상태를 끼운다.
		# 여는 따옴표까지 붙여 비교한다 — id 가 접두어로 겹치는 일이 없도록.
		if not 지형_id.is_empty() and 줄.begins_with('script = ExtResource("%s")' % 지형_id):
			결과.push_back(시작상태_줄 % 상태_흰색)
	if _확인만:
		_만듦 += 1
		return
	if _쓰기(흰색씬, "\n".join(결과)):
		_만듦 += 1
	else:
		_실패 += 1


## ext_resource 한 줄을 흰색 짝으로 바꾼다.
## 텍스처면 white 파일로, 재질(.tres)이면 흰색 재질로 (없으면 **여기서 만든다**).
func _ext_흰색으로(줄: String) -> String:
	var 경로 := _속성(줄, "path")
	if 경로.is_empty():
		return 줄
	if 경로.ends_with(".tres"):
		var 흰재질 := _흰색_경로(경로)
		if 흰재질.is_empty():
			return 줄                                  # 흑백 이름이 아닌 재질 — 그대로 둔다
		var uid := _재질_보장(경로, 흰재질)
		return _uid_갈기(_속성_갈기(줄, "path", 흰재질), uid)
	if not 경로.ends_with(".png"):
		return 줄
	var 흰텍 := _흰색_경로(경로)
	if 흰텍.is_empty() or not FileAccess.file_exists(흰텍):
		return 줄                                      # 짝이 없으면 셰이더가 반전으로 때운다
	return _uid_갈기(_속성_갈기(줄, "path", 흰텍), _uid_문자열(흰텍))


## 흰색 재질이 없으면 검정 재질에서 만든다. 반환값은 그 재질의 uid 문자열.
func _재질_보장(검정: String, 흰색: String) -> String:
	if FileAccess.file_exists(흰색) and not _덮어쓰기:
		return _uid_문자열(흰색)
	var 원문 := FileAccess.get_file_as_string(검정)
	if 원문.is_empty():
		push_error("재질을 못 읽음: %s" % 검정)
		_실패 += 1
		return ""
	var uid := _새_uid()
	var 결과: PackedStringArray = PackedStringArray()
	for 줄 in 원문.split("\n"):
		if 줄.begins_with("[gd_resource"):
			결과.push_back(_uid_갈기(줄, uid))
		elif 줄.begins_with("[ext_resource"):
			결과.push_back(_ext_흰색으로(줄))
		else:
			결과.push_back(줄)
	print("   + 재질 %s" % 흰색.get_file())
	if _확인만:
		return uid
	if not _쓰기(흰색, "\n".join(결과)):
		_실패 += 1
	return uid


# ── 경로·문자열 도구 ────────────────────────────────────────────────────────
## black → white 경로. `지형.gd _짝_찾기()` 와 **같은 두 규칙**을 쓴다.
##   1) 파일명 토막   2) 마지막 폴더 이름
## 어느 규칙에도 안 걸리면 빈 문자열(= 흑백 개념이 없는 파일).
func _흰색_경로(경로: String) -> String:
	var 파일 := 경로.get_file()
	var 조각 := 파일.get_basename().split("_")
	for i in 조각.size():
		if 조각[i] != "black":
			continue
		var 반대 := 조각.duplicate()
		반대[i] = "white"
		return "%s/%s.%s" % [경로.get_base_dir(), "_".join(반대), 파일.get_extension()]
	var 폴더 := 경로.get_base_dir()
	if 폴더.get_file() == "black":
		return "%s/white/%s" % [폴더.get_base_dir(), 파일]
	return ""


## ⚠ 반드시 **앞의 공백까지** 붙여서 찾는다.
##   `id="` 로 찾으면 `uid="uid://..."` 안의 `id="` 가 먼저 걸린다.
##   실제로 그 때문에 지형 스크립트의 id 로 uid 문자열을 집어서
##   `시작상태` 가 한 줄도 안 들어간 적이 있다(2026-08-29).
func _속성(줄: String, 이름: String) -> String:
	var 표 := ' %s="' % 이름
	var i := 줄.find(표)
	if i < 0:
		return ""
	var 시작 := i + 표.length()
	var 끝 := 줄.find('"', 시작)
	return 줄.substr(시작, 끝 - 시작) if 끝 > 시작 else ""


func _속성_갈기(줄: String, 이름: String, 값: String) -> String:
	var 옛 := ' %s="%s"' % [이름, _속성(줄, 이름)]
	return 줄.replace(옛, ' %s="%s"' % [이름, 값])


## uid 속성을 새 값으로 바꾼다. 새 값이 없으면 uid 속성을 아예 지운다
## (경로만으로도 로드되고, 남은 uid 가 엉뚱한 리소스를 가리키는 것보다 안전하다).
func _uid_갈기(줄: String, uid: String) -> String:
	var 옛 := _속성(줄, "uid")
	if 옛.is_empty():
		return 줄
	if uid.is_empty():
		return 줄.replace(' uid="%s"' % 옛, "")
	return 줄.replace(' uid="%s"' % 옛, ' uid="%s"' % uid)


func _uid_문자열(경로: String) -> String:
	var id := ResourceLoader.get_resource_uid(경로)
	return "" if id == ResourceUID.INVALID_ID else ResourceUID.id_to_text(id)


func _새_uid() -> String:
	return ResourceUID.id_to_text(ResourceUID.create_id())


## `지형.gd` 를 가리키는 ext_resource 의 id. 없으면 빈 문자열(= 칠할 수 없는 씬).
func _지형_스크립트_id(줄들: PackedStringArray) -> String:
	for 줄 in 줄들:
		if 줄.begins_with("[ext_resource") and _속성(줄, "path") == 지형_스크립트:
			return _속성(줄, "id")
	push_error("지형.gd 를 안 쓰는 씬이다 — 칠할 수 없다")
	_실패 += 1
	return ""


## 루트 노드 이름에 흰색 표시를 붙인다 (파일 이름과 같은 이름으로).
func _루트_이름_갈기(줄: String, 흰색씬: String) -> String:
	return _속성_갈기(줄, "name", 흰색씬.get_file().get_basename())


func _쓰기(경로: String, 내용: String) -> bool:
	var f := FileAccess.open(경로, FileAccess.WRITE)
	if f == null:
		push_error("저장 실패: %s" % 경로)
		return false
	f.store_string(내용)
	f.close()
	return true
