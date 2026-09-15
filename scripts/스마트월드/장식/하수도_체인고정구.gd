@tool
extends Node2D
## ============================================================================
## [2026-09-14 신규] 하수도 체인 고정구 — 쇠사슬 끝이 허공에서 끊기지 않게 하는 판 + 고리
## ----------------------------------------------------------------------------
## ▣ 원점 = 볼트 판이 붙는 면의 가운데
##   천장용: 원점을 천장 밑면에 놓는다. 고리가 아래로 나온다. 자식 `연결점`(Marker2D)이 고리 중심.
##   발판용: `방향 = 발판` 이면 위아래를 뒤집어 판이 발판 윗면에 앉고 고리가 위로 나온다.
##   쇠사슬의 시작점/끝점 경로에 이 노드의 **`연결점`** 을 지정하면 체인 끝이 고리 안에 들어간다.
##   (`끝단_겹침` 기본 6 이 고리 두께 뒤로 체인 끝을 숨긴다)
##
## ▣ 승강기에 붙일 때
##   고정구를 승강기(움직이는발판)의 **자식**으로 넣으면 같이 움직이고, 그 `연결점` 을 체인의 끝점으로 잡는다.
##   충돌·색 규칙 없음(프롬프트 §8).
## ============================================================================

const 기본_텍스처 := "res://assets/decorations/sewer_support_v01/chain_anchor.png"

enum 방향_ { 천장, 발판 }

@export var 방향: 방향_ = 방향_.천장:
	set(v):
		방향 = v
		_배치()
@export var 텍스처: Texture2D:
	set(v):
		텍스처 = v
		_배치()
@export var 색조: Color = Color(1, 1, 1, 1):
	set(v):
		색조 = v
		_배치()

## 고리 중심이 판 윗변에서 얼마나 떨어져 있나 (chain_anchor.png 40×28 기준 20).
const 고리_거리 := 20.0

var _그림: Sprite2D = null
var _연결점: Marker2D = null


func _ready() -> void:
	if 텍스처 == null:
		텍스처 = load(기본_텍스처)
	_배치()


func _준비() -> void:
	if _그림 == null or not is_instance_valid(_그림):
		_그림 = get_node_or_null("그림") as Sprite2D
		if _그림 == null:
			_그림 = Sprite2D.new()
			_그림.name = "그림"
			add_child(_그림)
			if Engine.is_editor_hint() and owner != null:
				_그림.owner = owner
	if _연결점 == null or not is_instance_valid(_연결점):
		_연결점 = get_node_or_null("연결점") as Marker2D
		if _연결점 == null:
			_연결점 = Marker2D.new()
			_연결점.name = "연결점"
			add_child(_연결점)
			if Engine.is_editor_hint() and owner != null:
				_연결점.owner = owner


func _배치() -> void:
	if not is_inside_tree():
		return
	_준비()
	_그림.texture = 텍스처
	_그림.modulate = 색조
	var 뒤집 := 방향 == 방향_.발판
	_그림.flip_v = 뒤집
	if 텍스처 != null:
		# 그림의 해상도와 월드 표시 크기를 분리해 연결점20px가 변하지 않게 한다.
		_그림.scale = Vector2(40, 28) / 텍스처.get_size()
		var h := 28.0
		_그림.position = Vector2(0, (-h * 0.5) if 뒤집 else (h * 0.5))
	_연결점.position = Vector2(0, (-고리_거리) if 뒤집 else 고리_거리)
	_그림.z_index = 1          # 체인 끝을 덮어 가린다
	_그림.z_as_relative = true


## 체인이 닿을 자리(월드).
func 연결점_월드() -> Vector2:
	_준비()
	return _연결점.global_position
