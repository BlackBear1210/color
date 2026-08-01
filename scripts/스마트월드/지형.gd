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
##   회색 : 반대색을 덮어써서 섞인 상태. 누구나 안전하지만 **다시 못 칠하고 수동 회수도 안 됨**.
##
## ▣ 부분 색칠 / 전체 색칠
##   한 발로 다 안 덮이는 크기면 맞은 자리만 얼룩진다(부분).
##   `필요횟수()` 만큼 같은 색을 맞히면 전체 색칠로 승격된다.
##   부분 색칠은 `부분_유지시간` 동안 새 명중이 없으면 스스로 흐려지고,
##   다 사라진 순간 페인트코어에 발수를 돌려준다(기획: "서서히 흐려지다 자동 회수").
## ============================================================================
class_name 스마트지형

const 페인트_셰이더 := preload("res://shaders/지형_페인트.gdshader")
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
@export var 부분_감쇠시간: float = 1.6

# ── 내부 상태 ──────────────────────────────────────────────────────────────
var 현재상태: 상태 = 상태.무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK

var _시드: PackedVector2Array = PackedVector2Array()      # 노드 로컬 px
var _반지름: PackedFloat32Array = PackedFloat32Array()
var _세기: PackedFloat32Array = PackedFloat32Array()
var _색: PackedInt32Array = PackedInt32Array()

var _마지막명중: float = 0.0
var _젖음: float = 0.0
var _감쇠중: bool = false
var _셰이더들: Array[ShaderMaterial] = []
var _로컬반경: float = 200.0                 ## 전체를 덮는 데 필요한 반지름 (자동 계산)
var _중심: Vector2 = Vector2.ZERO            ## 로컬 AABB 중심 (전체 색칠 얼룩의 기준점)
var _긴변: float = 200.0                     ## 로컬 AABB 의 긴 변 — 필요횟수 계산에 쓴다
var _코어: 페인트코어 = null


func _ready() -> void:
	super()                                   # ★SS2D 의 렌더러 초기화를 반드시 먼저
	if Engine.is_editor_hint():
		return
	add_to_group("칠할수있음")
	add_to_group("스마트지형")
	_코어 = get_tree().get_first_node_in_group("페인트코어") as 페인트코어
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
		var 첫텍스처: Texture2D = 메타.edge_material.get_texture(0)
		var mat := _셰이더_만들기(첫텍스처)
		if mat:
			메타.edge_material.material = mat
			_셰이더들.append(mat)

	shape_material = 전용


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


func _짝_텍스처(검정: Texture2D) -> Texture2D:
	var 경로 := 검정.resource_path
	if 경로.is_empty() or not 경로.get_file().begins_with("black_"):
		return null
	var 짝 := 경로.get_base_dir() + "/" + 경로.get_file().replace("black_", "white_")
	if not ResourceLoader.exists(짝):
		return null
	return load(짝) as Texture2D


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
			return "blocked"                            # 규칙 3: 회색은 끝난 상태
		상태.검정, 상태.흰색:
			if 색 == 현재색():
				return "wasted"                         # 같은 색 덧칠 = 낭비 → 환급
			_회색으로()                                  # 규칙 2: 반대색 → 회색
			return "mixed_gray"
		_:
			return _무색_명중(색, 월드좌표)


func _무색_명중(색: int, 월드좌표: Vector2) -> String:
	# 진행 중이던 색과 다른 색이 오면 진행도를 새 색으로 리셋한다.
	# (기획: "서로 다른 두 색이 부분 색칠 상태면 전체 색칠이 될 수 없다")
	if _맞은횟수 > 0 and _진행색 != 색:
		_시드_비우기()
		_맞은횟수 = 0
	_진행색 = 색
	_맞은횟수 += 1
	_마지막명중 = 0.0
	_젖음 = 1.0
	_감쇠중 = false

	if _맞은횟수 >= 필요횟수():
		_전체_즉시(상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색)
		_충돌레이어_갱신()
		_유니폼_갱신()
		return "painted"

	_시드_추가(to_local(월드좌표), 부분_반지름, 색)
	_유니폼_갱신()
	return "progress"


## 수동/자동 회수 — 무색으로 되돌린다. 회색은 되돌릴 수 없다.
func 되돌리기() -> bool:
	if 현재상태 == 상태.회색 or not 칠하기_허용:
		return false
	현재상태 = 상태.무색
	_맞은횟수 = 0
	_시드_비우기()
	_젖음 = 0.0
	_감쇠중 = false
	_충돌레이어_갱신()
	_유니폼_갱신()
	return true


# ── 상태 전이 ───────────────────────────────────────────────────────────────
func _회색으로() -> void:
	현재상태 = 상태.회색
	_시드_비우기()
	# 회색은 지형 전체를 덮는 얼룩 하나로 표현 (색 인덱스 2 = 셰이더의 gray)
	_시드_추가(_중심, _로컬반경, ColorDefs.GRAY)
	_젖음 = 1.0
	_감쇠중 = false
	_충돌레이어_갱신()
	_유니폼_갱신()


func _전체_즉시(새상태: 상태) -> void:
	현재상태 = 새상태
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
	var 갱신 := false

	if _젖음 > 0.0:
		_젖음 = maxf(_젖음 - delta * 1.4, 0.0)
		갱신 = true

	# 전체 색칠·회색은 감쇠하지 않는다. 부분 색칠(무색 + 시드 있음)만 대상.
	if 현재상태 == 상태.무색 and not _시드.is_empty():
		_마지막명중 += delta
		if _마지막명중 > 부분_유지시간:
			_감쇠중 = true
			var 감소 := delta / maxf(부분_감쇠시간, 0.01)
			var 남음 := false
			for i in _세기.size():
				_세기[i] = maxf(_세기[i] - 감소, 0.0)
				if _세기[i] > 0.0:
					남음 = true
			갱신 = true
			if not 남음:
				# 다 흐려졌다 → 페인트를 돌려준다
				var 발수 := _맞은횟수
				_시드_비우기()
				_맞은횟수 = 0
				_감쇠중 = false
				if _코어:
					_코어.부분_자동회수(self, 발수)

	if 갱신:
		_유니폼_갱신()


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
