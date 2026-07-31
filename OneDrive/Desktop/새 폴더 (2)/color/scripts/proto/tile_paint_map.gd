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
##   · 진행 중에 다른 색이 오면 회색이 아니라 "새 색으로 리셋"
##   · 완성된 플랫폼에 반대색 → 영구 회색 (회수 큐에서 제외)
##   · E 회수 = 색과 무관하게, 완성 여부와도 무관하게 "가장 먼저 손댄 플랫폼"부터
##     FIFO 로 원래 타일로 복구. **진행 중(필요횟수를 아직 못 채운) 플랫폼도 첫 명중 순간
##     바로 큐에 들어가므로 회수 대상이다** — 완성된 것만 되돌릴 수 있는 게 아니다.
##
## ▣ 탄약(오토로드 "탄약", ammo_manager.gd)과의 연결
##   · 플랫폼이 "완성"되는 순간(= painted 또는 회색으로 덮이는 mixed_gray) 1발씩 소모.
##     그래서 회색 하나는 처음 칠할 때 1발 + 회색으로 덮을 때 1발 = 총 2발.
##   · 잔량이 없으면 완성을 막고 "blocked" 를 돌려준다(고정지형/회색과 결과 문자열을 공유 —
##     어차피 둘 다 "지금은 칠해지지 않았다"는 뜻이라 호출부(HUD)는 구분할 필요가 없다).
##   · E 로 되돌리면(되돌리기) 그 플랫폼 몫 1발을 즉시 환급.
##   · 회색은 스테이지를 넘어가야 풀리는데, 스테이지 전환 자체가 씬을 통째로 새로 로드하므로
##     이전 TilePaintMap(회색 포함)은 자동으로 사라진다. stage_lab.gd 가 다음 스테이지 진입 시
##     탄약.리셋() 을 불러 잔량을 최대치로 채우는 것으로 "자동 회수"를 대신한다.
##
## ▣ proto_bullet / proto_gun 과의 연결
##   PaintSystem(v2) 과 **같은 메서드 이름**(on_hit / recover / 되돌리기)을 쓴다.
##   그래서 총알·총 코드를 고치지 않고 그대로 끼울 수 있다(덕 타이핑).
## ============================================================================
class_name TilePaintMap

signal 상태변경                                     ## HUD 갱신용
signal 명중됨(결과: String, 색: int, 월드좌표: Vector2)

