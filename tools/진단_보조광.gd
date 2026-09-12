extends SceneTree
## [2026-09-05 STEP 5] 플레이어 보조광이 실제로 씬에 하나만, 제대로 붙었나 확인.
const 씬들 := [
	"res://scenes/집/스테이지_1_2층방.tscn",
	"res://scenes/집/스테이지_2_복도계단.tscn",
	"res://scenes/world_1/1-1/stage_1-1.1.tscn",
	"res://scenes/world_2/stage_2-1.tscn",
]
func _init() -> void: call_deferred("_go")
func _go() -> void:
	var 실패 := 0
	for p: String in 씬들:
		if not ResourceLoader.exists(p):
			print("  ⚠ 없음 %s" % p); continue
		var n := (load(p) as PackedScene).instantiate()
		root.add_child(n); current_scene = n
		for _i in 20: await process_frame
		var 보조: Array = []
		for c in _모두(n):
			if c.name == "플레이어_보조광":
				보조.append(c)
		print("· %s → 보조광 %d개" % [p.get_file(), 보조.size()])
		if 보조.size() != 1:
			실패 += 1
		for b in 보조:
			var L := b.get_node_or_null("PointLight2D") as PointLight2D
			if L == null:
				print("    ✗ PointLight2D 없음"); 실패 += 1; continue
			print("    부모 %s · 노드scale %s · 빛 global_scale %s" % [
				b.get_parent().name, b.scale, L.global_scale])
			print("    energy %.2f · texture_scale %.2f · height %.0f · shadow %s · blend %d · visible %s" % [
				L.energy, L.texture_scale, L.height, L.shadow_enabled, L.blend_mode, L.visible])
			print("    빛 global_position %s / 플레이어 %s" % [
				L.global_position, b.get_parent().global_position])
			if L.shadow_enabled:
				print("    ✗ 보조광에 그림자가 켜져 있다"); 실패 += 1
			if absf(L.global_scale.x - L.global_scale.y) > 0.01:
				print("    ✗ 빛이 타원이다(비균등 스케일 상쇄 실패)"); 실패 += 1
		n.queue_free(); current_scene = null
		for _i in 5: await process_frame
	print("보조광 진단 실패 %d" % 실패)
	quit(1 if 실패 > 0 else 0)
func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children(): r.append_array(_모두(c))
	return r
