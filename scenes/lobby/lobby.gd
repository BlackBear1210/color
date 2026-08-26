extends Control
## [2026-07-18 도형 · v2 전면 리디자인] 로비 = "게임 세계의 축소판" 디오라마.
##
## v1(사선 반전 오버레이)이 "이미지가 안 살아난다"는 피드백을 받아 갈아엎음.
## 새 콘셉트: 타이틀 아래에 ★실제 인게임 요소로 만든 작은 세계★를 보여준다 —
##  - 왼쪽 = 흑 지형 + 흑 캐릭터 / 오른쪽 = 백 지형 + 백 캐릭터, 가운데 = 회색(중립)
##    → 시작 화면만 봐도 "흑백 반전 + 회색 중립"이라는 핵심 규칙이 읽힌다
##  - 캐릭터는 인게임과 같은 스프라이트(player_frames.tres)의 idle 모션 —
##    두 색의 캐릭터가 회색 경계를 사이에 두고 마주 보는 구도 (반전의 대칭)
##  - 무색 발판(점 무늬 = 칠하기 퍼즐), 패럴랙스 배경, 노멀맵 라이팅, 부유 먼지
##    → 모험(원경) + 퍼즐(발판)의 분위기를 한 화면에
##  - 전부 프로젝트 안의 인게임 에셋 재사용 = 외부 에셋 0, 아트 교체 시 자동 반영
##
## 구조: lobby.tscn 은 UI(CanvasLayer)만 갖고, 디오라마는 이 스크립트가
## Backdrop(Node2D) 아래에 런타임 조립한다 (존 조립과 같은 방식).
## 설정(볼륨·전체화면)은 v1 그대로 user://settings.cfg.

# ════════════════════════════════════════════════════════════════════════════
# [2026-08-07 도형] 로비 메뉴 재구성
# ----------------------------------------------------------------------------
# 도형님 지시:
#   "f5를 눌렀을때 로비에서 나머지 스테이지는 따로 파일에 모아두고
#    이제 시작을 누르면 동현 테스트 월드 제작에 있는 씬들이 시작되게 하고
#    스마트월드를 누르면 스마트월드1과 스마트월드2까지 실행이 될 수 있게 변경"
#
# 바뀐 메뉴 구성
#   시작            → 동현 테스트월드 라인 (타일맵 스테이지)
#   스마트월드      → 스마트월드 1 → (통로) → 스마트월드 2
#   기타 스테이지   → 예전 스테이지 1~5 / zone 선택 화면 (한 칸 아래로 내림)
#   설정 / 나가기   → 기존 그대로
#
# ⚠ lobby.tscn 파일은 **건드리지 않는다.** 버튼은 전부 런타임에 복제해서 끼운다
#   (9차부터 지켜온 방식 — 씬 파일을 안 고치면 팀원과 병합 충돌이 나지 않는다).
# ════════════════════════════════════════════════════════════════════════════

## ★"시작" — 동현님이 만든 타일맵 스테이지. 1-1 과 1-2 가 한 씬에 이어 붙어 있고,
##   중간에서 카메라 구역이 바인식으로 전환된다(`카메라_연출.gd`).
const MAIN_SCENE := "res://scenes/world_1/stage_1-1, 1-2.tscn"
## 재질 실험용 씬 (동현 테스트 월드 제작 폴더). 시작 화면 아래 별도 버튼.
## ⚠[2026-08-20] `df03f3d 폐기 라인 정리` 로 이 씬이 삭제됐다. 메뉴 버튼도 같이 뺐다.
##   상수만 남겨 두면 `test_lobby_flow` 가 "목적지 씬이 없다" 로 잡는다 —
##   버튼을 눌러 검은 화면으로 떨어지는 것보다 검사가 먼저 잡는 편이 낫다. 그래서 지운다.
## const 테스트월드_SCENE := "res://scenes/world_1/동현 테스트 월드 제작/테스트월드제작.tscn"
## ★"스마트월드" — SS2D 지형 라인. 1 편으로 들어가면 통로로 2 편까지 이어진다.
const 스마트월드_SCENE := "res://scenes/스마트월드/스마트월드_1.tscn"
## [2026-07-24 도형] 예전 챕터(스테이지 1~5 + 셰이더/VFX 비교존) 선택 화면
## ⚠[2026-08-20] 같은 커밋에서 구 스테이지 라인(스테이지_1~5 · 스테이지_선택)이 삭제됐다.
## const CHAPTER_SCENE := "res://scenes/스테이지/스테이지_선택.tscn"
## 구 심리스 월드 (zone1~3). 지금은 "기타" 로 내려갔다.
## ⚠[2026-08-20] 같은 커밋에서 삭제됨. 쓰는 곳이 없어 상수만 남아 있었다.
## const 구_월드_SCENE := "res://scenes/world_1/world_1.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const PLAYER_FRAMES := "res://assets/p/player_frames.tres"
const TILESET := "res://assets/tilesets/terrain_tileset.tres"
const NORMAL_DIR := "res://assets/textures/normal/"
## 디오라마 기준 해상도 — 창 크기가 달라지면 cover 방식으로 확대해 맞춘다
const BASE := Vector2(1152, 648)
## 캐릭터 시트 규격 (player_anim.gd 와 동일 값)
const FRAME_PX := 640.0
const FOOT_Y := 567.0
const CHAR_HEIGHT := 132.0

