@tool
class_name AutoCollision
extends RefCounted
## 스프라이트의 "알파(투명) 모양"을 따라 충돌 폴리곤을 자동 생성하는 헬퍼.
##
## 왜 필요한가:
##   디자이너가 준 지형 PNG는 곡선·구멍(오목)까지 있는 불규칙한 형태라
##   CollisionPolygon2D 정점을 손으로 찍는 건 비현실적이다.
##   Godot 내장 BitMap.opaque_to_polygons() 가 알파 영역을
##   여러 개의 (볼록) 폴리곤으로 자동 분해해 주므로, 그림 모양 그대로
##   충돌을 만들 수 있다. 구멍은 폴리곤이 비워져서 플레이어가 통과/낙하한다.
##
## 핵심: 이 작업은 "에디터에서 한 번만" 실행해 .tscn 에 저장한다.
##       → 게임 실행(런타임) 시에는 이미 만들어진 폴리곤을 쓰므로 추가 비용 0.

## 텍스처의 알파 영역을 폴리곤 배열로 변환한다.
## - texture          : 변환할 텍스처
## - alpha_threshold  : 이 값(0~1)보다 알파가 크면 "채워진 픽셀"로 간주
## - epsilon          : 외곽선 단순화 정도(px). 클수록 정점↓(가볍지만 거칢)
## 반환: PackedVector2Array 들의 Array. 각 점은 텍스처 좌상단(0,0) 기준 px 좌표.
static func polygons_from_texture(texture: Texture2D, alpha_threshold: float = 0.5, epsilon: float = 3.0) -> Array:
	if texture == null:
		return []
	var image: Image = texture.get_image()
	if image == null:
		# 임포트 설정에 따라 에디터에서 이미지를 못 읽는 경우가 있음
		push_warning("AutoCollision: 텍스처에서 Image를 읽지 못했습니다. (Import 탭에서 압축을 'Lossless'로)")
		return []
	var bitmap := BitMap.new()
	# 알파 > threshold 인 픽셀을 true(채워짐)로 표시한 비트맵 생성
	bitmap.create_from_image_alpha(image, alpha_threshold)
	var rect := Rect2i(Vector2i.ZERO, bitmap.get_size())
	# 채워진 영역의 외곽선을 폴리곤들로 추출 (epsilon으로 정점 단순화)
	return bitmap.opaque_to_polygons(rect, epsilon)

## sprite 의 알파 모양대로 target(StaticBody2D/Area2D)의 직속 자식에
## CollisionPolygon2D 들을 생성한다.
## - target       : 폴리곤을 자식으로 가질 충돌 바디 (CollisionObject2D)
## - sprite       : 모양의 기준이 되는 Sprite2D
## - owner_root   : 보통 get_tree().edited_scene_root. .tscn 저장을 위해 필요.
## 반환: 생성한 폴리곤 개수.
## 주의: 이전에 이 함수로 구운(meta "auto_baked") 폴리곤은 먼저 모두 제거한다.
##       → 다시 Bake 해도 중복으로 쌓이지 않음.
static func bake_into(target: Node, sprite: Sprite2D, alpha_threshold: float, epsilon: float, owner_root: Node) -> int:
	# 1) 기존에 자동 생성했던 폴리곤 제거 (수동으로 만든 것은 건드리지 않음)
	var to_remove: Array = []
	for c in target.get_children():
		if c is CollisionPolygon2D and c.has_meta("auto_baked"):
			to_remove.append(c)
	for c in to_remove:
		target.remove_child(c)
		c.free()

	if sprite == null or sprite.texture == null:
		return 0

	var polys := polygons_from_texture(sprite.texture, alpha_threshold, epsilon)
	if polys.is_empty():
		return 0

	# 2) 텍스처 px 좌표 → target 로컬 좌표 변환 준비
	#    (스프라이트의 centered/offset/scale/position 을 반영해 그림과 충돌을 정확히 일치시킴)
	var tex_size := Vector2(sprite.texture.get_size())
	var origin := sprite.offset
	if sprite.centered:
		origin -= tex_size * 0.5   # centered 면 텍스처 중심이 (0,0)

	# 3) 폴리곤마다 CollisionPolygon2D 노드 생성
	var count := 0
	for poly in polys:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append((p + origin) * sprite.scale + sprite.position)
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		cp.name = "AutoCol_%d" % count
		cp.set_meta("auto_baked", true)   # 다음 Bake 때 식별/제거용 표시
		target.add_child(cp)
		if owner_root:
			cp.owner = owner_root          # owner 설정해야 .tscn 에 저장됨
		count += 1
	return count
