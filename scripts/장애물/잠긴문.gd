extends Node2D
## ============================================================================
## [2026-10-08 Claude 신규] 잠긴 문 — 열쇠 스테이지의 출구 길목을 막는 문
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-B · 카드 4
##   · 집 = 낡은 나무 문(쇠띠·징) + 가로지른 쇠사슬 + 원형 자물쇠 / 하수도 = 주철 격자문 + 같은 자물쇠.
##   · 열쇠 없이 다가가면: 막혀 있고 자물쇠가 덜컥 흔들림 + HUD 점선 열쇠가 흔들림.
##     조각 하나만 있으면 HUD 의 빈 반쪽이 깜빡여 무엇이 모자란지 알린다.
##   · 완성된 열쇠를 가지고 다가가면(자동, E 불필요): HUD 열쇠가 자물쇠로 날아가 꽂힘(0.4초) →
##     자물쇠가 열려 떨어지고 사슬이 풀려 떨어짐 → 문이 열림(0.6초) → 콜리전 해제 →
##     걸어가던 그대로 연결구/연결통로의 쳅터1 전환으로 이어진다.
##   · 잠금은 **출구 한 곳에만**(새 길은 빛 장치로 연다).
##
## ▣ 놓는 법 — `반반열쇠_관리.gd` 가 표에 적힌 길목(연결구·연결통로)에 실행 때 `붙이기()` 로 붙인다.
##   원점 = 길목 바닥선 × 벽 안쪽 면(연결구 규약과 같다 · 연결통로는 입구 = 원점). `방향` = 통로가 뻗는 쪽.
##   문은 길목 입구 바로 안쪽(통로 쪽)에 선다. 콜리전은 문 가운데 24px 판 — 길목의 전환 판정(연결구 56px ·
##   연결통로 깊이의 49%)보다 앞이라 잠긴 동안에는 전환이 일어나지 않는다.
##
## ▣ 그림 — `게임용/잠금/`(tools/생성_신규기믹_게임용.py 잠금): 문 닫힘(사슬 띠를 지운 빈 문) · 문 열림 ·
##   원형 자물쇠 닫힘/열림 · 사슬 토막 · 낱 고리 4. 사슬·자물쇠는 따로 얹어 코드로 떨어뜨린다.
##   z 61 = 연결구 전경 띠(z 60) 앞 — 잠긴 문은 길목의 어둠에 묻히면 안 된다(무엇이 막고 있는지 읽혀야 한다).
## ============================================================================

const 폴더 := "res://assets/textures/props/신규기믹_v02/게임용/잠금/"

@export_enum("자동", "집", "하수도") var 재질: int = 0
## +1 = 통로가 오른쪽으로 뻗는다(오른쪽 벽의 길목) · −1 = 왼쪽.
@export var 방향: int = 1
## 통로 높이(px) — 문 그림 키를 여기에 맞춘다.
@export var 높이: float = 160.0
## [2026-10-09] 씬에 직접 놓을 때 붙을 길목(연결구·연결통로). 관리자가 `붙이기()` 를 부른다.
@export var 길목: NodePath

var 열림 := false
var _관리: Node = null
var _진행중 := false
var _쿨 := 0.0
var _문: Sprite2D
var _열린문: Sprite2D
var _자물쇠: Sprite2D
var _사슬들: Array[Sprite2D] = []
var _막이: StaticBody2D
var _감지: Area2D
var _배율 := 0.5
var _폭 := 94.0
var _문x := 0.0          ## 문 가운데 x(로컬)


## 길목(연결구 · 연결통로)에 붙인다. 원점·방향·높이를 길목에서 읽는다.
func 붙이기(길: Node2D) -> void:
	global_position = 길.global_position
	if 길.has_method("방향"):
		방향 = 1 if float(길.call("방향")) > 0.0 else -1
	else:
		방향 = 1 if int(길.get("방향")) > 0 else -1
	var h = 길.get("높이")
	if h != null:
		높이 = float(h)
	# [2026-10-09] 씬에 놓인 문은 _ready(제 자리 기준으로 이미 지음) 뒤에 붙는다 → 새 자리·방향으로 다시 짓는다
	if _문 != null and is_inside_tree():
		for c in get_children():
			c.queue_free()
		_사슬들.clear()
		_만들기()


func 관리_연결(관리: Node) -> void:
	_관리 = 관리


func _재질_이름() -> String:
	if 재질 == 1:
		return "집"
	if 재질 == 2:
		return "하수도"
	var 씬 := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	return "하수도" if 씬.contains("world_2") else "집"


func _ready() -> void:
	add_to_group("잠긴문")
	_만들기()