@onready var backdrop: Node2D = $Backdrop
@onready var title: Label = $UILayer/Title
@onready var settings_panel: Control = $UILayer/SettingsPanel
@onready var volume_slider: HSlider = $UILayer/SettingsPanel/Panel/VBox/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckBox = $UILayer/SettingsPanel/Panel/VBox/FullscreenCheck

var _time: float = 0.0
var _light: PointLight2D
var _bg_layers: Array = []           # [Sprite2D, 기준위치, 드리프트 속도] 목록

func _ready() -> void:
	# ★[2026-08-08] 시작 버튼의 목적지가 스마트월드 1 편으로 바뀌었다(§_챕터_버튼_추가).
	$UILayer/Menu/StartButton.pressed.connect(_on_start)
	$UILayer/Menu/SettingsButton.pressed.connect(func() -> void: settings_panel.visible = true)
	$UILayer/Menu/QuitButton.pressed.connect(func() -> void: get_tree().quit())
	$UILayer/SettingsPanel/Panel/VBox/BackButton.pressed.connect(_on_settings_back)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	# ★[2026-07-24 도형] 신규 챕터(스테이지 1~5, 페인트 v3) 입구를 로비에 추가.
	#   lobby.tscn 파일은 건드리지 않고, 기존 시작 버튼을 복제해 런타임에 끼워 넣는다
	#   (씬 파일을 안 고치면 팀원과 병합 충돌이 나지 않는다 — 9차부터 지켜온 방식).
	_챕터_버튼_추가()
	_load_settings()

