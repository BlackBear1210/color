@tool
extends SS2D_Shape_Closed
## ============================================================================
## [2026-08-01 신규] 칠할 수 있는 SmartShape2D 지형
## ----------------------------------------------------------------------------
## ▣ 왜 SS2D_Shape_Closed 를 상속했나
##   지형의 모양 편집(점 찍기·베지어 곡선)은 SS2D 플러그인이 이미 완벽하게 해준다.
##   여기에 "색칠 규칙"만 얹으면 되므로, 별도 래퍼 노드를 두지 않고 그대로 상속했다.
##   → 에디터에서 이 노드를 고르면 SS2D 툴바가 그대로 뜬다. 사용법이 안 바뀐다.
##
## ▣ @tool 인 이유
##   부모(SS2D_Shape)가 @tool 이다. 자식이 @tool 이 아니면 에디터에서 스크립트가
##   아예 안 돌아 지형 편집이 죽는다. 대신 런타임 전용 로직은 전부
##   `Engine.is_editor_hint()` 로 막아둔다.
##
## ▣ 색 상태 4가지 (docs/기획서_규칙_플로우차트.md 와 동일한 언어)
##   무색 : 아직 안 칠함. 누구나 안전. `무색일때_통과` 가 켜져 있으면 못 밟는 유령.
##   검정 : 검정 플레이어만 안전.   흰색 : 흰색 플레이어만 안전.
##   회색 : 장애물 상호작용이나 시작 설정으로만 만든다. 플레이어 총알끼리는 섞이지 않는다.
##
## ▣ 부분 색칠 / 전체 색칠
##   한 발로 다 안 덮이는 크기면 맞은 자리만 얼룩진다(부분).
##   `필요횟수()` 만큼 같은 색을 맞히면 전체 색칠로 승격된다.
##   부분 색칠은 `부분_유지시간` 동안 새 명중이 없으면 스스로 흐려지고,
##   다 사라진 순간 페인트코어에 발수를 돌려준다(기획: "서서히 흐려지다 자동 회수").
## ============================================================================
class_name 스마트지형

const 페인트_셰이더 := preload("res://shaders/지형_페인트.gdshader")
const 페인트진행_S := preload("res://scripts/페인트_진행.gd")
const 최대_시드: int = 24                      ## 셰이더의 MAX_SEEDS 와 반드시 같아야 한다
## 번짐 지수 감쇠 상수. `tile_paint_map.gd` 와 **같은 값**이어야 손맛이 같다.
const 번짐_지수: float = 0.0008
## 얼룩 반지름을 자리마다 몇 % 씩 일그러뜨리나 (셰이더 `blob_wobble` 과 **반드시 같은 값**).
## 전체 색칠 반경에 이만큼 여유를 더해야 오목한 쪽 구석이 안 칠해진 채 남지 않는다.
const 얼룩_일그러짐: float = 0.14

enum 상태 { 무색, 검정, 흰색, 회색 }

## 유령(무색·통과) 상태에서 쓰는 물리 레이어 = 4번(비트 8).
## PaintPlatform(v3) 과 같은 값을 써야 총알·조준 코드가 두 시스템에서 똑같이 동작한다.
const 유령_레이어비트: int = 8

@export_group("색칠")
## 끄면 영원히 무색인 "구조물"이 된다. 바닥·벽처럼 배경이 되는 지형에 쓴다.
@export var 칠하기_허용: bool = true
## 무색일 때 밟을 수 없는 유령으로 둘지. 공중 발판은 true(칠해야 길이 생김),
## 바닥은 false(항상 밟힘)로 두는 게 기본 문법이다.
@export var 무색일때_통과: bool = false
## 0 이면 지형 크기에서 자동 계산. 특정 발판만 더 어렵게/쉽게 하고 싶을 때만 값을 넣는다.
@export_range(0, 12) var 필요횟수_수동: int = 0
## 시작부터 칠해진 상태로 두고 싶을 때 (고정 색 지형).
@export var 시작상태: 상태 = 상태.무색

@export_group("연출")
## 부분 색칠 얼룩 하나의 반지름(px).
@export var 부분_반지름: float = 46.0
## 마지막 명중 후 이 시간이 지나면 부분 색칠이 흐려지기 시작한다(초).
@export var 부분_유지시간: float = 4.0
## 흐려지는 데 걸리는 시간(초).
@export var 부분_감쇠시간: float = 1.0

## ★[2026-08-29] 잉크 번짐 — 타일맵(`tile_paint_map.gd`)이 쓰던 연출을 SS2D 로 옮긴 것.
## 예전에는 맞은 자리에 46px 얼룩이 **즉시** 찍혔다. 타일맵은 씨앗이 0 에서 자라고
## 마지막 한 방에 전체로 확 튀어서 "칠했다"는 쾌감이 있었는데 그게 없었다.
##
## 아래로 흘러내리는 물감 줄기의 최대 길이(px). 0 이면 흘러내리지 않는다.
@export var 흘러내림_길이: float = 74.0
## 흘러내리는 속도(px/초).
@export var 흘러내림_속도: float = 110.0
## 테두리가 안쪽보다 얼마나 먼저 물드나. **1.0 = 한 덩어리로 칠해진다(기본).**
##
## ⚠★[2026-08-29] 기본값을 1.35 에서 **1.0 으로 내렸다** (성진님 제보).
##   SS2D 는 테두리 메시와 채우기 메시가 따로라, 테두리 쪽 얼룩만 크게 그리면
##   **테두리는 다 칠해졌는데 안쪽은 덜 칠해진** 상태가 눈에 그대로 보인다.
##   경계가 띠 두께를 따라 **직선으로 잘리고**, 모서리에서는 검은 쐐기가 파고든다.
##   "물감이 번진다" 가 아니라 "테두리와 안쪽을 따로 칠했다" 로 읽힌다.
##   → 기본은 한 덩어리. 이 값은 그 효과를 일부러 쓰고 싶을 때만 올린다(1.05~1.1 권장).
@export_range(1.0, 2.0, 0.05) var 테두리_선행: float = 1.0

