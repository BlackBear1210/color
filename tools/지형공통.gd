extends RefCounted
## ============================================================================
## [2026-08-06 신규] 스마트월드 지형 빌더 공통 부품
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   `build_스마트월드.gd` 하나에 재질 생성·점 계산·지형 노드 조립이 다 들어 있었다.
##   스테이지 1-2 를 만들면서 그걸 통째로 복사하면 **같은 버그를 두 벌 고쳐야 한다.**
##   (실제로 2026-08-02 의 `_주인_지정` 버그는 복사본이 있었으면 두 번 겪었을 것이다)
##   → 두 빌더가 공유하는 부분만 여기로 뺐다. 스테이지별 배치는 각 빌더가 갖는다.
##
## ▣ 여기 들어 있는 것
##   1. 재질 만들기 — `assets/textures/smartshape/` 의 **도형님이 그린 타일**로
##      SS2D 지형 재질(.tres)을 조립한다. 타일 조합만 바꾸면 지형 룩이 통째로 바뀐다.
##   2. 점 만들기 — 평평한 바닥 / 굽이치는 바닥 / 덩어리(섬) / 천장 매스
##   3. 지형 노드 조립 — 콜리전 폴리곤까지 구워서 돌려준다
##   4. owner 지정 — ★인스턴스 씬 경계에서 멈추는 안전한 버전 (2026-08-02 버그)
##
## ▣ 타일 카탈로그 (도형님 작업물, assets/textures/smartshape/)
##   전부 black_* / white_* 짝으로 존재한다. 짝이 있어야 `지형_페인트.gdshader` 가
##   "칠하면 흰 아트로 바뀌는" 연출을 할 수 있다.
##     center   / center2    32×16  윗면(지면) — 2 가 더 거칠다
##     left     / left2      16×16  왼쪽 벽면
##     right    / right2     16×16  오른쪽 벽면
##     bottom_center         32×16  아랫면(천장에서 내려다본 면)
##     bottom_left/right     16×16  아래 모서리 (SS2D 코너 슬롯용 — 지금은 미사용)
##     allaround             32×16  사방 공용 — 작은 덩어리에 한 장으로 두르기
##     fill                  64×64  안쪽 채우기
##
## ▣ ★재질을 여러 개 두는 이유 (변형 텍스처를 한 재질에 몰지 않는다)
##   SS2D 는 `randomize_texture` 로 한 슬롯에 여러 장을 섞어 쓸 수 있다. 하지만
##   `지형.gd` 의 페인트 셰이더는 **텍스처 한 장당 흰색 짝 한 장**을 물려주는 구조라
##   (`alt_tex` 유니폼이 하나), 한 슬롯에 두 장을 섞으면 칠했을 때 엉뚱한 흰 무늬가 나온다.
##   → 변형은 **재질을 나눠서** 쓴다. 스테이지마다 지형 룩이 달라지는 효과도 덤으로 얻는다.
## ============================================================================
class_name 지형공통

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 타일폴더 := "res://assets/textures/smartshape/"

# ============================================================================
# 1. 재질
# ============================================================================
## 재질 종류별 타일 조합.
##   슬롯 = [텍스처이름, 시작각, 폭, z]
##   각도는 **면의 바깥 노멀** 기준 (0°=오른쪽, 90°=위, 180°=왼쪽, 270°=아래).
##   90° 폭 4 개로 360° 를 다 덮는다. 45° 씩 어긋나게 시작해 모서리에서 자연스럽게 갈린다.
const 재질표 := {
	# 스테이지 1-1 — 부드러운 자연 지형 (기존과 동일한 조합, 호환 유지)
	"기본": {
		"채우기": "black_fill",
		"슬롯": [
			["black_bottom_center", 225.0, 90.0, 0],
			["black_left", 135.0, 90.0, 0],
			["black_right", 315.0, 90.0, 0],
			["black_center", 45.0, 90.0, 1],
		],
	},
	# 스테이지 1-2 — 거친 폐수로 암반. *2 변형 타일을 쓴다.
	# ★도형님이 그려두고 아직 한 번도 안 쓰인 타일들(center2/left2/right2)이 여기 들어간다.
	"거친암반": {
		"채우기": "black_fill",
		"슬롯": [
			["black_bottom_center", 225.0, 90.0, 0],
			["black_left2", 135.0, 90.0, 0],
			["black_right2", 315.0, 90.0, 0],
			["black_center2", 45.0, 90.0, 1],
		],
	},
	# 작은 공중 덩어리 전용 — 사방을 allaround 한 장으로 두른다.
	# 작은 섬은 면이 짧아서 4 슬롯으로 나누면 타일이 한두 개씩만 들어가 지저분해진다.
	"덩어리": {
		"채우기": "black_fill",
		"슬롯": [
			["black_allaround", 0.0, 360.0, 0],
		],
	},
}


