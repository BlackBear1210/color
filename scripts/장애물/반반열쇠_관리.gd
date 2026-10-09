extends Node
## ============================================================================
## [2026-10-08 Claude 신규] 반반 열쇠 관리 — 열쇠 스테이지 하나의 조각 · HUD 칸 · 잠긴 문 · 진행 저장
## ----------------------------------------------------------------------------
## ▣ 기획: docs/프롬프트_신규기믹_열쇠_빛몹_테마_2026-10-08.md §4-A · §4-B
##   열쇠는 **중간중간 특정 스테이지만**. 그 스테이지의 출구는 잠긴 문 — 검정 조각 + 흰 조각을 다 모아야 연다.
##
## ▣ 열쇠 스테이지 표(`표`) — 이 파일 한 곳에서 정한다(스테이지 순서를 `챕터.gd` 표 하나에 두는 것과 같은 원칙)
##   · "문" = 잠글 길목 노드 경로(월드 기준) · "왼쪽"/"오른쪽" = 검정/흰 조각 자리(월드 좌표, 조각 그림 가운데).
##   · 씬 파일을 고치지 않는다 — 쳅터1 은 도안 생성기(만들기.py)가 씬을 다시 쓰고, 하수도 씬은 무수정 원칙이라
##     실행 때 이 표를 보고 만든다(하수도 통로 구멍 메움과 같은 방식). 씬에 조각/문을 직접 놓아도 같이 맡는다.
##   · 조각 자리를 정하는 규칙(기획 §4-A 레벨 디자인): 그 색 몸으로 살아서 닿는 자리(공중 줍기 의도 제외) ·
##     주 경로에서 한 갈래 벗어난 곳 · 문 바로 앞 금지 · 두 조각은 서로 다른 갈래 · 근처에 세계 안 단서.
##
## ▣ 진행 — 죽어도 주운 조각은 유지(§7-7 추천) · 스테이지별로 `user://진행.cfg` [열쇠] 에 저장(`게임진행.gd`).
##   다시 들어와도 주운 조각은 HUD 에 채워진 채 시작하고, 문을 이미 열었으면 열린 채로 둔다.
##
## ▣ 월드.gd `_ready()` 끝(HUD 를 만든 뒤)에서 `배치(self)` 를 한 번 부른다. 열쇠 스테이지가 아니면 아무것도 안 만든다.
## ============================================================================

const 조각_스크립트 := preload("res://scripts/장애물/반반열쇠.gd")
const 문_스크립트 := preload("res://scripts/장애물/잠긴문.gd")
const HUD_스크립트 := preload("res://scripts/ui/열쇠_HUD.gd")
const 잉크_셰이더 := preload("res://shaders/ink_effect.gdshader")
const 열쇠_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/열쇠/"

## ★열쇠 스테이지 표 — **하수도용**(하수도 씬은 무수정 원칙이라 실행 때 이 표로 조각·문을 만든다).
##   쳅터1 은 [2026-10-09] 부터 도안 JSON 의 "기믹" 에 {"종류": "열쇠조각"} · {"종류": "잠긴문"} 으로 적고
##   tools/쳅터1/추가기믹.py 가 씬의 "추가기믹" 묶음에 넣는다(에디터에서 보이고 검사기가 자리를 검사한다).
##   이 관리자는 두 경우를 똑같이 맡는다(씬에 놓인 조각·문 + 이 표).
##   예) "res://scenes/world_2_클로드/stage_2-6.tscn": {"문": "출구통로", "왼쪽": Vector2(x, y), "오른쪽": Vector2(x, y)}
##   ⚠ 하수도를 넣으면 tools/하수도_주행검사.gd 공략에 조각 두 개 줍는 단계를 먼저 넣을 것(출구가 잠긴다).
const 표 := {}

var 씬경로 := ""
var HUD: Control = null
var _월드: Node = null
var _조각들: Array = []
var _문들: Array = []


