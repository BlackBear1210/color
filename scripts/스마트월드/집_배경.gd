@tool
extends Node2D
## ============================================================================
## [2026-09-27 신규] 집 다층 배경 — **한 씬으로 스테이지마다 다른 방**을 만든다
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나 (도형님 지시 2026-09-27)
##   "챕터를 방→복도→방→복도로 구성하면 계속 같은 배경을 쓰는 것처럼 보일 거야.
##    배경을 레이어로 구성하는데 **하나의 레이어만 조금 다르게** 계속 만들어서
##    이어 붙일 때 계속 이어지는 배경, 즉 다른 작업자가 만든 배경처럼 보이게 하고 싶어."
##
## ▣ 어디서 가져온 방식인가
##   `scenes/배경/하수도_다층배경_v02.tscn` (다른 작업자)가 이미 쓰고 있는 방식이다.
##   하수도는 스테이지가 11 개인데 배경 그림은 **4 장**뿐이다. 스테이지마다 바뀌는 것은
##   **건축 스프라이트의 개수와 위치**뿐이고, 먼 벽과 안개는 전부 공유한다.
##   → "같은 시설 안의 다른 구역"으로 읽힌다. 집에도 그대로 적용한다.
##
## ▣ 네 겹과 각자의 역할
##   | 층 | scroll | z | 스테이지마다 | 왜 |
##   |---|---|---|---|---|
##   | 먼 벽 | 0.12 | −100 | **절대 안 바뀐다** | 이게 고정이라 "같은 집"으로 읽힌다 |
##   | 방 구조 | 0.30 | −90 | 창·문 위치와 좌우반전 | 여기가 "다른 방"을 만드는 층 |
##   | 가구 | 0.55 | −60 | 조합과 자리 | 방의 성격(서재·응접실) |
##   | 전경 | 1.15 | +40 | 기둥 간격 | 지나가는 속도감 |
##
##   ★바뀌는 층은 위 **두 개뿐**이다. 먼 벽이 고정이라 스테이지를 넘어도 같은 집이고,
##     방 구조와 가구가 달라서 다른 방이다. 이 둘의 비율이 이 시스템의 전부다.
##
## ▣ 쓰는 법
##   스테이지 씬 루트 아래에 이 스크립트를 단 Node2D 를 하나 놓고
##   `종류`(방/복도)와 `변형`(0~11)만 정한다. 스테이지마다 **변형 번호만 다르게** 준다.
##   위치는 (0,0), 배율은 (1,1) 로 둘 것 — 안에서 다 계산한다.
##   [2026-09-28 v05] 지형에 맞춰 세 값을 더 준다:
##     `바닥_y`(바닥 윗면) · `방_구간`(방이면 방마다 x 범위, 복도면 복도 전체 x 범위) ·
##     `천장_높이`(복도만 — 복도 벽 한 장이 바닥→천장을 채운다).
##   예시 씬: `scenes/집/테스트_집배경_방_v05.tscn` · `테스트_집배경_복도_v05.tscn`
##
## ▣ ⚠ 자식 노드에 owner 를 주지 않는다
##   @tool 스크립트가 만든 자식에 owner 를 주면 에디터 저장 때 **씬에 구워진다**
##   (`도약대.gd` 가 그래서 1-1 을 삼각형으로 무너뜨린 적이 있다 · 2026-09-20).
##   owner 없이 두면 저장에 안 들어가고, 열 때마다 이 스크립트가 다시 만든다.
## ============================================================================
class_name 집_배경

## [2026-09-28] v03 키트에서 아직 쓰는 것은 전경 두 장뿐이다(먼 벽·방·가구는 v05 로 넘어갔다).
## 전경 — 왼쪽 문틀+커튼 / 오른쪽 기둥
const T_전경L := preload("res://assets/background/집/room_kit_v03/fg/fg_01_x000_y000.png")
const T_전경R := preload("res://assets/background/집/room_kit_v03/fg/fg_02_x080_y000.png")

