@tool
extends PaintPlatform
## ============================================================================
## 💥 무너지는 발판 (Crumbling Platform)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 밟으면 잠깐 흔들리다가 무너져 내리고, 일정 시간 뒤 되살아난다.
## PaintPlatform 상속 → **색칠도 되는 발판**. 무너졌다 살아나면 칠 상태는 유지된다.
##
## ▣ 이 게임에서 이 부품이 특별한 이유
##   "칠할 시간 압박"을 만드는 유일한 부품이다.
##   무색 발판 위에 서서 여유롭게 조준하는 게 기본 리듬인데, 이 발판 위에서는
##   **버티는 시간 안에 조준하고 쏴야** 한다 → 같은 퍼즐이 순간적으로 액션이 된다.
##
## ▣ 쓰는 법
##   `버티는시간`(밟고 나서 무너지기까지) / `되살아나는시간` 만 조절.
##   기본값 0.6 / 2.4 초는 "한 번 조준해서 한 발 쏠 수 있는" 길이로 맞춰 놓았다.
## ============================================================================

@export_range(0.15, 3.0) var 버티는시간: float = 0.6
@export_range(0.5, 10.0) var 되살아나는시간: float = 2.4

var _상태: int = 0                  ## 0=정상 1=흔들림 2=무너짐
var _타이머: float = 0.0
var _원래위치: Vector2
var _밟힘: bool = false

func _ready() -> void:
	super._ready()
	_원래위치 = position
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _상태:
		0:
			if _플레이어가_위에_있나():
				_상태 = 1
				_타이머 = 버티는시간
		1:
			_타이머 -= delta
			# 흔들림: 무너지기 직전이라는 경고. 시간이 갈수록 진폭이 커진다.
			var 진행 := 1.0 - clampf(_타이머 / maxf(버티는시간, 0.01), 0.0, 1.0)
			position = _원래위치 + Vector2(sin(Time.get_ticks_msec() * 0.05) * 3.0 * 진행, 0)
			if _타이머 <= 0.0:
				_무너지기()
		2:
			_타이머 -= delta
			if _타이머 <= 0.0:
				_되살리기()

func _플레이어가_위에_있나() -> bool:
	# 발판 윗면 바로 위 얇은 띠에 플레이어가 있는지 검사.
	# (Area2D 를 따로 두지 않고 좌표로만 판정 — 노드 수를 줄이고 씬을 단순하게 유지)
	var 플레이어들 := get_tree().get_nodes_in_group("player")
	if 플레이어들.is_empty():
		return false
	var p := 플레이어들[0] as Node2D
	if p == null:
		return false
	var 크기 := 크기_px()
	var 로컬 := to_local(p.global_position)
	return absf(로컬.x) <= 크기.x * 0.5 + 8.0 \
		and 로컬.y > -크기.y * 0.5 - 24.0 and 로컬.y < -크기.y * 0.5 + 12.0

func _무너지기() -> void:
	_상태 = 2
	_타이머 = 되살아나는시간
	position = _원래위치
	# 콜리전을 끄고 반투명하게 — "여기 있었지만 지금은 없다"를 보여준다
	set_deferred("collision_layer", 0)
	var 그림 := get_node_or_null("그림") as Sprite2D
	if 그림:
		var t := create_tween()
		t.tween_property(그림, "modulate:a", 0.18, 0.18)

func _되살리기() -> void:
	_상태 = 0
	set_deferred("collision_layer", 1)
	var 그림 := get_node_or_null("그림") as Sprite2D
	if 그림:
		var t := create_tween()
		t.tween_property(그림, "modulate:a", 1.0, 0.25)
