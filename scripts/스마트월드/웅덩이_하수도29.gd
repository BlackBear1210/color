@tool
extends "res://scripts/스마트월드/웅덩이_흰물v2.gd"
## 2-9의 넓고 얕은 물이 발판처럼 보이지 않도록 외관만 별도 재질로 바꾼다.
## 기존 색 판정, 수심, 낙하 받기, 침수 마감은 부모의 동작을 그대로 쓴다.
## 안개처럼 보이던 넓은 얼룩은 약하게 하고 얇고 끊긴 가로 반사를 쓴다.
## 물 밖의 벽돌에는 투명한 젖은 띠만 겹쳐 원래 줄눈과 색칠 상태가 보이게 한다.
const SEWER_SURFACE = preload("res://shaders/sewer_pool_29.gdshader")

func _ready() -> void:
	super._ready()
	# 부모가 만든 인스턴스별 재질을 바꿔 다른 스테이지의 물에는 영향을 주지 않는다.
	var surface := _white_visual.material as ShaderMaterial
	surface.shader = SEWER_SURFACE
	_white_visual.call("_갱신")

func _draw() -> void:
	if not 켜짐:
		return
	# 매립 수로의 양쪽 벽과 밑바닥에만 그린다. 수면 위와 판정 공간은 늘리지 않는다.
	var half := 크기.x * 0.5
	var inset := minf(오른쪽_안쪽폭, 크기.x * 0.75)
	_젖은_띠(Vector2(-half, -크기.y), Vector2(-half, 0.0), Vector2.LEFT, 0.0)
	_젖은_띠(Vector2(half, -크기.y), Vector2(half - inset, 0.0), Vector2.RIGHT, 1.7)
	_젖은_띠(Vector2(-half, 0.0), Vector2(half - inset, 0.0), Vector2.DOWN, 3.1)

func _젖은_띠(start: Vector2, end: Vector2, outward: Vector2, seed: float) -> void:
	# 경계로부터 2~6px 안에서만 불규칙하게 번져 직선 테두리나 검은 프레임을 피한다.
	var steps := maxi(2, int(ceil(start.distance_to(end) / 8.0)))
	var strip := PackedVector2Array([start, end])
	for i in range(steps, -1, -1):
		var along := start.lerp(end, float(i) / float(steps))
		var distance := start.distance_to(along)
		var width := 3.5 + sin(distance * 0.19 + seed) * 1.3 + sin(distance * 0.47) * 0.7
		strip.append(along + outward * width)
	draw_colored_polygon(strip, Color(0.025, 0.025, 0.025, 0.23))
