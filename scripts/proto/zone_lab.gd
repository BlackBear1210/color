extends Node2D
## [2026-07-18 도형 · v2.3] 테스트 존 공용 조립 스크립트. zone_01 / zone_02 / world_1 이 공유.
## 기존 씬/코드를 수정하지 않기 위해 "런타임"에 조립한다:
##  1. Player 안의 기존 Gun(gun.gd) 노드를 제거 (파일은 그대로, 이 맵에서만 비활성)
##  2. ProtoGun 을 붙이고 PaintSystem·지형·붓 커서 UI 를 서로 연결
##  3. 색 사망 판정 (규칙 v1.3): 반대색 발판을 밟으면 즉시 사망 → 사망 모션 재생 →
##     스폰 지점·스폰 색으로 리스폰. 회색 = 흑백 모두 안전한 중립 지형.
##     ⚠ 정식 구현은 P-A (여기서는 player.gd 무수정 — 존이 매 프레임 발밑 타일을 검사)
##
## v2.3 변경 (2026-07-18):
##  - 구형 공룡(DinoSprite) 코드 삭제 — 팀원의 정식 캐릭터(CharacterSprite +
##    player_anim.gd, 커밋 db8f55e)가 들어와서 시트가 이중이 될 뻔한 것을 정리.
##    사망 모션도 player_anim.gd 의 death 훅(물리 정지 감지)에 위임한다.
##  - ★ProtoCamera 부착: 룩어헤드+플랫폼 스냅 카메라 (Player.tscn 의 기본 카메라는
##    런타임에 enabled=false — 파일 무수정). 리밋은 지형 크기에서 자동 계산.
##  - ★ProtoMotion 부착: 착지 스쿼시&스트레치·달리기 기울임 (절차적 2차 모션)
##  - ★ZoneVisuals 부착: 환경광 + 플레이어 광원 + 배경 노멀맵 주입 + 비네트
##  - (v2.4, 07-18) 버렛 꼬리(VerletTail) 제거 — 캐릭터 디자인과 안 어울린다는 피드백
class_name ZoneLab

const PROTO_GUN := preload("res://scripts/proto/proto_gun.gd")
const PROTO_CAMERA := preload("res://scripts/proto/proto_camera.gd")
const PROTO_MOTION := preload("res://scripts/proto/proto_motion.gd")
const ZONE_VISUALS := preload("res://scripts/proto/zone_visuals.gd")

## 입(페인트를 뱉는 위치) — 플레이어 로컬 좌표 (화면 기준 약 (14, -26))
const MOUTH_POS := Vector2(18, -70)
## 사망 모션 재생 시간(초) — 이 동안 조작이 멈추고, 끝나면 리스폰
const DEATH_ANIM_TIME: float = 0.55
## 사망 리스폰 직후 무적 시간(초)
const RESPAWN_GRACE: float = 0.6
## 지형 크기에서 카메라 리밋을 만들 때 사방 여유(px)
const LIMIT_MARGIN: float = 64.0

@onready var paint_system: PaintSystem = $PaintSystem
@onready var terrain: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $Player
@onready var brush_ui: BrushCursorUI = $UI/BrushCursorUI

var camera: ProtoCamera
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

	# 3) 붓 커서 UI 연결 + UI 레이어를 위로 (비네트(5)보다 항상 위에 그려지게)
	brush_ui.setup(paint_system, terrain, player)
	($UI as CanvasLayer).layer = 10

	# 4) 리스폰 지점·색 기억
	_spawn_pos = player.global_position
	_spawn_color = player.get("player_color")

	# 5) ★카메라 v2 — Player.tscn 내장 카메라는 끄고(파일 무수정) 룩어헤드 카메라로 교체
	var old_cam := player.get_node_or_null("Camera2D") as Camera2D
	if old_cam:
		old_cam.enabled = false
	camera = PROTO_CAMERA.new()
	camera.name = "ProtoCamera"
	add_child(camera)
	camera.set_limit_rect(_auto_limit_rect(), false)
	camera.setup(player)

	# 6) ★절차적 모션: 스쿼시&스트레치·기울임
	# (버렛 꼬리는 2026-07-18 사용자 피드백 "캐릭터와 안 어울림"으로 제거 —
	#  스크립트도 삭제됨. 필요하면 git 이력의 verlet_tail.gd 참조)
	var motion: ProtoMotion = PROTO_MOTION.new()
	motion.name = "ProtoMotion"
	player.add_child(motion)

	# 7) ★라이팅/분위기 리그 (환경광·플레이어 광원·배경 노멀맵·비네트)
	var visuals: ZoneVisuals = ZONE_VISUALS.new()
	visuals.name = "ZoneVisuals"
	add_child(visuals)
	visuals.setup(player)

## 지형이 실제로 찍힌 범위 → 카메라 리밋 사각형 (월드 좌표)
func _auto_limit_rect() -> Rect2:
	var used := terrain.get_used_rect()
	var ts := Vector2(terrain.tile_set.tile_size)
	var pos := Vector2(used.position) * ts - Vector2(LIMIT_MARGIN, LIMIT_MARGIN)
	var size := Vector2(used.size) * ts + Vector2(LIMIT_MARGIN, LIMIT_MARGIN) * 2.0
	return Rect2(pos, size)

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

## 사망: 조작 정지 → 사망 모션(player_anim.gd 의 death 훅) → 스폰 위치·색으로 리스폰.
## 색 복원 이유: 반대색인 채 리스폰하면 스폰 바닥에서 또 죽는 무한 루프가 되므로.
func _die() -> void:
	_dying = true
	_death_count += 1
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)        # 물리 정지 = player_anim.gd 가 death 재생 (파일 무수정)
	brush_ui.show_message("💀 반대색 지형을 밟아 사망 (%d회)" % _death_count)
	await get_tree().create_timer(DEATH_ANIM_TIME).timeout
	player.global_position = _spawn_pos
	if player.get("player_color") != _spawn_color:
		player.call("_toggle_color")
	player.set_physics_process(true)
	_grace = RESPAWN_GRACE
	_dying = false
	# 리스폰 직후 카메라도 스폰 위치로 즉시 스냅 (허공을 길게 팬 하지 않도록)
	if camera:
		camera.setup(player)
