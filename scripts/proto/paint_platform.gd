@tool
extends AnimatableBody2D
## (상속 메모) StaticBody2D 가 아니라 AnimatableBody2D 를 상속한다.
## AnimatableBody2D 는 StaticBody2D 의 자식 클래스라 "가만히 있는 지형"으로는 완전히 동일하게
## 동작하면서, `sync_to_physics = true` 만 켜면 **플레이어를 태우고 움직이는 발판**이 된다.
## → 움직이는발판·무너지는발판 같은 장애물이 이 클래스를 그대로 상속해서 쓸 수 있다.
## ============================================================================
## [2026-07-24 도형 · 신규] 칠할 수 있는 플랫폼 (Paint Platform) — 페인트 시스템 v3
## ----------------------------------------------------------------------------
## ▣ 2026-07-24 회의 결정 반영
##   "플랫폼·장애물마다 최대 색칠 횟수가 있다. 8칸짜리 플랫폼은 4번 칠하면 전체가 바뀐다."
##   → 색칠 단위 = 타일 1칸(v2) 이 아니라 **플랫폼 1개**.
##   → 칠해진 지점에서 색이 퍼져나간다.
##
## ▣ 셰이더로 갈지 다른 방법으로 갈지 (도형님 질문에 대한 결론)
##   **둘 다 쓰되 역할을 나눈다.**
##   · 규칙/판정(몇 번 맞았나, 지금 무슨 색인가, 밟으면 죽나) = 이 스크립트(CPU).
##     퍼즐 게임은 판정이 결정론적이어야 하고, 저장·되돌리기·자동테스트가 가능해야 한다.
##     GPU 픽셀을 되읽어 판정하면 느리고 비결정적이라 절대 안 된다.
##   · 표현(어떻게 퍼져 보이나) = 셰이더(shaders/ink_spread.gdshader).
##     "칠해진 면쪽으로 색이 퍼져나간다"는 요구가 정확히 셰이더 마스크의 일이다.
##   이 분리 덕분에 나중에 아트/연출을 통째로 바꿔도 게임 규칙은 한 줄도 안 바뀐다.
##
## ▣ 색칠 횟수(내구도) 자동 계산
##   기본식: 필요횟수 = ceil( 긴 변의 칸 수 / 2 ), 최소 1
##   → 8칸 플랫폼 = 4번 (회의에서 정한 예시와 일치)
##   개별 조정이 필요하면 인스펙터의 `필요횟수_수동` 에 0 이 아닌 값을 넣으면 그게 우선.
##
## ▣ 상태 4가지
##   무색  : 아직 안 칠해짐. 흑·백 누구든 밟아도 안전. 칠할 수 있음.
##   검정  : 검정 상태 플레이어만 안전. 흰색이 밟으면 즉사.
##   흰색  : 흰색 상태 플레이어만 안전. 검정이 밟으면 즉사.
##   회색  : 장애물 상호작용이나 시작 설정으로만 만드는 중립 상태. 플레이어 총알은 만들지 않는다.
##
## ▣ 씬에 넣는 법
##   scenes/페인트/칠하는발판.tscn 을 스테이지에 드래그 → 인스펙터에서
##   `재질`(벽돌/나무/바위/흙/풀…) 과 `크기_칸` 만 바꾸면 끝. 콜리전·그림·셰이더 자동 구성.
## ============================================================================
class_name PaintPlatform

const 최대_시드: int = 16         ## 셰이더 uniform 배열 크기(MAX_SEEDS)와 반드시 같아야 함
const INK_SHADER := preload("res://shaders/ink_spread.gdshader")
const 페인트진행_S := preload("res://scripts/페인트_진행.gd")

