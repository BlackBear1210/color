@tool
extends Node2D
## ============================================================================
## [2026-08-08 신규] 장식 오브젝트 — 레인월드식 "잠식된 산업 폐허"
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가 (도형님 제보)
##   "오브젝트가 부족해서 게임 느낌이 안 나. 우리 게임은 레인월드 같은 오브젝트들이
##    너무 필요해. 도트 같지만 디테일이 살아있는 것들."
##
##   지금 스테이지에는 **기능이 있는 것**(발판·물·레버)만 있고 **기능이 없는 것**이 없다.
##   그런데 공간이 "살아 있다"고 느껴지게 만드는 건 오히려 후자다.
##   레인월드의 방이 압도적인 이유는 아무 기능도 없는 파이프와 이끼가
##   **"여기는 원래 누군가 쓰던 곳이고 지금은 자연이 먹었다"** 를 말해주기 때문이다.
##
## ▣ 왜 코드로 그리나 (에셋을 안 쓰고)
##   1. 상업 이용 가능한 외부 에셋을 새로 들이면 **라이선스 관리 대상**이 늘어난다.
##      이 프로젝트는 이미 디자이너가 직접 그린 타일로 룩을 잡고 있다.
##   2. 이 게임은 **흑백**이고 지형이 색칠에 따라 변한다. 남의 에셋은 그 팔레트에
##      절대 안 맞는다. 실제로 배경 프롭(tree_pine.svg 등)이 붕 떠 보이는 원인이었다.
##   3. **디자이너 그림이 나오면 바로 갈아끼울 수 있다** — 다른 장애물과 똑같이
##      자식 `그림`(아트슬롯.gd)에 Texture 를 꽂으면 코드 그리기가 스스로 멈춘다.
##
## ▣ 깊이(Z) 규약 — 도형님 지시 "배경/중경/전경으로 Z-Index 를 분리"
##      먼배경 −40 : 실루엣만. 아주 흐리고 대비가 낮다
##      배경   −12 : 지형 뒤. 벽에 붙은 파이프·이끼
##      중경     0 : 지형과 같은 층. 플레이어가 지나다니는 높이
##      전경   +40 : ★플레이어를 살짝 가린다. 화면 앞을 스치는 큰 파이프
##   전경이 진짜 깊이감의 핵심이다. 앞을 가리는 물체가 하나도 없으면
##   2D 화면은 계속 '그림'으로 읽힌다.
## ============================================================================
class_name 장식

enum 종류_ { 이끼, 버섯, 녹슨파이프, 잔해, 갈대, 얼룩 }
enum 층_ { 먼배경, 배경, 중경, 전경 }

@export var 종류: 종류_ = 종류_.이끼:
	set(v): 종류 = v; queue_redraw()

@export var 층: 층_ = 층_.중경:
	set(v): 층 = v; _층_적용(); queue_redraw()

## 크기(px). 종류마다 뜻이 조금씩 다르다 — 아래 각 그리기 함수 주석 참고.
@export var 크기: Vector2 = Vector2(120, 40):
	set(v): 크기 = Vector2(maxf(v.x, 4.0), maxf(v.y, 4.0)); queue_redraw()

## 같은 종류라도 매번 다른 실루엣이 나오게 하는 값. 배치기가 위치에서 만들어 넣는다.
@export var 씨앗: int = 0:
	set(v): 씨앗 = v; queue_redraw()

## 비워두면 층에 맞는 기본 명도를 쓴다.
@export var 색: Color = Color(0, 0, 0, 0):
	set(v): 색 = v; queue_redraw()

## 살아 있는 것(이끼·버섯·갈대)이 아주 느리게 숨쉬는 정도. 0 이면 정지.
@export_range(0.0, 1.0) var 생기: float = 0.35

## ★[2026-08-10 추가] 플레이어에서 이 거리 밖이면 다시 그리기를 쉰다(px).
## 화면 대각선(약 2,200px)보다 넉넉히 잡는다 — `덩굴.gd` 의 `활성_거리` 와 같은 이유.
## 스테이지가 최대 22,000px 라 장식이 70개 넘게 깔리는데, 화면 밖 장식까지
## 매 프레임 queue_redraw() 하는 건 낭비다(실측: 스테이지 진입 시 지속 프레임드랍의 원인).
@export_range(500.0, 8000.0) var 활성_거리: float = 2400.0

