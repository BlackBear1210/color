extends SceneTree
## ============================================================================
## [2026-08-24 신규] SmartShape2D 해상도/월드크기 분리(P0) 검사 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_ss2d_해상도분리.gd
##   덤프 모드(회귀 비교용):
##   Godot --headless --path . -s res://tools/test_ss2d_해상도분리.gd -- --덤프=D:/경로/파일.txt
##
## ▣ 왜 이 검사가 필요한가
##   원래 SS2D 는 "텍스처 1픽셀 = 월드 1픽셀" 로 고정이었다.
##   엣지 띠의 월드 두께 = 텍스처 픽셀 높이 (shape.gd, width_scale * c_scale * tex_size.y)
##   반복 주기          = 텍스처 픽셀 폭   (edge.gd, total_length / tex.get_size().x)
##   그래서 고해상도 일러스트 텍스처를 넣으면 지형이 물리적으로 커져 버렸다.
##   P0-1 로 edge_material 에 texture_scale 을 넣어 이 둘을 분리했다.
##
## ▣ 무엇을 검사하나
##   A. 하위호환 — 기존 5개 머티리얼(잔디/바위/벽돌/흙/나무)이 9가지 도형에서
##      texture_scale 기본값 1.0 으로 여전히 메시를 만든다
##   B. ★P0-2 UV 붕괴 — 텍스처 폭보다 짧은 엣지에서 UV 의 U 범위가 0 이 되지 않는다
##      (예전 코드는 roundf() 가 0 을 돌려줘 엣지 전체가 텍스처 한 컬럼으로 뭉갰다)
##   C. ★P0-1 스케일 비례 — texture_scale 을 s 로 주면
##      엣지 두께는 s 배, 반복 횟수는 1/s 배가 된다
##   D. 불변식 — texture_scale = 1.0 은 예전 동작과 수학적으로 동일하다
##
## ▣ --덤프 모드
##   모든 도형/머티리얼의 정점·UV 를 텍스트로 뱉는다.
##   애드온 수정 전/후로 각각 돌려서 diff 가 비면 = 하위호환이 바이트 단위로 증명된다.
## ============================================================================

# shape_closed.gd 는 @deprecated 다. 실제 API 는 SS2D_Shape 하나로 통합되어 있고
# "닫힘" 은 점 배열의 첫/끝 점을 제약으로 묶어서 표현한다 (point_array.close_shape()).
const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")

var 실패 := 0
var 총 := 0
var 덤프경로 := ""
var 덤프줄 := PackedStringArray()


func 확인(이름: String, 조건: bool, 덧말: String = "") -> void:
	총 += 1
	var 꼬리 := ("" if 덧말.is_empty() else "  [%s]" % 덧말)
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름 + 꼬리)
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--덤프="):
			덤프경로 = a.substr("--덤프=".length())
	call_deferred("_실행")


## 검사에 쓸 도형 9종. 전부 시계방향(화면좌표 기준)으로 감아야
## 바깥 노멀이 위=90도 가 되어 normal_range 표와 맞는다.
func _도형표() -> Dictionary:
	return {
		"긴직선_정사각": PackedVector2Array([
			Vector2(0, 0), Vector2(2400, 0), Vector2(2400, 400), Vector2(0, 400)]),
		"짧은엣지_작은사각": PackedVector2Array([
			Vector2(0, 0), Vector2(120, 0), Vector2(120, 120), Vector2(0, 120)]),
		"아주짧은엣지": PackedVector2Array([
			Vector2(0, 0), Vector2(60, 0), Vector2(60, 60), Vector2(0, 60)]),
		"직사각_가로긴": PackedVector2Array([
			Vector2(0, 0), Vector2(1600, 0), Vector2(1600, 200), Vector2(0, 200)]),
		"볼록_육각": PackedVector2Array([
			Vector2(300, 0), Vector2(900, 0), Vector2(1200, 400),
			Vector2(900, 800), Vector2(300, 800), Vector2(0, 400)]),
		"오목_L자": PackedVector2Array([
			Vector2(0, 0), Vector2(800, 0), Vector2(800, 400),
			Vector2(400, 400), Vector2(400, 800), Vector2(0, 800)]),
		"오목_S자": PackedVector2Array([
			Vector2(0, 0), Vector2(1200, 0), Vector2(1200, 400), Vector2(400, 400),
			Vector2(400, 600), Vector2(1200, 600), Vector2(1200, 1000), Vector2(0, 1000)]),
		"급격한방향전환_톱니": PackedVector2Array([
			Vector2(0, 0), Vector2(200, 0), Vector2(200, 150), Vector2(400, 150),
			Vector2(400, 0), Vector2(600, 0), Vector2(600, 500), Vector2(0, 500)]),
		"복합폐곡선": PackedVector2Array([
			Vector2(0, 200), Vector2(300, 0), Vector2(700, 60), Vector2(1000, 300),
			Vector2(900, 700), Vector2(500, 900), Vector2(150, 750), Vector2(20, 500)]),
	}


