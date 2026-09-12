extends SceneTree
## ============================================================================
## [2026-09-05 재구축] 조명 / 노멀맵 공식 검증 씬 굽기
##   → res://scenes/집/테스트_2층방_노멀맵.tscn
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/build_노멀맵_테스트씬.gd
##
## ▣ ★왜 다시 굽나 — 원래 씬이 "테스트 씬"이 아니었다
##   기존 파일은 `스테이지_1_2층방.tscn` 의 **통째 사본**이었다(루트에 `월드.gd`).
##   그래서 F6 로 켜면 게임이 그대로 돌고, 카메라가 `시작_위치 (150, -2050)`
##   — 6191 px 짜리 방의 **맨 왼쪽 복도 입구** — 에 붙은 플레이어를 따라간다.
##   실측(`tools/진단_테스트씬.gd`): **지형 24 개 중 20 개가 카메라 밖**이었고,
##   노멀맵 테스트 광원은 (1142 ± 900) 을 왕복하는데 카메라 오른쪽 끝이 x = 1856 이라
##   주기의 대부분을 화면 밖에서 보냈다. GRASS·IRON 은 아예 없었고
##   LightOccluder2D 도 0 개였다.
##
##   → 이 씬을 **고정 카메라 Lab** 으로 다시 만든다. 게임처럼 플레이하는 씬이 아니다.
##
## ▣ 새로 만드는 것이 없다 (지시서 §15)
##   지형은 전부 기존 TEMPLATE 인스턴스, 재질·노멀맵·CanvasTexture 는 STEP 4/5 에서
##   만든 것을 **그대로 재사용**한다. 노멀맵 PNG 를 다시 굽지 않는다.
##
## ▣ 카메라는 코드가 맞춘다
##   컨트롤러가 실행 시 모든 `테스트_*` 지형의 실제 경계를 재서 카메라를 맞춘다.
##   배치를 바꿔도 "화면 밖으로 나가서 안 보이는" 사고가 다시 안 난다.
## ============================================================================

const 저장경로 := "res://scenes/집/테스트_2층방_노멀맵.tscn"
const 컨트롤러 := "res://scripts/테스트/노멀맵_테스트_랩.gd"
const 플레이어_씬 := "res://scenes/player/Player.tscn"

const T_BRICK := "res://scenes/집/스마트 매쉬 assets/BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn"
const T_WOOD := "res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"
const T_GRASS := "res://scenes/집/스마트 매쉬 assets/GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn"
const T_METAL := "res://scenes/집/스마트 매쉬 assets/METAL_철판/TEMPLATE_METAL_SOLID.tscn"

