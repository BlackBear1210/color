@tool
extends Node2D
## ============================================================================
## [2026-10-04 Claude] ★시안★ 넓은 물 출수구 — 넓은 물도 **관 입구에서** 나오게
## ----------------------------------------------------------------------------
## ▣ 왜 (도형님: "배관 입구는 작은데 물의 너비는 큰 경우가 많아")
##   하수도 주철 배관은 지름 40 고정(`하수도_주철배관.gd`). 물은 64~576 을 쓴다.
##   넓은 물 위에 관 끝만 있으면 "관 아래 허공에서 넓은 물막이 시작" 하는 것처럼 보인다.
##   1 차 시안(슬롯관 · 수조 · 노즐줄)은 기각(2026-10-05): **"배관 입구에서 나오는 것이 아니야."**
##   → 2 차 시안:
##     큰관   : 관 안지름 = 물 폭. 관 자체를 키운다 — 얇은 물에선 "관 입구를 조금씩 조정" 과 같은 규칙이다
##     벽관   : 뒷벽에서 정면으로 나온 큰 관 입구(하수 배출관) — 관이 반쯤 차서 흐르고, 물이 아래 입술을 넘쳐 떨어진다.
##              입구 지름 = 물 폭. 위 반원은 어두운 관 속, 아래 반원은 떨어지는 물이 덮는다
##     천장구 : 1 차 시안 중 기각되지 않은 것 — 비교용
##
## ▣ 원점 = 물 윗변 가운데(유체 노드 원점과 같다). y 0 = 물 윗변, 위가 −.
## ▣ 그림뿐이다 — 충돌 없음 · 색 규칙 없음 · 총알 통과(배관과 같다). 물 판정은 그대로.
## ⚠ 부품 그림 규격은 `tools/생성_출수구_시안.py` 와 같아야 한다. 그림은 그 도구가 굽는다(손으로 고치지 말 것).
##   큰관·벽관 그림은 **물 폭마다 한 벌**(시안: 64 96 192 224 576). 없는 폭이면 그 도구에 폭을 주고 다시 굽는다.
## ============================================================================

const 폴더 := "res://assets/textures/obstacles/outlet/cast_iron_draft/"
const 관스크립트 := "res://scripts/스마트월드/하수도_주철배관.gd"
const 굽기배율 := 2.0
const 시안들 := ["큰관", "벽관", "타원관", "돌출관", "돌출타원", "관2개", "관3개", "관4개", "천장구"]
## [2026-10-07] 관 여러 개 — 도형님: "576 을 제외하곤 B 를 써도 어색하지 않은데, 576 이 문제야".
##   576 은 플레이어 키(≈100)의 6 배 — 관 하나로 내면 관이 아니라 터널이 된다. 실제 하수 배출구도 넓은 물은
##   **관 여러 개가 나란히**(다연 배수관) 낸다 → 물 하나(판정·밸브 그대로) 위에 돌출관 N 개를 붙여 그린다.
##   관 한 개 몫 = 폭 / N. 이웃 관 테가 맞닿게 안지름 = 몫 − 2 × 테.
const 관줄_개수 := {"관2개": 2, "관3개": 3, "관4개": 4}
## [2026-10-07] 벽관 변형 — 도형님: "넓은 곳은 B 가 좋아 보이긴 한데 헷갈리네". 검은 반원판이 크고(576 → 288)
##   테가 납작한 고리뿐이라 관 끝인지 벽 구멍인지 애매했다 → 입구를 눌러(타원) 검은 부분을 반으로 / 관 몸통이 벽에서 나와 보이게(돌출).
##   모양 → 그림 이름 앞붙이(굽는 도구 outfall2 의 종류)
const 벽관_종류 := {"벽관": "", "타원관": "e_", "돌출관": "p_", "돌출타원": "pe_"}

## 큰관 — 위쪽 끝은 천장 속으로 이만큼 들어간다(지금 하수도 급수관이 천장 위 128 에서 내려오는 것과 같게)
const 큰관_천장속 := 128.0
## 천장구: 안쪽은 천장 속으로 이만큼 더 들어간다 · 인방 12 · 문설주 14
const 천장구_속 := 48.0
const 인방 := 12.0
const 설주 := 14.0

@export_enum("큰관", "벽관", "타원관", "돌출관", "돌출타원", "관2개", "관3개", "관4개", "천장구") var 모양: String = "큰관":
	set(v): 모양 = v; _z_맞추기(); queue_redraw()
