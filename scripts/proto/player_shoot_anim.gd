extends AnimatedSprite2D
## ============================================================================
## [2026-07-24 도형 · 신규] 발사 모션 컴포넌트 (Player Shoot Anim)
## ----------------------------------------------------------------------------
## 디자이너가 올린 `assets/player(shoot)/Shoot(black|white).png` (640px × 5프레임)를
## 실제 게임에 붙인다.
##
## ▣ 왜 player_anim.gd 를 안 고치고 별도 스프라이트를 쓰는가
##   `scripts/player_anim.gd` 는 **팀 소유 파일(무수정 원칙)** 이다.
##   거기에 shoot 애니를 추가하려면 파일도, SpriteFrames 리소스도 고쳐야 한다.
##   → 대신 형제 노드로 발사 전용 스프라이트를 하나 더 붙이고,
##     발사하는 동안만 기존 CharacterSprite 를 숨긴다. 제거하면 흔적 없이 사라진다.
##
## ▣ 정렬 규칙 (player_anim.gd 의 값을 그대로 따라간다 — 두 스프라이트가 어긋나면 안 됨)
##   FRAME_PX 640 / FOOT_Y 567 / TARGET_HEIGHT 130 / 부모 비균등 스케일 역보정.
## ============================================================================

const FRAMES_PATH := "res://assets/player(shoot)/shoot_frames.tres"
const FRAME_PX: float = 640.0
const FOOT_Y: float = 567.0
const TARGET_HEIGHT: float = 130.0
const 분할_셰이더 := preload("res://shaders/색분할.gdshader")
const 색겹침_스크립트 := preload("res://scripts/색겹침.gd")

var _player: CharacterBody2D
var _gun: Node
var _재생중: bool = false
var _본체: AnimatedSprite2D            ## 팀의 CharacterSprite (발사 중 숨김)
var _반대색_발사시트: AnimatedSprite2D  ## 흑/백 발사 시트를 겹쳐 경계선으로 자른다.

func setup(player: CharacterBody2D, gun: Node) -> void:
	_player = player
	_gun = gun
	if gun and gun.has_signal("fired"):
		gun.fired.connect(_발사됨)

func _ready() -> void:
	var frames := load(FRAMES_PATH)
	if frames == null:
		push_warning("[발사모션] shoot_frames.tres 를 찾지 못했습니다 — 발사 모션 비활성")
		queue_free()
		return
	sprite_frames = frames
	visible = false
	_반대색_발사시트 = AnimatedSprite2D.new()
	_반대색_발사시트.name = "색겹침"
	_반대색_발사시트.sprite_frames = frames
	_반대색_발사시트.set_script(색겹침_스크립트)
	add_child(_반대색_발사시트)
	_분할_시트_준비()
	if _player == null:
		_player = get_parent() as CharacterBody2D
	if _player:
		# 부모 Player 의 비균등 스케일(0.795, 0.368) 역보정 → 왜곡 없이 표시
		var ps := _player.scale
		var k := TARGET_HEIGHT / FRAME_PX
		scale = Vector2(k / ps.x, k / ps.y)
		position = Vector2(0, -(FOOT_Y - FRAME_PX * 0.5) * scale.y)
		_본체 = _player.get_node_or_null("CharacterSprite") as AnimatedSprite2D
	animation_finished.connect(_끝남)

func _발사됨() -> void:
	if sprite_frames == null or _player == null:
		return
	# 발사 시트도 검정/흰색 두 장을 겹쳐 잘라 두므로, 경계에 걸린 채 쏴도
	# 발사 모션은 보이면서 몸의 분할 색은 유지된다.
	var 얼굴색: int = _player.call("얼굴색") if _player.has_method("얼굴색") else _player.get("player_color")
	var 색 := "black" if 얼굴색 == ColorDefs.BLACK else "white"
	# 조준 방향(마우스)으로 좌우 반전 — 뒤를 보고 앞으로 쏘는 어색함 방지
	flip_h = get_global_mouse_position().x < _player.global_position.x
	_재생중 = true
	visible = true
	if _본체:
		_본체.visible = false
	play(색 + "_shoot")

func _끝남() -> void:
	if not _재생중:
		return
	_재생중 = false
	visible = false
	if _본체:
		_본체.visible = true

## 발사 도중 죽거나 색이 바뀌어도 본체가 계속 숨어 있지 않도록 안전장치
func _process(_delta: float) -> void:
	_분할_갱신()
	if _재생중 and not is_playing():
		_끝남()


## 발사 시트도 평상시 몸과 같은 셰이더·색표를 쓴다. 그래야 경계선이 발사 애니메이션을
## 가로질러도 한 프레임의 단색 덮개 없이 보이는 색과 판정 색이 일치한다.
func _분할_시트_준비() -> void:
	for 시트 in [self, _반대색_발사시트]:
		if 시트 == null:
			continue
		var 재질 := ShaderMaterial.new()
		재질.shader = 분할_셰이더
		시트.material = 재질


func _분할_갱신() -> void:
	if _player == null or not _player.has_method("분할_셰이더값"):
		return
	var 값: Dictionary = _player.call("분할_셰이더값")
	for 시트 in [self, _반대색_발사시트]:
		if 시트 == null:
			continue
		var 재질 := 시트.material as ShaderMaterial
		if 재질 == null:
			continue
		재질.set_shader_parameter("split_count", int(값["개수"]))
		재질.set_shader_parameter("line_1", 값["선1"])
		재질.set_shader_parameter("line_2", 값["선2"])
		재질.set_shader_parameter("color_table", 값["색표"])
		재질.set_shader_parameter("sheet_color",
			0.0 if String(시트.animation).begins_with("black_") else 1.0)
