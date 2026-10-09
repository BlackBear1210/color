extends Node2D
## 플레이어 행동에만 반응하는 짧은 파티클 효과.
## 카메라 줌 0.85에서도 실루엣을 가리지 않도록 작은 입자의 방향과 수명으로 동작을 읽힌다.

const 점프_쪽당_개수 := 5
const 명중_잔점 := 9

@export_group("파티클 크기")
## Player > ActionFX 인스펙터에서 모든 행동 효과의 최종 크기만 조절한다.
@export_range(0.25, 3.0, 0.05) var 크기_배율 := 1.0

var _먼지_텍스처: Texture2D
var _물감_텍스처: Texture2D


## ── [2026-10-08 Claude] 점프 이펙트 약·강·점프대 (기획 §4-D · 카드 2) ─────────────────────
## 이 게임은 가변 점프(버튼을 일찍 떼면 상승 ×0.4)라 **이륙 순간엔 세기를 모른다**.
##   → 이륙 = 약 이펙트로 시작 → 버튼을 0.12초 넘게 누르고 있으면 player.gd 가 `점프_강하게()` 를 불러
##     같은 이펙트가 강 시트로 **자라난다**. 버튼을 일찍 떼면 약으로 끝난다. 점프대 = 가장 강함(파문 + 속도 줄).
const 프레임효과 := preload("res://scripts/effects/잉크_프레임효과.gd")
@export_group("점프 이펙트 (2026-10-08)")
## 끄면 옛 먼지 효과만 낸다(비교·되돌리기용).
@export var 잉크_이펙트_사용 := true
@export_range(0.05, 1.0, 0.01) var 약_시간 := 0.18
@export_range(0.05, 1.0, 0.01) var 강_시간 := 0.28
@export_range(0.05, 1.0, 0.01) var 점프대_시간 := 0.35
@export_range(0.05, 1.0, 0.01) var 솟구침_시간 := 0.30
## 게임 크기 배율 — 도구가 맞춘 크기(약 ≈ 몸 폭 · 점프대 ≈ 몸 폭 2.5배)에 곱한다.
@export_range(0.3, 3.0, 0.05) var 잉크_배율 := 1.0

var _마지막_점프: Node = null
## [2026-10-08] 새 이펙트는 **현재 씬**에 붙인다(명중 이펙트와 같은 방식).
##   ⚠ Player.tscn 의 ActionFX 는 2026-08-25(41da16d) 부터 `visible = false` 다 — 그 아래 자식은
##   top_level 이어도 보이지 않는다(그래서 옛 점프·착지 먼지도 지금 화면에 안 나온다). 그 값은 다른 작업의
##   결정일 수 있어 건드리지 않고, 새 잉크 이펙트·점프대 물감 가시만 씬에 붙여 보이게 한다.
var _파티클_부모: Node = null


func _씬() -> Node:
	var t := get_tree()
	return t.current_scene if t and t.current_scene else self


func 점프(색: int) -> void:
	# 발밑 양옆으로만 짧게 밀어내 점프 방향을 가리지 않고 이륙 순간만 보여준다.
	var 위치 := global_position + Vector2(0, -2)
	# [2026-10-08] 잉크 이펙트가 주인공이 되므로 먼지는 쪽당 5 → 2 개로 줄였다(기획 "기존 먼지 축소").
	var 먼지수 := 2 if 잉크_이펙트_사용 else 점프_쪽당_개수
	_먼지_한쪽(위치, Vector2(-1.0, -0.18), 색, 먼지수, 34.0, 62.0, 0.28, 0.24)
	_먼지_한쪽(위치, Vector2(1.0, -0.18), 색, 먼지수, 34.0, 62.0, 0.28, 0.24)
	if 잉크_이펙트_사용:
		# 발 자리(ActionFX 원점 = 발바닥)에 남는다 — 몸을 따라가지 않고 바닥에서 마른다.
		_마지막_점프 = 프레임효과.만들기(_씬(), "약", global_position + Vector2(0, -1), 색, 약_시간, 잉크_배율)


