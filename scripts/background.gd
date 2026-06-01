extends ParallaxBackground

# ═══════════════════════════════════════════════════════════════════
#  패럴랙스(시차) 배경 컨트롤러
#  세 레이어가 각기 다른 속도로 스크롤되어 원근감 있는 배경을 연출합니다.
#  Camera2D 가 오른쪽으로 이동하면 각 레이어는 motion_scale 비율로 왼쪽으로 밀립니다.
#
#  텍스처 교체 방법:
#    씬 트리에서 Layer1_Sky/Sprite2D (또는 Layer2_Mid, Layer3_Front) 를 클릭 →
#    인스펙터의 Texture 항목에 FileSystem 패널에서 이미지를 드래그해서 연결
# ═══════════════════════════════════════════════════════════════════


# ── 레이어별 스크롤 속도 ──────────────────────────────────────────
# motion_scale.x : 카메라 이동량 대비 이 레이어가 움직이는 비율
#
#   0.0 → 완전히 고정 (무한히 먼 배경처럼 보임)
#   1.0 → 카메라와 동일한 속도 (원근 효과 없음)
#   0.1 → 카메라가 100px 이동할 때 10px 만 이동 (아주 멀리 있는 느낌)
#
# ▼ 속도를 조절하고 싶을 때:
#   에디터 인스펙터에서 아래 슬라이더를 조절하거나 직접 숫자를 입력하세요.

## 하늘 레이어 스크롤 속도 — 가장 멀리 있는 배경, 가장 느리게 움직임
@export_range(0.0, 1.0, 0.01) var sky_speed: float   = 0.05

## 중간 레이어 스크롤 속도 — 중간 거리 배경
@export_range(0.0, 1.0, 0.01) var mid_speed: float   = 0.20

## 전경 레이어 스크롤 속도 — 가장 가까이 있는 배경, 가장 빠르게 움직임
@export_range(0.0, 1.0, 0.01) var front_speed: float = 0.45


# ── 내부 노드 참조 (씬 트리 노드와 자동으로 연결됨) ──────────────
@onready var _layer1:  ParallaxLayer = $Layer1_Sky
@onready var _layer2:  ParallaxLayer = $Layer2_Mid
@onready var _layer3:  ParallaxLayer = $Layer3_Front
@onready var _sprite1: Sprite2D      = $Layer1_Sky/Sprite2D
@onready var _sprite2: Sprite2D      = $Layer2_Mid/Sprite2D
@onready var _sprite3: Sprite2D      = $Layer3_Front/Sprite2D


func _ready() -> void:
	_apply_speeds()  # 스크롤 속도 적용
	_apply_tiling()  # 뷰포트 크기에 맞는 스케일 및 타일링 설정


# ─────────────────────────────────────────────────────────────────
# 스크롤 속도 적용
# motion_scale = Vector2(수평_비율, 수직_비율)
#   수직(y)은 0.0 고정 — 위아래 스크롤 없음
#
# ▼ 코드에서 직접 바꾸고 싶다면 아래 숫자를 수정하세요.
# ─────────────────────────────────────────────────────────────────
func _apply_speeds() -> void:
	_layer1.motion_scale = Vector2(sky_speed,   0.0)  # 하늘: 가장 느림
	_layer2.motion_scale = Vector2(mid_speed,   0.0)  # 중간
	_layer3.motion_scale = Vector2(front_speed, 0.0)  # 전경: 가장 빠름


# ─────────────────────────────────────────────────────────────────
# 타일링(가로 무한 반복) + 스케일 설정
#
# 뷰포트 높이에 맞게 배경 이미지를 자동 스케일하고,
# 그 스케일된 너비만큼 반복(타일링)하여 카메라가 어디를 봐도
# 배경이 끊기지 않도록 합니다.
#
# ▼ 배경이 너무 크거나 작게 보인다면:
#   아래 scale_v 계산식에 원하는 배율을 곱하세요 (예: scale_v * 0.8)
# ─────────────────────────────────────────────────────────────────
func _apply_tiling() -> void:
	# 현재 실행 중인 뷰포트의 실제 크기를 가져옴
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	# 배경 이미지의 원본 크기 (BG_Layer*.png 기준)
	# ▼ 다른 크기의 이미지로 교체했다면 이 두 값을 맞게 바꾸세요.
	const TEX_W: float = 2560.0
	const TEX_H: float = 1080.0

	# 뷰포트 높이에 꽉 차도록 스케일 계산
	var scale_v: float   = vp_size.y / TEX_H
	var display_w: float = TEX_W * scale_v  # 스케일 후 이미지의 가로 길이(px)

	# 세 스프라이트 모두 동일한 스케일 + 좌상단 기준 배치
	for sprite: Sprite2D in [_sprite1, _sprite2, _sprite3]:
		sprite.centered = false          # 좌상단(0,0)을 기준점으로 사용
		sprite.position = Vector2.ZERO   # 뷰포트 좌상단에서 시작
		sprite.scale    = Vector2(scale_v, scale_v)

	# 타일 너비 = 스케일된 이미지 가로 길이
	# motion_mirroring: 이 픽셀만큼 스크롤되면 이미지가 반복됨
	# → 이 값이 이미지의 실제 가로 길이와 다르면 이음새(gap)가 생깁니다.
	var mirror := Vector2(display_w, 0.0)
	_layer1.motion_mirroring = mirror
	_layer2.motion_mirroring = mirror
	_layer3.motion_mirroring = mirror
