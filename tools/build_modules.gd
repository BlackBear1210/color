extends SceneTree
## ▼ 2026-06-21 (작업 W-B) 지형 모듈 키트 10종 PackedScene 생성기 (1회 실행용).
##   실행: Godot --headless --path . -s res://tools/build_modules.gd
##   결과: res://scenes/지형파일셋/모듈/ 에 10종 .tscn 저장.
##
## ◆ 설계 원칙 (맵_레벨디자인_시스템.md)
##   - 비주얼/충돌 분리. 충돌은 모듈당 '매끈한 폴리곤 1개'(조각 금지).
##   - 원점=좌상단, 256px 그리드. color_state(BLACK/WHITE/GRAY) export 로 색 재활용.
##   - 경사는 floor_max_angle(46°) 이하: 256폭에 128 상승 = 26.6° (안전).
##
## ◆ 모듈 내부 구조 (platform.gd 재사용)
##   StaticBody2D(platform.gd)
##   ├── Preview (Polygon2D)          ← 비주얼(아트 PNG 오기 전 임시). platform.gd 가 색 자동 적용
##   ├── CollisionPolygon2D           ← 깔끔한 충돌 1개
##   ├── DeathDetector (Area2D)       ├ CollisionPolygon2D (색 판정 영역)
##   └── SnapPoints (Node2D)          ├ Entry/Exit (Marker2D) 이어붙임 기준점
##
##   ※ 실제 아트가 오면 Preview 대신/위에 Sprite2D("Visual") 를 추가하면 된다.

const OUT_DIR := "res://scenes/지형파일셋/모듈/"
const PLATFORM_SCRIPT := "res://scripts/platform.gd"

func _initialize() -> void:
	var script: Script = load(PLATFORM_SCRIPT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# [이름, 폴리곤, Entry좌표, Exit좌표] — 폴리곤은 좌상단 원점/256그리드 기준
	var modules := [
		["Ground_Flat",    PackedVector2Array([Vector2(0,0), Vector2(256,0), Vector2(256,64), Vector2(0,64)]),                 Vector2(0,0),   Vector2(256,0)],
		["Slope_Up",       PackedVector2Array([Vector2(0,128), Vector2(256,0), Vector2(256,192), Vector2(0,192)]),             Vector2(0,128), Vector2(256,0)],
		["Slope_Down",     PackedVector2Array([Vector2(0,0), Vector2(256,128), Vector2(256,192), Vector2(0,192)]),             Vector2(0,0),   Vector2(256,128)],
		["Platform_Float", PackedVector2Array([Vector2(0,0), Vector2(192,0), Vector2(192,48), Vector2(0,48)]),                 Vector2(0,0),   Vector2(192,0)],
		["Ledge_Edge",     PackedVector2Array([Vector2(0,0), Vector2(256,0), Vector2(256,128), Vector2(0,128)]),               Vector2(0,0),   Vector2(256,0)],
		["Pillar",         PackedVector2Array([Vector2(0,0), Vector2(64,0), Vector2(64,256), Vector2(0,256)]),                 Vector2(0,0),   Vector2(64,0)],
		["Ceiling",        PackedVector2Array([Vector2(0,0), Vector2(256,0), Vector2(256,48), Vector2(0,48)]),                 Vector2(0,48),  Vector2(256,48)],
		["Step_Small",     PackedVector2Array([Vector2(0,64), Vector2(128,64), Vector2(128,0), Vector2(256,0), Vector2(256,128), Vector2(0,128)]), Vector2(0,64), Vector2(256,0)],
		["Gap_Bridge",     PackedVector2Array([Vector2(0,0), Vector2(256,0), Vector2(256,32), Vector2(0,32)]),                 Vector2(0,0),   Vector2(256,0)],
		["Curve_Hill",     PackedVector2Array([Vector2(0,96), Vector2(43,40), Vector2(96,8), Vector2(160,8), Vector2(213,40), Vector2(256,96), Vector2(256,160), Vector2(0,160)]), Vector2(0,96), Vector2(256,96)],
	]

	var ok := 0
	for m in modules:
		var path: String = OUT_DIR + "%s.tscn" % m[0]
		var err := _build_one(script, m[0], m[1], m[2], m[3], path)
		if err == OK:
			ok += 1
			print("저장 완료: ", path)
		else:
			print("저장 실패(", err, "): ", path)

	print("MODULES_DONE  %d/10" % ok)
	quit(0 if ok == 10 else 1)

## 모듈 1개를 구성해 .tscn 으로 저장
func _build_one(script: Script, mod_name: String, poly: PackedVector2Array,
		entry: Vector2, exit: Vector2, path: String) -> int:
	# 루트: StaticBody2D + platform.gd
	var root := StaticBody2D.new()
	root.name = mod_name
	root.set_script(script)

	# Preview: 비주얼(임시). platform.gd 가 color_state 에 맞춰 색을 칠한다
	var prev := Polygon2D.new()
	prev.name = "Preview"
	prev.polygon = poly
	prev.color = Color(0.05, 0.05, 0.05)   # BLACK 기본
	root.add_child(prev)
	prev.owner = root

	# CollisionPolygon2D: 깔끔한 충돌 1개
	var col := CollisionPolygon2D.new()
	col.name = "CollisionPolygon2D"
	col.polygon = poly
	root.add_child(col)
	col.owner = root

	# DeathDetector(Area2D) + 색 판정 폴리곤
	var dd := Area2D.new()
	dd.name = "DeathDetector"
	dd.monitoring = false
	root.add_child(dd)
	dd.owner = root
	var ddcol := CollisionPolygon2D.new()
	ddcol.name = "CollisionPolygon2D"
	ddcol.polygon = poly
	dd.add_child(ddcol)
	ddcol.owner = root

	# SnapPoints: 이어붙임 기준점
	var snap := Node2D.new()
	snap.name = "SnapPoints"
	root.add_child(snap)
	snap.owner = root
	var e := Marker2D.new()
	e.name = "Entry"
	e.position = entry
	snap.add_child(e)
	e.owner = root
	var x := Marker2D.new()
	x.name = "Exit"
	x.position = exit
	snap.add_child(x)
	x.owner = root

	# 패킹 후 저장
	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		return perr
	return ResourceSaver.save(packed, path)
