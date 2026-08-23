@tool
extends AnimatedSprite2D
## ============================================================================
## [2026-08-23 신규] 색 겹침 — 반대 색 시트를 같은 자세로 겹쳐 그린다
## ----------------------------------------------------------------------------
## ▣ 왜 있나
##   플레이어 몸이 색 경계에 걸치면 상체·하체 색이 달라진다. 그때 두 색을 동시에
##   보여줘야 하는데, 시트가 흑·백 두 벌로 따로 그려져 있다(외곽선·명암이 다르다).
##   → 셰이더로 색을 덮어씌우지 않고, **두 시트를 겹쳐 놓고 각자 자기 몫만 남긴다.**
##     자르는 일은 `shaders/색분할.gdshader` 가 한다.
##
## ▣ 왜 부모의 자식으로 붙나
##   `player_anim.gd` 에는 스쿼시·낙하 스트레치·지면 경사 정렬·발 스냅 같은 절차적
##   변형이 잔뜩 들어 있다. 형제로 두면 그 계산을 통째로 복제해야 하고, 한쪽만 고치면
##   두 몸이 어긋난다. **자식으로 두면 변형이 전부 상속**되므로 여기서는
##   프레임 번호와 좌우 반전만 따라가면 된다.
##
## ▣ 좌우 반전은 왜 따로 복사하나
##   `flip_h` 는 변환(Transform)이 아니라 그리기 속성이라 자식에게 상속되지 않는다.
##   빼먹으면 뒤돌아설 때 상·하체가 서로 반대를 본다.
## ============================================================================

var _부모: AnimatedSprite2D = null


func _ready() -> void:
	_부모 = get_parent() as AnimatedSprite2D
	# 부모와 같은 시트를 쓴다 — 애니메이션 이름만 반대 색으로 바꿔 재생한다.
	if _부모 and sprite_frames == null:
		sprite_frames = _부모.sprite_frames
	# 부모가 이미 자기 자리를 잡아 두므로 여기서는 원점에 붙어만 있는다.
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE


func _process(_delta: float) -> void:
	if _부모 == null or not is_instance_valid(_부모):
		_부모 = get_parent() as AnimatedSprite2D
		if _부모 == null:
			return
	if sprite_frames == null:
		sprite_frames = _부모.sprite_frames
		if sprite_frames == null:
			return

	var 반대 := _반대색_이름(_부모.animation)
	if 반대 == "" or not sprite_frames.has_animation(반대):
		visible = false
		return
	visible = true

	if animation != 반대:
		play(반대)
	# ⚠ frame 만 맞추면 재생 위치(frame_progress)가 어긋나 미세하게 떤다.
	#   둘을 한 번에 맞추는 전용 함수를 쓴다.
	set_frame_and_progress(_부모.frame, _부모.frame_progress)
	flip_h = _부모.flip_h


## "black_idle" ↔ "white_idle". 접두어가 없으면 빈 문자열.
func _반대색_이름(이름: String) -> String:
	if 이름.begins_with("black_"):
		return "white_" + 이름.substr(6)
	if 이름.begins_with("white_"):
		return "black_" + 이름.substr(6)
	return ""
