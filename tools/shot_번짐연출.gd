extends SceneTree
## [2026-08-29 신규] 잉크 번짐 연출을 눈으로 확인하는 캡처 (창모드 실행 필요)
## 실행: godot --path . -s res://tools/shot_번짐연출.gd
## 결과: tools/_shots/번짐_{01..04}.png  (맞은 직후 → 퍼지는 중 → 흘러내림 → 완성)

## 기본은 나무 SOLID. `-- <씬경로> <접두어>` 로 다른 씬도 찍을 수 있다.
const 기본씬 := "res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"
const 색상 := preload("res://scripts/color_defs.gd")
const 찍을때 := { 6: "01", 16: "02", 34: "03", 90: "04" }

var _n := 0
var _지형: Node = null
var _씬 := ""
var _접두어 := "번짐"

func _init() -> void:
	Engine.max_fps = 60
	process_frame.connect(_틱)

func _틱() -> void:
	_n += 1
	if _n == 1:
		var 배경 := ColorRect.new()
		배경.color = Color(0.42, 0.42, 0.46)      # 회색 배경 — 흑/백이 둘 다 보인다
		# ⚠ SS2D 채우기는 z_index -1 로 그려진다. 배경을 0 에 두면 채움이 배경 뒤로 숨어
		#   "속이 빈 액자" 처럼 찍힌다 (실제로 한 번 그렇게 찍혔다).
		배경.z_index = -10
		배경.size = Vector2(1152, 648)
		배경.position = Vector2(-576, -324)
		root.add_child(배경)
		var args := OS.get_cmdline_user_args()
		_씬 = args[0] if args.size() >= 1 else 기본씬
		_접두어 = args[1] if args.size() >= 2 else "번짐"
		var 팩 := (load(_씬) as PackedScene).instantiate()
		_지형 = 팩 if 팩.has_method("반대색인가") else 팩.get_child(0)
		root.add_child(팩)
		root.add_child(_지형)
		var cam := Camera2D.new()
		cam.zoom = Vector2(1.6, 1.6)
		root.add_child(cam)
		cam.make_current()
		return
	if _n == 4:
		# 왼쪽 위 구석에 한 발 — 퍼지는 방향과 흘러내림이 잘 보이는 자리
		_지형.명중(색상.WHITE, _지형.to_global(Vector2(-170, -40)))
	if _n == 60:
		for i in 12:
			_지형.명중(색상.WHITE, _지형.to_global(Vector2(60, -20)))
	if 찍을때.has(_n):
		var img := root.get_texture().get_image()
		img.save_png("res://tools/_shots/%s_%s.png" % [_접두어, 찍을때[_n]])
		print("찍음: %s_%s.png" % [_접두어, 찍을때[_n]])
	if _n > 95:
		quit()