func _만들기() -> void:
	z_index = 61
	var 재 := _재질_이름()
	var 닫힌 := load(폴더 + 재 + "_문_닫힘.png") as Texture2D
	var 열린 := load(폴더 + 재 + "_문_열림.png") as Texture2D
	if 닫힌 == null:
		push_warning("[잠긴문] 그림 없음 — tools/생성_신규기믹_게임용.py 잠금 을 돌릴 것")
		return
	# 문 키 = 통로 높이(2배 그림 → 배율)
	_배율 = 높이 / float(닫힌.get_height())
	_폭 = 닫힌.get_width() * _배율
	var d := float(방향)
	_문x = d * (_폭 * 0.5 + 4.0)
	# 경첩은 그림 오른쪽 → 문짝이 오른쪽 끝을 축으로 접히게 원점을 오른쪽 아래에 둔다
	var 오른끝 := _문x + _폭 * 0.5
	_문 = _스프라이트(닫힌, Vector2(오른끝, 0.0), Vector2(-닫힌.get_width(), -닫힌.get_height()))
	_열린문 = _스프라이트(열린, Vector2(_문x - _폭 * 0.5, 0.0), Vector2(0, -열린.get_height()))
	_열린문.modulate.a = 0.0
	# 사슬 — 양쪽 기둥(문 폭의 ±46%, 키의 46% 높이)에서 자물쇠(가운데, 키의 39%)로 살짝 처진 V 자
	var 사슬 := load(폴더 + "사슬.png") as Texture2D
	var 자물 := load(폴더 + "자물쇠_닫힘.png") as Texture2D
	var 자물y := -높이 * 0.39
	for 옆 in [-1.0, 1.0]:
		var a := Vector2(_문x + 옆 * _폭 * 0.46, -높이 * 0.47)
		var b := Vector2(_문x, 자물y - 6.0)
		var s := _스프라이트(사슬, (a + b) * 0.5, -Vector2(사슬.get_size()) * 0.5)
		s.rotation = (b - a).angle() if 옆 < 0 else (a - b).angle()
		s.scale = Vector2(a.distance_to(b) / float(사슬.get_width()), _배율 * 2.0 * 0.5)
		_사슬들.append(s)
	_자물쇠 = _스프라이트(자물, Vector2(_문x, 자물y), -Vector2(자물.get_size()) * 0.5)
	_자물쇠.scale = Vector2.ONE * 0.5
	# 막이 — 문의 **방 쪽 면** 12px 판(위로 64 더 — 통로 천장 속까지 막아 뛰어넘지 못하게).
	#   처음엔 문 가운데에 두었더니 몸이 문 그림 속으로 반쯤 들어가 문(z 61) 뒤에 가려졌다(촬영 2026-10-08) → 문 앞에서 멈추게.
	_막이 = StaticBody2D.new()
	_막이.collision_layer = 1
	_막이.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12.0, 높이 + 64.0)
	cs.shape = r
	cs.position = Vector2(d * 10.0, -높이 * 0.5 - 32.0)
	_막이.add_child(cs)
	add_child(_막이)
	# 감지 — 문 앞(방 쪽) 130px 부터 문 가운데까지
	_감지 = Area2D.new()
	_감지.collision_layer = 0
	_감지.collision_mask = 1
	_감지.monitorable = false
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	var 앞 := -d * 130.0
	r2.size = Vector2(absf(_문x - 앞), 높이)
	cs2.shape = r2
	cs2.position = Vector2((_문x + 앞) * 0.5, -높이 * 0.5)
	_감지.add_child(cs2)
	add_child(_감지)
	_감지.body_entered.connect(_몸_들어옴)
	set_process(false)