## 시작 버튼 바로 아래에 진입 메뉴들을 만든다.
##
## ★[2026-08-07 도형] 메뉴를 재구성했다.
##   버튼은 `StartButton` 을 **복제**해서 만든다 → 폰트·테마·크기가 저절로 같아지고
##   lobby.tscn 을 수정하지 않아 다른 작업자와 병합 충돌이 안 난다.
##
##   시작 버튼의 글자도 여기서 바꾼다("시작" → "시작 — 스테이지 1-1 / 1-2").
##   씬 파일을 안 고치고 텍스트만 바꾸는 게 목적이다.
func _챕터_버튼_추가() -> void:
	var 메뉴 := $UILayer/Menu
	var 원본 := $UILayer/Menu/StartButton as Button
	if 원본 == null:
		return

	# ★[2026-08-08] "시작" 이 이제 스마트월드 1 편이다.
	#   예전에는 시작 = 타일맵 씬(`stage_1-1, 1-2`)이었는데, 그 지형이 통째로
	#   스마트월드 1·2 편으로 옮겨졌다(`tools/스마트월드_체인.gd`).
	#   같은 레벨이 두 군데서 굴러가면 어느 쪽을 고쳐야 하는지 알 수 없게 된다.
	#   → 시작은 **스마트월드 1 편**. 타일맵 원본은 아래 "원본 타일맵" 으로 내렸다.
	원본.text = "시작  ·  %s" % 챕터.표시이름(1)

	var 순서 := 원본.get_index()

	# ── ★[2026-08-26] 집 챕터 바로가기 ──────────────────────────────────────
	# `scenes/집/집_*.tscn`(원화 배경 4 방 + 새 복도·계단)은 **챕터표에 없다.**
	#   `연결통로.다음_씬` 으로만 이어져 있고, 기존 5·6·7(거실/굴뚝/지붕 원본)과
	#   어느 쪽을 본편으로 삼을지는 아직 도형님 결정 대기다(2026-08-25 기록).
	#   그래서 챕터표는 건드리지 않고 **버튼 한 개만** 얹는다.
	#   여기서 시작하면 2층 방 → 복도·계단 → 거실 → 부엌 → 굴뚝까지 걸어서 이어진다.
	순서 += 1
	var 집버튼 := _메뉴버튼(원본, "HouseButton",
		"      ↳ 집 · 2층 방부터 (원화 배경)", 메뉴, 순서)
	집버튼.pressed.connect(func() -> void:
		StageTransition.change_scene(self, "res://scenes/집/집_2층방.tscn"))

	# ── 스테이지 바로가기 ──
	# 챕터표를 읽어 **자동으로** 만든다. 스테이지를 추가해도 로비를 고칠 필요가 없다.
	# (예전에는 버튼이 코드에 박혀 있어서 3 편을 만들면 로비도 같이 고쳐야 했다)
	for 정보 in 챕터.스테이지표:
		var 번호: int = int(정보["번호"])
		if 번호 == 1:
			continue                     # 1 편은 위의 "시작" 버튼이 담당한다
		순서 += 1
		var b := _메뉴버튼(원본, "Stage%dButton" % 번호,
			"      ↳ %s" % 챕터.표시이름(번호), 메뉴, 순서)
		# ★람다가 도는 시점에는 반복 변수가 끝값이 되어 있을 수 있다 → 지금 값을 묶어 둔다
		var 경로 := 챕터.씬경로(번호)
		b.pressed.connect(func() -> void:
			StageTransition.change_scene(self, 경로))

	# ── 원본 타일맵 씬 (대조용) ──
	# 변환이 원본과 같은지 눈으로 확인할 때 쓴다. 레벨 디자인의 출처이기도 하다.
	순서 += 1
	var 원본씬 := _메뉴버튼(원본, "TileMapButton", "원본 타일맵 (대조용)", 메뉴, 순서)
	원본씬.pressed.connect(func() -> void:
		StageTransition.change_scene(self, MAIN_SCENE))

	# ── [2026-08-20] "테스트월드 제작" · "기타 스테이지" 버튼을 뺐다 ──
	#   `df03f3d 폐기 라인 정리` 에서 그 목적지 씬들(zone_* · 스테이지_* · 테스트월드제작)이
	#   삭제됐다. 버튼만 남겨 두면 **눌렀을 때 검은 화면으로 떨어진다** —
	#   씬 전환은 실패해도 예외를 안 던지기 때문에 조용히 망가진다.
	#   되살리려면 씬을 먼저 복구하고 상수(위 주석 처리된 두 줄)부터 되돌릴 것.

	_build_diorama()
	_add_atmosphere()
	# 창 크기가 바뀌어도 디오라마가 화면을 덮도록 (cover 스케일)
	get_viewport().size_changed.connect(_fit_backdrop)
	_fit_backdrop()

## 시작 버튼을 복제해 메뉴 버튼 하나를 만든다 (테마·폰트를 그대로 물려받는다).
func _메뉴버튼(원본: Button, 이름: String, 글자: String,
		메뉴: Node, 위치: int) -> Button:
	var b := 원본.duplicate() as Button
	b.name = 이름
	b.text = 글자
	# duplicate() 는 **연결된 시그널까지 복제하지 않는다**(Godot 4 기본).
	# 그래도 혹시 모를 중복 연결을 막기 위해 pressed 를 명시적으로 끊고 시작한다.
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	메뉴.add_child(b)
	메뉴.move_child(b, 위치)
	return b


func _process(delta: float) -> void:
	_time += delta
	# 타이틀 호흡: 미세한 스케일 맥동 — 정지 화면의 "죽은 느낌" 제거
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ONE * (1.0 + 0.010 * sin(_time * 1.4))
	# 중앙 광원 맥동 — 촛불처럼 아주 천천히
	if _light:
		_light.energy = 1.15 + 0.12 * sin(_time * 0.9) + 0.05 * sin(_time * 2.7)
	# 배경 패럴랙스 층별 드리프트 — 카메라 없이도 원경이 살아 있는 느낌
	for entry: Array in _bg_layers:
		var spr: Sprite2D = entry[0]
		spr.position.x = (entry[1] as Vector2).x + sin(_time * (entry[2] as float)) * 9.0

