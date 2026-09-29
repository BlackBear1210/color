extends Node2D
## [2026-09-27] 물 v3를 수정하지 않고 호퍼 입구에만 수면/착수/앞 테두리를 덧그린다.
## 원화 좌표 y270~285가 빈 입구, y286부터 앞 테두리다. 실제 아트 배율을 따라가며
## 착수점을 앞쪽(입구 깊이의 78%)에 둬 뒤 테두리에 물이 걸쳐 보이지 않게 한다.
const 아틀라스 = preload("res://assets/textures/obstacles/hopper/cast_iron_v1/hopper_atlas_flat.png")

var _호퍼: Node2D
var _색: int = -1
var _접점들: Array[Dictionary] = []
var _시간: float = 0.0
var _누적: float = 0.0

func _ready() -> void:
	_호퍼 = get_parent() as Node2D
	# 유체 그림(z+2) 위에 수면을 그린 뒤 원화 앞 테두리를 다시 얹어 자연스럽게 가린다.
	z_index = 4
	visible = false
	set_process(false)

func 상태_받기(물색: int, 유입들: Array) -> void:
	var 변경 := _색 != 물색
	_색 = 물색
	visible = _색 >= 0
	set_process(visible)
	if not visible:
		_접점들.clear()
		return
	# 겹침 재생성의 짧은 공백은 부모의 끊김 유예와 동일하게 마지막 접점을 유지한다.
	if not 유입들.is_empty():
		_접점들.clear()
		for 물: Node2D in 유입들:
			if not is_instance_valid(물):
				continue
			var 크기: Vector2 = 물.get("크기")
			var 끝 := to_local(물.to_global(Vector2(0.0, 크기.y)))
			var 왼쪽 := to_local(물.to_global(Vector2(-크기.x * 0.5, 크기.y)))
			var 오른쪽 := to_local(물.to_global(Vector2(크기.x * 0.5, 크기.y)))
			_접점들.append({"끝": 끝, "폭": absf(오른쪽.x - 왼쪽.x), "색": int(물.get("색"))})
	if 변경:
		queue_redraw()

func _process(delta: float) -> void:
	_시간 += delta
	_누적 += delta
	# 작은 입구 효과만 24fps로 갱신한다. 물 v3의 GPU 애니메이션/판정은 건드리지 않는다.
	if _누적 >= 1.0 / 24.0:
		_누적 = fmod(_누적, 1.0 / 24.0)
		queue_redraw()

static func 수면색(물색: int) -> Color:
	match 물색:
		0: return Color(0.035, 0.035, 0.035, 0.98)
		1: return Color(0.88, 0.88, 0.88, 0.98)
		_: return Color(0.45, 0.45, 0.45, 0.96)

static func 물결색(물색: int) -> Color:
	# 흰 물의 거품은 본체보다 어둡게 유지한다. 검정 물은 회색 반사로 흐름을 읽힌다.
	match 물색:
		0: return Color(0.29, 0.29, 0.29, 0.85)
		1: return Color(0.53, 0.53, 0.53, 0.90)
		_: return Color(0.65, 0.65, 0.65, 0.80)

