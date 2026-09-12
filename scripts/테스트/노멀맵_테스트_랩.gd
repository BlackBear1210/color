extends Node2D
## ============================================================================
## [2026-09-05 신규] 조명 / 노멀맵 공식 검증 랩 컨트롤러
##   씬: scenes/집/테스트_2층방_노멀맵.tscn  (빌더: tools/build_노멀맵_테스트씬.gd)
## ----------------------------------------------------------------------------
## ▣ 이 씬은 게임이 아니다
##   플레이해서 진행하는 스테이지가 아니라, Lighting / Normal Map / Player Fill /
##   Shadow 를 **눈으로 확인하는 고정 카메라 Lab** 이다.
##   앞으로 조명·노멀맵 작업은 여기서 먼저 확인하고 실제 스테이지에 적용한다.
##
## ▣ ★카메라를 코드가 맞추는 이유
##   예전 테스트 씬이 안 보였던 진짜 원인이 "노드는 있는데 카메라 밖"이었다.
##   (실측: 지형 24 개 중 20 개가 화면 밖)
##   → 실행할 때마다 `테스트_*` 지형의 **실제 경계**를 재서 카메라를 맞춘다.
##     배치를 아무리 고쳐도 화면 밖으로 나갈 수가 없다.
##
## ▣ 조작 (F6 로 이 씬만 실행)
##   ← / →   환경광 LEFT / CENTER / RIGHT
##   N       노멀맵 ON / OFF
##   E       환경광 ON / OFF
##   F       플레이어 보조광 ON / OFF
##   S       그림자 ON / OFF
##   Shift   BLACK ↔ WHITE (Player 가 스스로 처리 — 게임과 같은 키)
##   ⚠ 게임플레이 Input Map 은 한 글자도 안 건드린다. 여기서만 도는 키다.
##
## ▣ 촬영 도구 창구
##   `빛_자리(이름)` · `노멀_켜기(bool)` · `환경광_켜기(bool)`
##   · `보조광_켜기(bool)` · `그림자_켜기(bool)`
## ============================================================================

## ⚠ class_name 이 아니라 **경로 preload** — 헤드리스에서 전역 클래스 등록보다 먼저 돈다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")
const 페인트HUD_씬 := preload("res://scenes/ui/페인트_HUD.tscn")
const 페인트HUD어댑터_코어 := preload("res://scripts/ui/페인트_HUD_어댑터_코어.gd")

## 환경광의 세 자리. BRICK 벽을 기준으로 왼쪽 위 / 바로 위 / 오른쪽 위.
## ★노멀맵이 진짜 붙었는지는 "빛을 옮겼을 때 **벽돌마다** 하이라이트가 반대편으로
##   옮겨가는가" 로만 알 수 있다. 전체 밝기만 변하면 노멀맵이 안 붙은 것이다.
const 빛자리 := {
	# BRICK 벽(-60, -180 · 512×192) 을 기준으로 좌/우가 **같은 거리(670px)** 다.
	# ★좌우 거리가 같아야 "빛을 옮겼을 때 하이라이트가 반대편으로
	#   옮겨갔다"를 밝기 차이와 헷갈리지 않고 판단할 수 있다.
	"LEFT":   Vector2(-700, -380),
	"CENTER": Vector2(-60, -560),
	"RIGHT":  Vector2(580, -380),
}

@export var 광원_자리: String = "LEFT"
@export var 노멀맵_켬: bool = true
@export var 환경광_켬: bool = true
@export var 보조광_켬: bool = true
@export var 그림자_켬: bool = false
## HUD(초상 + 게이지)를 띄울지. 좌상단 구석만 쓰므로 테스트를 안 가린다.
## ⚠ 끄더라도 **프로젝트에서 HUD 를 지우는 것이 아니다.** 이 씬에서만 감춘다.
@export var HUD_보이기: bool = true
## 환경광 반경(px). 기본은 조명 표준(700) 그대로.
## ⚠ 랩의 판이 한 광원 pool 보다 넓어서, 700 에서는 GRASS·IRON 이 pool 가장자리에 앉는다.
##   "네 재질을 한 화면에서 나란히 비교"할 때만 1100 쯤으로 올려서 본다.
##   energy · height · blend · CanvasModulate 는 **절대** 안 올린다 —
##   그쪽을 올리면 테스트 씬만 밝게 만들어 노멀맵이 좋아 보이게 하는 것이 된다(§10 금지).
@export var 광원_반경: float = 조명표준.기준_반경
## 카메라 여백(내용물 대비 비율).
@export var 카메라_여백: float = 1.12

