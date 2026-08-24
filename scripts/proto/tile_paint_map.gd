extends Node
## ============================================================================
## 타일맵 기반 페인트 시스템 — "아틀라스 좌표로 색을 인지한다"
## ----------------------------------------------------------------------------
## ▣ 무엇이 달라지는가
##   zone_04 방식(PaintPlatform)은 플랫폼 1개 = 노드 1개였다. 그래서 새 스테이지를
##   만들 때마다 플랫폼을 노드로 하나하나 배치해야 했다.
##   이 시스템은 그 반대다 — **디자이너는 TileMapLayer 로 맵을 찍기만 하면 되고**,
##   런타임에 이 노드가 타일을 훑어서 "플랫폼"을 자동으로 찾아낸다.
##   덕분에 플랫폼 조각을 새 씬으로 복붙할 필요가 없다.
##
## ▣ 색을 어떻게 인지하는가 (실측으로 확인한 규칙)
##   디자이너 PNG 5장은 한 장 안에 흑 버전과 백 버전이 나란히/위아래로 들어 있다.
##   타일 크기가 16px 이고 한 버전이 384px 이므로 **정확히 24칸**이 경계다.
##     | 파일       | 해상도   | 배치           | 흑→백 변환 |
##     |-----------|---------|---------------|-----------|
##     | brick.png | 768×768 | 흑 좌 / 백 우   | x + 24    |
##     | grass.png | 768×896 | 흑 좌 / 백 우   | x + 24    |
##     | rock.png  | 768×384 | 흑 좌 / 백 우   | x + 24    |
##     | soil.png  | 768×384 | 흑 좌 / 백 우   | x + 24    |
##     | wood.png  | 768×768 | 흑 상 / 백 하   | y + 24    |
##   → 즉 아틀라스 좌표 하나만 보면 그 타일이 흑인지 백인지 알 수 있고,
##     ±24 만 하면 같은 무늬의 반대색 타일로 바꿔치기할 수 있다.
##   (소스 id 를 하드코딩하지 않고 텍스처 파일명으로 규칙을 찾으므로,
##    TileSet 의 소스 순서가 바뀌어도 깨지지 않는다.)
##
## ▣ 규칙은 zone_04 를 그대로 따른다 (paint_platform.gd 와 동일한 상태 기계)
##   · 연결된 같은 색 타일 덩어리 = 플랫폼 1개
##   · 필요횟수 = 플랫폼의 긴 변(칸) / 나눗값  → 크면 더 많이 맞혀야 한다
##   · 흑·백 부분칠은 따로 남고, 두 색이 함께 있으면 전체칠이 되지 않는다
##   · 완성된 플랫폼에 반대색 → 회색 없이 마지막 색으로 덮어쓰기
##   · 부분칠은 4초 유지 + 1초 감쇠 뒤 색별로 자동 회수
##   · E 회수 = 색과 무관하게 "가장 먼저 칠한 플랫폼"부터 원래 타일로 FIFO 복구
##
## ▣ proto_bullet / proto_gun 과의 연결
##   PaintSystem(v2) 과 **같은 메서드 이름**(on_hit / recover / 되돌리기)을 쓴다.
##   그래서 총알·총 코드를 고치지 않고 그대로 끼울 수 있다(덕 타이핑).
## ============================================================================
class_name TilePaintMap

const 페인트진행_S := preload("res://scripts/페인트_진행.gd")

signal 상태변경                                     ## HUD 갱신용
signal 명중됨(결과: String, 색: int, 월드좌표: Vector2)
## [2026-08-17] 탄약이 바뀔 때. HUD 는 매 프레임 읽지만, 소리·연출을 붙일 자리로 남겨둔다.
signal 탄약_변경(남은: int, 최대: int)

# ── 탄약 (2026-08-17 신규) ──────────────────────────────────────────────────
## ▣ 왜 이제서야 넣나
##   이 시스템은 원래 탄약이 없었다. `proto_gun` 은 아무한테도 안 물어보고 그냥 쐈고,
##   그래서 좌상단 HUD 에 **탄약 줄이 아예 안 나왔다**(그릴 값이 없었다).
##   규칙은 `페인트_코어.gd`(스마트월드)를 그대로 따른다 — 같은 게임인데 스테이지마다
##   자원 규칙이 다르면 플레이어가 두 번 배워야 한다.
##
## ▣ 숫자를 고를 때 알아야 할 것
##   E 로 회수하면 발이 돌아오므로, 탄약은 "총 사용량 제한"이 아니라
##   **동시에 칠해둘 수 있는 양의 상한**이다.
##   `stage_1-1, 1-2` 실측: 칠할 수 있는 플랫폼 103 개, 전부 칠하면 440 발,
##   가장 큰 플랫폼 하나가 12 발을 먹는다. 그래서 12 발이면 큰 것 하나도 못 칠한다.
##
## ★0 이하 = 무제한(예전 동작). `zone_*` 등 탄약을 안 쓰는 경로는 손댈 필요가 없다.
@export var 최대_탄약: int = 14:
	set(v):
		최대_탄약 = maxi(v, 0)
		남은_탄약 = 최대_탄약
		탄약_변경.emit(남은_탄약, 최대_탄약)

var 남은_탄약: int = 14
## 회색이 되어 잠긴 총 발수. 스테이지를 다시 시작해야 돌아온다.
var _잠긴_발수: int = 0
## ★[2026-08-17] 지금 날아가는 중인 발 수 — **HUD 표시 전용**(규칙 판정에 쓰지 않는다).
## 탄약은 쏘는 순간 깎이고 착탄해야 결과가 나오므로, HUD 가 `남은_탄약` 을 그대로 그리면
## 한 발에 두 번 바뀐다(쏨 → 꺼짐 → 착탄 → 켜짐). 빗나가면 깜빡임만 남는다.
## → HUD 는 `남은_탄약 + 비행중` 을 그려서 **착탄하는 순간 한 번만** 바뀌게 한다.
var _비행중: int = 0