func _스프라이트(tex: Texture2D, 위치: Vector2, 오프셋: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = 오프셋
	s.position = 위치
	s.scale = Vector2.ONE * _배율
	add_child(s)
	return s


## 저장된 진행이 '이미 열었다' 면 연출 없이 열린 채로 시작한다.
func 열린채로() -> void:
	열림 = true
	if _문 == null:
		return
	_문.visible = false
	_열린문.modulate.a = 1.0
	_자물쇠.visible = false
	for s in _사슬들:
		s.visible = false
	_막이_끄기()


## 열쇠 구멍 자리(월드). 자물쇠 그림의 가운데는 고리(위)까지 포함한 가운데라, 몸통의 구멍은 그보다 아래다
##   (원형 자물쇠: 그림 키 40 중 구멍 = 가운데에서 +9px — 촬영 2026-10-08 로 맞춤).
func 자물쇠_위치() -> Vector2:
	return (_자물쇠.global_position + Vector2(0, 9)) if _자물쇠 else global_position + Vector2(_문x, -높이 * 0.4)


func _몸_들어옴(몸: Node2D) -> void:
	if 열림 or _진행중 or not 몸.is_in_group("player"):
		return
	if _관리 == null:
		return
	if _관리.call("완성됨"):
		_진행중 = true
		# HUD 의 완성 열쇠가 자물쇠로 날아와 꽂힌 뒤(0.4초) 연다
		_관리.call("열쇠_꽂으러_보내기", self, _열기)
		return
	# 열쇠가 없다 — 덜컥(자물쇠 흔들림) + HUD 알림. 같은 접근에 연달아 울리지 않게 0.8초 쉰다.
	#   시계는 **게임 시간**(물리 프레임 수)으로 잰다 — 실제 시각(ms)으로 재면 일시정지·고정 fps 시험에서 어긋난다.
	if _게임시간() < _쿨:
		return
	_쿨 = _게임시간() + 0.8
	_덜컥()
	_관리.call("잠긴문_알림")


func _게임시간() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _덜컥() -> void:
	if _자물쇠 == null:
		return
	var t := create_tween()
	for i in 4:
		var 각 := 0.28 * (1.0 - float(i) / 4.0) * (1.0 if i % 2 == 0 else -1.0)
		t.tween_property(_자물쇠, "rotation", 각, 0.05)
	t.tween_property(_자물쇠, "rotation", 0.0, 0.05)
	# 사슬도 같이 살짝 출렁 — 무거운 사슬이라 1px 만
	for s in _사슬들:
		var t2 := create_tween()
		t2.tween_property(s, "position:y", s.position.y + 1.5, 0.06)
		t2.tween_property(s, "position:y", s.position.y, 0.12)


## 열쇠가 꽂힌 뒤 — 자물쇠 열림·낙하 → 사슬 낙하 → 문 열림(0.6초) → 콜리전 해제
func _열기() -> void:
	열림 = true
	if _자물쇠 == null:
		_막이_끄기()
		return
	_자물쇠.texture = load(폴더 + "자물쇠_열림.png")
	_자물쇠.offset = -Vector2(_자물쇠.texture.get_size()) * 0.5 + Vector2(0, -6)
	var 바닥 := 0.0
	var t := create_tween().set_parallel(true)
	# 자물쇠: 0.12초 열린 채 멈칫 → 아래로 떨어지며 돈다
	t.tween_property(_자물쇠, "position:y", 바닥 - 8.0, 0.42).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_자물쇠, "rotation", 1.4 * float(방향), 0.42).set_delay(0.12)
	t.tween_property(_자물쇠, "modulate:a", 0.0, 0.25).set_delay(0.55)
	# 사슬: 가운데가 풀려 양쪽으로 늘어지며 떨어진다
	for i in _사슬들.size():
		var s := _사슬들[i]
		var 옆 := -1.0 if i == 0 else 1.0
		t.tween_property(s, "rotation", s.rotation + 옆 * -1.1, 0.35).set_delay(0.15)
		t.tween_property(s, "position", s.position + Vector2(옆 * 10.0, 높이 * 0.38), 0.45).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(s, "modulate:a", 0.0, 0.2).set_delay(0.5)
	_고리_떨어뜨리기()
	# 문: 0.25초부터 0.6초 동안 — 닫힌 문짝이 경첩(오른쪽) 쪽으로 접히며 어두워지고, 열린 문 그림이 떠오른다
	t.tween_property(_문, "scale:x", _배율 * 0.28, 0.6).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_문, "modulate", Color(0.45, 0.45, 0.45, 0.0), 0.6).set_delay(0.25)
	t.tween_property(_열린문, "modulate:a", 1.0, 0.45).set_delay(0.4)
	t.chain().tween_callback(func():
		_막이_끄기()
		_진행중 = false)
	# 문은 열리는 중간(0.55초)에 지나갈 수 있게 — 걸어가던 그대로 이어지도록 끝까지 기다리지 않는다
	get_tree().create_timer(0.55, false).timeout.connect(_막이_끄기)


func _고리_떨어뜨리기() -> void:
	for i in 4:
		var tex := load(폴더 + "고리_%d.png" % i) as Texture2D
		if tex == null:
			continue
		var s := _스프라이트(tex, Vector2(_문x + randf_range(-_폭 * 0.3, _폭 * 0.3), -높이 * 0.42), -Vector2(tex.get_size()) * 0.5)
		s.scale = Vector2.ONE * 0.5
		var t := create_tween().set_parallel(true)
		var 아래 := randf_range(-6.0, 0.0)
		t.tween_property(s, "position", Vector2(s.position.x + randf_range(-26, 26), 아래), randf_range(0.38, 0.5)).set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(s, "rotation", randf_range(-3.0, 3.0), 0.5).set_delay(0.15)
		t.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.9)
		t.chain().tween_callback(s.queue_free)


func _막이_끄기() -> void:
	if _막이 and is_instance_valid(_막이):
		for c in _막이.get_children():
			(c as CollisionShape2D).set_deferred("disabled", true)
		_막이.set_deferred("collision_layer", 0)
	if _감지:
		_감지.set_deferred("monitoring", false)