## ★[2026-07-25] 그림이 콜리전 밖으로 삐져나오는 여백(px). **크기와 무관하게 항상 일정**하다.
##
## ⚠ 왜 고쳤나 — 도형님이 지적한 "벽돌 옆 마스킹 테이프까지 같이 칠해진다" 의 진짜 원인.
##   예전엔 배율을 `크기 / 350(그림 내용물)` 로 잡았다. 그러면 384 셀의 투명 여백(17px)도
##   같은 배율로 커져서, **폭에 비례해 삐져나오는 양이 늘어난다**:
##     2칸(64px)  → 3px   ← 자연스러운 유기적 가장자리
##     8칸(256px) → 12.4px ← 콜리전 밖에 "칠해진 띠"가 따로 생긴 것처럼 보인다
##   → 이제는 항상 6px 만 삐져나온다. 어떤 크기의 발판이든 가장자리 느낌이 똑같다.
const 그림_여백: float = 6.0

## 색 상태
enum 상태 { 무색, 검정, 흰색, 회색 }

signal 칠해짐(플랫폼: PaintPlatform, 색: int)        ## 필요 횟수를 다 채워 색이 확정된 순간
signal 진행됨(플랫폼: PaintPlatform, 남은: int)      ## 맞았지만 아직 완성 전
signal 회색됨(플랫폼: PaintPlatform)                 ## 장애물 상호작용으로 회색화할 때 쓰는 예약 신호
signal 되돌려짐(플랫폼: PaintPlatform)               ## E 회수로 무색 복귀
## 모든 명중을 한 번에 받는 통합 시그널 — 이펙트(paint_fx.gd)가 이걸 구독한다.
## 결과 문자열 = progress / painted / wasted / blocked
signal 명중됨(플랫폼: PaintPlatform, 결과: String, 색: int, 월드좌표: Vector2)

# ── 인스펙터 설정 ──────────────────────────────────────────────────────────
@export_enum("벽돌", "벽돌액자", "나무", "나무액자", "바위", "흙", "풀", "풀두꺼움")
var 재질: String = "벽돌":
	set(v): 재질 = v; _다시_만들기()

## 플랫폼 크기 — "타일 몇 칸"(1칸 = 32px). 가로 8 × 세로 1 이 기본 발판.
@export var 크기_칸: Vector2i = Vector2i(8, 1):
	set(v):
		크기_칸 = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_다시_만들기()

## 시작 상태. 고정 지형을 만들고 싶으면 검정/흰색/회색으로 두면 칠할 수 없다.
@export var 시작상태: 상태 = 상태.무색:
	set(v): 시작상태 = v; _다시_만들기()

## 0 이면 크기에서 자동 계산. 개별 조정이 필요할 때만 값을 넣는다.
@export_range(0, 12) var 필요횟수_수동: int = 0:
	set(v): 필요횟수_수동 = v; _다시_만들기()

## 끄면 영원히 무색으로 남는 "장식/구조물" 이 된다 (총알은 튕겨나감).
@export var 칠하기_허용: bool = true

## ★★[2026-07-24 도형 · 중요] 무색 상태일 때 "밟을 수 없는 유령 지형"으로 둘 것인가.
##
## ▣ 왜 이 옵션이 생겼는가 — 문서 2건이 서로 반대로 적혀 있었다
##   · docs/레벨디자인_가이드.md §3 부품표 V1: **"무색 발판 = 칠해야만 밟을 수 있음"**
##   · docs/기획서_규칙_플로우차트.md 1-5: "무색(칠 가능) 발판 = 안전"
##   구현(zone_lab.gd)은 후자를 따르고 있었는데, 그러면 **색칠할 이유가 사라진다.**
##   무색이 이미 안전하다면 굳이 물감을 쓸 필요가 없고, "최대 색칠 횟수"(7/24 회의 결정)도
##   의미를 잃는다. 실제로 이 프로젝트에서 "왜 칠하는가"에 대한 답이 비어 있었다.
##
## ▣ 해결
##   레벨디자인 가이드(V1) 쪽을 코드로 구현하되, **끌 수 있는 옵션**으로 둔다.
##     true  = 유령 지형. 안 칠하면 통과해서 떨어진다. 칠하면 실체가 된다. → "칠할 이유"
##     false = 기존 규칙. 무색이어도 밟을 수 있는 안전한 징검다리.
##   덕분에 E 회수도 비로소 뜻이 생긴다 — 칠해서 만든 길을 **없애서 아래를 여는** 도구.
##   ⚠ 팀 확정 필요 항목. 어느 쪽이든 이 한 줄만 바꾸면 전 스테이지가 따라온다.
##
## ▣ 구현
##   유령 상태에서는 collision_layer 를 4번 레이어로 옮긴다.
##   · 플레이어(mask=1)는 통과   · 총알(mask=1|4)은 명중   · 조준 궤적(all)은 표시
@export var 무색일때_통과: bool = true:
	set(v): 무색일때_통과 = v; _충돌레이어_갱신(); queue_redraw()

