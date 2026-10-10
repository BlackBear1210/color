@tool
extends Area2D
## ============================================================================
## [2026-10-09 Claude · 2-7 신규] 순찰 몬스터 — 바닥 위를 좌우로 오가며, **몸 색이 다르면 닿는 순간 죽인다.**
## ----------------------------------------------------------------------------
## 왜 만들었나
##   2-7 도면 위쪽 바위에 "몬스터 · 좌우로 움직임(흰색)" 이 그려져 있는데 게임에 몹 로직이 없었다.
##   그림은 Codex 가 10-08 에 만든 `assets/characters/paint_beast_b/` 걷기 시트(8 프레임)를 그대로 쓴다.
##
## 규칙 — 새 규칙을 만들지 않고 **물·지형과 같은 색 규칙**에 태운다
##   · 레이어 32(유체와 같은 층) + `반대색인가()` → 월드.gd `_조각이_반대색에_닿았나` 가 몸 조각마다 묻는다.
##     그래서 흰 몬스터는 검은 몸을 죽이고 흰 몸은 통과시킨다(색이 같으면 안전 — 게임의 핵심 규칙 그대로).
##   · `hazard`(색 무관 즉사)에는 넣지 않는다 — 넣으면 "칠하면 안전" 같은 색 규칙이 흐려진다(월드.gd §0 주석).
##   · 플레이어 페인트 한 발로 몸색을 바꾼다. 접촉 판정·사격색도 같은 `색`을 사용하며 회수/리스폰은 원래 색으로 돌아간다.
##
## 성능: 그림은 AnimatedSprite2D 가 그린다(_draw 없음). 매 물리 틱 position 만 바꾼다 — 지형이 아니라 마감 재계산이 없다.
##   ★로드: `monster_frames.tres` 를 통째로 preload 하면 시트 6 장(걷기·차오르기·발사 × 검·흰)을 다 읽어
##     2-7 로드가 ≈190ms 늘었다(측정_하수도_프레임 로드 560 → 740). 순찰은 걷기만 쓰므로 **그 색 걷기 시트 한 장**만
##     읽어 SpriteFrames 를 코드로 만든다(같은 색 몬스터끼리는 정적 캐시로 나눠 쓴다).
## ============================================================================
class_name 순찰몬스터

## 걷기 시트 — 4 열 × 2 행 · 칸 512×512 · 10fps 반복(README)
const 걷기_시트 := ["res://assets/characters/paint_beast_b/black_walk.png", "res://assets/characters/paint_beast_b/white_walk.png"]
## 원본 프레임 512×512 · 발 기준선 y=452(README) → 가운데(256)에서 발까지 196.
const 발_아래 := 196.0
static var _프레임_캐시: Dictionary = {}

## 0 = 검정 · 1 = 흰색 (ColorDefs 와 같다)
@export_enum("검정", "흰색") var 색: int = 1:
	set(v):
		색 = v
		_그림_맞추기()
## 순찰 왼끝·오른끝 — **부모 기준 x**(빌더가 도면 선 끝을 그대로 넣는다).
@export var 왼끝: float = 0.0
@export var 오른끝: float = 320.0
@export_range(20.0, 600.0) var 속도: float = 120.0
## 보이는 키(px). 판정 사각형도 이 키를 따른다.
@export_range(40.0, 200.0) var 키: float = 104.0:
	set(v):
		키 = v
		_그림_맞추기()
@export_range(20.0, 160.0) var 판정_폭: float = 64.0:
	set(v):
		판정_폭 = v
		_그림_맞추기()

var _방향 := 1.0
var _그림: AnimatedSprite2D
var _걸음_남음 := 0.2
# 회수와 리스폰이 현재 칠한 색이 아니라 씬에서 지정한 원래 몸색을 복원해야 한다.
var _원래색: int = ColorDefs.WHITE


func _ready() -> void:
	_그림_맞추기()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_원래색 = 색
	add_to_group("몬스터")
	add_to_group("칠할수있음")
	collision_layer = 32
	collision_mask = 0
	monitorable = true
	monitoring = false
	set_physics_process(true)


