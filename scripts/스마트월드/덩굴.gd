@tool
extends Node2D
## ============================================================================
## [2026-08-08 신규] 벨레(Verlet) 덩굴 / 전선 / 사슬
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가 (도형님 요청)
##   "《레인월드》처럼 고정되어 있지 않고, 플레이어가 지나가며 건드렸을 때
##    유기적이고 부드럽게 출렁이는 덩굴/전선"
##
##   지금 스테이지의 장식은 전부 **정지 이미지**다. 그래서 아무리 많이 깔아도
##   배경이 '벽지'로 보인다. 레인월드가 살아 있는 것처럼 느껴지는 이유는
##   **플레이어가 지나가면 세상이 반응하기 때문**이다. 덩굴 하나가 흔들리는 것만으로
##   "이 공간에 내가 실제로 있다"는 감각이 생긴다.
##
## ▣ 왜 벨레 적분인가 (스프링 물리가 아니라)
##   벨레는 속도를 따로 들지 않는다. **이전 위치와 현재 위치의 차이가 곧 속도**다.
##     장점 1: 위치를 그냥 옮기기만 하면 그게 자연스러운 충격이 된다
##             (플레이어가 미는 처리가 한 줄로 끝난다)
##     장점 2: 길이 제약을 반복해서 밀어 넣어도 **폭발하지 않는다**
##             (스프링은 강성을 올리면 프레임 하나에 발산한다 — 로프에 최악이다)
##     장점 3: 마디 12 개 × 반복 4 회면 충분히 로프처럼 보인다. 아주 싸다
##
## ▣ 구조
##   _점[0]     = 고정점(anchor). 지형/천장에 박혀 절대 안 움직인다.
##   _점[1..n]  = 자유 마디. 중력 + 바람 + 플레이어 충격을 받는다.
##   매 프레임: ① 적분 → ② 길이 제약 반복 → ③ 그리기
##
## ▣ 성능 — ★스테이지가 22,000px 이나 된다
##   덩굴이 200 개 깔리면 매 프레임 200×12×4 = 9,600 번 계산이다. 그 자체는 싸지만
##   **화면 밖 덩굴까지 계산하는 건 낭비**다. 플레이어에서 `활성_거리` 밖이면
##   물리도 그리기도 통째로 쉰다. 다시 가까워지면 자연스럽게 다시 흔들린다.
##
## ▣ 쓰는 법
##   var v := 벨레덩굴.new()
##   v.position = 천장에서_찾은_부착점
##   v.마디수 = 14
##   v.종류 = 벨레덩굴.종류_.덩굴
##   부모.add_child(v)
## ============================================================================
class_name 벨레덩굴

## 무엇처럼 보일지. 물리는 같고 **그림과 기본값만** 달라진다.
##   덩굴 : 굵고 끝이 가늘어지며 잎이 달린다 (챕터 1 자연)
##   전선 : 가늘고 균일하며 늘어짐이 크다 (챕터 3 도시)
##   사슬 : 마디가 또렷하게 보인다 (챕터 2·3 산업 폐허)
enum 종류_ { 덩굴, 전선, 사슬 }

@export var 종류: 종류_ = 종류_.덩굴:
	set(v): 종류 = v; _기본값_적용(); queue_redraw()

@export_group("모양")
## 마디 개수. 많을수록 부드럽지만 비싸다. 10~16 이 적당하다.
@export_range(3, 40) var 마디수: int = 12:
	set(v): 마디수 = v; _다시_만들기()
## 마디 하나의 길이(px). 전체 길이 = 마디수 × 마디길이.
@export_range(6.0, 120.0) var 마디길이: float = 24.0:
	set(v): 마디길이 = v; _다시_만들기()
## 뿌리 굵기(px).
@export_range(1.0, 24.0) var 굵기: float = 5.0
## 끝 굵기 = 뿌리 굵기 × 이 값. 1 이면 균일(전선·사슬), 작을수록 뾰족(덩굴).
@export_range(0.05, 1.0) var 끝_굵기비: float = 0.30
## 늘어지는 방향. 기본은 아래(중력). 옆으로 뻗는 덩굴을 만들 때 바꾼다.
@export var 처음_방향: Vector2 = Vector2.DOWN

