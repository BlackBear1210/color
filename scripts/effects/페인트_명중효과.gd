extends Node2D
## ============================================================================
## [2026-09-05 신규] 페인트 명중 이펙트 — 원본 물 이펙트(water_05~08) 재생
## ----------------------------------------------------------------------------
## ▣ 도형님 지시 (이번 작업의 핵심)
##   "플레이어가 **어떤 스테이지에서** Paint Projectile을 쏘더라도 지형에 충돌하면
##    동일한 Water Splash Animation이 발생해야 한다. 스테이지마다 복붙하지 마라."
##
##   → 그래서 이 씬은 **아무 스테이지도 모른다.** 스테이지 코드에 한 줄도 안 들어간다.
##     들어가는 자리는 딱 하나, 모든 발사체가 이미 공통으로 부르고 있던
##     `Player > ActionFX` (`player_action_fx.gd` 의 `명중()`) 이다.
##
##     페인트총알(집·2-1) ┐
##     ProtoBullet(1-1·2-2·2-3) ├→ Player/ActionFX.명중() → 이 씬 → 자동 삭제
##     bullet(옛 타일맵 씬)     ┘
##
##     스테이지가 10개 20개로 늘어도 발사체가 저 셋 중 하나면 그냥 나온다.
##
## ▣ 그림은 어디서 오나
##   `assets/vfx/water_impact/water_05~08.png` (도형님이 준 원본 시트, 픽셀 무수정)
##   → `tools/생성_물감명중_프레임.gd` 가 SpriteFrames(.tres)와 기준점(.json)으로 굽는다.
##   프레임 수·칸 크기·기준점은 **전부 그 json 에서 읽는다.** 여기 박아 두지 않는다.
##   (문서에 적혀 있던 "176×176 × 16프레임"은 실제 파일과 전혀 달랐다 — 숫자를 믿지 않는다)
##
## ▣ 원본이 검정 배경 위에 그려져 있다
##   알파가 전 픽셀 1.0 이라 그냥 붙이면 **검은 네모**가 찍힌다.
##   → `shaders/물감_명중.gdshader` 가 밝기를 알파로 바꿔 뽑아낸다. 원본은 안 건드린다.
##
## ▣ 흑백 게임이라 두 겹으로 그린다
##   본체 = 페인트 색(검정/흰색) · 받침 = 반대색을 살짝 크게 깔아 둔다.
##   안 그러면 검정 페인트가 어두운 배경에서 아예 안 보인다.
##   (`물감_스플래시.gd` 가 테두리를 깔던 것과 같은 수법)
## ============================================================================
class_name 페인트명중효과

const 기준_경로 := "res://assets/vfx/water_impact/물감_명중_기준점.json"

## 기준점 json 은 명중할 때마다 읽을 이유가 없다. 처음 한 번만 읽어 들고 있는다.
static var _기준표: Dictionary = {}

## 원본 그림이 이 배율로 그려진다. 예전 손그림 스플래시(반경 26~78px)와 비슷한 크기다.
@export var 기본_크기 := 0.85
## 받침(반대색)이 본체보다 얼마나 큰가. 1.0 이면 안 보인다.
@export var 받침_배율 := 1.10
## 받침의 진하기. 너무 진하면 흑백이 뒤집혀 보인다.
@export var 받침_알파 := 0.42
## 지형 법선에서 좌우로 흔드는 폭(라디안). 완전 랜덤으로 돌리면 지형과 어긋난다.
@export var 각도_흔들림 := 0.15
## 같은 애니메이션이라도 매번 조금씩 다른 크기로 튀게 한다.
@export var 크기_흔들림 := Vector2(0.88, 1.15)

var _본체: AnimatedSprite2D = null
var _받침: AnimatedSprite2D = null

# 시작()이 준 값. add_child 순서와 무관하게 _ready 에서 반영한다.
var _시작점 := Vector2.ZERO
var _바깥 := Vector2.UP
var _색 := ColorDefs.BLACK
var _크기배율 := 1.0
var _발사체 := ""
var _로그 := false
var _적용됨 := false


## 발사체가 실제 명중 지점에서 부른다.
## `바깥방향` 은 지형 표면의 바깥쪽(법선). 없으면 진행 반대 방향을 넣어도 된다.
## ⚠ 값만 저장한다. 실제 반영은 _ready() — `물감_스플래시.gd` 와 같은 이유다.
##   (new/instantiate → add_child → 시작 순서로 불릴 수도 있어서)
func 시작(지점: Vector2, 바깥방향: Vector2, 색: int, 크기배율: float = 1.0,
		발사체: String = "", 로그: bool = false) -> void:
	_시작점 = 지점
	_바깥 = 바깥방향.normalized() if not 바깥방향.is_zero_approx() else Vector2.UP
	_색 = 색
	_크기배율 = 크기배율
	_발사체 = 발사체
	_로그 = 로그
	if is_inside_tree() and not _적용됨:
		_적용()


func _ready() -> void:
	# 총알이 어느 노드 밑에 붙든 명중 지점은 월드 좌표 그대로여야 한다.
	top_level = true
	z_as_relative = false
	z_index = 31                    # 총알(30)보다 살짝 위
	_본체 = $본체
	_받침 = $받침
	if not _적용됨:
		_적용()