var _t: float = 0.0
var _플레이어: Node2D = null
var _쉬는중: bool = false


func _ready() -> void:
	_층_적용()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("장식")
	# 숨쉬는 장식만 매 프레임 다시 그린다. 나머지는 한 번 그리고 끝 — 공짜다.
	set_process(생기 > 0.0 and 종류 != 종류_.녹슨파이프 and 종류 != 종류_.잔해)


## Z 와 흐림(공기 원근)을 층에 맞춘다.
## ⚠ 먼 것을 그냥 작게만 그리면 깊이가 안 생긴다. **대비를 낮춰야** 멀어 보인다.
func _층_적용() -> void:
	match 층:
		층_.먼배경:
			z_index = -40
			modulate = Color(1, 1, 1, 0.30)
		층_.배경:
			z_index = -12
			modulate = Color(1, 1, 1, 0.62)
		층_.중경:
			z_index = 0
			modulate = Color(1, 1, 1, 1.0)
		층_.전경:
			z_index = 40
			# 전경은 살짝 어둡게 — 카메라에 가까운 물체는 빛을 덜 받는다
			modulate = Color(0.55, 0.55, 0.58, 0.92)


func _process(delta: float) -> void:
	# ── 멀면 통째로 쉰다 ── (`덩굴.gd` 와 같은 문법)
	_플레이어 = _플레이어_찾기()
	if _플레이어 and is_instance_valid(_플레이어):
		var 거리 := global_position.distance_to(_플레이어.global_position)
		if 거리 > 활성_거리:
			if not _쉬는중:
				_쉬는중 = true
				queue_redraw()      # 멈추기 전 마지막 모습을 한 번 반영해 둔다
			return
		_쉬는중 = false

	_t += delta
	queue_redraw()


func _플레이어_찾기() -> Node2D:
	if _플레이어 and is_instance_valid(_플레이어):
		return _플레이어
	return get_tree().get_first_node_in_group("player") as Node2D


func _draw() -> void:
	# 디자이너 그림 슬롯 (다른 장애물과 같은 규약)
	if 아트슬롯.그림_있나(self):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗
	match 종류:
		종류_.이끼:       _이끼(rng)
		종류_.버섯:       _버섯(rng)
		종류_.녹슨파이프: _파이프(rng)
		종류_.잔해:       _잔해(rng)
		종류_.갈대:       _갈대(rng)
		종류_.얼룩:       _얼룩(rng)


## 기본색 — 지정이 없으면 종류에 맞는 무채색 계열을 쓴다.
## 이 게임은 흑백이라 **채도를 거의 넣지 않는다.** 색이 들어가는 건 물감뿐이어야 한다.
func _본색() -> Color:
	if 색.a > 0.0:
		return 색
	match 종류:
		종류_.이끼:       return Color(0.20, 0.26, 0.19)
		종류_.버섯:       return Color(0.46, 0.44, 0.42)
		종류_.녹슨파이프: return Color(0.24, 0.22, 0.20)
		종류_.잔해:       return Color(0.18, 0.18, 0.19)
		종류_.갈대:       return Color(0.26, 0.28, 0.24)
		_:                return Color(0.12, 0.12, 0.13)


