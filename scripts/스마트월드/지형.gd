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

# ── 내부 상태 ──────────────────────────────────────────────────────────────
var 현재상태: 상태 = 상태.무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _진행 := 페인트진행_S.new()

var _시드: PackedVector2Array = PackedVector2Array()      # 노드 로컬 px
var _반지름: PackedFloat32Array = PackedFloat32Array()
var _세기: PackedFloat32Array = PackedFloat32Array()
var _색: PackedInt32Array = PackedInt32Array()

var _젖음: float = 0.0
var _셰이더들: Array[ShaderMaterial] = []
var _로컬반경: float = 200.0                 ## 전체를 덮는 데 필요한 반지름 (자동 계산)
var _중심: Vector2 = Vector2.ZERO            ## 로컬 AABB 중심 (전체 색칠 얼룩의 기준점)
var _긴변: float = 200.0                     ## 로컬 AABB 의 긴 변 — 필요횟수 계산에 쓴다
var _코어: 페인트코어 = null

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
	# 그래서 **여기서 비운다.** 점 배열은 인스턴스마다 제대로 저장되므로, 비워 두면
	# `super()` 안의 첫 `force_update()` 가 그 점으로 새로 굽는다.
	# 에디터에서도 비운다 — 작업자가 Template 을 복제해 점을 끌었을 때 크기가 안 변하는
	# 그 함정(README_지형찍기 작업자들이 실제로 겪은 것)이 같은 원인이기 때문이다.
	_meshes.clear()

	super()                                   # ★SS2D 의 렌더러 초기화를 반드시 먼저
	if Engine.is_editor_hint():
		return
	add_to_group("칠할수있음")
	add_to_group("스마트지형")
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
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
	전용.fill_mesh_material = _셰이더_만들기(채우기_텍스처)
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
		var mat := _셰이더_만들기(첫텍스처)
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
		var mat := _셰이더_만들기_조용히(tex)
		if mat == null:
			continue                      # 흰색 짝이 없는 캐리어 — 화면에도 안 나온다
		m.material = mat
		_셰이더들.append(mat)
		새로붙임 += 1
	if 새로붙임 > 0:
		_유니폼_갱신()                     # 새 셰이더에도 지금까지의 얼룩을 알려 준다
		_renderer.render(_meshes)          # 캔버스 아이템에 재질을 다시 밀어 넣는다


## `_셰이더_만들기` 와 같지만 **경고를 안 띄운다.**
## 위 보정은 "짝이 없으면 그냥 넘어가는" 게 정상 동작이라 경고가 소음이 된다.
func _셰이더_만들기_조용히(검정: Texture2D) -> ShaderMaterial:
	var 흰색 := _짝_텍스처(검정)
	if 흰색 == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = 페인트_셰이더
	mat.set_shader_parameter("alt_tex", 흰색)
	return mat


## black_xxx.png 에 대응하는 white_xxx.png 를 찾아 셰이더를 만든다.
func _셰이더_만들기(검정: Texture2D) -> ShaderMaterial:
	if 검정 == null:
		return null
	var 흰색 := _짝_텍스처(검정)
	if 흰색 == null:
		# 짝을 못 찾으면 셰이더를 안 붙인다 (원본 그대로 그려서 최소한 보이게)
		push_warning("스마트지형(%s): '%s' 의 흰색 짝을 못 찾음" % [name, 검정.resource_path])
		return null
	var mat := ShaderMaterial.new()
	mat.shader = 페인트_셰이더
	mat.set_shader_parameter("alt_tex", 흰색)
	return mat


## 검정 텍스처의 흰색 짝을 찾는다. 규칙 두 가지를 **순서대로** 시도한다.
##
##   1) 파일명 규칙 (기존)   .../black_grass_edge.png  ->  .../white_grass_edge.png
##   2) 폴더 규칙   (신규)   .../grass_v4/black/edge_top.png
##                            -> .../grass_v4/white/edge_top.png
##
## ▣ 2번을 추가한 이유
##   grass_v4 이후의 고해상도 타일셋은 재질 폴더 밑에 black/ white/ 를 나눠 담는다
##   (파일이 재질당 32장이라 접두어로 구분하면 한 폴더가 감당이 안 된다).
##   그 구조에서는 파일명이 "black_" 로 시작하지 않아 1번 규칙이 실패하고,
##   셰이더가 아예 안 붙어서 **지형이 총에 맞아도 색이 안 변한다**.
##   "내 색과 다른 지형에 닿으면 즉사" 가 핵심 규칙인 게임에서 치명적이라 넓혔다.
##
## ▣ 하위호환
##   1번을 먼저 보므로 기존 머티리얼 5개는 예전과 완전히 같은 경로로 짝을 찾는다.
##   1번이 실패할 때만 2번을 추가로 시도하므로, 예전에 null 이던 경우만 값이 생긴다.
func _짝_텍스처(검정: Texture2D) -> Texture2D:
	var 경로 := 검정.resource_path
	if 경로.is_empty():
		return null

	# 1) 파일명 규칙 — 기존 동작. 여기서 찾으면 예전과 동일하다.
	if 경로.get_file().begins_with("black_"):
		var 짝 := 경로.get_base_dir() + "/" + 경로.get_file().replace("black_", "white_")
		if ResourceLoader.exists(짝):
			return load(짝) as Texture2D
		return null

	# 2) 폴더 규칙 — 경로 마지막 폴더가 정확히 "black" 일 때만 "white" 로 바꾼다.
	#    경로 중간에 우연히 black 이 들어간 폴더를 건드리지 않으려고 마지막 폴더만 본다.
	var 폴더 := 경로.get_base_dir()
	if 폴더.get_file() != "black":
		return null
	var 짝2 := 폴더.get_base_dir() + "/white/" + 경로.get_file()
	if not ResourceLoader.exists(짝2):
		return null
	return load(짝2) as Texture2D


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
			_전체_즉시(상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색)
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
	_시드_추가(to_local(월드좌표), 부분_반지름, 색)

	# 두 색의 부분 얼룩이 함께 있으면 어느 쪽도 전체 색칠로 승격되지 않는다.
	if _진행.완성가능(색, 필요횟수()):
		_전체_즉시(상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색)
		_충돌레이어_갱신()
		_유니폼_갱신()
		return "painted"

	_유니폼_갱신()
	return "progress"


