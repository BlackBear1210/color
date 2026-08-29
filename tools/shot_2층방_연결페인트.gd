extends SceneTree
## 2층방의 비원형 얼룩이 자라고 흘러내린 뒤 증발·자동 회수되는 과정을 캡처한다.
## 실행: godot --path . -s res://tools/shot_2층방_연결페인트.gd -- <출력접두어>

const 이층방씬 := preload("res://scenes/집/스테이지_1_2층방.tscn")
const 찍을때 := {
	20: "00_초기번짐",
	100: "01_흐르는중",
	220: "02_최대흐름",
	320: "03_증발중",
	365: "04_자동회수뒤",
}

var _프레임 := 0
var _방: Node2D = null
var _벽돌: Node2D = null
var _출력접두어 := "C:/Users/82104/AppData/Local/Temp/gray_2floor_link"


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)


func _틱() -> void:
	_프레임 += 1
	if _프레임 == 1:
		var 인수 := OS.get_cmdline_user_args()
		if not 인수.is_empty():
			_출력접두어 = 인수[0]
		_방 = 이층방씬.instantiate() as Node2D
		root.add_child(_방)
		_벽돌 = _방.get_node("지형/바닥_STAGE1_BRICK_01") as Node2D
		# 실제 문제 위치인 침대·책상과 바닥 접점이 화면 가운데 오게 한다.
		var 카메라 := Camera2D.new()
		카메라.global_position = Vector2(1500.0, -20.0)
		카메라.zoom = Vector2(0.78, 0.78)
		root.add_child(카메라)
		카메라.make_current()
		return

	if _프레임 == 4:
		# 서로 떨어진 세 지점에 실제 탄약을 써서 쏜다. 위치가 다르면 고정 난수도 달라져
		# 둥근 각·비대칭과 1~3개의 물줄기 조합이 서로 다른 모습으로 나온다.
		var 코어 := _방.get_node("페인트코어") as 페인트코어
		for 로컬점 in [Vector2(-1545.0, -60.0), Vector2(-975.0, -60.0), Vector2(-345.0, -60.0)]:
			코어.발사_소모()
			코어.명중_처리(_벽돌, ColorDefs.WHITE, _벽돌.to_global(로컬점))

	if 찍을때.has(_프레임):
		var 경로 := "%s_%s.png" % [_출력접두어, 찍을때[_프레임]]
		var 오류 := root.get_texture().get_image().save_png(경로)
		print("2층방 연결 캡처: %s -> %s" % [error_string(오류), 경로])

	if _프레임 > 370:
		quit()