## 셰이프를 하나 만들어 메시까지 굽고 돌려준다.
func _셰이프_생성(머티: SS2D_Material_Shape, 점들: PackedVector2Array) -> Node2D:
	var s: Node2D = 셰이프_S.new()
	s.shape_material = 머티
	root.add_child(s)
	# 점은 셰이프가 아니라 점 배열에 직접 넣는다 (shape.add_points() 는 @deprecated).
	var pa: SS2D_Point_Array = s.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()          # 첫 점과 끝 점을 제약으로 묶어 폐곡선으로 만든다
	s.force_update()
	return s


## 구워진 메시들에서 (정점수, U최소, U최대, 두께평균) 를 뽑는다.
## _meshes 는 언더스코어지만 GDScript 에서는 접근 가능하다. 읽기만 한다.
func _메시요약(s: Node2D) -> Dictionary:
	var 정점수 := 0
	var u최소 := INF
	var u최대 := -INF
	var 면수 := 0
	# ★메시별 U 폭의 최소값. 이걸 봐야 UV 붕괴를 잡을 수 있다.
	# 전체를 뭉뚱그려 min/max 를 내면, 필 메시(월드좌표 기반 UV)의 넓은 U 범위가
	# 붕괴한 엣지 메시(U 폭 0)를 가려버린다.
	var u폭최소 := INF
	for m in s._meshes:
		var am: ArrayMesh = m.mesh
		for surf in am.get_surface_count():
			var arr: Array = am.surface_get_arrays(surf)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			정점수 += vs.size()
			면수 += 1
			var mn := INF
			var mx := -INF
			for uv in uvs:
				mn = minf(mn, uv.x)
				mx = maxf(mx, uv.x)
			if uvs.size() > 0:
				u폭최소 = minf(u폭최소, mx - mn)
				u최소 = minf(u최소, mn)
				u최대 = maxf(u최대, mx)
	return {"정점수": 정점수, "u최소": u최소, "u최대": u최대, "면수": 면수, "u폭최소": u폭최소}


## 엣지 쿼드의 실제 월드 두께 평균. texture_scale 비례 검증용.
func _두께평균(s: Node2D) -> float:
	var 합 := 0.0
	var 개수 := 0
	for e in s._edges:
		for q in e.quads:
			if q.corner != SS2D_Quad.CORNER.NONE:
				continue
			합 += q.get_height_average()
			개수 += 1
	return (합 / 개수) if 개수 > 0 else 0.0


func _덤프_추가(꼬리표: String, s: Node2D) -> void:
	if 덤프경로.is_empty():
		return
	for m in s._meshes:
		var am: ArrayMesh = m.mesh
		for surf in am.get_surface_count():
			var arr: Array = am.surface_get_arrays(surf)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			for i in vs.size():
				덤프줄.push_back("%s v=%.4f,%.4f uv=%.6f,%.6f" % [
					꼬리표, vs[i].x, vs[i].y, uvs[i].x, uvs[i].y])


