@tool
extends Node2D
## ============================================================================
## [2026-09-14 신규] 하수도 쇠사슬 — 길이가 바뀌어도 고리 크기가 그대로인 반복 텍스처 장식
## ----------------------------------------------------------------------------
## ▣ 무엇인가
##   천장 고정점(A)에서 발판 연결점(B)까지 쇠사슬 그림을 **반복 단위 텍스처**로 이어 그린다.
##   충돌·색 규칙·게임 그룹이 전혀 없다 — 총알도 플레이어도 그냥 지나간다(프롬프트 §8).
##   "이 발판은 천장 기계에 매달려 있다" 를 보여 주는 그림일 뿐이다.
##
## ▣ 길이를 바꾸는 원리 (프롬프트 §5-1)
##   draw_polygon 한 번으로 A→B 사각형을 그리되 UV 의 v 를 `길이 / 고리_간격` 까지 늘린다.
##   `texture_repeat = ENABLED` 라 텍스처가 그만큼 반복된다. Scale 을 늘리지 않으므로 고리가
##   길쭉해지지 않고, 고리 수만큼 노드를 만들지도 않는다(매 프레임 노드 생성 금지).
##   위상은 **B(발판 연결점)에 고정**한다(v = 0 이 B). 길이가 고리 한 칸을 넘어가도 B 쪽 고리는
##   제자리에 있고 A(천장) 쪽으로 고리가 "감겨 들어가는" 것처럼 보인다 → 전체가 한 칸 튀지 않는다.
##
## ▣ 모드 (프롬프트 §5-3)
##   고정   : `고정_시작`·`고정_끝`(이 노드의 **로컬** 좌표)으로 그린다. 값이 바뀔 때만 다시 그린다.
##   추적   : `시작점_경로`·`끝점_경로`(Marker2D 등 Node2D)의 **월드** 위치를 읽어 로컬로 바꿔 그린다.
##            경로가 비었거나 끊어졌으면 그 쪽은 고정 좌표를 쓴다(끝점만 추적하는 경우).
##            둘 다 없으면 아무것도 안 그리고 경고를 **한 번만** 찍는다 — 원점까지 긴 체인을 그리지 않는다.
##   우선순위: 추적 모드에서 유효한 경로가 있으면 경로가 이기고, 없으면 고정 좌표다.
##
## ▣ 갱신 시점 (프롬프트 §5-4)
##   승강기는 `_physics_process` 에서 움직인다(움직이는발판.gd). 체인은 `_process` 에서 위치를 읽는데,
##   같은 프레임에 물리가 먼저 돌므로 화면에 한 프레임 늦게 보이지 않는다. 위치가 실제로 바뀐 프레임에만
##   `queue_redraw()` 한다. 체인은 **읽기만** 한다 — 승강기 position 을 절대 건드리지 않는다.
##
## ▣ 한계
##   · 최대 길이 `최대_길이`(기본 4000). 넘으면 B 에서 그만큼만 그리고 한 번 경고한다.
##   · 부모의 비균일/음수 스케일은 지원하지 않는다(로컬 변환을 그대로 쓰므로 그림이 찌그러진다). 부모 Scale (1,1) 권장.
##   · 수평 승강기에 매달면 대각선으로 늘어나 보인다. 수직 승강기 전용으로 쓴다.
## ============================================================================

## 기본 텍스처 — 24×48 반복 단위(앞고리 + 옆고리). `tools/생성_하수도_지지구조_아트.gd` 가 굽는다.
const 기본_텍스처 := "res://assets/decorations/sewer_support_v01/chain_repeat.png"

enum 모드_ { 고정, 추적 }

@export var 모드: 모드_ = 모드_.추적:
	set(v):
		모드 = v
		# 고정 모드는 매 프레임 볼 게 없다 — _process 를 끈다(100 개면 프레임당 0.2ms 차이 · 측정_지지구조_비용.gd)
		set_process(모드 == 모드_.추적)
		_다시_계산(true)

@export_group("추적 (Marker2D 경로)")
## 천장 고정점. **승강기 바깥**에 둔다 — 승강기 자식이면 두 점이 같이 움직여 길이가 안 변한다.
@export var 시작점_경로: NodePath:
	set(v):
		시작점_경로 = v
		_시작노드 = null
		_경고_함 = false
		_다시_계산(true)
