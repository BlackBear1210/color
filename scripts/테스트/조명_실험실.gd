extends Node2D
## ============================================================================
## [2026-09-05 신규 · STEP 5 개편] 조명 표준 실험실 컨트롤러
## ----------------------------------------------------------------------------
## ▣ 무엇을 하나
##   `Lighting_Standard_Lab.tscn` 의 **세 구역**에 각각 정해진 조명 조합을 세운다.
##
##     구역 A  환경광만                  (Environment Only)
##     구역 B  환경광 + 플레이어 보조광   (Environment + Player Fill)
##     구역 C  환경광 + 보조광 + 그림자   (Full Lighting)
##
##   구역마다 BRICK · WOOD · GRASS · METAL 이 같은 배치로 깔려 있어서,
##   **한 화면에서** 세 조명 조합의 차이를 볼 수 있다.
##
## ▣ 광원 텍스처는 조명표준이 만든 것을 나눠 쓴다
##   ⚠ PointLight2D 는 texture 가 없으면 **아무것도 안 비춘다.**
##     (2026-09-05 에 실험실이 통째로 안 보였던 원인이 이것이다)
##   같은 텍스처를 써야 실험실에서 고른 값이 본 스테이지에서 그대로 재현된다.
##
## ▣ 조작 (F6 로 이 씬만 실행할 때 · **테스트 전용**)
##   ← / →  환경광 위치 조건       ↑ / ↓  height 단계       N  노멀맵 ON/OFF
##   1 ~ 4   CanvasModulate 후보값      Q / W  환경광 energy − / +
##   Z / X   보조광 밝기 − / +          C      보조광 전체 ON/OFF
##   ⚠ 게임플레이 입력(Input Map)은 한 글자도 안 건드린다. 이 씬 안에서만 도는 키다.
##
## ▣ 촬영 도구가 쓰는 창구
##   `조건_세우기` · `높이_세우기` · `세기_세우기` · `반경_세우기`
##   · `어둠_세우기` · `노멀_켜기` · `보조광_세우기`
## ============================================================================

## ⚠ class_name 이 아니라 **경로 preload** — 헤드리스에서 전역 클래스 등록보다 먼저 돈다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")

const 판_가로 := 512.0
const 판_세로 := 192.0

## ★비교할 환경광 위치 조건 — 값은 그 재질 줄의 원점 기준 오프셋.
const 조건표 := {
	"LEFT":  Vector2(-판_가로 * 0.60, -110.0),
	"RIGHT": Vector2( 판_가로 * 0.60, -110.0),
	"TOP":   Vector2(0.0, -판_세로 * 1.50),
	"LOW":   Vector2(0.0, -판_세로 * 0.55),
	"HIGH":  Vector2(0.0, -판_세로 * 3.20),
}
const 높이표 := [32.0, 64.0, 128.0, 256.0]
const 어둠표 := [0.45, 0.55, 0.62, 0.72]

## 구역 이름 → [보조광 켬, 그림자 켬]
const 구역_설정 := {
	"A_환경광만":      [false, false],
	"B_환경광_보조광": [true, false],
	"C_전체":          [true, true],
}

@export var 조건: String = "LEFT"
@export var 빛_높이: float = 조명표준.높이
@export var 빛_세기: float = 조명표준.기준_세기
@export var 빛_반경: float = 조명표준.기준_반경
@export var 어둠_밝기: float = 0.62
@export var 노멀맵_켬: bool = true
@export var 보조광_밝기: float = 조명표준.보조광_세기

var _빛들: Array[PointLight2D] = []
## CanvasTexture 의 normal_texture 를 잠깐 빼 두는 자리 (대조군용 · 리소스 파일은 안 고친다)
var _노멀_보관: Dictionary = {}


func _ready() -> void:
	# ⚠ Player.tscn 안에도 Camera2D 가 있다. 구역마다 Player 가 하나씩 있으니
	#   그대로 두면 그중 하나가 current 가 되어 실험실 카메라가 통째로 무시된다
	#   (실제로 세 구역 사진이 전부 같게 나왔다). 씬에 구운 enabled=false 가
	#   인스턴스 오버라이드로 안 남는 경우가 있어 **런타임에서 확실히** 끈다.
	for n in _모두(self):
		if n is Camera2D and n.get_parent() != null \
				and String(n.get_parent().name) == "Player":
			(n as Camera2D).enabled = false
	var 캠 := get_node_or_null("촬영카메라") as Camera2D
	if 캠:
		캠.enabled = true
		캠.make_current()

	for 구역이름: String in 구역_설정:
		var 구역 := get_node_or_null(구역이름) as Node2D
		if 구역 == null:
			continue
		var 보조켬: bool = 구역_설정[구역이름][0]
		var 그늘켬: bool = 구역_설정[구역이름][1]
		for c in 구역.get_children():
			if c is PointLight2D:
				var L := c as PointLight2D
				L.texture = 조명표준.방사형_텍스처()
				# 곱하기가 아니라 더하기 — 어두운 배경 위에 빛이 "얹히는" 느낌.
				# (MIX 로 두면 빛이 닿은 자리가 통째로 회색 판이 된다)
				조명표준.적용(L, 빛_세기)
				L.shadow_enabled = 그늘켬
				L.shadow_filter = Light2D.SHADOW_FILTER_PCF13
				L.shadow_filter_smooth = 8.0
				L.shadow_color = Color(0, 0, 0, 조명표준.그림자_알파)
				_빛들.append(L)
			# Player 안의 보조광 — 구역마다 켜고 끈다.
			var 보조 := c.get_node_or_null("플레이어_보조광")
			if 보조 != null:
				보조.set("켜기", 보조켬)
				보조.set("밝기", 보조광_밝기)
				# 이 구역의 광원 레이어만 비추게 (옆 구역으로 새면 비교가 무의미)
				var pl := 보조.get_node_or_null("PointLight2D") as PointLight2D
				if pl:
					pl.range_item_cull_mask = _레이어(구역이름)
			# Player 본체도 이 구역 빛만 받게
			if c.name == "Player" and c is CanvasItem:
				(c as CanvasItem).light_mask = _레이어(구역이름)

	_노멀_모으기()
	조건_세우기(조건)
	높이_세우기(빛_높이)
	세기_세우기(빛_세기)
	반경_세우기(빛_반경)
	어둠_세우기(어둠_밝기)
	노멀_켜기(노멀맵_켬)


