@tool
extends "res://scripts/스마트월드/압력버튼.gd"
## 전체 하수도 압력 발판: 기존 누름 동작을 유지하고 상단 마감 한 단만 금속으로 교체한다.

@export_node_path("Node2D") var 매립_지형: NodePath
var _마감_대상: Node2D

# 돌과 고정 프레임은 그대로 두고 상판만 4px 솟게 해 누르는 장치임을 보여 준다.
const 상판_돌출: float = 4.0


func _상판_올림() -> float:
	return 상판_돌출 * (1.0 - _눌림_표현)


func _재구성() -> void:
	super._재구성()
	_상판_충돌_갱신()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# 그림과 같은 눌림 값을 물리 프레임에서 반영해 캐릭터 발이 판에 파묻히지 않게 한다.
	_상판_충돌_갱신()


func _상판_충돌_갱신() -> void:
	if not is_inside_tree():
		return
	var 올림 := _상판_올림()
	var 모양 := get_node_or_null("밟는면/모양") as CollisionShape2D
	if 모양 != null and 모양.shape is RectangleShape2D:
		# 아래쪽은 고정하고 윗면만 4→0px 이동한다. 기존 폭과 바닥 높이를 유지한다.
		var 사각 := 모양.shape as RectangleShape2D
		var 크기 := Vector2(폭, 높이 + 올림)
		if 사각.size != 크기:
			사각.size = 크기
		모양.position = Vector2(0, -(높이 + 올림) * 0.5)
	var 감지모양 := get_node_or_null("누름감지/모양") as CollisionShape2D
	if 감지모양 != null:
		# 감지도 상판을 따라가므로 눌림 도중 플레이어를 놓쳐 상판이 떨리지 않는다.
		감지모양.position = Vector2(0, -높이 * 0.5 - 감지_높이 * 0.5 + 4.0 - 올림)


func _ready() -> void:
	super._ready()
	_매립_갱신()
	set_process(true)


func _process(_delta: float) -> void:
	# 편집기 이동·폭 변경·숨김도 반영한다. 지형 API가 동일 다각형을 걸러 메시 재생성을 막는다.
	_매립_갱신()


func _exit_tree() -> void:
	_마감_복원()


func _마감_복원() -> void:
	if is_instance_valid(_마감_대상):
		_마감_대상.call("침수마감_설정", get_instance_id(), PackedVector2Array())
		_마감_대상.call("매립접합_설정", get_instance_id(), Rect2())
	_마감_대상 = null


func _매립_갱신() -> void:
	var 대상 := get_node_or_null(매립_지형) as Node2D
	if 대상 != _마감_대상:
		_마감_복원()
		if 대상 != null and 대상.has_method("침수마감_설정"):
			_마감_대상 = 대상
	if not is_instance_valid(_마감_대상):
		return
	var 영역 := PackedVector2Array()
	if is_visible_in_tree():
		# 수중 마감에서 쓰는 차집합 API를 공유해 돌 띠만 자른다. 지형 충돌/색 판정은 보존한다.
		# 사각형으로 파면 상판 모따기 밖에 검은 구멍이 남는다. 금속 윤곽 안쪽만 걷어낸다.
		# 잘라낸 돌과 금속을 0.6px 겹쳐 필터링/투명 가장자리에서 검은 틈이 벌어지지 않게 한다.
		var 반폭 := 폭 * 0.5 - 0.6
		var 앞면높이 := 높이 * 0.625
		var 상단 := -높이 - 4.0 + 0.4
		var 모따기 := (높이 + 5.0 - 앞면높이) * 0.43
		for 점 in [Vector2(-반폭 + 2.0 + 모따기, 상단),
			Vector2(반폭 - 2.0 - 모따기, 상단),
			Vector2(반폭 - 2.0, 상단 + 모따기),
			Vector2(반폭 - 2.0, -앞면높이), Vector2(반폭, -앞면높이),
			Vector2(반폭, -0.6), Vector2(-반폭, -0.6),
			Vector2(-반폭, -앞면높이), Vector2(-반폭 + 2.0, -앞면높이),
			Vector2(-반폭 + 2.0, 상단 + 모따기)]:
			영역.append(to_global(점))
	_마감_대상.call("침수마감_설정", get_instance_id(), 영역)
	# 3개 돌 폭으로 맞춘 발판 양옆 한 조각은 전용 접합 UV로 원래 사선 줄눈을 걷어낸다.
	var 접합 := Rect2()
	if is_visible_in_tree():
		접합 = Rect2(to_global(Vector2(-폭 * 0.5, -높이)),
			to_global(Vector2(폭 * 0.5, 0.0)) - to_global(Vector2(-폭 * 0.5, -높이)))
	_마감_대상.call("매립접합_설정", get_instance_id(), 접합)