var _환경광: PointLight2D = null
var _캠: Camera2D = null
var _라벨: Label = null
var _보조: Node = null
## CanvasTexture 의 normal_texture 를 잠깐 빼 두는 자리 (대조군 · 리소스 파일은 안 고친다)
var _노멀_보관: Dictionary = {}


func _ready() -> void:
	# ⚠ Player.tscn 안의 Camera2D 가 current 를 가로채면 Lab 카메라가 무시된다.
	#   씬에 구운 enabled=false 가 인스턴스 오버라이드로 안 남는 경우가 있어 런타임에서 끈다.
	for n in _모두(self):
		if n is Camera2D and n.get_parent() != null \
				and String(n.get_parent().name).begins_with("테스트_Player"):
			(n as Camera2D).enabled = false

	_환경광 = get_node_or_null("환경광") as PointLight2D
	_캠 = get_node_or_null("Camera2D") as Camera2D
	if _환경광:
		_환경광.texture = 조명표준.방사형_텍스처()
		조명표준.적용(_환경광, 조명표준.기준_세기)
		조명표준.반경(_환경광, 광원_반경)
		_환경광.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		_환경광.shadow_filter_smooth = 8.0
		_환경광.shadow_color = Color(0, 0, 0, 조명표준.그림자_알파)

	var 플레이어 := get_node_or_null("테스트_Player")
	if 플레이어:
		_보조 = 플레이어.get_node_or_null("플레이어_보조광")

	_HUD_만들기(플레이어)
	_디버그_라벨_만들기()

	# 지형(SS2D)이 메시를 굽고 `지형.gd` 가 노멀맵을 물릴 때까지 몇 프레임 걸린다.
	await get_tree().process_frame
	await get_tree().process_frame
	_노멀_모으기()

	빛_자리(광원_자리)
	노멀_켜기(노멀맵_켬)
	환경광_켜기(환경광_켬)
	보조광_켜기(보조광_켬)
	그림자_켜기(그림자_켬)
	카메라_맞추기()


# ── 창구 ────────────────────────────────────────────────────────────────────

func 빛_자리(이름: String) -> void:
	if not 빛자리.has(이름):
		return
	광원_자리 = 이름
	if _환경광:
		_환경광.position = 빛자리[이름]
	_라벨_갱신()


## ★씬을 바꾸지 않고 CanvasTexture 의 normal_texture 만 비운다.
##   그래야 나머지 조건이 100 % 같은 진짜 대조군이 된다.
func 노멀_켜기(켬: bool) -> void:
	노멀맵_켬 = 켬
	for ct: CanvasTexture in _노멀_보관.keys():
		ct.normal_texture = (_노멀_보관[ct] if 켬 else null)
	_라벨_갱신()


func 환경광_켜기(켬: bool) -> void:
	환경광_켬 = 켬
	if _환경광:
		_환경광.visible = 켬
	_라벨_갱신()


func 보조광_켜기(켬: bool) -> void:
	보조광_켬 = 켬
	if _보조:
		_보조.set("켜기", 켬)
	_라벨_갱신()


## 환경광 반경을 런타임에 바꾼다(네 재질을 한 화면에서 비교할 때만).
func 반경_세우기(px: float) -> void:
	광원_반경 = px
	if _환경광:
		조명표준.반경(_환경광, px)


## 그림자는 **환경광만** 만든다. 보조광에는 절대 켜지 않는다(STEP 5 결정).
func 그림자_켜기(켬: bool) -> void:
	그림자_켬 = 켬
	if _환경광:
		_환경광.shadow_enabled = 켬
	_라벨_갱신()


## 테스트 대상 전체가 항상 화면 안에 들어오도록 카메라를 맞춘다.
func 카메라_맞추기() -> void:
	if _캠 == null:
		return
	var 상자 := _내용물_상자()
	if 상자.size.x <= 1.0 or 상자.size.y <= 1.0:
		return
	var 화면 := get_viewport().get_visible_rect().size
	var 필요 := 상자.size * 카메라_여백
	# zoom < 1 = 줌아웃. 가로·세로 중 더 빡빡한 쪽에 맞춘다.
	var z: float = minf(화면.x / 필요.x, 화면.y / 필요.y)
	_캠.zoom = Vector2(z, z)
	_캠.global_position = 상자.get_center()
	_캠.enabled = true
	_캠.make_current()


# ── 안쪽 ────────────────────────────────────────────────────────────────────

