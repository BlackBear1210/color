extends SceneTree
## ============================================================================
## [2026-10-03 신규] 세 상태 순환 밸브 검사 — 2-3 밸브_2 (제어레버.gd `세_상태_순환`)
## ----------------------------------------------------------------------------
## 도형님 규칙: "처음에는 검정물과 흰색물이 활성화 → 돌리면 검정물 비활성화·흰색물 활성화 →
##   한 번 더 돌리면 검정물 활성화·흰색물 비활성화 → 한 번 더 돌리면 다 활성화. 이걸 계속 반복."
## 두 물이 호퍼_6 으로 들어가므로 출구(회색물_1)는 둘 다 = 회색 · 흰만 = 흰색 · 검만 = 검정이어야 한다.
## 두 바퀴(6 번) 돌려 순환이 되풀이되는지도 본다.
##
## 실행:
##   Godot --headless --path . -s res://tools/test_밸브_세상태.gd
## ============================================================================

const 씬 := "res://scenes/world_2_클로드/stage_2-3.tscn"
const 물_검 := 0
const 물_흰 := 1
const 물_회 := 2

var _통과 := 0
var _실패 := 0


func _initialize() -> void:
	_실행()


func _실행() -> void:
	var s := (load(씬) as PackedScene).instantiate()
	root.add_child(s)
	for i in 3:
		await physics_frame
	var 밸브 := s.get_node("장치/밸브_2")
	var 검 := s.get_node("장치/검정물_5")
	var 흰 := s.get_node("장치/흰색물_7")
	var 출 := s.get_node("장치/회색물_1")
	print("\n=== 세 상태 순환 밸브 (2-3 밸브_2) ===")
	# [검5 켜짐, 흰7 켜짐, 출구 색] — 0 번째가 처음 상태
	var 기대 := [[true, true, 물_회], [false, true, 물_흰], [true, false, 물_검]]
	for 회 in 7:
		if 회 > 0:
			밸브.call("조작")
		# 호퍼는 물리 프레임에서 입구 물을 섞고, 끊김 유예(0.3 초)가 있다 → 넉넉히 기다린다.
		for i in 40:
			await physics_frame
		var e: Array = 기대[회 % 3]
		var 지금 := [bool(검.get("켜짐")), bool(흰.get("켜짐")), int(출.get("색"))]
		var ok: bool = 지금[0] == e[0] and 지금[1] == e[1] and 지금[2] == e[2] and bool(출.get("켜짐"))
		print("  %s %d 번 돌림 — 검5=%s 흰7=%s 출구색=%d 출구켜짐=%s (기대 %s)" % [
			"✔" if ok else "✖", 회, str(지금[0]), str(지금[1]), 지금[2], str(출.get("켜짐")), str(e)])
		if ok: _통과 += 1
		else: _실패 += 1
	print("  통과 %d · 실패 %d\n" % [_통과, _실패])
	quit(0 if _실패 == 0 else 1)
