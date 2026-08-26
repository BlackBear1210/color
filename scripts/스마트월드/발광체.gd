@tool
extends Node2D
## ============================================================================
## [2026-08-01 신규] 발광체 — 가로등 / 등불 / 반딧불 구슬 / 물 반사광
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가 (도형님 요청: "레인월드 같은 퀄리티")
##   레인월드가 2D 인데도 깊이가 있어 보이는 이유의 절반은 **빛**이다.
##   어두운 화면 안에 광원이 몇 개 박혀 있으면, 같은 실루엣도 "공간"으로 읽힌다.
##   여기서는 Godot 2D 라이트를 쓰되, 텍스처를 코드로 만들어(방사형 그라데이션)
##   에셋 의존 없이 어디서든 켤 수 있게 했다.
##
## ▣ 쓰려면 CanvasModulate 가 필요하다
##   화면이 이미 밝으면 빛이 안 보인다. 월드.gd 가 CanvasModulate 로 전체를
##   어둡게 눌러주고, 그 위에 이 발광체들이 구멍을 뚫는 구조다.
##
## ▣ 종류
##   가로등 : 기둥 + 갓 + 아래로 퍼지는 빛. 어두운 길에 놓는다.
##   구슬   : 떠다니며 깜빡이는 작은 빛. 자연 바이옴의 반딧불.
##   반사   : 물 위에 눕는 넓고 약한 빛. 수면 반사를 흉내낸다.
## ============================================================================
class_name 발광체

enum 종류_ { 가로등, 구슬, 반사 }

@export var 종류: 종류_ = 종류_.가로등:
	set(v): 종류 = v; _다시_만들기()

## 빛 색. 흑백 게임이라 채도는 아주 낮게 — 따뜻함/차가움 정도만 준다.
@export var 빛색: Color = Color(1.0, 0.94, 0.82):
	set(v): 빛색 = v; _다시_만들기()

## 빛의 반경(px).
@export var 반경: float = 260.0:
	set(v): 반경 = maxf(v, 32.0); _다시_만들기()

@export var 밝기: float = 1.15:
	set(v): 밝기 = maxf(v, 0.0); _다시_만들기()

## 깜빡임 세기(0=없음). 가로등의 낡은 느낌, 반딧불의 명멸.
@export_range(0.0, 1.0) var 깜빡임: float = 0.18

## ★[2026-08-02 추가] 빛의 **크기**가 노이즈로 흔들리는 폭(0=고정).
## 0.25 면 반경이 75%~125% 사이에서 부드럽게 오간다.
## 세기(깜빡임)만 흔들면 형광등처럼 딱딱한데, 크기까지 같이 흔들리면
## 불꽃·반딧불처럼 "살아 있는 빛"으로 읽힌다.
@export_range(0.0, 0.8) var 크기_흔들림: float = 0.22

## 노이즈가 흐르는 속도. 낮을수록 느긋하게 커졌다 작아진다.
@export_range(0.05, 4.0) var 흔들림_속도: float = 0.55

## 구슬이 떠다니는 반경(px). 0 이면 고정.
@export var 부유: float = 0.0

## ★[2026-08-26 추가] 알갱이(구슬 그림)를 그릴지. 끄면 **빛만** 남는다.
##
## 왜 필요한가: `구슬` 은 원래 반딧불 하나를 그리라고 만든 종류인데,
## 실내에서 "벽등·천장등이 만드는 빛 웅덩이"를 얻으려고 같은 종류를 쓰면
## 허공에 흰 알갱이가 같이 떠서 **반딧불이와 등이 구분되지 않는다**
## (집 복도에서 실제로 그랬다 — 둘 다 똑같은 흰 점으로 보였다).
## 등은 이걸 끄고 빛만 쓰고, 반딧불이는 켜 둔다. 기본값 true = 예전과 똑같다.
@export var 알갱이_보이기: bool = true:
	set(v): 알갱이_보이기 = v; queue_redraw()

var _빛: PointLight2D
var _시간: float = 0.0
var _시작위치: Vector2 = Vector2.ZERO

## ── 노이즈 ───────────────────────────────────────────────────────────────
## ⚠ Godot 3 의 `OpenSimplexNoise` 는 Godot 4 에서 없어졌다.
##    대체재가 `FastNoiseLite` 이고, `TYPE_SIMPLEX_SMOOTH` 가 예전 OpenSimplex 와
##    거의 같은 결과를 낸다. (문서: Godot 4 Migrating from 3.x — Noise classes)
## 왜 sin() 대신 노이즈인가: sin 은 주기가 눈에 보여서 여러 개를 나란히 두면
##    "다 같이 숨쉬는" 티가 난다. 노이즈는 각 광원이 서로 다른 리듬으로 흔들린다.
var _노이즈: FastNoiseLite = null
var _노이즈_시작: float = 0.0


