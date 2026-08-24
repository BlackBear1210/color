extends Node
## [2026-07-18 도형 · 신규] 존 공용 라이팅/분위기 리그 — "고퀄리티 2D" 의 정체.
##
## 참고한 원리 (Godot 공식 "2D lights and shadows" + GDQuest "Lighting with
## 2D normal maps"): 2D 라도 텍스처에 노멀맵을 붙이면 Light2D 가 픽셀 단위로
## 입체 음영을 계산한다 — "배경이 빛을 받으면 색이 변하는" 그 기법이다.
## 구성 요소 3가지:
##  1. CanvasModulate: 화면 전체를 살짝 가라앉힘 (환경광). 이게 있어야 라이트가 "보인다".
##  2. PlayerLight(PointLight2D): 플레이어를 따라다니는 부드러운 원형 광원.
##     노멀맵이 있는 타일·배경은 이 빛의 방향에 따라 음영이 실시간으로 변한다.
##  3. 배경 노멀맵 주입: Parallax 배경 스프라이트를 CanvasTexture(원본+노멀맵)로
##     런타임 교체 — 씬 파일은 그대로, 노멀맵 PNG 가 없으면 조용히 생략.
##     (노멀맵 생성: tools/generate_normal_maps.gd 를 헤드리스로 1회 실행)
## 비네트는 카메라 전환과 강도를 함께 제어하는 `ProtoCamera` 한 곳에서 담당한다.
##
## 사용법: 존 루트에 add_child 후 setup(player) 호출. (모든 씬 파일 무수정)
class_name ZoneVisuals

## 환경광 — 1.0(무효)보다 조금 낮춰 라이트 대비를 만든다. 너무 낮으면 가독성 붕괴.
const AMBIENT := Color(0.82, 0.82, 0.88)
## 플레이어 광원 세기·반경(px)
const LIGHT_ENERGY: float = 1.15
const LIGHT_RADIUS: float = 520.0
const NORMAL_DIR := "res://assets/textures/normal/"

## [2026-07-25 도형] 환경광을 씬마다 다르게 줄 수 있게 열어둔다.
## 새 스테이지(stage_lab)는 배경·프롭이 많아 기본값(0.82)이면 전체가 너무 어둡다.
## setup() 전에 `visuals.환경광 = Color(...)` 로 덮어쓰면 된다. 기존 존은 그대로 AMBIENT.
var 환경광: Color = AMBIENT

var _player: Node2D
var _light: PointLight2D

func setup(p_player: Node2D) -> void:
	_player = p_player
	_add_ambient()
	_add_player_light()
	_inject_bg_normal_maps()

## 1) 환경광 — CanvasModulate 는 같은 캔버스(월드)만 어둡게 하고 UI(CanvasLayer)는 건드리지 않는다
func _add_ambient() -> void:
	var cm := CanvasModulate.new()
	cm.name = "Ambient"
	cm.color = 환경광
	add_child(cm)

## 2) 플레이어를 따라다니는 원형 광원 (GradientTexture2D 라디얼 = 외부 에셋 0)
func _add_player_light() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	_light = PointLight2D.new()
	_light.name = "PlayerLight"
	_light.texture = tex
	_light.texture_scale = LIGHT_RADIUS * 2.0 / 256.0
	_light.energy = LIGHT_ENERGY
	add_child(_light)

func _process(_delta: float) -> void:
	# 광원이 플레이어 가슴 높이를 따라다닌다 (자식으로 붙이면 비균등 스케일에 왜곡되므로 직접 추적)
	if _light and _player and is_instance_valid(_player):
		_light.global_position = _player.global_position + Vector2(0, -40)

## 3) 배경 스프라이트에 노멀맵 주입 — <텍스처이름>_n.png 가 있으면 CanvasTexture 로 감싼다
func _inject_bg_normal_maps() -> void:
	for spr in _find_sprites(get_parent()):
		var tex := spr.texture
		if tex == null or tex is CanvasTexture:
			continue
		var base := tex.resource_path.get_file().get_basename()
		var normal_path := NORMAL_DIR + base + "_n.png"
		if not ResourceLoader.exists(normal_path):
			continue
		var ct := CanvasTexture.new()
		ct.diffuse_texture = tex
		ct.normal_texture = load(normal_path)
		spr.texture = ct

func _find_sprites(root: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Sprite2D:
			out.append(n)
		stack.append_array(n.get_children())
	return out
