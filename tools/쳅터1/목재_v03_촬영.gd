extends SceneTree
## ============================================================================
## [2026-10-04 Claude] 스테이지 촬영 — 전체(맵 전체가 한 장에) + 첫 화면
## ----------------------------------------------------------------------------
## ⚠ --headless 로 돌리면 화면이 안 그려진다. 창 모드로 실행한다.
##   Godot_console --path . -s res://tools/촬영_스테이지.gd -- [씬경로 ...]
##   인자가 없으면 아래 `기본목록` 전부. 결과: res://tools/쳅터1/목재_v03_검토/실제/<씬이름>_전체.png · _첫화면.png
##
## 전체 샷: ProtoCamera 를 멈추고 임시 Camera2D 로 `카메라_리밋` 사각형을 화면에 꽉 맞춘다.
## 첫 화면: 씬이 원래 하는 대로(플레이어를 따라가는 카메라) 40 프레임 뒤.
## ============================================================================

const 폴더 := "res://tools/쳅터1/목재_v03_검토/실제/"
const 기본목록 := [
	"res://scenes/쳅터1/2층방.tscn",
	"res://scenes/쳅터1/스테이지_2_복도계단.tscn",
	"res://scenes/쳅터1/스테이지_2_복도.tscn",
	"res://scenes/쳅터1/스테이지_4_복도.tscn",
	"res://scenes/쳅터1/집_거실.tscn",
	"res://scenes/쳅터1/집_부엌.tscn",
	"res://scenes/쳅터1/집_굴뚝.tscn",
]

var _목록: Array = []
var _i := -1
var _씬: Node = null
var _프레임 := 0
var _단계 := 0
var _횟수: Dictionary = {}


func _initialize() -> void:
	var 인자 := OS.get_cmdline_user_args()
	_목록 = 인자 if 인자.size() > 0 else 기본목록
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	root.size = Vector2i(1920, 1080)
	# 초기 트리 구성 중 오디오가 루트 자식을 추가하지 않도록 다음 프레임에 로드한다.
	_다음.call_deferred()


func _다음() -> void:
	if _씬:
		_씬.queue_free()
		_씬 = null
	_i += 1
	if _i >= _목록.size():
		print("DONE")
		quit()
		return
	var p: String = _목록[_i]
	var 팩 := load(p) as PackedScene
	if 팩 == null:
		print("FAIL ", p)
		_다음()
		return
	_씬 = 팩.instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_프레임 = 0
	_단계 = 0


func _process(_delta: float) -> bool:
	if _씬 == null:
		return false
	_프레임 += 1
	var 이름 := String(_목록[_i]).get_file().get_basename()
	if _단계 == 0 and _프레임 == 32:
		_횟수.clear()
		for n in _씬.find_children("*", "Node2D", true, false):
			if n.get("덮개_생성횟수") != null:
				_횟수[n.get_instance_id()] = n.덮개_생성횟수
	if _단계 == 0 and _프레임 == 40:
		var errors := 0
		for id in _횟수:
			var n: Node = instance_from_id(id)
			if n.덮개_생성횟수 != _횟수[id] or n._덮개재질 == null or not n._셰이더들.has(n._덮개재질):
				errors += 1
		print("DECK ", 이름, " count=", _횟수.size(), " errors=", errors)
		_찍기(폴더 + 이름 + "_첫화면.png")
		_전체_카메라()
		_단계 = 1
		_프레임 = 0
	elif _단계 == 1 and _프레임 == 8:
		_찍기(폴더 + 이름 + "_전체.png")
		_다음()
	return false


func _찍기(경로: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(경로))
	print("SHOT ", 경로)


func _전체_카메라() -> void:
	var 리밋: Rect2 = _씬.get("카메라_리밋") if _씬.get("카메라_리밋") != null else Rect2()
	if 리밋.size.length() < 1.0:
		리밋 = Rect2(-2000, -2000, 8000, 5000)
	for c in _씬.find_children("*", "Camera2D", true, false):
		(c as Camera2D).process_mode = Node.PROCESS_MODE_DISABLED
		(c as Camera2D).enabled = false
	var cam := Camera2D.new()
	cam.position = 리밋.get_center()
	var z := minf(1920.0 / 리밋.size.x, 1080.0 / 리밋.size.y) * 0.98
	cam.zoom = Vector2(z, z)
	_씬.add_child(cam)
	cam.make_current()
