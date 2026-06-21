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

## ▼ 2026-06-17 추가: 폴리곤 빌드 모드 상수
##   왜 추가했나(중요):
##     opaque_to_polygons() 는 "구멍(동굴) 있는 도넛 모양"을 만나면, 바깥 외곽선과
##     안쪽 구멍을 폭 0 의 슬릿(키홀)으로 이어 붙인 "자기교차 폴리곤" 1개를 돌려준다.
##     이 폴리곤을 CollisionPolygon2D 의 기본값인 SOLIDS(채움) 모드로 쓰면,
##     내부 삼각분할(ear-clipping)이 구멍 영역까지 메워 버려서
##     "동굴 안(플레이어가 지나가야 할 빈 공간)"이 충돌로 꽉 차 버린다.
##     → stage_2 의 BlackCave 들이 바로 이 증상(폴리가 안 들어가야 할 곳까지 들어감)이었다.
##   해결:
##     동굴/도넛형 지형은 SEGMENTS(외곽선만, 속을 채우지 않음) 모드로 구우면
##     구멍이 메워지지 않고 벽/바닥 선만 충돌로 남는다.
##     평지·언덕처럼 구멍이 없는 단순 지형은 기존대로 SOLIDS 가 안전하다.
const BUILD_SOLIDS: int = CollisionPolygon2D.BUILD_SOLIDS
const BUILD_SEGMENTS: int = CollisionPolygon2D.BUILD_SEGMENTS

## ▼ 2026-06-17 추가: 너무 작은(노이즈) 폴리곤을 버리는 최소 면적(px²).
##   왜: 알파 외곽에 생기는 1~2px 짜리 사금파리 폴리곤이 캐릭터 발에 걸리는
##       "고스트 충돌" 의 원인이 된다. 일정 면적 미만은 충돌로 만들지 않는다.
const MIN_POLY_AREA: float = 24.0

## 폴리곤의 절대 면적(px²)을 구한다 (신발끈 공식). 부호 무시.
static func _polygon_area(poly: PackedVector2Array) -> float:
	var n := poly.size()
	if n < 3:
		return 0.0
	var area := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5

## sprite 의 알파 모양대로 target(StaticBody2D/Area2D)의 직속 자식에
## CollisionPolygon2D 들을 생성한다.
## - target       : 폴리곤을 자식으로 가질 충돌 바디 (CollisionObject2D)
## - sprite       : 모양의 기준이 되는 Sprite2D
## - owner_root   : 보통 get_tree().edited_scene_root. .tscn 저장을 위해 필요.
## - build_mode   : 0=SOLIDS(채움, 단순 지형 기본) / 1=SEGMENTS(외곽선만, 동굴·도넛형)
##                  ▼ 2026-06-17 추가된 인자. 동굴형 지형의 충돌 메움 버그 해결용.
## 반환: 생성한 폴리곤 개수.
## 주의: 이전에 이 함수로 구운(meta "auto_baked") 폴리곤은 먼저 모두 제거한다.
##       → 다시 Bake 해도 중복으로 쌓이지 않음.
static func bake_into(target: Node, sprite: Sprite2D, alpha_threshold: float, epsilon: float, owner_root: Node, build_mode: int = BUILD_SOLIDS) -> int:
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
		# ▼ 2026-06-17 추가: 노이즈(초소형) 폴리곤은 건너뛴다 → 고스트 충돌(발 걸림) 예방
		if _polygon_area(poly) < MIN_POLY_AREA:
			continue
		var pts := PackedVector2Array()
		for p in poly:
			pts.append((p + origin) * sprite.scale + sprite.position)
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		# ▼ 2026-06-17 추가: build_mode 적용 (SEGMENTS 면 동굴 구멍이 메워지지 않음)
		cp.build_mode = build_mode
		cp.name = "AutoCol_%d" % count
		cp.set_meta("auto_baked", true)   # 다음 Bake 때 식별/제거용 표시
		target.add_child(cp)
		if owner_root:
			cp.owner = owner_root          # owner 설정해야 .tscn 에 저장됨
		count += 1
	return count