func _실행() -> void:
	print("\n=== SS2D 해상도/월드크기 분리 검사 ===")
	var 도형들 := _도형표()

	# ------------------------------------------------------------------ A
	print("\n[A] 기존 5개 머티리얼 하위호환 (texture_scale 기본 1.0)")
	var 머티경로 := {
		"잔디": "res://assets/textures/smartshape/지형_잔디.tres",
		"바위": "res://assets/textures/smartshape/지형_바위.tres",
		"벽돌": "res://assets/textures/smartshape/지형_벽돌.tres",
		"흙": "res://assets/textures/smartshape/지형_흙.tres",
		"나무": "res://assets/textures/smartshape/지형_나무.tres",
	}
	for 이름 in 머티경로:
		var 머티: SS2D_Material_Shape = load(머티경로[이름])
		확인("%s 머티리얼 로드" % 이름, 머티 != null)
		if 머티 == null:
			continue
		# 기존 .tres 에는 texture_scale 키가 없다 -> 기본값 1.0 이 들어와야 한다.
		# 덤프 모드에서는 건너뛴다: 덤프는 수정 전 애드온에서도 돌려서 diff 해야 하는데,
		# 수정 전에는 texture_scale 속성 자체가 없기 때문이다.
		if 덤프경로.is_empty():
			for meta in 머티.get_all_edge_meta_materials():
				확인("%s 엣지 texture_scale 기본값 1.0" % 이름,
					is_equal_approx(meta.edge_material.texture_scale, 1.0),
					"%.3f" % meta.edge_material.texture_scale)
		for 도형이름 in 도형들:
			var s := _셰이프_생성(머티, 도형들[도형이름])
			var r := _메시요약(s)
			확인("%s / %s 메시 생성" % [이름, 도형이름], r["정점수"] > 0,
				"정점 %d, 면 %d" % [r["정점수"], r["면수"]])
			_덤프_추가("%s|%s" % [이름, 도형이름], s)
			s.queue_free()

	# 덤프 모드는 여기서 끝낸다. B/C 는 texture_scale 을 직접 쓰므로
	# 수정 전 애드온에서는 실행할 수 없다.
	if not 덤프경로.is_empty():
		_덤프_저장()
		print("\n결과: %d / %d 통과 (덤프 모드)" % [총 - 실패, 총])
		quit(1 if 실패 > 0 else 0)
		return

	# ------------------------------------------------------------------ B
	# P0-2: 텍스처보다 짧은 엣지에서 UV 가 붕괴하지 않는가.
	# 예전 코드는 roundf(len/w) 가 0 -> change_in_length 0 -> u최소==u최대 였다.
	print("\n[B] ★P0-2 짧은 엣지 UV 붕괴 방지 (고해상도 1024px 텍스처)")
	var 고해상_top := "res://assets/textures/smartshape/grass_v4/black/grass_edge_top.png"
	if ResourceLoader.exists(고해상_top):
		# 실제 grass_v4 운용값으로 검사한다: 1024x256 텍스처 + texture_scale 0.35
		# -> 월드 반복 주기 358px, 띠 두께 90px.
		# 아래 정사각형들의 변 길이는 전부 358px 보다 짧다 = P0-2 가 없으면 붕괴하는 구간.
		# ★반드시 4방향 normal_range 머티리얼로 검사해야 한다.
		# 전방향(0~360) 머티리얼 하나만 쓰면 폐곡선의 4변이 "하나의 엣지" 로 병합되어
		# total_length 가 둘레 전체가 되고, 그러면 짧은 변이어도 reps 가 0 이 되지 않는다.
		# v4 는 상/하/좌/우가 각각 다른 머티리얼이라 변 하나가 곧 엣지 하나다.
		var 배율 := 0.35
		var 주기: float = 1024.0 * 배율
		var v4경로 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres"
		var 테스트머티: SS2D_Material_Shape = load(v4경로)
		확인("v4 머티리얼 로드", 테스트머티 != null, v4경로)
		# 4방향(상/하/좌/우) + 코너 전용(0~360) = 5 개가 정상이다.
		# 코너 전용 메타가 있어야 90도 모서리에 코너 쿼드가 생긴다 (하이브리드 구성).
		확인("v4 엣지 메타가 5개다 (4방향 + 코너전용)",
			테스트머티 != null and 테스트머티.get_all_edge_meta_materials().size() == 5,
			"%d 개" % (테스트머티.get_all_edge_meta_materials().size() if 테스트머티 else -1))
		확인("v4 texture_scale = %.2f" % 배율,
			테스트머티 != null and is_equal_approx(
				테스트머티.get_all_edge_meta_materials()[0].edge_material.texture_scale, 배율))
		for 변 in [150, 200, 250, 300, 340]:
			var pts := PackedVector2Array([
				Vector2(0, 0), Vector2(변, 0), Vector2(변, 변), Vector2(0, 변)])
			var s := _셰이프_생성(테스트머티, pts)
			var r := _메시요약(s)
			확인("변 %dpx (주기 %.0fpx 보다 짧다): 메시가 생성된다" % [변, 주기],
				r["면수"] > 0, "면 %d" % r["면수"])
			# ★메시 하나라도 U 폭이 0 이면 그 엣지는 텍스처 한 컬럼으로 뭉갠 것이다.
			확인("변 %dpx: 모든 메시의 U 폭이 0 이 아니다" % 변,
				r["면수"] > 0 and r["u폭최소"] > 0.0001,
				"최소 U폭 %.5f (전체 U %.3f~%.3f)" % [r["u폭최소"], r["u최소"], r["u최대"]])
			s.queue_free()

		# 참고용(합격/불합격 아님): 배율 1.0 이면 띠 두께가 256px 라
		# 작은 도형은 띠가 도형보다 두꺼워져 애드온이 메시를 못 만든다.
		# 이건 P0 와 무관한 기존 SS2D 의 한계이며, 배율을 쓰면 애초에 발생하지 않는다.
		var 큰띠머티 := _임시머티(load(고해상_top), 1.0)
		var 작은사각 := PackedVector2Array([
			Vector2(0, 0), Vector2(120, 0), Vector2(120, 120), Vector2(0, 120)])
		var s2 := _셰이프_생성(큰띠머티, 작은사각)
		print("  INFO  배율 1.0 + 120px 도형(띠 256px) -> 면 %d 개 (기존 SS2D 한계, P0 무관)"
			% _메시요약(s2)["면수"])
		s2.queue_free()

		# 참고: 4방향 normal_range 구성에서 코너 쿼드가 실제로 만들어지는가?
		# 코너는 "한 엣지 머티리얼의 점 나열 안에서" 방향이 꺾일 때만 생긴다.
		# 상/하/좌/우가 서로 다른 머티리얼이면 90도 모서리는 서로 다른 엣지의 경계라
		# 코너 쿼드가 안 생길 수 있다. 추측하지 말고 실제로 세어 본다.
		for 도형이름 in ["긴직선_정사각", "오목_L자", "볼록_육각", "복합폐곡선"]:
			var sc := _셰이프_생성(테스트머티, 도형들[도형이름])
			var 외부 := 0
			var 내부 := 0
			for e in sc._edges:
				for q in e.quads:
					if q.corner == SS2D_Quad.CORNER.OUTER:
						외부 += 1
					elif q.corner == SS2D_Quad.CORNER.INNER:
						내부 += 1
			print("  INFO  %s 코너 쿼드: OUTER %d / INNER %d" % [도형이름, 외부, 내부])
			sc.queue_free()
	else:
		print("  SKIP  grass_v4 텍스처가 아직 없다 (%s)" % 고해상_top)

	# ------------------------------------------------------------------ C
	print("\n[C] ★P0-1 texture_scale 비례 검증")
	var 기준텍스: Texture2D = null
	if ResourceLoader.exists(고해상_top):
		기준텍스 = load(고해상_top)
	else:
		기준텍스 = load("res://assets/textures/smartshape/black_grass_edge.png")
	if 기준텍스 != null:
		var 두께표 := {}
		var 긴도형: PackedVector2Array = 도형들["긴직선_정사각"]
		for s_val in [1.0, 0.5, 0.25]:
			var 머티 := _임시머티(기준텍스, s_val)
			var sh := _셰이프_생성(머티, 긴도형)
			두께표[s_val] = _두께평균(sh)
			sh.queue_free()
		확인("texture_scale 1.0 두께 = 텍스처 픽셀 높이",
			is_equal_approx(두께표[1.0], 기준텍스.get_size().y),
			"%.2f vs %.2f" % [두께표[1.0], 기준텍스.get_size().y])
		확인("texture_scale 0.5 두께 = 절반",
			absf(두께표[0.5] - 두께표[1.0] * 0.5) < 0.01,
			"%.2f vs %.2f" % [두께표[0.5], 두께표[1.0] * 0.5])
		확인("texture_scale 0.25 두께 = 1/4",
			absf(두께표[0.25] - 두께표[1.0] * 0.25) < 0.01,
			"%.2f vs %.2f" % [두께표[0.25], 두께표[1.0] * 0.25])

		# 반복 횟수: 배율이 작아지면 같은 길이에 더 많이 반복된다 (U 최대값이 커진다)
		var u표 := {}
		for s_val in [1.0, 0.5, 0.25]:
			var 머티 := _임시머티(기준텍스, s_val)
			var sh := _셰이프_생성(머티, 긴도형)
			u표[s_val] = _메시요약(sh)["u최대"]
			sh.queue_free()
		확인("배율 0.5 -> 반복 약 2배", u표[0.5] > u표[1.0] * 1.8,
			"U최대 %.2f -> %.2f" % [u표[1.0], u표[0.5]])
		확인("배율 0.25 -> 반복 약 4배", u표[0.25] > u표[1.0] * 3.6,
			"U최대 %.2f -> %.2f" % [u표[1.0], u표[0.25]])

	# ------------------------------------------------------------------ 마무리
	print("\n결과: %d / %d 통과" % [총 - 실패, 총])
	quit(1 if 실패 > 0 else 0)


func _덤프_저장() -> void:
	var f := FileAccess.open(덤프경로, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(덤프줄))
		f.close()
		print("\n[덤프] %d 줄 -> %s" % [덤프줄.size(), 덤프경로])
	else:
		print("\n[덤프] 파일 열기 실패: %s" % 덤프경로)


## 텍스처 한 장 + 배율만 지정한 최소 셰이프 머티리얼을 만든다 (전 방향 동일).
func _임시머티(tex: Texture2D, 배율: float) -> SS2D_Material_Shape:
	var e := SS2D_Material_Edge.new()
	e.textures = [tex] as Array[Texture2D]
	e.use_corner_texture = false
	e.use_taper_texture = false
	e.texture_scale = 배율

	var nr := SS2D_NormalRange.new(0.0, 360.0)
	var meta := SS2D_Material_Edge_Metadata.new()
	meta.edge_material = e
	meta.normal_range = nr

	var m := SS2D_Material_Shape.new()
	m.set_edge_meta_materials([meta] as Array[SS2D_Material_Edge_Metadata])
	return m