## 월드가 부른다. 열쇠 스테이지면 관리자를 만들어 돌려준다(아니면 null).
static func 배치(월드: Node) -> Node:
	var 경로: String = 월드.scene_file_path
	var 항목: Dictionary = 표.get(경로, {})
	var 놓인 := 월드.get_tree().get_nodes_in_group("반반열쇠_조각").filter(func(n): return 월드.is_ancestor_of(n))
	var 놓인문 := 월드.get_tree().get_nodes_in_group("잠긴문").filter(func(n): return 월드.is_ancestor_of(n))
	if 항목.is_empty() and 놓인.is_empty() and 놓인문.is_empty():
		return null
	var 관 = load("res://scripts/장애물/반반열쇠_관리.gd").new()
	관.name = "반반열쇠"
	월드.add_child(관)
	관._시작(월드, 경로, 항목, 놓인, 놓인문)
	return 관


func _시작(월드: Node, 경로: String, 항목: Dictionary, 놓인: Array, 놓인문: Array) -> void:
	_월드 = 월드
	씬경로 = 경로
	# [2026-10-09] 조각의 '주인' — 특별 스테이지(예: 17 숨은 서재)에서 주운 조각이 다른 스테이지(16)의 문을 연다.
	#   이 씬에 문이 없고 조각에 `주인_씬` 이 적혀 있으면, 진행 저장·HUD 를 그 주인 스테이지 기준으로 한다.
	if 놓인문.is_empty() and not 항목.has("문"):
		for 조 in 놓인:
			var 주인 := String(조.get("주인_씬"))
			if 주인 != "":
				씬경로 = 주인
				break
	add_to_group("반반열쇠_관리")
	# 보관됐다 다시 들어온 스테이지(전경전환 되돌아가기)는 _ready 가 다시 안 불린다 → 트리에 들어올 때마다 HUD 를 다시 맞춘다
	tree_entered.connect(_새로고침)
	# ── 조각 ── 표에 적힌 자리 + 씬에 놓인 것. 이미 주운 쪽은 만들지 않는다.
	for 쪽 in ["왼쪽", "오른쪽"]:
		if 항목.has(쪽) and not 게임진행.열쇠_조각_있나(씬경로, 쪽):
			var 조 := Area2D.new()
			조.set_script(조각_스크립트)
			조.set("쪽", 0 if 쪽 == "왼쪽" else 1)
			조.name = "열쇠조각_" + 쪽
			조.position = 항목[쪽]
			_월드.add_child(조)
			놓인.append(조)
	for 조 in 놓인:
		if 게임진행.열쇠_조각_있나(씬경로, 조.call("쪽_이름")):
			조.queue_free()
			continue
		조.call("관리_연결", self)
		_조각들.append(조)
	# ── 잠긴 문 ── 표의 길목에 붙인다
	if 항목.has("문"):
		var 길목 := _월드.get_node_or_null(NodePath(항목["문"])) as Node2D
		if 길목 == null:
			push_warning("[반반열쇠] 문 길목 없음: %s" % 항목["문"])
		else:
			var 문 := Node2D.new()
			문.set_script(문_스크립트)
			문.name = "잠긴문_" + String(길목.name)
			문.call("붙이기", 길목)
			_월드.add_child(문)
			놓인문.append(문)
	for 문 in 놓인문:
		문.call("관리_연결", self)
		# 씬에 직접 놓인 문은 `길목` 경로로 붙인다(생성기가 적는다)
		var 길경로 = 문.get("길목")
		if 길경로 is NodePath and not (길경로 as NodePath).is_empty():
			var 길 := 문.get_node_or_null(길경로) as Node2D
			if 길:
				문.call("붙이기", 길)
		if 게임진행.열쇠_문_열림(씬경로):
			문.call("열린채로")
		_문들.append(문)
	_HUD_만들기()