## 재질 .tres 를 만든다(이미 있으면 그대로 쓴다).
##   종류 : 재질표의 키
##   경로 : 저장 위치. 비우면 `assets/textures/smartshape/지형_<종류>.tres`
## 반환: 재질 리소스 경로
static func 재질_준비(종류: String, 경로: String = "", 강제재생성: bool = false) -> String:
	var 저장경로 := 경로
	if 저장경로.is_empty():
		저장경로 = "%s지형_%s.tres" % [타일폴더, 종류]
	if ResourceLoader.exists(저장경로) and not 강제재생성:
		return 저장경로

	var 표: Dictionary = 재질표.get(종류, 재질표["기본"])
	var 재질 := SS2D_Material_Shape.new()

	var 채우기경로 := "%s%s.png" % [타일폴더, 표["채우기"]]
	if not ResourceLoader.exists(채우기경로):
		push_error("지형공통: 채우기 타일이 없다 → %s" % 채우기경로)
		return ""
	var 채우기: Array[Texture2D] = [load(채우기경로)]
	재질.fill_textures = 채우기
	재질.fill_texture_scale = 1.0
	# ★[2026-08-01 함정 유지] SS2D 기본값 -10 은 배경 보정 레이어(z=-7)보다 뒤라서
	#   지형 안쪽이 통째로 가려진다(테두리만 보이는 상태). -1 로 올려 둔다.
	재질.fill_texture_z_index = -1

	var 메타들: Array[SS2D_Material_Edge_Metadata] = []
	for 슬롯 in 표["슬롯"]:
		var 텍경로 := "%s%s.png" % [타일폴더, 슬롯[0]]
		if not ResourceLoader.exists(텍경로):
			push_warning("지형공통: 테두리 타일 없음(건너뜀) → %s" % 텍경로)
			continue
		var 텍스처: Array[Texture2D] = [load(텍경로)]
		var 테두리 := SS2D_Material_Edge.new()
		테두리.textures = 텍스처
		# 모서리·테이퍼 조각은 아직 규격이 안 맞다. 켜면 빈 텍스처로 구멍이 뚫린다.
		테두리.use_corner_texture = false
		테두리.use_taper_texture = false
		# ★한 슬롯 한 장 원칙 — 위 주석 참고(페인트 셰이더의 alt_tex 가 하나뿐이다)
		테두리.randomize_texture = false
		var 메타 := SS2D_Material_Edge_Metadata.new()
		메타.edge_material = 테두리
		메타.normal_range = SS2D_NormalRange.new(슬롯[1], 슬롯[2])
		메타.z_index = 슬롯[3]
		메타들.append(메타)
	재질.set_edge_meta_materials(메타들)

	var err := ResourceSaver.save(재질, 저장경로)
	if err != OK:
		push_error("지형공통: 재질 저장 실패(%s) → %s" % [error_string(err), 저장경로])
		return ""
	print("  [지형공통] 재질 생성 → %s" % 저장경로)
	return 저장경로


# ============================================================================
# 2. 점 만들기
# ============================================================================

## ★평평한 바닥 (스테이지 1-2 용 — 도형님 요청 "바닥이 일자로 가고").
## 완전한 직선이면 죽은 그림이라, **1~3px 짜리 미세한 요철**만 준다.
## 눈에는 직선으로 보이지만 타일 테두리가 살아나서 "그린 것"처럼 보인다.
static func 평바닥_점들(x0: float, x1: float, y: float, 바닥y: float,
		거칠기: float = 2.5, 간격: float = 64.0) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var x := x0
	var i := 0
	while x <= x1:
		# 사인 2 개를 아주 작은 진폭으로 겹친다 — 규칙적인 물결로 보이지 않게
		var dy := sin(x * 0.031) * 거칠기 + sin(x * 0.0077 + 1.3) * 거칠기 * 0.7
		점들.append(Vector2(x, y + dy))
		x += 간격
		i += 1
	점들.append(Vector2(x1, y))
	점들.append(Vector2(x1, 바닥y))
	점들.append(Vector2(x0, 바닥y))
	return 점들


