@tool
extends Node2D
## ============================================================================
## [2026-08-02 신규] 패럴랙스 안개 / 구름 층
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가
##   지금 배경은 "하늘 + 실루엣"뿐이라 카메라가 움직여도 공간이 얕게 느껴진다.
##   서로 다른 속도로 흐르는 안개를 몇 겹 깔면
##     ① 깊이가 생기고(가까운 안개가 빨리 지나간다)
##     ② 화면에 항상 미세한 움직임이 있어 정지 화면처럼 안 보인다.
##   레인월드가 2D 인데도 습하고 넓어 보이는 이유 중 하나가 이 겹겹의 대기다.
##
## ▣ Parallax2D 안에 넣어서 쓴다
##   스크롤 속도는 부모 Parallax2D 의 `scroll_scale` 이 정한다.
##   이 노드는 **그 안에서 다시 천천히 흘러가는** 자체 이동만 담당한다
##   (= 카메라가 멈춰 있어도 안개는 계속 흐른다).
##
## ▣ 그림
##   FastNoiseLite 로 만든 부드러운 덩어리 텍스처를 여러 장 겹쳐 그린다.
##   ⚠ Godot 3 의 OpenSimplexNoise 는 4 에서 FastNoiseLite 로 바뀌었다.
##      TYPE_SIMPLEX_SMOOTH 가 예전 OpenSimplex 와 가장 비슷하다.
## ============================================================================
class_name 안개층

## 안개가 덮는 영역(px). 카메라가 볼 수 있는 범위보다 넉넉하게.
@export var 영역: Vector2 = Vector2(6000, 900):
	set(v):
		영역 = Vector2(maxf(v.x, 100.0), maxf(v.y, 50.0))
		queue_redraw()

## 덩어리 개수. 많을수록 촘촘하지만 무겁다.
@export_range(1, 40) var 덩어리수: int = 12:
	set(v):
		덩어리수 = clampi(v, 1, 40)
		_덩어리_생성()

## 덩어리 하나의 기본 반경(px).
@export var 덩어리_반경: float = 320.0:
	set(v):
		덩어리_반경 = maxf(v, 20.0)
		_덩어리_생성()

## 자체 흐름 속도(px/s). 음수면 왼쪽으로.
@export var 흐름속도: float = 14.0

## 안개 색과 진하기.
@export var 안개색: Color = Color(0.78, 0.80, 0.84, 0.14):
	set(v): 안개색 = v; queue_redraw()

## 모양이 매번 달라지도록 하는 씨앗. 같은 값이면 항상 같은 안개가 나온다.
@export var 씨앗: int = 20260802:
	set(v): 씨앗 = v; _덩어리_생성()

var _덩어리: Array[Dictionary] = []
var _흐름: float = 0.0
var _노이즈: FastNoiseLite = null


func _ready() -> void:
	_덩어리_생성()
	set_process(true)
	queue_redraw()


func _덩어리_생성() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗
	_노이즈 = FastNoiseLite.new()
	_노이즈.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_노이즈.seed = 씨앗
	_노이즈.frequency = 0.55

	_덩어리.clear()
	for i in 덩어리수:
		_덩어리.append({
			"x": rng.randf() * 영역.x,
			"y": rng.randf() * 영역.y,
			# 크기를 넓게 흩어야 "같은 도장을 찍은" 느낌이 안 난다
			"r": 덩어리_반경 * rng.randf_range(0.55, 1.6),
			# 세로로 눌러야 구름처럼 보인다 (동그라미는 연기 방울처럼 보인다)
			"납작": rng.randf_range(0.28, 0.5),
			"위상": rng.randf() * 100.0,
			"속도": rng.randf_range(0.6, 1.5),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_흐름 += delta * 흐름속도
	queue_redraw()


## 부드러운 방사형 덩어리 텍스처.
## ★[2026-08-02 수정] 처음엔 draw_circle 을 3겹 겹쳐 그렸는데, 원마다 **단단한 경계**가
##   남아서 안개가 아니라 "동심원 고리"로 보였다(첫 스크린샷에서 확인).
##   → 가장자리가 0 으로 부드럽게 떨어지는 텍스처 한 장을 만들어 늘려 그린다.
##   모양이 전부 같으므로 static 으로 한 번만 만들어 전 인스턴스가 공유한다.
static var _공용_텍스처: Texture2D = null

static func _덩어리_텍스처() -> Texture2D:
	if _공용_텍스처 != null:
		return _공용_텍스처
	var 크기 := 128
	var img := Image.create(크기, 크기, false, Image.FORMAT_RGBA8)
	var 중심 := Vector2(크기, 크기) * 0.5
	for y in 크기:
		for x in 크기:
			var d := Vector2(x, y).distance_to(중심) / (float(크기) * 0.5)
			# smoothstep 으로 떨어뜨리면 가장자리에 경계선이 안 생긴다
			var a := 1.0 - smoothstep(0.0, 1.0, clampf(d, 0.0, 1.0))
			a = a * a                      # 가운데를 더 진하게 = 뭉게구름 느낌
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_공용_텍스처 = ImageTexture.create_from_image(img)
	return _공용_텍스처


func _draw() -> void:
	if _노이즈 == null:
		_덩어리_생성()
	var 텍스처 := _덩어리_텍스처()
	for 덩 in _덩어리:
		# 가로로 흘러가되, 영역 밖으로 나가면 반대쪽에서 다시 들어온다(무한 루프)
		var x: float = fposmod(float(덩["x"]) + _흐름 * float(덩["속도"]), 영역.x)
		var y: float = 덩["y"]
		var r: float = 덩["r"]
		var 납작: float = 덩["납작"]

		# 노이즈로 크기를 천천히 부풀렸다 줄인다 — 안개가 살아 있는 느낌
		var n := _노이즈.get_noise_2d(float(덩["위상"]), _흐름 * 0.012)
		r *= 1.0 + n * 0.22

		# 가로로 길고 세로로 납작한 사각형에 부드러운 덩어리를 늘려 그린다 = 구름 실루엣.
		# (동그라미로 그리면 연기 방울처럼 보인다)
		var 사각 := Rect2(Vector2(x - r, y - r * 납작), Vector2(r * 2.0, r * 2.0 * 납작))
		draw_texture_rect(텍스처, 사각, false, 안개색)