## 유령(무색·통과) 상태에서 쓰는 물리 레이어 = **4번 레이어(비트마스크 8)**.
## 1~3번은 팀이 이미 쓰고 있을 수 있으므로 비워두고 4번을 새로 잡았다.
const 유령_레이어비트: int = 8

## ★표현 방식 비교용 (zone_04 vs zone_05).
##   0 = 셰이더 번짐  : 잉크가 셰이더 마스크로 유기적으로 퍼진다 (zone_04)
##   1 = VFX 스탬프  : 셰이더 마스크를 끄고, 물감 얼룩 스프라이트를 찍어 덮는다 (zone_05)
## 게임 규칙은 두 모드가 완전히 동일하다 — 오직 "보이는 방식"만 다르다.
var 표현_모드: int = 0

# ── 내부 상태 ──────────────────────────────────────────────────────────────
var 현재상태: 상태 = 상태.무색
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _진행 := 페인트진행_S.new()
var _시드: PackedVector2Array = PackedVector2Array()      # 로컬 UV(0~1)
var _시드반지름: PackedFloat32Array = PackedFloat32Array()
var _시드목표: PackedFloat32Array = PackedFloat32Array()
var _시드색: PackedInt32Array = PackedInt32Array()
var _시드세기: PackedFloat32Array = PackedFloat32Array()
var _젖음: float = 0.0
var _애니중: bool = false

var _스프라이트: Sprite2D
var _충돌: CollisionShape2D
var _재질정보: Dictionary = {}

# ── 조회 ───────────────────────────────────────────────────────────────────
## 월드 기준 **콜리전** 크기(px) — 밟는 면의 크기. 레벨 디자인의 기준값.
func 크기_px() -> Vector2:
	return Vector2(크기_칸) * float(TileArt.TILE)

## 월드 기준 **그림** 크기(px) — 콜리전보다 사방 `그림_여백` 만큼 크다.
## 셰이더의 UV·종횡비·9슬라이스는 전부 이 크기를 기준으로 계산해야
## 색칠 좌표와 그림이 어긋나지 않는다.
func 그림크기_px() -> Vector2:
	return 크기_px() + Vector2(그림_여백, 그림_여백) * 2.0

## 이 플랫폼을 칠하는 데 필요한 총 명중 횟수
func 필요횟수() -> int:
	if 필요횟수_수동 > 0:
		return 필요횟수_수동
	# 8칸 → 4번. 긴 변 기준이라 세로로 긴 기둥도 같은 감각으로 계산된다.
	return maxi(1, int(ceil(float(maxi(크기_칸.x, 크기_칸.y)) / 2.0)))

## 이 색으로 쏘면 앞으로 몇 발 더 필요한가. 칠할 수 없는 대상이면 -1.
func 남은횟수(색: int) -> int:
	if not 칠하기_허용 or 현재상태 != 상태.무색:
		return -1
	return _진행.남은횟수(색, 필요횟수())

## 지금 이 발판을 밟았을 때 죽는 색인가 (stage_lab 의 사망 판정이 사용)
func 반대색인가(플레이어색: int) -> bool:
	if 현재상태 == 상태.검정:
		return 플레이어색 == ColorDefs.WHITE
	if 현재상태 == 상태.흰색:
		return 플레이어색 == ColorDefs.BLACK
	return false        # 무색·회색은 누구에게나 안전