# ── 이끼 ────────────────────────────────────────────────────────────────────
## 크기 = (가로로 퍼진 폭, 위로 솟은 높이). 지면/벽면에 **붙어서** 자란다.
## 원점이 붙는 면 위에 오도록 그린다(배치기가 표면 좌표를 그대로 준다).
func _이끼(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 폭 := 크기.x
	var 높이 := 크기.y
	var 숨 := 1.0 + sin(_t * 0.6 + float(씨앗)) * 0.03 * 생기

	# 밑동 — 면에 눌러 붙은 덩어리. 여러 개를 겹쳐 울퉁불퉁하게.
	var 덩이수 := 5 + rng.randi() % 4
	for i in 덩이수:
		var t := float(i) / float(덩이수 - 1)
		var x := lerpf(-폭 * 0.5, 폭 * 0.5, t) + rng.randf_range(-4.0, 4.0)
		var r := 높이 * rng.randf_range(0.45, 1.0) * 숨
		var 짙기 := 0.75 + rng.randf() * 0.25
		draw_circle(Vector2(x, -r * 0.35),
			r, Color(c.r * 짙기, c.g * 짙기, c.b * 짙기, 0.92))

	# 삐죽 솟은 잔털 — 이게 없으면 그냥 '얼룩'으로 보인다
	var 털수 := int(폭 / 7.0)
	for i in 털수:
		var x := rng.randf_range(-폭 * 0.5, 폭 * 0.5)
		var h := 높이 * rng.randf_range(0.5, 1.5) * 숨
		var 휨 := rng.randf_range(-0.3, 0.3) + sin(_t * 0.8 + x * 0.05) * 0.12 * 생기
		draw_line(Vector2(x, 0), Vector2(x + h * 휨, -h),
			Color(c.r * 1.5, c.g * 1.6, c.b * 1.4, 0.75), 1.6, true)


# ── 버섯 ────────────────────────────────────────────────────────────────────
## 크기 = (무리 전체 폭, 가장 큰 버섯의 키).
func _버섯(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 개수 := 2 + rng.randi() % 4
	for i in 개수:
		var x := rng.randf_range(-크기.x * 0.5, 크기.x * 0.5)
		var h := 크기.y * rng.randf_range(0.45, 1.0)
		var 갓 := h * rng.randf_range(0.55, 0.85)
		# 아주 느린 숨 — 살아 있다는 신호. 크게 움직이면 만화가 된다.
		var 숨 := 1.0 + sin(_t * 0.5 + float(i) * 1.7 + float(씨앗)) * 0.04 * 생기

		# 대
		draw_line(Vector2(x, 0), Vector2(x, -h * 숨),
			Color(c.r * 0.8, c.g * 0.8, c.b * 0.78), maxf(h * 0.16, 1.5), true)
		# 갓 — 반원. 아래쪽에 어두운 주름을 한 줄 넣으면 입체로 읽힌다.
		var 갓중심 := Vector2(x, -h * 숨)
		var 점들 := PackedVector2Array()
		var 단계 := 10
		for k in 단계 + 1:
			var a := PI + PI * float(k) / float(단계)
			점들.append(갓중심 + Vector2(cos(a) * 갓 * 0.5, sin(a) * 갓 * 0.34))
		점들.append(갓중심 + Vector2(갓 * 0.5, 0))
		점들.append(갓중심 + Vector2(-갓 * 0.5, 0))
		draw_colored_polygon(점들, Color(c.r * 1.15, c.g * 1.1, c.b * 1.05))
		draw_line(갓중심 + Vector2(-갓 * 0.45, 0), 갓중심 + Vector2(갓 * 0.45, 0),
			Color(0.06, 0.06, 0.07, 0.6), 1.4, true)
		# 갓 위 하이라이트 — 흑백 화면에서 실루엣이 배경에 먹히지 않게
		draw_arc(갓중심, 갓 * 0.5, PI * 1.15, PI * 1.85, 8,
			Color(0.85, 0.86, 0.84, 0.35), 1.4, true)


# ── 녹슨 파이프 ─────────────────────────────────────────────────────────────
## 크기 = (길이, 지름). 원점은 파이프의 **왼쪽 끝 중앙**. 회전은 노드 rotation 으로.
## 산업 폐허의 뼈대다. 이게 화면에 몇 개 지나가는 것만으로 공간의 성격이 바뀐다.
func _파이프(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 길이 := 크기.x
	var 지름 := 크기.y

	# 몸통
	draw_rect(Rect2(0, -지름 * 0.5, 길이, 지름), c)
	# 위쪽 하이라이트 / 아래쪽 그림자 — 두 줄이면 원통으로 읽힌다
	draw_rect(Rect2(0, -지름 * 0.5, 길이, 지름* 0.22),
		Color(c.r * 1.9, c.g * 1.85, c.b * 1.75, 0.55))
	draw_rect(Rect2(0, 지름 * 0.24, 길이, 지름 * 0.26),
		Color(0.03, 0.03, 0.04, 0.45))

	# 이음 밴드 — 일정 간격마다. "만들어진 물건" 이라는 신호.
	var 간격 := maxf(지름 * 2.6, 48.0)
	var x := 간격 * 0.5
	while x < 길이:
		draw_rect(Rect2(x - 지름 * 0.14, -지름 * 0.62, 지름 * 0.28, 지름 * 1.24),
			Color(c.r * 1.4, c.g * 1.35, c.b * 1.3))
		draw_rect(Rect2(x - 지름 * 0.14, -지름 * 0.62, 지름 * 0.28, 지름 * 0.2),
			Color(0.7, 0.68, 0.64, 0.30))
		x += 간격

	# 녹 얼룩 — 무채색 게임이라 '색'이 아니라 **명도 얼룩**으로 표현한다
	var 얼룩수 := int(길이 / 40.0)
	for i in 얼룩수:
		var px := rng.randf_range(0.0, 길이)
		var pr := rng.randf_range(지름 * 0.15, 지름 * 0.45)
		draw_circle(Vector2(px, rng.randf_range(-지름 * 0.3, 지름 * 0.3)), pr,
			Color(0.09, 0.08, 0.07, 0.35))


# ── 잔해 ────────────────────────────────────────────────────────────────────
## 크기 = (퍼진 폭, 가장 큰 조각의 높이). 지면에 흩어진 돌·콘크리트 부스러기.
func _잔해(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 개수 := 3 + rng.randi() % 5
	for i in 개수:
		var x := rng.randf_range(-크기.x * 0.5, 크기.x * 0.5)
		var w := 크기.y * rng.randf_range(0.5, 1.3)
		var h := w * rng.randf_range(0.4, 0.9)
		# 각진 조각 — 원형이면 자갈로 보여서 '부서진 것'이 안 된다
		var 점들 := PackedVector2Array()
		var 각수 := 5 + rng.randi() % 2
		for k in 각수:
			var a := TAU * float(k) / float(각수) + rng.randf_range(-0.2, 0.2)
			점들.append(Vector2(x + cos(a) * w * 0.5, -h * 0.5 + sin(a) * h * 0.5))
		var 짙기 := 0.7 + rng.randf() * 0.6
		draw_colored_polygon(점들, Color(c.r * 짙기, c.g * 짙기, c.b * 짙기))
		draw_polyline(점들, Color(0.55, 0.55, 0.58, 0.35), 1.2, true)


# ── 갈대 ────────────────────────────────────────────────────────────────────
## 크기 = (퍼진 폭, 키). 물가·습지용. 바람에 천천히 눕는다.
func _갈대(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 개수 := int(크기.x / 9.0) + 3
	for i in 개수:
		var x := rng.randf_range(-크기.x * 0.5, 크기.x * 0.5)
		var h := 크기.y * rng.randf_range(0.55, 1.0)
		var 휨 := (sin(_t * 0.7 + x * 0.04 + float(씨앗)) * 0.20
			+ rng.randf_range(-0.18, 0.18)) * 생기 + rng.randf_range(-0.1, 0.1)
		var 끝 := Vector2(x + h * 휨, -h)
		var 중간 := Vector2(x + h * 휨 * 0.3, -h * 0.55)
		# 2 차 곡선 3 등분 — 곧은 선보다 훨씬 식물처럼 보인다
		draw_polyline(PackedVector2Array([Vector2(x, 0), 중간, 끝]),
			Color(c.r, c.g, c.b, 0.9), 1.8, true)
		# 이삭
		draw_line(끝, 끝 + (끝 - 중간).normalized() * h * 0.16,
			Color(c.r * 1.5, c.g * 1.5, c.b * 1.4, 0.85), 3.2, true)


# ── 얼룩 ────────────────────────────────────────────────────────────────────
## 크기 = 얼룩 전체 크기. 벽에 번진 물때/그을음. 아주 흐리게 깔아 면을 지저분하게 만든다.
## 깨끗한 큰 면 하나가 화면에 있으면 그 자체로 "미완성"으로 보인다.
func _얼룩(rng: RandomNumberGenerator) -> void:
	var c := _본색()
	var 개수 := 4 + rng.randi() % 4
	for i in 개수:
		var p := Vector2(rng.randf_range(-크기.x * 0.5, 크기.x * 0.5),
			rng.randf_range(-크기.y * 0.5, 크기.y * 0.5))
		var r := minf(크기.x, 크기.y) * rng.randf_range(0.20, 0.55)
		draw_circle(p, r, Color(c.r, c.g, c.b, 0.16))
