extends Node
## ============================================================================
## 2층방 전용 — 서로 맞닿은 SS2D 사이의 연결 페인트
## ----------------------------------------------------------------------------
## 일반 SS2D는 자기 로컬 시드만 셰이더에 보내므로, 벽돌 안에서 커진 번짐 전선이
## 나중에 나무와 만나도 그 자리에서 끊긴다. 이 노드는 2층방에서 칠할 수 있는 SS2D를
## 찾아 서로 맞닿은 것끼리 묶고, 같은 묶음의 **실제 시드**를 월드 좌표로 매 프레임
## 공유한다. 재질 텍스처는 각 SS2D 것이 그대로고 페인트 마스크만 공유하므로,
## 경계에서는 한 덩어리의 물감처럼 이어진다. 공중에 떨어진 물체에는 건너뛰지 않는다.
##
## 이 스크립트는 `스테이지_1_2층방.tscn`의 전용 노드에만 붙는다. 다른 스테이지에는
## 노드가 없으므로 기존 페인트 규칙과 화면을 전혀 바꾸지 않는다.
## ============================================================================

const 최대_시드: int = 24                 ## 지형_페인트.gdshader의 MAX_SEEDS와 같아야 한다

@export_node_path("Node2D") var 지형_루트_경로: NodePath
## SS2D 콜리전 외곽 사이가 이 거리 이하면 맞닿은 한 표면으로 본다.
## 현재 2층방의 BRICK·WOOD 외곽은 메시 굽기 오차 때문에 약 2~6px 겹치거나 벌어진다.
@export_range(0.0, 24.0, 1.0) var 접촉_여유_px: float = 10.0

@export_group("한 발 페인트 양")
## 2층방 시험값. 한 발이 빈 공간에서 칠하는 평균 면적은 `PI × 160² ≈ 80,425px²`다.
## 총알 총량이 확정되면 이 값 하나만 조절하면 필요 발수도 함께 다시 계산된다.
@export_range(64.0, 320.0, 1.0) var 기준_월드반지름: float = 160.0
## 사용자가 허용한 **면적** 편차. 반지름 편차로 그대로 쓰면 면적 오차가 제곱으로
## 커지므로, 실제 반지름에는 `sqrt(면적계수)`를 곱한다.
@export_range(0.0, 0.2, 0.01) var 한발_면적오차: float = 0.2

@export_group("유기적인 얼룩 모양")
## 큰 SS2D에서 기존 반지름 비례 흔들림을 쓰면 수백 px짜리 못 모양이 생긴다.
## 기존 물결은 끄고, 셰이더의 면적 보존 타원과 3·5·7각 곡선 굴곡을 따로 쓴다.
@export_range(0.0, 0.05, 0.001) var 큰물결_비율: float = 0.0
## 완벽한 원을 깨되 뾰족해지지 않도록 여러 각을 사인 곡선으로 둥글게 연결한다.
@export_range(0.0, 0.2, 0.005) var 둥근각_굴곡: float = 0.145
## x·y 축을 서로 역비례로 늘려 면적은 유지하면서 탄마다 방향이 다른 비대칭을 만든다.
@export_range(0.0, 0.25, 0.01) var 비대칭_비율: float = 0.18
@export_range(0.0, 8.0, 0.5) var 잔물결_px: float = 4.0
@export_range(0.0, 8.0, 0.5) var 가장자리_부드러움_px: float = 2.5
@export_range(0.04, 0.2, 0.005) var 물줄기_굵기: float = 0.16

@export_group("흐름과 자동 회수")
## 약 4초 동안 길고 짧은 줄기가 자란 다음, 1.4초 동안 증발하며 탄약으로 돌아온다.
@export_range(40.0, 180.0, 1.0) var 흘러내림_최대길이: float = 132.0
@export_range(10.0, 100.0, 1.0) var 흘러내림_속도: float = 34.0
@export_range(1.0, 8.0, 0.1) var 부분_유지시간: float = 4.4
@export_range(0.5, 3.0, 0.1) var 부분_증발시간: float = 1.4

