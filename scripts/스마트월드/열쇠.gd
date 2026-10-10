@tool
extends Area2D
## ============================================================================
## [2026-10-08 Claude · 2-5 신규] 열쇠 — 주우면 지정한 문(Node2D)을 밀어 연다.
## ----------------------------------------------------------------------------
## 왜 만들었나
##   2-5 도면 낙사 존 오른쪽 홈에 "검은 열쇠" 가 그려져 있는데, 게임에 열쇠 부품이 없었다.
##   도면의 다른 곳에 잠긴 것이 없으므로 **도착 지점 출구를 막은 문**을 여는 것으로 정했다(작업기록 §4 · 도형님 확인 대기).
##
## 규칙
##   · 플레이어 몸이 닿으면 줍는다(색 상관없음 — 이름의 "검은" 은 그림 색이다).
##   · 주우면 `문들` 을 `문_이동량` 만큼 `이동속도` 로 옮긴다(압력버튼과 같은 짜임 — 문 = Node2D 그릇 + 그 안의 지형).
##   · 한 번 주우면 끝 — 죽어도 되돌리지 않는다(페인트가 아니라 진행이다).
##
## 성능: 그림은 줍기 전 한 번만 그린다(매 프레임 redraw 없음 · 다음작업 §8 재발 방지 규칙).
##   둥실거림은 position 만 바꾼다(다시 그리지 않는다). 문은 다 열리면 처리를 멈춘다.
## ============================================================================
class_name 열쇠

const 새그림_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/열쇠/"
static var _새그림들: Dictionary = {}
## 하수도 기존 문 연결·획득 규칙을 유지하고 새 원형 열쇠의 그림만 선택한다.
@export_enum("기존", "완성", "검정 조각", "흰 조각") var 새_디자인: int = 0:
	set(v):
		새_디자인 = v
		queue_redraw()

@export var 문들: Array[NodePath] = []
## 문을 어디로 미나(px). 예: Vector2(0, -304) = 위로 304 (천장 바위 속으로).
@export var 문_이동량: Vector2 = Vector2(0, -304)
@export_range(40.0, 1200.0) var 이동속도: float = 360.0
@export_range(16.0, 160.0) var 감지_반지름: float = 40.0
## ★[2026-10-09 Claude · 2-7] 이 열쇠들도 **다 주워야** 문이 움직인다(열쇠 조각). 비워 두면 예전처럼 혼자 연다.
##   왜: 2-7 도면에 "흰색 열쇠조각" 과 "검은 열쇠조각" 이 따로 있다 — 두 조각을 모아야 도착 문이 열린다.
##   문을 가진 열쇠 하나에만 짝을 적는다(둘 다 문을 가지면 같은 문을 두 번 민다).
@export var 함께_필요한_열쇠들: Array[NodePath] = []
## 그림 색 — 켜면 흰 열쇠(검은 테두리). 판정은 색과 상관없다(누구나 줍는다).
@export var 흰_열쇠: bool = false:
	set(v):
		흰_열쇠 = v
		queue_redraw()

var 주움 := false
var _문_노드들: Array[Node2D] = []
var _문_목표들: Array[Vector2] = []
var _기준y := 0.0
var _시간 := 0.0
var _짝들: Array[Node] = []


func _ready() -> void:
	_감지_만들기()
	queue_redraw()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group("열쇠")
	_기준y = position.y
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_닿음)
	for 경로 in 문들:
		var 문 := get_node_or_null(경로) as Node2D
		if 문 == null:
			push_warning("[열쇠:%s] 문 경로(%s)를 못 찾음" % [name, 경로])
			continue
		_문_노드들.append(문)
		_문_목표들.append(문.position + 문_이동량)
	for 경로2 in 함께_필요한_열쇠들:
		var 짝 := get_node_or_null(경로2)
		if 짝 == null:
			push_warning("[열쇠:%s] 짝 열쇠 경로(%s)를 못 찾음" % [name, 경로2])
			continue
		_짝들.append(짝)


func _감지_만들기() -> void:
	var c := get_node_or_null("감지") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "감지"
		add_child(c)
	var 원 := CircleShape2D.new()
	원.radius = 감지_반지름
	c.shape = 원


func _닿음(몸: Node) -> void:
	if 주움 or not 몸.is_in_group("player"):
		return
	주움 = true
	visible = false
	set_deferred("monitoring", false)


