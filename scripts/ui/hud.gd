extends CanvasLayer
## 좌상단 플레이 기록 HUD (가로 배치).
## [ TIME 00:00 ]  [해골]  [ x0 ]
## 실제 값은 SceneManager(autoload)에 저장 → 스테이지를 넘어가도 유지된다.

@onready var _time_label: Label  = $Bar/Time
@onready var _death_label: Label = $Bar/Deaths

func _process(_delta: float) -> void:
	# 경과 시간(초)을 분:초로 변환
	var t: int = int(SceneManager.run_time)
	_time_label.text  = "TIME  %02d:%02d" % [t / 60, t % 60]
	# 해골 아이콘 옆 "x죽은횟수"
	_death_label.text = "x%d" % SceneManager.death_count