# ── 내부 상태 ──────────────────────────────────────────────────────────────
var 현재상태: 상태 = 상태.무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _진행 := 페인트진행_S.new()

var _시드: PackedVector2Array = PackedVector2Array()      # 노드 로컬 px
var _반지름: PackedFloat32Array = PackedFloat32Array()     ## 지금 반지름 (자라는 중)
var _목표: PackedFloat32Array = PackedFloat32Array()       ## 자라서 닿을 반지름
var _흘러내림: PackedFloat32Array = PackedFloat32Array()   ## 아래로 흘러내린 길이(px)
## 시드별 흘러내림 상한. **총에 맞아 생긴 얼룩만** 0 보다 크다 —
## `시작상태` 로 태어난 지형에서 물감이 흘러내리면 방금 칠한 것처럼 보여 거짓말이 된다.
var _흘림상한: PackedFloat32Array = PackedFloat32Array()
var _세기: PackedFloat32Array = PackedFloat32Array()
var _색: PackedInt32Array = PackedInt32Array()

var _젖음: float = 0.0
var _셰이더들: Array[ShaderMaterial] = []
var _로컬반경: float = 200.0                 ## 전체를 덮는 데 필요한 반지름 (자동 계산)
var _중심: Vector2 = Vector2.ZERO            ## 로컬 AABB 중심 (전체 색칠 얼룩의 기준점)
var _긴변: float = 200.0                     ## 로컬 AABB 의 긴 변 — 필요횟수 계산에 쓴다
var _면적: float = 40000.0                   ## 다각형 실면적(px²) — 번짐 목표 반지름 계산에 쓴다
## 채우기 텍스처들. 메시가 테두리인지 채우기인지 **이름 추측 없이** 가르는 데 쓴다
## (옛 벽돌 채움은 `brick_black_seamless_341x307.png` 라 이름에 fill 이 없다).
var _채움_텍스처들: Array[Texture2D] = []
## 페인트 규칙 엔진. 스마트월드에서는 `페인트코어`, 프로토 계열 스테이지에서는
## `TilePaintMap` 이 들어온다 — 둘 다 `부분_자동회수()` 를 갖는 **계약**만 맞으면 된다.
var _코어: Node = null

## ★[2026-08-27] `_메시별_셰이더_보정()` 을 마지막으로 돌렸을 때의 메시 개수.
## 모양을 편집해 메시가 다시 구워지면 개수가 달라지므로 그때 한 번 더 훑는다.
var _보정한_메시수: int = -1


func _ready() -> void:
	# ★★[2026-08-26] Template 인스턴스가 **남의 크기로 렌더되는 버그** 차단
	# ------------------------------------------------------------------------
	# 증상: `scenes/집/스마트 매쉬 assets/TEMPLATE_*.tscn` 을 인스턴스해서 점을 바꿔도
	#       화면에는 **Template 원래 크기**(벽돌 310×500 / 나무 410×580)로 그려진다.
	#       콜리전과 레벨검사는 새 점을 쓰므로 "보이는 것과 밟는 것이 다른" 상태가 된다.
	#       집 4방(2층방·거실·부엌·굴뚝)의 바닥·천장·벽이 전부 이 상태였다.
	#       원화가 앞을 가려서 여태 안 보였을 뿐이다.
	#
	# 원인 두 겹:
	#   ① `_meshes` 는 부모(SS2D_Shape)의 `@export_storage` 라 **저장 씬에 실린다.**
	#      Template 이 이미 구워 둔 메시가 인스턴스에 그대로 따라온다.
	#   ② `force_update()` 는 `if not _first_update or not _meshes:` 일 때만 다시 굽는다.
	#      로드 직후는 `_first_update == true` 이고 `_meshes` 가 비어 있지 않으니 **안 굽는다.**
	#      빌더에서 `_meshes` 를 비워 저장하려 해도 소용없다 — 빈 배열은 프로퍼티 기본값이라
	#      `PackedScene.pack()` 이 아예 저장하지 않고, 로드 때 Template 값으로 되돌아간다.
	#
	# 그래서 **여기서 비운다.** 점 배열은 인스턴스마다 제대로 저장되므로, 비운 뒤
	# `super()`로 렌더러를 만들고 바로 아래의 `force_update()`로 그 점을 새로 굽는다.
	# 에디터에서도 비운다 — 작업자가 Template 을 복제해 점을 끌었을 때 크기가 안 변하는
	# 그 함정(README_지형찍기 작업자들이 실제로 겪은 것)이 같은 원인이기 때문이다.
	_meshes.clear()

	super()                                   # ★SS2D 의 렌더러 초기화를 반드시 먼저
	# ★ [2026-08-27] 메시를 비운 뒤에도 _dirty가 false면 부모는 재굽기를 건너뛴다.
	# 그 경우 이전 캔버스 메시가 남아 다른 템플릿이 합쳐진 것처럼 보이므로,
	# 렌더러가 준비된 직후 현재 점 배열 기준으로 반드시 다시 굽고 기존 RID를 교체한다.
	force_update()
	if Engine.is_editor_hint():
		return
	add_to_group("칠할수있음")
	add_to_group("스마트지형")
	_코어 = _규칙엔진_찾기()
	_진행.유지시간 = 부분_유지시간
	_진행.감쇠시간 = 부분_감쇠시간
	_로컬반경_계산()
	_셰이더_설치()
	현재상태 = 시작상태
	if 현재상태 != 상태.무색:
		_전체_즉시(현재상태)
	_충돌레이어_갱신()
	_유니폼_갱신()
	set_process(true)


