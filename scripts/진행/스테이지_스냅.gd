extends Node
## ============================================================================
## [2026-10-09 Claude 신규] 스테이지 스냅 — 플레이 중 한 장면을 '사진'으로 찍어 두었다가 클리어하면 보드 조각에 넣는다
## ----------------------------------------------------------------------------
## ▣ 도형님: "검정색 사진 대신 플레이어가 플레이하는 인게임 속 해당 스테이지의 한 부분을 랜덤하게 찍어서 넣는 거야."
## ▣ 하는 일
##   1) 들어오면 `게임진행.방문_기록` — 숨은 스테이지는 이걸로 '입구를 찾았다' 가 된다(보드에 점선 실이 나타난다).
##   2) 들어온 뒤 무작위 시각(6~40초)에, 플레이어가 **바닥에 서 있고 살아 있을 때** 화면 한 장을 메모리에 찍는다.
##      화면 가장자리의 HUD(왼위 물감 · 위 가운데 시계)는 잘라 낸다(가운데 70%×74%) → 480×270 으로 줄인다.
##      한 번 찍은 뒤에도 가끔(25%) 더 늦은 장면으로 바꿔 찍는다 — 매번 같은 첫 화면만 남지 않게.
##   3) 스테이지가 클리어되면(월드 `클리어됨` 신호) 찍어 둔 사진을 user://스냅/<스테이지>.png 로 저장한다.
##      (클리어 못 하고 나가면 버린다 — 보드에는 '깬 판' 의 사진만 들어간다)
## ▣ 헤드리스(시험)에서는 화면이 없으니 찍지 않는다.
## ============================================================================

const 폴더 := "user://스냅/"
const 크기 := Vector2i(480, 270)

var _찍을_때 := 0.0
var _t := 0.0
var _사진: Image = null
var _씬이름 := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var 씬 := get_parent()
	_씬이름 = 씬.scene_file_path.get_file().get_basename()
	게임진행.방문_기록(씬.scene_file_path)
	if 씬.has_signal("클리어됨"):
		씬.connect("클리어됨", _저장)
	_찍을_때 = randf_range(6.0, 40.0)
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if _t < _찍을_때:
		return
	var p := get_parent().get_node_or_null("Player") as CharacterBody2D
	if p == null or not p.is_physics_processing() or not p.is_on_floor():
		return                        # 서 있을 때까지 기다린다(공중·죽는 중 사진 X)
	_찍기()
	# 다음 찍을 때 — 25% 확률로 나중 장면으로 갈아 찍는다, 아니면 그만
	if randf() < 0.25:
		_찍을_때 = _t + randf_range(15.0, 45.0)
	else:
		set_process(false)


func _찍기() -> void:
	# 헤드리스(시험)에는 화면 그림이 없다 — 찍지 않는다(빈 텍스처에서 이미지를 꺼내면 엔진 오류)
	if DisplayServer.get_name() == "headless" or get_viewport().get_texture() == null:
		return
	var 화면 := get_viewport().get_texture().get_image()
	if 화면 == null or 화면.is_empty():
		return
	var w := 화면.get_width()
	var h := 화면.get_height()
	var 자름 := Rect2i(int(w * 0.15), int(h * 0.18), int(w * 0.70), int(h * 0.74))
	var img := 화면.get_region(자름)
	img.resize(크기.x, 크기.y, Image.INTERPOLATE_BILINEAR)
	_사진 = img


func _저장() -> void:
	# 저장을 금지한 검증 실행에서는 진행뿐 아니라 사진 파일도 쓰지 않는다.
	if not 게임진행.기록해도_되나():
		return
	if _사진 == null:
		_찍기()                       # 아직 못 찍었으면 지금(출구 앞) 한 장
	if _사진 == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	_사진.save_png(폴더 + _씬이름 + ".png")
