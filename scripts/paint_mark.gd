extends Node2D
## 총알이 지형에 남긴 페인트 자국.
##
## ▸ Node2D 기반: 물리 충돌(StaticBody) 없음 → 플레이어가 페인트 위를 걸어도 지형처럼 막히지 않음
## ▸ "runtime_paint" 그룹: 플레이어 리스폰 시 player.gd 가 이 그룹 전체를 queue_free()
## ▸ JudgmentZone(Area2D): ColorSensor 가 감지해 색 판정에만 사용 (물리 없음)

@export var paint_color: int = ColorDefs.WHITE

@onready var _black_mark: Node2D = $BlackMark
@onready var _white_mark: Node2D = $WhiteMark
@onready var _zone:       Area2D = $JudgmentZone

func _ready() -> void:
	add_to_group("runtime_paint")         # 리스폰 때 일괄 제거
	add_to_group("paint_bodies")          # bullet 이 근처 기존 마크 탐색할 때 사용

	_zone.add_to_group("paint_marks")     # ColorSensor(player) 가 색 판정할 때 사용

	_apply(paint_color)
	_play_splat_tween()

## 같은 자리에 다시 쐈을 때 색만 덮어씀 (bullet.gd → call_deferred)
func update_color(new_color: int) -> void:
	paint_color = new_color
	_apply(paint_color)
	_play_splat_tween()

## 색에 맞는 그룹만 보이고, 그 안에서 랜덤으로 1개만 표시
func _apply(c: int) -> void:
	_black_mark.visible = (c == ColorDefs.BLACK)
	_white_mark.visible = (c == ColorDefs.WHITE)

	var group: Node2D = _black_mark if c == ColorDefs.BLACK else _white_mark
	var sprites := group.get_children()
	var pick: int = randi() % sprites.size()
	for i in sprites.size():
		sprites[i].visible = (i == pick)

## 페인트가 튀겼다가 스며드는 애니메이션
func _play_splat_tween() -> void:
	rotation  = randf_range(-0.4, 0.4)
	scale     = Vector2(1.4, 1.4)
	modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale",      Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0,         0.14)
