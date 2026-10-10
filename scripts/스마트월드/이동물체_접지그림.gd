extends RefCounted
## 이동하는 소품도 플레이어와 같은 지형 API를 사용해야 바닥 원근이 바뀌는 곳에서 떠 보이지 않는다.
static func 보정(body: CharacterBody2D, 그림바닥: float, 이전깊이: float) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(body.to_global(Vector2(0, -14)), body.to_global(Vector2(0, 20)), 1)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# 공중에서는 마지막 지형의 투영을 유지한다. 낙하 중 갑자기 그림이 위로 튀지 않게 한다.
		return Vector2(이전깊이, 이전깊이)
	var surface := hit["collider"] as Node
	while surface != null and not surface.has_method("발_그림_깊이"):
		surface = surface.get_parent()
	var depth := 0.0
	if surface is Node2D:
		var amount := float(surface.call("발_그림_깊이"))
		depth = body.to_local(surface.to_global(Vector2(0, amount))).y - body.to_local(surface.to_global(Vector2.ZERO)).y
	# 가까운 바닥이 보여도 공중의 물체를 바닥까지 끌어내려 그리지 않는다. 실제 접지 때만 원점 차이를 보정한다.
	var offset := depth
	if body.is_on_floor():
		offset += body.to_local(hit["position"]).y - 그림바닥
	return Vector2(offset, depth)