@export var 폭: float = 192.0:
	set(v): 폭 = v; queue_redraw()
## 물 윗변에서 천장까지 거리(0 = 물이 천장에 붙어 있다 · −1 = 위에 천장 없음). `물에_맞추기` 가 잰다.
@export var 천장_거리: float = 0.0:
	set(v): 천장_거리 = v; queue_redraw()
## 관 속 물·천장구 물빛 색(물 색에 맞춘다)
@export var 물빛: Color = Color(0.86, 0.87, 0.88)

static var _그림들: Dictionary = {}


static func 시안_목록() -> Array:
	return 시안들


## 부품 = 그림 + 노멀맵(있으면) → 벽등 빛이 관 둥근 면을 따라 흐른다(하수도_주철배관 과 같다)
static func _부품(이름: String) -> Texture2D:
	if not _그림들.has(이름):
		var 길 := 폴더 + 이름 + ".png"
		if not ResourceLoader.exists(길):
			push_error("출수구 시안: 그림 없음 %s — tools/생성_출수구_시안.py 에 폭을 주고 다시 굽는다" % 길)
			_그림들[이름] = null
		elif ResourceLoader.exists(폴더 + 이름 + "_n.png"):
			var t := CanvasTexture.new()
			t.diffuse_texture = load(길)
			t.normal_texture = load(폴더 + 이름 + "_n.png")
			t.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			_그림들[이름] = t
		else:
			_그림들[이름] = load(길)
	return _그림들[이름]


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_z_맞추기()
	queue_redraw()


## 벽관은 물 **뒤**(물이 입구 아래 반을 덮고 떨어진다) · 나머지는 물 위(관 입구가 물 윗변을 덮는다)
func _z_맞추기() -> void:
	z_index = -1 if 벽관_종류.has(모양) or 관줄_개수.has(모양) else 6


## ----------------------------------------------------------------------------
## 물 노드에 맞춰 자리·폭을 잡고, 밸브 같은 장치에 이어진 원래 관이면 이 부품 옆구리로 다시 잇는다.
##   원래관은 건드리지 않는다(숨기는 것은 부르는 쪽 몫).
##   장치와 안 이어진 급수관(천장에서 내려오던 40 관)은 이 부품이 대신한다 → 새로 잇지 않는다.
## 돌려주는 값: false = 이 자리에 맞지 않는 시안(천장구인데 위에 천장이 없다)
## ----------------------------------------------------------------------------
func 물에_맞추기(물: Node2D, 시안: String, 원래관: Node2D = null) -> bool:
	모양 = 시안
	global_position = 물.global_position
	var 크기: Vector2 = 물.get("크기")
	폭 = 크기.x
	match int(물.get("색")):
		0: 물빛 = Color(0.16, 0.16, 0.17)
		2: 물빛 = Color(0.52, 0.52, 0.53)
		_: 물빛 = Color(0.86, 0.87, 0.88)
	천장_거리 = _천장까지()
	if 모양 == "천장구" and 천장_거리 < 0.0:
		return false
	for c in get_children():
		c.queue_free()
	if 원래관 != null:
		var 시작: NodePath = 원래관.get("시작_장치")
		var 장치: Node = null if 시작.is_empty() else 원래관.get_node_or_null(시작)
		if 장치 != null:
			var 경로 := PackedVector2Array()
			for p in 원래관.get("점들"):
				경로.append(원래관.to_global(p) - global_position)
			_옆으로_잇기(경로, 장치)
	queue_redraw()
	return true


## 물 윗변 가운데·양끝에서 위로 쏴 천장(물리 몸체)까지 거리. 300 안에 없으면 −1.
func _천장까지() -> float:
	var 공간 := get_world_2d().direct_space_state
	var 가장 := -1.0
	for dx in [-폭 * 0.5 + 8.0, 0.0, 폭 * 0.5 - 8.0]:
		# 물 윗변이 천장에 딱 붙어 있으면 윗변에서 쏘면 몸체 안에서 출발해 못 잡는다 → 4 아래에서 쏜다
		var a := global_position + Vector2(dx, 4.0)
		var q := PhysicsRayQueryParameters2D.create(a, a + Vector2(0, -300))
		q.collide_with_areas = false
		var r := 공간.intersect_ray(q)
		if r.is_empty():
			return -1.0
		가장 = maxf(가장, maxf(0.0, a.y - (r["position"] as Vector2).y - 4.0))
	return 가장