## 발판 연결점. 승강기의 **자식** Marker2D.
@export var 끝점_경로: NodePath:
	set(v):
		끝점_경로 = v
		_끝노드 = null
		_경고_함 = false
		_다시_계산(true)

@export_group("고정 (이 노드의 로컬 좌표)")
@export var 고정_시작: Vector2 = Vector2(0, 0):
	set(v):
		고정_시작 = v
		_다시_계산(true)
@export var 고정_끝: Vector2 = Vector2(0, 240):
	set(v):
		고정_끝 = v
		_다시_계산(true)

@export_group("모양")
## 그려지는 폭(px). 텍스처 가로를 이 폭으로 맞춘다. 고리 간격과 같은 비율(24:48)을 유지해야 고리가 안 찌그러진다.
@export_range(8.0, 96.0, 1.0) var 고리_폭: float = 24.0:
	set(v):
		고리_폭 = v
		queue_redraw()
## 텍스처 한 단위가 차지하는 길이(px). 24×48 텍스처면 48.
@export_range(8.0, 192.0, 1.0) var 고리_간격: float = 48.0:
	set(v):
		고리_간격 = maxf(v, 4.0)
		queue_redraw()
## 양 끝을 이만큼 짧게 그린다 — 고정구 그림 뒤로 체인 끝을 숨긴다. 길이의 40 % 까지만 허용.
@export_range(0.0, 64.0, 1.0) var 끝단_겹침: float = 6.0:
	set(v):
		끝단_겹침 = v
		queue_redraw()
@export var 텍스처: Texture2D:
	set(v):
		텍스처 = v
		_경고_함 = false
		queue_redraw()
## 전체 색조. 화면 밝기 규칙(흰 발판보다 어둡게)을 지킨다.
@export var 색조: Color = Color(1, 1, 1, 1):
	set(v):
		색조 = v
		queue_redraw()
## 이보다 길면 B 에서 이 길이까지만 그린다.
@export_range(100.0, 8000.0, 10.0) var 최대_길이: float = 4000.0

var _시작노드: Node2D = null
var _끝노드: Node2D = null
var _마지막_A := Vector2.INF
var _마지막_B := Vector2.INF
var _경고_함: bool = false
var _경고_횟수: int = 0          ## 검사기가 "같은 경고를 반복하지 않는가" 를 세는 데 쓴다
var _그리기_횟수: int = 0        ## 검사기가 "안 바뀌면 안 그리는가" 를 세는 데 쓴다


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if 텍스처 == null:
		텍스처 = load(기본_텍스처)
	# 추적 모드만 매 프레임 본다(에디터 미리보기도 같이 움직인다). 플레이 로직·저장·노드 생성은 하지 않는다(그리기만).
	set_process(모드 == 모드_.추적)
	_다시_계산(true)


func _exit_tree() -> void:
	# 씬을 나가면 참조를 놓는다 — 다시 들어올 때 옛 노드를 붙들지 않는다.
	_시작노드 = null
	_끝노드 = null


func _process(_delta: float) -> void:
	if 모드 != 모드_.추적:
		return
	_다시_계산(false)


## 두 끝점(로컬)을 구해 바뀌었을 때만 다시 그린다.
func _다시_계산(강제: bool) -> void:
	if not is_inside_tree():
		return
	var 끝들 := 끝점_로컬()
	var a: Vector2 = 끝들[0]
	var b: Vector2 = 끝들[1]
	if 강제 or a.distance_squared_to(_마지막_A) > 0.0001 or b.distance_squared_to(_마지막_B) > 0.0001:
		_마지막_A = a
		_마지막_B = b
		queue_redraw()


## [A(천장), B(발판)] 을 **이 노드의 로컬 좌표**로. 못 구하면 INF.
func 끝점_로컬() -> Array:
	var a := Vector2.INF
	var b := Vector2.INF
	if 모드 == 모드_.추적:
		var sn := _노드(시작점_경로, true)
		var en := _노드(끝점_경로, false)
		if sn != null:
			a = to_local(sn.global_position)
		elif 시작점_경로.is_empty():
			a = 고정_시작
		if en != null:
			b = to_local(en.global_position)
		elif 끝점_경로.is_empty():
			b = 고정_끝
	else:
		a = 고정_시작
		b = 고정_끝
	return [a, b]


