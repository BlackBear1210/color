@tool
extends Node2D
## ============================================================================
## [2026-10-09 Claude 신규] 타이머 양초 — 세계 안의 시계(기획 §4-I 타임어택 = "큰 양초가 타들어 감")
## ----------------------------------------------------------------------------
## ▣ 쓰임: 레버 퍼즐을 풀면 켜져 `시간` 초 동안 다 탄다. 그동안만 비밀문이 열려 있다(도형님 "시간초").
##   UI 숫자 타이머 대신 초 길이로 남은 시간을 읽게 한다(0~25%면 불꽃이 깜빡여 '곧 꺼진다').
## ▣ 켜진 양초 둘레는 **태우는 빛**("태우는빛" 그룹) — 그을음이 못 들어온다. 퍼즐 방에 그을음을 함께 두면
##   "양초가 타는 동안은 안전 · 꺼지면 깨어난다" 가 된다(기획 §4-I 타임어택 + 그을음 조합).
## ▣ 그림: 아스트라 양초 6상태(100/75/50/25 · 꺼짐 연기 · 다 탐 — `tools/생성_신규기믹_게임용.py 양초`). 원점 = 받침 바닥 가운데.
## ============================================================================

signal 다탐

@export var 시간: float = 20.0
@export var 빛_반경: float = 170.0
## 처음부터 켜 둘지(장식용 양초)
@export var 켜둠: bool = false
## 켜면 타들어 가지 않는다 — 그을음 안전지대용 큰 양초(도안 "촛불")
@export var 영원: bool = false

var 켜짐 := false
var _탄적있음 := false        ## 한 번이라도 켜졌다 꺼졌나(다 탄 촛대를 보일지 · 새 초를 보일지)
var _남은 := 0.0
var _그림들: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	for k in 6:
		var 경로 := "res://assets/textures/props/신규기믹_v02/게임용/테마/양초_%d.png" % k
		_그림들.append(load(경로) if ResourceLoader.exists(경로) else null)
	z_index = -1
	queue_redraw()
	if Engine.is_editor_hint():
		set_process(false)
		return
	add_to_group("태우는빛")
	if 켜둠:
		켜기()
	else:
		set_process(false)


func 켜기(초: float = -1.0) -> void:
	켜짐 = true
	_남은 = 시간 if 초 < 0.0 else 초
	set_process(true)
	queue_redraw()


## 부활·퍼즐 되감기 — 새 초로 되돌린다
func 끄기() -> void:
	켜짐 = false
	_탄적있음 = false
	_남은 = 0.0
	queue_redraw()


func 남은_비율() -> float:
	return clampf(_남은 / maxf(시간, 0.01), 0.0, 1.0) if 켜짐 else 0.0


func 빛_안인가(월드점: Vector2) -> bool:
	if not 켜짐:
		return false
	return 월드점.distance_to(global_position + Vector2(0, -_불높이())) <= 빛_반경


func _불높이() -> float:
	return lerpf(60.0, 150.0, 남은_비율())


func _process(delta: float) -> void:
	_t += delta
	if 켜짐 and not 영원:
		_남은 -= delta
		if _남은 <= 0.0:
			켜짐 = false
			_탄적있음 = true
			다탐.emit()
	queue_redraw()


func _draw() -> void:
	# 상태: 켜짐 = 남은 비율로 0~3 · 다 탔음 = 5(촛대만) · 아직 안 켬 = 0 번 그림에서 불꽃만 잘라 낸 '새 초'
	var 단계 := 5
	var 새초 := false
	if 켜짐:
		var r := 남은_비율()
		단계 = 0 if r > 0.75 else (1 if r > 0.5 else (2 if r > 0.25 else 3))
	elif not _탄적있음:
		단계 = 0
		새초 = true
	var t: Texture2D = _그림들[단계] if 단계 < _그림들.size() else null
	if t == null:
		draw_rect(Rect2(-8, -120, 16, 120), Color(0.8, 0.8, 0.78))
		return
	var 크기 := Vector2(t.get_size()) * 0.5
	if 새초:
		# 0 번 그림 위 46px(2배 기준)이 불꽃 — 잘라 내고 심지만 남긴다(원화에 '안 켠 초' 그림이 없어서)
		var 잘라 := 46.0
		draw_texture_rect_region(t, Rect2(Vector2(-크기.x * 0.5, -크기.y + 잘라 * 0.5), Vector2(크기.x, 크기.y - 잘라 * 0.5)),
			Rect2(Vector2(0, 잘라), Vector2(t.get_width(), t.get_height() - 잘라)))
		return
	var 색 := Color.WHITE
	if 켜짐 and 남은_비율() < 0.25:
		색 = Color(1, 1, 1, 0.75 + 0.25 * absf(sin(_t * 14.0)))     # 곧 꺼진다 — 깜빡
	draw_texture_rect(t, Rect2(Vector2(-크기.x * 0.5, -크기.y), 크기), false, 색)
	if 켜짐:
		# 둘레의 은은한 빛 — 그을음이 못 들어오는 자리를 보여 준다(반경 = 빛_반경)
		draw_circle(Vector2(0, -_불높이()), 빛_반경, Color(1.0, 0.96, 0.85, 0.035))
		draw_circle(Vector2(0, -_불높이()), 빛_반경 * 0.45, Color(1.0, 0.96, 0.85, 0.05))
