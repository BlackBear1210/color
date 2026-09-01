@tool
extends Node2D
## ============================================================================
## SS2D 배관의 양 끝을 원본 이음쇠로 마감한다.
## ----------------------------------------------------------------------------
## ▣ 왜 Sprite2D를 따로 쓰나
## SS2D의 열린 경로는 길이와 꺾임을 아주 편하게 처리하지만, 첫·마지막 점에만
## 나타나는 끝 이음쇠는 엣지 반복 텍스처로 표현할 수 없다. 원본에서 잘라낸 이음쇠를
## 별도 Sprite2D로 두고 점 배열의 양 끝을 따라가게 해야, 본체와 색감이 정확히 맞는다.
## 시작 이미지는 끝 이미지의 180도 짝이라, 시작 Sprite2D의 회전 뒤에도 양 끝 명암이 같다.
## ============================================================================

@export_node_path("SS2D_Shape") var 경로_노드: NodePath = NodePath("경로")
@export_node_path("Sprite2D") var 시작_끝마개: NodePath = NodePath("시작_끝마개")
@export_node_path("Sprite2D") var 끝_끝마개: NodePath = NodePath("끝_끝마개")
## 2D 작업 화면에서 호퍼·저장고 포트와 스냅할 수 있도록, SS2D 양 끝의 실제 점을 노출한다.
@export_node_path("Marker2D") var 시작_물_포트: NodePath = NodePath("시작_물_포트")
@export_node_path("Marker2D") var 끝_물_포트: NodePath = NodePath("끝_물_포트")

## 배관 재질의 texture_scale(0.22)와 같아야 띠 높이와 끝마개 높이가 정확히 맞는다.
@export var 끝마개_배율: float = 0.22

var _경로: SS2D_Shape


func _ready() -> void:
	call_deferred("_경로_연결")


func _경로_연결() -> void:
	_경로 = get_node_or_null(경로_노드) as SS2D_Shape
	if _경로 == null:
		push_warning("배관 끝마개: SS2D 경로를 찾지 못했다")
		return
	if not _경로.points_modified.is_connected(_끝마개_맞추기):
		# 점을 끌거나 추가할 때만 갱신한다. 에디터 매 프레임 계산을 피하기 위해서다.
		_경로.points_modified.connect(_끝마개_맞추기)
	_끝마개_맞추기()


func _끝마개_맞추기() -> void:
	if _경로 == null:
		return
	var 점들 := _경로.get_point_array().get_vertices()
	if 점들.size() < 2:
		return
	var 마지막 := 점들.size() - 1
	# 시작점은 첫 선분의 반대쪽이 바깥이다. 그래야 한 방향 끝마개가 양쪽에서 모두 밖을 향한다.
	_한쪽_맞추기(get_node_or_null(시작_끝마개) as Sprite2D, 점들[0], 점들[0] - 점들[1])
	_한쪽_맞추기(get_node_or_null(끝_끝마개) as Sprite2D, 점들[마지막], 점들[마지막] - 점들[마지막 - 1])
	_포트_맞추기(get_node_or_null(시작_물_포트) as Marker2D, 점들[0], 점들[0] - 점들[1])
	_포트_맞추기(get_node_or_null(끝_물_포트) as Marker2D, 점들[마지막], 점들[마지막] - 점들[마지막 - 1])


func _한쪽_맞추기(끝마개: Sprite2D, 위치: Vector2, 방향: Vector2) -> void:
	if 끝마개 == null or 방향.length_squared() <= 0.001:
		return
	끝마개.position = 위치
	끝마개.rotation = 방향.angle()
	끝마개.scale = Vector2.ONE * 끝마개_배율


## 포트는 게임에는 그려지지 않는 편집용 기준점이다. 유체 원점과 같은 좌표로 맞춘다.
func _포트_맞추기(포트: Marker2D, 위치: Vector2, 방향: Vector2) -> void:
	if 포트 == null or 방향.length_squared() <= 0.001:
		return
	포트.position = 위치
	포트.rotation = 방향.angle()
