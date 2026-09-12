extends SceneTree
## ============================================================================
## [2026-09-05 신규 · STEP 5 개편] 조명 표준 실험실(Lighting Standard Lab) 씬 굽기
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/build_조명_실험실.gd
##   → res://scenes/테스트/Lighting_Standard_Lab.tscn
##
## ▣ 왜 이 씬이 필요한가
##   "노멀맵을 켠다 / CanvasModulate 를 얼마로 한다 / 보조광이 과한가" 를
##   **본 스테이지에서** 시험하면 값을 바꿀 때마다 레벨 아트가 통째로 흔들려서
##   무엇 때문에 좋아졌는지 알 수가 없다.
##
## ▣ ★[STEP 5] 세 구역을 한 화면에 놓는다
##   ┌ 구역 A  환경광만                 (Environment Only)
##   ├ 구역 B  환경광 + 플레이어 보조광  (Environment + Player Fill)
##   └ 구역 C  환경광 + 보조광 + 그림자  (Full Lighting)
##   각 구역에 BRICK · WOOD · GRASS · METAL 을 **같은 배치**로 깔고, Player 도 넣는다.
##
## ▣ 구역끼리 빛이 새지 않게 — light_mask
##   2D 라이트는 화면 전체에 작용하므로 구역을 그냥 멀리 두면 반경 700 짜리 빛이
##   옆 구역까지 물든다. → 구역마다 **광원 레이어**를 하나씩 준다.
##     구역 A = 레이어 1 · B = 2 · C = 3
##   지형/플레이어의 `light_mask` 와 광원의 `range_item_cull_mask` 를 맞춰 둔다.
##
## ▣ 원본 보호
##   지형은 전부 `scenes/집/스마트 매쉬 assets/` 의 TEMPLATE 인스턴스다.
##   템플릿·재질·텍스처를 한 글자도 안 고친다.
## ============================================================================

const 저장경로 := "res://scenes/테스트/Lighting_Standard_Lab.tscn"
const 컨트롤러 := "res://scripts/테스트/조명_실험실.gd"
const 플레이어_씬 := "res://scenes/player/Player.tscn"

## [이름, 템플릿]  ※ 재질은 템플릿 원본 그대로 쓴다.
##   노멀맵은 `지형.gd` + `노멀맵_표.gd` 가 런타임에 입히므로 여기서 바꿔 달 필요가 없다.
const 재질줄 := [
	["BRICK", "res://scenes/집/스마트 매쉬 assets/BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn"],
	["WOOD", "res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"],
	["GRASS", "res://scenes/집/스마트 매쉬 assets/GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn"],
	["METAL", "res://scenes/집/스마트 매쉬 assets/METAL_철판/TEMPLATE_METAL_SOLID.tscn"],
]

## 구역 = [이름, 설명]
const 구역들 := [
	["A_환경광만", "Environment Only"],
	["B_환경광_보조광", "Environment + Player Fill"],
	["C_전체", "Environment + Player Fill + Shadow"],
]

const 판_가로 := 512.0
const 판_세로 := 192.0
const 줄_간격 := 800.0      ## 재질 세로줄 사이 가로 간격 (METAL 템플릿이 624px 로 제일 넓다)
const 구역_간격 := 1250.0   ## 구역 사이 세로 간격
const 벽_y := 470.0         ## 벽(세로판)의 중심 y — 구역 원점 기준


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 뿌리 := Node2D.new()
	뿌리.name = "Lighting_Standard_Lab"
	뿌리.set_script(load(컨트롤러))

	# 뷰포트 기본 배경색(회색)이 그대로 보이면 "어두운 방"이 아니라 회색 판이 된다.
	var 바탕 := ColorRect.new()
	바탕.name = "바탕"
	바탕.color = Color(0.045, 0.045, 0.05)
	바탕.z_index = -100
	바탕.z_as_relative = false
	# 카메라가 줌아웃돼 있어서 넉넉히 깔지 않으면 화면 가장자리에 뷰포트 회색이 보인다.
	바탕.offset_left = -2600.0
	바탕.offset_top = -1200.0
	바탕.offset_right = 재질줄.size() * 줄_간격 + 2600.0
	바탕.offset_bottom = 구역들.size() * 구역_간격 + 1200.0
	바탕.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 바탕도 세 구역의 빛을 전부 받아야 한다(어느 구역에서도 벽처럼 밝아진다).
	바탕.light_mask = 0b111
	뿌리.add_child(바탕)
	바탕.owner = 뿌리

	var 어둠 := CanvasModulate.new()
	어둠.name = "어둠"
	어둠.color = Color(0.62, 0.62, 0.60)
	뿌리.add_child(어둠)
	어둠.owner = 뿌리

	for z in 구역들.size():
		_구역_만들기(뿌리, z)

	var cam := Camera2D.new()
	cam.name = "촬영카메라"
	cam.position = Vector2((재질줄.size() - 1) * 줄_간격 * 0.5,
		(구역들.size() - 1) * 구역_간격 * 0.5 + 250.0)
	cam.zoom = Vector2(0.30, 0.30)
	cam.enabled = true
	뿌리.add_child(cam)
	cam.owner = 뿌리

	var 팩 := PackedScene.new()
	var err := 팩.pack(뿌리)
	if err != OK:
		push_error("pack 실패: %s" % error_string(err))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(저장경로.get_base_dir())
	err = ResourceSaver.save(팩, 저장경로)
	print("조명 실험실: %s -> %s (구역 %d · 재질 %d)" % [
		error_string(err), 저장경로, 구역들.size(), 재질줄.size()])
	quit(0 if err == OK else 1)