## 한 버전(384px)이 차지하는 칸 수 = 384 / 16
const 반칸: int = 24
## 텍스처 파일명 → 흑/백이 나뉘는 축 (0 = X, 1 = Y)
## [2026-08-07] wood.png 는 원래 혼자만 상하 분할(축=1)이었다. 좌우 절반이 흑/백인
## 나머지 4종과 달라, 레벨을 짤 때 "오른쪽 = 흰색"인 줄 알고 찍은 타일이 실제로는
## 검정(평면 변형)이라 "쏴도 안 칠해지는" 오해를 반복해서 만들었다.
## → wood.png 의 우상(검정 평면) ↔ 좌하(흰색 액자형) 블록을 맞바꿔 5종 모두
##   "좌 = 검정, 우 = 흰색" 으로 통일했다. 기존 씬의 셀 좌표도 같이 옮겨서
##   겉모습·색 판정은 그대로다. 이제 예외 없이 전부 X축이다.
const 축_by_파일 := {
	"brick.png": 0,
	"grass.png": 0,
	"rock.png": 0,
	"soil.png": 0,
	"wood.png": 0,
}

## 필요횟수 = ceil(긴 변 칸수 / 나눗값). 기본 4 는 zone_04 의 감각과 맞춘 값 —
## zone_04 는 32px 를 1칸으로 세고 ceil(긴변/2) 였는데, 이 타일셋은 16px 이므로 2배가 된다.
@export var 필요횟수_나눗값: int = 4
## 아무리 커도 이 횟수를 넘지 않는다 (거대한 바닥이 사실상 못 칠하게 되는 걸 방지)
@export var 최대_필요횟수: int = 12
## 이 타일 수를 넘는 덩어리는 "고정 지형"으로 본다 (바닥·벽 등은 칠 대상이 아님).
## ★0 이하 = 제한 없음(모두 칠할 수 있다).
## ⚠ 타일맵으로 그린 스테이지는 바닥이 하나로 크게 연결되기 쉽다. stage_1-1 을 실측해 보니
##   스폰 앞 바닥이 560칸 한 덩어리여서 400 기준에서는 전부 "고정"으로 빠졌다
##   → 쏴도 blocked 만 나와 "색칠이 안 되는" 것처럼 보였다. 그래서 기본값을 제한 없음으로 둔다.
@export var 칠하기_최대_타일수: int = 0

## 잉크 마스크 셰이더 (오버레이 레이어에 붙는다)
const MASK_SHADER := preload("res://shaders/ink_spread_mask.gdshader")
## 셰이더의 MAX_SEEDS 와 반드시 같아야 한다
const 최대_시드: int = 16
## 오버레이 레이어 이름 접두어 — 재등록 시 이 레이어들은 훑지 않는다
const 오버레이_접두어: String = "_페인트오버레이"

## 연결된 같은 색 타일 덩어리 하나 = 플랫폼 하나
class 플랫폼:
	var 레이어: TileMapLayer
	var 셀: Array[Vector2i] = []
	var 원본: Dictionary = {}          ## Vector2i → { "src": int, "atlas": Vector2i, "alt": int }
	var 원래색: int = ColorDefs.BLACK
	var 필요: int = 1
	var 맞은: int = 0
	var 진행색: int = -1
	var 진행 = 페인트진행_S.new()
	var 칠해짐: bool = false
	var 회색: bool = false
	var 고정: bool = false             ## 바닥·벽 등 칠할 수 없는 덩어리
	## ── 잉크 번짐 표현 ──
	## 원본 레이어는 절대 건드리지 않고, 반대색 타일을 찍은 오버레이 레이어의
	## 알파를 셰이더 마스크로 깎아서 "물감이 스며드는" 경계를 만든다.
	var 오버레이: TileMapLayer = null
	var 시드: PackedVector2Array = PackedVector2Array()        ## 바운딩박스 UV(0~1)
	var 시드반지름: PackedFloat32Array = PackedFloat32Array()
	var 시드목표: PackedFloat32Array = PackedFloat32Array()
	var 시드색: PackedInt32Array = PackedInt32Array()
	var 시드세기: PackedFloat32Array = PackedFloat32Array()
	var 바탕마스크: float = 0.0
	var 젖음: float = 0.0
	var 최소: Vector2i = Vector2i.ZERO                          ## 바운딩박스(칸)
	var 최대: Vector2i = Vector2i.ZERO

## ★[2026-08-22 신규] 타일이 **아닌** 칠할 수 있는 노드 하나가 회수줄에 선 자리.
##
## 왜 필요한가: 이 클래스는 원래 TileMapLayer 의 셀 덩어리만 다뤘다. 그런데 하수도
## 챕터의 장애물(투명블럭·통과플랫폼·물저장고…)은 **독립 노드**라 셀 좌표가 없다.
## 그렇다고 따로 줄을 세우면 E 회수의 FIFO 순서가 타일과 뒤엉킨다.
## → `_큐` 에 **같이** 세우고 `되돌리기()` 에서 한 번만 갈라 본다.
##
## ⚠ HUD(`회수줄_요약`·`대상_발수`·`대상_좌표`)가 `_큐` 원소에서 **`플랫폼` 의 필드를
##   그대로 읽는다.** 그래서 이름을 맞춰 두지 않으면 HUD 가 그려지는 순간 죽는다
##   (2026-08-22 에 실제로 `회색` 접근에서 터졌다).
class 외부칠:
	var 노드: Node
	var 맞은: int = 0
	## 회색이 된 항목은 `_큐` 에서 빼므로 언제나 false 다. HUD 가 읽으니 필드는 있어야 한다.
	var 회색: bool = false
	## E 마커를 띄울 자리. 외부 노드는 레이어·셀이 없어서 **마지막 명중 지점**을 쓴다.
	var 좌표: Vector2 = Vector2.ZERO

## 내부 클래스(플랫폼)를 담으므로 타입 힌트 없는 Array 를 쓴다.
var _플랫폼들: Array = []
var _셀_찾기: Dictionary = {}          ## "레이어경로|셀" → 플랫폼
var _큐: Array = []                    ## 칠한 순서 (앞이 가장 오래된 것)
## ★[2026-08-22] 회색으로 굳은 **외부 노드** 목록.
## 회색이 되면 회수줄(`_큐`)에서 빠지기 때문에, 이 목록이 없으면 `리셋()` 이
## 그 노드를 찾을 방법이 없다 — 죽어도 회색이 그대로 남는 버그가 된다.
## (`페인트_코어.gd` 가 `_회색_목록` 을 따로 드는 것과 같은 이유다.)
var _외부_회색: Array[Node] = []
## [2026-08-17] HUD 호버 조회용 레이어 목록 캐시. `등록()` 이 돌면 비운다.
var _레이어_캐시: Array[TileMapLayer] = []