## 굽이치는 바닥 (스테이지 1-1 의 자연 지형).
## 사인 3 개를 겹쳐서 규칙성을 없앤다. 노이즈보다 예측 가능하고, 같은 식을
## `높이함수` 로 다시 불러 프롭을 지면에 정확히 붙일 수 있다.
static func 굽은바닥_점들(x0: float, x1: float, 높이함수: Callable,
		바닥y: float, 간격: float = 40.0) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var x := x0
	while x <= x1:
		점들.append(Vector2(x, float(높이함수.call(x))))
		x += 간격
	점들.append(Vector2(x1, float(높이함수.call(x1))))
	점들.append(Vector2(x1, 바닥y))
	점들.append(Vector2(x0, 바닥y))
	return 점들


## ★천장 매스 — 위에서 아래로 내려오는 암반 덩어리.
## 레인월드 지형이 묵직한 건 방이 항상 "덩어리에서 파낸 공간"이기 때문이다.
## 천장이 없으면 아무리 바닥을 잘 만들어도 "허공에 놓인 발판"으로 읽힌다.
##   아랫면(=플레이어가 올려다보는 면)만 울퉁불퉁하게 만들고 위쪽은 평평하게 닫는다.
static func 천장_점들(x0: float, x1: float, 아랫면y: float, 위y: float,
		굴곡: float = 34.0, 간격: float = 72.0, 위상: float = 0.0) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	# 위쪽(평평) — 왼쪽에서 오른쪽으로
	점들.append(Vector2(x0, 위y))
	점들.append(Vector2(x1, 위y))
	# 아랫면 — 오른쪽에서 왼쪽으로 되돌아오며 요철을 준다
	var x := x1
	while x >= x0:
		var t := x / 190.0 + 위상
		var dy := sin(t) * 굴곡 + sin(t * 2.11 + 0.7) * 굴곡 * 0.5 \
			+ sin(t * 0.47 - 1.1) * 굴곡 * 0.7
		점들.append(Vector2(x, 아랫면y + dy))
		x -= 간격
	점들.append(Vector2(x0, 아랫면y))
	return 점들


## 유기적인 덩어리(섬). 타원에 요철을 섞는다.
static func 덩어리_점들(rx: float, ry: float, rng: RandomNumberGenerator,
		점개수: int = 26) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var 위상 := rng.randf() * TAU
	for i in 점개수:
		var a := TAU * float(i) / float(점개수)
		# 사인 2 개를 겹친 요철 — 매번 다른 실루엣이 나오되 뾰족해지지는 않는다
		var 요철 := 1.0 + sin(a * 3.0 + 위상) * 0.11 + sin(a * 5.0 - 위상) * 0.06
		점들.append(Vector2(cos(a) * rx * 요철, sin(a) * ry * 요철))
	return 점들


## ★벽에서 튀어나온 선반(ledge). 레인월드에서 수직 이동의 발판이 되는 그것.
## 벽에 붙는 쪽(안쪽)은 직각, 바깥쪽은 아래로 얇아진다 = "깎여 나온 바위" 실루엣.
##   방향 +1 = 오른쪽으로 뻗음 / −1 = 왼쪽으로 뻗음
static func 선반_점들(길이: float, 두께: float, 방향: float) -> PackedVector2Array:
	var d := signf(방향)
	if is_zero_approx(d):
		d = 1.0
	return PackedVector2Array([
		Vector2(0, -두께 * 0.5),
		Vector2(d * 길이 * 0.55, -두께 * 0.5),
		Vector2(d * 길이, -두께 * 0.22),      # 끝이 살짝 들린다
		Vector2(d * 길이 * 0.92, 두께 * 0.16),
		Vector2(d * 길이 * 0.45, 두께 * 0.42),
		Vector2(0, 두께 * 0.5),
	])


## 세로 벽 기둥 — 수직 갱도·굴뚝의 양옆을 막는다. 원점은 벽의 **중심**.
##
## ⚠[2026-08-06 함정] 처음엔 "오른쪽 면을 위→아래로 훑고 왼쪽 면을 아래→위로" 만들었더니
##   `Convex decomposing failed!` 이 떴다. 콜리전은 `Geometry2D.offset_polygon()` 으로
##   부풀린 다음 볼록 분해되는데, 다음 두 가지가 겹치면 분해가 실패한다.
##     · 감김 방향이 다른 지형 함수들(평바닥·천장·덩어리 = **시계 방향**)과 반대
##     · 요철 진폭(9px)에 비해 점 간격(60px)이 촘촘해 MITER 조인이 뾰족하게 튄다
##   → 아래처럼 **시계 방향(위→오른쪽→아래→왼쪽)** 으로 통일하고,
##     진폭을 줄이고(7px) 간격을 넓혔다(90px). 이 조합은 실패하지 않는다.
##   새 지형 함수를 추가할 때도 **감김 방향을 시계 방향으로 맞출 것.**
static func 벽_점들(폭: float, 높이: float, 거칠기: float = 7.0,
		간격: float = 90.0) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var 반폭 := 폭 * 0.5
	var 반높 := 높이 * 0.5

	# ① 윗면 (왼 → 오)
	점들.append(Vector2(-반폭, -반높))
	점들.append(Vector2(반폭, -반높))
	# ② 오른쪽 면 (위 → 아래)
	var y := -반높 + 간격
	while y < 반높 - 간격 * 0.5:
		점들.append(Vector2(반폭 + sin(y * 0.011) * 거칠기, y))
		y += 간격
	# ③ 아랫면 (오 → 왼)
	점들.append(Vector2(반폭, 반높))
	점들.append(Vector2(-반폭, 반높))
	# ④ 왼쪽 면 (아래 → 위)
	y = 반높 - 간격
	while y > -반높 + 간격 * 0.5:
		점들.append(Vector2(-반폭 + sin(y * 0.013 + 2.1) * 거칠기, y))
		y -= 간격
	return 점들


