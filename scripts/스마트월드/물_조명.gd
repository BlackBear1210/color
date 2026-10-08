extends RefCounted
## [2026-10-01 Claude · 도형님 "물이 종이를 잘라 얹은 느낌"] 물 셰이더에 "근처 광원" 을 넘겨 주는 공용 도우미.
##
## 왜 Godot 기본 2D 조명(render_mode unshaded 빼기)을 안 쓰나:
##   하수도는 CanvasModulate 가 없고 벽등(PointLight2D)이 **더하기**로만 밝힌다.
##   흰 물(0.86)은 이미 거의 최대라 더해도 안 변하고, 검정 물은 바탕이 0 에 가까워 반응이 없다.
##   즉 기본 조명으로는 "등 쪽은 밝고 반대쪽은 어두운" 입체감이 안 생긴다.
##   → 물 셰이더가 광원 위치·반경·세기·높이를 받아 **직접** 음영과 하이라이트를 계산한다.
##   셰이더는 unshaded 그대로라 굴절(screen_texture)로 읽은 벽이 두 번 밝아지는 일도 없다.
##
## 광원 목록은 SceneTree.node_added / node_removed 로만 유지한다.
##   매번 트리 전체를 뒤지면(find_children) 프레임 드랍 기록(2026-09-30)의 재발이 된다.

const 최대 := 6

static var _등록됨 := false
static var _광원들: Array[PointLight2D] = []
## 한 프레임에 한 번만 광원 정보를 모은다. 물이 여러 개면 물마다 광원을 다시 훑던 것이
## 2-1 측정에서 스크립트 +0.6ms 로 나왔다(2026-10-01). [자리, 반경, 세기, 높이, 밝기] 목록.
static var _모은_프레임 := -1
static var _모음: Array = []


static func _등록(트리: SceneTree) -> void:
	if _등록됨:
		return
	_등록됨 = true
	# 이미 트리에 있는 광원은 한 번만 훑는다(첫 물이 켜질 때 한 번).
	for 노드 in 트리.root.find_children("*", "PointLight2D", true, false):
		_광원들.append(노드)
	트리.node_added.connect(func(노드: Node) -> void:
		if 노드 is PointLight2D:
			_광원들.append(노드))
	트리.node_removed.connect(func(노드: Node) -> void:
		if 노드 is PointLight2D:
			_광원들.erase(노드))


## 사각형(월드 좌표) 에 빛이 닿는 광원을 가까운 순으로 최대 6 개.
## 돌려주는 두 배열을 셰이더 lights / light_extra 에 그대로 넣는다.
##   lights[i]      = (x, y, 반경, 세기)
##   light_extra[i] = (높이, 색 밝기, 0, 0)
static func 근처(트리: SceneTree, 영역: Rect2) -> Array:
	_등록(트리)
	var 프레임 := Engine.get_process_frames()
	if 프레임 != _모은_프레임:
		_모은_프레임 = 프레임
		_모음.clear()
		for 빛 in _광원들:
			if not is_instance_valid(빛) or not 빛.enabled or not 빛.is_visible_in_tree():
				continue
			var 밝기 := (빛.color.r + 빛.color.g + 빛.color.b) / 3.0
			_모음.append([빛.global_position, _반경(빛), 빛.energy, 빛.height, 밝기])
	var 후보: Array = []
	for 정보 in _모음:
		var 거리 := _사각형_거리(영역, 정보[0])
		if 거리 > 정보[1]:
			continue
		후보.append([거리, 정보])
	후보.sort_custom(func(a, b): return a[0] < b[0])
	var 위치들 := PackedVector4Array()
	var 덧붙임 := PackedVector4Array()
	for i in 최대:
		if i < 후보.size():
			var 정보: Array = 후보[i][1]
			var 자리: Vector2 = 정보[0]
			위치들.append(Vector4(자리.x, 자리.y, 정보[1], 정보[2]))
			덧붙임.append(Vector4(정보[3], 정보[4], 0.0, 0.0))
		else:
			위치들.append(Vector4.ZERO)
			덧붙임.append(Vector4.ZERO)
	return [위치들, 덧붙임, mini(후보.size(), 최대)]


## 빛이 실제로 닿는 반경 = 텍스처 반지름 × texture_scale (벽등: 128 × 230/128 = 230).
static func _반경(빛: PointLight2D) -> float:
	var 텍스처 := 빛.texture
	var 반지름 := 128.0
	if 텍스처 != null:
		반지름 = maxf(텍스처.get_width(), 텍스처.get_height()) * 0.5
	return 반지름 * 빛.texture_scale * maxf(빛.global_scale.x, 빛.global_scale.y)


static func _사각형_거리(영역: Rect2, 점: Vector2) -> float:
	var dx := maxf(0.0, maxf(영역.position.x - 점.x, 점.x - 영역.end.x))
	var dy := maxf(0.0, maxf(영역.position.y - 점.y, 점.y - 영역.end.y))
	return sqrt(dx * dx + dy * dy)
