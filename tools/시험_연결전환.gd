extends SceneTree
## ============================================================================
## [2026-10-04 Claude] 연결구 전환 실제 엔진 시험 — 창 모드로 실행(--headless 금지: 촬영)
##   Godot_console --path . -s res://tools/시험_연결전환.gd
## 순서
##   1) 01 시작방을 띄우고 루트에 표식(meta)을 단다
##   2) 플레이어를 오른쪽 길목 앞 2칸에 세우고 자동 걷기 → 연결구 판정 → 전환
##      전환 동안 0.1초마다 찍는다(줌인·암전·교체·걸어 나옴·줌아웃)
##   3) 02 복도 A 가 current_scene 인지, 플레이어가 길목 안쪽에 섰는지 확인
##   4) 02 의 왼쪽 길목으로 되돌아가 → current_scene 이 **표식 달린 같은 01** 인지(보관 복원) 확인
## 결과: res://tools/_진단/연결전환/결과.txt · 프레임 PNG
## ============================================================================

const 폴더 := "res://tools/_진단/연결전환/"
const 시작 := "res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn"

var _줄: PackedStringArray = []
var _단계 := 0
var _f := 0
var _컷 := 0
var _원래01: Node = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	root.size = Vector2i(1920, 1080)
	var s := (load(시작) as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	s.set_meta("test_mark", 1)
	_원래01 = s


func _플레이어() -> CharacterBody2D:
	return current_scene.get_node_or_null("Player") as CharacterBody2D if current_scene else null


func _길목(이름: String) -> Node2D:
	return current_scene.find_child(이름, true, false) as Node2D


func _찍기(이름: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png(ProjectSettings.globalize_path(폴더 + 이름 + ".png"))


func _기록(s: String) -> void:
	_줄.append(s)
	print(s)


func _끝() -> void:
	var f := FileAccess.open(폴더 + "결과.txt", FileAccess.WRITE)
	f.store_string("\n".join(_줄))
	f.close()
	quit()


func _process(_d: float) -> bool:
	_f += 1
	var p := _플레이어()
	match _단계:
		0:
			if _f == 30:
				var 길 := _길목("오른쪽")
				p.global_position = 길.global_position + Vector2(-float(길.get("방향")) * 64.0, -2.0)
				p.velocity = Vector2.ZERO
				p.set("자동_걷기", float(길.get("방향")))
				_기록("01: 오른쪽 길목 앞에 세우고 자동 걷기 시작 @%s" % p.global_position)
				_단계 = 1
				_f = 0
		1:
			# 전환 시작 감지 후 6프레임마다 찍는다(약 3초)
			if _f % 6 == 0 and _컷 < 40:
				_찍기("01_02_%02d" % _컷)
				_컷 += 1
			if current_scene and current_scene.name == "쳅터1_02_복도_A" and _f > 200:
				var 진행: bool = load("res://scripts/쳅터1/전경전환.gd").call("진행중인가")
				_기록("02 도착: current_scene=%s · 플레이어=%s · 전환중=%s · 자동걷기=%s" % [current_scene.name, _플레이어().global_position, 진행, _플레이어().get("자동_걷기")])
				var 안쪽: Vector2 = _길목("왼쪽").call("안쪽_위치")
				_기록("    왼쪽 길목 안쪽 기대 x≈%.0f · 실제 %.0f" % [안쪽.x, _플레이어().global_position.x])
				_단계 = 2
				_f = 0
			elif _f > 600:
				_기록("× 10초 안에 02 로 넘어가지 않음 · current=%s" % (current_scene.name if current_scene else "없음"))
				_끝()
		2:
			if _f == 20:
				var 길 := _길목("왼쪽")
				p.global_position = 길.global_position + Vector2(-float(길.get("방향")) * 64.0, -2.0)
				p.velocity = Vector2.ZERO
				p.set("자동_걷기", float(길.get("방향")))
				_기록("02: 왼쪽 길목으로 되돌아가기 시작")
				_단계 = 3
				_f = 0
		3:
			if _f % 10 == 0 and _f <= 120:
				_찍기("02_01_%02d" % int(_f / 10))
			if current_scene and current_scene.name == "쳅터1_01_방_시작방" and _f > 160:
				var 같음 := current_scene == _원래01 and current_scene.has_meta("test_mark")
				_기록("01 복귀: 같은 인스턴스(보관 복원)=%s · 플레이어=%s" % [같음, _플레이어().global_position])
				_찍기("01_복귀")
				_기록("○ 전환 왕복 시험 끝")
				_끝()
			elif _f > 600:
				_기록("× 01 로 돌아가지 않음 · current=%s" % (current_scene.name if current_scene else "없음"))
				_끝()
	return false