## ── [2026-09-28] v05 방 키트 ────────────────────────────────────────────────
## 아스트라 v05 주문서(§6) 파일 이름 그대로다. 아스트라가 진짜 그림을 주면 **같은 이름으로
## 덮어쓰기만** 하면 되고 이 스크립트는 안 고쳐도 된다.
## 지금 들어 있는 그림: 먼 벽 = 아스트라 A1 원본 · 나머지 = `tools/배경키트_v05/만들기.py` 가
## 기존 납품본에서 잘라 오거나 코드로 그린 대체품.
const 키트5 := "res://assets/background/집/room_kit_v05/"
const T5_먼벽_방 := preload("res://assets/background/집/room_kit_v05/far/wall_room_repeat.png")
const T5_가구: Array[Texture2D] = [
	preload("res://assets/background/집/room_kit_v05/layers/furniture_01_study.png"),
	preload("res://assets/background/집/room_kit_v05/layers/furniture_02_parlour.png"),
	preload("res://assets/background/집/room_kit_v05/layers/furniture_03_bedroom.png"),
	preload("res://assets/background/집/room_kit_v05/layers/furniture_04_storeroom.png"),
	preload("res://assets/background/집/room_kit_v05/layers/furniture_05_empty.png"),
	preload("res://assets/background/집/room_kit_v05/layers/furniture_06_stairhall.png"),
]
const T5_창 := preload("res://assets/background/집/room_kit_v05/mid/room_window_bay.png")
const T5_벽난로 := preload("res://assets/background/집/room_kit_v05/mid/room_fireplace_bay.png")
const T5_문 := preload("res://assets/background/집/room_kit_v05/mid/room_door_bay.png")
const T5_샹들리에 := preload("res://assets/background/집/room_kit_v05/fg/fg_chandelier_dead.png")
## 복도 — 먼 벽(A2)과 벽 디테일 6 장(C1~C6)
const T5_먼벽_복도 := preload("res://assets/background/집/room_kit_v05/far/wall_hall_repeat.png")
const T5_복도: Array[Texture2D] = [
	preload("res://assets/background/집/room_kit_v05/layers/hall_01_portraits.png"),
	preload("res://assets/background/집/room_kit_v05/layers/hall_02_sconces.png"),
	preload("res://assets/background/집/room_kit_v05/layers/hall_03_armour.png"),
	preload("res://assets/background/집/room_kit_v05/layers/hall_04_peeling.png"),
	preload("res://assets/background/집/room_kit_v05/layers/hall_05_doors_shut.png"),
	preload("res://assets/background/집/room_kit_v05/layers/hall_06_boxes.png"),
]
## 창 그림 안에서 유리 한가운데(가로·세로 비율) — 광원을 여기에 세운다.
const 창_유리_중심 := Vector2(0.50, 0.40)

enum 종류_ { 방, 복도 }

## 방이냐 복도냐. **같은 그림으로 다른 공간을 만든다** — 복도는 방 구조를 빼고
## 전경 기둥을 촘촘히 세워 "좁고 길다"를 만든다.
@export var 종류: 종류_ = 종류_.방:
	set(v): 종류 = v; _다시짓기()

## ★스테이지마다 **이 숫자만** 다르게 준다. 같은 숫자면 같은 방이 나온다(재현성).
@export_range(0, 11) var 변형: int = 0:
	set(v): 변형 = v; _다시짓기()

## 이 스테이지의 월드 크기. 배경을 얼마나 넓게 깔지 정한다.
@export var 맵_폭: float = 22272.0:
	set(v): 맵_폭 = v; _다시짓기()
@export var 맵_높이: float = 5760.0:
	set(v): 맵_높이 = v; _다시짓기()

## 그림 → 월드 배율. 1.25 = 1536px 그림이 화면 폭(1920)을 딱 채운다.
## ★이 값이 곧 "사람 대비 방이 얼마나 큰가"다. 프롬프트 v03 §2 의 크기 계약과 같은 값.
@export_range(0.6, 3.0, 0.05) var 배율: float = 1.25:
	set(v): 배율 = v; _다시짓기()

## 방 바닥선이 놓일 월드 y. 그림 속 바닥(높이의 87%)을 여기에 맞춘다.
@export var 바닥_y: float = 480.0:
	set(v): 바닥_y = v; _다시짓기()

