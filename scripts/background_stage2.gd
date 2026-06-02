extends ParallaxBackground
## Stage 2 전용 4레이어 패럴랙스 배경 (타일링 없음)
##
## 이음새 없이 끊기지 않으면서도 레이어마다 다른 속도로 움직여
## 생동감 있는 원근감을 연출한다.
##
## ── 원리 ───────────────────────────────────────────────────────────
##   각 레이어 스프라이트를 수식으로 크기·위치를 계산해서,
##   카메라가 camera_rect 안 어디에 있어도 화면 밖이 보이지 않는다.
##   모션 배율(motion_scale)이 작을수록(멀리 있는 레이어)
##   더 많이 확대해야 하고, 클수록(가까운 레이어) 적게 확대해도 된다.
##
## ── 수식 ───────────────────────────────────────────────────────────
##   화면 좌표에서의 스프라이트 위치:
##     screen_pos = sprite.position + camera_pos * motion_scale
##   camera_pos 가 camera_rect.end 일 때 screen_pos = (0,0) 이 되도록 배치:
##     sprite.position = -camera_rect.end * motion_scale
##   필요한 스케일(카메라가 min 위치에 있을 때도 화면을 채우려면):
##     scale ≥ (motion_scale * 카메라범위 + 뷰포트크기) / 텍스처크기

## 카메라 이동 범위 — stage.gd 의 camera_limit 값과 일치시킬 것
## Rect2(left, top, width, height)
@export var camera_rect: Rect2 = Rect2(-1100.0, -200.0, 2700.0, 4400.0)

## 레이어별 스크롤 배율 (x=수평, y=수직)
## 0 = 고정, 1 = 카메라와 같이 이동 (원근 없음)
## 값이 클수록 가까운 배경처럼 빠르게 움직임
@export var sky_motion:   Vector2 = Vector2(0.05, 0.05)
@export var mid_motion:   Vector2 = Vector2(0.15, 0.20)
@export var front_motion: Vector2 = Vector2(0.30, 0.45)
@export var near_motion:  Vector2 = Vector2(0.50, 0.75)

const TEX_W: float = 2560.0
const TEX_H: float = 1080.0

@onready var _layer1:  ParallaxLayer = $Layer1_Sky
@onready var _layer2:  ParallaxLayer = $Layer2_Mid
@onready var _layer3:  ParallaxLayer = $Layer3_Front
@onready var _layer4:  ParallaxLayer = $Layer4_Near
@onready var _sprite1: Sprite2D = $Layer1_Sky/Sprite2D
@onready var _sprite2: Sprite2D = $Layer2_Mid/Sprite2D
@onready var _sprite3: Sprite2D = $Layer3_Front/Sprite2D
@onready var _sprite4: Sprite2D = $Layer4_Near/Sprite2D


func _ready() -> void:
	_apply_layers()


func _apply_layers() -> void:
	var vp: Vector2   = get_viewport().get_visible_rect().size

	# 카메라가 도달할 수 있는 최대 좌표 (Rect2.end = position + size)
	var cx_end: float = camera_rect.position.x + camera_rect.size.x
	var cy_end: float = camera_rect.position.y + camera_rect.size.y

	var motions: Array[Vector2] = [sky_motion, mid_motion, front_motion, near_motion]
	var layers:  Array          = [_layer1, _layer2, _layer3, _layer4]
	var sprites: Array          = [_sprite1, _sprite2, _sprite3, _sprite4]

	for i in 4:
		var m:      Vector2      = motions[i]
		var layer:  ParallaxLayer = layers[i]
		var sprite: Sprite2D     = sprites[i]

		# ── 이동 배율 설정 (타일링 완전 비활성화) ──────────────────
		layer.motion_scale     = m
		layer.motion_mirroring = Vector2.ZERO

		# ── 스케일 계산 ────────────────────────────────────────────
		# 카메라가 최소 위치로 이동해도 스프라이트가 화면을 완전히 덮어야 함
		# 필요 너비 = motion_scale * 카메라 이동 범위 + 뷰포트 크기
		var scale_x: float = (m.x * camera_rect.size.x + vp.x) / TEX_W
		var scale_y: float = (m.y * camera_rect.size.y + vp.y) / TEX_H
		var scale_v: float = max(scale_x, scale_y) * 1.05  # 5% 여유

		# ── 위치 계산 ────────────────────────────────────────────
		# 카메라가 최대 위치(cx_end, cy_end)에 있을 때
		# screen_pos = sprite.position + (cx_end, cy_end) * m = (0, 0)
		# → 카메라 최대 위치에서 스프라이트 좌상단이 화면 좌상단에 정확히 맞음
		sprite.centered  = false
		sprite.scale     = Vector2(scale_v, scale_v)
		sprite.position  = Vector2(
			-cx_end * m.x,
			-cy_end * m.y
		)
