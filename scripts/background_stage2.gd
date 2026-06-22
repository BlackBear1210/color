extends ParallaxBackground
## Stage 2 전용 배경 (세로 고정 백드롭 방식)
##
## ▼ 2026-06-22 재작성 #2 (사용자 피드백: "배경이 아래로 빨려 들어간다 / 위아래로 붙이지 마라")
##   [문제] 직전 버전은 배경을 세로로 무한 반복(motion_mirroring)시켰는데,
##          가로로 된 '숲 그림 한 장'을 위아래로 이어 붙이니
##          위 타일의 '나뭇잎'과 아래 타일의 '뿌리'가 맞닿아 어색한 이음새가 생겼다.
##   [근본 원인] 세로로 긴 맵 + 배경 1장 → 세로로 '붙이는(타일)' 방식은 원천적으로 부자연스럽다.
##   [해법] 배경을 세로로 반복·스크롤하지 말고, **화면을 꽉 채운 채 고정**한다.
##          → 올라가도 같은 숲 한 장이 늘 뒤에 있으니 이음새가 아예 없다(세로 게임의 표준 기법).
##          깊이감을 위해 레이어마다 '아주 조금만' 세로로 따라가되,
##          이미지 가장자리가 절대 드러나지 않도록 여유분(margin) 안에서 clamp 한다.

## 레이어별 세로 시차(깊이) 강도. 0=완전 고정, 클수록 더 따라 움직임(아주 작게).
## 멀리 있는 sky 는 거의 고정, 가까운 near 는 살짝 더 반응.
@export var sky_depth:   float = 0.02
@export var mid_depth:   float = 0.04
@export var front_depth: float = 0.06
@export var near_depth:  float = 0.09

## 화면보다 얼마나 더 크게 키울지(세로로 살짝 움직일 '여유분' 확보용). 1.0=딱 맞음.
@export var oversize: float = 1.18

@onready var _layers: Array[ParallaxLayer] = [
	$Layer1_Sky, $Layer2_Mid, $Layer3_Front, $Layer4_Near
]
@onready var _sprites: Array[Sprite2D] = [
	$Layer1_Sky/Sprite2D, $Layer2_Mid/Sprite2D, $Layer3_Front/Sprite2D, $Layer4_Near/Sprite2D
]

# 각 레이어의 런타임 계산값(매 프레임 위치 보정에 사용)
var _depths: Array[float] = []
var _base_y: Array[float] = []     # 화면 세로 중앙(스프라이트 기준점)
var _margin_y: Array[float] = []   # 가장자리를 안 드러내고 움직일 수 있는 최대 폭
var _ready_ok: bool = false


func _ready() -> void:
	_apply_layers()
	get_viewport().size_changed.connect(_apply_layers)


func _apply_layers() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_depths  = [sky_depth, mid_depth, front_depth, near_depth]
	_base_y  = []
	_margin_y = []

	for i in _layers.size():
		var layer: ParallaxLayer = _layers[i]
		var sprite: Sprite2D = _sprites[i]
		if sprite == null or sprite.texture == null:
			_base_y.append(0.0); _margin_y.append(0.0)
			continue

		var tex: Vector2 = sprite.texture.get_size()
		if tex.x <= 0.0 or tex.y <= 0.0:
			_base_y.append(0.0); _margin_y.append(0.0)
			continue

		# ── 균등 커버 배율: 화면을 가로·세로 모두 덮고, oversize 만큼 여유 확보 ──
		var s: float = max(vp.x / tex.x, vp.y / tex.y) * oversize

		sprite.centered = true
		sprite.scale    = Vector2(s, s)
		# 화면 중앙에 고정(가로도 중앙). 가로는 motion_scale 로 살짝 시차.
		sprite.position = Vector2(vp.x * 0.5, vp.y * 0.5)

		# ── 세로는 '붙이지' 않는다: 타일링 완전 해제 + 세로 스크롤 0 ──
		#   (가로만 ParallaxLayer 가 아주 약하게 시차 처리, 세로는 아래 _process 가 clamp 로 직접 제어)
		layer.motion_scale     = Vector2(_depths[i] * 0.5, 0.0)
		layer.motion_mirroring = Vector2.ZERO

		_base_y.append(sprite.position.y)
		# 세로로 움직여도 위/아래 가장자리가 안 보이도록 하는 한계폭(스프라이트 높이 - 화면)/2
		_margin_y.append(max((tex.y * s - vp.y) * 0.5, 0.0))

	_ready_ok = true


func _process(_dt: float) -> void:
	if not _ready_ok:
		return
	# 카메라(=ParallaxBackground.scroll_offset)의 세로 위치에 비례해 '아주 조금만' 따라 움직이되,
	# margin 을 넘지 않게 clamp → 이미지 가장자리(검은 빈 공간)가 절대 드러나지 않는다.
	var sy: float = scroll_offset.y
	for i in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		if sprite == null:
			continue
		var drift: float = clamp(sy * _depths[i], -_margin_y[i], _margin_y[i])
		sprite.position.y = _base_y[i] + drift
