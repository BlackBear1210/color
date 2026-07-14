extends Node2D
## [2026-07-14 도형 · v2.2] 테스트 존 공용 조립 스크립트. zone_01 / zone_02 가 공유한다.
## 기존 씬/코드를 수정하지 않기 위해 "런타임"에 조립:
##  1. Player 안의 기존 Gun(gun.gd) 노드를 제거 (파일은 그대로, 이 맵에서만 비활성)
##  2. ProtoGun 을 붙이고 PaintSystem·지형·붓 커서 UI 를 서로 연결
##  3. ★공룡 캐릭터(arks DinoSprites 원본 리컬러) 장착 — v2.2 (2026-07-14 사용자 확정):
##     · 원본 시트의 애니메이션 사용: 대기(꼬리 흔들기)·걷기·사망(피격 모션 유용)
##     · 좌우 반전은 마우스가 아니라 "이동 방향" 기준 (자연스러운 움직임)
##     · 발사 모션은 없음 (원본에 없어서 생략 — 사용자 확정)
##     · 흑/백 2버전 리컬러(반전 외곽선), Shift 전환 시 시트 스왑
##     · 에셋 출처: https://arks.itch.io/dino-characters (무료, 크레딧 @ScissorMarks 권장)
##  4. 색 사망 판정 (규칙 v1.3): 반대색 발판을 밟으면 즉시 사망 → 사망 모션 재생 →
##     스폰 지점·스폰 색으로 리스폰. 회색 = (일단) 흑백 모두 안전한 중립 지형.
##     ⚠ 정식 구현은 P-A (여기서는 player.gd 무수정 — 존이 매 프레임 발밑 타일을 검사)
class_name ZoneLab

const PROTO_GUN := preload("res://scripts/proto/proto_gun.gd")

## 리컬러된 공룡 시트 (tools 아님 — 원본은 스크래치, 산출물만 저장소에)
const DINO_SHEET := {
	ColorDefs.BLACK: "res://assets/characters/dino_sheet_black.png",
	ColorDefs.WHITE: "res://assets/characters/dino_sheet_white.png",
}

## DinoSprites 시트 규격: 24×24 프레임이 가로 한 줄로 이어짐
const FRAME_PX := 24
## 애니메이션 구간 (시트 프레임 번호). DinoSprites 공통 배치:
## 0~3 대기 / 4~9 걷기 / 10~12 차기 / 13~16 피격 / 17~23 전력질주
const ANIM := {
	"idle": { "start": 0,  "len": 4, "fps": 6.0 },
	"walk": { "start": 4,  "len": 6, "fps": 10.0 },
	"die":  { "start": 13, "len": 4, "fps": 8.0 },   # 피격 모션을 사망 연출로 사용
}

## 화면(월드) 기준 프레임 크기(px) — 24px 원본의 2배 (요청: "크기만 줄이고" = 작게 유지)
const CHAR_SCREEN_SIZE := Vector2(48, 48)
## 프레임 하단의 투명 여백(px, 원본 기준) — 발이 프레임 바닥에서 이만큼 위에 있음
const FOOT_PAD_PX: float = 2.0
## 콜리전 크기(화면 px) — 프레임 여백을 뺀 대략의 몸통
const BODY_SCREEN := Vector2(30, 34)
## 입(페인트를 뱉는 위치) — 플레이어 로컬 좌표 (화면 기준 약 (14, -26))
const MOUTH_POS := Vector2(18, -70)
## 사망 모션 재생 시간(초) — 이 동안 조작이 멈추고, 끝나면 리스폰
const DEATH_ANIM_TIME: float = 0.55
## 사망 리스폰 직후 무적 시간(초)
const RESPAWN_GRACE: float = 0.6

@onready var paint_system: PaintSystem = $PaintSystem
@onready var terrain: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $Player
@onready var brush_ui: BrushCursorUI = $UI/BrushCursorUI

var _sprite: Sprite2D
var _sheets: Dictionary = {}        # 색 → Texture2D
var _anim_name: String = "idle"
var _anim_time: float = 0.0
var _face_left: bool = false
var _spawn_pos: Vector2
var _spawn_color: int = ColorDefs.BLACK
var _grace: float = 0.0
var _dying: bool = false
var _death_count: int = 0

func _ready() -> void:
	# 1) 기존 총 비활성화 (gun.gd 는 즉시 직선 발사 → 이 맵에서는 프로토 총 사용)
	var old_gun := player.get_node_or_null("Gun")
	if old_gun:
		old_gun.queue_free()

	# 2) 프로토 총 부착 (입 위치)
	var gun: ProtoGun = PROTO_GUN.new()
	gun.name = "ProtoGun"
	gun.position = MOUTH_POS
	player.add_child(gun)
	gun.setup(paint_system, terrain, player)

	# 3) 붓 커서 UI 연결
	brush_ui.setup(paint_system, terrain, player)

	# 4) 공룡 캐릭터 장착 + 리스폰 지점·색 기억
	_setup_dino()
	_spawn_pos = player.global_position
	_spawn_color = player.get("player_color")