# ── 생성 ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("paint_platform")
	# 기본은 "가만히 있는 지형" — 움직이는 발판만 자식 클래스에서 true 로 켠다.
	sync_to_physics = false
	_다시_만들기()

func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	_재질정보 = TileArt.정보(재질)
	_그림_만들기()
	_충돌_만들기()
	# 시작 상태를 실제 상태로 반영 (고정 지형이면 처음부터 꽉 칠해진 모습)
	현재상태 = 시작상태
	_맞은횟수 = 0
	_진행.비우기()
	_시드 = PackedVector2Array()
	_시드반지름 = PackedFloat32Array()
	_시드목표 = PackedFloat32Array()
	_시드색 = PackedInt32Array()
	_시드세기 = PackedFloat32Array()
	if 현재상태 != 상태.무색:
		_전체칠하기_즉시()
	_유니폼_갱신()
	_충돌레이어_갱신()
	queue_redraw()

## 유령(무색·통과) 상태 표시 — 점선 테두리로 "여기 발판이 생길 수 있다"를 알린다.
## 반투명만으로는 배경과 헷갈리므로 형태(점선)로도 구분한다(가독성 규칙 §5).
func _draw() -> void:
	if not 밟을_수_있나():
		var 크기 := 크기_px()
		var 모서리 := [
			Vector2(-크기.x, -크기.y) * 0.5, Vector2(크기.x, -크기.y) * 0.5,
			Vector2(크기.x, 크기.y) * 0.5, Vector2(-크기.x, 크기.y) * 0.5]
		for i in 4:
			var a: Vector2 = 모서리[i]
			var b: Vector2 = 모서리[(i + 1) % 4]
			var 길이 := a.distance_to(b)
			var 칸 := maxi(int(길이 / 12.0), 1)
			for k in 칸:
				if k % 2 == 1:
					continue
				var t0 := float(k) / float(칸)
				var t1 := float(k + 1) / float(칸)
				draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(0.05, 0.05, 0.05, 0.85), 3.0)
				draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(0.95, 0.95, 0.95, 0.85), 1.4)

func _그림_만들기() -> void:
	if _스프라이트 == null:
		_스프라이트 = get_node_or_null("그림") as Sprite2D
	if _스프라이트 == null:
		_스프라이트 = Sprite2D.new()
		_스프라이트.name = "그림"
		add_child(_스프라이트)
		if Engine.is_editor_hint() and get_tree() != null:
			_스프라이트.owner = get_tree().edited_scene_root

	var 흑: Rect2 = _재질정보["black"]
	_스프라이트.texture = load(_재질정보["sheet"])
	_스프라이트.region_enabled = true
	_스프라이트.region_rect = 흑                  # 셰이더가 이 UV 범위를 기준으로 로컬좌표 복원
	_스프라이트.centered = true
	# ★[2026-07-25] 셀(384) 전체가 "콜리전 + 사방 6px" 에 정확히 들어가도록 배율을 잡는다.
	#   → 삐져나오는 유기적 가장자리가 **플랫폼 크기와 무관하게 항상 6px** 로 일정하다.
	_스프라이트.scale = 그림크기_px() / TileArt.CELL_PX

	var mat := _스프라이트.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = INK_SHADER
		_스프라이트.material = mat

func _충돌_만들기() -> void:
	if _충돌 == null:
		_충돌 = get_node_or_null("충돌") as CollisionShape2D
	if _충돌 == null:
		_충돌 = CollisionShape2D.new()
		_충돌.name = "충돌"
		add_child(_충돌)
		if Engine.is_editor_hint() and get_tree() != null:
			_충돌.owner = get_tree().edited_scene_root
	var shape := _충돌.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		_충돌.shape = shape
	shape.size = 크기_px()
	collision_mask = 0
	_충돌레이어_갱신()