# ── 색 인지 ─────────────────────────────────────────────────────────────────
## 이 소스의 흑/백이 나뉘는 축. 규칙을 모르는 소스면 -1.
static func 분할축(tile_set: TileSet, source_id: int) -> int:
	if tile_set == null:
		return -1
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null or src.texture == null:
		return -1
	return int(축_by_파일.get(src.texture.resource_path.get_file(), -1))

## 아틀라스 좌표 → 색. 규칙을 모르면 -1.
static func 좌표_색(tile_set: TileSet, source_id: int, atlas: Vector2i) -> int:
	var 축 := 분할축(tile_set, source_id)
	if 축 < 0:
		return -1
	var v := atlas.x if 축 == 0 else atlas.y
	return ColorDefs.BLACK if v < 반칸 else ColorDefs.WHITE

## 같은 무늬의 반대색 아틀라스 좌표. 규칙을 모르면 원래 좌표를 그대로 돌려준다.
static func 반대색_좌표(tile_set: TileSet, source_id: int, atlas: Vector2i) -> Vector2i:
	var 축 := 분할축(tile_set, source_id)
	if 축 < 0:
		return atlas
	var out := atlas
	if 축 == 0:
		out.x = atlas.x - 반칸 if atlas.x >= 반칸 else atlas.x + 반칸
	else:
		out.y = atlas.y - 반칸 if atlas.y >= 반칸 else atlas.y + 반칸
	# 그 좌표에 실제 타일이 없으면(예: grass 의 "두꺼움" 은 백 버전이 없다) 포기한다
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null or not src.has_tile(out):
		return atlas
	return out

## 이 셀의 현재 색. 빈 셀이거나 규칙을 모르면 -1.
static func 셀_색(layer: TileMapLayer, cell: Vector2i) -> int:
	var src := layer.get_cell_source_id(cell)
	if src == -1:
		return -1
	return 좌표_색(layer.tile_set, src, layer.get_cell_atlas_coords(cell))

# ── 등록 (플랫폼 자동 검출) ─────────────────────────────────────────────────
func _ready() -> void:
	set_process(false)                 # 번짐 애니메이션이 있을 때만 돌린다
	if get_parent():
		등록_전체(get_parent())

## 씬 안의 모든 TileMapLayer 를 훑어 플랫폼을 찾아낸다.
func 등록_전체(뿌리: Node) -> void:
	for layer in _모든_타일맵(뿌리):
		등록(layer)
	상태변경.emit()