func _HUD_만들기() -> void:
	var 층 := _월드.get_node_or_null("페인트HUD")
	var 루트 := 층.get_node_or_null("루트") if 층 else null
	if 루트 == null:
		return
	HUD = Control.new()
	HUD.set_script(HUD_스크립트)
	HUD.name = "열쇠칸"
	루트.add_child(HUD)
	# 자리 = 페인트 게이지 오른쪽(초상·게이지 + "× N" + "사망 N" 다음 칸). 여백은 HUD 가 가진 값을 따른다.
	var 여백: Vector2 = 층.get("여백") if 층.get("여백") != null else Vector2(34, 26)
	HUD.position = 여백 + Vector2(372, -2)
	HUD.call("준비", 게임진행.열쇠_조각_있나(씬경로, "왼쪽"), 게임진행.열쇠_조각_있나(씬경로, "오른쪽"))
	if 게임진행.열쇠_문_열림(씬경로):
		HUD.call("사용함")


## 다시 들어왔을 때 — 다른 스테이지(특별 스테이지)에서 조각을 주워 왔으면 HUD 에 반영한다.
func _새로고침() -> void:
	if HUD == null or not is_instance_valid(HUD):
		return
	HUD.call("준비", 게임진행.열쇠_조각_있나(씬경로, "왼쪽"), 게임진행.열쇠_조각_있나(씬경로, "오른쪽"))
	if 게임진행.열쇠_문_열림(씬경로):
		HUD.call("사용함")


func 완성됨() -> bool:
	return 게임진행.열쇠_조각_있나(씬경로, "왼쪽") and 게임진행.열쇠_조각_있나(씬경로, "오른쪽")


func 조각수() -> int:
	return int(게임진행.열쇠_조각_있나(씬경로, "왼쪽")) + int(게임진행.열쇠_조각_있나(씬경로, "오른쪽"))


# ── 줍기 ─────────────────────────────────────────────────────────────────────
## 조각이 부른다. 저장은 **바로** 한다(연출 도중 죽거나 떠나도 주운 것은 주운 것).
func 조각_주움(조각: Node2D, _몸: Node2D) -> void:
	var 쪽: String = 조각.call("쪽_이름")
	게임진행.열쇠_조각_기록(씬경로, 쪽)
	var 색: int = 조각.call("색")
	_획득빛(조각.global_position, 색)
	_날아가기(조각.global_position, 쪽)


## 줍는 순간 그 자리에서 조각 색의 빛이 짧게 퍼진다(0.35초 · 반경 약 3칸).
##   흰 = 부드러운 흰빛 고리 / 검정 = 어두운 잉크 고리 + 가장자리만 밝은 테(ink_effect 셰이더 mode 1).
func _획득빛(위치: Vector2, 색: int) -> void:
	var 흰 := 색 == ColorDefs.WHITE
	var s := Sprite2D.new()
	s.texture = load(열쇠_폴더 + ("획득빛_흰_퍼짐.png" if 흰 else "획득빛_검_퍼짐.png"))
	var m := ShaderMaterial.new()
	m.shader = 잉크_셰이더
	m.set_shader_parameter("mode", 0 if 흰 else 1)
	s.material = m
	s.global_position = 위치
	s.z_index = 40
	s.scale = Vector2.ONE * 0.22
	_월드.add_child(s)
	# 256px 그림 → 지름 192(반경 3칸)까지 0.35초에 퍼진다. 절반을 넘으면 '사라짐' 그림으로 바꾸고 옅어진다.
	var t := s.create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2.ONE * 0.75, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): s.texture = load(열쇠_폴더 + ("획득빛_흰_사라짐.png" if 흰 else "획득빛_검_사라짐.png"))).set_delay(0.17)
	t.tween_property(s, "modulate:a", 0.0, 0.2).set_delay(0.15)
	t.chain().tween_callback(s.queue_free)