## 배치표 — [노드이름, 템플릿, 위치, 회전(도)]
##   템플릿 한 판은 512 × 192 다(METAL 만 안쪽에 오프셋이 있어 조금 다르다).
##   지시서 §4 의 스케치를 그대로 옮겼다:
##       BRICK WALL
##       ███████████
##             Player ●
##       WOOD PLATFORM
##       ━━━━━━━━━━━━━
##            GRASS      IRON
##            █████      █████
const 배치 := [
	# BRICK 벽 — 노멀맵을 육안으로 볼 **주 대상**. 좌/우 광원에서 같은 거리에 둔다.
	["테스트_브릭", T_BRICK, Vector2(-60, -180), 0.0],
	# 세로 벽 — LEFT 광원과 BRICK 벽 **사이**에 선다.
	#   그래야 그림자를 켰을 때 "빛이 막힌 자리"가 **밝은 면 위에** 나타난다.
	#   (빛이 안 닿는 곳에 가림막을 두면 그림자를 켜도 화면이 안 바뀐다 — 실제로 그랬다)
	["테스트_벽", T_BRICK, Vector2(-470, -300), 90.0],
	# 오른쪽 나무 — RIGHT 광원 쪽 재질
	["테스트_우드", T_WOOD, Vector2(600, -180), 0.0],
	# 플레이어가 서는 나무 발판.
	#   환경광에서 멀어서 어둡다 → **보조광이 무엇을 하는지**가 여기서 제일 잘 보인다.
	["테스트_플랫폼", T_WOOD, Vector2(60, 90), 0.0],
	["테스트_그래스", T_GRASS, Vector2(-300, 380), 0.0],
	["테스트_아이언", T_METAL, Vector2(480, 380), 0.0],
]


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 뿌리 := Node2D.new()
	뿌리.name = "노멀맵_테스트_랩"
	뿌리.set_script(load(컨트롤러))

	# ── 어두운 바탕 ──
	# 뷰포트 기본 배경색(회색)이 보이면 "어두운 방"이 아니라 회색 판이 된다.
	var 배경 := ColorRect.new()
	배경.name = "배경"
	배경.color = Color(0.05, 0.05, 0.055)
	배경.z_index = -100
	배경.z_as_relative = false
	배경.offset_left = -3000.0
	배경.offset_top = -2200.0
	배경.offset_right = 3000.0
	배경.offset_bottom = 2200.0
	배경.mouse_filter = Control.MOUSE_FILTER_IGNORE
	뿌리.add_child(배경)
	배경.owner = 뿌리

	# ── CanvasModulate — ★프로덕션 표준과 같은 0.62 (지시서 §10) ──
	#   테스트 씬만 밝게 해서 노멀맵이 좋아 보이게 만드는 것은 금지다.
	var 어둠 := CanvasModulate.new()
	어둠.name = "어둠"
	어둠.color = Color(0.62, 0.62, 0.60)
	뿌리.add_child(어둠)
	어둠.owner = 뿌리

	# ── 지형 ──
	for 줄 in 배치:
		var ps := load(줄[1]) as PackedScene
		if ps == null:
			push_error("템플릿 없음: %s" % 줄[1])
			continue
		var n := ps.instantiate()
		n.name = String(줄[0])
		(n as Node2D).position = 줄[2]
		(n as Node2D).rotation_degrees = float(줄[3])
		뿌리.add_child(n)
		n.owner = 뿌리

	# ── 환경 주광 — BRICK 벽의 **왼쪽 위** (지시서 §6) ──
	#   처음에는 광원 하나만 쓴다. 값은 조명 표준 그대로.
	var 환경광 := PointLight2D.new()
	환경광.name = "환경광"
	환경광.position = Vector2(-430, -330)
	환경광.energy = 1.6
	환경광.height = 128.0
	환경광.shadow_enabled = false        # 컨트롤러가 켠다 (지시서 §6: 처음엔 OFF)
	뿌리.add_child(환경광)
	환경광.owner = 뿌리

	# ── 페인트 코어 (HUD 게이지가 읽을 자원) ──
	var 코어 := Node.new()
	코어.name = "페인트코어"
	코어.set_script(load("res://scripts/스마트월드/페인트_코어.gd"))
	# ⚠ 두 번째 인자(persistent)를 안 주면 씬 파일에 그룹이 저장되지 않는다.
	#   그러면 HUD 가 `get_first_node_in_group("페인트코어")` 로 코어를 못 찾아 안 뜬다.
	코어.add_to_group("페인트코어", true)
	뿌리.add_child(코어)
	코어.owner = 뿌리

	# ── Player — 나무 발판 위 ──
	#   `플레이어_보조광` 은 Player.tscn 안에 이미 들어 있다(STEP 5).
	var p_ps := load(플레이어_씬) as PackedScene
	if p_ps:
		var p := p_ps.instantiate()
		p.name = "테스트_Player"
		# 나무 발판 `테스트_플랫폼`(60, 90) 의 윗면 = -6. 발이 닿게 세운다.
		p.position = Vector2(60, -6)
		# ⚠ Player.tscn 안의 Camera2D 가 current 를 가로채면 Lab 카메라가 무시된다.
		var pc := p.get_node_or_null("Camera2D")
		if pc:
			pc.enabled = false
		뿌리.add_child(p)
		p.owner = 뿌리

	# ── Lab 카메라 (컨트롤러가 내용물에 맞춰 위치·줌을 정한다) ──
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.enabled = true
	뿌리.add_child(cam)
	cam.owner = 뿌리

	var 팩 := PackedScene.new()
	var err := 팩.pack(뿌리)
	if err != OK:
		push_error("pack 실패: %s" % error_string(err))
		quit(1)
		return
	err = ResourceSaver.save(팩, 저장경로)
	print("노멀맵 테스트 랩: %s -> %s (지형 %d개)" % [
		error_string(err), 저장경로, 배치.size()])
	quit(0 if err == OK else 1)