## 이 지형의 페인트 규칙을 관리하는 노드를 찾는다.
##
## ▣ 왜 두 군데를 보나 (2026-08-29)
##   같은 SS2D 지형이 **두 계열 스테이지**에 다 놓인다.
##     · 스마트월드(`월드.gd`)  → 그룹 "페인트코어" 의 `페인트코어`
##     · 프로토(`stage_lab.gd`) → 자식으로 붙는 `TilePaintMap`("타일페인트")
##   전에는 앞엣것만 봤다. 프로토 스테이지에 지형을 놓으면 `_코어` 가 null 이라,
##   부분 칠이 스스로 흐려져 사라져도 **총알이 안 돌아왔다**(잠긴 채로 남는다).
func _규칙엔진_찾기() -> Node:
	var 코어 := get_tree().get_first_node_in_group("페인트코어")
	if 코어 != null:
		return 코어
	# 프로토 계열 — 스테이지 루트 아래에 붙은 TilePaintMap 을 위로 올라가며 찾는다.
	var n := get_parent()
	while n != null:
		for 자식 in n.get_children():
			if 자식.has_method("노드_명중") and 자식.has_method("부분_자동회수"):
				return 자식
		n = n.get_parent()
	return null


## 지형 전체를 덮으려면 얼룩 반지름이 얼마여야 하는지 — 로컬 AABB 의 대각선 절반.
func _로컬반경_계산() -> void:
	var 점들 := get_point_array().get_tessellated_points()
	if 점들.is_empty():
		return
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	_중심 = (최소 + 최대) * 0.5
	_로컬반경 = 최소.distance_to(최대) * 0.5 + 24.0
	_긴변 = maxf(최대.x - 최소.x, 최대.y - 최소.y)
	# 실면적(신발끈 공식). AABB 가 아니라 진짜 면적이어야 계단·L자에서 번짐이 안 부푼다.
	var 합:= 0.0
	for i in 점들.size():
		var a := 점들[i]
		var b := 점들[(i + 1) % 점들.size()]
		합 += a.x * b.y - b.x * a.y
	_면적 = maxf(absf(합) * 0.5, 1.0)


## 이 지형을 전체 색칠하는 데 필요한 명중 횟수.
## 96px(3칸)마다 한 발 — 작은 공중 발판은 1~2발, 큰 지형은 4~6발.
func 필요횟수() -> int:
	if 필요횟수_수동 > 0:
		return 필요횟수_수동
	return clampi(int(ceil(_긴변 / 96.0)), 1, 8)


# ── 셰이더 설치 ─────────────────────────────────────────────────────────────
## SS2D 는 채우기 메시에 `shape_material.fill_mesh_material` 을,
## 테두리 메시에 `SS2D_Material_Edge.material` 을 물려준다.
## 두 곳 모두에 같은 셰이더를 꽂아야 얼룩이 지형 전체(안쪽+테두리)에 이어진다.
##
## ⚠ shape_material 은 여러 지형이 공유하는 .tres 다. 그대로 건드리면 한 곳을 칠할 때
##   같은 재질을 쓰는 모든 지형이 같이 칠해진다 → **인스턴스마다 깊은 복사**해서 쓴다.
func _셰이더_설치() -> void:
	if shape_material == null:
		push_warning("스마트지형(%s): shape_material 이 비어 있음" % name)
		return
	var 전용: SS2D_Material_Shape = shape_material.duplicate(true)
	_셰이더들.clear()

	# 채우기
	var 채우기_텍스처: Texture2D = 전용.fill_textures[0] if not 전용.fill_textures.is_empty() else null
	_채움_텍스처들.clear()
	for t in 전용.fill_textures:
		if t != null:
			_채움_텍스처들.append(t)
	전용.fill_mesh_material = _셰이더_만들기(채우기_텍스처, false, false)
	if 전용.fill_mesh_material:
		_셰이더들.append(전용.fill_mesh_material)

	# 테두리 — 메타마다 짝이 되는 흰색 텍스처가 다르므로 각각 따로 만든다.
	for 메타 in 전용.get_all_edge_meta_materials():
		if 메타 == null or 메타.edge_material == null:
			continue
		# ★ 코너 전용 엣지는 건너뛴다.
		#   grass_v4 이후 타일셋은 "전방향 코너 전용" 메타를 하나 더 얹는데,
		#   그 메타의 기본 텍스처는 **안 보이는 투명 캐리어**(투명_256)다.
		#   캐리어는 흰색 짝이 있을 이유가 없고 화면에도 안 나오므로
		#   셰이더를 붙일 필요가 없다. 그냥 두면 지형 하나당 경고가 하나씩 떠서
		#   (쇼케이스 씬에서 144개) 진짜 경고를 덮어 버린다.
		#   판별은 이름이 아니라 **코너 텍스처를 들고 있는가**로 한다.
		if not 메타.edge_material.textures_corner_outer.is_empty():
			continue
		var 첫텍스처: Texture2D = 메타.edge_material.get_texture(0)
		var mat := _셰이더_만들기(첫텍스처, false, true)   # 테두리 = 먼저 물든다
		if mat:
			메타.edge_material.material = mat
			_셰이더들.append(mat)

	shape_material = 전용