## 조각이 HUD 칸으로 날아간다(0.35초 곡선) → 도착하면 HUD 가 그 모양대로 0.4초 채운다.
func _날아가기(월드위치: Vector2, 쪽: String) -> void:
	if HUD == null:
		return
	var 화면 := _월드.get_viewport().get_canvas_transform() * 월드위치
	var 목표: Vector2 = HUD.call("칸_중심")
	var 그림 := TextureRect.new()
	그림.texture = load(열쇠_폴더 + 쪽 + ".png")
	# ⚠ TextureRect 는 기본(EXPAND_KEEP_SIZE)이면 그림 크기(2배 저장) 아래로 줄지 않는다 → 크기 무시로
	그림.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	그림.stretch_mode = TextureRect.STRETCH_SCALE
	그림.mouse_filter = Control.MOUSE_FILTER_IGNORE
	그림.size = Vector2(그림.texture.get_size()) * 0.5
	그림.pivot_offset = 그림.size * 0.5
	HUD.get_parent().add_child(그림)
	var 시작 := 화면 - 그림.size * 0.5
	var 끝 := 목표 - 그림.size * 0.5
	var 손잡이 := (시작 + 끝) * 0.5 + Vector2(0, -160)       # 위로 휘는 곡선
	var 곡선 := func(k: float) -> void:
		var a := 시작.lerp(손잡이, k)
		var b := 손잡이.lerp(끝, k)
		그림.position = a.lerp(b, k)
		그림.scale = Vector2.ONE * lerpf(1.0, 1.2, k)
	var t := 그림.create_tween()
	t.tween_method(곡선, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		그림.queue_free()
		HUD.call("채우기", 쪽))


# ── 잠긴 문 ──────────────────────────────────────────────────────────────────
## 열쇠 없이(또는 반쪽만) 문에 다가왔다.
func 잠긴문_알림() -> void:
	if HUD == null:
		return
	HUD.call("흔들기")
	if 조각수() == 1:
		HUD.call("빈쪽_깜빡")


## 완성 열쇠를 HUD 에서 자물쇠로 날려 보낸다(0.4초) → 꽂혀서 돈다(0.12초) → `끝` 을 부른다.
func 열쇠_꽂으러_보내기(문: Node2D, 끝: Callable) -> void:
	게임진행.열쇠_문_열기_기록(씬경로)
	if HUD == null:
		끝.call()
		return
	HUD.call("사용함")
	var 열쇠 := Control.new()
	열쇠.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for 쪽 in ["왼쪽", "오른쪽"]:
		var tr := TextureRect.new()
		tr.texture = load(열쇠_폴더 + 쪽 + ".png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # 위와 같은 이유(안 하면 2배 크기로 날아간다)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = Vector2(tr.texture.get_size()) * 0.5
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		열쇠.add_child(tr)
	열쇠.size = Vector2(40, 72)
	# 축 = 날 끝(그림 아래쪽 64px 지점). 줄이기·돌리기가 모두 이 점을 기준으로 일어나므로
	#   '날 끝 = 자물쇠 구멍' 으로 맞춰 두면 줄어도 돌아도 날이 구멍에서 빠지지 않는다(꽂힌 채 돈다).
	열쇠.pivot_offset = Vector2(20, 64)
	HUD.get_parent().add_child(열쇠)
	var 시작: Vector2 = HUD.call("칸_중심") - 열쇠.size * 0.5
	var 문화면 := _월드.get_viewport().get_canvas_transform() * (문.call("자물쇠_위치") as Vector2)
	# 자물쇠(게임 키 40px)에 맞게 날아가며 0.6 배로 준다 — 열쇠가 자물쇠보다 크면 '꽂힌다' 가 안 읽힌다
	var 끝위치 := 문화면 - 열쇠.pivot_offset
	var t := 열쇠.create_tween()
	t.set_parallel(true)
	t.tween_property(열쇠, "position", 끝위치, 0.4).from(시작).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(열쇠, "scale", Vector2.ONE * 0.6, 0.4)
	t.set_parallel(false)
	t.tween_property(열쇠, "rotation", PI * 0.5, 0.12)
	t.tween_callback(끝)
	t.tween_property(열쇠, "modulate:a", 0.0, 0.18)
	t.tween_callback(열쇠.queue_free)