## player.gd — 점프 버튼을 0.12초 넘게 누르고 있으면(= 끝까지 누르는 강한 점프) 한 번 부른다.
func 점프_강하게() -> void:
	if is_instance_valid(_마지막_점프):
		_마지막_점프.강화("강", 강_시간)
	_마지막_점프 = null


## 도약대.gd — 튕겨 올리는 순간. `판위치` = 스프링 판 윗면(발 자리) 월드 좌표. `몸` = 솟구치는 플레이어.
func 점프대(색: int, 판위치: Vector2, 몸: Node2D = null) -> void:
	_마지막_점프 = null      # 점프대로 솟구치는 중엔 약→강 키우기가 없다(점프대가 가장 강하다)
	if not 잉크_이펙트_사용:
		_먼지_한쪽(판위치, Vector2(-1.0, -0.1), 색, 6, 60.0, 120.0, 0.32, 0.30)
		_먼지_한쪽(판위치, Vector2(1.0, -0.1), 색, 6, 60.0, 120.0, 0.32, 0.30)
		return
	# 판 위로 옆으로 펼쳐지는 파문 — 파문 줄(가장 넓은 줄)이 판 윗면에 오도록 기준점을 맞춰 놓았다.
	프레임효과.만들기(_씬(), "점프대", 판위치, 색, 점프대_시간, 잉크_배율)
	# 아래로 튀는 물감 가시 5~7 — 파문 그림의 방울과 겹쳐 '세게 밟아 사방으로 튄다' 를 만든다
	_파티클_부모 = _씬()
	_물감_뿌리기(판위치 + Vector2(0, -4), Vector2(0, 1), 색, 6, 70.0, 90.0, 210.0, 0.24, 0.32, 520.0)
	_파티클_부모 = null
	# 솟구치는 처음 0.3초 몸 뒤(아래)로 긴 속도 줄 — 둥근 머리가 발 자리, 줄은 아래로. 몸을 가리지 않는다.
	if 몸:
		var 줄 := 프레임효과.만들기(_씬(), "솟구침", 몸.global_position + Vector2(0, 6), 색, 솟구침_시간, 잉크_배율)
		줄.따라가기(몸, Vector2(0, 6))
		줄.z_index = 29
		# 검정 잉크 속도 줄은 덩어리로 뭉쳐 보였다(촬영 2026-10-08) → 반투명으로 '지나간 자국' 만 남긴다
		줄.self_modulate = Color(1, 1, 1, 0.55 if 색 == ColorDefs.BLACK else 0.8)


func 착지(색: int, 낙하속도: float) -> void:
	if 낙하속도 < 190.0:
		return
	# 낙하 충격은 위로 폭발시키지 않고 지면을 따라 좌우로 낮게 흘려 무게감을 만든다.
	var 세기 := clampf((낙하속도 - 190.0) / 710.0, 0.0, 1.0)
	var 개수 := roundi(lerpf(3.0, 6.0, 세기))
	var 최소속도 := lerpf(42.0, 72.0, 세기)
	var 최대속도 := lerpf(78.0, 132.0, 세기)
	var 위치 := global_position + Vector2(0, -1)
	_먼지_한쪽(위치, Vector2(-1.0, -0.12), 색, 개수, 최소속도, 최대속도, 0.30, 0.30)
	_먼지_한쪽(위치, Vector2(1.0, -0.12), 색, 개수, 최소속도, 최대속도, 0.30, 0.30)


const 스플래시_S := preload("res://scripts/스마트월드/물감_스플래시.gd")
const 명중효과_씬 := preload("res://scenes/effects/PaintImpactEffect.tscn")