func _노드(경로: NodePath, 시작쪽: bool) -> Node2D:
	if 경로.is_empty():
		return null
	var 캐시 := _시작노드 if 시작쪽 else _끝노드
	if 캐시 != null and is_instance_valid(캐시) and 캐시.is_inside_tree():
		return 캐시
	var n := get_node_or_null(경로) as Node2D
	if n == null:
		_경고("쇠사슬 %s: %s 경로 '%s' 를 못 찾았다 — 그 쪽은 안 그린다" % [
			name, "시작점" if 시작쪽 else "끝점", String(경로)])
		return null
	if 시작쪽:
		_시작노드 = n
	else:
		_끝노드 = n
	return n


func _경고(글: String) -> void:
	if _경고_함:
		return
	_경고_함 = true
	_경고_횟수 += 1
	push_warning(글)
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var 목록 := PackedStringArray()
	if 모드 == 모드_.추적 and 시작점_경로.is_empty() and 끝점_경로.is_empty():
		목록.append("추적 모드인데 시작점·끝점 경로가 둘 다 비었다 — 고정 좌표로 그린다")
	if 텍스처 == null:
		목록.append("텍스처가 없다")
	return 목록


## 지금 그려지는 상태. 검사기와 사용 안내용 — 그리기와 같은 계산을 쓴다.
##   {보임, 시작(로컬), 끝(로컬), 길이, 그린길이, 고리수, 위상기준="끝점"}
func 그리기_정보() -> Dictionary:
	var 끝들 := 끝점_로컬()
	var a: Vector2 = 끝들[0]
	var b: Vector2 = 끝들[1]
	var 정보 := {"보임": false, "시작": a, "끝": b, "길이": 0.0, "그린길이": 0.0, "고리수": 0.0, "위상기준": "끝점"}
	if 텍스처 == null or a == Vector2.INF or b == Vector2.INF:
		return 정보
	var 길이 := a.distance_to(b)
	정보["길이"] = 길이
	if 길이 < 1.0:
		return 정보                                    # 길이 0 — 정규화 전에 끝낸다
	var 그린 := minf(길이, 최대_길이)
	var 겹침 := minf(끝단_겹침, 그린 * 0.2)              # 양 끝 합쳐 40 % 까지만
	그린 -= 겹침 * 2.0
	if 그린 <= 1.0:
		return 정보
	정보["보임"] = true
	정보["그린길이"] = 그린
	정보["고리수"] = 그린 / 고리_간격
	return 정보


func _draw() -> void:
	_그리기_횟수 += 1
	var 정보 := 그리기_정보()
	if not bool(정보["보임"]):
		if 텍스처 == null:
			_경고("쇠사슬 %s: 텍스처가 없다" % name)
		return
	var a: Vector2 = 정보["시작"]
	var b: Vector2 = 정보["끝"]
	var 길이: float = 정보["길이"]
	if 길이 > 최대_길이:
		_경고("쇠사슬 %s: 길이 %.0f 가 최대 %.0f 를 넘는다 — 끝점에서 최대 길이만 그린다" % [name, 길이, 최대_길이])
	var 방향 := (a - b) / 길이                            # B(발판) → A(천장)
	var 옆 := Vector2(-방향.y, 방향.x) * (고리_폭 * 0.5)
	var 겹침 := minf(끝단_겹침, minf(길이, 최대_길이) * 0.2)
	var 시작 := b + 방향 * 겹침                          # v = 0 자리 (발판 쪽)
	var 끝 := 시작 + 방향 * float(정보["그린길이"])
	var v끝 := float(정보["고리수"])
	# 텍스처의 v 는 위(0)가 발판 쪽이 되게 뒤집어 붙인다 — 단위 그림의 첫 고리가 발판에 붙는다.
	var 점들 := PackedVector2Array([시작 - 옆, 시작 + 옆, 끝 + 옆, 끝 - 옆])
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, v끝), Vector2(0, v끝)])
	var 색들 := PackedColorArray([색조, 색조, 색조, 색조])
	draw_polygon(점들, 색들, uv, 텍스처)
