extends SceneTree
## ============================================================================
## [2026-08-01 신규] 스마트월드 테스트 스테이지 생성기
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_스마트월드.gd
##   → scenes/스마트월드/스마트월드_테스트.tscn 을 새로 만든다 (덮어쓰기)
##
## ▣ 왜 코드로 만드나
##   유기적 지형은 점이 수십 개다. 손으로 찍으면 다시 만들 수 없고, 값 하나 바꿀 때마다
##   전부 다시 찍어야 한다. 여기서 뼈대를 만든 다음 **에디터에서 점을 끌어 다듬는** 게
##   가장 빠르다. (다듬은 뒤에는 이 스크립트를 다시 돌리지 말 것 — 덮어써진다)
##
## ▣ 스테이지 구성 (자연 → 물가 바이옴 진행)
##   ①   0~1180  숲 바닥        — 기본 이동, 식물 A(잎 발판), 반딧불
##   ② 1180~1620 구덩이         — 공중 발판을 칠해야 실체가 되어 건널 수 있다
##   ③ 1620~2560 물 구역        — 저장고→배관→호퍼→물줄기. 통과플랫폼으로 색 지키기
##   ④ 2560~3200 덤불 구역      — 식물 B 임시 색 지대
##   ⑤ 3200~4300 바람 구역      — 송풍기가 연기와 총알 궤적을 휘게 한다. 가로등
##
## ▣ 플레이어 점프 성능 (동현 테스트월드제작과 동일하게 맞춤)
##   점프_높이_칸 10 × 16px = 160px / 점프_거리_칸 20 × 16px = 320px
##   → 발판 간격은 260px 이하, 단차는 130px 이하로 잡았다.
##
## ▣ ⚠ 노드를 만들 때 반드시 `스크립트.new()` 를 쓴다
##   Node2D.new() + set_script() 로 만들면 스크립트의 `_init()` 이 안 돈다.
##   SS2D_Shape 는 _init() 에서 점 배열(SS2D_Point_Array)을 만들기 때문에,
##   set_script 로 만들면 get_point_array() 가 null 이라 지형이 통째로 안 나온다.
## ============================================================================

const 씬경로 := "res://scenes/스마트월드/스마트월드_테스트.tscn"
const 재질경로 := "res://assets/textures/smartshape/검정_지형.tres"
const PLAYER := "res://scenes/player/Player.tscn"

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 식물A_S := preload("res://scripts/스마트월드/식물_a.gd")
const 식물B_S := preload("res://scripts/스마트월드/식물_b.gd")
const 유체_S := preload("res://scripts/스마트월드/유체.gd")
const 배관_S := preload("res://scripts/스마트월드/배관.gd")
const 호퍼_S := preload("res://scripts/스마트월드/호퍼.gd")
const 저장고_S := preload("res://scripts/스마트월드/물저장고.gd")
const 레버_S := preload("res://scripts/스마트월드/제어레버.gd")
const 송풍기_S := preload("res://scripts/스마트월드/송풍기.gd")
const 통과_S := preload("res://scripts/스마트월드/통과플랫폼.gd")
const 발광_S := preload("res://scripts/스마트월드/발광체.gd")
const 안개_S := preload("res://scripts/스마트월드/안개층.gd")

const 지면 := 760.0
const 끝x := 4300.0

var _루트: Node2D
var _지형층: Node2D
var _오브젝트층: Node2D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260801
	_재질_확인()
	_짓기()
	quit(0)


# ============================================================================
# 지형 재질(.tres) — 없으면 만든다
# ----------------------------------------------------------------------------
# 2026-08-01: assets/textures/smartshape/검정_지형.tres 가 정리 과정에서 지워져
# 빌드가 통째로 실패한 적이 있다. 재질은 PNG 이름만 알면 언제든 다시 만들 수 있으므로
# **없으면 여기서 자동 생성**해서 "PNG 만 있으면 한 명령으로 복구"되게 한다.
#
# 테두리 슬롯 → 노멀 각도 (0°=오른쪽, 90°=위, 180°=왼쪽, 270°=아래)
# ============================================================================
const 테두리표 := [
	# [텍스처 이름들, 시작각, 폭, z]  — 그리는 순서대로(뒤에 올수록 위)
	[["black_bottom_center"], 225.0, 90.0, 0],
	[["black_left"], 135.0, 90.0, 0],
	[["black_right"], 315.0, 90.0, 0],
	[["black_center"], 45.0, 90.0, 1],
]