func _적용() -> void:
	_적용됨 = true
	global_position = _시작점

	var 프레임집 := _본체.sprite_frames
	if 프레임집 == null or 프레임집.get_animation_names().is_empty():
		push_warning("페인트명중효과: SpriteFrames 가 비어 있다. tools/생성_물감명중_프레임.gd 를 돌려라.")
		queue_free()
		return

	# ── 어떤 물 이펙트로 튈지 매번 새로 뽑는다 ──
	# 목록을 코드에 적지 않고 리소스가 들고 있는 이름을 그대로 쓴다.
	# 나중에 water_09 를 시트 폴더에 넣고 도구만 돌리면 자동으로 후보에 들어온다.
	var 이름들 := 프레임집.get_animation_names()
	var 고른것: String = 이름들[randi() % 이름들.size()]
	var 기준: Dictionary = _기준(고른것)

	# ── 명중 지점이 그림의 어느 점에 놓여야 하나 ──
	# AnimatedSprite2D 는 그림의 **한가운데**를 자기 원점에 놓는다.
	# 우리가 원점에 놓고 싶은 것은 "물이 터져 나오는 점"(기준점)이므로 그만큼 민다.
	var 칸 := Vector2(float(기준.get("칸폭", 0)), float(기준.get("높이", 0)))
	var 기준점: Vector2 = _벡터(기준.get("기준점", [칸.x * 0.5, 칸.y * 0.5]))
	var 밀기 := 칸 * 0.5 - 기준점

	# ── 지형 법선에 맞춰 돌린다 ──
	# 원화가 "바깥"으로 삼은 방향이 실제 지형 법선을 향하게 회전시킨다.
	# 완전 무작위로 돌리면 벽에서 물이 벽 속으로 튀는 그림이 나온다.
	var 그림_바깥: Vector2 = _벡터(기준.get("바깥방향", [0.0, -1.0]))
	rotation = _바깥.angle() - 그림_바깥.angle() + randf_range(-각도_흔들림, 각도_흔들림)
	scale = Vector2.ONE * 기본_크기 * _크기배율 * randf_range(크기_흔들림.x, 크기_흔들림.y)

	var 본색 := Color(0.97, 0.97, 0.95) if _색 == ColorDefs.WHITE else Color(0.055, 0.055, 0.065)
	var 받침색 := Color(0.05, 0.05, 0.06) if _색 == ColorDefs.WHITE else Color(0.93, 0.95, 0.99)
	_꾸미기(_본체, 고른것, 밀기, 본색, 1.0, 1.0)
	_꾸미기(_받침, 고른것, 밀기, 받침색, 받침_알파, 받침_배율)

	# 마지막 프레임까지 재생하면 스스로 사라진다.
	_본체.animation_finished.connect(queue_free)
	# 안전장치 — 어떤 이유로 animation_finished 가 안 오더라도 반드시 치운다.
	var 수명 := float(프레임집.get_frame_count(고른것)) / maxf(프레임집.get_animation_speed(고른것), 1.0)
	get_tree().create_timer(수명 + 1.0).timeout.connect(func(): if is_instance_valid(self): queue_free())

	if _로그:
		var 스테이지: String = get_tree().current_scene.name if get_tree().current_scene else "?"
		print("[PAINT IMPACT] stage=%s projectile=%s position=(%.0f,%.0f) animation=%s frame_count=%d" % [
			스테이지, (_발사체 if _발사체 != "" else "?"), _시작점.x, _시작점.y,
			고른것, 프레임집.get_frame_count(고른것)])


func _꾸미기(스프라이트: AnimatedSprite2D, 애니: String, 밀기: Vector2,
		색: Color, 알파: float, 배율: float) -> void:
	스프라이트.offset = 밀기
	스프라이트.scale = Vector2.ONE * 배율
	# 받침은 본체보다 크게 그리므로, 커진 만큼 기준점이 밀려나지 않게 되돌린다.
	스프라이트.position = -밀기 * (배율 - 1.0)
	var 재질 := 스프라이트.material as ShaderMaterial
	if 재질:
		# 씬에 박힌 재질을 그대로 쓰면 두 노드가 색을 공유해 버린다. 인스턴스마다 복제한다.
		재질 = 재질.duplicate() as ShaderMaterial
		스프라이트.material = 재질
		재질.set_shader_parameter("paint_tint", 색)
		재질.set_shader_parameter("paint_alpha", 알파)
	스프라이트.play(애니)


## 기준점 json 을 한 번만 읽어 캐시한다.
func _기준(애니: String) -> Dictionary:
	if _기준표.is_empty():
		var f := FileAccess.open(기준_경로, FileAccess.READ)
		if f:
			var 읽음 = JSON.parse_string(f.get_as_text())
			f.close()
			if 읽음 is Dictionary:
				_기준표 = 읽음
	var d = _기준표.get(애니, null)
	var 값: Dictionary = d if d is Dictionary else {}
	return 값


func _벡터(값) -> Vector2:
	if 값 is Array and 값.size() >= 2:
		return Vector2(float(값[0]), float(값[1]))
	return Vector2.ZERO
