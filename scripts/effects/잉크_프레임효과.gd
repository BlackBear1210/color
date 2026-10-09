extends Sprite2D
## ============================================================================
## [2026-10-08 Claude 신규] 잉크 프레임 효과 — 점프(약·강) · 점프대 파문 · 솟구침 속도 줄
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-D · 카드 2
##   약한 점프(0.18초) · 강한 점프(0.28초 — 버튼을 0.12초 넘게 누르면 약에서 **자라난다**) · 점프대(0.35초 + 속도 줄 0.3초)
##
## ▣ 그림
##   아스트라 원화(붓결_v05 · 점프대_튕김 · 세로잔상)를 `tools/생성_신규기믹_게임용.py` 가 가로 띠로 다시 붙인 것.
##   띠의 모든 칸은 **같은 기준점(발 자리)** 에 맞춰 놓였다 → 여기서는 region 만 바꿔 재생한다(떨림 없음).
##   칸 크기·기준점은 자동 생성 상수 `잉크_시트정보.gd` 에서 읽는다(도구를 다시 돌려도 어긋나지 않게).
##
## ▣ 색
##   PNG 는 모양(알파)과 붓결만 담고, 색은 `shaders/ink_effect.gdshader` 가 입힌다.
##   흰 몸 = 흰 물감(184 상한 · 순백 금지) / 검정 몸 = 잉크 + 가장자리 밝은 테(어두운 화면에서 읽히게).
##
## ▣ 왜 top_level 인가
##   Player 루트는 scale 이 비균등(0.795, 0.368)이다. 자식으로 두면 이펙트가 납작하게 찌그러진다.
##   그래서 늘 top_level 로 띄우고, 따라다녀야 하는 것(솟구침)은 `따라갈` 노드의 위치만 매 프레임 옮긴다.
## ============================================================================

const 시트정보 := preload("res://scripts/effects/잉크_시트정보.gd")
const 셰이더 := preload("res://shaders/ink_effect.gdshader")

## 색 모드별 재질은 하나씩만 만들어 모든 이펙트가 같이 쓴다(이펙트마다 새 재질 = 배치가 깨진다).
static var _재질들 := {}

var _종류 := ""
var _정보: Dictionary = {}
var _길이 := 0.2
var _t := 0.0
var _배율 := 1.0
var _따라갈: Node2D = null
var _따라_오프셋 := Vector2.ZERO
var _시작알파 := 1.0
var _지난프레임 := -1


## 만들어서 `부모` 아래에 붙인다. `위치` = 기준점(발 자리)이 놓일 월드 좌표.
## `색` = ColorDefs.BLACK / WHITE. `배율` = 게임 크기 기준 추가 배율(1 = 도구가 맞춘 크기).
static func 만들기(부모: Node, 종류: String, 위치: Vector2, 색: int, 길이: float, 배율: float = 1.0) -> Sprite2D:
	var e: Sprite2D = load("res://scripts/effects/잉크_프레임효과.gd").new()
	부모.add_child(e)
	e._설정(종류, 위치, 색, 길이, 배율)
	return e


func _설정(종류: String, 위치: Vector2, 색: int, 길이: float, 배율: float) -> void:
	top_level = true
	z_as_relative = false
	z_index = 30
	centered = false
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = _재질(색)
	_배율 = 배율
	_길이 = maxf(길이, 0.01)
	_시트_바꾸기(종류)
	global_position = 위치
	_프레임_맞추기()


func _시트_바꾸기(종류: String) -> void:
	_종류 = 종류
	_정보 = 시트정보.시트.get(종류, {})
	if _정보.is_empty():
		push_warning("[잉크_프레임효과] 모르는 종류: %s" % 종류)
		queue_free()
		return
	texture = load(_정보["경로"]) as Texture2D
	# 시트는 게임 크기의 2배 → 0.5 배로 그린다. offset = −기준점 → 노드 원점이 곧 발 자리.
	scale = Vector2.ONE * 0.5 * _배율
	offset = -(_정보["기준"] as Vector2)
	_지난프레임 = -1


static func _재질(색: int) -> ShaderMaterial:
	var 모드 := 1 if 색 == ColorDefs.BLACK else 0
	if not _재질들.has(모드):
		var m := ShaderMaterial.new()
		m.shader = 셰이더
		m.set_shader_parameter("mode", 모드)
		_재질들[모드] = m
	return _재질들[모드]


## 약 → 강으로 자라난다(player.gd 가 점프 버튼을 0.12초 넘게 누르고 있으면 부른다).
##   지금까지 흐른 시간은 버리지 않고 강 시트의 "최대(2번째) 칸" 부터 이어 간다 — 줄기가 길어지며 커지는 것처럼 보인다.
func 강화(새_종류: String, 새_길이: float) -> void:
	if _종류 == 새_종류 or is_queued_for_deletion():
		return
	var 진행 := _t / _길이
	_길이 = 새_길이
	_t = maxf(진행, 1.0 / 4.0) * _길이
	_시트_바꾸기(새_종류)
	_프레임_맞추기()


## 솟구침처럼 몸을 따라가야 하는 효과. 노드의 위치만 따라간다(회전·비균등 scale 은 안 받는다).
func 따라가기(대상: Node2D, 오프셋: Vector2) -> void:
	_따라갈 = 대상
	_따라_오프셋 = 오프셋


func _process(delta: float) -> void:
	_t += delta
	if _t >= _길이:
		queue_free()
		return
	if _따라갈 and is_instance_valid(_따라갈):
		global_position = _따라갈.global_position + _따라_오프셋
	_프레임_맞추기()


func _프레임_맞추기() -> void:
	if _정보.is_empty():
		return
	var n: int = _정보["프레임"]
	var f := mini(int(_t / _길이 * n), n - 1)
	# 마지막 30% 동안 옅어진다 — 프레임 그림 자체가 마르는 순서라 알파만 살짝 거든다
	var 남음 := 1.0 - _t / _길이
	modulate.a = clampf(남음 / 0.3, 0.0, 1.0)
	if f == _지난프레임:
		return
	_지난프레임 = f
	var 칸: Vector2 = _정보["칸"]
	region_rect = Rect2(칸.x * f, 0.0, 칸.x, 칸.y)
