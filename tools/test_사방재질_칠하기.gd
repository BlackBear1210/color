extends SceneTree
## ============================================================================
## [2026-08-27 신규] 지형의 **모든 조각**에 페인트 셰이더가 붙었나
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/test_사방재질_칠하기.gd
##
## ▣ 왜 만들었나 (도형님 제보)
##   "코너 부분을 보면 지형 플랫폼들이 전부 안 칠해져."
##
##   진짜 원인: `지형.gd _셰이더_설치()` 는 **코너 텍스처를 든 엣지 메타를 건너뛴다.**
##   그 메타의 기본 텍스처가 투명 캐리어(`투명_256.png`)라서 흰색 짝이 없기 때문이다.
##   건너뛴 메타로 생성된 **코너 쿼드에는 페인트 셰이더가 안 붙는다** →
##   총을 맞아 `현재상태` 는 흰색이 돼도 **화면의 코너만 검정 그대로**다.
##   "내 색과 다른 지형에 닿으면 즉사" 가 규칙인 게임에서 이건 거짓말하는 화면이다.
##
##   `test_집_칠하기와빛.gd` 는 `현재상태` 같은 **논리값**만 본다. 그래서 이 버그를 못 잡았다.
##   → 여기서는 **구워진 메시 하나하나**를 열어 셰이더가 붙었는지 센다.
##
## ▣ 합격 기준
##   구운 메시 중 **화면에 실제로 보이는 것**(투명 캐리어 제외)은 전부
##   `ShaderMaterial`(지형_페인트.gdshader) 을 들고 있어야 한다.
##
## ⚠ 잔디(grass_v4)는 `PRODUCTION LOCK` 이고 아직 구형 구성이라 **예상 실패**로 따로 센다.
##   아트 판단(윗면 잔디 유지 vs 사방 단일 엣지)이 필요해 이번에 안 건드렸다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const 색상 := preload("res://scripts/color_defs.gd")

## ★[2026-08-29] 흰색 키트가 생기면서 표에 두 칸이 늘었다.
##   시작색 : 이 씬이 **태어날 때 무슨 색인가** (-1 = 무색). 흰색 키트는 `시작상태 = 흰색` 이다.
##   칠할색 : 무슨 색으로 칠해 보나. **자기 색의 반대**로 칠해야 진짜 검사가 된다
##            (검정 지형을 검정으로 칠하면 'wasted' 라 아무것도 증명하지 못한다).
##   흰색 씬은 흰 아트를 기본으로 들기 때문에, 예전의 "검정이 원본" 가정이 남아 있으면
##   셰이더가 아예 안 붙거나 검정으로 칠해지지 않는다 — 그 회귀를 여기서 잡는다.
##
## [경로, 사방재질로 고쳤나, 시작색, 칠할색]
const 대상 := [
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn", true, -1, 색상.WHITE],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_HOLLOW.tscn", true, -1, 색상.WHITE],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_STAIRS.tscn", true, -1, 색상.WHITE],
	[키트 + "BRICK_벽돌/벽돌 계단.tscn", true, -1, 색상.WHITE],
	[키트 + "BRICK_벽돌/벽돌 계단_흰색.tscn", true, 색상.WHITE, 색상.BLACK],
	[키트 + "BRICK_벽돌/벽돌 테스.tscn", true, -1, 색상.WHITE],
	[키트 + "BRICK_벽돌/벽돌 테스_흰색.tscn", true, 색상.WHITE, 색상.BLACK],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn", true, -1, 색상.WHITE],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID_WHITE.tscn", true, 색상.WHITE, 색상.BLACK],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_HOLLOW.tscn", true, -1, 색상.WHITE],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn", true, -1, 색상.WHITE],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS_WHITE.tscn", true, 색상.WHITE, 색상.BLACK],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn", false, -1, 색상.WHITE],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID_WHITE.tscn", false, 색상.WHITE, 색상.BLACK],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_HOLLOW.tscn", false, -1, 색상.WHITE],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS.tscn", false, -1, 색상.WHITE],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS_WHITE.tscn", false, 색상.WHITE, 색상.BLACK],
]

var _통과 := 0
var _실패 := 0
var _n := 0
var _루트: Node = null
var _잔디경고 := 0


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)


func _확인(조건: bool, 설명: String) -> void:
	if 조건:
		_통과 += 1
		print("  ✔ %s" % 설명)
	else:
		_실패 += 1
		print("  ✖ %s" % 설명)