## 원래 경로 [.., A, B, 끝] 에서 A→B 가 가로 구간이면: 끝을 버리고 B 를 이 부품의 옆구리로 옮긴다(높이는 A·B 그대로).
func _옆으로_잇기(경로: PackedVector2Array, 장치: Node) -> void:
	var n := 경로.size()
	if n < 3:
		return
	var A := 경로[n - 3]
	var 쪽 := -1.0 if A.x < 0.0 else 1.0
	var y := A.y
	var 끝x: float
	match 모양:
		"큰관":
			var 위 := _큰관_위()
			y = clampf(y, 위 + 48.0, -40.0)
			끝x = 쪽 * (_큰관_반지름() - 6.0)          # 큰 관(z 6) 밑으로 밀어 넣는다 → 플랜지만 바깥에 보인다
		"벽관", "타원관", "돌출관", "돌출타원":
			# 테 바깥 타원(가로 ao · 세로 bo) 위에서 멈춘다 — 관(같은 z)이 테 위에 그려지므로 안으로 밀면 테를 가린다
			var ao := 폭 * 0.5 + _테()
			var bo := _벽관_세로() + _테()
			y = clampf(y, -bo + 14.0, -14.0)
			끝x = 쪽 * (ao * sqrt(maxf(0.0, 1.0 - (y / bo) * (y / bo))) + 2.0)
		"관2개", "관3개", "관4개":
			# 가장 가까운 끝 관의 테에 붙인다
			var 몫 := 폭 / float(관줄_개수[모양])
			var r := 몫 * 0.5
			y = clampf(y, -r + 14.0, -14.0)
			끝x = 쪽 * (폭 * 0.5 - r + sqrt(maxf(0.0, r * r - y * y)) + 2.0)
		_:
			y = clampf(y, -(maxf(천장_거리, 0.0) + 천장구_속) + 8.0, -24.0)
			끝x = 쪽 * (폭 * 0.5 + 설주 - 4.0)
	경로.resize(n - 1)
	경로[n - 3] = Vector2(A.x, y)
	경로[n - 2] = Vector2(끝x, y)
	var p := Node2D.new()
	p.set_script(load(관스크립트))
	p.name = "관"
	# 원래 2-2 관과 같은 높이(−1, 절대)
	p.z_as_relative = false
	p.z_index = -1
	p.set("점들", 경로)
	add_child(p)
	p.set("시작_장치", p.get_path_to(장치))


## ============================================================================
## 치수 — 굽는 도구와 같은 식
## ============================================================================
func _큰관_두께() -> float:
	return clampf(폭 * 0.07, 5.0, 16.0)


func _큰관_반지름() -> float:
	return 폭 * 0.5 + _큰관_두께()


func _큰관_위() -> float:
	return -(maxf(천장_거리, 0.0) + 큰관_천장속) if 천장_거리 >= 0.0 else -160.0


## 굽는 도구 `벽관_치수`·`벽관2_치수` 와 같은 식
func _테() -> float:
	if 모양 == "벽관":
		return clampf(폭 * 0.5 * 0.09, 8.0, 26.0)
	return clampf(minf(폭 * 0.5, _벽관_세로() * 1.6) * 0.09, 8.0, 22.0)


func _벽관_세로() -> float:
	return 폭 * 0.5 * (0.5 if 모양 in ["타원관", "돌출타원"] else 1.0)


## ============================================================================
## 그리기 — 부품은 2 배로 구웠다 → 0.5 배로 그린다(배관과 같다)
## ============================================================================
## 물 윗부분에 까는 그늘(위 a → 아래 0). 물 셰이더는 윗변에 밝은 입술선을 그리는데, 입구 바로 밑에서
##   그 선이 그대로 보이면 "물이 여기서 딱 잘려 시작한다" 로 읽힌다 → 관 속 그늘에서 나오는 것처럼 눌러 준다.
func _그늘(x0: float, x1: float, y0: float, y1: float, a: float) -> void:
	var 위 := Color(0, 0, 0, a)
	var 아래 := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([위, 위, 아래, 아래]))