# ══ 디오라마 조립 ═══════════════════════════════════════════════════════
func _build_diorama() -> void:
	# 0) 환경광 — 이게 있어야 광원 대비가 생긴다 (UI 는 CanvasLayer 라 안 어두워짐)
	var cm := CanvasModulate.new()
	cm.name = "Ambient"
	cm.color = Color(0.85, 0.85, 0.92)
	backdrop.add_child(cm)

	# 1) 하늘: 위(어둠) → 아래(옅은 회색) 세로 그라데이션 — 새벽빛 같은 원경
	var sky_grad := Gradient.new()
	sky_grad.set_color(0, Color(0.05, 0.05, 0.07))
	sky_grad.set_color(1, Color(0.26, 0.26, 0.30))
	var sky_tex := GradientTexture2D.new()
	sky_tex.gradient = sky_grad
	sky_tex.fill_from = Vector2(0.5, 0.0)
	sky_tex.fill_to = Vector2(0.5, 1.0)
	sky_tex.width = 16
	sky_tex.height = 256
	var sky := Sprite2D.new()
	sky.name = "Sky"
	sky.texture = sky_tex
	sky.centered = false
	sky.scale = Vector2(BASE.x / 16.0, BASE.y / 256.0)
	# ⚠ z_index 를 음수로 주면 안 된다: 로비의 BG ColorRect(z=0)가 같은 캔버스에 있어서
	# 음수 z 는 그 "아래"로 들어가 가려진다 (z-index 는 트리 순서보다 우선).
	# → 전부 z=0 으로 두고 Backdrop 안의 트리 순서(하늘→원경→지형)로 겹침을 만든다.
	backdrop.add_child(sky)

	# 2) 패럴랙스 배경 3층 (인게임과 같은 에셋 + 노멀맵) — 지평선 너머 = 모험의 예감
	for def: Array in [
		["bg_far",  Vector2(-224, -150), 0.11],
		["bg_mid",  Vector2(-224, -30),  0.17],
		["bg_near", Vector2(-224, 230),  0.23],
	]:
		var spr := Sprite2D.new()
		spr.name = def[0]
		spr.centered = false
		spr.position = def[1]
		var tex: Texture2D = load("res://assets/textures/bg/%s.svg" % def[0])
		var normal_path: String = NORMAL_DIR + def[0] + "_n.png"
		if ResourceLoader.exists(normal_path):
			var ct := CanvasTexture.new()   # 노멀맵 포함 → 광원에 입체 반응
			ct.diffuse_texture = tex
			ct.normal_texture = load(normal_path)
			spr.texture = ct
		else:
			spr.texture = tex
		backdrop.add_child(spr)
		_bg_layers.append([spr, def[1], def[2]])

	# 3) 지형: 왼쪽 흑 / 가운데 회색(중립) / 오른쪽 백 — 게임 규칙의 한 줄 요약
	var tm := TileMapLayer.new()
	tm.name = "Ground"
	tm.tile_set = load(TILESET)
	backdrop.add_child(tm)
	const BLACK := Vector2i(0, 0)
	const WHITE := Vector2i(1, 0)
	const GRAY := Vector2i(2, 0)
	const U1 := Vector2i(3, 0)
	const U2 := Vector2i(4, 0)
	const U3 := Vector2i(5, 0)
	for y in [17, 18, 19]:                       # 바닥 3줄 (y17 = 화면 y 544)
		for x in range(-2, 16):
			tm.set_cell(Vector2i(x, y), 0, BLACK)
		for x in range(16, 21):
			tm.set_cell(Vector2i(x, y), 0, GRAY)
		for x in range(21, 39):
			tm.set_cell(Vector2i(x, y), 0, WHITE)
	# 공중 발판: 칠하기 퍼즐(점 무늬 무색 발판)이 있다는 예고 — 좌우 대칭 배치
	# 발판은 화면 좌우 가장자리에만 — 중앙(타이틀·메뉴)을 가리지 않게
	for cell: Array in [
		[2, 13, BLACK], [3, 13, BLACK],          # 흑 발판 (좌하)
		[6, 11, U1], [7, 11, U1],                # 무색 1발
		[3, 9, U3],                              # 무색 3발 (좌상)
		[33, 12, WHITE], [34, 12, WHITE],        # 백 발판 (우하)
		[30, 10, U2], [31, 10, U2],              # 무색 2발
		[34, 8, U1],                             # 무색 1발 (우상)
	]:
		tm.set_cell(Vector2i(cell[0], cell[1]), 0, cell[2])

	# 4) ★캐릭터 2체: 흑/백이 회색 경계를 사이에 두고 마주 보는 구도 (반전의 대칭)
	#    인게임과 같은 시트의 idle 모션 — 로비가 곧 게임 소개가 된다
	#    (메뉴 버튼 폭 416~736 을 피해서 바깥쪽에 배치)
	_spawn_character("black_idle", Vector2(310, 544), false)
	_spawn_character("white_idle", Vector2(842, 544), true)

	# 5) 중앙 광원 — 두 캐릭터 사이 위에서 떨어지는 빛 (노멀맵 지형이 입체로 반응)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var ltex := GradientTexture2D.new()
	ltex.gradient = grad
	ltex.fill = GradientTexture2D.FILL_RADIAL
	ltex.fill_from = Vector2(0.5, 0.5)
	ltex.fill_to = Vector2(0.5, 0.0)
	ltex.width = 256
	ltex.height = 256
	_light = PointLight2D.new()
	_light.name = "CenterLight"
	_light.texture = ltex
	_light.position = Vector2(576, 200)
	_light.texture_scale = 5.5                   # 반경 약 700px
	_light.energy = 1.15
	backdrop.add_child(_light)

	# 6) 부유 먼지 — 빛 기둥 사이를 떠다니는 입자 (화면에 공기를 넣는다)
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.position = BASE * 0.5
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 7.0                        # 시작부터 화면에 퍼져 있게
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(600, 330)
	dust.direction = Vector2(0, -1)
	dust.spread = 30.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.4
	dust.color = Color(1, 1, 1, 0.13)
	backdrop.add_child(dust)

