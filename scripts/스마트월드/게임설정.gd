extends RefCounted
## ============================================================================
## [2026-08-02 신규] 게임 설정 저장/불러오기 (밝기 등)
## ----------------------------------------------------------------------------
## ▣ 왜 오토로드가 아니라 static 클래스인가
##   project.godot 의 [autoload] 를 건드리면 **모든 씬**(zone_01, world_1, 스테이지 1~5…)의
##   실행 환경이 바뀐다. 다른 작업자 씬이 깨질 위험을 감수할 이유가 없다.
##   설정은 "파일에서 읽고 쓰기"가 전부라 상태를 들고 있을 필요가 없으므로 static 으로 충분하다.
##   → 나중에 팀이 오토로드로 승격하기로 하면 이 파일을 그대로 등록만 하면 된다.
##
## ▣ 저장 위치
##   user://설정.cfg  (윈도우 기준 %APPDATA%\Godot\app_userdata\dev_4\설정.cfg)
##   프로젝트 폴더가 아니라 사용자 폴더라 git 에 안 들어가고, 사람마다 값이 다를 수 있다.
##
## ▣ 밝기를 어떻게 적용하나
##   씬의 CanvasModulate 색을 곱한다. 1.0 = 스테이지가 원래 의도한 밝기,
##   0.5 = 절반으로 어둡게, 1.6 = 밝게. 셰이더나 Environment 를 쓰지 않으므로
##   어느 씬에든 CanvasModulate 하나만 있으면 그대로 동작한다.
## ============================================================================
class_name 게임설정

const 파일 := "user://설정.cfg"
const 구역 := "화면"

## 밝기 배수의 허용 범위. 너무 어두우면 아무것도 안 보이고,
## 너무 밝으면 흑백 게임의 명도 규칙(검정 지형 vs 회색)이 무너진다.
const 밝기_최소 := 0.45
const 밝기_최대 := 1.80
const 밝기_기본 := 1.00


static func 밝기_불러오기() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(파일) != OK:
		return 밝기_기본
	return clampf(float(cfg.get_value(구역, "밝기", 밝기_기본)), 밝기_최소, 밝기_최대)


static func 밝기_저장(값: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(파일)                     # 실패해도 무시 — 없으면 새로 만든다
	cfg.set_value(구역, "밝기", clampf(값, 밝기_최소, 밝기_최대))
	cfg.save(파일)


# ============================================================================
# [2026-08-07 도형] 전체화면
# ----------------------------------------------------------------------------
# ⚠ 로비(`scenes/lobby/lobby.gd`)는 예전부터 **`user://settings.cfg`** 라는
#   다른 파일에 전체화면을 저장해 왔다. 여기서 `user://설정.cfg` 에 따로 저장하면
#   **로비에서 켠 전체화면이 인게임 메뉴에서는 꺼진 것으로 보이는** 어긋남이 생긴다.
#   → 전체화면만은 **로비와 같은 파일·같은 키**를 읽고 쓴다. (밝기는 여기 파일 그대로)
# ============================================================================
const 로비_설정파일 := "user://settings.cfg"
const 로비_구역 := "video"


static func 전체화면_불러오기() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(로비_설정파일) != OK:
		# 파일이 없으면 지금 창 상태를 그대로 읽어 온다 (체크박스가 거짓말하지 않게)
		return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return bool(cfg.get_value(로비_구역, "fullscreen", false))


static func 전체화면_저장(켬: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(로비_설정파일)              # 실패해도 무시 — 로비의 다른 값(볼륨)은 보존된다
	cfg.set_value(로비_구역, "fullscreen", 켬)
	cfg.save(로비_설정파일)


static func 전체화면_적용(켬: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if 켬 else DisplayServer.WINDOW_MODE_WINDOWED)


## 씬 안의 CanvasModulate 를 찾아 밝기를 적용한다.
## `기준색` 은 스테이지가 원래 의도한 색 — 밝기 1.0 일 때의 값이다.
## (매번 곱하면 값이 계속 줄어들기 때문에, 항상 기준색에서 다시 계산해야 한다)
static func 밝기_적용(모듈레이트: CanvasModulate, 기준색: Color, 밝기: float) -> void:
	if 모듈레이트 == null:
		return
	모듈레이트.color = Color(
		clampf(기준색.r * 밝기, 0.0, 1.0),
		clampf(기준색.g * 밝기, 0.0, 1.0),
		clampf(기준색.b * 밝기, 0.0, 1.0),
		기준색.a)