## ★[2026-08-27 신규] 구워진 메시 중 **셰이더가 없는 것**에 하나씩 붙여 준다.
##
## ▣ 왜 메타가 아니라 메시 단위인가
##   `_셰이더_설치()` 는 `edge_material.material` 에 셰이더를 꽂는다 — 그러면 그 메타에서
##   나온 모든 쿼드가 **같은 흰색 짝**을 쓴다. 코너 메타는 쿼드마다 텍스처가 다르고
##   (corner_outer / corner_inner / 투명 캐리어) 기본 텍스처에 흰색 짝이 없어서
##   통째로 건너뛰어져 왔다.
##   구워진 `SS2D_Mesh` 는 **자기 텍스처를 하나만** 들고 있으므로, 여기서라면
##   그 텍스처의 흰색 짝으로 정확한 셰이더를 만들어 줄 수 있다.
##
## ▣ 안전장치
##   · 이미 셰이더가 붙은 메시는 건드리지 않는다(= 기존 동작 그대로).
##   · 흰색 짝이 없는 텍스처(투명 캐리어 등)는 조용히 건너뛴다. 경고를 띄우면
##     지형 하나당 여러 줄이 쏟아져 진짜 경고가 묻힌다.
##   · 새로 만든 셰이더도 `_셰이더들` 에 넣어야 `_유니폼_갱신()` 이 얼룩을 전달한다.
##   · 마지막에 `_renderer.render()` 를 다시 불러야 캔버스 아이템에 재질이 반영된다.
func _메시별_셰이더_보정() -> void:
	if _meshes.is_empty():
		return
	var 새로붙임 := 0
	for m in _meshes:
		if m == null or m.material != null:
			continue                      # 이미 붙었거나 빈 메시
		var tex: Texture2D = m.texture
		if tex == null:
			continue
		var mat := _셰이더_만들기_조용히(tex, not _채움_텍스처들.has(tex))
		if mat == null:
			continue                      # 흰색 짝이 없는 캐리어 — 화면에도 안 나온다
		m.material = mat
		_셰이더들.append(mat)
		새로붙임 += 1
	if 새로붙임 > 0:
		_유니폼_갱신()                     # 새 셰이더에도 지금까지의 얼룩을 알려 준다
		_renderer.render(_meshes)          # 캔버스 아이템에 재질을 다시 밀어 넣는다


## `_셰이더_만들기` 와 같지만 **경고를 안 띄운다.**
## 메시별 보정은 조용히 지나가는 게 정상 동작이라 경고가 소음이 된다.
func _셰이더_만들기_조용히(기본: Texture2D, 테두리: bool) -> ShaderMaterial:
	return _셰이더_만들기(기본, true, 테두리)


## 이 조각이 든 아트에 **반대색 짝**을 물려 페인트 셰이더를 만든다.
##
## ★[2026-08-29 개정] 예전에는 짝을 못 찾으면 **셰이더를 안 붙이고 null 을 돌려줬다.**
##   그러면 총에 맞아 `현재상태` 는 바뀌는데 그 조각만 원래 색으로 남는다 —
##   "몸에 닿은 지형이 내 색과 다르면 즉사" 가 규칙인 게임에서 **화면이 거짓말을 한다.**
##   실제로 벽돌 Template 3 종이 `brick_v2_opaque/black/edge_top_thin.png` 의 흰색 짝이
##   없다는 이유로 윗면 테두리만 검정으로 남아 있었다 (test_사방재질_칠하기 실패 3).
##   → 이제 짝이 없으면 **셰이더 안에서 밝기를 뒤집어** 쓴다(`alt_invert`). 색은 항상 바뀐다.
##   진짜 아트가 나중에 들어오면 `_짝_찾기()` 가 파일을 먼저 집으므로 저절로 교체된다.
func _셰이더_만들기(기본: Texture2D, 조용히: bool = false, 테두리: bool = false) -> ShaderMaterial:
	if 기본 == null:
		return null
	# 투명 캐리어는 화면에 안 나온다 → 셰이더를 붙일 이유가 없다.
	if _투명_캐리어인가(기본):
		return null
	var 짝 := _짝_찾기(기본)
	var mat := ShaderMaterial.new()
	mat.shader = 페인트_셰이더
	mat.set_shader_parameter("base_is_white", bool(짝["흰색이_기본"]))
	mat.set_shader_parameter("blob_wobble", 얼룩_일그러짐)
	# 테두리 쪽 얼룩만 크게 그린다 = 가장자리가 먼저 잠기고 안쪽이 따라온다.
	mat.set_shader_parameter("r_scale", 테두리_선행 if 테두리 else 1.0)
	if 짝["짝"] == null:
		mat.set_shader_parameter("alt_invert", true)
		if not 조용히:
			# 경고는 남긴다 — 돌아가긴 하지만 **진짜 아트가 빠진 상태**다.
			push_warning("스마트지형(%s): '%s' 의 반대색 짝이 없어 밝기 반전으로 대체함"
				% [name, 기본.resource_path])
	else:
		mat.set_shader_parameter("alt_tex", 짝["짝"])
	return mat