var _지형들: Array[Node2D] = []
var _연결묶음: Dictionary = {}             ## instance_id → 같은 접촉면의 Array[Node2D]


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	# 스마트지형이 자기 유니폼을 먼저 갱신한 뒤 마지막에 두 표면을 합쳐야 한다.
	# 순서가 반대면 다음 지형 처리에서 공유 시드가 한 프레임 만에 덮어써진다.
	process_priority = 100
	set_process(false)
	call_deferred("_연결_준비")


func _연결_준비() -> void:
	# 내보낸 경로는 관리 노드가 아니라 2층방 루트를 기준으로 적는다.
	var 무대 := get_parent()
	var 지형루트 := 무대.get_node_or_null(지형_루트_경로)
	if 지형루트 == null:
		push_warning("2층방 연결페인트: 지형 루트를 찾지 못함 (%s)" % 지형_루트_경로)
		return
	_지형들.clear()
	for 자식 in 지형루트.get_children():
		var 지형 := 자식 as Node2D
		if _유효한_지형(지형) and bool(지형.get("칠하기_허용")):
			_지형들.append(지형)
	if _지형들.is_empty():
		push_warning("2층방 연결페인트: 칠할 수 있는 SS2D가 없음")
		return
	# 가장 작은 허용량(-20%)의 총알만 연속으로 나와도 지형 면적을 채울 수 있는
	# 보수적인 발수를 쓴다. 그래서 큰 땅은 6~10발 탄창으로 완성할 수 없다.
	for 지형 in _지형들:
		_지형_흐름과수명_설정(지형)
		지형.set("필요횟수_수동", 계산_필요횟수(지형))
	_접촉묶음_계산()
	set_process(true)
	_모든표면_갱신()


func _process(_delta: float) -> void:
	if _지형들.is_empty():
		set_process(false)
		return
	_모든표면_갱신()


## 테스트가 프레임 순서에 기대지 않고 동일한 동기화를 직접 확인할 때도 사용한다.
func 즉시_갱신() -> void:
	if not _지형들.is_empty():
		_모든표면_갱신()


## 자동 검사와 디버그에서 두 SS2D가 실제로 같은 접촉면으로 묶였는지 확인한다.
func 같은_연결면인가(a: Node, b: Node) -> bool:
	if a == null or b == null or not _연결묶음.has(a.get_instance_id()):
		return false
	return (_연결묶음[a.get_instance_id()] as Array).has(b)


func _모든표면_갱신() -> void:
	# 스마트지형의 기본 공식은 지형 면적에 따라 시드 목표를 다시 키운다. 먼저 그것을
	# 동일한 월드 면적으로 정규화한 뒤 접촉면끼리 공유해야 출발 지형에 따른 차이가 없다.
	for 지형 in _지형들:
		if is_instance_valid(지형):
			_한발_면적_정규화(지형)
	for 대상 in _지형들:
		if not is_instance_valid(대상):
			continue
		var 묶음: Array = _연결묶음.get(대상.get_instance_id(), [대상]).duplicate()
		# 이웃 시드를 먼저, 자기 시드를 나중에 넣는다. 둘이 다른 색이면 직접 맞은
		# 자기 표면의 최신 색이 마지막에 그려져 플레이어 입력을 우선한다.
		묶음.erase(대상)
		묶음.append(대상)
		_대상_유니폼_갱신(대상, 묶음)


## 지형 실면적을 한 발의 최소 허용 면적(기준의 80%)으로 나눈다.
## `ceil`을 쓰므로 오차 범위에서 가장 작은 얼룩들만 나와도 완료 발수가 부족하지 않다.
func 계산_필요횟수(지형: Node) -> int:
	if not _유효한_지형(지형):
		return 1
	var 기준면적 := PI * 기준_월드반지름 * 기준_월드반지름
	var 최소한발 := 기준면적 * (1.0 - 한발_면적오차)
	return maxi(int(ceil(float(지형.get("_면적")) / maxf(최소한발, 1.0))), 1)