## 공룡 스프라이트 + 콜리전 축소. Player.tscn 은 만지지 않고 이 인스턴스에서만 바꾼다.
func _setup_dino() -> void:
	for color in DINO_SHEET:
		if not ResourceLoader.exists(DINO_SHEET[color]):
			return   # 시트가 없으면 기존 Placeholder 유지
		_sheets[color] = load(DINO_SHEET[color])

	_sprite = Sprite2D.new()
	_sprite.name = "DinoSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 도트 또렷하게
	_sprite.texture = _sheets[ColorDefs.BLACK]
	_sprite.hframes = int(_sprite.texture.get_width() / float(FRAME_PX))
	# 로컬 스케일 = (원하는 화면 크기 / 프레임 크기) ÷ Player 노드 스케일(0.795, 0.368) 역보정
	var ps := player.scale
	_sprite.scale = Vector2(
		CHAR_SCREEN_SIZE.x / FRAME_PX / ps.x,
		CHAR_SCREEN_SIZE.y / FRAME_PX / ps.y)
	# 발(프레임 바닥에서 FOOT_PAD_PX 위)이 로컬 y=0 바닥선에 닿도록 중심을 올림
	var px_scale := CHAR_SCREEN_SIZE.y / FRAME_PX               # 화면px / 원본px
	var center_up := (FRAME_PX * 0.5 - FOOT_PAD_PX) * px_scale  # 발→프레임중심 거리(화면px)
	_sprite.position = Vector2(0, -center_up / ps.y)
	player.add_child(_sprite)

	var ph := player.get_node_or_null("Placeholder")
	if ph:
		ph.visible = false

	# 콜리전을 몸통 크기로 축소 — 새 Shape 인스턴스를 대입하므로
	# Player.tscn 의 공유 리소스(64×128)는 변하지 않는다 (main.tscn 영향 없음).
	var col := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(BODY_SCREEN.x / ps.x, BODY_SCREEN.y / ps.y)
		col.shape = shape
		col.position = Vector2(0, -BODY_SCREEN.y * 0.5 / ps.y)

# ── 애니메이션 (대기/걷기/사망) ─────────────────────────────────────────
func _process(delta: float) -> void:
	if _sprite == null:
		return
	# 색 상태에 맞는 시트 스왑
	if not _dying:
		var col: int = player.get("player_color")
		if _sheets.has(col) and _sprite.texture != _sheets[col]:
			_sprite.texture = _sheets[col]
		# 이동 방향 기준 좌우 반전 (마우스 방향 아님 — 자연스러운 움직임)
		var vx: float = player.velocity.x
		if vx > 5.0:
			_face_left = false
		elif vx < -5.0:
			_face_left = true
		_set_anim("walk" if absf(vx) > 5.0 else "idle")
	_sprite.flip_h = _face_left

	# 프레임 진행
	var a: Dictionary = ANIM[_anim_name]
	_anim_time += delta
	var idx := int(_anim_time * a["fps"])
	if _anim_name == "die":
		idx = mini(idx, a["len"] - 1)        # 사망은 마지막 프레임에서 멈춤
	else:
		idx = idx % int(a["len"])            # 대기/걷기는 반복
	_sprite.frame = a["start"] + idx

func _set_anim(name_: String) -> void:
	if _anim_name != name_:
		_anim_name = name_
		_anim_time = 0.0

# ── 색 사망 판정 (규칙 v1.3) ────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	_check_color_death()

func _check_color_death() -> void:
	if _dying or _grace > 0.0 or not player.is_on_floor():
		return
	var atlas := _standing_tile_atlas()
	if atlas == Vector2i(-1, -1):
		return
	var col: int = player.get("player_color")
	var opposite := (atlas == PaintSystem.ATLAS_BLACK and col == ColorDefs.WHITE) \
		or (atlas == PaintSystem.ATLAS_WHITE and col == ColorDefs.BLACK)
	# 회색(ATLAS_GRAY)·무색·자기색은 전부 안전. 반대색만 사망.
	if opposite:
		_die()

## 발밑 타일의 아틀라스 좌표. 중앙이 빈 셀이면 좌우 발끝도 확인. 없으면 (-1,-1).
func _standing_tile_atlas() -> Vector2i:
	for off_x in [0.0, -12.0, 12.0]:
		var probe := player.global_position + Vector2(off_x, 8.0)
		var cell := terrain.local_to_map(terrain.to_local(probe))
		if terrain.get_cell_source_id(cell) != -1:
			return terrain.get_cell_atlas_coords(cell)
	return Vector2i(-1, -1)

## 사망: 조작 정지 → 사망 모션 재생 → 스폰 위치·스폰 색으로 리스폰.
## 색 복원 이유: 반대색인 채 리스폰하면 스폰 바닥에서 또 죽는 무한 루프가 되므로.
func _die() -> void:
	_dying = true
	_death_count += 1
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)        # 사망 모션 동안 조작 정지 (파일 무수정, 런타임만)
	_set_anim("die")
	brush_ui.show_message("💀 반대색 지형을 밟아 사망 (%d회)" % _death_count)
	await get_tree().create_timer(DEATH_ANIM_TIME).timeout
	player.global_position = _spawn_pos
	if player.get("player_color") != _spawn_color:
		player.call("_toggle_color")
	player.set_physics_process(true)
	_grace = RESPAWN_GRACE
	_dying = false
	_set_anim("idle")