## 상태에 따라 물리 레이어를 고른다.
##   실체(칠해짐·회색·고정색) = 레이어 1 (기존 타일맵 지형과 동일 → 팀 코드 무수정)
##   유령(무색 + 무색일때_통과) = 레이어 4 (총알만 감지)
func _충돌레이어_갱신() -> void:
	var 유령 := (현재상태 == 상태.무색) and 무색일때_통과 and 칠하기_허용
	var 새레이어 := 유령_레이어비트 if 유령 else 1
	if collision_layer != 새레이어:
		# 물리 프레임 밖에서 바꾸면 경고가 뜨므로 deferred 로 넘긴다
		set_deferred("collision_layer", 새레이어)
	if _스프라이트:
		# 유령은 반투명 — "아직 실체가 아니다"를 한눈에
		_스프라이트.modulate.a = 0.42 if 유령 else 1.0

## 지금 밟을 수 있는 상태인가 (레벨 검증·자동 테스트용)
func 밟을_수_있나() -> bool:
	return not ((현재상태 == 상태.무색) and 무색일때_통과 and 칠하기_허용)

# ── 색칠 처리 ──────────────────────────────────────────────────────────────
## 총알이 명중했을 때 호출. 반환값은 paint_system v2 와 같은 문자열 체계를 따른다.
##   progress / painted / wasted / blocked
func 명중(색: int, 월드좌표: Vector2) -> String:
	var 결과 := _명중_처리(색, 월드좌표)
	# 이펙트(스플래시·물감 흐름·카메라 킥)는 전부 이 통합 시그널 하나만 구독한다.
	명중됨.emit(self, 결과, 색, 월드좌표)
	return 결과

func _명중_처리(색: int, 월드좌표: Vector2) -> String:
	if not 칠하기_허용:
		return "blocked"
	var uv := _월드_to_uv(월드좌표)

	match 현재상태:
		상태.회색:
			return "blocked"                     # 장애물 상호작용으로 생긴 회색은 총알로 못 덮는다.
		상태.검정, 상태.흰색:
			var 내색 := ColorDefs.BLACK if 현재상태 == 상태.검정 else ColorDefs.WHITE
			if 색 == 내색:
				return "wasted"                  # 같은 색 덧칠 = 낭비
			# 완성된 플랫폼에는 마지막 플레이어 색을 바로 덮고 회색을 만들지 않는다.
			현재상태 = 상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색
			_전체칠하기_즉시()
			_젖음 = 1.0
			_애니시작()
			_충돌레이어_갱신()
			칠해짐.emit(self, 색)
			return "painted"
		_:
			# ── 무색: 진행 누적 ──
			_진행색 = 색
			_진행.명중(색, 필요횟수())
			_맞은횟수 = maxi(_진행.횟수(ColorDefs.BLACK), _진행.횟수(ColorDefs.WHITE))
			_시드_추가(uv, 색)
			_젖음 = 1.0
			_애니시작()
			if _진행.완성가능(색, 필요횟수()):
				현재상태 = 상태.검정 if 색 == ColorDefs.BLACK else 상태.흰색
				_전체칠하기_즉시()
				_충돌레이어_갱신()               # ★유령 → 실체 (이제 밟을 수 있다)
				queue_redraw()
				칠해짐.emit(self, 색)
				return "painted"
			_목표반지름_갱신(false)
			진행됨.emit(self, 필요횟수() - _맞은횟수)
			return "progress"

## E 회수 — 무색으로 되돌린다. 회색은 되돌릴 수 없다(호출해도 false).
func 되돌리기() -> bool:
	if 현재상태 == 상태.회색 or not 칠하기_허용:
		return false
	현재상태 = 상태.무색
	_맞은횟수 = 0
	_진행.비우기()
	_시드 = PackedVector2Array()
	_시드반지름 = PackedFloat32Array()
	_시드목표 = PackedFloat32Array()
	_시드색 = PackedInt32Array()
	_시드세기 = PackedFloat32Array()
	_젖음 = 0.0
	_유니폼_갱신()
	_충돌레이어_갱신()                          # ★실체 → 유령 (발판이 사라져 아래가 열린다)
	queue_redraw()
	되돌려짐.emit(self)
	return true