func _draw() -> void:
	if _색 < 0 or not is_instance_valid(_호퍼):
		return
	var 배율: Vector2 = _호퍼.call("입구_아트_배율")
	var 높이: float = _호퍼.get("높이")
	var 왼쪽 := -175.0 * 배율.x
	var 오른쪽 := 175.0 * 배율.x
	var 뒤 := -높이 + 10.0 * 배율.y
	var 앞 := -높이 + 25.0 * 배율.y
	var 착수y := lerpf(뒤, 앞, 0.78)
	var 본체 := 수면색(_색)
	var 물결 := 물결색(_색)
	# 원화의 검정 구멍 안에서만 수면을 채우고 모서리의 얇은 그늘은 남긴다.
	draw_colored_polygon(PackedVector2Array([
		Vector2(왼쪽 + 3.0 * 배율.x, 뒤), Vector2(오른쪽 - 3.0 * 배율.x, 뒤),
		Vector2(오른쪽, 앞), Vector2(왼쪽, 앞)
	]), 본체)
	for 줄 in range(2):
		var 점들 := PackedVector2Array()
		for i in range(25):
			var 비율 := float(i) / 24.0
			var x := lerpf(왼쪽 + 2.0, 오른쪽 - 2.0, 비율)
			var y := lerpf(뒤, 앞, 0.35 + 줄 * 0.38)
			y += sin(비율 * 20.0 - _시간 * 3.0 + 줄) * (앞 - 뒤) * 0.08
			점들.append(Vector2(x, y))
		draw_polyline(점들, 물결, maxf(0.45, 배율.x * 0.8), true)
	for 접점 in _접점들:
		var 끝: Vector2 = 접점["끝"]
		var 반폭 := float(접점["폭"]) * 0.5
		var 시작x := maxf(왼쪽 + 1.0, 끝.x - 반폭)
		var 끝x := minf(오른쪽 - 1.0, 끝.x + 반폭)
		if 끝x <= 시작x:
			continue
		# 판정은 그대로 두고 마지막 몇 픽셀만 수면 앞으로 이어 붙인다.
		var 위 := clampf(끝.y - 3.0, 뒤 - 6.0, 뒤)
		var 유입색 := 수면색(int(접점["색"]))
		유입색.a = 0.84
		draw_rect(Rect2(시작x, 위, 끝x - 시작x, 착수y - 위), 유입색)
		for 줄 in range(4):
			var x := lerpf(시작x, 끝x, (줄 + 0.5) / 4.0)
			draw_line(Vector2(x, 위), Vector2(x + sin(_시간 * 5.0 + 줄) * 0.4, 착수y), 물결색(int(접점["색"])), 0.55, true)
		_착수_그리기(Vector2((시작x + 끝x) * 0.5, 착수y), 끝x - 시작x, 왼쪽, 오른쪽, 수면색(_색), 배율.x)
	# 입구의 앞 금속 띠만 마지막에 재사용한다. 물이 호퍼 앞면을 타고 흐르지 않는다.
	var 방향: int = _호퍼.get("출구방향")
	var 원본 := Rect2(방향 * 512 + 52, 286, 408, 58)
	var 목적 := Rect2(Vector2(-204.0 * 배율.x, -높이 + 26.0 * 배율.y), Vector2(408, 58) * 배율)
	draw_texture_rect_region(아틀라스, 목적, 원본)

func _착수_그리기(중심: Vector2, 물폭: float, 왼쪽: float, 오른쪽: float, 물결: Color, 배율: float) -> void:
	# 수면 잔물결의 어두운 색 대신 실제 입구 물색으로 작은 왕관과 포물선 물방울을 그린다. 방 전체를 가리는 분무는 없다.
	var 진폭 := clampf(물폭 * 0.08, 1.2, 5.0)
	var 왕관 := PackedVector2Array()
	for i in range(13):
		var x := 중심.x + (float(i) / 12.0 - 0.5) * 물폭 * 0.9
		var 튐 := (0.5 + 0.5 * sin(_시간 * 7.0 + i * 2.3)) * 진폭 if i % 2 else 0.0
		왕관.append(Vector2(clampf(x, 왼쪽, 오른쪽), 중심.y - 튐))
	draw_polyline(왕관, 물결, maxf(0.65, 배율), true)
	for i in range(6):
		var 진행 := fposmod(_시간 * 1.6 + float(i) / 6.0, 1.0)
		var 방향 := -1.0 if i % 2 else 1.0
		var x := 중심.x + 방향 * (물폭 * 0.2 + 진행 * 진폭 * 2.0)
		var y := 중심.y - sin(진행 * PI) * 진폭 * 2.0
		draw_circle(Vector2(clampf(x, 왼쪽, 오른쪽), y), maxf(0.5, 배율 * 0.75), 물결)