## [2026-09-28] 방 구간(월드 x 시작, 끝) — 지형의 방 칸과 **같은 값**을 준다.
## 방마다 가구 세트 1 개 · 방 구조(창/벽난로/문) 1 개 · 샹들리에 1 개가 **그 방 한가운데**에
## 오도록 시차를 거꾸로 계산해서 놓는다. 비워 두면 맵 폭을 `방_수` 로 나눈다.
@export var 방_구간: PackedVector2Array = PackedVector2Array():
	set(v): 방_구간 = v; _다시짓기()
@export_range(1, 12) var 방_수: int = 4:
	set(v): 방_수 = v; _다시짓기()
## 방 구조(창·벽난로·문) 그림 배율. 방 천장이 낮은 스테이지(864 px)는 1.0 이라야
## 창 윗부분이 천장에 안 잘린다. 천장 1,920 px 방이면 1.25.
@export_range(0.6, 2.0, 0.05) var 배율_방구조: float = 1.0:
	set(v): 배율_방구조 = v; _다시짓기()
## 시차 그림을 '제자리'에 맞출 때 기준이 되는 카메라 중심 y.
## ProtoCamera 는 발밑보다 EYE_LIFT(60) 위를 본다. NAN 이면 바닥_y − 60 을 쓴다.
@export var 기준_카메라_y: float = NAN:
	set(v): 기준_카메라_y = v; _다시짓기()

## [2026-09-28] 복도 천장 높이(월드 px, 바닥에서). 복도 벽(A2) 한 장이 바닥→천장을 **딱 채우게**
## 배율을 이 값에서 역산한다 — 세로 반복이 없으니 가로 띠가 안 생긴다.
@export var 천장_높이: float = 960.0:
	set(v): 천장_높이 = v; _다시짓기()

## [2026-09-30] 여러 층 방(동굴형 집-1) — 층마다 바닥 윗면 y. 비워 두면 종전(한 층, `바닥_y`).
## ▣ 왜 세로 시차를 끄나
##   시차 층 안에서 위아래 층 그림의 **화면상 간격 = 층간격 × 시차** 가 된다(0.55 면 960 → 528).
##   그러면 윗층 가구가 아랫층 방 한가운데에 떠 보인다. 층이 여럿이면 세로는 1.0(월드 고정),
##   가로만 시차를 준다 → 층마다 그림이 제 바닥에 붙어 있고, 걸을 때만 깊이가 느껴진다.
## ▣ 층 모드에서 빼는 것
##   샹들리에·전경 기둥(z +40, 지형 **앞**)은 천장 낮은 층에서 윗층 발판을 가린다 → 안 놓는다.
##   창빛도 안 놓는다 — 층 4 × 방 4 = 광원 16 개가 체크포인트 10 개와 겹쳐 예산(15/캔버스아이템)을 넘는다.
@export var 층_바닥들: PackedFloat32Array = PackedFloat32Array():
	set(v): 층_바닥들 = v; _다시짓기()
## 층 모드에서 방 하나 폭(px). 층마다 맵 폭을 이 값으로 나눠 방을 만든다.
@export var 층_방폭: float = 5568.0:
	set(v): 층_방폭 = v; _다시짓기()

@export_group("시차")
@export var 시차_먼벽 := Vector2(0.12, 0.10):
	set(v): 시차_먼벽 = v; _다시짓기()
@export var 시차_방구조 := Vector2(0.30, 0.26):
	set(v): 시차_방구조 = v; _다시짓기()
@export var 시차_가구 := Vector2(0.55, 0.48):
	set(v): 시차_가구 = v; _다시짓기()
@export var 시차_전경 := Vector2(1.15, 1.10):
	set(v): 시차_전경 = v; _다시짓기()

## 그림 속 바닥선 위치(세로 비율). 수리 도구가 이 값 기준으로 아래를 녹였다.
const 그림_바닥 := 0.87


func _ready() -> void:
	_다시짓기()