## 투명 캐리어인가 — 코너 메타가 드는, 화면에 안 나오는 텍스처.
## 판별은 파일명 접두어 `투명_` 로 한다. `tools/test_사방재질_칠하기.gd` 와 **같은 규칙**이다
## (두 곳이 어긋나면 검사가 거짓말을 한다).
func _투명_캐리어인가(tex: Texture2D) -> bool:
	return tex != null and tex.resource_path.get_file().begins_with("투명_")


## 기본 아트의 **반대색 짝**을 찾는다. 흑→백뿐 아니라 **백→흑도** 찾는다.
##
## 반환 { "짝": Texture2D | null, "흰색이_기본": bool }
##   · 짝 == null  → 파일이 없다. 셰이더가 밝기 반전으로 대신 만든다.
##   · 흰색이_기본 → 이 조각이 **흰 아트를 기본으로 들었는가**. 셰이더의 검정/흰색
##     매핑이 이 값으로 뒤집힌다. 흰색 Template 이 이 위에 얹힌다.
##
## ▣ 왜 양방향이 필요한가 (2026-08-29)
##   흑백이 공존하는 게임인데 코드에는 "검정이 원본" 이라는 가정이 박혀 있었다.
##   흰 아트를 기본으로 든 지형(흰색 Template)은 `black → white` 규칙에 아예 안 걸려
##   셰이더가 안 붙고, 그래서 **검정으로 칠할 수가 없었다.**
##
## ▣ 규칙 세 가지를 순서대로 본다
##   1) 파일명 토큰   black_edge.png ↔ white_edge.png
##                    brick_black_seamless_341x307.png ↔ brick_white_seamless_341x307.png
##   2) 폴더 이름     .../brick_v2/black/edge_top.png ↔ .../brick_v2/white/edge_top.png
##   3) 둘 다 안 걸리면 짝 없음 → 반전 대체. 방향을 모르니 검정 기본으로 본다.
##
## ▣ 1) 이 예전보다 넓어졌다
##   예전에는 `begins_with("black_")` 만 봤다. 그래서 옛 이름
##   `brick_black_seamless_341x307.png`(벽돌 계단 씬이 쓰는 채움)이 규칙 밖으로 빠졌다.
##   `_` 로 끊어 **정확히 black/white 인 토막**을 보면 두 이름 모두 걸린다.
func _짝_찾기(기본: Texture2D) -> Dictionary:
	var 없음 := { "짝": null, "흰색이_기본": false }
	var 경로 := 기본.resource_path
	if 경로.is_empty():
		return 없음
	var 파일 := 경로.get_file()

	# 1) 파일명 토큰
	var 조각 := 파일.get_basename().split("_")
	for i in 조각.size():
		if 조각[i] != "black" and 조각[i] != "white":
			continue
		var 흰색기본 := 조각[i] == "white"
		var 반대 := 조각.duplicate()
		반대[i] = "black" if 흰색기본 else "white"
		var 짝경로 := "%s/%s.%s" % [경로.get_base_dir(), "_".join(반대), 파일.get_extension()]
		if ResourceLoader.exists(짝경로):
			return { "짝": load(짝경로) as Texture2D, "흰색이_기본": 흰색기본 }
		return { "짝": null, "흰색이_기본": 흰색기본 }

	# 2) 폴더 이름 — 마지막 폴더가 정확히 black / white 일 때만.
	#    경로 중간에 우연히 black 이 들어간 폴더를 건드리지 않으려고 마지막 폴더만 본다.
	var 폴더 := 경로.get_base_dir()
	var 폴더명 := 폴더.get_file()
	if 폴더명 == "black" or 폴더명 == "white":
		var 흰색기본2 := 폴더명 == "white"
		var 반대폴더 := "black" if 흰색기본2 else "white"
		var 짝경로2 := "%s/%s/%s" % [폴더.get_base_dir(), 반대폴더, 파일]
		if ResourceLoader.exists(짝경로2):
			return { "짝": load(짝경로2) as Texture2D, "흰색이_기본": 흰색기본2 }
		return { "짝": null, "흰색이_기본": 흰색기본2 }

	return 없음


# ── 페인트코어와의 약속 ─────────────────────────────────────────────────────
func 현재색() -> int:
	match 현재상태:
		상태.검정: return ColorDefs.BLACK
		상태.흰색: return ColorDefs.WHITE
		상태.회색: return ColorDefs.GRAY
	return -1


## 이 지형을 밟았을 때 죽는 색인가. (무색·회색은 누구에게나 안전)
func 반대색인가(플레이어색: int) -> bool:
	if 현재상태 == 상태.검정:
		return 플레이어색 == ColorDefs.WHITE
	if 현재상태 == 상태.흰색:
		return 플레이어색 == ColorDefs.BLACK
	return false


func 밟을_수_있나() -> bool:
	return not (현재상태 == 상태.무색 and 무색일때_통과 and 칠하기_허용)


## 총알 명중. 반환값은 페인트코어가 규칙 판정에 쓴다.
func 명중(색: int, 월드좌표: Vector2) -> String:
	if not 칠하기_허용:
		return "blocked"

	match 현재상태:
		상태.회색:
			return "blocked"                            # 장애물 상호작용으로 생긴 회색은 총알로 못 덮는다.
		상태.검정, 상태.흰색:
			if 색 == 현재색():
				return "wasted"                         # 같은 색 덧칠 = 낭비 → 환급
			# 플레이어 페인트끼리는 섞지 않고 마지막 색이 기존 색을 그대로 덮는다.
			_덮어쓰기(상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색, to_local(월드좌표))
			_충돌레이어_갱신()
			_유니폼_갱신()
			return "painted"
		_:
			return _무색_명중(색, 월드좌표)