## 공용 지형의 규칙을 바꾸지 않고, 2층방에 놓인 실제 인스턴스만 천천히 흐르고
## 증발하도록 맞춘다. `_진행`은 ready 때 값을 복사하므로 함께 갱신해야 한다.
func _지형_흐름과수명_설정(지형: Node2D) -> void:
	지형.set("흘러내림_길이", 흘러내림_최대길이)
	지형.set("흘러내림_속도", 흘러내림_속도)
	지형.set("부분_유지시간", 부분_유지시간)
	지형.set("부분_감쇠시간", 부분_증발시간)
	var 진행상태: Object = 지형.get("_진행")
	if 진행상태 != null:
		진행상태.set("유지시간", 부분_유지시간)
		진행상태.set("감쇠시간", 부분_증발시간)


## 부분칠 상태의 모든 실제 시드를 동일한 월드 면적 범위로 고정한다.
## 완료된 지형은 마지막 전체칠 전선이 끝까지 커져야 하므로 건드리지 않는다.
func _한발_면적_정규화(지형: Node2D) -> void:
	if int(지형.call("현재색")) != -1:
		return
	var 시드들: PackedVector2Array = 지형.get("_시드")
	var 목표들: PackedFloat32Array = 지형.get("_목표")
	var 현재들: PackedFloat32Array = 지형.get("_반지름")
	var 색들: PackedInt32Array = 지형.get("_색")
	var 수 := mini(시드들.size(), 목표들.size())
	for i in 수:
		var 월드중심 := 지형.to_global(시드들[i])
		var 색 := 색들[i] if i < 색들.size() else ColorDefs.BLACK
		var 면적계수 := _한발_면적계수(월드중심, 색)
		# 원 넓이는 반지름의 제곱이므로 sqrt를 써야 결과 면적이 정확히 ±20% 안이다.
		var 월드반지름 := 기준_월드반지름 * sqrt(면적계수)
		var 로컬반지름 := _월드길이_대상으로(지형, 월드중심, 월드반지름)
		목표들[i] = 로컬반지름
		# 명중 직후 기본 면적 공식으로 한 프레임 먼저 커졌어도 허용량 밖으로 못 나가게 한다.
		if i < 현재들.size():
			현재들[i] = minf(현재들[i], 로컬반지름)
	지형.set("_목표", 목표들)
	지형.set("_반지름", 현재들)


## 위치와 색으로 만든 결정적 오차. 같은 명중은 실행할 때마다 같은 양이 나와
## 테스트와 플레이 감각이 흔들리지 않으면서도 모든 발이 기계적으로 같아 보이지 않는다.
func _한발_면적계수(월드중심: Vector2, 색: int) -> float:
	var 영일 := _결정적_영일(월드중심, 색, 0.0)
	return lerpf(1.0 - 한발_면적오차, 1.0 + 한발_면적오차, 영일)


## 위치·색·용도 소금값으로 0~1 변형값을 만든다. 시간 난수가 아니어서 물줄기가
## 프레임마다 떨리지 않고, 같은 시드가 BRICK·WOOD 경계를 넘어가도 같은 모양을 유지한다.
func _결정적_영일(월드중심: Vector2, 색: int, 소금: float) -> float:
	var 섞임 := sin(월드중심.x * 12.9898 + 월드중심.y * 78.233
		+ float(색) * 37.719 + 소금 * 19.193)
	return fposmod(섞임 * 43758.5453, 1.0)


## 2층방의 정적인 SS2D 외곽을 한 번 비교해 접촉 그래프의 연결 요소를 만든다.
## 매 프레임 물리 질의를 하지 않아도 되므로 지형 수가 늘어도 런타임 비용은 시드 복사뿐이다.
func _접촉묶음_계산() -> void:
	_연결묶음.clear()
	var 방문함: Dictionary = {}
	for 시작 in _지형들:
		var 시작id := 시작.get_instance_id()
		if 방문함.has(시작id):
			continue
		var 묶음: Array[Node2D] = []
		var 대기: Array[Node2D] = [시작]
		방문함[시작id] = true
		while not 대기.is_empty():
			var 현재 := 대기.pop_front() as Node2D
			묶음.append(현재)
			for 후보 in _지형들:
				var 후보id := 후보.get_instance_id()
				if 방문함.has(후보id) or not _서로_맞닿나(현재, 후보):
					continue
				방문함[후보id] = true
				대기.append(후보)
		for 지형 in 묶음:
			_연결묶음[지형.get_instance_id()] = 묶음


