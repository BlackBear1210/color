extends SceneTree
## [2026-09-30 Claude] 체크포인트 성수반 — 꺼짐 → 플레이어가 닿음 → 불빛 + 흰 잉크 차오름 → 방울을 순서대로 찍는다.
##   게임 파일은 안 바꾼다. 창 모드로 돌린다:
##   G --path . -s res://tools/촬영_체크포인트_성수반.gd [-- <씬> <체크포인트 노드 경로>]
## 결과: user://체크포인트_성수반/*.png

var 씬 := "res://scenes/world_2_클로드/stage_2-9.tscn"
var 노드경로 := "장치/체크포인트_기계실"
const 폴더 := "user://체크포인트_성수반"


func _initialize() -> void:
	var 인자 := OS.get_cmdline_user_args()
	if 인자.size() >= 2:
		씬 = 인자[0]
		노드경로 = 인자[1]
	call_deferred("_실행")


func _찍기(이름: String) -> void:
	var 파일 := "%s/%s.png" % [폴더, 이름]
	root.get_texture().get_image().save_png(파일)
	print("SHOT ", ProjectSettings.globalize_path(파일))


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute(폴더)
	var 스테이지: Node = (load(씬) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	var cp := 스테이지.get_node(노드경로) as Node2D
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	플레이어.global_position = cp.global_position + Vector2(-260, -4)
	카메라.global_position = cp.global_position + Vector2(-40, -90)
	카메라.zoom = Vector2(1.6, 1.6)
	카메라.reset_smoothing()
	for i in 30:
		await physics_frame
	print("활성(닿기 전) = ", cp.get("활성"))
	await _찍기("1_꺼짐")
	# 걸어 들어가는 대신 옆에 내려놓는다 — body_entered 로 스스로 켜지는지가 확인 대상이다
	플레이어.global_position = cp.global_position + Vector2(-26, -4)
	for i in 3:
		await physics_frame
	플레이어.global_position = cp.global_position + Vector2(-110, -4)   # 닿아 켠 뒤 비켜서 대야가 가리지 않게
	for 판 in [["2_닿음_0.1초", 6], ["3_차오름_0.5초", 24], ["4_가득_1.2초", 42], ["5_방울_2.4초", 72]]:
		for i in 판[1]:
			await process_frame
		await _찍기(판[0])
	print("활성(닿은 뒤) = ", cp.get("활성"), " 채움 = ", cp.get("_채움"), " 잉크색 = ", cp.get("_잉크색"))
	quit(0)