func _무색_명중(색: int, 월드좌표: Vector2) -> String:
	_진행색 = 색
	_진행.명중(색, 필요횟수())
	_맞은횟수 = _진행.전체횟수()
	_젖음 = 1.0
	# 0 에서 자라기 시작한다. 목표는 바로 아래에서 진행률로 다시 잡는다.
	_시드_추가(to_local(월드좌표), 부분_반지름, 색, false)
	_목표반지름_갱신()

	# 두 색의 부분 얼룩이 함께 있으면 어느 쪽도 전체 색칠로 승격되지 않는다.
	if _진행.완성가능(색, 필요횟수()):
		_전체_즉시(상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색, false)
		_충돌레이어_갱신()
		_유니폼_갱신()
		return "painted"

	_유니폼_갱신()
	return "progress"


## 수동/자동 회수 — 무색으로 되돌린다. 회색은 되돌릴 수 없다.
func 되돌리기() -> bool:
	if 현재상태 == 상태.회색 or not 칠하기_허용:
		return false
	_원래대로()
	return true


## ★[2026-08-29 신규] "원래" 는 무색이 아니라 **`시작상태`** 다.
##
## ▣ 왜 고쳤나 — 흰색 Template 이 생기면서 드러난 구멍
##   예전에는 회수·사망 리셋이 무조건 `무색` 으로 돌렸다. `시작상태 = 흰색` 인 지형을
##   플레이어가 검정으로 덮은 뒤 죽으면, 리셋이 그것을 **흰색이 아니라 무색으로** 돌린다.
##   → 흰 발판이 통째로 사라진 채로 스테이지가 다시 시작된다(디자인이 조용히 무너진다).
##   회수의 뜻은 "내가 칠한 것을 지운다" 이지 "레벨이 원래 갖고 있던 색을 뺏는다" 가 아니다.
##
## ⚠ 기존 씬은 전부 `시작상태 = 무색` 이라 동작이 하나도 안 바뀐다.
##   색을 갖고 태어난 지형(흰색 Template · 고정색 함정)만 제 색으로 돌아온다.
func _원래대로() -> void:
	_맞은횟수 = 0
	_진행.비우기()
	_시드_비우기()
	_젖음 = 0.0
	if 시작상태 == 상태.무색:
		현재상태 = 상태.무색
		_충돌레이어_갱신()
		_유니폼_갱신()
		return
	_전체_즉시(시작상태)                  # 시드까지 다시 찍어야 화면도 제 색으로 돌아온다
	_충돌레이어_갱신()
	_유니폼_갱신()


## 사망/스테이지 리셋 전용 — 되돌리기() 와 달리 회색이어도 강제로 무색화한다.
## (규칙 3의 "회색은 수동 회수 불가"는 플레이 중 E 회수에만 적용되고,
##  사망 리스폰은 스테이지 재시도이므로 회색도 포함해 전부 초기화돼야 한다.)
func 강제_초기화() -> void:
	_원래대로()


# ── 상태 전이 ───────────────────────────────────────────────────────────────
func _회색으로() -> void:
	현재상태 = 상태.회색
	_시드_비우기()
	# 회색은 지형 전체를 덮는 얼룩 하나로 표현 (색 인덱스 2 = 셰이더의 gray)
	_시드_추가(_중심, _로컬반경 * (1.0 + 얼룩_일그러짐 + 0.02), ColorDefs.GRAY)
	_젖음 = 1.0
	_충돌레이어_갱신()
	_유니폼_갱신()


## 지형 전체를 한 색으로 만든다.
##   즉시 = true  → 그 자리에서 덮는다 (시작상태·회수 복귀·강제 초기화)
##   즉시 = false → **마지막 한 방** 연출. 지금까지 번진 크기에서 이어서 전체로 퍼진다.
## `기준점` 을 주면 그 자리에서부터 퍼진다(맞은 자리). 안 주면 지형 중심.
func _전체_즉시(새상태: 상태, 즉시: bool = true, 기준점: Variant = null) -> void:
	현재상태 = 새상태
	_진행.비우기()
	var 이어받을 := _최대_현재반지름()          # 시드를 지우기 전에 재둔다
	_시드_비우기()
	var 색 := ColorDefs.BLACK
	match 새상태:
		상태.흰색: 색 = ColorDefs.WHITE
		상태.회색: 색 = ColorDefs.GRAY
	_진행색 = 색
	_맞은횟수 = 필요횟수()
	# 검정은 기본 아트가 이미 검정이라 얼룩을 안 찍어도 같은 그림이지만,
	# "칠해졌다"는 걸 셰이더 젖음 효과로 보여주기 위해 똑같이 찍는다.
	var 중심: Vector2 = 기준점 if 기준점 is Vector2 else _중심
	# 전체를 덮으려면 중심에서 잰 반경으로는 모자란다(맞은 자리가 구석일 수 있다).
	# ★얼룩이 일그러지는 만큼 여유를 더 준다 — 안 그러면 오목한 쪽 구석이
	#   안 칠해진 채 남아 "다 칠했는데 검은 자국"이 생긴다.
	var 반경 := (_로컬반경 + 중심.distance_to(_중심)) * (1.0 + 얼룩_일그러짐 + 0.02)
	_시드_추가(중심, 반경, 색, 즉시, 이어받을)