# ============================================================================
# 3. 지형 노드 조립
# ============================================================================
## SS2D 지형 노드 하나. 콜리전 폴리곤까지 미리 구워서 돌려준다.
##
## ⚠ 반드시 `지형_S.new()` 로 만든다. Node2D.new() + set_script() 로 만들면
##   SS2D_Shape._init() 이 안 돌아 점 배열(SS2D_Point_Array)이 null 이 된다.
static func 지형_노드(이름: String, 위치: Vector2, 점들: PackedVector2Array,
		재질경로: String, 칠하기: bool, 유령: bool,
		필요횟수: int = 0, 콜리전두께: float = 24.0) -> 스마트지형:
	var 지형: 스마트지형 = 지형_S.new()
	지형.name = 이름
	지형.position = 위치
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 픽셀아트라 필수
	지형.칠하기_허용 = 칠하기
	지형.무색일때_통과 = 유령
	지형.필요횟수_수동 = 필요횟수

	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()

	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	# ★[2026-08-02] 오목 폴리곤은 Godot 이 볼록 조각으로 쪼개 조각마다 다른 색 기즈모를
	#   그린다. 지형이 크면 에디터 2D 뷰가 통째로 무지개가 되어 점을 찍을 수가 없다.
	#   visible 은 기즈모/디버그 그리기만 끄는 것이라 물리 판정에는 영향이 없다.
	폴리.visible = false
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	지형.collision_size = 콜리전두께
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime

	# 콜리전 폴리곤 굽기.
	# ⚠ `generate_filled` 는 내부에서 `Geometry2D.offset_polygon(...).front()` 를 쓴다.
	#   모양이 뾰족하거나 감김 방향이 어긋나면 **빈 배열**이 나오고, 그걸 그대로 넣으면
	#   "Convex decomposing failed!" 와 함께 **밟을 수 없는 지형**이 된다(조용히 망가진다).
	#   그래서 결과가 비면 원본 점을 그대로 쓴다 — 살짝 얇아지지만 최소한 밟히긴 한다.
	var gen := SS2D_CollisionGen.new()
	gen.collision_size = 콜리전두께
	var 원본 := 지형.get_point_array().get_tessellated_points()
	var 구운것 := gen.generate_filled(원본)
	if 구운것.size() < 3:
		push_warning("지형공통(%s): 콜리전 오프셋 실패 → 원본 폴리곤을 그대로 쓴다" % 이름)
		구운것 = 원본
	폴리.polygon = 구운것
	return 지형


# ============================================================================
# 4. owner 지정
# ============================================================================
## 씬 저장(PackedScene.pack)을 위해 owner 를 루트로 지정한다.
##
## ★★[2026-08-02 치명적 버그] 인스턴스 씬 **안쪽으로 내려가면 안 된다.**
##   Player.tscn 처럼 인스턴스로 넣은 노드의 자식(Gun·Placeholder…)까지 owner 를 바꾸면
##   PackedScene 이 그것들을 **원본과 별개인 새 노드로 한 벌 더 저장**한다.
##   그래서 Player 밑에 Gun2 / Placeholder2 / Camera2D2 가 생겨
##   "Muzzle 을 못 찾음" · "null 에 global_position 접근" · "파란 박스에 갇힘" 이 한꺼번에 났다.
##   → `scene_file_path` 가 비어 있지 않으면 그 노드가 인스턴스 루트다. 거기서 멈춘다.
static func 주인_지정(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		자식.owner = 루트
		if not 자식.scene_file_path.is_empty():
			continue          # 인스턴스 씬 — 내부는 그 씬이 관리한다. 건드리지 않는다.
		주인_지정(자식, 루트)