func _다시짓기() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	# queue_free 는 프레임 끝에 처리된다. 지금 바로 새로 만들면 한 프레임 겹치므로
	# 이름 충돌을 피하려고 기존 것을 트리에서 먼저 뺀다.
	for c in get_children():
		remove_child(c)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260927 + 변형 * 7919      # 변형 번호가 곧 씨앗 = 같은 번호면 같은 방

	_배경판()
	_어둠()
	if 종류 == 종류_.방 and 층_바닥들.size() > 0:
		# [2026-09-30] 여러 층 방 — 동굴형 집-1
		_층들_v05(rng)
	elif 종류 == 종류_.방:
		# [2026-09-28] v05 — 방마다 한 세트씩, 방 한가운데에 맞춰 놓는다
		_먼벽_v05()
		_방들_v05(rng)
	else:
		# [2026-09-28] v05 복도 — 먼 벽(A2) + 벽 디테일 구간 + 촘촘한 전경 기둥
		_복도_v05(rng)


# ============================================================================
# 층 만들기
# ============================================================================
func _층(이름: String, 시차: Vector2, z: int, 반복: Vector2 = Vector2.ZERO) -> Parallax2D:
	var p := Parallax2D.new()
	p.name = 이름
	p.scroll_scale = 시차
	p.z_index = z
	p.repeat_size = 반복
	if 반복 != Vector2.ZERO:
		p.repeat_times = 4
	add_child(p)                      # ★owner 를 주지 않는다 — 씬에 구워지면 안 된다
	return p


func _그림(부모: Node, tex: Texture2D, 자리: Vector2, 알파: float = 1.0,
		반전: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = 자리
	s.scale = Vector2(배율, 배율) * (Vector2(-1, 1) if 반전 else Vector2.ONE)
	s.modulate = Color(1, 1, 1, 알파)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	부모.add_child(s)
	return s


## 창에서 새어 나오는 빛. 기준값은 전부 `조명표준.gd` 에서 가져온다(유일한 출처).
##
## ▣ 왜 광원을 파랄랙스 층 **안에** 넣나
##   창 그림이 시차로 흐르는데 빛만 월드에 고정하면, 걸어갈수록 빛과 창이 **어긋난다.**
##   같은 층에 넣으면 빛이 창을 따라다녀 둘이 항상 붙어 있다.
##   대가: 바닥에 깔린 빛 웅덩이가 카메라를 따라 조금 미끄러진다. 시차 0.30 에
##   아주 어두운 화면이라 눈에 잘 안 띄고, 창과 빛이 따로 노는 쪽이 훨씬 눈에 띈다.
##
## ▣ 세기를 왜 낮추나
##   CLAUDE.md: "★흰색 발판이 순백으로 뭉갠다 — 흰 지형 바로 위에 세기 1.0 넘는 광원을
##   두지 말 것. 빛은 **검정 지형을 읽히게 하려고** 놓는다." 창은 넓게 퍼지는 빛이므로
##   반경을 키우고 세기는 기준(1.6)보다 낮춘다.
func _창빛(부모: Node, 자리: Vector2, 이름: String) -> void:
	var L := PointLight2D.new()
	L.name = 이름
	L.position = 자리
	조명표준.적용(L, 1.05)
	조명표준.반경(L, 1450.0)
	L.color = Color(0.95, 0.96, 1.0)     # 바깥 흐린 하늘빛 — 아주 살짝 차다
	L.shadow_enabled = false             # 배경 광원이라 그림자까지 내면 지형이 더 안 읽힌다
	부모.add_child(L)


# ── ⓪ 배경판 — **화면이 비는 일이 절대 없게 한다** ──────────────────────────
## ▣ 왜 필요한가 (도형님 지적 2026-09-27)
##   "배경이 짤려서 아래면이 회색이랑 검정색으로 보이는 게, 플레이어 입장에서는
##    '어? 배경이 끊겨서 나오네?' 싶고 **맵이 덜 완성되었다는 걸 인지해버려.**"
##
##   원인은 배경 그림이 아니었다. 집 스테이지 씬에는 **배경색 노드가 하나도 없어서**
##   그림이 안 닿는 자리에 Godot 의 **기본 clear color(회색 0.3)** 가 그대로 보였다.
##   회색은 이 게임에서 하필 **안전한 회색 지형**의 색이라 최악의 오해를 부른다.
##
## ▣ 왜 Parallax 가 아니라 CanvasLayer 인가
##   Parallax 스프라이트는 아무리 크게 만들어도 카메라가 그 밖으로 나가면 끝이 보인다.
##   `CanvasLayer` 안의 **전체 화면 ColorRect** 는 카메라와 무관하게 언제나 화면을 덮는다.
##   → 카메라가 맵 어디로 가든, 줌이 얼마든, 빈 화면이 **구조적으로 불가능**해진다.
##   layer = −100 이라 월드(layer 0)보다 항상 뒤에 그려진다.
func _배경판() -> void:
	var cl := CanvasLayer.new()
	cl.name = "배경판"
	cl.layer = -100
	add_child(cl)
	var r := ColorRect.new()
	r.name = "어둠"
	# 방 그림의 녹인 바닥과 **같은 어둠**이라 경계가 안 보인다(수리 도구 `바닥_어둠`).
	r.color = Color(0.043, 0.043, 0.048)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)