## 이미 칠해진 지형을 반대색으로 덮는다 — **옛 얼룩을 지우지 않고 그 위로 번지게** 한다.
##
## ▣ 왜 `_전체_즉시` 를 안 쓰나
##   그쪽은 시드를 비우고 새 얼룩 하나만 남긴다. 그러면 새 얼룩이 자라는 동안
##   나머지가 **기본 아트**(= 안 칠한 색)로 보인다. 흰 지형을 검정으로 덮는데
##   한순간 원래 색이 드러나는 셈이라, 덮어쓰기가 아니라 지우기처럼 보인다.
##   셰이더는 시드를 배열 순서대로 겹쳐 칠하므로, 옛 얼룩을 그냥 두고 새 얼룩을
##   **뒤에 붙이면** 새 색이 옛 색 위를 쓸고 지나간다.
func _덮어쓰기(새상태: 상태, 기준점: Vector2) -> void:
	현재상태 = 새상태
	_진행.비우기()
	var 색 := ColorDefs.WHITE if 새상태 == 상태.흰색 else ColorDefs.BLACK
	_진행색 = 색
	_맞은횟수 = 필요횟수()
	var 반경 := (_로컬반경 + 기준점.distance_to(_중심)) * (1.0 + 얼룩_일그러짐 + 0.02)
	_시드_추가(기준점, 반경, 색, false, 부분_반지름 * 0.4)
	_젖음 = 1.0


func _충돌레이어_갱신() -> void:
	var 유령 := not 밟을_수_있나()
	var 새레이어 := 유령_레이어비트 if 유령 else 1
	var 폴리 := get_collision_polygon_node()
	if 폴리 == null:
		return
	var 바디 := 폴리.get_parent() as CollisionObject2D
	if 바디 and 바디.collision_layer != 새레이어:
		바디.set_deferred("collision_layer", 새레이어)
	# 유령은 반투명 — "아직 실체가 아니다"를 한눈에 (v3 PaintPlatform 과 같은 문법)
	modulate.a = 0.42 if 유령 else 1.0


# ── 시드 관리 ───────────────────────────────────────────────────────────────
func _시드_비우기() -> void:
	_시드 = PackedVector2Array()
	_반지름 = PackedFloat32Array()
	_목표 = PackedFloat32Array()
	_흘러내림 = PackedFloat32Array()
	_흘림상한 = PackedFloat32Array()
	_세기 = PackedFloat32Array()
	_색 = PackedInt32Array()


## 얼룩 하나를 찍는다.
##   즉시 = true  → 처음부터 목표 크기로 (시작상태·회수 복귀처럼 **연출이 없어야** 하는 자리)
##   즉시 = false → `시작반지름` 에서 목표까지 자란다 (총에 맞았을 때)
func _시드_추가(로컬: Vector2, 목표반지름: float, 색: int, 즉시: bool = true,
		시작반지름: float = 0.0) -> void:
	if _시드.size() >= 최대_시드:
		_시드.remove_at(0)
		_반지름.remove_at(0)
		_목표.remove_at(0)
		_흘러내림.remove_at(0)
		_흘림상한.remove_at(0)
		_세기.remove_at(0)
		_색.remove_at(0)
	_시드.append(로컬)
	_반지름.append(목표반지름 if 즉시 else 시작반지름)
	_목표.append(목표반지름)
	_흘러내림.append(0.0)
	_흘림상한.append(0.0 if 즉시 else 흘러내림_길이)
	_세기.append(1.0)
	_색.append(색)


## 지금 찍혀 있는 얼룩 중 가장 큰 반지름. 완성 연출을 여기서 이어 시작한다.
func _최대_현재반지름() -> float:
	var 큰 := 0.0
	for r in _반지름:
		큰 = maxf(큰, r)
	return 큰


## 진행률에 맞춰 모든 얼룩의 **목표** 반지름을 다시 잡는다.
## `tile_paint_map.gd _목표반지름_갱신()` 과 같은 공식을 px 좌표로 옮긴 것이다.
##   · 초반 = 면적 비례 원 → 조금씩 스며드는 느낌
##     (n 개 얼룩이 지형 면적의 `진행` 만큼을 나눠 덮는 반지름)
##   · 끝에서 pow(진행, 5) 로 전체 반지름에 확 붙는다 → "마지막 한 방" 의 쾌감
func _목표반지름_갱신() -> void:
	var n := _시드.size()
	if n == 0:
		return
	var 색진행 := maxi(_진행.횟수(ColorDefs.BLACK), _진행.횟수(ColorDefs.WHITE))
	var 진행 := clampf(float(색진행) / float(maxi(필요횟수(), 1)), 0.0, 1.0)
	var 면적반지름 := sqrt(maxf(진행, 0.0001) * _면적 / (PI * float(n)))
	var 목표 := lerpf(면적반지름, _로컬반경, pow(진행, 5.0))
	# 한 발만 맞아도 눈에 보여야 한다 — 부분 반지름보다 작아지지 않게 바닥을 깐다.
	목표 = clampf(목표, 부분_반지름, _로컬반경)
	for i in n:
		_목표[i] = 목표


