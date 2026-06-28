extends SceneTree
## ▼ 2026-06-28 배터리 게이지 시각 확인. 3개 상태(검정 60% / 흰색 80% / 검정 20%)를 키워서 렌더.
const OUT := "res://battery_shot_out.png"
var _frame := 0
func _initialize() -> void:
	get_root().add_child(_make(Vector2(40, 40), 0.6, false))
	get_root().add_child(_make(Vector2(40, 160), 0.8, true))
	get_root().add_child(_make(Vector2(40, 280), 0.2, false))
func _make(pos: Vector2, r: float, white: bool) -> Control:
	var bg := ColorRect.new(); bg.position = pos - Vector2(6,6); bg.size = Vector2(460,110); bg.color = Color(0.3,0.45,0.3)
	var b := BatteryGauge.new(); b.position = Vector2(6,6); b.scale = Vector2(1.8,1.8); b.set_state(r, white)
	bg.add_child(b); return bg
func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 20:
		var img := get_root().get_texture().get_image()
		if img: img.save_png(OUT); print("BATTERY_SHOT_DONE ", OUT)
		quit(0); return true
	return false