# ── ⓪' 어둠 — 빛이 의미를 갖게 만드는 전제 ──────────────────────────────────
## ▣ 왜 여기서 켜나
##   생성기가 만든 집 스테이지에는 `CanvasModulate` 가 **하나도 없었다.** 그래서 화면이
##   전부 같은 밝기였고, 광원을 놓아도 **아무 차이가 안 났다**(어둡지 않은 곳은 못 밝힌다).
##   배경과 빛은 한 몸이라 배경 노드가 같이 책임진다.
##
## ▣ 값의 출처
##   `챕터.gd` 챕터표[1]["어둠"] = Color(0.72, 0.74, 0.70).
##   ⚠ 이 값은 STAGE 1 원화 밝기에 맞춰 이미 통과한 톤이라 **함부로 바꾸지 않는다**
##     (챕터.gd 주석: "지금 값을 바꾸면 이미 통과한 배경 톤이 전부 어긋난다").
func _어둠() -> void:
	# 씬에 이미 있으면 건드리지 않는다 — 손으로 조정해 둔 스테이지를 덮으면 안 된다.
	var 부모 := get_parent()
	if 부모:
		for c in 부모.get_children():
			if c is CanvasModulate:
				return
	var cm := CanvasModulate.new()
	cm.name = "어둠"
	cm.color = 챕터.팔레트(1).get("어둠", Color(0.72, 0.74, 0.70))
	add_child(cm)


# ============================================================================
# [2026-09-28] v05 방 — "먼 벽은 고정, 방마다 가구 한 장만 바뀐다" (주문서 §1-2)
# ============================================================================
## ▣ 시차 그림을 '그 방 앞'에 세우는 계산
##   Parallax2D 자식의 화면 x = 층x − 카메라왼쪽 × 시차.
##   카메라 중심이 월드 X 에 있을 때 그 그림이 **진짜로 X 에 있는 것처럼** 보이려면
##     층x = X − (X − 960) × (1 − 시차)
##   세로도 같다(기준 카메라 y 에서 맞춘다). 카메라가 그 자리를 떠나면 시차만큼 미끄러진다
##   — 그게 깊이감이고, 방 한가운데에서 '제자리'가 되도록 맞추는 것이 이 함수의 일이다.
func _층자리(월드: Vector2, 시차: Vector2) -> Vector2:
	var cy := (바닥_y - 60.0 if is_nan(기준_카메라_y) else 기준_카메라_y)
	var 화면 := Vector2(960.0, 540.0)
	var 기준 := Vector2(월드.x, cy)
	return 월드 - (기준 - 화면) * (Vector2.ONE - 시차)


func _방목록() -> Array:
	var 목록: Array = []
	if 방_구간.size() > 0:
		for v in 방_구간:
			목록.append(Vector2(v.x, v.y))
	else:
		var w := 맵_폭 / float(방_수)
		for i in 방_수:
			목록.append(Vector2(i * w, (i + 1) * w))
	return 목록