## 명중 연출을 무엇으로 낼지. 스테이지가 아니라 **여기 한 곳**에서만 정해진다.
enum 명중연출 {
	원화_물이펙트,     ## [2026-09-05 기본] 도형님이 준 water_05~08 원본 애니메이션
	손그림_스플래시,   ## [2026-09-03] 코드로 그리던 물줄기 — 비교·되돌리기용으로 남겨 뒀다
}
@export var 명중_연출: 명중연출 = 명중연출.원화_물이펙트
## [2026-09-05 임시] 명중마다 `[PAINT IMPACT] …` 한 줄을 찍는다.
## 모든 스테이지에서 같은 이펙트가 나오는지 확인하려고 켜 뒀다. 확인이 끝나면 꺼도 된다.
@export var 명중_디버그로그 := true


## 발사체가 지형에 맞은 그 자리에서 부른다. **모든 발사체의 공통 출구**다.
##   페인트총알(집·2-1) / ProtoBullet(1-1·2-2·2-3) / bullet(옛 타일맵 씬) 셋 다 여기로 온다.
##   → 스테이지 코드에 이펙트를 심을 필요가 없다. 스테이지가 늘어도 이 줄 하나면 된다.
## `법선` 은 지형 표면의 바깥 방향. 레이캐스트로 쏘는 총알만 줄 수 있어서 기본값을 둔다.
## `발사체` 는 디버그 로그에 찍을 이름.
func 명중(지점: Vector2, 속도: Vector2, 색: int,
		법선: Vector2 = Vector2.ZERO, 발사체: String = "") -> void:
	if 속도.is_zero_approx():
		return
	# 지형 법선을 받았으면 그게 제일 정확하다. 못 받으면 진행 반대 방향으로 대신한다
	# (벽·바닥 모두 한 방향으로 튀어 자연스럽다).
	var 바깥방향 := 법선.normalized() if not 법선.is_zero_approx() else -속도.normalized()

	if 명중_연출 == 명중연출.원화_물이펙트:
		var 효과: Node2D = 명중효과_씬.instantiate()
		효과.시작(지점 + 바깥방향 * 2.0, 바깥방향, 색, 크기_배율, 발사체, 명중_디버그로그)
		get_tree().current_scene.add_child(효과)
	else:
		# ★[2026-09-03 도형님] "블럭이 날라가는 느낌" → 매번 다른 물줄기 스플래시로 바꿨다.
		#   예전엔 여기서 큰 타원 얼룩(_물감_얼룩) 하나를 그려서 "네모가 찍힌" 인상이었다.
		var 스플래시: Node2D = 스플래시_S.new()
		스플래시.시작(지점 + 바깥방향 * 2.0, 바깥방향, 색, 크기_배율)  # 값 저장 (아직 트리 밖)
		get_tree().current_scene.add_child(스플래시)                # _ready 가 _바깥 반영해 생성

	# 잔점 파티클은 남긴다 — 물줄기 사이를 채우는 미세한 물보라라 형태 연출을 해치지 않는다.
	_물감_뿌리기(지점 + 바깥방향 * 2.0, 바깥방향, 색, 명중_잔점,
		112.0, 48.0, 135.0, 0.20, 0.22, 560.0)

func _먼지_한쪽(위치: Vector2, 방향: Vector2, 색: int, 개수: int,
		최소속도: float, 최대속도: float, 크기: float, 수명: float) -> void:
	var p := _새_파티클(위치, 방향, _먼지_텍스처_가져오기(), _먼지색(색), 개수, 수명)
	p.spread = 24.0
	p.initial_velocity_min = 최소속도
	p.initial_velocity_max = 최대속도
	p.gravity = Vector2(0, 170.0)
	p.damping_min = 80.0
	p.damping_max = 135.0
	p.scale_amount_min = 크기 * 0.72 * 크기_배율
	p.scale_amount_max = 크기 * 1.18 * 크기_배율
	p.scale_amount_curve = _크기_곡선(0.55, 1.0, 1.20)
	p.color_ramp = _사라짐_그라데이션(_먼지색(색), 0.45)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(5.0, 1.0)
	_방출(p)