func _회색으로() -> void:
	현재상태 = 상태.회색
	_전체칠하기_즉시()
	_젖음 = 1.0
	_애니시작()
	_충돌레이어_갱신()                          # 회색도 실체 — 밟을 수는 있지만 다시 못 칠한다
	queue_redraw()

## 시작상태/회색화처럼 "이미 꽉 칠해진" 모습으로 즉시 세팅
func _전체칠하기_즉시() -> void:
	_진행.비우기()
	_시드 = PackedVector2Array([Vector2(0.5, 0.5)])
	var r := _최대반지름()
	_시드반지름 = PackedFloat32Array([r])
	_시드목표 = PackedFloat32Array([r])
	_맞은횟수 = 필요횟수()
	match 현재상태:
		상태.검정: _진행색 = ColorDefs.BLACK
		상태.흰색: _진행색 = ColorDefs.WHITE
		_:         _진행색 = ColorDefs.BLACK      # 회색은 셰이더 locked 로 덮이므로 아무 색이나
	_시드색 = PackedInt32Array([_진행색])
	_시드세기 = PackedFloat32Array([1.0])

## 명중 지점을 씨앗으로 등록.
## [2026-07-25] 물감 얼룩 프로파일(표현_모드 1)에서는 **한 번 명중에 씨앗 3개**를
## 살짝 흩어 심는다 → 원 하나가 커지는 게 아니라 "물감이 튀어 뭉친" 덩어리가 된다.
## (얼룩 스프라이트를 따로 찍던 구 방식과 달리, 씨앗은 셰이더 마스크 안에 있으므로
##  실루엣을 절대 벗어나지 않고 진행률 100% 에서 반드시 전부 덮인다)
func _시드_추가(uv: Vector2, 색: int) -> void:
	var 개수 := 3 if 표현_모드 == 1 else 1
	for i in 개수:
		var p := uv
		if 개수 > 1:
			var a := randf() * TAU
			var r := randf_range(0.04, 0.11)
			# x 는 종횡비로 눌러야 화면상에서 등방(동그랗게)으로 흩어진다
			p = Vector2(clampf(uv.x + cos(a) * r / maxf(_종횡비(), 0.001), 0.0, 1.0),
				clampf(uv.y + sin(a) * r, 0.0, 1.0))
		if _시드.size() >= 최대_시드:
			# 씨앗이 꽉 차면 가장 오래된 것을 밀어낸다 (셰이더 배열 한도)
			_시드.remove_at(0)
			_시드반지름.remove_at(0)
			_시드목표.remove_at(0)
			_시드색.remove_at(0)
			_시드세기.remove_at(0)
		_시드.append(p)
		_시드반지름.append(0.0)
		_시드목표.append(0.0)
		_시드색.append(색)
		_시드세기.append(1.0)

## 화면 대각선(가로세로 보정 단위) — 이 반지름이면 플랫폼 전체가 덮인다.
func _최대반지름() -> float:
	var a := _종횡비()
	return sqrt(a * a + 1.0) + 0.05

func _종횡비() -> float:
	var s := 그림크기_px()          # 셰이더가 보는 것은 그림 크기다 (콜리전이 아니라)
	return maxf(s.x, 1.0) / maxf(s.y, 1.0)

