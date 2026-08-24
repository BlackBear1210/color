extends SceneTree
## ============================================================================
## [2026-08-25 신규] 새 타일셋(재질 폴더 구조)에서 런타임 색 시스템이 도는지 검증
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/검증_런타임색_타일셋.gd
##
## ▣ 왜 이게 따로 필요한가
##   이 게임의 핵심 규칙은 "몸에 닿은 지형이 내 색과 다르면 즉사" 다.
##   그 판정은 **지형이 칠해진다는 전제** 위에 있다.
##   새 타일셋은 파일명이 black_ 로 시작하지 않고 <재질>/black/edge_top.png 구조라
##   짝 찾기 규칙이 한 번 깨진 적이 있다 (그때 지형이 총에 안 맞았다).
##   그래서 머티리얼이 아니라 **지형 노드를 실제로 세워서**
##   셰이더가 붙었는지 · 흰색 짝이 white 폴더를 가리키는지 · 명중이 상태를 바꾸는지 본다.
##
## ▣ 흑/백 전용 머티리얼을 만들지 않았다는 것도 여기서 같이 증명된다.
##   머티리얼 하나(검정 텍스처 기반)로 검정↔흰색이 둘 다 되어야 통과한다.
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const T := "res://assets/textures/smartshape"

const 대상 := [
	["잔디", T + "/grass_v4/tres/지형_잔디_v4_black_detail.tres",
		T + "/grass_v4/tres/지형_잔디v4_black_detail_속빔.tres"],
	["벽돌", T + "/brick_v1/tres/지형_벽돌v1_black_detail.tres",
		T + "/brick_v1/tres/지형_벽돌v1_black_detail_속빔.tres"],
	["하수", T + "/sewer_v1/tres/지형_하수v1_black_detail.tres",
		T + "/sewer_v1/tres/지형_하수v1_black_detail_속빔.tres"],
	["나무", T + "/wood_v1/tres/지형_나무v1_black_detail.tres",
		T + "/wood_v1/tres/지형_나무v1_black_detail_속빔.tres"],
]

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
	else:
		실패 += 1
		print("    ✗ %s" % 글)


func _세우기(머티: String, 시작: int) -> Node:
	var n = 지형_S.new()
	n.name = "T"
	n.shape_material = load(머티)
	n.시작상태 = 시작
	root.add_child(n)
	var pa: SS2D_Point_Array = n.get_point_array()
	pa.begin_update()
	pa.add_points(PackedVector2Array([
		Vector2(-200, -80), Vector2(200, -80), Vector2(200, 80), Vector2(-200, 80)]))
	pa.end_update()
	pa.close_shape()
	n.force_update()
	return n


func _검사(이름: String, 머티: String, 속빔: bool) -> void:
	print("  %s %s" % [이름, "속빔" if 속빔 else "채움"])
	var n := _세우기(머티, 0)   # 0 = 무색

	var m = n.shape_material
	# 인스턴스마다 깊은 복사 — 같은 재질을 쓰는 다른 지형까지 같이 칠해지면 안 된다
	_확인(m.resource_path != 머티, "shape_material 이 .tres 원본을 그대로 쓴다 (공유 오염)")

	var 엣지셰이더 := 0
	var 코너셰이더 := 0
	for 메타 in m.get_all_edge_meta_materials():
		var e = 메타.edge_material
		if e == null:
			continue
		if not e.textures_corner_outer.is_empty():
			# 코너 전용 = 투명 캐리어. 셰이더가 붙으면 안 된다 (경고 폭탄의 원인이었다)
			if e.material != null:
				코너셰이더 += 1
			continue
		if e.material is ShaderMaterial:
			엣지셰이더 += 1
			var alt = (e.material as ShaderMaterial).get_shader_parameter("alt_tex")
			_확인(alt != null, "엣지 alt_tex 가 비었다")
			if alt != null:
				_확인(String(alt.resource_path).contains("/white/"),
					"alt_tex 가 white 폴더가 아니다: %s" % alt.resource_path)
	_확인(엣지셰이더 == 4, "4방향 엣지에 페인트 셰이더가 %d개만 붙었다" % 엣지셰이더)
	_확인(코너셰이더 == 0, "코너 캐리어에 셰이더가 붙었다 (%d)" % 코너셰이더)

	# 채움은 fill 셰이더가 있어야 하고, 속빔은 채울 것이 없으므로 없어야 정상
	if 속빔:
		_확인(m.fill_textures.is_empty(), "속빔인데 fill_textures 가 차 있다")
		_확인(m.fill_mesh_material == null, "속빔인데 fill 셰이더가 붙었다")
	else:
		_확인(m.fill_mesh_material is ShaderMaterial, "채움인데 fill 셰이더가 없다")
		var f = (m.fill_mesh_material as ShaderMaterial).get_shader_parameter("alt_tex")
		_확인(f != null and String(f.resource_path).contains("/white/"),
			"fill alt_tex 가 white 폴더가 아니다")

	# 런타임 색 변경 — 머티리얼 하나로 검정도 흰색도 되어야 한다
	# 무색은 현재색()이 -1 을 돌려주는 것이 정상이다 (검정/흰색만 색을 가진다).
	_확인(int(n.현재상태) == 0, "시작상태가 무색이 아니다 (%d)" % int(n.현재상태))
	_확인(n.현재색() == -1, "무색인데 색이 잡힌다 (%d)" % n.현재색())
	n._전체_즉시(1)                                     # 1 = 검정
	_확인(int(n.현재상태) == 1, "검정으로 못 바꿨다")
	_확인(n.반대색인가(ColorDefs.WHITE), "검정 지형인데 흰 플레이어에게 안전하다고 나온다")
	n._전체_즉시(2)                                     # 2 = 흰색
	_확인(int(n.현재상태) == 2, "흰색으로 못 바꿨다")
	_확인(n.반대색인가(ColorDefs.BLACK), "흰 지형인데 검정 플레이어에게 안전하다고 나온다")
	n._전체_즉시(1)
	_확인(int(n.현재상태) == 1,
		"흰색에서 검정으로 되돌리지 못했다 (색 전용 머티리얼이었다면 여기서 막힌다)")
	n.강제_초기화()
	_확인(int(n.현재상태) == 0, "강제_초기화 후 무색이 아니다")

	n.queue_free()
	root.remove_child(n)


func _실행() -> void:
	print("런타임 색 시스템 x 새 타일셋 검증\n")
	for d in 대상:
		_검사(d[0], d[1], false)
		_검사(d[0], d[2], true)
	print("\n%d 통과 / %d 실패" % [통과, 실패])
	quit(0 if 실패 == 0 else 1)
