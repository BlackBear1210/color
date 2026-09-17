## 호퍼 입구에 어떤 물이 겹치는지 실측한다 — "저장고를 칠했는데 왜 출구가 회색이 안 되나" 를 잡는 도구.
## [2026-09-17 Claude] 2-4 에서 S3b 호퍼 출구가 흰색 그대로였다. 원인은 옆 호퍼 H4 의 출구 물(448 폭)이 S3b 입구 영역(윗면 −84~+6)에
## 걸쳐 흰색이 하나 더 섞인 것 — 씬을 아무리 봐도 안 보이고, 이렇게 겹침 목록을 찍어야 보인다.
##
## 실행:
##   godot --headless --path . -s res://tools/진단_호퍼입구.gd -- res://scenes/world_2_클로드/stage_2-4.tscn [--칠=검정|흰색]
##   --칠 을 주면 모든 물저장고를 그 색으로 필요횟수만큼 명중시킨 뒤 잰다(저장고 공급까지 켠 상태).
extends SceneTree


func _init() -> void:
	var 인자 := Array(OS.get_cmdline_user_args())
	var 씬경로 := ""
	var 칠색 := -1
	for a in 인자:
		var s := String(a)
		if s.begins_with("--칠="):
			칠색 = 0 if s.ends_with("검정") else 1
		elif s.ends_with(".tscn"):
			씬경로 = s
	if 씬경로.is_empty():
		push_error("씬 경로가 없다: -- res://scenes/.../stage_2-N.tscn")
		quit(1)
		return
	var 씬: Node = (load(씬경로) as PackedScene).instantiate()
	root.add_child(씬)
	for i in 10:
		await physics_frame
	if 칠색 >= 0:
		for t in get_nodes_in_group("물저장고"):
			for k in maxi(int(t.get("필요횟수")), 1):
				t.call("명중", 칠색, Vector2.ZERO)
		for i in 10:
			await physics_frame
	print("── 호퍼 입구 겹침 (%s%s) ──" % [씬경로.get_file(), ("" if 칠색 < 0 else " · 저장고 전부 %s" % ("검정" if 칠색 == 0 else "흰색"))])
	for h in get_nodes_in_group("호퍼") if not get_nodes_in_group("호퍼").is_empty() else _찾기_전부(씬, "호퍼"):
		var 입구: Area2D = h.get_node_or_null("입구")
		if 입구 == null:
			continue
		var 목록 := []
		for a in 입구.get_overlapping_areas():
			목록.append("%s(켜짐=%s 색=%s)" % [a.name, str(a.get("켜짐")), str(a.get("색"))])
		var 출구 = h.get("_출구")
		print("  %-8s @(%.0f,%.0f) 입구 중심 (%.0f,%.0f) → 겹침 %d: %s · 출구 %s" % [h.name, h.global_position.x, h.global_position.y,
			입구.get_node("모양").global_position.x, 입구.get_node("모양").global_position.y, 목록.size(), str(목록),
			("%s(켜짐=%s 색=%s)" % [출구.name, str(출구.get("켜짐")), str(출구.get("색"))]) if 출구 else "없음"])
	for t in get_nodes_in_group("물저장고"):
		var sup: Node = t.get_node_or_null(t.get("공급_유체"))
		print("  저장고 %-6s 현재색=%d 공급=%s%s" % [t.name, int(t.call("현재색")), sup.name if sup else "(없음)",
			(" 켜짐=%s 색=%s @(%.0f,%.0f)" % [str(sup.get("켜짐")), str(sup.get("색")), sup.global_position.x, sup.global_position.y]) if sup else ""])
	quit()


## 호퍼가 그룹에 안 들어 있을 때를 대비해 스크립트 이름으로 찾는다.
func _찾기_전부(n: Node, 스크립트명: String, 결과: Array = []) -> Array:
	var sc: Variant = n.get_script()
	if sc and String(sc.resource_path).get_file().get_basename() == 스크립트명:
		결과.append(n)
	for c in n.get_children():
		_찾기_전부(c, 스크립트명, 결과)
	return 결과