## 그림 한 장을 월드 기준점에 맞춰 층 안에 놓는다.
## 기준점 = 그림의 (가로 기준비율, 세로 기준비율) 지점이 월드 `자리` 에 오게.
func _세우기(층: Node, tex: Texture2D, 자리: Vector2, 시차: Vector2, 배: float,
		기준비율: Vector2, 반전: bool = false, 알파: float = 1.0) -> Sprite2D:
	var 크기 := Vector2(tex.get_width(), tex.get_height()) * 배
	var 층자리 := _층자리(자리, 시차) - 크기 * 기준비율
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(-배 if 반전 else 배, 배)
	s.position = 층자리 + (Vector2(크기.x, 0) if 반전 else Vector2.ZERO)
	s.modulate = Color(1, 1, 1, 알파)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	층.add_child(s)
	return s


# ── ① 먼 벽 — 가로로만 반복. 세로 반복은 안 한다(방 한가운데 가로띠가 생긴다) ───
## A1 은 방 한 칸 높이(1,536 → 월드 1,920)다. 아래 8 % 는 민무늬 벽 밑동이라
## 그 위쪽(92 %)을 바닥선에 맞춘다 — 밑동은 바닥 지형 뒤로 들어간다.
func _먼벽_v05() -> void:
	var tex := T5_먼벽_방
	var w := tex.get_width() * 배율
	var h := tex.get_height() * 배율
	var p := _층("먼벽", 시차_먼벽, -100, Vector2(w, 0))
	var y := _층자리(Vector2(0, 바닥_y), 시차_먼벽).y - h * 0.92
	var s := _그림(p, tex, Vector2(0, y))
	s.name = "그림"


# ── ②③④ 방마다 한 세트 ─────────────────────────────────────────────────────
## · 가구(0.55)   : 변형 번호에서 출발해 방마다 다음 세트 → 이웃 방끼리 절대 안 겹친다
## · 방 구조(0.30): 창 / 벽난로 / 창 / 문 을 돌려 쓴다. 넓은 방(> 4,000)은 창을 하나 더
## · 샹들리에(1.15): 방 한가운데 천장 — 화면 앞을 스치는 실루엣
## · 전경 기둥(1.15): 방과 방 사이 문간마다 — "방을 넘어간다"를 몸으로 느끼게
func _방들_v05(rng: RandomNumberGenerator) -> void:
	var 구조층 := _층("방구조", 시차_방구조, -90)
	var 가구층 := _층("가구", 시차_가구, -60)
	var 전경층 := _층("전경", 시차_전경, 40)
	var 방들 := _방목록()
	var 구조순서 := [T5_창, T5_벽난로, T5_창, T5_문]
	var 가구기준 := Vector2(0.5, 그림_바닥)          # 가구 캔버스의 바닥선(87 %) 한가운데
	var 구조기준 := Vector2(0.5, 그림_바닥)          # 방 구조도 같은 바닥선 계약

	for i in 방들.size():
		var 방: Vector2 = 방들[i]
		var cx := (방.x + 방.y) * 0.5
		var 폭 := 방.y - 방.x

		# 가구 — 이 스테이지의 성격은 '변형'이 정하고, 방마다 한 칸씩 넘긴다
		var k := (변형 + i) % T5_가구.size()
		var 반전 := rng.randf() < 0.4
		var g := _세우기(가구층, T5_가구[k], Vector2(cx, 바닥_y), 시차_가구, 배율, 가구기준, 반전)
		g.name = "가구_%d_%s" % [i, T5_가구[k].resource_path.get_file().get_basename()]

		# 방 구조 — 가구와 겹치지 않게 방 안에서 조금 비켜 선다
		var 구조 := [구조순서[(변형 + i) % 구조순서.size()]]
		if 폭 > 4000.0 and 구조[0] != T5_창:
			구조.append(T5_창)
		for j in 구조.size():
			var t: Texture2D = 구조[j]
			var 비켜 := 폭 * (0.18 if j == 0 else -0.24) * (-1.0 if 반전 else 1.0)
			var 자리 := Vector2(cx + 비켜, 바닥_y)
			var sp := _세우기(구조층, t, 자리, 시차_방구조, 배율_방구조, 구조기준)
			sp.name = "구조_%d_%d_%s" % [i, j, t.resource_path.get_file().get_basename()]
			if t == T5_창:
				var 크기 := Vector2(t.get_width(), t.get_height()) * 배율_방구조
				_창빛(구조층, sp.position + 크기 * 창_유리_중심, "창빛_%d_%d" % [i, j])

		# 샹들리에 — 천장은 보통 화면 밖이라, 화면 맨 위 1/8 에만 걸리게 늘어뜨린다.
		#   1 차 촬영(배율 0.9 · 화면 위 끝에서 시작)은 몸통이 화면 한가운데 와서 플레이를 가렸다.
		#   → 배율 0.55(높이 약 330) · 윗끝을 화면 위 200 px 밖에 둔다 = 화면 안엔 아랫부분 130 px 만.
		var ch_y := 바닥_y - 60.0 - 540.0 - 200.0
		var ch := _세우기(전경층, T5_샹들리에, Vector2(cx - 폭 * 0.08, ch_y), 시차_전경, 0.55,
			Vector2(0.5, 0.0), false, 0.95)
		ch.name = "샹들리에_%d" % i

		# 전경 기둥 — 다음 방과의 문간에
		if i < 방들.size() - 1:
			var 문간 := (방.y + (방들[i + 1] as Vector2).x) * 0.5
			var 오른쪽 := (i % 2) == 1
			var tex := T_전경R if 오른쪽 else T_전경L
			var fg := _세우기(전경층, tex, Vector2(문간, 바닥_y + 40.0), 시차_전경, 배율,
				Vector2(0.5, 1.0), false, 0.92)
			fg.name = "전경_%d" % i