## 한 버전(384px)이 차지하는 칸 수 = 384 / 16
const 반칸: int = 24
## 텍스처 파일명 → 흑/백이 나뉘는 축 (0 = X, 1 = Y)
const 축_by_파일 := {
	"brick.png": 0,
	"grass.png": 0,
	"rock.png": 0,
	"soil.png": 0,
	"wood.png": 1,
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
	var 젖음: float = 0.0
	var 최소: Vector2i = Vector2i.ZERO                          ## 바운딩박스(칸)
	var 최대: Vector2i = Vector2i.ZERO

## 내부 클래스(플랫폼)를 담으므로 타입 힌트 없는 Array 를 쓴다.
var _플랫폼들: Array = []
var _셀_찾기: Dictionary = {}          ## "레이어경로|셀" → 플랫폼
var _큐: Array = []                    ## 칠한 순서 (앞이 가장 오래된 것)

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
## 반환값: progress / painted / wasted / mixed_gray / blocked / miss
## 명중 지점 보정 반경(칸). 아래 이유로 2칸(=32px)이 필요하다.
const 탐색_반경: int = 2

func on_hit(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	var 실제셀 := _가까운_셀(layer, cell)
	var 결과 := _명중_처리(layer, 실제셀, color)
	var 타일 := Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
	var 월드 := layer.to_global((Vector2(실제셀) + Vector2(0.5, 0.5)) * 타일)
	명중됨.emit(결과, color, 월드)
	return 결과

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
		if not 탄약.소모(1):                    # 회색화도 "완성 이벤트" → 1발 (그래서 회색=총 2발)
			return "blocked"
		_회색으로(p)
		상태변경.emit()
		return "mixed_gray"

	# 아직 원래색인 플랫폼에 같은 색을 쏘면 아무 의미가 없다
	if color == p.원래색:
		return "wasted"

	# ── 진행 누적 ──
	if p.맞은 > 0 and p.진행색 != color:
		p.맞은 = 0                             # 다른 색이 오면 새 색으로 리셋 (zone_04 규칙 3)
		_시드_비우기(p)
	p.진행색 = color
	var 새로_손댐 := p.맞은 == 0              # ★완성 전이라도 "손댄" 순간 바로 회수 큐에 넣는다
	p.맞은 += 1
	if 새로_손댐 and not _큐.has(p):
		_큐.append(p)

	_오버레이_준비(p)
	_시드_추가(p, cell)
	p.젖음 = 1.0

	if p.맞은 >= p.필요:
		if not 탄약.소모(1):                    # 플랫폼 완성 = 1발 (필요횟수와 무관하게 완성 시점에 1발)
			return "blocked"
		p.칠해짐 = true
		_목표반지름_갱신(p, true)               # 마지막 한 방 = 전체로 확 번짐
		_유니폼_갱신(p)                         # 첫 프레임부터 올바른 마스크로 그려지게
		_애니_시작()
		상태변경.emit()
		return "painted"

	_목표반지름_갱신(p, false)
	_유니폼_갱신(p)
	_애니_시작()
	상태변경.emit()
	return "progress"

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
func _시드_추가(p: 플랫폼, cell: Vector2i) -> void:
	var 크기 := p.최대 - p.최소 + Vector2i.ONE
	var uv := Vector2(
		(float(cell.x - p.최소.x) + 0.5) / float(maxi(크기.x, 1)),
		(float(cell.y - p.최소.y) + 0.5) / float(maxi(크기.y, 1)))
	if p.시드.size() >= 최대_시드:
		p.시드.remove_at(0)
		p.시드반지름.remove_at(0)
		p.시드목표.remove_at(0)
	p.시드.append(uv)
	p.시드반지름.append(0.0)
	p.시드목표.append(0.0)

func _시드_비우기(p: 플랫폼) -> void:
	p.시드 = PackedVector2Array()
	p.시드반지름 = PackedFloat32Array()
	p.시드목표 = PackedFloat32Array()

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
	var 진행 := clampf(float(p.맞은) / float(maxi(p.필요, 1)), 0.0, 1.0)
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
		if 이_플랫폼_남음:
			남음 = true
		_유니폼_갱신(p)
	if not 남음:
		set_process(false)

func _유니폼_갱신(p: 플랫폼) -> void:
	if p.오버레이 == null or not is_instance_valid(p.오버레이):
		return
	var mat := p.오버레이.material as ShaderMaterial
	if mat == null:
		return
	var 타일 := Vector2(p.레이어.tile_set.tile_size)
	var 시드8 := PackedVector2Array()
	var 반지름8 := PackedFloat32Array()
	for i in 최대_시드:
		시드8.append(p.시드[i] if i < p.시드.size() else Vector2.ZERO)
		반지름8.append(p.시드반지름[i] if i < p.시드반지름.size() else 0.0)
	# ★셰이더는 월드 좌표로 계산한다 (TileMapLayer 가 쿼드런트별 CanvasItem 으로 쪼개 그리므로
	#   레이어 로컬 좌표를 넘기면 마스크가 어긋나 아예 투명해진다 — 실제로 그 버그를 겪었다)
	mat.set_shader_parameter("origin_world", p.레이어.to_global(Vector2(p.최소) * 타일))
	mat.set_shader_parameter("size_world",
		Vector2(p.최대 - p.최소 + Vector2i.ONE) * 타일 * p.레이어.global_scale)
	mat.set_shader_parameter("aspect", _종횡비(p))
	mat.set_shader_parameter("seeds", 시드8)
	mat.set_shader_parameter("seed_r", 반지름8)
	mat.set_shader_parameter("seed_count", p.시드.size())
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
		_시드_추가(p, (p.최소 + p.최대) / 2)
	for i in p.시드목표.size():
		p.시드목표[i] = _최대반지름(p)
	p.젖음 = 1.0
	_애니_시작()

# ── 회수 (E) ────────────────────────────────────────────────────────────────
## 가장 먼저 "손댄"(완성이든 진행 중이든) 플랫폼부터 원래 모습으로 되돌린다.
## 회색은 큐에 없으므로 안 돌아온다.
## 원본 레이어를 한 번도 수정하지 않았으므로, 오버레이만 지우면 완벽하게 복구된다.
func 되돌리기() -> bool:
	while not _큐.is_empty():
		var p = _큐.pop_front()
		if p.회색:
			continue
		var 완성했었나 := p.칠해짐          # 진행 중이었으면 탄약을 쓴 적이 없으니 환급도 없다
		if p.오버레이 != null and is_instance_valid(p.오버레이):
			p.오버레이.queue_free()
		p.오버레이 = null
		_시드_비우기(p)
		p.젖음 = 0.0
		p.맞은 = 0
		p.진행색 = -1
		p.칠해짐 = false
		if 완성했었나:
			탄약.환급(1)                        # 완성할 때 쓴 1발을 즉시 돌려준다
		상태변경.emit()
		return true
	return false

## PaintSystem(v2) 과 같은 이름 — proto_gun 의 기존 호출 경로도 그대로 동작한다.
func recover(_layer: TileMapLayer = null) -> bool:
	return 되돌리기()

# ── 조회 (HUD·테스트용) ─────────────────────────────────────────────────────
func 큐_크기() -> int:
	return _큐.size()

func 플랫폼_수() -> int:
	return _플랫폼들.size()

## 지금 이 셀을 밟았을 때 죽는 색인가 (stage_lab 의 사망 판정이 사용 — paint_platform.gd 의
## 반대색인가() 와 같은 이름·의미).
## ⚠ PaintPlatform 과 달리 "무색" 개념이 없다 — 타일은 안 칠해도 원래색(흑/백)을 갖고 있어서
##   칠하기 전에도 위험할 수 있다. 회색·규칙을 모르는 셀(플랫폼이 없음)은 누구에게나 안전.
func 반대색인가(layer: TileMapLayer, cell: Vector2i, 플레이어색: int) -> bool:
	var p = _찾기(layer, cell)
	if p == null or p.회색:
		return false
	var 색: int = p.진행색 if p.칠해짐 else p.원래색
	return 색 != 플레이어색

## 이 색으로 쏘면 앞으로 몇 발 더 필요한가. 칠할 수 없으면 -1.
func remaining_hits(layer: TileMapLayer, cell: Vector2i, color: int) -> int:
	var p = _찾기(layer, cell)
	if p == null or p.고정 or p.회색 or p.칠해짐 or color == p.원래색:
		return -1
	if p.맞은 > 0 and p.진행색 == color:
		return p.필요 - p.맞은
	return p.필요

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