## `테스트_*` 지형의 SS2D 점 배열에서 실제 경계를 구한다.
## ★콜리전이 아니라 **그려지는 점 배열**을 쓴다 — 화면에 보이는 것이 기준이어야 한다.
func _내용물_상자() -> Rect2:
	var 상자 := Rect2()
	var 처음 := true
	for n in _모두(self):
		if not (n is Node2D):
			continue
		if n.get("shape_material") == null:
			continue
		if not String(_최상위_이름(n)).begins_with("테스트_"):
			continue
		var pa = n.call("get_point_array") if n.has_method("get_point_array") else null
		if pa == null:
			continue
		for p in pa.get_vertices():
			var g: Vector2 = (n as Node2D).to_global(p)
			if 처음:
				상자 = Rect2(g, Vector2.ZERO)
				처음 = false
			else:
				상자 = 상자.expand(g)
	# 플레이어도 반드시 화면에 들어와야 한다.
	var p2 := get_node_or_null("테스트_Player") as Node2D
	if p2 and not 처음:
		상자 = 상자.expand(p2.global_position + Vector2(0, -120))
		상자 = 상자.expand(p2.global_position + Vector2(0, 40))
	return 상자


## 이 지형 노드가 속한 `테스트_*` 인스턴스의 이름.
## (METAL 템플릿은 루트 밑에 `SS2D_Shape_Closed` 가 한 겹 더 있다)
func _최상위_이름(n: Node) -> String:
	var c := n
	while c != null and c.get_parent() != self:
		c = c.get_parent()
	return String(c.name) if c != null else ""


func _노멀_모으기() -> void:
	_노멀_보관.clear()
	for n in _모두(self):
		var sm = n.get("shape_material")
		if sm == null:
			continue
		for t in sm.fill_textures:
			if t is CanvasTexture and (t as CanvasTexture).normal_texture != null:
				_노멀_보관[t] = (t as CanvasTexture).normal_texture


## 게임과 **같은 HUD 씬**을 쓴다 — 여기서만 보이는 가짜 HUD 를 만들면
## "테스트에서는 됐는데 게임에서 다르다"가 생긴다.
func _HUD_만들기(플레이어: Node) -> void:
	if not HUD_보이기 or 플레이어 == null:
		return
	var 코어 = get_tree().get_first_node_in_group("페인트코어")
	if 코어 == null:
		return
	var hud: CanvasLayer = 페인트HUD_씬.instantiate()
	hud.name = "페인트HUD"
	add_child(hud)
	hud.연결(플레이어, 페인트HUD어댑터_코어.new(코어, hud))


## 지시서 §12 — 게임 HUD 와 **섞지 않는** 작은 디버그 표시.
func _디버그_라벨_만들기() -> void:
	var 층 := CanvasLayer.new()
	층.name = "디버그표시"
	층.layer = 80
	add_child(층)
	_라벨 = Label.new()
	_라벨.name = "상태"
	# HUD(좌상단, 34~260px) 아래에 붙인다. 지형과 겹치지 않게 화면 왼쪽 위 구석만 쓴다.
	_라벨.position = Vector2(30, 175)
	_라벨.add_theme_font_size_override("font_size", 20)
	_라벨.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	_라벨.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_라벨.add_theme_constant_override("outline_size", 5)
	층.add_child(_라벨)
	_라벨_갱신()


func _라벨_갱신() -> void:
	if _라벨 == null:
		return
	_라벨.text = "LIGHTING LAB\nLight: %s\nEnvironment: %s\nPlayer Fill: %s\nShadow: %s\nNormal: %s" % [
		광원_자리,
		"ON" if 환경광_켬 else "OFF",
		"ON" if 보조광_켬 else "OFF",
		"ON" if 그림자_켬 else "OFF",
		"ON" if 노멀맵_켬 else "OFF"]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var 이름들 := 빛자리.keys()
	match e.keycode:
		KEY_RIGHT:
			빛_자리(이름들[(이름들.find(광원_자리) + 1) % 이름들.size()])
		KEY_LEFT:
			빛_자리(이름들[(이름들.find(광원_자리) - 1 + 이름들.size()) % 이름들.size()])
		KEY_N:
			노멀_켜기(not 노멀맵_켬)
		KEY_E:
			환경광_켜기(not 환경광_켬)
		KEY_F:
			보조광_켜기(not 보조광_켬)
		KEY_S:
			그림자_켜기(not 그림자_켬)
		_:
			return
	print("[노멀맵랩] 빛=%s 환경=%s 보조=%s 그림자=%s 노멀=%s" % [
		광원_자리, 환경광_켬, 보조광_켬, 그림자_켬, 노멀맵_켬])


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r
