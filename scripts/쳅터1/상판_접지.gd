extends RefCounted
## 빛 끝과 양초 받침을 충돌선이 아닌 지형의 보이는 윗면 중앙에 놓는다. 판정 좌표는 옮기지 않는다.
## 물리가 없는 편집기에서는 챕터1 목재의 기본 깊이만 미리 보여 준다.
static func 보정(item: Node2D, local_point: Vector2) -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(0, 7)
	var point := item.to_global(local_point)
	var q := PhysicsRayQueryParameters2D.create(point + Vector2(0, -12), point + Vector2(0, 20), 1)
	var player := 플레이어찾기.찾기(item) as CollisionObject2D
	if player:
		q.exclude = [player.get_rid()]
	var hit := item.get_world_2d().direct_space_state.intersect_ray(q)
	return 충돌_보정(item, local_point, hit)


static func 충돌_보정(item: Node2D, local_point: Vector2, hit: Dictionary) -> Vector2:
	# 창문은 이미 광선 충돌 결과를 알고 있다. 그 결과를 재사용해 같은 바닥을 다시 쏘지 않는다.
	# 벽·거울·허공에 끝나는 반사광에는 바닥 깊이를 억지로 적용하지 않는다.
	if hit.is_empty() or Vector2(hit.normal).y > -0.7:
		return Vector2.ZERO
	var surface := hit.collider as Node
	while surface and not surface.has_method("발_그림_깊이"):
		surface = surface.get_parent()
	var offset := Vector2.ZERO
	if surface is Node2D:
		offset = surface.to_global(Vector2(0, float(surface.call("발_그림_깊이")))) - surface.global_position
	return item.to_local(Vector2(hit.position) + offset) - local_point
