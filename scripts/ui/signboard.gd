extends Node2D
## 튜토리얼 표지판.
## - 플레이어가 가까이 오면 설명 팝업이 뜬다.
## - ESC 키 또는 "닫기(X)" 버튼으로 닫는다.
## - 한 번 닫으면 다시는 뜨지 않는다. (한 번만 보여줌)
##
## 표지판마다 인스펙터의 Message 칸에 다른 설명을 적을 수 있다.

## 팝업에 표시할 설명 글 (인스펙터에서 여러 줄 입력 가능)
@export_multiline var message: String = "여기에 설명을 입력하세요."

# ── 내부 상태 ────────────────────────────────────────────────
var _already_shown: bool = false   # 한 번이라도 닫았으면 true → 다시 안 뜸
var _is_open: bool = false          # 지금 팝업이 열려 있는지

# ── 노드 참조 (씬 구조와 경로가 일치해야 함) ──────────────────
@onready var _detect: Area2D     = $DetectZone
@onready var _popup: Control     = $UI/Popup
@onready var _label: Label       = $UI/Popup/Panel/Message
@onready var _close_btn: Button  = $UI/Popup/Panel/CloseButton

func _ready() -> void:
	# 시작 시 팝업은 꺼둔다
	_popup.visible = false
	# 인스펙터에 적은 설명 글을 라벨에 반영
	_label.text = message

	# 플레이어가 감지 영역에 들어오면 _on_player_near 실행
	_detect.body_entered.connect(_on_player_near)
	# 닫기 버튼을 누르면 _close 실행
	_close_btn.pressed.connect(_close)

func _on_player_near(body: Node) -> void:
	# 플레이어이고, 아직 한 번도 안 보여줬다면 팝업을 연다
	if body.is_in_group("player") and not _already_shown:
		_open()

func _open() -> void:
	_is_open = true
	_popup.visible = true

func _close() -> void:
	_popup.visible = false
	_is_open = false
	_already_shown = true   # 이제부터 다시는 안 뜸

func _unhandled_input(event: InputEvent) -> void:
	# 팝업이 열려 있을 때 ESC(ui_cancel)를 누르면 닫는다
	if _is_open and event.is_action_pressed("ui_cancel"):
		_close()
		# 이 입력을 다른 노드가 또 처리하지 않도록 소비 처리
		get_viewport().set_input_as_handled()
