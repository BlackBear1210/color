@tool
extends "res://scripts/스마트월드/유체.gd"
## 기존 경로를 유지한 세 색 공용 외관. 물의 혼합 시에도 현재 색을 전달한다.
## 2-1의 선택된 물에만 적용. 혼합/도색 제거/켜짐은 기존 유체가 담당한다.
const WHITE_DESIGN = preload("res://scenes/장식/유체/흰물_디자인.tscn")
var _white_visual: Node2D
var _white_active: bool = false

## 호퍼 유입은 바닥 충돌이 아니므로 끝에서 물보라가 터지지 않게 한다.
@export var 호퍼_유입: bool = false:
	set(value):
		호퍼_유입 = value
		_물_애니_크기_맞추기()

func _ready() -> void:
	super._ready()
	# 상위 _ready 안에서 호출될 때는 준비 검사 때문에 외관 생성이 미뤄질 수 있다.
	call_deferred("_물_그림_갱신")

func _새물인가() -> bool:
	return 종류 == 종류_.물

func _물_그림_갱신() -> void:
	super._물_그림_갱신()
	if not is_node_ready():
		return
	if not is_instance_valid(_white_visual):
		_white_visual = WHITE_DESIGN.instantiate()
		_white_visual.name = "WhiteWaterV2"
		_white_visual.z_index = 2
		add_child(_white_visual)
	var active := _새물인가()
	_white_visual.visible = active
	if active:
		for animation_node in [_물_애니(), _물_상세_애니()]:
			if animation_node != null:
				animation_node.stop()
				animation_node.visible = false
	_물_애니_크기_맞추기()
	if active != _white_active:
		_white_active = active
		# 혼합 판정 도중 색이 바뀌어도 물리 서버 조회 중 도형을 수정하지 않는다.
		call_deferred("_물_판정_갱신")
	queue_redraw()

func _물_애니_크기_맞추기() -> void:
	super._물_애니_크기_맞추기()
	if is_instance_valid(_white_visual):
		_white_visual.set("착수_물보라", not 호퍼_유입)
		_white_visual.set("물색", int(색))
		_white_visual.set("크기", 크기)
		_white_visual.set("흐름속도", 흐름속도)
		_white_visual.set("형태", 1 if 크기.x >= 160.0 else 0)

func _판정_폴리곤들(frame_index: int) -> Array:
	if not _새물인가():
		return super._판정_폴리곤들(frame_index)
	# v2 가장자리 분무/착수 물보라는 비위험 장식. 밝은 연속 몸통만 접촉 판정한다.
	# 새 그림 위에 이전 프레임의 불규칙한 섬 폴리곤을 남기지 않는다.
	var inset := minf(7.0, 크기.x * 0.2)
	var half_width := maxf(1.0, 크기.x * 0.5 - inset + 판정_여유)
	var top := minf(3.0, 크기.y * 0.1)
	var bottom := maxf(top + 1.0, 크기.y - minf(9.0, 크기.y * 0.2))
	return [PackedVector2Array([Vector2(-half_width, top), Vector2(half_width, top), Vector2(half_width, bottom), Vector2(-half_width, bottom)])]

func _물_애니_재생중() -> bool:
	return (is_instance_valid(_white_visual) and _새물인가()) or super._물_애니_재생중()

func _process(delta: float) -> void:
	if not _새물인가():
		super._process(delta)
		return
	# GPU TIME으로 재생한다. 매 프레임 충돌 재생성과 queue_redraw를 피한다.
	if is_instance_valid(_white_visual) and _white_visual.get("흐름속도") != 흐름속도:
		_white_visual.set("흐름속도", 흐름속도)
