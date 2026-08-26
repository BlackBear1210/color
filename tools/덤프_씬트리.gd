extends SceneTree
## ============================================================================
## [2026-08-26 신규] 씬 구조 덤프 — 큰 .tscn 을 눈으로 읽지 않고 파악한다
## ----------------------------------------------------------------------------
## 집 스테이지 .tscn 은 60~110KB 라 텍스트로 읽으면 맥락이 다 날아간다.
## 실제로 **로드해서** 노드 트리·스크립트·그룹·SS2D 점 개수·바운딩을 요약한다.
##
## 실행:
##   Godot --headless --path . -s res://tools/덤프_씬트리.gd -- <씬경로> [--깊이 N] [--점]
## ============================================================================

var _씬경로 := ""
var _최대깊이 := 4
var _점출력 := false
var _n := 0
var _루트: Node = null


func _init() -> void:
	Engine.max_fps = 60
	var args := OS.get_cmdline_user_args()
	var 다음이깊이 := false
	for a in args:
		if 다음이깊이:
			_최대깊이 = int(a)
			다음이깊이 = false
		elif a == "--깊이":
			다음이깊이 = true
		elif a == "--점":
			_점출력 = true
		elif not a.begins_with("--"):
			_씬경로 = a
	if _씬경로.is_empty():
		print("사용법: -s res://tools/덤프_씬트리.gd -- <씬경로> [--깊이 N] [--점]")
		quit(2)


func _process(_d: float) -> bool:
	_n += 1
	if _n == 2:
		var 씬 := load(_씬경로) as PackedScene
		if 씬 == null:
			print("씬을 못 읽음: ", _씬경로)
			quit(2)
			return true
		_루트 = 씬.instantiate()
		root.add_child(_루트)
	elif _n == 5:
		_찍기(_루트, 0)
		quit(0)
	return false


func _찍기(n: Node, 깊이: int) -> void:
	if 깊이 > _최대깊이:
		return
	var 들여 := "  ".repeat(깊이)
	var 줄 := "%s%s [%s]" % [들여, n.name, n.get_class()]

	var s: Script = n.get_script() as Script
	if s != null:
		줄 += "  <%s>" % (s.resource_path.get_file())

	if n is Node2D:
		var p := (n as Node2D).global_position
		줄 += "  @(%.0f, %.0f)" % [p.x, p.y]
		var sc := (n as Node2D).scale
		if not sc.is_equal_approx(Vector2.ONE):
			줄 += " x%.3f,%.3f" % [sc.x, sc.y]

	var g := n.get_groups()
	var 보일그룹: Array = []
	for x in g:
		var t := String(x)
		if not t.begins_with("_"):
			보일그룹.append(t)
	if not 보일그룹.is_empty():
		줄 += "  {%s}" % ", ".join(보일그룹)

	# SmartShape2D 요약
	if n.has_method("get_point_array"):
		var pa: Object = n.get_point_array()
		if pa != null:
			var 점들: Array = []
			for pk in pa.get_all_point_keys():
				점들.append(pa.get_point_position(pk))
			줄 += "  SS2D점=%d" % 점들.size()
			if 점들.size() > 0:
				var mn: Vector2 = 점들[0]
				var mx: Vector2 = 점들[0]
				for p2 in 점들:
					mn = Vector2(minf(mn.x, p2.x), minf(mn.y, p2.y))
					mx = Vector2(maxf(mx.x, p2.x), maxf(mx.y, p2.y))
				줄 += " 로컬범위(%.0f,%.0f)~(%.0f,%.0f) 크기%.0fx%.0f" \
					% [mn.x, mn.y, mx.x, mx.y, mx.x - mn.x, mx.y - mn.y]
				if _점출력:
					var 문자: Array = []
					for p3 in 점들:
						문자.append("(%.0f,%.0f)" % [p3.x, p3.y])
					줄 += "\n%s    점: %s" % [들여, " ".join(문자)]

	if n is CollisionPolygon2D:
		줄 += "  콜폴리곤점=%d" % (n as CollisionPolygon2D).polygon.size()
	if n is Sprite2D and (n as Sprite2D).texture:
		var t2: Texture2D = (n as Sprite2D).texture
		줄 += "  텍스처=%s %dx%d" % [t2.resource_path.get_file(), t2.get_width(), t2.get_height()]

	print(줄)
	for c in n.get_children():
		_찍기(c, 깊이 + 1)