func _레이어(구역이름: String) -> int:
	var i := 구역_설정.keys().find(구역이름)
	return 1 << maxi(i, 0)


# ── 창구 ────────────────────────────────────────────────────────────────────

func 조건_세우기(이름: String) -> void:
	if not 조건표.has(이름):
		return
	조건 = 이름
	var 오프: Vector2 = 조건표[이름]
	for L in _빛들:
		# 광원의 x 기준점은 그 재질 줄의 원점이다. 오프셋이 **누적되지 않도록**
		# 원점을 다시 계산해서 얹는다.
		var 줄x := roundf((L.position.x + 판_가로 * 0.60) / 800.0) * 800.0
		L.position = Vector2(줄x, 0.0) + 오프


func 높이_세우기(px: float) -> void:
	빛_높이 = px
	for L in _빛들:
		L.height = px


func 세기_세우기(값: float) -> void:
	빛_세기 = 값
	for L in _빛들:
		L.energy = 값


## 빛의 반경(px). 텍스처가 256px 기준이라 texture_scale = 반경 / 128 이다.
## ★"광원이 아니라 공간이 밝아 보이게" 하는 데 energy 보다 이쪽이 훨씬 크게 작용한다 —
##   작은 반경 + 센 energy 는 허공에 흰 구슬이 뜬 것처럼 보인다.
func 반경_세우기(px: float) -> void:
	빛_반경 = px
	for L in _빛들:
		조명표준.반경(L, px)


func 어둠_세우기(값: float) -> void:
	어둠_밝기 = 값
	var 어둠 := get_node_or_null("어둠") as CanvasModulate
	if 어둠:
		어둠.color = Color(값, 값, 값)


## 보조광 밝기를 세 구역에 한꺼번에 준다(켜져 있는 구역에만 보인다).
func 보조광_세우기(값: float) -> void:
	보조광_밝기 = 값
	for n in _모두(self):
		if n.name == "플레이어_보조광":
			n.set("밝기", 값)


## ★노멀맵 ON/OFF 는 **씬을 바꾸지 않고** CanvasTexture 의 normal_texture 만 비운다.
##   그래야 나머지 조건이 100 % 같은 진짜 대조군이 된다.
func 노멀_켜기(켬: bool) -> void:
	노멀맵_켬 = 켬
	for ct: CanvasTexture in _노멀_보관.keys():
		ct.normal_texture = (_노멀_보관[ct] if 켬 else null)


# ── 안쪽 ────────────────────────────────────────────────────────────────────

func _노멀_모으기() -> void:
	_노멀_보관.clear()
	for n in _모두(self):
		var sm = n.get("shape_material")
		if sm == null:
			continue
		for t in sm.fill_textures:
			if t is CanvasTexture and (t as CanvasTexture).normal_texture != null:
				_노멀_보관[t] = (t as CanvasTexture).normal_texture


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var 이름들 := 조건표.keys()
	match e.keycode:
		KEY_RIGHT:
			조건_세우기(이름들[(이름들.find(조건) + 1) % 이름들.size()])
		KEY_LEFT:
			조건_세우기(이름들[(이름들.find(조건) - 1 + 이름들.size()) % 이름들.size()])
		KEY_UP:
			높이_세우기(높이표[(높이표.find(빛_높이) + 1) % 높이표.size()])
		KEY_DOWN:
			높이_세우기(높이표[(높이표.find(빛_높이) - 1 + 높이표.size()) % 높이표.size()])
		KEY_N:
			노멀_켜기(not 노멀맵_켬)
		KEY_Q:
			세기_세우기(maxf(빛_세기 - 0.1, 0.0))
		KEY_W:
			세기_세우기(빛_세기 + 0.1)
		KEY_Z:
			보조광_세우기(maxf(보조광_밝기 - 0.05, 0.0))
		KEY_X:
			보조광_세우기(보조광_밝기 + 0.05)
		KEY_C:
			for n in _모두(self):
				if n.name == "플레이어_보조광":
					n.set("켜기", not bool(n.get("켜기")))
		KEY_1, KEY_2, KEY_3, KEY_4:
			어둠_세우기(어둠표[e.keycode - KEY_1])
		_:
			return
	print("[조명실험실] 조건=%s height=%.0f energy=%.2f 반경=%.0f 어둠=%.2f 보조광=%.2f 노멀=%s" % [
		조건, 빛_높이, 빛_세기, 빛_반경, 어둠_밝기, 보조광_밝기, 노멀맵_켬])


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r
