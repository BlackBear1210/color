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
## [경로, 사방재질로 고쳤나]
const 대상 := [
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn", true],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_HOLLOW.tscn", true],
	[키트 + "BRICK_벽돌/TEMPLATE_BRICK_STAIRS.tscn", true],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn", true],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_HOLLOW.tscn", true],
	[키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn", true],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn", false],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_HOLLOW.tscn", false],
	[키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS.tscn", false],
]

const 색상 := preload("res://scripts/color_defs.gd")

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
		_검사(String(대상[i][0]), bool(대상[i][1]))
	elif 단계 == 6 and _루트 != null:
		_루트.queue_free()
		_루트 = null


func _검사(경로: String, 사방인가: bool) -> void:
	print("\n── %s%s" % [경로.get_file(), "" if 사방인가 else "   (잔디 · 구형 구성 · 예상 실패)"])
	var 지형 := _루트
	if not 지형.has_method("반대색인가"):
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

	# 실제로 칠해지는지도 본다 — 셰이더만 있고 규칙이 안 돌면 의미가 없다.
	var 필요: int = 지형.필요횟수()
	var 결과 := ""
	for k in maxi(필요, 1) + 1:
		결과 = 지형.명중(색상.WHITE, 지형.global_position)
		if 결과 == "painted":
			break
	if 사방인가:
		_확인(결과 == "painted" and 지형.현재색() == 색상.WHITE,
			"흰색으로 전체 색칠된다 (%d 발 · 결과 '%s')" % [필요, 결과])


func _끝내기() -> void:
	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d · 잔디 경고 %d" % [_통과, _실패, _잔디경고])
	print("════════════════════════════════════════\n")
	quit(1 if _실패 > 0 else 0)
