extends SceneTree
## ============================================================================
## [2026-09-14 신규] 지지구조 장식 비용 측정 — 정적 체인 · 동적 체인 · 지지대를 켜고/끄고 프레임 처리시간 비교
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/측정_지지구조_비용.gd -- 정적=20 동적=4 지지대=20 승강기=4
##   인자를 안 주면 위 값. [스프라이트=N] 은 같은 텍스처를 붙인 맨 Sprite2D N 개(비교용) · [스크립트떼기] 는 지지대 스크립트를 뗀다.
##   `--headless` 면 스크립트·엔진 갱신 비용만, `--rendering-method gl_compatibility` 로 돌리면 렌더까지 포함.
##
## ▣ 재는 법
##   `Performance.TIME_PROCESS + TIME_PHYSICS_PROCESS` 를 프레임마다 더한다(벽시계는 60Hz 물리 틱에 묶여 늘 16.7ms).
##   같은 프로세스에서 [기준(승강기만) → 장식 추가] 순으로 만들고, 각각 200 프레임 블록 3 개의 **최소값**을 쓴다
##   (첫 블록은 로드·캐시 때문에 늘 느리다). 수량(20/4/20)은 게임 요구량이 아니라 측정 예시다(프롬프트 §11).
## ============================================================================

const S_쇠사슬 := "res://scenes/장식/하수도_지지구조/쇠사슬.tscn"
const S_지지대 := "res://scenes/장식/하수도_지지구조/삼각지지대.tscn"
const S_승강기 := "res://scenes/집/스마트월드_장애물/움직이는발판.tscn"
const 블록프레임 := 200

var 정적수 := 20
var 동적수 := 4
var 지지대수 := 20
var 승강기수 := 4
var 비교스프라이트수 := 0
var 스크립트떼기 := false


func _initialize() -> void:
	# 60 으로 고정해야 process 프레임 수 ≈ physics 프레임 수 라 프레임당 처리시간이 뜻을 갖는다.
	Engine.max_fps = 60
	call_deferred("_go")


func _go() -> void:
	for a in OS.get_cmdline_user_args():
		var 글 := String(a)
		if 글.begins_with("정적="): 정적수 = int(글.trim_prefix("정적="))
		elif 글.begins_with("동적="): 동적수 = int(글.trim_prefix("동적="))
		elif 글.begins_with("지지대="): 지지대수 = int(글.trim_prefix("지지대="))
		elif 글.begins_with("승강기="): 승강기수 = int(글.trim_prefix("승강기="))
		elif 글.begins_with("스프라이트="): 비교스프라이트수 = int(글.trim_prefix("스프라이트="))
		elif 글 == "스크립트떼기": 스크립트떼기 = true
	동적수 = mini(동적수, 승강기수)
	print("\n── 지지구조 비용 · 정적 %d · 동적 %d · 지지대 %d · 승강기 %d · 비교 스프라이트 %d ──" % [정적수, 동적수, 지지대수, 승강기수, 비교스프라이트수])
	var 기준: Array = await _재기(false)
	var 장식: Array = await _재기(true)
	print("  기준(승강기만) : 프레임당 %.3f ms · 노드 %d" % [기준[0], int(기준[1])])
	print("  장식 추가      : 프레임당 %.3f ms · 노드 %d" % [장식[0], int(장식[1])])
	print("  차이           : 프레임당 %+.3f ms · 노드 %+d" % [장식[0] - 기준[0], int(장식[1] - 기준[1])])
	quit(0)


func _재기(장식_켬: bool) -> Array:
	var 루트 := Node2D.new()
	root.add_child(루트)
	var 승들 := []
	for i in 승강기수:
		var 승 := (load(S_승강기) as PackedScene).instantiate() as Node2D
		승.position = Vector2(500 + i * 400, 800)
		승.set("이동방향", 1); 승.set("이동거리", 400.0); 승.set("왕복시간", 5.0)
		루트.add_child(승)
		var m := Marker2D.new(); m.name = "끝"; m.position = Vector2(0, -14)
		승.add_child(m)
		승들.append(승)
	if 장식_켬:
		for i in 정적수:
			var c := (load(S_쇠사슬) as PackedScene).instantiate() as Node2D
			c.position = Vector2(100 + i * 60, 100)
			c.set("모드", 0); c.set("고정_끝", Vector2(0, 300 + i * 20))
			루트.add_child(c)
		for i in 지지대수:
			var b := (load(S_지지대) as PackedScene).instantiate() as Node2D
			b.position = Vector2(100 + i * 60, 1200)
			루트.add_child(b)
			if 스크립트떼기:
				b.set_script(null)
		for i in 비교스프라이트수:
			var sp := Sprite2D.new()
			sp.texture = load("res://assets/decorations/sewer_support_v01/bracket.png")
			sp.position = Vector2(100 + i * 30, 1500)
			루트.add_child(sp)
		for i in 동적수:
			var 천장 := Marker2D.new(); 천장.position = Vector2(500 + i * 400, 100)
			루트.add_child(천장)
			var c := (load(S_쇠사슬) as PackedScene).instantiate() as Node2D
			c.position = 천장.position
			루트.add_child(c)
			c.set("모드", 1)
			c.set("시작점_경로", c.get_path_to(천장))
			c.set("끝점_경로", c.get_path_to(승들[i].get_node("끝")))
	for i in 10:
		await physics_frame
	var 최소 := 1e18
	for k in 3:
		var 합 := 0.0
		for i in 블록프레임:
			await physics_frame
			합 += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		최소 = minf(최소, 합 * 1000.0 / float(블록프레임))
	var 노드 := _노드수(루트)
	루트.free()
	await physics_frame
	return [최소, 노드]


func _노드수(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		k += 1 + _노드수(c)
	return k