## 수동/자동 회수 — 무색으로 되돌린다. 회색은 되돌릴 수 없다.
func 되돌리기() -> bool:
	if 현재상태 == 상태.회색 or not 칠하기_허용:
		return false
	현재상태 = 상태.무색
	_맞은횟수 = 0
	_진행.비우기()
	_시드_비우기()
	_젖음 = 0.0
	_충돌레이어_갱신()
	_유니폼_갱신()
	return true


## 사망/스테이지 리셋 전용 — 되돌리기() 와 달리 회색이어도 강제로 무색화한다.
## (규칙 3의 "회색은 수동 회수 불가"는 플레이 중 E 회수에만 적용되고,
##  사망 리스폰은 스테이지 재시도이므로 회색도 포함해 전부 초기화돼야 한다.)
func 강제_초기화() -> void:
	현재상태 = 상태.무색
	_맞은횟수 = 0
	_진행.비우기()
	_시드_비우기()
	_젖음 = 0.0
	_충돌레이어_갱신()
	_유니폼_갱신()


# ── 상태 전이 ───────────────────────────────────────────────────────────────
func _회색으로() -> void:
	현재상태 = 상태.회색
	_시드_비우기()
	# 회색은 지형 전체를 덮는 얼룩 하나로 표현 (색 인덱스 2 = 셰이더의 gray)
	_시드_추가(_중심, _로컬반경, ColorDefs.GRAY)
	_젖음 = 1.0
	_충돌레이어_갱신()
	_유니폼_갱신()


func _전체_즉시(새상태: 상태) -> void:
	현재상태 = 새상태
	_진행.비우기()
	_시드_비우기()
	var 색 := ColorDefs.BLACK
	match 새상태:
		상태.흰색: 색 = ColorDefs.WHITE
		상태.회색: 색 = ColorDefs.GRAY
	_진행색 = 색
	_맞은횟수 = 필요횟수()
	# 검정은 기본 아트가 이미 검정이라 얼룩을 안 찍어도 같은 그림이지만,
	# "칠해졌다"는 걸 셰이더 젖음 효과로 보여주기 위해 똑같이 찍는다.
	_시드_추가(_중심, _로컬반경, 색)


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
	_세기 = PackedFloat32Array()
	_색 = PackedInt32Array()


func _시드_추가(로컬: Vector2, 반지름: float, 색: int) -> void:
	if _시드.size() >= 최대_시드:
		_시드.remove_at(0)
		_반지름.remove_at(0)
		_세기.remove_at(0)
		_색.remove_at(0)
	_시드.append(로컬)
	_반지름.append(반지름)
	_세기.append(1.0)
	_색.append(색)


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

	# 흑·백은 각자 4초를 유지한 뒤 1초 동안 흐려지며, 한쪽이 남아 조건을 채우면 그때 완성된다.
	if 현재상태 == 상태.무색 and _진행.전체횟수() > 0:
		var 변화: Dictionary = _진행.진행(delta, 필요횟수())
		for i in _세기.size():
			_세기[i] = _진행.알파(_색[i])
		for 만료색 in 변화["만료"]:
			_색_시드_지우기(int(만료색))
			if _코어:
				_코어.부분_자동회수(self, int(변화["만료"][만료색]))
		_맞은횟수 = _진행.전체횟수()
		var 완성색: int = 변화["완성색"]
		if 완성색 >= 0:
			_전체_즉시(상태.검정 if 완성색 == ColorDefs.BLACK else 상태.흰색)
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
	for i in 최대_시드:
		시드.append(_시드[i] if i < _시드.size() else Vector2.ZERO)
		반지름.append(_반지름[i] if i < _반지름.size() else 0.0)
		세기.append(_세기[i] if i < _세기.size() else 0.0)
		색.append(_색[i] if i < _색.size() else 0)

	for mat in _셰이더들:
		mat.set_shader_parameter("seed_count", _시드.size())
		mat.set_shader_parameter("seeds", 시드)
		mat.set_shader_parameter("seed_r", 반지름)
		mat.set_shader_parameter("seed_a", 세기)
		mat.set_shader_parameter("seed_c", 색)
		mat.set_shader_parameter("wet", _젖음)