func _물감_뿌리기(위치: Vector2, 방향: Vector2, 색: int, 개수: int,
		퍼짐: float, 최소속도: float, 최대속도: float, 크기: float,
		수명: float, 중력: float) -> void:
	var p := _새_파티클(위치, 방향, _물감_텍스처_가져오기(), _물감색(색), 개수, 수명)
	p.spread = 퍼짐
	p.initial_velocity_min = 최소속도
	p.initial_velocity_max = 최대속도
	p.gravity = Vector2(0, 중력)
	p.damping_min = 22.0
	p.damping_max = 58.0
	p.scale_amount_min = 크기 * 0.72 * 크기_배율
	p.scale_amount_max = 크기 * 1.28 * 크기_배율
	p.scale_amount_curve = _크기_곡선(0.42, 1.0, 0.34)
	p.color_ramp = _사라짐_그라데이션(_물감색(색), 0.72)
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	_방출(p)


func _새_파티클(위치: Vector2, 방향: Vector2, 텍스처: Texture2D,
		색상: Color, 개수: int, 수명: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.global_position = 위치
	p.z_as_relative = false
	p.z_index = 30
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.65
	p.lifetime_randomness = 0.28
	p.amount = 개수
	p.lifetime = 수명
	p.direction = 방향
	p.texture = 텍스처
	p.color = 색상
	p.finished.connect(p.queue_free)
	(_파티클_부모 if _파티클_부모 else self).add_child(p)
	return p


func _방출(p: CPUParticles2D) -> void:
	p.emitting = true


func _크기_곡선(시작: float, 중간: float, 끝: float) -> Curve:
	var 곡선 := Curve.new()
	곡선.add_point(Vector2(0.0, 시작))
	곡선.add_point(Vector2(0.22, 중간))
	곡선.add_point(Vector2(1.0, 끝))
	return 곡선


func _사라짐_그라데이션(색상: Color, 유지끝: float) -> Gradient:
	var 그라데이션 := Gradient.new()
	그라데이션.set_color(0, 색상)
	그라데이션.set_color(1, Color(색상.r, 색상.g, 색상.b, 0.0))
	그라데이션.add_point(유지끝, Color(색상.r, 색상.g, 색상.b, 색상.a * 0.82))
	return 그라데이션


func _먼지색(색: int) -> Color:
	# 점프 피드백이 현재 색과 즉시 연결되도록 회색 보정 없이 플레이어의 흰색·검정을 그대로 따른다.
	return Color(0.96, 0.96, 0.94, 0.82) if 색 == ColorDefs.WHITE else Color(0.035, 0.035, 0.045, 0.90)


func _물감색(색: int) -> Color:
	return Color(0.98, 0.98, 0.96, 1.0) if 색 == ColorDefs.WHITE else Color(0.055, 0.055, 0.065, 1.0)


func _먼지_텍스처_가져오기() -> Texture2D:
	if _먼지_텍스처:
		return _먼지_텍스처
	var 이미지 := Image.create_empty(10, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 10:
			var 좌표 := Vector2((float(x) - 4.5) / 4.5, (float(y) - 2.5) / 2.4)
			var 알파 := pow(clampf(1.0 - 좌표.length(), 0.0, 1.0), 0.72)
			이미지.set_pixel(x, y, Color(1.0, 1.0, 1.0, 알파))
	_먼지_텍스처 = ImageTexture.create_from_image(이미지)
	return _먼지_텍스처


func _물감_텍스처_가져오기() -> Texture2D:
	if _물감_텍스처:
		return _물감_텍스처
	var 이미지 := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var 좌표 := Vector2((float(x) - 3.5) / 3.25, (float(y) - 3.5) / 3.25)
			var 가장자리흔들림 := sin(float(x * 13 + y * 19)) * 0.10
			var 알파 := clampf(1.02 - 좌표.length() + 가장자리흔들림, 0.0, 1.0)
			이미지.set_pixel(x, y, Color(1.0, 1.0, 1.0, 알파))
	_물감_텍스처 = ImageTexture.create_from_image(이미지)
	return _물감_텍스처