@export_group("물리")
@export_range(0.0, 3000.0) var 중력: float = 900.0
## 1 에 가까울수록 오래 흔들린다. 0.985 면 두어 번 크게 출렁이고 잦아든다.
@export_range(0.80, 1.0) var 감쇠: float = 0.985
## 길이 제약을 몇 번 반복할지. 3~5. 적으면 늘어나 보이고, 많으면 뻣뻣해진다.
@export_range(1, 10) var 반복: int = 4
## 바람에 흔들리는 세기(px/s²). 0 이면 바람을 안 탄다.
@export_range(0.0, 600.0) var 산들바람: float = 60.0

@export_group("상호작용")
## 플레이어가 이 반경 안에 들어오면 덩굴이 밀린다(px).
@export_range(0.0, 300.0) var 상호작용_반경: float = 52.0
## 밀리는 정도. 플레이어 속도의 몇 배를 마디에 실을지.
@export_range(0.0, 2.0) var 밀림세기: float = 0.55
## 플레이어에서 이 거리 밖이면 물리와 그리기를 통째로 쉰다(px).
## 화면 대각선(약 2,200px)보다 넉넉히 잡아, 화면에 들어오기 전에 이미 자연스럽게 늘어져 있게 한다.
@export_range(500.0, 8000.0) var 활성_거리: float = 2400.0

@export_group("색")
## 비워두면 종류에 맞는 기본색을 쓴다.
@export var 몸색: Color = Color(0, 0, 0, 0)

# ── 내부 상태 ──────────────────────────────────────────────────────────────
var _점: PackedVector2Array = PackedVector2Array()     ## 지금 위치 (로컬 좌표)
var _이전: PackedVector2Array = PackedVector2Array()   ## 직전 위치 (= 속도의 출처)
var _잎각: PackedFloat32Array = PackedFloat32Array()   ## 덩굴 잎이 붙는 각도(마디마다 고정)
var _t: float = 0.0
var _플레이어: Node2D = null
var _쉬는중: bool = false
var _씨앗: float = 0.0


func _ready() -> void:
	# 위치마다 다른 위상 — 모든 덩굴이 똑같이 흔들리면 즉시 가짜로 보인다
	_씨앗 = fmod(absf(global_position.x * 0.013 + global_position.y * 0.027), TAU)
	_기본값_적용()
	_다시_만들기()
	if Engine.is_editor_hint():
		return
	add_to_group("덩굴")
	set_physics_process(true)
	set_process(true)


## 종류에 맞는 기본값. **이미 손으로 바꾼 값은 건드리지 않는다** —
## 디자이너가 인스펙터에서 조정한 뒤 종류만 바꿔도 값이 날아가면 안 되기 때문에,
## 여기서는 "그 종류에서만 의미 있는" 값만 손댄다.
func _기본값_적용() -> void:
	match 종류:
		종류_.전선:
			끝_굵기비 = 1.0
			감쇠 = 0.992          # 전선은 무겁고 오래 흔들린다
		종류_.사슬:
			끝_굵기비 = 0.9
			감쇠 = 0.975          # 쇠사슬은 금방 멎는다
		_:
			pass


## 마디를 처음 상태(고정점에서 처음_방향으로 곧게 늘어진 상태)로 만든다.
func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	var n := maxi(마디수, 3)
	var 방향 := 처음_방향.normalized()
	if 방향 == Vector2.ZERO:
		방향 = Vector2.DOWN
	_점 = PackedVector2Array()
	_이전 = PackedVector2Array()
	_잎각 = PackedFloat32Array()
	for i in n:
		var p := 방향 * (마디길이 * float(i))
		_점.append(p)
		_이전.append(p)
		# 잎은 좌우로 번갈아 — 한쪽으로만 나면 깃발처럼 보인다
		_잎각.append((1.0 if i % 2 == 0 else -1.0) * (0.7 + fmod(float(i) * 0.37, 0.5)))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _점.size() < 2:
		return

	# ── 멀면 통째로 쉰다 ──
	_플레이어 = _플레이어_찾기()
	if _플레이어 and is_instance_valid(_플레이어):
		var 거리 := global_position.distance_to(_플레이어.global_position)
		if 거리 > 활성_거리:
			if not _쉬는중:
				_쉬는중 = true
				queue_redraw()      # 마지막 모습으로 한 번 그려두고 멈춘다
			return
		_쉬는중 = false

	_t += delta

	# ── ① 적분 ──
	# 벨레: 다음위치 = 지금 + (지금 − 이전) × 감쇠 + 가속도 × dt²
	# (지금 − 이전) 이 곧 속도라서 속도 배열을 따로 안 든다.
	var dt2 := delta * delta
	var 힘 := Vector2(0.0, 중력)
	if 산들바람 > 0.0:
		# 위상이 다른 사인 두 개 — 규칙적인 좌우 왕복으로 안 보이게
		힘.x += sin(_t * 0.9 + _씨앗) * 산들바람 * 0.6 \
			+ sin(_t * 2.3 + _씨앗 * 1.7) * 산들바람 * 0.4
	힘 += _송풍기_바람()

	for i in range(1, _점.size()):
		var 지금 := _점[i]
		var 속도 := (지금 - _이전[i]) * 감쇠
		_점[i] = 지금 + 속도 + 힘 * dt2
		_이전[i] = 지금

	# ── ② 플레이어 충격 ──
	_플레이어_밀기(delta)

	# ── ③ 길이 제약 ── 반복할수록 로프에 가까워진다
	for _r in 반복:
		_제약()

	queue_redraw()


