extends Area2D
## 스테이지 출구 포탈.
## 플레이어가 닿으면 "스테이지 클리어 팝업"을 띄운다.
##
## ── 다음 스테이지 경로 지정 방법 ───────────────────────────────────────
##   인스펙터의 "Next Stage Path" 항목에서 *.tscn 파일을 직접 선택.
##   비워 두면 SceneManager.next_stage() (현재 스테이지 번호 +1) 로 자동 이동.

const CLEAR_POPUP: PackedScene = preload("res://scenes/ui/ClearPopup.tscn")

## 인스펙터에서 다음 씬을 직접 지정. 비워 두면 SceneManager 자동 처리.
@export_file("*.tscn") var next_stage_path: String = ""

var _used: bool = false   # 한 번만 발동 (중복 방지)

func _ready() -> void:
	# 플레이어(layer 1)만 감지
	collision_layer = 0
	collision_mask  = 1
	monitoring      = true
	monitorable     = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	# 물리 콜백 도중 노드 추가는 안전하지 않으므로 다음 프레임에 실행
	call_deferred("_show_clear_popup")

func _show_clear_popup() -> void:
	var popup := CLEAR_POPUP.instantiate()
	# next_stage_path 가 설정되어 있으면 팝업에 전달 → 팝업이 그 경로로 이동
	# 비어 있으면 팝업이 SceneManager.next_stage() 를 자동으로 호출
	if not next_stage_path.is_empty():
		popup.next_stage_path = next_stage_path
	get_tree().current_scene.add_child(popup)