# ============================================================================
# [2026-09-30] v05 여러 층 방 — 동굴형 집-1 (층 4 개 · 층간격 960)
# ============================================================================
## 방 모드와 같은 그림·같은 규칙(먼 벽 고정, 방마다 가구 한 장)을 층마다 되풀이한다.
## 층이 바뀌면 `변형` 을 3 칸씩 넘긴다 → 바로 위아래 방끼리도 가구가 안 겹친다.
func _층들_v05(rng: RandomNumberGenerator) -> void:
	var 바닥들: Array = Array(층_바닥들)
	바닥들.sort()
	var 간격 := 960.0
	for j in range(1, 바닥들.size()):
		간격 = minf(간격, float(바닥들[j]) - float(바닥들[j - 1]))

	# ① 먼 벽 — 층마다 한 줄 + 맨 윗층 위로 한 줄. 한 줄 높이(92 %)가 층간격과 같게 줄인다.
	var 벽 := T5_먼벽_방
	var 벽배 := 간격 / (벽.get_height() * 0.92)
	var 벽층 := _층("먼벽", Vector2(시차_먼벽.x, 1.0), -100, Vector2(벽.get_width() * 벽배, 0))
	var 줄들: Array = 바닥들.duplicate()
	줄들.push_front(float(바닥들[0]) - 간격)
	for j in 줄들.size():
		var s := _그림(벽층, 벽, Vector2(0, float(줄들[j]) - 벽.get_height() * 벽배 * 0.92))
		s.scale = Vector2(벽배, 벽배)
		s.name = "그림_%d" % j

	# ②③ 층마다 방 세트(가구 0.55 · 방 구조 0.30). 그림 키는 층간격의 85 % 이내.
	var 층배 := 간격 * 0.85 / (1024.0 * 그림_바닥)
	var 구조층 := _층("방구조", Vector2(시차_방구조.x, 1.0), -90)
	var 가구층 := _층("가구", Vector2(시차_가구.x, 1.0), -60)
	var 구조순서 := [T5_창, T5_벽난로, T5_창, T5_문]
	var 기준 := Vector2(0.5, 그림_바닥)
	var 방수 := maxi(1, roundi(맵_폭 / 층_방폭))
	var 방폭 := 맵_폭 / float(방수)
	for f in 바닥들.size():
		var y: float = 바닥들[f]
		for i in 방수:
			var cx := (i + 0.5) * 방폭
			var n := 변형 + f * 3 + i
			var k := n % T5_가구.size()
			var 반전 := rng.randf() < 0.4
			var g := _세우기(가구층, T5_가구[k], Vector2(cx, y), Vector2(시차_가구.x, 1.0), 층배, 기준, 반전)
			g.name = "가구_%d_%d_%s" % [f, i, T5_가구[k].resource_path.get_file().get_basename()]
			var t: Texture2D = 구조순서[n % 구조순서.size()]
			var 비켜 := 방폭 * 0.2 * (-1.0 if 반전 else 1.0)
			var sp := _세우기(구조층, t, Vector2(cx + 비켜, y), Vector2(시차_방구조.x, 1.0), 층배, 기준)
			sp.name = "구조_%d_%d_%s" % [f, i, t.resource_path.get_file().get_basename()]


