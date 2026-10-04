@tool
extends Node2D
## ============================================================================
## [2026-10-04 신규 · Claude] 방 배경 — 프리셋대로 레이어를 방 크기에 맞춰 깐다
## ----------------------------------------------------------------------------
## ▣ 자식 구성
##   _레이어 (코드가 만든다 · 씬에 저장되지 않는다)  벽지 · 먼지 · 낡음 조각 · 징두리 · 걸레받이 · 천장몰딩
##   가구    (씬에 저장된다 · 에디터에서 끌어 옮겨도 된다)  Sprite2D 들
##
## ▣ 방 크기 = 카메라 리밋(도안 전체). 그 밖은 바깥 지형이 덮으므로 그리지 않는다.
##   벽지는 리밋보다 사방 여유(256px)만큼 더 깔아 카메라 흔들림에도 빈틈이 없다.
## ============================================================================

const 여유 := 256.0
const 낡음_폴더 := "res://assets/background/쳅터1/레이어_v01/낡음/"
const 낡음_조각 := {
	1: ["얼룩_1", "얼룩_2", "얼룩_3", "얼룩_4"],
	2: ["얼룩_1", "얼룩_3", "금_1", "금_2", "금_3", "벗겨짐_1", "벗겨짐_2", "벗겨짐_3"],
	3: ["얼룩_2", "얼룩_4", "금_1", "금_3", "벗겨짐_1", "벗겨짐_3", "찢김_1", "찢김_2"],
}
## 512×512 벽지 한 장 넓이당 조각 수 (낡음 단계별)
## [2026-10-04 2차] 엔진 촬영에서 낡음 3 의 조각이 너무 크고 많아 벽을 덮었다 → 밀도·크기·진하기를 낮춤
const 낡음_밀도 := [0.0, 0.22, 0.4, 0.6]

@export var 프리셋: Resource:
	set(v): 프리셋 = v; _재구성()
## 방(카메라 리밋) 크기 px. 원점 = 방 왼쪽 위.
@export var 방_크기: Vector2 = Vector2(3584, 1792):
	set(v): 방_크기 = v; _재구성()
## 바닥선 y(px) — 징두리·걸레받이가 붙는다. 0 이하면 방 아래 끝.
@export var 바닥_y: float = 0.0:
	set(v): 바닥_y = v; _재구성()
## 천장선 y(px) — 천장 몰딩이 붙는다.
@export var 천장_y: float = 96.0:
	set(v): 천장_y = v; _재구성()
## −1 = 프리셋 값을 쓴다. 0~3 = 이 방만 덮어쓴다.
@export_range(-1, 3) var 낡음_덮어쓰기: int = -1:
	set(v): 낡음_덮어쓰기 = v; _재구성()
## 낡음 조각 배치 씨앗. 같은 씨앗 = 같은 자리.
@export var 씨앗: int = 1:
	set(v): 씨앗 = v; _재구성()


func _ready() -> void:
	_재구성()


func _재구성() -> void:
	if not is_inside_tree():
		return
	var 옛 := get_node_or_null("_레이어")
	if 옛:
		remove_child(옛)
		옛.queue_free()
	if 프리셋 == null:
		return
	var 판 := Node2D.new()
	판.name = "_레이어"
	add_child(판)
	move_child(판, 0)
	var W := 방_크기.x
	var H := 방_크기.y
	var 바닥 := 바닥_y if 바닥_y > 0.0 else H
	var 낡음: int = 낡음_덮어쓰기 if 낡음_덮어쓰기 >= 0 else int(프리셋.get("낡음"))
	var 밝기: float = float(프리셋.get("벽지_밝기")) * (1.0 - float(프리셋.get("낡음_어둡게")) * 낡음)

	# 벽지
	var 벽지 := 프리셋.get("벽지") as Texture2D
	if 벽지:
		var s := _타일(벽지, Rect2(-여유, -여유, W + 여유 * 2.0, H + 여유 * 2.0), -100)
		s.modulate = Color(밝기, 밝기, 밝기)
		판.add_child(s)
	# 먼지 — 바닥 쪽이 짙어지는 띠
	if 낡음 >= 1:
		var 먼지 := load(낡음_폴더 + "먼지.png") as Texture2D
		if 먼지:
			var m := Sprite2D.new()
			m.texture = 먼지
			m.centered = false
			var 높이 := 256.0 * (1.0 + 낡음)
			m.position = Vector2(-여유, 바닥 - 높이)
			m.scale = Vector2((W + 여유 * 2.0) / 먼지.get_width(), 높이 / 먼지.get_height())
			m.modulate.a = 0.35 + 0.15 * 낡음
			m.z_index = -98
			판.add_child(m)
	# 낡음 조각
	if 낡음 >= 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = 씨앗 * 7919 + 낡음
		var 이름들: Array = 낡음_조각[낡음]
		var n := int(round(W * (바닥 - 천장_y) / (512.0 * 512.0) * 낡음_밀도[낡음]))
		for i in n:
			var t := load(낡음_폴더 + String(이름들[rng.randi() % 이름들.size()]) + ".png") as Texture2D
			if t == null:
				continue
			var d := Sprite2D.new()
			d.texture = t
			d.position = Vector2(rng.randf_range(0.0, W), rng.randf_range(천장_y + 64.0, 바닥 - 160.0))
			d.scale = Vector2.ONE * rng.randf_range(0.45, 0.95)
			d.rotation = rng.randf_range(-0.25, 0.25)
			d.flip_h = rng.randf() < 0.5
			d.modulate.a = rng.randf_range(0.35, 0.7)
			d.z_index = -96
			판.add_child(d)
	# 징두리 · 걸레받이 · 천장 몰딩
	var 징두리 := 프리셋.get("징두리") as Texture2D
	if 징두리:
		판.add_child(_타일(징두리, Rect2(-여유, 바닥 - 징두리.get_height(), W + 여유 * 2.0, 징두리.get_height()), -94))
	var 걸레 := 프리셋.get("걸레받이") as Texture2D
	if 걸레:
		판.add_child(_타일(걸레, Rect2(-여유, 바닥 - 걸레.get_height(), W + 여유 * 2.0, 걸레.get_height()), -93))
	var 몰딩 := 프리셋.get("천장_몰딩") as Texture2D
	if 몰딩:
		판.add_child(_타일(몰딩, Rect2(-여유, 천장_y, W + 여유 * 2.0, 몰딩.get_height()), -93))


func _타일(t: Texture2D, r: Rect2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = r.position
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, r.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.z_index = z
	return s
