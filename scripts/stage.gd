extends Node2D
## 각 스테이지의 베이스 스크립트.
## KillZone 에 빠진 바디에 die() 를 호출하고, Camera2D 맵 경계를 설정한다.

## 카메라가 이동 가능한 맵 경계 (픽셀 단위)
@export var camera_limit_left:   int = 0
@export var camera_limit_top:    int = 0
@export var camera_limit_right:  int = 100000
@export var camera_limit_bottom: int = 100000

# ▼ 2026-06-22 추가: 스테이지별 카메라 줌.
#   왜 필요한가: Player.tscn 의 Camera2D 는 Player(scale 0.3)의 자식이라 0.3 스케일을 상속한다.
#   그래서 줌 1.0 일 때 화면에 보이는 월드 영역이 (뷰포트/0.3) = 1152x648 → 약 3840x2160 으로 매우 넓다.
#   stage_2 처럼 지형 폭(약 2554px)이 이 가시폭보다 좁으면 좌/우 벽 '너머'(빈 배경)가 보인다.
#   → 스테이지에서 이 값을 주면 가시 영역을 좁혀(=줌 인) 지형만 화면에 담는다.
#   0(기본)이면 줌을 건드리지 않음 → 기존 stage_1/stage_3 동작 그대로 유지.
@export var camera_zoom: float = 0.0

# ▼ 2026-06-17: $ 직접경로 → get_node_or_null 로 변경.
#   이유: KillZone 이 없는 씬(예: 모듈 조립 템플릿)에서 @onready $경로가
#         "Node not found" 에러를 뱉었다. 선택적 노드이므로 null 허용으로 바꿈.
@onready var kill_zone: Area2D = get_node_or_null("MapPhysics/KillZone")

func _ready() -> void:
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)
	# Player 는 _ready() 이후에 추가되므로 한 프레임 뒤에 적용
	call_deferred("_apply_camera_limits")

func _apply_camera_limits() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left   = camera_limit_left
			cam.limit_top    = camera_limit_top
			cam.limit_right  = camera_limit_right
			cam.limit_bottom = camera_limit_bottom
			# ▼ 2026-06-22: 스테이지가 camera_zoom 을 지정하면 적용(0=미설정→그대로).
			#   Player 가 0.3 스케일이라, 화면 가시폭 = 뷰포트.x / (zoom * 0.3).
			#   stage_2 는 이 값으로 가시폭을 지형폭에 맞춰 '지형만' 보이게 한다.
			if camera_zoom > 0.0:
				cam.zoom = Vector2(camera_zoom, camera_zoom)

func _on_kill_zone_entered(body: Node) -> void:
	if body.has_method("die"):
		body.die()
