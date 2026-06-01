@tool
extends Area2D
## 가시(Thorn) 장애물 — 닿으면 즉시 사망. 색과 무관하게 모두 위험.
## 이미지의 뾰족뾰족한 알파 모양 그대로 사망 판정 영역이 자동 생성된다.
## (작은 삼각형 1개는 기존 SpikeObstacle 을 쓰고, Platform_Thorn 처럼
##  넓고 불규칙한 가시 띠는 이 ThornObstacle 로 처리하면 편하다.)
##
## ◆ 사용법(에디터)
##   1) 이 씬(ThornObstacle)을 스테이지에 인스턴스
##   2) 자식 Sprite2D 에 가시 PNG 드래그 (예: Platform_Thorn_01.png)
##   3) 인스펙터의 "Bake Collision" 체크 → 가시 모양대로 판정 영역 자동 생성
##
## ※ 가시는 "밟는 발판"이 아니라 "닿으면 죽는 영역"이므로 물리 충돌 본체가 없는
##    Area2D 다. 플레이어는 가시를 물리적으로 통과하지만 닿는 순간 사망한다.

@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5
@export_range(0.5, 20.0, 0.5) var simplify: float = 3.0

@export var bake_collision: bool = false:
	set(value):
		bake_collision = false
		if Engine.is_editor_hint():
			_bake()

func _ready() -> void:
	# Area2D 설정: 플레이어(layer1)만 감지. 자신은 감지 대상이 아님(monitorable=false).
	collision_layer = 0
	collision_mask  = 1          # layer 1 = player
	monitoring      = true
	monitorable     = false

	if Engine.is_editor_hint():
		return

	# 총알이 가시에 닿아도 PaintMark 가 생기지 않도록 차단 (bullet.gd 의 obstacle 예외)
	add_to_group("obstacle")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# 물리 콜백 내 직접 die() 호출은 flush 오류 → call_deferred 필수
		body.call_deferred("die")

# ── 판정 영역 자동 생성 ───────────────────────────────────────────
func _bake() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	var root := get_tree().edited_scene_root
	var n := AutoCollision.bake_into(self, spr, alpha_threshold, simplify, root)
	if n == 0:
		push_warning("ThornObstacle '%s': 판정 영역 생성 실패 — Sprite2D 텍스처/알파를 확인하세요." % name)
	else:
		print("ThornObstacle '%s': 폴리곤 %d개 생성 완료." % [name, n])
