@tool
extends Node2D
## ============================================================================
## [2026-10-04 신규 · Claude] 반딧불이 — "이쪽으로 가면 다음 스테이지" 를 알려 주는 작은 빛
## ----------------------------------------------------------------------------
## ▣ 도형님 지시: "다음 스테이지랑 이어지는 부분은 … 근처에 반딧불이가 깜빡이며 돌아다니는 것이 좋을 거 같아"
##   문(포탈) 대신, 살아 있는 작은 빛이 길목에 모여 있으면 플레이어가 자연스럽게 그쪽으로 간다.
##   (Ori · Hollow Knight 의 "빛을 따라가는" 길 안내와 같은 원리 — 화살표 없이 시선을 끈다)
##
## ▣ 만드는 법 — 파티클 대신 _draw
##   개수가 적고(기본 7) 각자 다른 궤적·깜빡임이 필요해서 GPUParticles2D 보다 직접 그리는 편이 단순하다.
##   한 마리 = 겹친 원 3개(가운데 밝고 바깥 옅게) + 가산 혼합 → 흑백 화면에서 "빛"으로 읽힌다.
##   광원(PointLight2D)은 쓰지 않는다 — 한 지형에 겹치는 광원 한계(15)를 아끼려고(CLAUDE.md 예산 진단).
##
## ▣ 움직임
##   · 떠돌기: 서로 다른 주파수의 사인 2개를 더한 부드러운 궤적(같은 반경 타원 안).
##   · 깜빡임: (사인 → 0~1)^3 — 대부분 어둡다가 짧게 반짝인다. 마리마다 위상·주기가 다르다.
##   · 화면 밖이면 그리지 않는다(VisibleOnScreenNotifier2D) → 방마다 놓아도 비용이 거의 없다.
##   · 에디터에서는 움직이지 않는다(값이 바뀔 때만 다시 그림 — 에디터 GPU 상시 사용 방지 규칙 §8).
## ============================================================================

## 반딧불이 수.
@export_range(1, 24) var 개수: int = 7:
	set(v): 개수 = v; _준비()
## 떠도는 범위(타원 반지름, px). 노드 위치가 가운데.
@export var 범위: Vector2 = Vector2(150, 110):
	set(v): 범위 = v; _준비()
## 빛 색. 흑백 게임이라 아주 옅은 따뜻한 흰색.
@export var 색: Color = Color(1.0, 0.97, 0.86, 1.0):
	set(v): 색 = v; queue_redraw()
## 가운데 점 반지름(px). 바깥 번짐은 이것의 6배까지.
@export_range(1.0, 8.0) var 크기: float = 2.6:
	set(v): 크기 = v; queue_redraw()
## 움직임 빠르기 배수.
@export_range(0.1, 3.0) var 속도: float = 1.0
@export var 씨앗: int = 1:
	set(v): 씨앗 = v; _준비()

var _벌레: Array = []          ## [{기준, 진폭, 주파수, 위상, 깜빡주기, 깜빡위상}]
var _t := 0.0
var _보임 := true


func _ready() -> void:
	var 재질 := CanvasItemMaterial.new()
	재질.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = 재질
	_준비()
	if Engine.is_editor_hint():
		return
	var 알림 := VisibleOnScreenNotifier2D.new()
	알림.rect = Rect2(-범위 - Vector2(40, 40), (범위 + Vector2(40, 40)) * 2.0)
	add_child(알림)
	알림.screen_entered.connect(func(): _보임 = true)
	알림.screen_exited.connect(func(): _보임 = false; queue_redraw())


func _준비() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗 * 104729 + 7
	_벌레.clear()
	for i in 개수:
		var 각 := rng.randf() * TAU
		var r := sqrt(rng.randf())
		_벌레.append({
			"기준": Vector2(cos(각) * 범위.x, sin(각) * 범위.y) * r * 0.7,
			"진폭": Vector2(rng.randf_range(0.15, 0.35) * 범위.x, rng.randf_range(0.15, 0.35) * 범위.y),
			"주파수": Vector2(rng.randf_range(0.25, 0.6), rng.randf_range(0.3, 0.7)),
			"위상": Vector2(rng.randf() * TAU, rng.randf() * TAU),
			"깜빡주기": rng.randf_range(1.4, 3.2),
			"깜빡위상": rng.randf() * TAU,
		})
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _보임:
		return
	_t += delta * 속도
	queue_redraw()


func _draw() -> void:
	for b in _벌레:
		var 진폭: Vector2 = b["진폭"]
		var 주: Vector2 = b["주파수"]
		var 위: Vector2 = b["위상"]
		# 두 사인을 더하면 단조로운 원운동이 아니라 "헤매는" 궤적이 된다
		var p: Vector2 = b["기준"] + Vector2(
			sin(_t * 주.x + 위.x) * 진폭.x + sin(_t * 주.x * 2.3 + 위.y) * 진폭.x * 0.35,
			sin(_t * 주.y + 위.y) * 진폭.y + cos(_t * 주.y * 1.7 + 위.x) * 진폭.y * 0.3)
		var 깜 := 0.5 + 0.5 * sin(_t * TAU / float(b["깜빡주기"]) + float(b["깜빡위상"]))
		var a := 0.12 + 0.88 * pow(깜, 3.0)      # 대부분 희미 → 짧게 반짝
		if Engine.is_editor_hint():
			a = 0.8
		draw_circle(p, 크기 * 6.0, Color(색.r, 색.g, 색.b, 0.05 * a))
		draw_circle(p, 크기 * 2.6, Color(색.r, 색.g, 색.b, 0.22 * a))
		draw_circle(p, 크기, Color(색.r, 색.g, 색.b, 0.95 * a))