# ============================================================================
# [2026-09-28] v05 복도 — "같은 집의 다른 부분" (주문서 §5-A2 · §5-C)
# ============================================================================
## ▣ 방과 무엇이 다른가
##   · 먼 벽이 **낮고 촘촘하다**(널판 징두리 + 그림 레일). 방 벽(A1)의 결을 그대로 써서 같은 집이다.
##   · 방 구조층(창·벽난로)이 **없다.** 복도에는 창이 없어서 빛도 안 세운다 — 방보다 어둡다.
##   · 디테일은 방처럼 "방마다 1 장" 이 아니라 **구간마다 1 장씩 끊김 없이 잇는다.**
##     한 장(월드 1,920)은 시차 0.55 에서 카메라가 1,920 ÷ 0.55 ≈ 3,490 px 를 가는 동안 화면을 지나간다.
##     그래서 구간 길이를 3,490 으로 잡으면 장과 장이 겹치지도 비지도 않고 맞물린다.
##   · 전경 기둥이 방(문간마다)보다 훨씬 자주 스친다 → "좁고 길다 · 빠르게 지나간다".
func _복도_v05(rng: RandomNumberGenerator) -> void:
	# ① 먼 벽 — 바닥에서 천장까지 한 장. 가로로만 반복.
	var tex := T5_먼벽_복도
	var 배 := 천장_높이 / float(tex.get_height())
	var w := tex.get_width() * 배
	var h := tex.get_height() * 배
	var 벽층 := _층("먼벽", 시차_먼벽, -100, Vector2(w, 0))
	var 벽 := _그림(벽층, tex, Vector2(0, _층자리(Vector2(0, 바닥_y), 시차_먼벽).y - h))
	벽.scale = Vector2(배, 배)
	벽.name = "그림"

	# ② 벽 디테일 — 구간마다 한 장. 변형 번호에서 출발해 한 칸씩 넘긴다(이웃 구간이 안 겹친다)
	var 디테일층 := _층("벽디테일", 시차_가구, -60)
	var 범위: Vector2 = (_방목록()[0] as Vector2) if 방_구간.size() > 0 else Vector2(0, 맵_폭)
	var 장폭 := T5_복도[0].get_width() * 배율
	var 구간 := 장폭 / 시차_가구.x
	var x := 범위.x + 구간 * 0.5
	var i := 0
	while x < 범위.y + 구간 * 0.5:
		var k := (변형 + i) % T5_복도.size()
		var 반전 := rng.randf() < 0.4
		var d := _세우기(디테일층, T5_복도[k], Vector2(x, 바닥_y), 시차_가구, 배율,
			Vector2(0.5, 그림_바닥), 반전)
		d.name = "디테일_%02d_%s" % [i, T5_복도[k].resource_path.get_file().get_basename()]
		i += 1
		x += 구간

	# ③ 전경 기둥 — 1,300~1,900 px 마다. 대부분 가는 기둥, 가끔 커튼 문틀
	var 전경층 := _층("전경", 시차_전경, 40)
	var fx := 범위.x + rng.randf_range(400.0, 1200.0)
	var n := 0
	while fx < 범위.y:
		var 문틀 := rng.randf() < 0.25
		var ft := T_전경L if 문틀 else T_전경R
		var fg := _세우기(전경층, ft, Vector2(fx, 바닥_y + 40.0), 시차_전경, 배율,
			Vector2(0.5, 1.0), rng.randf() < 0.5, 0.92)
		fg.name = "전경_%02d" % n
		n += 1
		fx += rng.randf_range(1300.0, 1900.0)