## 그림·판정을 키·색에 맞춘다. 자식은 매번 이름으로 찾아 재사용한다(씬에 굽지 않도록 owner 를 주지 않는다).
func _그림_맞추기() -> void:
	if not is_inside_tree():
		return
	_그림 = get_node_or_null("그림") as AnimatedSprite2D
	if _그림 == null:
		_그림 = AnimatedSprite2D.new()
		_그림.name = "그림"
		add_child(_그림)
	var 프레임 := _걷기_프레임(색)
	if _그림.sprite_frames != 프레임:
		_그림.sprite_frames = 프레임
	# 발 기준선이 원점(바닥)에 오게 — 프레임 안 몸 키 = 351px(알파 bbox 104~455 실측) → 키/351 배.
	var s := 키 / 351.0
	_그림.scale = Vector2(s, s)
	_그림.position = Vector2(0.0, -발_아래 * s)
	if not Engine.is_editor_hint():
		_그림.play(&"walk")
	var c := get_node_or_null("판정") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "판정"
		add_child(c)
	var r := RectangleShape2D.new()
	r.size = Vector2(판정_폭, 키 * 0.9)
	c.shape = r
	c.position = Vector2(0.0, -키 * 0.45)


## 그 색 걷기 시트 한 장으로 "walk" 애니메이션 하나짜리 SpriteFrames 를 만든다(색마다 한 번 · 정적 캐시).
static func _걷기_프레임(몸색: int) -> SpriteFrames:
	var 키값 := clampi(몸색, 0, 1)
	if _프레임_캐시.has(키값):
		return _프레임_캐시[키값]
	var 시트 := load(걷기_시트[키값]) as Texture2D
	var sf := SpriteFrames.new()
	sf.set_animation_speed(&"default", 10.0)
	sf.rename_animation(&"default", &"walk")
	sf.set_animation_loop(&"walk", true)
	for i in 8:
		var a := AtlasTexture.new()
		a.atlas = 시트
		a.region = Rect2(float(i % 4) * 512.0, float(i / 4) * 512.0, 512.0, 512.0)
		sf.add_frame(&"walk", a)
	_프레임_캐시[키값] = sf
	return sf


func _physics_process(delta: float) -> void:
	var 이전_x := position.x
	var x := position.x + _방향 * 속도 * delta
	if x >= 오른끝:
		x = 오른끝
		_방향 = -1.0
	elif x <= 왼끝:
		x = 왼끝
		_방향 = 1.0
	position.x = x
	# 걷기 시트는 8프레임/10fps이므로 반 주기(0.4초)마다 한 발씩 낸다.
	# 이동 없는 순찰 범위에서는 애니메이션만 돌아도 발소리를 내지 않는다.
	if absf(position.x - 이전_x) > 0.001:
		_걸음_남음 -= delta
		if _걸음_남음 <= 0.0:
			_걸음_남음 = 0.4
			preload("res://scripts/페인트_효과음.gd").재생(self, "몬스터_걷기",
				global_position, -16.0, randf_range(0.96, 1.04))
	else:
		_걸음_남음 = 0.2
	if _그림:
		_그림.flip_h = _방향 < 0.0      # 원본은 오른쪽을 본다


## 월드.gd 색 판정 계약 — 플레이어 몸 색과 다르면 위험하다(회색 몸은 안전 · 색규칙 한 곳에서 판단).
func 반대색인가(플레이어색: int) -> bool:
	return 색규칙.위험한가(색, 플레이어색)


## 유체 차단 계약은 그대로 두고, 총알 쪽의 몬스터 명중 경로에서 플레이어 페인트만 받는다.
func 총알_막나(_총알색: int) -> bool:
	return false


## 몸 그림·접촉 위험·다음 사격이 같은 색을 보게 기존 색 setter 한 곳에서 갱신한다.
func 명중(페인트색: int, _월드좌표: Vector2) -> String:
	if 페인트색 != ColorDefs.BLACK and 페인트색 != ColorDefs.WHITE:
		return "blocked"
	if 페인트색 == 색:
		return "wasted"
	색 = 페인트색
	return "painted"


## 몬스터끼리 쏘는 탄과 분사기 탄이 몸색을 덮어 전투 규칙을 바꾸지 않게 한다.
func 장치_명중(_페인트색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 현재색() -> int:
	return 색


func 칠_가능_미리보기(페인트색: int) -> bool:
	return (페인트색 == ColorDefs.BLACK or 페인트색 == ColorDefs.WHITE) and 페인트색 != 색


## 페인트코어의 E 회수와 리스폰 정산을 그대로 이용해 소비한 탄약이 사라지지 않게 한다.
func 되돌리기() -> bool:
	색 = _원래색
	return true


func 강제_초기화() -> void:
	색 = _원래색