func _서로_맞닿나(a: Node2D, b: Node2D) -> bool:
	var ap := _월드외곽(a)
	var bp := _월드외곽(b)
	if ap.size() < 3 or bp.size() < 3:
		return false
	var ar := _점들_AABB(ap).grow(접촉_여유_px)
	var br := _점들_AABB(bp).grow(접촉_여유_px)
	if not ar.intersects(br, true):
		return false
	# 겹쳐 들어간 배치는 꼭짓점 포함 검사로 즉시 잡는다.
	if Geometry2D.is_point_in_polygon(ap[0], bp) or Geometry2D.is_point_in_polygon(bp[0], ap):
		return true
	# 맞닿았지만 꼭짓점이 상대 내부에 없는 경우를 위해 점→모든 변 최단거리를 본다.
	return _점과외곽_거리안(ap, bp, 접촉_여유_px) \
		or _점과외곽_거리안(bp, ap, 접촉_여유_px)


func _월드외곽(지형: Node2D) -> PackedVector2Array:
	var 로컬점: PackedVector2Array = 지형.call("get_point_array").get_tessellated_points()
	var 월드점 := PackedVector2Array()
	for 점 in 로컬점:
		월드점.append(지형.to_global(점))
	return 월드점


func _점들_AABB(점들: PackedVector2Array) -> Rect2:
	var 사각 := Rect2(점들[0], Vector2.ZERO)
	for 점 in 점들:
		사각 = 사각.expand(점)
	return 사각


func _점과외곽_거리안(점들: PackedVector2Array, 외곽: PackedVector2Array, 한계: float) -> bool:
	for 점 in 점들:
		for i in 외곽.size():
			var a := 외곽[i]
			var b := 외곽[(i + 1) % 외곽.size()]
			if 점.distance_to(Geometry2D.get_closest_point_to_segment(점, a, b)) <= 한계:
				return true
	return false


func _대상_유니폼_갱신(대상: Node2D, 출처들: Array) -> void:
	var 항목들: Array[Dictionary] = []
	var 젖음 := 0.0
	for 출처 in 출처들:
		if not _유효한_지형(출처):
			continue
		젖음 = maxf(젖음, float(출처.get("_젖음")))
		_실제시드_모으기(출처, 대상, 항목들)

	# 슬롯이 모자라면 오래된 이웃 시드부터 버리고, 배열 뒤쪽의 자기 최신 시드를 남긴다.
	var 시작 := maxi(항목들.size() - 최대_시드, 0)
	var 위치 := PackedVector2Array()
	var 반지름 := PackedFloat32Array()
	var 세기 := PackedFloat32Array()
	var 색 := PackedInt32Array()
	var 흘러내림 := PackedFloat32Array()
	var 변형 := PackedFloat32Array()
	for i in range(시작, 항목들.size()):
		var 항목: Dictionary = 항목들[i]
		위치.append(항목["위치"])
		반지름.append(float(항목["반지름"]))
		세기.append(float(항목["세기"]))
		색.append(int(항목["색"]))
		흘러내림.append(float(항목["흘러내림"]))
		변형.append(float(항목["변형"]))
	var 보낼수 := 위치.size()
	while 위치.size() < 최대_시드:
		위치.append(Vector2.ZERO)
		반지름.append(0.0)
		세기.append(0.0)
		색.append(0)
		흘러내림.append(0.0)
		변형.append(0.0)

	# ★[2026-08-30] 화면에 그리는 얼룩 목록을 **판정에도 그대로** 넘긴다.
	#   이걸 안 하면 나무를 칠했을 때 옆 벽돌이 하얗게 보이는데 판정은 무색으로 남아
	#   "하얀 바닥인데 검정으로 밟아도 안 죽는" 상태가 된다(실측으로 확인된 구멍).
	var 판정용: Array[Dictionary] = []
	for i in range(시작, 항목들.size()):
		판정용.append(항목들[i])
	대상.set("위치별_판정", true)
	대상.call("판정시드_설정", 판정용, 둥근각_굴곡, 비대칭_비율)

	var 재질들: Array = 대상.get("_셰이더들")
	for 값 in 재질들:
		var 재질 := 값 as ShaderMaterial
		if 재질 == null:
			continue
		재질.set_shader_parameter("seed_count", 보낼수)
		재질.set_shader_parameter("seeds", 위치)
		재질.set_shader_parameter("seed_r", 반지름)
		재질.set_shader_parameter("seed_a", 세기)
		재질.set_shader_parameter("seed_c", 색)
		재질.set_shader_parameter("seed_d", 흘러내림)
		재질.set_shader_parameter("seed_v", 변형)
		재질.set_shader_parameter("wet", 젖음)
		# 기존의 거대 돌출은 끄고, 2층방에서만 둥근 각·비대칭·다양한 물줄기를 켠다.
		재질.set_shader_parameter("blob_wobble", 큰물결_비율)
		재질.set_shader_parameter("organic_mode", true)
		재질.set_shader_parameter("organic_shape", 둥근각_굴곡)
		재질.set_shader_parameter("organic_aspect", 비대칭_비율)
		재질.set_shader_parameter("noise_amount", 잔물결_px)
		재질.set_shader_parameter("edge_soft", 가장자리_부드러움_px)
		재질.set_shader_parameter("drip_width", 물줄기_굵기)


