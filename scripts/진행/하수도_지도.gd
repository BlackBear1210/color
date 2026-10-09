extends "res://scripts/ui/퍼즐보드.gd"
## 챕터2도 집과 같은 사진·물감 UI를 사용한다. 연결은 게임진행의 하수도 표가 관리한다.
func _ready() -> void:
	게임진행.선택_쳅터 = 2
	super()