## 인게임 캐릭터 시트(player_frames.tres)로 idle 캐릭터 한 체 배치
func _spawn_character(anim: String, foot_pos: Vector2, flip: bool) -> void:
	if not ResourceLoader.exists(PLAYER_FRAMES):
		return   # 시트가 없어도 로비는 깨지지 않는다
	var spr := AnimatedSprite2D.new()
	spr.name = "Char_" + anim
	spr.sprite_frames = load(PLAYER_FRAMES)
	spr.animation = anim
	spr.flip_h = flip
	var k := CHAR_HEIGHT / FRAME_PX
	spr.scale = Vector2(k, k)
	# 발끝(FOOT_Y)이 foot_pos 에 닿도록 중심 보정 (player_anim.gd 와 같은 계산)
	spr.position = foot_pos - Vector2(0, (FOOT_Y - FRAME_PX * 0.5) * k)
	spr.z_index = 2
	backdrop.add_child(spr)
	spr.play(anim)

## 창 크기가 바뀌어도 디오라마가 화면을 가득 덮도록 cover 스케일 + 중앙 정렬
func _fit_backdrop() -> void:
	var vp := get_viewport_rect().size
	var s := maxf(vp.x / BASE.x, vp.y / BASE.y)
	backdrop.scale = Vector2(s, s)
	backdrop.position = (vp - BASE * s) * 0.5

# ══ 분위기 레이어: 필름 그레인 + 비네트 (인게임 zone_visuals 와 톤 통일) ═
func _add_atmosphere() -> void:
	var rect := ColorRect.new()
	rect.name = "GrainVignette"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "
shader_type canvas_item;
uniform float grain_amount = 0.045;
uniform float vignette_strength = 0.42;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// 필름 그레인: 매 프레임 시드가 바뀌는 픽셀 노이즈
	float g = (hash(UV * vec2(1152.0, 648.0) + vec2(TIME * 61.7, TIME * 13.3)) - 0.5) * grain_amount;
	// 비네트: 중심에서 멀수록 어둡게. 그레인은 어두움의 미세한 흔들림으로 얹는다
	float d = distance(UV, vec2(0.5)) * 1.35;
	float v = smoothstep(0.5, 1.05, d) * vignette_strength;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v + g, 0.0, 1.0));
}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	$UILayer.add_child(rect)   # UI 레이어 맨 위 = 화면 전체 질감 통일

# ══ 메뉴 / 설정 (v1 그대로) ═════════════════════════════════════════════
## "시작" — ★[2026-08-08] 목적지가 스마트월드 1 편으로 바뀌었다.
## 여기서 들어가면 통로를 따라 2 → 3 → 4 편까지 끊김 없이 이어진다
## (챕터가 넘어가는 3 → 4 구간에서는 배경·BGM 이 같이 바뀐다).
func _on_start() -> void:
	StageTransition.change_scene(self, 스마트월드_SCENE)

func _on_settings_back() -> void:
	settings_panel.visible = false
	_save_settings()

func _on_volume_changed(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(v, 0.0001, 1.0)))
	AudioServer.set_bus_mute(bus, v <= 0.001)

func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 파일이 없으면 그냥 기본값 사용
	var vol: float = cfg.get_value("audio", "master", 1.0)
	var full: bool = cfg.get_value("video", "fullscreen", false)
	volume_slider.set_value_no_signal(vol)
	_on_volume_changed(vol)
	fullscreen_check.set_pressed_no_signal(full)
	_on_fullscreen_toggled(full)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", volume_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_PATH)
