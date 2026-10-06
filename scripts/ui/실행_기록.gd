extends Node
## 한 스테이지 입장부터 명시적인 완료까지 센다. 메뉴 이동과 통로 이동은 저장하지 않는다.
const 기본_파일 := "user://completed_runs.cfg"
var 저장_파일: String = 기본_파일
var 경과: float = 0.0
var 사망: int = 0
var 완료: bool = false
var 저장_오류: Error = OK
var 스테이지: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	스테이지 = get_parent().scene_file_path
	if get_parent().has_signal("사망함"):
		get_parent().connect("사망함", 사망_추가)
	if get_parent().has_signal("클리어됨"):
		get_parent().connect("클리어됨", 완료_저장)

func _process(delta: float) -> void:
	if not 완료:
		경과 += delta

func 사망_추가() -> void:
	if not 완료:
		사망 += 1

func 완료_저장() -> void:
	if 완료 or 스테이지.is_empty():
		return
	완료 = true
	var cfg := ConfigFile.new()
	var 읽기 := cfg.load(저장_파일)
	if 읽기 != OK and 읽기 != ERR_FILE_NOT_FOUND:
		저장_오류 = 읽기
		push_warning("기록 파일을 읽지 못해 기존 기록을 보존합니다.")
		return
	var 이번 := {"초": 경과, "사망": 사망, "완료시각": Time.get_datetime_string_from_system(true)}
	var 시간기록: Dictionary = cfg.get_value(스테이지, "최단시간", {})
	var 사망기록: Dictionary = cfg.get_value(스테이지, "최소사망", {})
	# 두 최고값은 서로 다른 실행일 수 있으므로 각각 자기 실행의 값과 날짜를 보존한다.
	if 시간기록.is_empty() or 경과 < float(시간기록.get("초", INF)):
		cfg.set_value(스테이지, "최단시간", 이번)
	if 사망기록.is_empty() or 사망 < int(사망기록.get("사망", 2147483647)):
		cfg.set_value(스테이지, "최소사망", 이번)
	cfg.set_value(스테이지, "최근완료", 이번)
	cfg.set_value(스테이지, "완료횟수", int(cfg.get_value(스테이지, "완료횟수", 0)) + 1)
	var 임시 := 저장_파일 + ".tmp"
	저장_오류 = cfg.save(임시)
	if 저장_오류 == OK:
		저장_오류 = DirAccess.rename_absolute(임시, 저장_파일)
	if 저장_오류 != OK:
		push_warning("완료 기록을 저장하지 못했습니다: %s" % error_string(저장_오류))

static func 불러오기(경로: String = 기본_파일) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(경로)
	return cfg

static func 시간_문자(초: float) -> String:
	var 십분초 := int(maxf(초, 0.0) * 10.0)
	return "%02d:%02d.%d" % [십분초 / 600, (십분초 / 10) % 60, 십분초 % 10]