func _실제시드_모으기(출처: Node2D, 대상: Node2D, 받을곳: Array[Dictionary]) -> void:
	var 위치들: PackedVector2Array = 출처.get("_시드")
	var 반지름들: PackedFloat32Array = 출처.get("_반지름")
	var 세기들: PackedFloat32Array = 출처.get("_세기")
	var 색들: PackedInt32Array = 출처.get("_색")
	var 흐름들: PackedFloat32Array = 출처.get("_흘러내림")
	var 수 := mini(위치들.size(), 반지름들.size())
	for i in 수:
		var 출처로컬 := 위치들[i]
		var 월드중심 := 출처.to_global(출처로컬)
		var 월드반지름 := _출처길이_월드로(출처, 출처로컬, 반지름들[i])
		var 대상중심 := 대상.to_local(월드중심)
		var 월드흐름 := _출처길이_월드로(출처, 출처로컬,
			흐름들[i] if i < 흐름들.size() else 0.0)
		받을곳.append({
			"위치": 대상중심,
			"반지름": _월드길이_대상으로(대상, 월드중심, 월드반지름),
			"세기": 세기들[i] if i < 세기들.size() else 1.0,
			"색": 색들[i] if i < 색들.size() else ColorDefs.BLACK,
			"흘러내림": _월드길이_대상으로(대상, 월드중심, 월드흐름),
			"변형": _결정적_영일(월드중심,
				색들[i] if i < 색들.size() else ColorDefs.BLACK, 11.73),
		})


func _출처길이_월드로(출처: Node2D, 중심: Vector2, 길이: float) -> float:
	if 길이 <= 0.0:
		return 0.0
	var 월드중심 := 출처.to_global(중심)
	var x길이 := 월드중심.distance_to(출처.to_global(중심 + Vector2(길이, 0.0)))
	var y길이 := 월드중심.distance_to(출처.to_global(중심 + Vector2(0.0, 길이)))
	return maxf(x길이, y길이)


func _월드길이_대상으로(대상: Node2D, 월드중심: Vector2, 길이: float) -> float:
	if 길이 <= 0.0:
		return 0.0
	var 로컬중심 := 대상.to_local(월드중심)
	var x길이 := 로컬중심.distance_to(대상.to_local(월드중심 + Vector2(길이, 0.0)))
	var y길이 := 로컬중심.distance_to(대상.to_local(월드중심 + Vector2(0.0, 길이)))
	return maxf(x길이, y길이)


func _유효한_지형(노드: Node) -> bool:
	return 노드 != null and 노드.has_method("현재색") and 노드.get("_시드") != null