func _가로_분할_그리기(목적: Rect2, 원본: Rect2, 끝폭: float, 명도: float) -> void:
	# 양끝 볼트/모따기는 원본 비율로 고정하고 가운데만 늘려 규격 변경 시 찌그러짐을 막는다.
	var 배율 := 목적.size.y / 원본.size.y
	var 가장자리 := minf(끝폭 * 배율, 목적.size.x * 0.25)
	var 원본끝 := 가장자리 / 배율
	# 금속만 낮춰 주변 석재와 명도를 맞춘다. 활성 표시창은 별도 그려 읽기 쉽게 유지한다.
	var 색 := Color(명도, 명도, 명도, 1.0)
	draw_texture_rect_region(주철_부품, Rect2(목적.position, Vector2(가장자리, 목적.size.y)),
		Rect2(원본.position, Vector2(원본끝, 원본.size.y)), 색)
	draw_texture_rect_region(주철_부품,
		Rect2(목적.position + Vector2(가장자리, 0), Vector2(목적.size.x - 가장자리 * 2, 목적.size.y)),
		Rect2(원본.position + Vector2(원본끝, 0), Vector2(원본.size.x - 원본끝 * 2, 원본.size.y)), 색)
	draw_texture_rect_region(주철_부품,
		Rect2(목적.position + Vector2(목적.size.x - 가장자리, 0), Vector2(가장자리, 목적.size.y)),
		Rect2(원본.position + Vector2(원본.size.x - 원본끝, 0), Vector2(원본끝, 원본.size.y)), 색)


func _draw() -> void:
	var 상단 := -높이 - 4.0
	var 앞면높이 := 높이 * 0.625
	var 올림 := _상판_올림()
	# 검은 바탕은 상판과 프레임 사이 내부에만 둔다. 바깥 여백은 원래 돌 마감을 남긴다.
	draw_rect(Rect2(-폭 * 0.5 + 3.0, -앞면높이 - 상판_돌출, 폭 - 6.0, 앞면높이 + 상판_돌출 - 1.0), Color(0.055, 0.055, 0.055))
	# 원본 외곽의 검은 테두리/하단 테두리만 제외하고 같은 목적 크기로 그려 스티커 같은 경계를 줄인다.
	_가로_분할_그리기(Rect2(-폭 * 0.5, -앞면높이, 폭, 앞면높이), Rect2(32, 427, 562, 65), 86.0, 0.86)
	# 두께는 유지한 채 기본 4px 돌출, 완전히 누르면 기존 돌 마감 윗선으로 복귀한다.
	_가로_분할_그리기(Rect2(-폭 * 0.5 + 2.0, 상단 - 올림, 폭 - 4.0, 높이 + 5.0 - 앞면높이),
		Rect2(682, 398, 514, 83), 72.0, 0.78)
	if _활성:
		draw_rect(Rect2(-폭 * 0.12, -앞면높이 * 0.56, 폭 * 0.24, 2.0), Color(0.87, 0.87, 0.85))