## 지금까지 맞은 횟수에 맞춰 각 시드의 목표 반지름을 다시 계산한다.
##   · 초반에는 "면적 비례 원"(원 넓이 = 진행률 × 플랫폼 넓이) → 조금씩 스며드는 느낌
##   · 마지막 한 방에서는 전체 반지름으로 확 튀어 "완성됐다"는 쾌감을 준다
func _목표반지름_갱신(완성: bool) -> void:
	var n := _시드.size()
	if n == 0:
		return
	var 총 := maxi(필요횟수(), 1)
	var 진행 := clampf(float(_맞은횟수) / float(총), 0.0, 1.0)
	var a := _종횡비()
	var 면적반지름 := sqrt(maxf(진행, 0.0001) * a / PI) / sqrt(float(n))
	var 목표 := 면적반지름
	if 완성:
		목표 = _최대반지름()
	else:
		# 진행이 뒤로 갈수록 원이 서로 이어지도록 가속.
		# ⚠[2026-07-24 튜닝] 지수 3.0 은 60% 진행에서 이미 꽉 찬 것처럼 보였다(zone_04
		#   스크린샷의 벽에서 확인 — 5발 중 3발인데 완성처럼 보임). 5.0 으로 올려
		#   "마지막 한 발에서 확 덮이는" 쾌감을 남긴다.
		목표 = lerpf(면적반지름, _최대반지름(), pow(진행, 5.0))
	for i in n:
		_시드목표[i] = 목표

func _애니시작() -> void:
	_애니중 = true
	set_process(true)

# ── 번짐 애니메이션 (CPU) ──────────────────────────────────────────────────
## GPU TIME 이 아니라 CPU 에서 굴리는 이유: 저장/되돌리기/자동테스트에서
## "지금 몇 % 번졌는가"를 정확히 알아야 하고, 일시정지(히트스톱)와도 맞물려야 하기 때문.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	if not _애니중:
		set_process(false)
		return
	var 남음 := false
	for i in _시드반지름.size():
		var r := _시드반지름[i]
		var t := _시드목표[i]
		if absf(t - r) > 0.002:
			# 지수 감쇠 보간 = 처음엔 빠르게 퍼지고 끝에서 살짝 붙는 잉크 느낌
			_시드반지름[i] = lerpf(r, t, 1.0 - pow(0.0008, delta))
			남음 = true
		else:
			_시드반지름[i] = t
	if _젖음 > 0.0:
		_젖음 = maxf(_젖음 - delta * 1.25, 0.0)     # 약 0.8초에 걸쳐 마른다
		남음 = true
	if 현재상태 == 상태.무색 and _진행.전체횟수() > 0:
		var 변화: Dictionary = _진행.진행(delta, 필요횟수())
		for i in _시드세기.size():
			_시드세기[i] = _진행.알파(_시드색[i])
		for 만료색 in 변화["만료"]:
			_색_시드_지우기(int(만료색))
		_맞은횟수 = maxi(_진행.횟수(ColorDefs.BLACK), _진행.횟수(ColorDefs.WHITE))
		var 완성색: int = 변화["완성색"]
		if 완성색 >= 0:
			현재상태 = 상태.검정 if 완성색 == ColorDefs.BLACK else 상태.흰색
			_전체칠하기_즉시()
			_충돌레이어_갱신()
			칠해짐.emit(self, 완성색)
		남음 = _진행.전체횟수() > 0
	_유니폼_갱신()
	_애니중 = 남음


func _색_시드_지우기(색: int) -> void:
	# 반대색 진행은 유지해야 하므로 만료된 색에 속한 얼룩만 제거한다.
	for i in range(_시드색.size() - 1, -1, -1):
		if _시드색[i] != 색:
			continue
		_시드.remove_at(i)
		_시드반지름.remove_at(i)
		_시드목표.remove_at(i)
		_시드색.remove_at(i)
		_시드세기.remove_at(i)