func _틱() -> void:
	_n += 1
	var 칸 := 8
	var i := int(_n / 칸)
	if i >= 대상.size():
		_끝내기()
		return
	var 단계 := _n % 칸
	if 단계 == 1:
		var 팩 := load(String(대상[i][0])) as PackedScene
		_루트 = 팩.instantiate()
		root.add_child(_루트)          # ★_ready 를 돌려야 셰이더가 설치된다
	elif 단계 == 5:
		_검사(String(대상[i][0]), bool(대상[i][1]), int(대상[i][2]), int(대상[i][3]))
	elif 단계 == 6 and _루트 != null:
		_루트.queue_free()
		_루트 = null


func _검사(경로: String, 사방인가: bool, 시작색: int, 칠할색: int) -> void:
	print("\n── %s%s" % [경로.get_file(), "" if 사방인가 else "   (잔디 · 구형 구성 · 예상 실패)"])
	# ★지형이 루트라는 보장은 없다 — `벽돌 테스.tscn` 은 빈 Node2D 아래에 들어 있다.
	var 지형 := _지형_찾기(_루트)
	if 지형 == null:
		_확인(false, "스마트지형이다")
		return

	var 메시들 = 지형.get("_meshes")
	if 메시들 == null or (메시들 as Array).is_empty():
		_확인(false, "구운 메시가 있다")
		return

	var 전체 := 0
	var 셰이더있음 := 0
	var 캐리어 := 0
	for mm in (메시들 as Array):
		var tex: Texture2D = mm.get("texture") as Texture2D
		# 투명 캐리어(코너 메타의 기본 텍스처)는 화면에 안 나오므로 세지 않는다.
		if tex != null and tex.resource_path.get_file().begins_with("투명_"):
			캐리어 += 1
			continue
		전체 += 1
		var mat = mm.get("material")
		if mat is ShaderMaterial:
			셰이더있음 += 1

	var 설명 := "보이는 메시 %d 개 중 %d 개에 페인트 셰이더 (투명 캐리어 %d 개 제외)" \
		% [전체, 셰이더있음, 캐리어]
	if 사방인가:
		_확인(셰이더있음 == 전체, 설명)
	else:
		# 잔디는 아직 구형이라 실패가 정상 — 실패로 세지 않고 경고만 남긴다.
		if 셰이더있음 != 전체:
			_잔디경고 += 1
			print("  ⚠ %s  ← 잔디는 아직 구형 구성(아트 판단 대기)" % 설명)
		else:
			_통과 += 1
			print("  ✔ %s" % 설명)

	# 태어날 때의 색 — 흰색 키트는 `시작상태 = 흰색` 이라야 화면과 판정이 같은 말을 한다.
	if 시작색 != -1:
		_확인(지형.현재색() == 시작색,
			"태어날 때 %s 이다" % _색이름(시작색))

	# 실제로 칠해지는지도 본다 — 셰이더만 있고 규칙이 안 돌면 의미가 없다.
	var 필요: int = 지형.필요횟수()
	var 결과 := ""
	for k in maxi(필요, 1) + 1:
		결과 = 지형.명중(칠할색, 지형.global_position)
		if 결과 == "painted":
			break
	_확인(결과 == "painted" and 지형.현재색() == 칠할색,
		"%s으로 전체 색칠된다 (%d 발 · 결과 '%s')" % [_색이름(칠할색), 필요, 결과])

	# 회수하면 **무색이 아니라 시작상태로** 돌아와야 한다.
	# (흰 발판을 검정으로 덮고 죽으면 흰색이 사라지던 버그 — 2026-08-29 수정)
	지형.되돌리기()
	_확인(지형.현재색() == 시작색,
		"되돌리면 %s으로 돌아온다" % _색이름(시작색))


## 씬 안에서 칠할 수 있는 지형 노드를 찾는다 (루트이거나 그 아래 어딘가).
func _지형_찾기(n: Node) -> Node:
	if n.has_method("반대색인가"):
		return n
	for 자식 in n.get_children():
		var 찾음 := _지형_찾기(자식)
		if 찾음 != null:
			return 찾음
	return null


func _색이름(색: int) -> String:
	match 색:
		색상.BLACK: return "검정"
		색상.WHITE: return "흰색"
		색상.GRAY: return "회색"
	return "무색"


func _끝내기() -> void:
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d · 잔디 경고 %d" % [_통과, _실패, _잔디경고])
	print("════════════════════════════════════════\n")
	quit(1 if _실패 > 0 else 0)