## 마디 사이 거리를 원래 길이로 되돌린다.
## ⚠ 0 번 점(고정점)은 절대 안 움직인다 — 움직이면 덩굴이 지형에서 떨어져 나간다.
func _제약() -> void:
	_점[0] = Vector2.ZERO
	for i in range(1, _점.size()):
		var a := _점[i - 1]
		var b := _점[i]
		var 차 := b - a
		var 길이 := 차.length()
		if 길이 < 0.0001:
			# 완전히 겹치면 방향이 없다 → 아래로 살짝 떼어 놓는다
			_점[i] = a + Vector2(0, 마디길이)
			continue
		var 어긋남 := (길이 - 마디길이) / 길이
		# 앞 마디는 뿌리에 가까울수록 덜 움직여야 자연스럽다.
		# 0 번은 고정이므로 1 번은 자기가 전부 감당한다.
		if i == 1:
			_점[i] = b - 차 * 어긋남
		else:
			_점[i - 1] = a + 차 * (어긋남 * 0.5)
			_점[i] = b - 차 * (어긋남 * 0.5)


## ★플레이어가 지나가면 그 부위를 밀어낸다.
##
## ▣ 왜 "위치를 그냥 옮기는" 것으로 충분한가
##   벨레에서는 **위치를 옮기면 그 차이가 다음 프레임의 속도가 된다.**
##   그래서 힘을 계산해 더할 필요 없이, 겹친 만큼 밀어내기만 하면
##   자연스러운 충격과 반동이 공짜로 따라온다.
##
## ▣ 두 가지를 같이 준다
##   1) 밀어내기 : 플레이어 몸이 파고든 만큼 바깥으로 (덩굴이 몸을 통과하지 않는다)
##   2) 끌기     : 플레이어 속도를 조금 실어준다 (달리며 스치면 뒤로 휩쓸린다)
func _플레이어_밀기(delta: float) -> void:
	if _플레이어 == null or not is_instance_valid(_플레이어) or 상호작용_반경 <= 0.0:
		return
	var 중심 := to_local(_플레이어.global_position)
	# 플레이어 원점은 발바닥이다. 몸 중앙(키의 절반 위)을 기준으로 삼아야
	# 발끝만 스쳤을 때 덩굴 위쪽까지 휘는 이상한 그림이 안 나온다.
	중심.y -= 지형규칙.플레이어_키 * 0.5
	var 속도: Vector2 = _플레이어.get("velocity") if _플레이어.has_method("get") else Vector2.ZERO
	if typeof(속도) != TYPE_VECTOR2:
		속도 = Vector2.ZERO

	var r := 상호작용_반경
	for i in range(1, _점.size()):
		var 차 := _점[i] - 중심
		var d := 차.length()
		if d >= r:
			continue
		var 방향 := 차 / maxf(d, 0.001)
		# 1) 파고든 만큼 밀어낸다 (가장자리에서는 0, 중심에서는 최대)
		_점[i] += 방향 * (r - d) * 0.6
		# 2) 플레이어 속도를 실어 준다. 안쪽 마디일수록 세게.
		var 세기 := (1.0 - d / r) * 밀림세기
		_점[i] += 속도 * delta * 세기