# ── 셰이더 유니폼 동기화 ───────────────────────────────────────────────────
func _유니폼_갱신() -> void:
	if _스프라이트 == null:
		return
	var mat := _스프라이트.material as ShaderMaterial
	if mat == null:
		return
	var 크기 := 그림크기_px()        # ★[2026-07-25] 셰이더 기준은 그림 크기 (콜리전 아님)
	var 시트크기: Vector2 = _재질정보.get("sheet_size", Vector2(768, 384))

	# 셰이더 배열은 길이가 고정(최대_시드)이라 남는 칸은 0 으로 채워 보낸다.
	var 시드8 := PackedVector2Array()
	var 반지름8 := PackedFloat32Array()
	var 색8 := PackedInt32Array()
	var 세기8 := PackedFloat32Array()
	for i in 최대_시드:
		시드8.append(_시드[i] if i < _시드.size() else Vector2.ZERO)
		반지름8.append(_시드반지름[i] if i < _시드반지름.size() else 0.0)
		색8.append(_시드색[i] if i < _시드색.size() else ColorDefs.BLACK)
		세기8.append(_시드세기[i] if i < _시드세기.size() else 0.0)

	# ★[2026-07-25] 표현 모드 = **같은 마스크의 프로파일 전환**으로 바뀌었다.
	#   (구 방식: 얼룩 스프라이트를 따로 찍음 → 실루엣 밖으로 새고 덮임이 안 보장됨)
	var 얼룩 := 표현_모드 == 1

	mat.set_shader_parameter("sheet", _스프라이트.texture)
	mat.set_shader_parameter("uv_black", TileArt.uv_rect(_재질정보["black"], 시트크기))
	mat.set_shader_parameter("uv_white", TileArt.uv_rect(_재질정보["white"], 시트크기))
	mat.set_shader_parameter("node_size", 크기)
	mat.set_shader_parameter("cell_px", Vector2(TileArt.CELL_PX, TileArt.CELL_PX))
	# ⚠[2026-07-24 튜닝] 원본 테두리(약 50px)를 32px 짜리 얇은 발판에 그대로 쓰면
	#   화면의 45% 가 "뜯긴 가장자리"로 채워져 뭉개진 얼룩처럼 보인다(스크린샷 확인).
	#   → 얇은 발판에서는 테두리를 비례해서 줄여 가운데 무늬가 살아나게 한다.
	var 테두리: float = _재질정보.get("border_px", 50.0)
	테두리 = minf(테두리, minf(크기.x, 크기.y) * 1.2)
	mat.set_shader_parameter("border_px", 테두리)
	mat.set_shader_parameter("tile_middle", _재질정보.get("tile_middle", true))
	mat.set_shader_parameter("paint_color", 0 if _진행색 == ColorDefs.BLACK else 1)
	mat.set_shader_parameter("seeds", 시드8)
	mat.set_shader_parameter("seed_r", 반지름8)
	mat.set_shader_parameter("seed_c", 색8)
	mat.set_shader_parameter("seed_a", 세기8)
	mat.set_shader_parameter("seed_count", _시드.size())
	mat.set_shader_parameter("locked", 1.0 if 현재상태 == 상태.회색 else 0.0)
	mat.set_shader_parameter("wet_amount", _젖음)
	mat.set_shader_parameter("aspect", _종횡비())
	# ── 프로파일: 0 = 스며듦(zone_04) / 1 = 물감 얼룩(zone_05) ──
	mat.set_shader_parameter("profile", 1 if 얼룩 else 0)
	mat.set_shader_parameter("noise_amount", 0.19 if 얼룩 else 0.13)
	mat.set_shader_parameter("noise_scale", 4.4 if 얼룩 else 3.2)
	mat.set_shader_parameter("blob_amount", 0.26 if 얼룩 else 0.0)
	mat.set_shader_parameter("edge_soft", 0.010 if 얼룩 else 0.035)

# ── 좌표 변환 ──────────────────────────────────────────────────────────────
## 월드 좌표 → 이 플랫폼 로컬 UV(0~1). 셰이더의 시드 좌표계와 동일해야 한다.
func _월드_to_uv(월드: Vector2) -> Vector2:
	var 로컬 := to_local(월드)
	var 크기 := 그림크기_px()        # ★셰이더 로컬 좌표계와 동일해야 씨앗이 어긋나지 않는다
	return Vector2(
		clampf(로컬.x / maxf(크기.x, 1.0) + 0.5, 0.0, 1.0),
		clampf(로컬.y / maxf(크기.y, 1.0) + 0.5, 0.0, 1.0)
	)

## 이 플랫폼의 윗면 y (월드) — 레벨 배치·물감 흐름 시작점 계산용
func 윗면_y() -> float:
	return global_position.y - 크기_px().y * 0.5