func _구역_만들기(뿌리: Node2D, z: int) -> void:
	var 구역이름: String = 구역들[z][0]
	var 레이어 := 1 << z          # 구역 A=1, B=2, C=4
	var 원점 := Vector2(0.0, z * 구역_간격)

	var 구역 := Node2D.new()
	구역.name = 구역이름
	구역.position = 원점
	뿌리.add_child(구역)
	구역.owner = 뿌리

	for i in 재질줄.size():
		var 이름: String = 재질줄[i][0]
		var ps := load(재질줄[i][1]) as PackedScene
		if ps == null:
			push_error("템플릿 없음: %s" % 재질줄[i][1])
			continue
		var x := i * 줄_간격

		# ① 바닥판 — 위에서 오는 빛을 받는 면
		var 바닥 := ps.instantiate()
		바닥.name = "%s_바닥" % 이름
		바닥.position = Vector2(x, 0)
		(바닥 as CanvasItem).light_mask = 레이어
		구역.add_child(바닥)
		바닥.owner = 뿌리

		# ② 벽 — 옆에서 오는 빛을 받는 면(노멀맵의 좌우 반응을 보는 자리)
		var 벽 := ps.instantiate()
		벽.name = "%s_벽" % 이름
		벽.position = Vector2(x, 벽_y)
		벽.rotation = PI * 0.5          # 세로로 세운다 (점 배열은 안 건드린다)
		(벽 as CanvasItem).light_mask = 레이어
		구역.add_child(벽)
		벽.owner = 뿌리

		# ③ 환경 주광 — 재질마다 하나씩.
		#   하나로 전부 비추면 "재질 차이"인지 "거리 차이"인지 구분이 안 된다.
		var 빛 := PointLight2D.new()
		빛.name = "환경광_%s" % 이름
		빛.position = Vector2(x - 판_가로 * 0.60, -110.0)
		빛.energy = 1.6
		빛.height = 128.0
		빛.range_item_cull_mask = 레이어
		빛.shadow_item_cull_mask = 레이어
		빛.shadow_enabled = false      # 컨트롤러가 구역 C 에서만 켠다
		구역.add_child(빛)
		빛.owner = 뿌리

		# ④ 구역 C 에만 그림자를 만들 기둥(BRICK) + 빛가림.
		#   "그림자가 생기는가"를 보려면 빛과 판 사이에 막는 것이 있어야 한다.
		if z == 2:
			var 기둥_씬 := load(재질줄[0][1]) as PackedScene
			var 기둥 := 기둥_씬.instantiate()
			기둥.name = "그림자기둥_%s" % 이름
			# 광원(x-307, -110)과 벽(x, y 214~726) 사이에 세운다.
			# 그래야 기둥 그림자가 벽면을 가로질러 "빛이 막힌 자리"가 눈에 보인다.
			기둥.position = Vector2(x - 230.0, 250.0)
			기둥.rotation = PI * 0.5
			기둥.scale = Vector2(0.55, 0.22)   # 가늘고 긴 기둥
			(기둥 as CanvasItem).light_mask = 레이어
			구역.add_child(기둥)
			기둥.owner = 뿌리
			# 템플릿의 콜리전 사각형과 **같은 모양**의 가림막.
			# (실제 스테이지에서는 `tools/그림자_가림막.gd` 가 콜리전을 읽어서 만든다.
			#  실험실은 템플릿 규격이 512×192 로 고정이라 그 값을 그대로 쓴다)
			var occ := LightOccluder2D.new()
			occ.name = "빛가림"
			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([
				Vector2(-256, -96), Vector2(256, -96),
				Vector2(256, 96), Vector2(-256, 96)])
			occ.occluder = poly
			occ.occluder_light_mask = 레이어
			기둥.add_child(occ)
			occ.owner = 뿌리

	# ⑤ Player — 구역마다 하나. 보조광 ON/OFF 는 컨트롤러가 구역별로 정한다.
	var p_ps := load(플레이어_씬) as PackedScene
	if p_ps:
		var p := p_ps.instantiate()
		p.name = "Player"
		p.position = Vector2(판_가로 * 0.10, -150.0)
		# Player.tscn 안에도 Camera2D 가 있다. 그대로 두면 그쪽이 current 가 되어
		# 실험실 촬영 카메라가 무시된다.
		var pc := p.get_node_or_null("Camera2D")
		if pc:
			pc.enabled = false
		구역.add_child(p)
		p.owner = 뿌리
