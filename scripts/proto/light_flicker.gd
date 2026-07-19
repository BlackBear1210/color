extends PointLight2D
## [2026-07-19 도형 · 신규] 광원 깜빡임 — 가로등·창문 불빛에 "살아 있는" 미세 흔들림.
##
## 원리: 주기가 서로 다른 사인파 두 개 + 픽셀 해시 노이즈를 섞으면
## 규칙성이 눈에 안 보이는 자연스러운 촛불/형광등 흔들림이 된다.
## (로비 lobby.gd 의 중앙 광원 맥동과 같은 계열 — 톤 통일)
##
## 사용법: PointLight2D 에 이 스크립트를 붙이고 Inspector 에서 강도만 조절.
## base_energy 를 0 으로 두면 _ready 시점의 energy 를 기준값으로 쓴다.
class_name LightFlicker

## 기준 밝기 (0 = 현재 energy 를 그대로 기준으로 사용)
@export var base_energy: float = 0.0
## 흔들림 폭 (기준 밝기 대비 비율, 0.1 = ±10%)
@export var flicker_amount: float = 0.12
## 흔들림 속도 배율
@export var speed: float = 1.0

var _t: float = 0.0

func _ready() -> void:
	if base_energy <= 0.0:
		base_energy = energy
	# 같은 씬에 여러 개 있어도 위상이 겹치지 않게 위치로 시드를 흩뿌린다
	_t = fmod(global_position.x * 0.37 + global_position.y * 0.13, 100.0)

func _process(delta: float) -> void:
	_t += delta * speed
	# 느린 파도(0.9Hz) + 빠른 잔떨림(2.7Hz) — lobby.gd 중앙 광원과 같은 조합
	var wave := sin(_t * 0.9) * 0.6 + sin(_t * 2.7) * 0.4
	energy = base_energy * (1.0 + wave * flicker_amount)