## 게임 좌표 사각형을 2 배 좌표로
func _r(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(Vector2(x0, y0) * 굽기배율, Vector2(x1 - x0, y1 - y0) * 굽기배율)


## 그림을 (cx, cy) 가운데에 원래 크기로
func _가운데(t: Texture2D, cx: float, cy: float, 색: Color = Color.WHITE) -> void:
	if t == null:
		return
	var 크기 := t.get_size()
	draw_texture_rect(t, Rect2(Vector2(cx, cy) * 굽기배율 - 크기 * 0.5, 크기), false, 색)


func _draw() -> void:
	var 반 := 폭 * 0.5
	match 모양:
		"큰관":
			_그늘(-반, 반, 0.0, 12.0, 0.45)
		"천장구":
			_그늘(-반, 반, 0.0, 22.0, 0.85)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / 굽기배율)
	match 모양:
		"큰관":
			_큰관_그리기()
		"벽관", "타원관", "돌출관", "돌출타원":
			var 이름 := "outfall_%s%d" % [벽관_종류[모양], int(round(폭))]
			_가운데(_부품(이름), 0.0, 0.0)
			_가운데(_부품(이름 + "_fill"), 0.0, 0.0, 물빛)
		"관2개", "관3개", "관4개":
			var n: int = 관줄_개수[모양]
			var 몫 := 폭 / float(n)
			# 굽는 도구에 준 안지름과 같은 식(테 = 몫/2 × 0.09, 8~22)
			var 안 := roundi(몫 - 2.0 * clampf(몫 * 0.5 * 0.09, 8.0, 22.0))
			var 이름 := "outfall_p_%d" % 안
			for i in n:
				var cx := -반 + 몫 * (i + 0.5)
				_가운데(_부품(이름), cx, 0.0)
				_가운데(_부품(이름 + "_fill"), cx, 0.0, 물빛)
		"천장구":
			_천장구_그리기(반)
	draw_set_transform(Vector2.ZERO)


func _큰관_그리기() -> void:
	var w := int(round(폭))
	var 직관 := _부품("bigpipe_%d_straight_v" % w)
	if 직관 == null:
		return
	var 관폭 := 직관.get_size().x / 굽기배율
	var 위 := _큰관_위()
	# 입구 플랜지(고리 길이 14): 아랫변이 물 윗변을 3 덮는다 → 고리 가운데 y = 3 − 7
	var 입구y := 3.0 - 7.0
	draw_texture_rect(직관, _r(-관폭 * 0.5, 위, 관폭 * 0.5, 입구y), true)
	# 벽 고정 밴드 — 배관처럼 드문드문(256), 양끝 48 비움
	var 길이 := 입구y - 위
	if 길이 > 160.0:
		var 개수 := maxi(1, int(round((길이 - 96.0) / 256.0)))
		for j in 개수:
			_가운데(_부품("bigpipe_%d_band_v" % w), 0.0, 위 + 48.0 + (길이 - 96.0) * (j + 0.5) / 개수)
	_가운데(_부품("bigpipe_%d_flange_v" % w), 0.0, 입구y)


func _천장구_그리기(반: float) -> void:
	var 위 := -(maxf(천장_거리, 0.0) + 천장구_속)          # 안쪽 윗변
	# 안쪽: 젖은 어두운 돌 + 물빛(아래에서 위로 어둠에 묻힌다)
	draw_texture_rect(_부품("throat_m"), _r(-반, 위, 반, 0), true)
	draw_texture_rect(_부품("glow"), _r(-반, 위, 반, 2), false, 물빛)
	# 인방(문설주 바깥까지) → 문설주 → 모서리 보스 → 발
	var L := -반 - 설주
	var R := 반 + 설주
	draw_texture_rect(_부품("lintel_m"), _r(L, 위 - 인방 - 4, R, 위 + 4), true)
	for x0 in [L, 반]:
		draw_texture_rect(_부품("jamb_m"), _r(x0 - 4, 위, x0 + 설주 + 4, 0), true)
	for cx in [L + 설주 * 0.5, R - 설주 * 0.5]:
		draw_texture_rect(_부품("boss"), _r(cx - 14, 위 - 인방 * 0.5 - 14, cx + 14, 위 - 인방 * 0.5 + 14), false)
	# 발 판 24×9 (그림은 사방 4 여유 = 32×20) — 판이 문설주보다 바깥으로 4 · 안쪽(물 쪽)으로 6 나온다
	draw_texture_rect(_부품("foot_l"), _r(L - 8, -9, L + 24, 11), false)
	draw_texture_rect(_부품("foot_r"), _r(R - 24, -9, R + 8, 11), false)