func _재질_확인() -> void:
	if ResourceLoader.exists(재질경로):
		return
	print("  재질이 없어 새로 만든다 → %s" % 재질경로)
	var 재질 := SS2D_Material_Shape.new()
	var 채우기: Array[Texture2D] = [load("res://assets/textures/smartshape/black_fill.png")]
	재질.fill_textures = 채우기
	재질.fill_texture_scale = 1.0
	# ★[2026-08-01 함정] SS2D 기본값은 fill_texture_z_index = -10 이다.
	#   배경 보정용 '대기' 레이어(z=-7)보다 뒤라서 **지형 안쪽이 통째로 가려진다**
	#   (테두리만 보이고 속이 빈 것처럼 나온다 — 첫 스크린샷에서 실제로 그랬다).
	#   -1 로 올려 테두리(z=0/1) 바로 뒤, 배경보다는 앞에 오게 한다.
	재질.fill_texture_z_index = -1

	var 메타들: Array[SS2D_Material_Edge_Metadata] = []
	for 줄 in 테두리표:
		var 텍스처: Array[Texture2D] = []
		for 이름 in 줄[0]:
			var 경로 := "res://assets/textures/smartshape/%s.png" % 이름
			if ResourceLoader.exists(경로):
				텍스처.append(load(경로))
		if 텍스처.is_empty():
			continue
		var 테두리 := SS2D_Material_Edge.new()
		테두리.textures = 텍스처
		# 모서리·테이퍼 조각은 아직 규격이 안 맞아 꺼둔다 (켜면 빈 텍스처로 구멍이 뚫린다)
		테두리.use_corner_texture = false
		테두리.use_taper_texture = false
		var 메타 := SS2D_Material_Edge_Metadata.new()
		메타.edge_material = 테두리
		메타.normal_range = SS2D_NormalRange.new(줄[1], 줄[2])
		메타.z_index = 줄[3]
		메타들.append(메타)
	재질.set_edge_meta_materials(메타들)
	var err := ResourceSaver.save(재질, 재질경로)
	if err != OK:
		push_error("재질 저장 실패: %s" % error_string(err))