func _physics_process(delta: float) -> void:
	if not 주움:
		# 둥실거림 — position 만 바꾼다(다시 그리지 않는다)
		_시간 += delta
		position.y = _기준y + sin(_시간 * 2.4) * 4.0
		return
	if not _짝도_다_주웠나():
		return
	var 다 := true
	for i in _문_노드들.size():
		var 문 := _문_노드들[i]
		if not is_instance_valid(문):
			continue
		# 이미 목표면 대입하지 않는다 — 같은 값을 넣어도 지형 마감 재계산이 퍼진다(압력버튼 2026-09-30 실측과 같은 이유)
		if 문.position != _문_목표들[i]:
			문.position = 문.position.move_toward(_문_목표들[i], 이동속도 * delta)
			다 = false
	if 다:
		# 다 열린 문은 숨긴다 — 문은 출구 통로 그림(z 0) 앞에 보이도록 z 를 올려 두었으니,
		#   천장 바위 속으로 들어간 뒤에도 그대로 두면 바위 앞에 겹쳐 그려진다(충돌은 바위 속이라 남아도 된다).
		for 문2 in _문_노드들:
			if is_instance_valid(문2):
				문2.visible = false
		set_physics_process(false)


## 짝 열쇠(조각)를 전부 주웠나. 짝이 없으면 언제나 참.
func _짝도_다_주웠나() -> bool:
	for 짝 in _짝들:
		if is_instance_valid(짝) and not bool(짝.get("주움")):
			return false
	return true


## 주행검사가 "문이 다 열렸나" 를 물을 때 쓴다.
func 문_열림() -> bool:
	if not 주움 or not _짝도_다_주웠나():
		return false
	for i in _문_노드들.size():
		if is_instance_valid(_문_노드들[i]) and _문_노드들[i].position != _문_목표들[i]:
			return false
	return true


func _draw() -> void:
	# 새 조각 시스템으로 스크립트를 교체하면 색별 획득·진행 저장·문 규칙까지 바뀌므로 그림만 연결한다.
	if 새_디자인 != 0 and _새_열쇠_그리기():
		return
	# 검은 열쇠 — 어두운 하수도에서 읽히게 흰 테두리를 두른다. 원점 = 열쇠 가운데.
	var 몸 := Color(0.06, 0.06, 0.07)
	var 테 := Color(0.86, 0.87, 0.88)
	if 흰_열쇠:
		# 흰 열쇠 조각(2-7) — 몸과 테두리 색만 맞바꾼다(흰 지형 위에서도 테두리로 읽힌다).
		var 임시 := 몸
		몸 = Color(0.93, 0.93, 0.92)
		테 = 임시
	var 선 := PackedVector2Array([Vector2(-6, 0), Vector2(26, 0)])
	draw_circle(Vector2(-16, 0), 13.0, 테)
	draw_polyline(선, 테, 10.0)
	draw_rect(Rect2(14, -1, 5, 14), 테)
	draw_rect(Rect2(21, -1, 5, 11), 테)
	draw_circle(Vector2(-16, 0), 10.0, 몸)
	draw_circle(Vector2(-16, 0), 4.0, 테)
	draw_polyline(선, 몸, 5.0)
	draw_rect(Rect2(15.5, 0, 2, 11), 몸)
	draw_rect(Rect2(22.5, 0, 2, 8), 몸)


func _새_열쇠_그리기() -> bool:
	var 이름들: Array[String] = ["왼쪽", "오른쪽"] if 새_디자인 == 1 else (["왼쪽"] if 새_디자인 == 2 else ["오른쪽"])
	# 두 조각은 같은 크기·기준점의 캔버스다. 원본 위치 그대로 겹쳐야 지그재그 이음이 맞물린다.
	for 이름 in 이름들:
		if not _새그림들.has(이름):
			var 경로 := 새그림_폴더 + 이름 + ".png"
			var 그림: Texture2D = null
			if ResourceLoader.exists(경로, "Texture2D"):
				그림 = load(경로) as Texture2D
			elif FileAccess.file_exists(경로):
				# 에디터 임포트 전에도 새 PNG를 표시한다. 원본 이미지는 수정하지 않는다.
				그림 = ImageTexture.create_from_image(Image.load_from_file(경로))
			if 그림 == null:
				return false
			_새그림들[이름] = 그림
	for 이름 in 이름들:
		var 그림 := _새그림들[이름] as Texture2D
		var 크기 := 그림.get_size() * 0.5
		draw_texture_rect(그림, Rect2(-크기 * 0.5, 크기), false)
	return true
