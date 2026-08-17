extends SceneTree
## ============================================================================
## [2026-08-17 도형 · 신규] 카메라 공간 배치 러너
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/카메라공간_배치.gd
##   Godot --headless --path . -s res://tools/카메라공간_배치.gd -- --조사
##   Godot --headless --path . -s res://tools/카메라공간_배치.gd -- --씬 res://scenes/스마트월드/스마트월드_4.tscn
##
## ▣ 이 도구는 "구운 씬" 을 손본다 (씬을 다시 만들지 않는다)
##   `tools/스마트월드_체인.gd` 는 스테이지를 **통째로** 다시 굽는다. 그건 평소에
##   돌리면 안 되는 도구다(에디터에서 손본 값이 날아간다 — 인수인계 문서 §4).
##   → 여기서는 이미 구워진 `스마트월드_N.tscn` 을 열어 카메라 공간만 얹고 저장한다.
##     실제 배치 규칙은 `scripts/스마트월드/카메라공간배치.gd` 한 곳에 있고,
##     체인 빌더도 **같은 함수**를 부른다 → 다시 구워도 결과가 같다(로직 복사 없음).
##
## ▣ owner 규칙 (2026-08-07 세그폴트)
##   읽어온 씬의 기존 노드는 owner 를 건드리지 않는다.
##   우리가 만든 `카메라공간_*` 노드에만 owner 를 준다.
##   ★그 노드가 런타임에 스스로 만드는 자식(`판정`)에는 owner 를 주지 않는다 —
##     주면 씬에 한 벌 더 저장되고 다음 로드 때 두 벌이 된다.
## ============================================================================

const 배치 := preload("res://scripts/스마트월드/카메라공간배치.gd")

var _조사만 := false
var _씬들: Array[String] = []
var _총 := 0


func _init() -> void:
	Engine.max_fps = 60
	_인자_읽기()
	call_deferred("_실행")


func _인자_읽기() -> void:
	var 인자 := OS.get_cmdline_user_args()
	var i := 0
	while i < 인자.size():
		var a: String = 인자[i]
		if a == "--조사":
			_조사만 = true
		elif a == "--씬" and i + 1 < 인자.size():
			i += 1
			_씬들.append(인자[i])
		i += 1
	if _씬들.is_empty():
		for s in 챕터.스테이지표:
			_씬들.append(챕터.씬경로(int(s["번호"])))


func _실행() -> void:
	print("\n=== 카메라 공간 배치 (%s) ===" % ("조사만" if _조사만 else "적용"))
	for 경로 in _씬들:
		await _씬_하나(경로)
	print("---")
	print("[카메라공간] 총 %d개 %s" % [_총, "(조사만)" if _조사만 else "생성·저장"])
	quit(0)


func _씬_하나(경로: String) -> void:
	if not ResourceLoader.exists(경로):
		push_warning("씬이 없다 → %s" % 경로)
		return
	var 루트 := (load(경로) as PackedScene).instantiate() as Node2D
	root.add_child(루트)
	# 콜리전이 물리 공간에 들어가야 벽 실측이 된다
	await physics_frame
	await physics_frame

	var 결과 := 배치.깔기(루트)
	var 수: int = int(결과["만든수"])
	_총 += 수
	if 수 == 0:
		print("── %-22s 수직 통로 없음" % 경로.get_file())
	else:
		for 이름 in 결과["이름들"]:
			var 공간 := _찾기(루트, String(이름)) as 카메라공간
			if 공간:
				print("── %-22s %s  중심(%.0f, %.0f) 크기 %.0f×%.0f  줌×%.2f"
					% [경로.get_file(), 이름, 공간.global_position.x,
					   공간.global_position.y, 공간.크기.x, 공간.크기.y, 공간.줌_배수])

	if not _조사만 and 수 > 0:
		# ★새로 만든 공간 노드에만 owner. 그 자식(`판정`)은 런타임 생성물이라 주지 않는다.
		for 이름 in 결과["이름들"]:
			var n := _찾기(루트, String(이름))
			if n:
				n.owner = 루트
		_저장(루트, 경로)

	루트.queue_free()
	await process_frame


func _찾기(노드: Node, 이름: String) -> Node:
	for c in 노드.get_children():
		if String(c.name) == 이름:
			return c
		var r := _찾기(c, 이름)
		if r:
			return r
	return null


func _저장(루트: Node2D, 경로: String) -> void:
	var 팩 := PackedScene.new()
	var err := 팩.pack(루트)
	if err != OK:
		push_error("  pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, 경로)
	print("   저장 %s → %s" % [error_string(err), 경로.get_file()])