# ── 부분 색칠 감쇠 (기획: "서서히 흐려지다 자동으로 회수") ────────────────────
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# ★[2026-08-27] 구워진 메시 중 셰이더가 안 붙은 것을 메꾼다 (도형님 제보)
	#   "코너 부분을 보면 지형 플랫폼들이 전부 안 칠해져."
	#   `_셰이더_설치()` 는 **엣지 메타 단위**로 셰이더를 만든다. 그런데 코너 전용 메타는
	#   기본 텍스처가 투명 캐리어라 흰색 짝이 없어 통째로 건너뛴다 →
	#   그 메타에서 나온 **코너 쿼드**는 셰이더 없이 검정 그대로 남는다.
	#   (잔디 SOLID 실측: 보이는 메시 17 개 중 13 개만 셰이더. 코너 4 개가 안 칠해졌다)
	#   → 메타가 아니라 **구워진 메시 하나하나**를 보고, 자기 텍스처의 흰색 짝으로
	#     셰이더를 따로 만들어 붙인다. 아트를 하나도 안 건드리고 고칠 수 있다.
	#   메시 개수가 바뀌면(모양 편집·재굽기) 다시 한 번 훑는다.
	if _meshes.size() != _보정한_메시수:
		_보정한_메시수 = _meshes.size()
		_메시별_셰이더_보정()

	var 갱신 := false

	if _젖음 > 0.0:
		_젖음 = maxf(_젖음 - delta * 1.4, 0.0)
		갱신 = true

	# ── 잉크 번짐 ──────────────────────────────────────────────────────────
	# 지수 감쇠 = 처음엔 빠르게 퍼지고 끝에서 살짝 붙는 잉크 느낌.
	# 상수 0.0008 은 타일맵(`tile_paint_map.gd _process`)이 쓰던 값 그대로다 —
	# 두 시스템의 번짐 속도가 다르면 같은 게임인데 스테이지마다 손맛이 달라진다.
	for i in _반지름.size():
		var r: float = _반지름[i]
		var t: float = _목표[i] if i < _목표.size() else r
		if absf(t - r) > 0.05:
			_반지름[i] = lerpf(r, t, 1.0 - pow(번짐_지수, delta))
			갱신 = true
		else:
			_반지름[i] = t
		# 흘러내림은 얼룩이 어느 정도 자란 뒤부터 시작한다 (물감이 고여야 흐른다).
		if i < _흘림상한.size() and _흘림상한[i] > 0.0:
			# 작은 얼룩은 짧게, 다 자란 얼룩은 상한만큼 흐른다.
			var 최대 := _흘림상한[i] * clampf(_반지름[i] / maxf(부분_반지름, 1.0), 0.0, 1.0)
			if _흘러내림[i] < 최대 - 0.5:
				_흘러내림[i] = minf(_흘러내림[i] + 흘러내림_속도 * delta, 최대)
				갱신 = true

	# 흑·백은 각자 4초를 유지한 뒤 1초 동안 흐려지며, 한쪽이 남아 조건을 채우면 그때 완성된다.
	if 현재상태 == 상태.무색 and _진행.전체횟수() > 0:
		var 변화: Dictionary = _진행.진행(delta, 필요횟수())
		for i in _세기.size():
			_세기[i] = _진행.알파(_색[i])
		for 만료색 in 변화["만료"]:
			_색_시드_지우기(int(만료색))
			if _코어 and _코어.has_method("부분_자동회수"):
				_코어.부분_자동회수(self, int(변화["만료"][만료색]))
		_맞은횟수 = _진행.전체횟수()
		var 완성색: int = 변화["완성색"]
		if 완성색 >= 0:
			# 시간이 지나 저절로 완성된 경우도 **퍼지는 연출**을 준다 (즉시 = false).
			_전체_즉시(상태.검정 if 완성색 == ColorDefs.BLACK else 상태.흰색, false)
			_충돌레이어_갱신()
		갱신 = true

	if 갱신:
		_유니폼_갱신()


func _색_시드_지우기(색: int) -> void:
	# 다른 색의 부분 칠은 남겨야 하므로 만료된 색의 시드만 뒤에서부터 제거한다.
	for i in range(_색.size() - 1, -1, -1):
		if _색[i] != 색:
			continue
		_시드.remove_at(i)
		_반지름.remove_at(i)
		_목표.remove_at(i)
		_흘러내림.remove_at(i)
		_흘림상한.remove_at(i)
		_세기.remove_at(i)
		_색.remove_at(i)


func _유니폼_갱신() -> void:
	if _셰이더들.is_empty():
		return
	# 셰이더 배열은 길이가 고정이라 남는 칸을 0 으로 채워 보낸다.
	var 시드 := PackedVector2Array()
	var 반지름 := PackedFloat32Array()
	var 세기 := PackedFloat32Array()
	var 색 := PackedInt32Array()
	var 흘러내림 := PackedFloat32Array()
	for i in 최대_시드:
		시드.append(_시드[i] if i < _시드.size() else Vector2.ZERO)
		반지름.append(_반지름[i] if i < _반지름.size() else 0.0)
		세기.append(_세기[i] if i < _세기.size() else 0.0)
		색.append(_색[i] if i < _색.size() else 0)
		흘러내림.append(_흘러내림[i] if i < _흘러내림.size() else 0.0)

	for mat in _셰이더들:
		mat.set_shader_parameter("seed_count", _시드.size())
		mat.set_shader_parameter("seeds", 시드)
		mat.set_shader_parameter("seed_r", 반지름)
		mat.set_shader_parameter("seed_a", 세기)
		mat.set_shader_parameter("seed_c", 색)
		mat.set_shader_parameter("seed_d", 흘러내림)
		mat.set_shader_parameter("wet", _젖음)