func _모든_타일맵(뿌리: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for 자식 in 뿌리.get_children():
		if String(자식.name).begins_with(오버레이_접두어):
			continue                    # 우리가 만든 잉크 오버레이는 칠 대상이 아니다
		var l := 자식 as TileMapLayer
		if l != null:
			out.append(l)
		out.append_array(_모든_타일맵(자식))
	return out

## 한 레이어를 훑어 "연결된 같은 색 타일 덩어리"를 플랫폼으로 등록한다 (4방향 플러드 필).
func 등록(layer: TileMapLayer) -> void:
	if layer.tile_set == null:
		return
	_레이어_캐시.clear()        # 플랫폼이 새로 생기면 HUD 호버 캐시도 무효다
	var 남은 := {}
	for cell in layer.get_used_cells():
		var 색 := 셀_색(layer, cell)
		if 색 >= 0:                     # 규칙을 아는(= 칠할 수 있는) 타일만 대상
			남은[cell] = 색

	while not 남은.is_empty():
		var 시작: Vector2i = 남은.keys()[0]
		var 색: int = 남은[시작]
		var 덩어리: Array[Vector2i] = []
		var 대기: Array[Vector2i] = [시작]
		남은.erase(시작)
		while not 대기.is_empty():
			var c: Vector2i = 대기.pop_back()
			덩어리.append(c)
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if 남은.has(n) and 남은[n] == 색:
					남은.erase(n)
					대기.append(n)
		_플랫폼_만들기(layer, 덩어리, 색)

func _플랫폼_만들기(layer: TileMapLayer, 셀들: Array[Vector2i], 색: int) -> void:
	var p := 플랫폼.new()
	p.레이어 = layer
	p.셀 = 셀들
	p.원래색 = 색
	for c in 셀들:
		p.원본[c] = {
			"src": layer.get_cell_source_id(c),
			"atlas": layer.get_cell_atlas_coords(c),
			"alt": layer.get_cell_alternative_tile(c),
		}
		_셀_찾기[_키(layer, c)] = p

	# 필요횟수 = 긴 변 기준 (zone_04 와 같은 감각: 크면 더 많이 맞혀야 한다)
	var 최소 := 셀들[0]
	var 최대 := 셀들[0]
	for c in 셀들:
		최소 = Vector2i(mini(최소.x, c.x), mini(최소.y, c.y))
		최대 = Vector2i(maxi(최대.x, c.x), maxi(최대.y, c.y))
	p.최소 = 최소
	p.최대 = 최대
	var 긴변 := maxi(최대.x - 최소.x + 1, 최대.y - 최소.y + 1)
	p.필요 = clampi(int(ceil(float(긴변) / float(maxi(필요횟수_나눗값, 1)))), 1, 최대_필요횟수)
	p.고정 = 칠하기_최대_타일수 > 0 and 셀들.size() > 칠하기_최대_타일수
	_플랫폼들.append(p)

## 셀 → 플랫폼 조회 키.
## ⚠ 예전엔 layer.get_path() 를 썼는데, 노드가 씬 트리에 없는 순간에는
##   "Cannot get path of node as it is not in a scene tree" 에러가 나면서 조회가 전부 실패했다.
##   인스턴스 ID 는 트리에 있든 없든 항상 유효하고 더 빠르다.
static func _키(layer: TileMapLayer, cell: Vector2i) -> String:
	return "%d|%d,%d" % [layer.get_instance_id(), cell.x, cell.y]

func _찾기(layer: TileMapLayer, cell: Vector2i):
	return _셀_찾기.get(_키(layer, cell), null)

# ── 명중 처리 (proto_bullet 이 호출 — PaintSystem.on_hit 과 같은 시그니처) ───
## 반환값: progress / painted / wasted / blocked / miss
## 명중 지점 보정 반경(칸). 아래 이유로 2칸(=32px)이 필요하다.
const 탐색_반경: int = 2

func on_hit(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	_비행_해제()                       # 이 발은 결판났다 (HUD 표시용 계수)
	var 실제셀 := _가까운_셀(layer, cell)
	var 결과 := _명중_처리(layer, 실제셀, color)
	_탄약_정산(layer, 실제셀, 결과)
	var 타일 := Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
	var 월드 := layer.to_global((Vector2(실제셀) + Vector2(0.5, 0.5)) * 타일)
	명중됨.emit(결과, color, 월드)
	return 결과


## 명중 결과에 따라 페인트를 돌려주거나 잠근다 (페인트_코어.gd 규칙 5·6 과 동일).
##   painted / progress → 그대로 대상에 묶인다 (E 로 회수 가능)
##   wasted / blocked / miss → 아무 일도 안 일어났으니 **그 자리에서 환급**
##   mixed_gray → 외부 장애물끼리 회색을 만든 경우에만 발을 잠근다
func _탄약_정산(layer: TileMapLayer, cell: Vector2i, 결과: String) -> void:
	if not 탄약을_쓰나():
		return
	match 결과:
		"wasted", "blocked", "miss":
			_환급(1)
		"mixed_gray":
			# ⚠ `_회색으로()` 는 `맞은` 을 건드리지 않는다 → 여기서 아직 원래 발수가 들어 있다.
			var p = _찾기(layer, cell)
			var 들어간: int = int(p.맞은) if p != null else 0
			_잠긴_발수 += 들어간 + 1

## ★총알이 준 셀이 빈 칸이면 주변에서 "등록된 타일"을 가까운 순으로 찾는다.
##
## ⚠ 왜 필요한가 — 이게 없으면 대부분의 명중이 miss 로 새서 "색칠이 안 되는" 것처럼 보인다.
##   · ProtoBullet 은 **반지름 6px 원형 Area2D** 다. body_entered 는 원의 테두리가 타일에
##     닿는 순간 터지므로, 그 시점의 총알 **중심은 타일 밖(최대 6px)** 에 있다.
##   · 이 타일셋의 타일은 16px 다 → 중심이 옆의 빈 셀에 떨어지는 일이 매우 흔하다.
##   · 게다가 총알은 프레임당 7.5~22px 씩 튀어 이동한다(초속 450~1350). 한 프레임 이동거리가
##     타일 한 칸보다 클 수 있어서, proto_bullet 의 "10px 앞을 한 번 더 본다" 보정으로는
##     빈 셀 두 번을 연달아 짚는 경우를 못 막는다.
##   → 그래서 여기서 반경 2칸(32px)까지 가까운 순으로 훑어 실제 타일을 찾아준다.
##     (proto_bullet 은 손대지 않는다 — 기존 zone_01/02 경로에 영향을 주지 않기 위해)
func _가까운_셀(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	if _찾기(layer, cell) != null:
		return cell
	var 최적 := cell
	var 최단 := 1e9
	for dy in range(-탐색_반경, 탐색_반경 + 1):
		for dx in range(-탐색_반경, 탐색_반경 + 1):
			if dx == 0 and dy == 0:
				continue
			var c := cell + Vector2i(dx, dy)
			if _찾기(layer, c) == null:
				continue
			var d := float(dx * dx + dy * dy)
			if d < 최단:
				최단 = d
				최적 = c
	return 최적

func _명중_처리(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	var p = _찾기(layer, cell)
	if p == null:
		return "miss"
	if p.고정 or p.회색:
		return "blocked"

	# 이미 칠해진 플랫폼
	if p.칠해짐:
		if color == p.진행색:
			return "wasted"                    # 같은 색 덧칠 = 낭비
		# 플레이어가 쏜 반대색은 회색으로 섞지 않고 마지막 색으로 전체를 덮는다.
		p.진행색 = color
		p.맞은 += 1
		_전체색칠(p, color)
		상태변경.emit()
		return "painted"

	# 아무 부분 칠도 없을 때 원래 타일과 같은 색을 쏘면 보이는 변화가 없다.
	if color == p.원래색 and p.진행.전체횟수() == 0:
		return "wasted"

	# ── 진행 누적 ──
	p.진행색 = color
	p.진행.명중(color, p.필요)
	p.맞은 = p.진행.전체횟수()

	_오버레이_준비(p)
	_시드_추가(p, cell, color)
	p.젖음 = 1.0

	if p.진행.완성가능(color, p.필요):
		_전체색칠(p, color)
		if not _큐.has(p):
			_큐.append(p)
		_유니폼_갱신(p)                         # 첫 프레임부터 올바른 마스크로 그려지게
		_애니_시작()
		상태변경.emit()
		return "painted"

	_목표반지름_갱신(p, false)
	_유니폼_갱신(p)
	_애니_시작()
	상태변경.emit()
	if not _큐.has(p):
		_큐.append(p)                           # 부분 칠도 E 회수와 자동 환급의 대상이다.
	return "progress"


func _전체색칠(p: 플랫폼, 색: int) -> void:
	p.칠해짐 = true
	p.진행색 = 색
	p.진행.비우기()
	_시드_비우기(p)
	p.바탕마스크 = 0.0 if 색 == p.원래색 else 1.0
	_오버레이_준비(p)
	p.젖음 = 1.0

# ── 잉크 번짐 표현 ──────────────────────────────────────────────────────────
## 반대색 타일을 통째로 찍어둔 오버레이 레이어를 만든다(없으면).
## 원본 레이어는 절대 수정하지 않는다 — 그래야 회수가 완벽하고, 마스크로 알파만
## 깎으므로 "타일 한 칸이 각지게 바뀌는" 느낌이 사라진다.
func _오버레이_준비(p: 플랫폼) -> void:
	if p.오버레이 != null and is_instance_valid(p.오버레이):
		return
	var ov := TileMapLayer.new()
	ov.name = "%s_%d" % [오버레이_접두어, p.레이어.get_child_count()]
	ov.tile_set = p.레이어.tile_set
	ov.enabled = true
	ov.collision_enabled = false               # 콜리전은 원본 레이어가 이미 갖고 있다
	ov.navigation_enabled = false
	ov.z_index = 1                             # 원본 레이어 바로 위
	var mat := ShaderMaterial.new()
	mat.shader = MASK_SHADER
	ov.material = mat
	# 오버레이를 원본 레이어의 자식으로 붙여 좌표계를 그대로 공유한다
	p.레이어.add_child(ov)
	p.오버레이 = ov
	# 이 플랫폼의 모든 칸에 "반대색" 타일을 찍어둔다 (보이는 범위는 셰이더 마스크가 결정)
	for c in p.셀:
		var 원 = p.원본[c]
		var 새좌표 := 반대색_좌표(p.레이어.tile_set, 원["src"], 원["atlas"])
		ov.set_cell(c, 원["src"], 새좌표, 원["alt"])

## 명중 지점을 씨앗으로 등록 (바운딩박스 UV 로 변환)
func _시드_추가(p: 플랫폼, cell: Vector2i, 색: int) -> void:
	var 크기 := p.최대 - p.최소 + Vector2i.ONE
	var uv := Vector2(
		(float(cell.x - p.최소.x) + 0.5) / float(maxi(크기.x, 1)),
		(float(cell.y - p.최소.y) + 0.5) / float(maxi(크기.y, 1)))
	if p.시드.size() >= 최대_시드:
		p.시드.remove_at(0)
		p.시드반지름.remove_at(0)
		p.시드목표.remove_at(0)
		p.시드색.remove_at(0)
		p.시드세기.remove_at(0)
	p.시드.append(uv)
	p.시드반지름.append(0.0)
	p.시드목표.append(0.0)
	p.시드색.append(색)
	p.시드세기.append(1.0)

func _시드_비우기(p: 플랫폼) -> void:
	p.시드 = PackedVector2Array()
	p.시드반지름 = PackedFloat32Array()
	p.시드목표 = PackedFloat32Array()
	p.시드색 = PackedInt32Array()
	p.시드세기 = PackedFloat32Array()

func _종횡비(p: 플랫폼) -> float:
	var 크기 := p.최대 - p.최소 + Vector2i.ONE
	return float(maxi(크기.x, 1)) / float(maxi(크기.y, 1))

## 이 반지름이면 플랫폼 전체가 덮인다
func _최대반지름(p: 플랫폼) -> float:
	var a := _종횡비(p)
	return sqrt(a * a + 1.0) + 0.05

## 진행률에 맞춰 각 씨앗의 목표 반지름을 다시 계산한다 (paint_platform.gd 와 같은 공식).
##  · 초반 = 면적 비례 원 → 조금씩 스며드는 느낌
##  · 마지막 한 방 = 전체 반지름으로 확 튀어 "완성됐다"는 쾌감
func _목표반지름_갱신(p: 플랫폼, 완성: bool) -> void:
	var n := p.시드.size()
	if n == 0:
		return
	var 색진행 := maxi(p.진행.횟수(ColorDefs.BLACK), p.진행.횟수(ColorDefs.WHITE))
	var 진행 := clampf(float(색진행) / float(maxi(p.필요, 1)), 0.0, 1.0)
	var a := _종횡비(p)
	var 면적반지름 := sqrt(maxf(진행, 0.0001) * a / PI) / sqrt(float(n))
	var 목표 := _최대반지름(p) if 완성 else lerpf(면적반지름, _최대반지름(p), pow(진행, 5.0))
	for i in n:
		p.시드목표[i] = 목표

func _애니_시작() -> void:
	set_process(true)

## 번짐 애니메이션은 CPU 에서 굴린다 — 저장·회수·자동테스트에서 "지금 몇 % 번졌나"를
## 정확히 알아야 하기 때문(paint_platform.gd 와 같은 이유).
func _process(delta: float) -> void:
	var 남음 := false
	for p in _플랫폼들:
		if p.오버레이 == null or not is_instance_valid(p.오버레이):
			continue
		var 이_플랫폼_남음 := false
		for i in p.시드반지름.size():
			var r: float = p.시드반지름[i]
			var t: float = p.시드목표[i]
			if absf(t - r) > 0.002:
				# 지수 감쇠 = 처음엔 빠르게 퍼지고 끝에서 살짝 붙는 잉크 느낌
				p.시드반지름[i] = lerpf(r, t, 1.0 - pow(0.0008, delta))
				이_플랫폼_남음 = true
			else:
				p.시드반지름[i] = t
		if p.젖음 > 0.0:
			p.젖음 = maxf(p.젖음 - delta * 1.25, 0.0)     # 약 0.8초에 걸쳐 마른다
			이_플랫폼_남음 = true
		if not p.칠해짐 and p.진행.전체횟수() > 0:
			var 변화: Dictionary = p.진행.진행(delta, p.필요)
			for i in p.시드세기.size():
				p.시드세기[i] = p.진행.알파(p.시드색[i])
			for 만료색 in 변화["만료"]:
				var 발수 := int(변화["만료"][만료색])
				_색_시드_지우기(p, int(만료색))
				p.맞은 = maxi(p.맞은 - 발수, 0)
				_환급(발수)
			var 완성색: int = 변화["완성색"]
			if 완성색 >= 0:
				_전체색칠(p, 완성색)
				이_플랫폼_남음 = true
			elif p.진행.전체횟수() == 0:
				_큐.erase(p)
				p.진행색 = -1
			이_플랫폼_남음 = p.진행.전체횟수() > 0
			상태변경.emit()
		if 이_플랫폼_남음:
			남음 = true
		_유니폼_갱신(p)
	if not 남음:
		set_process(false)


func _색_시드_지우기(p: 플랫폼, 색: int) -> void:
	for i in range(p.시드색.size() - 1, -1, -1):
		if p.시드색[i] != 색:
			continue
		p.시드.remove_at(i)
		p.시드반지름.remove_at(i)
		p.시드목표.remove_at(i)
		p.시드색.remove_at(i)
		p.시드세기.remove_at(i)

func _유니폼_갱신(p: 플랫폼) -> void:
	if p.오버레이 == null or not is_instance_valid(p.오버레이):
		return
	var mat := p.오버레이.material as ShaderMaterial
	if mat == null:
		return
	var 타일 := Vector2(p.레이어.tile_set.tile_size)
	var 시드8 := PackedVector2Array()
	var 반지름8 := PackedFloat32Array()
	var 색8 := PackedInt32Array()
	var 세기8 := PackedFloat32Array()
	for i in 최대_시드:
		시드8.append(p.시드[i] if i < p.시드.size() else Vector2.ZERO)
		반지름8.append(p.시드반지름[i] if i < p.시드반지름.size() else 0.0)
		색8.append(p.시드색[i] if i < p.시드색.size() else p.원래색)
		세기8.append(p.시드세기[i] if i < p.시드세기.size() else 0.0)
	# ★셰이더는 월드 좌표로 계산한다 (TileMapLayer 가 쿼드런트별 CanvasItem 으로 쪼개 그리므로
	#   레이어 로컬 좌표를 넘기면 마스크가 어긋나 아예 투명해진다 — 실제로 그 버그를 겪었다)
	mat.set_shader_parameter("origin_world", p.레이어.to_global(Vector2(p.최소) * 타일))
	mat.set_shader_parameter("size_world",
		Vector2(p.최대 - p.최소 + Vector2i.ONE) * 타일 * p.레이어.global_scale)
	mat.set_shader_parameter("aspect", _종횡비(p))
	mat.set_shader_parameter("seeds", 시드8)
	mat.set_shader_parameter("seed_r", 반지름8)
	mat.set_shader_parameter("seed_c", 색8)
	mat.set_shader_parameter("seed_a", 세기8)
	mat.set_shader_parameter("seed_count", p.시드.size())
	mat.set_shader_parameter("original_color", p.원래색)
	mat.set_shader_parameter("base_mask", p.바탕마스크)
	mat.set_shader_parameter("wet_amount", p.젖음)
	mat.set_shader_parameter("paint_color", 0 if p.진행색 == ColorDefs.BLACK else 1)
	mat.set_shader_parameter("locked", 1.0 if p.회색 else 0.0)

# ── 회색 (영구) ─────────────────────────────────────────────────────────────
## 회색 전용 타일이 타일셋에 없으므로, 오버레이를 꽉 덮고 셰이더의 locked 로 대비를 죽인다.
## (예전엔 런타임에 대체 타일을 만들어 modulate 했는데, 그 방식은 TileSet 리소스를
##  건드려 저장될 위험이 있었고 각진 느낌도 그대로였다)
func _회색으로(p: 플랫폼) -> void:
	p.회색 = true
	_큐.erase(p)                               # 영구 → 회수 대상에서 제외
	_오버레이_준비(p)
	if p.시드.is_empty():
		_시드_추가(p, (p.최소 + p.최대) / 2, ColorDefs.BLACK)
	for i in p.시드목표.size():
		p.시드목표[i] = _최대반지름(p)
	p.젖음 = 1.0
	_애니_시작()

# ── 회수 (E) ────────────────────────────────────────────────────────────────
## 가장 먼저 칠한 플랫폼부터 원래 모습으로 되돌린다. 회색은 큐에 없으므로 안 돌아온다.
## 원본 레이어를 한 번도 수정하지 않았으므로, 오버레이만 지우면 완벽하게 복구된다.
func 되돌리기() -> bool:
	while not _큐.is_empty():
		var p = _큐.pop_front()
		# ★[2026-08-22] 타일이 아닌 노드는 자기가 알아서 되돌린다.
		#   회색이면 `되돌리기()` 가 false 를 주므로 그냥 다음 항목으로 넘어간다.
		if p is 외부칠:
			if not is_instance_valid(p.노드) or not p.노드.has_method("되돌리기"):
				continue
			if not p.노드.되돌리기():
				continue
			_환급(int(p.맞은))
			상태변경.emit()
			return true
		if p.회색:
			continue
		if p.오버레이 != null and is_instance_valid(p.오버레이):
			p.오버레이.queue_free()
		# ★[2026-08-17] 그 플랫폼에 들어갔던 발을 통째로 돌려준다 (규칙 4).
		#   `_플랫폼_비우기` 가 `맞은` 을 0 으로 만들기 **전에** 읽어야 한다.
		_환급(int(p.맞은))
		_플랫폼_비우기(p)
		상태변경.emit()
		return true
	return false


## ★[2026-08-22 신규] 타일이 아닌 **칠할 수 있는 노드**의 명중 처리.
##
## ▣ 왜 필요한가
##   `on_hit()` 은 TileMapLayer 의 셀만 받는다. 하수도 장애물들은 독립 노드라
##   여기로 못 들어왔고, 그래서 `proto_bullet.gd` 가 "못 맞혔다"로 처리해
##   **총을 쏴도 아무 일도 안 일어났다**(2026-08-22 stage_2-1 에서 실제로 겪음).
##
## ▣ 규칙은 `페인트_코어.명중_처리()` 를 그대로 따른다
##   같은 장애물이 스마트월드(월드.gd)와 stage_lab 두 계열에서 **똑같이** 동작해야
##   레벨 디자이너가 어느 씬에 두든 같은 결과를 얻는다.
##     painted / progress → 회수줄에 쌓인다 (E 로 회수 가능)
##     wasted / blocked   → 페인트 1발 환급
##     mixed_gray         → 장애물 상호작용으로 회색이 된 경우에만 줄에서 빼고 발수를 잠근다
func 노드_명중(대상: Node, 색: int, 월드좌표: Vector2) -> String:
	_비행_해제()                       # 이 발은 결판났다 (HUD 표시용 계수)

	if 대상 == null or not is_instance_valid(대상) or not 대상.has_method("명중"):
		_환급(1)
		return "miss"

	var 결과: String = 대상.명중(색, 월드좌표)

	match 결과:
		"painted", "progress":
			# 같은 노드를 여러 발 맞히면 항목 하나에 발수를 쌓는다
			# (E 한 번에 그 노드에 들어간 발이 통째로 돌아와야 규칙 4와 맞다).
			var 항목: 외부칠 = _외부_찾기(대상)
			if 항목 == null:
				항목 = 외부칠.new()
				항목.노드 = 대상
				_큐.append(항목)
			항목.맞은 += 1
			항목.좌표 = 월드좌표          # HUD 의 E 마커가 마지막으로 칠한 자리에 뜬다
		"mixed_gray":
			# 플레이어 총알 대상은 이 값을 내지 않는다. 장애물 상호작용 회색만 잠근다.
			var 기존: 외부칠 = _외부_찾기(대상)
			var 들어간 := 0
			if 기존 != null:
				들어간 = 기존.맞은
				_큐.erase(기존)
			_잠긴_발수 += 들어간 + 1      # 원래 색 발수 + 방금 덮은 1발
			if not _외부_회색.has(대상):
				_외부_회색.append(대상)
		"wasted", "blocked":
			_환급(1)

	명중됨.emit(결과, 색, 월드좌표)
	상태변경.emit()
	return 결과


func _외부_찾기(대상: Node) -> 외부칠:
	for p in _큐:
		if p is 외부칠 and p.노드 == 대상:
			return p
	return null


## ★[2026-08-17] 스테이지 재시도(사망) — 칠한 것·진행 중·회색을 **전부** 되돌리고
## 페인트를 모두 회수한다. `페인트_코어.리셋()` 과 같은 규칙이다.
##
## ⚠ 탄약만 채우고 지형을 남기면 **죽을 때마다 페인트가 공짜로 생긴다.**
##   반대로 지형만 되돌리고 탄약을 안 채우면 몇 번 죽는 것만으로 탄약이 말라
##   스테이지를 깰 수 없게 된다. 둘은 반드시 같이 가야 한다.
func 리셋() -> void:
	for p in _플랫폼들:
		_플랫폼_비우기(p)
	# ★[2026-08-22] 외부 노드는 `강제_초기화()` 로 되돌린다 — `되돌리기()` 는 회색을
	#   거부하므로, 그것만 쓰면 회색으로 굳은 장애물이 사망 후에도 남는다.
	#   (`페인트_코어.리셋()` 이 `_회색_목록` 을 따로 도는 것과 같은 이유다.)
	for p in _큐:
		if p is 외부칠 and is_instance_valid(p.노드) and p.노드.has_method("강제_초기화"):
			p.노드.강제_초기화()
	# 회색으로 굳은 것은 회수줄에서 빠져 있으므로 따로 훑어야 한다.
	for n in _외부_회색:
		if is_instance_valid(n) and n.has_method("강제_초기화"):
			n.강제_초기화()
	_외부_회색.clear()
	_큐.clear()
	탄약_리셋()
	상태변경.emit()
	_애니_시작()


## 플랫폼 하나를 손대기 전 상태로. 원본 레이어는 건드리지 않으므로
## 우리가 얹은 오버레이만 치우면 완전히 되돌아간다.
func _플랫폼_비우기(p: 플랫폼) -> void:
	if p.오버레이 != null and is_instance_valid(p.오버레이):
		p.오버레이.queue_free()
	p.오버레이 = null
	_시드_비우기(p)
	p.진행.비우기()
	p.젖음 = 0.0
	p.맞은 = 0
	p.진행색 = -1
	p.칠해짐 = false
	p.회색 = false
	p.바탕마스크 = 0.0

## PaintSystem(v2) 과 같은 이름 — proto_gun 의 기존 호출 경로도 그대로 동작한다.
func recover(_layer: TileMapLayer = null) -> bool:
	return 되돌리기()

# ── 조회 (HUD·테스트용) ─────────────────────────────────────────────────────
func 큐_크기() -> int:
	return _큐.size()

func 플랫폼_수() -> int:
	return _플랫폼들.size()

## 이 색으로 쏘면 앞으로 몇 발 더 필요한가. 칠할 수 없으면 -1.
func remaining_hits(layer: TileMapLayer, cell: Vector2i, color: int) -> int:
	var p = _찾기(layer, cell)
	if p == null or p.고정 or p.회색 or p.칠해짐:
		return -1
	if color == p.원래색 and p.진행.전체횟수() == 0:
		return -1
	return p.진행.남은횟수(color, p.필요)

# ── [2026-08-17 추가] 탄약 ──────────────────────────────────────────────────
# `총.gd`(스마트월드)가 `페인트코어` 에게 묻는 것과 **같은 이름**을 쓴다.
# 그래서 `proto_gun` 은 덕 타이핑 한 줄만 얹으면 되고, 탄약이 없는 경로
# (zone_01/02/world_1 의 PaintSystem)는 이 함수들이 없으므로 예전처럼 그냥 쏜다.

## 이 스테이지가 탄약을 쓰나. 0 이하면 무제한(예전 동작).
func 탄약을_쓰나() -> bool:
	return 최대_탄약 > 0


func 쏠_수_있나() -> bool:
	return (not 탄약을_쓰나()) or 남은_탄약 > 0


## 발사 순간 1발 차감. 명중 결과에 따라 `_탄약_정산()` 이 되돌려줄 수 있다.
func 발사_소모() -> bool:
	if not 탄약을_쓰나():
		return true
	if 남은_탄약 <= 0:
		return false
	남은_탄약 -= 1
	_비행중 += 1                      # 착탄할 때까지 HUD 는 이 발을 계속 보여준다
	탄약_변경.emit(남은_탄약, 최대_탄약)
	return true


## 총알이 아무것도 못 맞히고 사라졌을 때 (proto_bullet 이 부른다).
## 빗나간 페인트는 손해가 아니다 — "맞혀야만 잠긴다" 가 규칙이다.
func 빗나감() -> void:
	_비행_해제()
	if 탄약을_쓰나():
		_환급(1)


## 스테이지 시작 · 사망 재시도. 잠긴 발까지 전부 돌아온다.
func 탄약_리셋() -> void:
	_잠긴_발수 = 0
	# 씬을 갈아끼우면 날아가던 총알이 결과를 못 알리고 사라진다 → 여기서 털어준다.
	_비행중 = 0
	남은_탄약 = 최대_탄약
	탄약_변경.emit(남은_탄약, 최대_탄약)


func 잠긴_발수() -> int:
	return _잠긴_발수


## 지금 날아가는 중인 발 수. **HUD 표시 전용**.
func 비행중() -> int:
	return _비행중


## 발 하나가 결판났다. 0 아래로 안 내려가게 막는다
## (도구·테스트가 `발사_소모` 없이 `on_hit` 을 부를 수 있다).
func _비행_해제() -> void:
	_비행중 = maxi(_비행중 - 1, 0)


func _환급(수량: int) -> void:
	if 수량 <= 0 or not 탄약을_쓰나():
		return
	남은_탄약 = mini(남은_탄약 + 수량, 최대_탄약)
	탄약_변경.emit(남은_탄약, 최대_탄약)


# ── [2026-08-17 추가] 페인트 HUD 전용 조회 ─────────────────────────────────
# 전부 **읽기만** 한다. 색칠 규칙에 관여하지 않으므로 기존 검사에 영향이 없다.
# 이 시스템에는 탄약(전역 자원)이 없다 — 그래서 HUD 는 탄약 줄을 안 그리고
# **회수 대기 묶음 · 회색 개수 · E 마커 · 호버 발수**만 보여준다.

## 회수 대기줄 사본. 앞이 먼저 칠한 것(FIFO).
## 원소 = { "대상": 플랫폼, "발수": int, "좌표": Vector2 }
## ★회색 플랫폼은 큐에 남아 있어도 `되돌리기()` 가 건너뛰므로 여기서도 뺀다.
##   (안 빼면 "E 를 누르면 이게 돌아온다"고 거짓말하는 마커가 뜬다)
func 회수줄_요약() -> Array:
	var 결과: Array = []
	for p in _큐:
		if p == null or not is_instance_valid(p) or p.회색:
			continue
		결과.append({ "대상": p, "발수": maxi(int(p.맞은), 1), "좌표": 대상_좌표(p) })
	return 결과


## 칠하는 중이지만 아직 완성이 안 된 플랫폼들. 원소 형식은 `회수줄_요약()` 과 같다.
## ★이 시스템은 완성된 것만 `_큐` 에 넣는다. `stage_1-1` 은 플랫폼 하나에 11발이
##   필요하므로, 이게 없으면 HUD 가 11발 동안 아무 반응도 안 한다.
func 진행줄_요약() -> Array:
	var 결과: Array = []
	for p in _플랫폼들:
		if p.고정 or p.회색 or p.칠해짐 or p.맞은 <= 0:
			continue
		결과.append({ "대상": p, "발수": int(p.맞은), "좌표": 대상_좌표(p) })
	return 결과


## 그 플랫폼에 지금까지 들어간 발 수.
func 대상_발수(대상: Variant) -> int:
	if 대상 == null or not is_instance_valid(대상):
		return 0
	return maxi(int(대상.맞은), 0)


## 마커를 띄울 월드 좌표 = 플랫폼 바운딩박스의 한가운데.
func 대상_좌표(대상: Variant) -> Vector2:
	if 대상 == null or not is_instance_valid(대상):
		return Vector2.ZERO
	# ★[2026-08-22] 외부 노드는 레이어도 셀도 없다 → 명중 지점을 그대로 쓴다.
	if 대상 is 외부칠:
		return 대상.좌표
	var layer: TileMapLayer = 대상.레이어
	if layer == null or not is_instance_valid(layer):
		return Vector2.ZERO
	# `map_to_local` 은 **셀의 중심**을 준다 → 양 끝 셀 중심의 중점이 곧 바운딩박스 중심.
	# (타일 크기를 직접 곱하지 않으므로 타일셋이 바뀌어도 안 깨진다)
	var a := layer.map_to_local(대상.최소)
	var b := layer.map_to_local(대상.최대)
	return layer.to_global((a + b) * 0.5)


## 회색이 된 플랫폼 수. 발 단위 자원이 없으니 "잠긴 발수" 대신 이 개수를 보여준다.
func 회색_수() -> int:
	var n := 0
	for p in _플랫폼들:
		if p.회색:
			n += 1
	# ★[2026-08-22] 회색으로 굳은 외부 노드(투명블럭 등)도 같이 센다.
	for 노드 in _외부_회색:
		if is_instance_valid(노드):
			n += 1
	return n


## 이 월드 좌표 아래에 있는 플랫폼. 없으면 null.
## 등록된 레이어마다 셀로 환산해 찾는다 — 플랫폼을 전부 훑는 것보다 싸고 정확하다.
## ⚠ 레이어 목록을 **캐시한다.** stage_1-1, 1-2 는 플랫폼이 수백 개라
##   호출할 때마다 전부 훑으면 마우스를 움직이는 동안 프레임이 눈에 띄게 떨어진다.
func 대상_아래(월드: Vector2) -> Variant:
	if _레이어_캐시.is_empty():
		for p in _플랫폼들:
			var l: TileMapLayer = p.레이어
			if l != null and is_instance_valid(l) and not _레이어_캐시.has(l):
				_레이어_캐시.append(l)
	for layer in _레이어_캐시:
		if not is_instance_valid(layer):
			continue
		var cell: Vector2i = layer.local_to_map(layer.to_local(월드))
		var 찾음 = _찾기(layer, cell)
		if 찾음 != null:
			return 찾음
	return null


## 자동 검출 결과 요약 (레벨 검증용)
func 통계() -> Dictionary:
	var 칠함 := 0
	var 회색 := 0
	var 고정 := 0
	for p in _플랫폼들:
		if p.고정: 고정 += 1
		elif p.회색: 회색 += 1
		elif p.칠해짐: 칠함 += 1
	return {
		"전체": _플랫폼들.size(), "칠함": 칠함, "회색": 회색, "고정": 고정,
		"칠가능": _플랫폼들.size() - 고정,
	}