func _ready() -> void:
	_시작위치 = position
	_다시_만들기()
	if Engine.is_editor_hint():
		return
	# 광원마다 노이즈의 다른 구간을 읽게 해서 전부 따로 논다.
	# 이름을 시드로 쓰면 실행할 때마다 같은 리듬이 재현된다(디버깅에 유리).
	_노이즈 = FastNoiseLite.new()
	_노이즈.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_노이즈.seed = hash(name)
	_노이즈.frequency = 0.9
	_노이즈_시작 = float(hash(name) % 1000)
	set_process(깜빡임 > 0.0 or 부유 > 0.0 or 크기_흔들림 > 0.0)


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	_빛 = get_node_or_null("빛") as PointLight2D
	if _빛 == null:
		_빛 = PointLight2D.new()
		_빛.name = "빛"
		add_child(_빛)
	_빛.texture = _빛_텍스처()
	_빛.color = 빛색
	_빛.energy = 밝기
	# 곱하기 대신 더하기 블렌드 = 어두운 배경 위에 "빛이 얹히는" 느낌
	_빛.blend_mode = Light2D.BLEND_MODE_ADD
	_빛.shadow_enabled = false
	# 텍스처가 256px 기준이므로 원하는 반경에 맞춰 스케일을 잡는다
	_빛.texture_scale = 반경 / 128.0
	match 종류:
		종류_.반사:
			_빛.scale = Vector2(1.0, 0.32)     # 수면 반사는 가로로 납작하다
			_빛.position = Vector2.ZERO
		종류_.가로등:
			_빛.scale = Vector2.ONE
			_빛.position = Vector2(0, -6)
		_:
			_빛.scale = Vector2.ONE
			_빛.position = Vector2.ZERO
	queue_redraw()


## 코드로 만드는 방사형 그라데이션 — 외부 이미지 없이 광원 텍스처를 얻는다.
## ★[성능] 256×256 픽셀 루프라 인스턴스마다 만들면 스테이지 로딩이 눈에 띄게 느려진다.
##   모양이 전부 같으므로 **한 번 만들어 전 인스턴스가 공유**한다 (색·크기는 노드 속성으로 조절).
static var _공용_텍스처: Texture2D = null

func _빛_텍스처() -> Texture2D:
	if _공용_텍스처 != null:
		return _공용_텍스처
	var 크기 := 256
	var img := Image.create(크기, 크기, false, Image.FORMAT_RGBA8)
	var 중심 := Vector2(크기, 크기) * 0.5
	for y in 크기:
		for x in 크기:
			var d := Vector2(x, y).distance_to(중심) / (float(크기) * 0.5)
			# 제곱으로 떨어뜨리면 중심이 또렷하고 바깥이 부드럽다
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_공용_텍스처 = ImageTexture.create_from_image(img)
	return _공용_텍스처


func _process(delta: float) -> void:
	_시간 += delta

	# 노이즈 값 두 줄기를 뽑는다. 같은 시간이라도 y 를 달리하면 서로 다른 흐름이 된다.
	# → 세기와 크기가 따로 움직여야 "숨쉬는 빛"처럼 보인다. 같이 움직이면 그냥 깜빡임.
	var t := _노이즈_시작 + _시간 * 흔들림_속도
	var n_세기 := _노이즈.get_noise_2d(t, 0.0) if _노이즈 else 0.0        # -1 ~ 1
	var n_크기 := _노이즈.get_noise_2d(t, 37.0) if _노이즈 else 0.0

	if _빛:
		if 깜빡임 > 0.0:
			# 노이즈(느린 흔들림) + 빠른 사인(전기적 떨림)을 섞는다
			var 떨림 := sin(_시간 * 11.7) * 0.25
			_빛.energy = maxf(밝기 * (1.0 + (n_세기 + 떨림) * 깜빡임), 0.0)
		if 크기_흔들림 > 0.0:
			# 반경 자체를 흔든다 — texture_scale 이 곧 빛의 크기다
			var 배수 := 1.0 + n_크기 * 크기_흔들림
			_빛.texture_scale = maxf(반경 / 128.0 * 배수, 0.01)

	if 부유 > 0.0:
		# 떠다니는 것도 노이즈로 — 사인 궤도는 "8자로 도는" 티가 나서 부자연스럽다
		var nx := _노이즈.get_noise_2d(t * 0.6, 91.0) if _노이즈 else 0.0
		var ny := _노이즈.get_noise_2d(t * 0.6, 173.0) if _노이즈 else 0.0
		position = _시작위치 + Vector2(nx, ny * 0.7) * 부유
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	match 종류:
		종류_.가로등:
			var 기둥 := Color(0.16, 0.16, 0.18)
			draw_line(Vector2(0, 0), Vector2(0, 180), 기둥, 7.0)      # 기둥
			draw_line(Vector2(0, 0), Vector2(34, 0), 기둥, 6.0)        # 팔
			# 갓
			draw_colored_polygon(PackedVector2Array([
				Vector2(20, -2), Vector2(48, -2), Vector2(42, 14), Vector2(26, 14)
			]), 기둥)
			draw_circle(Vector2(34, 12), 6.0, 빛색)
			if _빛:
				_빛.position = Vector2(34, 12)
		종류_.구슬:
			if not 알갱이_보이기:
				return                                         # 빛만 남긴다(벽등·천장등)
			draw_circle(Vector2.ZERO, 5.0, 빛색)
			draw_circle(Vector2.ZERO, 9.0, Color(빛색.r, 빛색.g, 빛색.b, 0.25))
		종류_.반사:
			pass                                                   # 그림 없음 — 빛만