## 송풍기 바람 — 이미 있는 장애물과 자연스럽게 엮인다.
## (총알이 바람을 타듯, 덩굴도 바람에 눕는다)
func _송풍기_바람() -> Vector2:
	var 합 := Vector2.ZERO
	for n in get_tree().get_nodes_in_group("송풍기"):
		if not n.has_method("바람"):
			continue
		var f: Vector2 = n.바람(global_position)
		if f != Vector2.ZERO:
			# 덩굴은 총알보다 훨씬 가볍게 반응한다 — 그대로 받으면 수평으로 뻗어버린다
			합 += f * 0.25
	return 합


func _플레이어_찾기() -> Node2D:
	if _플레이어 and is_instance_valid(_플레이어):
		return _플레이어
	return get_tree().get_first_node_in_group("player") as Node2D


# ── 그림 ────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	# 디자이너 그림 슬롯 — 텍스처가 꽂히면 코드 그리기는 쉰다 (다른 장애물과 같은 규약)
	if 아트슬롯.그림_있나(self):
		return
	if _점.size() < 2:
		return

	var 본색 := 몸색
	if 본색.a <= 0.0:
		match 종류:
			종류_.전선: 본색 = Color(0.10, 0.10, 0.12)
			종류_.사슬: 본색 = Color(0.34, 0.33, 0.31)
			_:          본색 = Color(0.16, 0.20, 0.15)

	# ★흑백 게임이라 단색 선은 어느 한쪽 배경에서 반드시 묻힌다.
	#   어두운 테두리를 먼저 굵게 깔고 그 위에 본체를 그린다(조준선과 같은 문법).
	var 테 := Color(0.02, 0.02, 0.03, 0.85)
	for 단계 in 2:
		var 테두리 := 단계 == 0
		for i in range(1, _점.size()):
			var t := float(i) / float(_점.size() - 1)
			var w := lerpf(굵기, 굵기 * 끝_굵기비, t)
			if 테두리:
				w += 2.0
			draw_line(_점[i - 1], _점[i], 테 if 테두리 else 본색, w, true)

	match 종류:
		종류_.덩굴:
			_잎_그리기(본색)
		종류_.사슬:
			_사슬마디_그리기(본색)
		_:
			pass


## 덩굴 잎 — 마디마다 좌우로 번갈아 작은 잎을 하나씩.
## 잎이 없으면 그냥 "줄"이라 덩굴로 안 읽힌다.
func _잎_그리기(본색: Color) -> void:
	var 잎색 := Color(본색.r * 1.35, 본색.g * 1.5, 본색.b * 1.25, 1.0)
	for i in range(2, _점.size() - 1):
		var 방향 := (_점[i] - _점[i - 1]).normalized()
		if 방향 == Vector2.ZERO:
			continue
		var 옆 := 방향.orthogonal() * _잎각[i]
		var 뿌리 := _점[i]
		var 길이 := 굵기 * 3.2 * (1.0 - float(i) / float(_점.size()) * 0.5)
		var 끝 := 뿌리 + 옆 * 길이 + 방향 * 길이 * 0.35
		var 중간 := 뿌리 + 옆 * 길이 * 0.5
		draw_colored_polygon(PackedVector2Array([
			뿌리,
			중간 + 방향 * 길이 * 0.45,
			끝,
			중간 - 방향 * 길이 * 0.30,
		]), 잎색)


## 사슬 마디 — 선 위에 작은 고리를 얹어 "쇠사슬"로 읽히게 한다.
func _사슬마디_그리기(본색: Color) -> void:
	var 고리 := Color(본색.r * 1.4, 본색.g * 1.4, 본색.b * 1.4, 1.0)
	for i in range(1, _점.size()):
		var 중간 := (_점[i - 1] + _점[i]) * 0.5
		draw_arc(중간, 굵기 * 0.85, 0.0, TAU, 8, 고리, 1.6, true)


# ── 조회 (도구·테스트용) ───────────────────────────────────────────────────
func 마디_위치(i: int) -> Vector2:
	return _점[clampi(i, 0, _점.size() - 1)] if not _점.is_empty() else Vector2.ZERO


func 끝_위치() -> Vector2:
	return _점[_점.size() - 1] if not _점.is_empty() else Vector2.ZERO


func 쉬는중() -> bool:
	return _쉬는중