func _짓기() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/스마트월드/"))

	_루트 = 월드_S.new()
	_루트.name = "스마트월드_테스트"
	_루트.스테이지_이름 = "스마트월드 테스트 — 자연→물가"
	_루트.시작_위치 = Vector2(240, 600)
	_루트.낙사_y = 1500.0
	_루트.카메라_리밋 = Rect2(-200, -700, 끝x + 400, 2300)
	_루트.카메라_줌 = 0.82

	# ── 페인트 규칙 엔진 (지형보다 먼저 트리에 들어가야 한다) ──
	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.최대_탄약 = 12
	코어.add_to_group("페인트코어", true)      # ★true = 씬 파일에 그룹이 저장된다
	_루트.add_child(코어)

	# ── 배경 (자연 → 물가 그라데이션) ──
	# 기존 stage_backdrop.gd 를 그대로 재사용한다. 하늘·원경·뒷벽·안개까지 한 번에 나온다.
	StageBackdrop.구성(_루트, _루트, Rect2(0, -200, 끝x, 1200), "자연", "물가", 20260801)

	# ── ★대기(공기 원근) 레이어 ──────────────────────────────────────────
	# [2026-08-01 문제와 해결] 처음 만들었을 때 화면이 통째로 새까맸다.
	#   원인: 배경(하늘 0.15~0.36 + 어두운 뒷벽)과 지형 아트(black_fill ≈ 0.10)의
	#   명도가 거의 같아서 지형 실루엣이 배경에 먹혔다.
	#   해결: 배경과 지형 **사이**에 밝은 반투명 판을 한 장 끼워 배경 명도를 0.55 대로
	#   끌어올린다. 이러면 검정 지형(0.1)도 흰색 지형(0.9)도 배경 위에서 또렷해진다.
	#   (레벨디자인_가이드 §5 의 "배경은 45~55%를 침범하지 않는다"는 지형이 그 대역을
	#    쓰기 때문인데, 여기서는 지형이 0.1/0.9 양극이라 중간 배경이 오히려 정답이다)
	var 대기 := ColorRect.new()
	대기.name = "대기"
	대기.color = Color(0.58, 0.60, 0.65, 0.45)
	대기.position = Vector2(-1600, -1400)
	대기.size = Vector2(끝x + 3200, 3600)
	# 뒷벽(z=-8)보다 **앞**, 지형(z=0)보다 뒤. 뒷벽이 제일 어두운 판이라 그 앞을 덮어야 한다.
	대기.z_index = -7
	대기.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_루트.add_child(대기)

	# ── ★패럴랙스 안개/구름 (2026-08-02 추가) ──────────────────────────
	# 서로 다른 속도로 흐르는 안개를 3겹 깔아 깊이를 만든다.
	# scroll_scale 이 작을수록 멀리 있는 것처럼 천천히 지나간다.
	#   0.30 = 먼 구름(하늘과 실루엣 사이)
	#   0.65 = 중간 안개(지형 뒤)
	#   1.25 = 전경 안개(플레이어 앞을 스쳐 지나간다 = 깊이감이 확 산다)
	_안개층("안개_원경", 0.30, -26, Vector2(0, -260), 9, 460.0, 10.0,
		Color(0.80, 0.83, 0.88, 0.10), 11)
	_안개층("안개_중경", 0.65, -6, Vector2(0, 60), 12, 330.0, 17.0,
		Color(0.76, 0.79, 0.84, 0.13), 22)
	_안개층("안개_전경", 1.25, 14, Vector2(0, 320), 7, 280.0, 30.0,
		Color(0.72, 0.75, 0.80, 0.10), 33)

	# ── 전체 톤 — 빛이 보일 정도로만 살짝 누른다 ──
	# 0.6 대로 세게 누르면 위의 대기 보정이 도로 무의미해진다.
	# ★이 색이 "밝기 100%" 의 기준값이다. ESC 메뉴의 밝기 슬라이더가 여기에 배수를 곱한다.
	var 어둠 := CanvasModulate.new()
	어둠.name = "어둠"
	어둠.color = Color(0.90, 0.90, 0.94)
	_루트.add_child(어둠)

	_지형층 = Node2D.new()
	_지형층.name = "지형"
	_루트.add_child(_지형층)

	_오브젝트층 = Node2D.new()
	_오브젝트층.name = "오브젝트"
	_루트.add_child(_오브젝트층)

	_바닥_만들기()
	_공중발판_만들기()
	_숲_구역()
	_물_구역()
	_덤불_구역()
	_바람_구역()

	# ── 플레이어 (동현 테스트월드제작과 같은 점프 세팅) ──
	var 플레이어 := (load(PLAYER) as PackedScene).instantiate()
	플레이어.name = "Player"
	플레이어.set("점프_높이_칸", 10.0)
	플레이어.set("점프_거리_칸", 20.0)
	플레이어.set("상승_배수", 4.563)
	플레이어.set("낙하_가속_증가율", 3.284)
	플레이어.position = Vector2(240, 600)
	_루트.add_child(플레이어)

	_주인_지정(_루트, _루트)

	var 팩 := PackedScene.new()
	var err := 팩.pack(_루트)
	if err != OK:
		push_error("pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, 씬경로)
	print("[build_스마트월드] %s → %s" % [error_string(err), 씬경로])


# ============================================================================
# 지형
# ============================================================================
## 바닥 3덩이 — 사이에 구덩이가 있다.
func _바닥_만들기() -> void:
	# ★[2026-08-01] 물 구역 한가운데(1950~2210)를 뚫어 **수직 갱도**를 만든다.
	#   그렇게 안 하면 물줄기·통과플랫폼이 전부 지면 속에 파묻혀 보이지도, 시험하지도 못한다.
	#   폭 260px = 점프 거리(320px) 안이라 건널 수 있고, 내려가면 물길 퍼즐이 나온다.
	var 구간 := [
		[-200.0, 1180.0],
		[1620.0, 1950.0],
		[2210.0, 2560.0],
		[2520.0, 끝x + 200.0],
	]
	var i := 0
	for s in 구간:
		i += 1
		var 지형 := _지형_노드("바닥_%d" % i, Vector2.ZERO, _바닥_점들(s[0], s[1]), false, false)
		_지형층.add_child(지형)


## 윗면이 부드럽게 굽이치는 바닥 폴리곤(월드 좌표 그대로).
## 사인 3개를 겹쳐서 "규칙적이지 않은 언덕"을 만든다 — 노이즈보다 결과가 예측 가능하고,
## `_지면y()` 로 같은 식을 다시 쓸 수 있어 프롭을 지면에 정확히 붙일 수 있다.
func _바닥_점들(x0: float, x1: float) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var 간격 := 40.0                      # 촘촘할수록 곡선이 매끄럽다
	var x := x0
	while x <= x1:
		점들.append(Vector2(x, _지면y(x)))
		x += 간격
	점들.append(Vector2(x1, _지면y(x1)))
	# 아래쪽을 닫는다 — 충분히 깊게. 얕으면 "떠 있는 막대기"로 보인다.
	점들.append(Vector2(x1, 1420.0))
	점들.append(Vector2(x0, 1420.0))
	return 점들


func _지면y(x: float) -> float:
	var 굴곡 := 46.0
	var 오프셋 := 0.0
	if x > 1620.0 and x < 2560.0:
		굴곡 = 30.0
		오프셋 = -30.0
	elif x >= 2560.0:
		굴곡 = 52.0
		오프셋 = -10.0
	var t := x / 260.0
	return 지면 + 오프셋 + sin(t) * 굴곡 + sin(t * 2.37 + 1.1) * 굴곡 * 0.45 \
		+ sin(t * 0.61 - 0.4) * 굴곡 * 0.8


## 공중 발판 — 무색이면 유령(통과), 칠하면 실체가 된다.
func _공중발판_만들기() -> void:
	var 자료 := [
		[Vector2(1300, 600), 105.0, 46.0, 1],
		[Vector2(1520, 470), 95.0, 42.0, 1],
		[Vector2(1760, 560), 120.0, 50.0, 2],
		[Vector2(2760, 500), 130.0, 52.0, 2],
		[Vector2(3020, 380), 100.0, 44.0, 1],
		[Vector2(3560, 470), 145.0, 56.0, 2],
		[Vector2(3900, 350), 110.0, 46.0, 1],
	]
	var i := 0
	for d in 자료:
		i += 1
		var 지형 := _지형_노드("발판_%d" % i, d[0], _덩어리_점들(d[1], d[2]), true, true)
		지형.필요횟수_수동 = d[3]
		_지형층.add_child(지형)


## 유기적인 덩어리(섬) 모양 — 타원에 요철을 섞는다.
func _덩어리_점들(rx: float, ry: float) -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	var n := 26
	var 위상 := _rng.randf() * TAU
	for i in n:
		var a := TAU * float(i) / float(n)
		# 사인 2개를 겹친 요철 — 매번 다른 실루엣이 나오되 뾰족해지지는 않는다
		var 요철 := 1.0 + sin(a * 3.0 + 위상) * 0.11 + sin(a * 5.0 - 위상) * 0.06
		점들.append(Vector2(cos(a) * rx * 요철, sin(a) * ry * 요철))
	return 점들


## SS2D 지형 노드 하나 (콜리전 폴리곤까지 미리 구워서).
func _지형_노드(이름: String, 위치: Vector2, 점들: PackedVector2Array,
		칠하기: bool, 유령: bool) -> 스마트지형:
	var 지형: 스마트지형 = 지형_S.new()
	지형.name = 이름
	지형.position = 위치
	지형.shape_material = load(재질경로)
	지형.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	지형.칠하기_허용 = 칠하기
	지형.무색일때_통과 = 유령

	지형.get_point_array().add_points(점들)
	지형.get_point_array().close_shape()

	var 바디 := StaticBody2D.new()
	바디.name = "StaticBody2D"
	var 폴리 := CollisionPolygon2D.new()
	폴리.name = "CollisionPolygon2D"
	# ★[2026-08-02] 에디터에서 콜리전 기즈모를 숨긴다.
	#   오목한 폴리곤은 Godot 이 볼록 조각으로 쪼개서 **조각마다 다른 색**으로 그린다.
	#   그래서 에디터 2D 뷰가 무지개색 삼각형 덩어리로 뒤덮여 지형 점을 찍을 수가 없었다.
	#   visible 은 **기즈모/디버그 그리기만** 끄는 것이라 물리 판정에는 아무 영향이 없다.
	#   (다시 보고 싶으면 씬 트리에서 눈 아이콘을 켜면 된다)
	폴리.visible = false
	바디.add_child(폴리)
	지형.add_child(바디)
	지형.collision_polygon_node_path = 지형.get_path_to(폴리)
	지형.collision_size = 24.0
	# EditorAndRuntime — 에디터에서도 굽고 실행할 때도 다시 굽는다
	지형.collision_update_mode = SS2D_Shape.CollisionUpdateMode.EditorAndRuntime

	var gen := SS2D_CollisionGen.new()
	gen.collision_size = 24.0
	폴리.polygon = gen.generate_filled(지형.get_point_array().get_tessellated_points())
	return 지형


# ============================================================================
# ① 숲 구역 — 식물 A, 반딧불
# ============================================================================
func _숲_구역() -> void:
	_식물A(Vector2(620, _지면y(620)), 3)
	_식물A(Vector2(940, _지면y(940)), 2)
	_식물A(Vector2(1900, _지면y(1900)), 4)

	for i in 7:
		var x := 300.0 + float(i) * 150.0
		# 반딧불 = 구슬(종류 1). 떠다니고 깜빡인다.
		# 반경을 키우면 안개처럼 뭉개진다 — 작고 또렷하게 여러 개가 훨씬 잘 읽힌다.
		_발광(Vector2(x, _지면y(x) - _rng.randf_range(120.0, 300.0)), 1,
			Color(0.85, 0.95, 0.75), 88.0, 0.85, 0.6, 26.0)


# ============================================================================
# ③ 물 구역
# ============================================================================
func _물_구역() -> void:
	# 물줄기(위)는 저장고 → 호퍼 입구(y≈572~612)까지 닿아야 호퍼가 감지한다.
	var 물위 := _유체("물줄기_위", Vector2(2080, 300), 0, ColorDefs.WHITE, Vector2(56, 300))
	# 물줄기(아래)는 호퍼 밑에서 갱도 안으로 길게 떨어진다.
	var 물아래 := _유체("물줄기_아래", Vector2(2080, 700), 0, ColorDefs.WHITE, Vector2(48, 430))

	# 저장고 — 칠해야 물이 흐른다 (무색이면 꺼져 있음)
	var 저장고 := 저장고_S.new()
	저장고.name = "물저장고"
	저장고.position = Vector2(2080, 230)
	저장고.크기 = Vector2(240, 92)
	저장고.필요횟수 = 3
	_오브젝트층.add_child(저장고)
	저장고.공급_유체 = 저장고.get_path_to(물위)

	# 배관 — 저장고에서 호퍼까지. 흐르는 색을 따라간다.
	_배관("배관_세로1", Vector2(2080, 420), 0, true, 150.0, 물위)
	_배관("배관_사갈래", Vector2(2080, 520), 2, false, 150.0, 물위)
	_배관("배관_가로1", Vector2(1930, 520), 0, false, 150.0, 물위)
	_배관("배관_가로2", Vector2(2230, 520), 0, false, 150.0, 물위)

	# 호퍼 — 위에서 오는 물을 받아 아래 물줄기를 켠다
	var 호퍼 := 호퍼_S.new()
	호퍼.name = "호퍼"
	호퍼.position = Vector2(2080, 660)
	호퍼.폭 = 150.0
	호퍼.높이 = 62.0
	_오브젝트층.add_child(호퍼)
	호퍼.출구_유체 = 호퍼.get_path_to(물아래)

	# ── 갱도 안: 통과플랫폼 vs 일반 발판 비교 실험 ──────────────────────
	# 둘 다 물줄기(x 2056~2104) 안에 걸치도록 놓는다.
	#   통과플랫폼 → 물이 지나가도 색이 남는다
	#   일반 발판   → 반대색 물이 지나가면 색이 지워지고 페인트가 회수된다
	# 나란히 놓아야 "왜 통과플랫폼이 필요한가"를 한 화면에서 알 수 있다.
	var 통과 := 통과_S.new()
	통과.name = "통과플랫폼"
	통과.position = Vector2(2000, 900)
	통과.크기 = Vector2(200, 26)
	통과.필요횟수 = 2
	_오브젝트층.add_child(통과)

	var 비교 := _지형_노드("발판_물아래", Vector2(2150, 900), _덩어리_점들(85.0, 32.0), true, false)
	비교.필요횟수_수동 = 1
	_지형층.add_child(비교)

	# 원형 레버 — 옆 폭포를 껐다 켠다 (독립 물줄기라 저장고와 안 부딪힌다)
	var 폭포 := _유체("폭포", Vector2(1700, 260), 0, ColorDefs.BLACK, Vector2(70, 420))
	var 레버1 := 레버_S.new()
	레버1.name = "원형레버"
	레버1.position = Vector2(1810, _지면y(1810) - 30.0)
	레버1.종류 = 제어레버.종류_.원형
	_오브젝트층.add_child(레버1)
	레버1.대상_유체 = 레버1.get_path_to(폭포)

	# 물 위 반사광 — 2D 지만 "빛이 물에 비친다"는 인상
	_발광(Vector2(2080, 990), 2, Color(0.72, 0.86, 0.95), 430.0, 0.55, 0.10, 0.0)
	_발광(Vector2(1700, 700), 2, Color(0.72, 0.86, 0.95), 330.0, 0.45, 0.10, 0.0)


# ============================================================================
# ④ 덤불 구역
# ============================================================================
func _덤불_구역() -> void:
	_식물B("덤불_1", Vector2(2700, _지면y(2700) - 90.0), 120.0)
	_식물B("덤불_2", Vector2(3080, _지면y(3080) - 110.0), 140.0)
	_식물A(Vector2(2900, _지면y(2900)), 2)


# ============================================================================
# ⑤ 바람 구역
# ============================================================================
func _바람_구역() -> void:
	var 송풍 := 송풍기_S.new()
	송풍.name = "송풍기"
	송풍.position = Vector2(3320, _지면y(3320) - 150.0)
	송풍.사거리 = 520.0
	송풍.바람폭 = 190.0
	송풍.세기 = 1250.0
	_오브젝트층.add_child(송풍)

	# 연기 — 아래에서 위로. 송풍기가 밀어낸다.
	_유체("연기_1", Vector2(3700, _지면y(3700)), 1, ColorDefs.BLACK, Vector2(120, 300))

	# 직선 레버 — 두 갈래 물줄기를 번갈아 켠다
	var 갈래A := _유체("갈래_A", Vector2(3480, 100), 0, ColorDefs.WHITE, Vector2(52, 300))
	var 갈래B := _유체("갈래_B", Vector2(3980, 100), 0, ColorDefs.BLACK, Vector2(52, 300))
	_배관("배관_갈래", Vector2(3730, 80), 1, false, 500.0, 갈래A)
	var 레버2 := 레버_S.new()
	레버2.name = "직선레버"
	레버2.position = Vector2(3730, _지면y(3730) - 30.0)
	레버2.종류 = 제어레버.종류_.직선
	_오브젝트층.add_child(레버2)
	레버2.갈래_A = 레버2.get_path_to(갈래A)
	레버2.갈래_B = 레버2.get_path_to(갈래B)

	# 가로등 — 어두운 구간에 빛을 심는다
	for x in [2620.0, 3200.0, 3860.0]:
		_발광(Vector2(x, _지면y(x) - 190.0), 0, Color(1.0, 0.92, 0.76), 340.0, 1.25, 0.22, 0.0)


# ============================================================================
# 만들기 도우미
# ============================================================================
func _식물A(위치: Vector2, 단계: int) -> void:
	var n := 식물A_S.new()
	n.name = "식물A_%d" % _오브젝트층.get_child_count()
	n.position = 위치
	n.최대_단계 = 단계
	_오브젝트층.add_child(n)


func _식물B(이름: String, 위치: Vector2, 반경: float) -> void:
	var n := 식물B_S.new()
	n.name = 이름
	n.position = 위치
	n.반경 = 반경
	_오브젝트층.add_child(n)


func _유체(이름: String, 위치: Vector2, 종류: int, 색: int, 크기: Vector2) -> 유체:
	var n: 유체 = 유체_S.new()
	n.name = 이름
	n.position = 위치
	n.종류 = 종류
	n.색 = 색
	n.크기 = 크기
	_오브젝트층.add_child(n)
	return n


func _배관(이름: String, 위치: Vector2, 모양: int, 세로: bool, 길이: float,
		유체노드: Node) -> void:
	var n := 배관_S.new()
	n.name = 이름
	n.position = 위치
	n.모양 = 모양
	n.세로 = 세로
	n.길이 = 길이
	_오브젝트층.add_child(n)
	if 유체노드:
		n.연결_유체 = n.get_path_to(유체노드)


## 패럴랙스 안개 한 겹. Parallax2D 로 감싸야 카메라 속도에 따라 다르게 흐른다.
func _안개층(이름: String, 스크롤: float, z: int, 오프셋: Vector2, 개수: int,
		반경: float, 속도: float, 색: Color, 씨앗보정: int) -> void:
	var par := Parallax2D.new()
	par.name = 이름
	par.scroll_scale = Vector2(스크롤, 스크롤 * 0.55)   # 세로는 덜 움직여야 어지럽지 않다
	# 반복 폭을 주면 카메라가 끝까지 가도 안개가 끊기지 않는다
	par.repeat_size = Vector2(6000, 0)
	par.repeat_times = 3
	par.z_index = z
	_루트.add_child(par)

	var 안개 := 안개_S.new()
	안개.name = "안개"
	안개.position = 오프셋
	안개.영역 = Vector2(6000, 900)
	안개.덩어리수 = 개수
	안개.덩어리_반경 = 반경
	안개.흐름속도 = 속도
	안개.안개색 = 색
	안개.씨앗 = 20260802 + 씨앗보정
	par.add_child(안개)


func _발광(위치: Vector2, 종류: int, 색: Color, 반경: float, 밝기: float,
		깜빡임: float, 부유: float) -> void:
	var n := 발광_S.new()
	n.name = "발광_%d" % _오브젝트층.get_child_count()
	n.position = 위치
	n.종류 = 종류
	n.빛색 = 색
	n.반경 = 반경
	n.밝기 = 밝기
	n.깜빡임 = 깜빡임
	n.부유 = 부유
	_오브젝트층.add_child(n)


## 씬 저장을 위해 owner 를 루트로 지정한다.
##
## ★★[2026-08-02 치명적 버그 수정] 인스턴스 씬 **안쪽으로 내려가면 안 된다.**
##   Player.tscn 처럼 인스턴스로 넣은 노드의 자식(Gun·Placeholder·CollisionShape2D…)까지
##   owner 를 바꾸면, PackedScene 이 그것들을 **원본과 별개인 새 노드로 한 벌 더 저장**한다.
##   그래서 실행하면 Player 밑에 Gun2 / Placeholder2 / CollisionShape2D2 / Camera2D2 가
##   생겼고, 아래 세 가지 증상이 한꺼번에 나왔다:
##     · "Node not found: Muzzle (…/Player/Gun2)" — 복제된 Gun 에는 Muzzle 이 없다
##     · "_shoot: … 'global_position' on a null instance" — 위 Muzzle 이 null 이라서
##     · 플레이어가 **파란 박스에 갇혀 보임** — 복제된 Placeholder2 는
##       player_anim.gd 가 숨기는 대상("Placeholder")이 아니라 그대로 남는다
##   → `scene_file_path` 가 비어 있지 않으면 그 노드가 인스턴스 루트다. 거기서 멈춘다.
func _주인_지정(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		자식.owner = 루트
		if not 자식.scene_file_path.is_empty():
			continue          # 인스턴스 씬 — 내부는 그 씬이 관리한다. 건드리지 않는다.
		_주인_지정(자식, 루트)
