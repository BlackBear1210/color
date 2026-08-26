extends SceneTree
## ============================================================================
## [2026-08-27 신규] 작업자 Template 9 종을 한 화면에 늘어놓고 **눈으로** 본다
## ----------------------------------------------------------------------------
## 실행(창모드 필요 — 헤드리스는 렌더 안 됨):
##   Godot --path . -s res://tools/시각_템플릿점검.gd -- <저장.png> [재질군]
##     재질군 생략 = 9 종 전부 / "BRICK" / "WOOD" / "GRASS"
##
## ▣ 왜 필요한가
##   숫자(콜리전 vs 메시 AABB)로는 "코너가 예쁜가" 를 못 잰다.
##   `진단_콜리전대_그림.gd` 가 어긋난 px 을 재고, 이 도구가 **모양**을 본다. 둘이 짝이다.
##
## ▣ 콜리전을 초록 선으로 같이 그린다
##   그림과 밟는 자리가 어긋나면 그 자리에서 바로 보인다.
## ============================================================================

const 키트 := "res://scenes/집/스마트 매쉬 assets/"
const 목록 := {
	"BRICK": [
		키트 + "BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn",
		키트 + "BRICK_벽돌/TEMPLATE_BRICK_HOLLOW.tscn",
		키트 + "BRICK_벽돌/TEMPLATE_BRICK_STAIRS.tscn",
	],
	"WOOD": [
		키트 + "WOOD_나무/TEMPLATE_WOOD_SOLID.tscn",
		키트 + "WOOD_나무/TEMPLATE_WOOD_HOLLOW.tscn",
		키트 + "WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn",
	],
	"GRASS": [
		키트 + "GRASS_잔디/TEMPLATE_GRASS_SOLID.tscn",
		키트 + "GRASS_잔디/TEMPLATE_GRASS_HOLLOW.tscn",
		키트 + "GRASS_잔디/TEMPLATE_GRASS_STAIRS.tscn",
	],
}

var _n := 0
var _루트: Node2D = null


func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)


func _틱() -> void:
	_n += 1
	var a := OS.get_cmdline_user_args()
	if _n == 1:
		_루트 = Node2D.new()
		root.add_child(_루트)

		var 군 := String(a[1]) if a.size() > 1 else ""
		var 쓸것: Array = []
		if 군 != "" and 목록.has(군):
			쓸것 = (목록[군] as Array).duplicate()
		else:
			for k in ["BRICK", "WOOD", "GRASS"]:
				쓸것.append_array(목록[k] as Array)

		# 가로로 늘어놓는다. SOLID/HOLLOW 는 512 폭, STAIRS 는 900 폭이라 넉넉히 띄운다.
		var x := -1900.0
		var y := -500.0
		var 칸 := 0
		for 경로 in 쓸것:
			var s := load(경로) as PackedScene
			if s == null:
				continue
			var 지형: Node2D = s.instantiate()
			지형.position = Vector2(x, y)
			_루트.add_child(지형)
			_콜리전_그리기(지형)
			x += 1250.0
			칸 += 1
			if 칸 % 3 == 0:
				x = -1900.0
				y += 900.0

		var cam := Camera2D.new()
		cam.position = Vector2(-650, 250)
		cam.zoom = Vector2(0.42, 0.42)
		_루트.add_child(cam)
		cam.make_current()
	elif _n == 60:
		var img := root.get_viewport().get_texture().get_image()
		print("shot: ", error_string(img.save_png(a[0])), " -> ", a[0])
		quit(0)


## 콜리전 폴리곤을 **초록 선**으로 덧그린다. 그림과 어긋나면 바로 보인다.
func _콜리전_그리기(지형: Node2D) -> void:
	var poly := 지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if poly == null or poly.polygon.size() < 3:
		return
	var l := Line2D.new()
	var 점 := PackedVector2Array(poly.polygon)
	점.append(poly.polygon[0])
	l.points = 점
	l.width = 4.0
	l.default_color = Color(0.2, 1.0, 0.45, 0.9)
	l.z_index = 50
	l.z_as_relative = false
	지형.add_child(l)
