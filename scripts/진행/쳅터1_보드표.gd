extends RefCounted
## ============================================================================
## [2026-10-09 Claude 신규] 쳅터1 퍼즐 보드 표 — 조각(스테이지) · 실(앞 조각) · 출구 · 숨은 길의 규칙을 한곳에
## ----------------------------------------------------------------------------
## ▣ 표의 출처 = `scenes/lobby/퍼즐보드_쳅터1.json` (위치·순서·문구를 바꾸려면 그 파일만 고친다).
## ▣ 누가 쓰나
##   · 퍼즐보드.gd(그림) — 조각 상태(잠김/열림/클리어) · 기록 · 사진.
##   · 전경전환.gd — 길목을 지날 때 `출구인가()` 로 "앞으로 나가는 길목" 이면 클리어를 적는다.
##   · 타이틀.gd — 이어하기(아직 안 깬 첫 조각).
## ▣ 규칙
##   · 열림 = 앞 조각이 없거나(첫 조각) 앞 조각 중 하나라도 클리어. **숨은 조각**은 입구를 찾았을 때(방문) 열린다.
##   · 클리어 = 그 스테이지의 '출구' 길목으로 앞으로 나감(조건 "열쇠" = 그 열쇠 두 조각을 들고 나가야).
##   · 기록(최단 시간 · 최소 사망) = user://completed_runs.cfg (실행_기록.gd — 클리어 때 월드.스테이지_완료 가 적는다).
## ============================================================================

const 표_경로 := "res://scenes/lobby/퍼즐보드_쳅터1.json"
const 스테이지_폴더 := "res://scenes/쳅터1/스테이지/"
const 기록형 := preload("res://scripts/ui/실행_기록.gd")
const 스냅_폴더 := "user://스냅/"

static var _표: Dictionary = {}
static var _하수도표: Dictionary = {}


static func 표() -> Dictionary:
	# 챕터2도 동일한 사진 카드로 표시하되 기존 진행 표의 연결·해금 규칙을 그대로 읽는다.
	if 게임진행.선택_쳅터 == 2:
		if _하수도표.is_empty():
			var 다: Array = []
			for 칸 in 게임진행.하수도_지도:
				var 위치: Vector2 = 칸[2]
				다.append({"id": 칸[0], "씬": 게임진행.씬경로(칸).get_basename(), "이름": 게임진행.하수도_이름.get(칸[0], ""), "위치": [위치.x * 0.88 + 0.06, 위치.y * 0.64 + 0.17], "앞": 칸[3], "입구": "입구통로", "길": "하수도"})
			_하수도표 = {"제목": "쳅터 2 · 하수도", "조각": 다, "길": [{"이름": "하수도", "조각": 다.map(func(c): return c["id"]), "문구": "지워지는 물 너머로"}]}
		return _하수도표
	if _표.is_empty():
		var 글 := FileAccess.get_file_as_string(표_경로)
		var d = JSON.parse_string(글)
		_표 = d if d is Dictionary else {"조각": [], "길": []}
	return _표


static func 조각들() -> Array:
	return 표().get("조각", [])


static func 길들() -> Array:
	return 표().get("길", [])


static func 씬경로(조각: Dictionary) -> String:
	if String(조각["씬"]).begins_with("res://"):
		return String(조각["씬"]) + ".tscn"
	return 스테이지_폴더 + String(조각["씬"]) + ".tscn"


static func 찾기(id: String) -> Dictionary:
	for c in 조각들():
		if String(c["id"]) == id:
			return c
	return {}


static func 경로로_찾기(경로: String) -> Dictionary:
	# 실행 중인 집의 출구 판정은 선택창이 마지막으로 열었던 챕터와 무관해야 한다.
	if _표.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(표_경로))
		_표 = d if d is Dictionary else {"조각": [], "길": []}
	for c in _표.get("조각", []):
		if 씬경로(c) == 경로:
			return c
	return {}


static func 클리어함(조각: Dictionary) -> bool:
	if String(조각.get("씬", "")).begins_with(게임진행.하수도_폴더):
		return 게임진행.클리어함(String(조각["id"]))
	return not 조각.is_empty() and 게임진행.쳅터1_클리어함(씬경로(조각))


static func 발견함(조각: Dictionary) -> bool:
	return not bool(조각.get("숨김", false)) or 게임진행.방문함(씬경로(조각)) or 클리어함(조각)


static func 열림(조각: Dictionary) -> bool:
	if 조각.is_empty():
		return false
	if bool(조각.get("숨김", false)):
		return 발견함(조각)
	var 앞: Array = 조각.get("앞", [])
	if 앞.is_empty():
		return true
	for id in 앞:
		if 클리어함(찾기(String(id))):
			return true
	return false


## 전경전환이 묻는다 — 이 씬에서 이 길목으로 나가면 클리어인가(조건까지 본다)
static func 출구인가(경로: String, 길목: String) -> bool:
	var c := 경로로_찾기(경로)
	if c.is_empty() or not (c.get("출구", []) as Array).has(길목):
		return false
	if String(c.get("조건", "")) == "열쇠":
		var 열쇠씬 := 스테이지_폴더 + String(c.get("열쇠_씬", c["씬"])) + ".tscn"
		return 게임진행.열쇠_조각_있나(열쇠씬, "왼쪽") and 게임진행.열쇠_조각_있나(열쇠씬, "오른쪽")
	return true


## [2026-10-10 Claude] 열쇠 스테이지 표시 — 표 "열쇠" 칸(도안에서 `사진지도_정비.py` 가 채운다):
##   true = 이 스테이지 출구가 잠긴 문 · "<씬 이름>" = 이 스테이지에 그 스테이지 문을 여는 조각이 있다(18 → 17).
## 열쇠 진행을 적는 씬 경로(문이 있는 스테이지) · 열쇠 스테이지가 아니면 "".
static func 열쇠_씬(조각: Dictionary) -> String:
	var v = 조각.get("열쇠", null)
	if v is bool and v:
		return 씬경로(조각)
	if v is String and v != "":
		return 스테이지_폴더 + v + ".tscn"
	return ""


## 카드에 그릴 열쇠 진행 — {"왼쪽": 검정 조각, "오른쪽": 흰 조각, "열림": 문을 열었나, "주인": 다른 스테이지 열쇠면 그 씬 경로} · 아니면 빈 사전
static func 열쇠_진행(조각: Dictionary) -> Dictionary:
	var 씬 := 열쇠_씬(조각)
	if 씬 == "":
		return {}
	return {"왼쪽": 게임진행.열쇠_조각_있나(씬, "왼쪽"), "오른쪽": 게임진행.열쇠_조각_있나(씬, "오른쪽"),
		"열림": 게임진행.열쇠_문_열림(씬), "주인": "" if 씬 == 씬경로(조각) else 씬}


## 최단 시간 · 최소 사망(없으면 빈 사전)
static func 기록(조각: Dictionary) -> Dictionary:
	var cfg := 기록형.불러오기()
	var 경로 := 씬경로(조각)
	var 시간: Dictionary = cfg.get_value(경로, "최단시간", {})
	var 사망: Dictionary = cfg.get_value(경로, "최소사망", {})
	if 시간.is_empty() and 사망.is_empty():
		return {}
	return {"초": float(시간.get("초", 0.0)), "사망": int(사망.get("사망", 0)), "횟수": int(cfg.get_value(경로, "완료횟수", 0))}


## 그 스테이지에서 찍어 둔 사진(없으면 null)
static func 사진(조각: Dictionary) -> Texture2D:
	var 파일 := 스냅_폴더 + String(조각["씬"]).get_file() + ".png"
	if not FileAccess.file_exists(파일):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(파일))
	return ImageTexture.create_from_image(img) if img else null


## 이어하기 — 열려 있고 아직 안 깬 첫 조각(표 순서). 다 깼으면 마지막 조각.
static func 이어할_조각() -> Dictionary:
	for c in 조각들():
		if not bool(c.get("숨김", false)) and 열림(c) and not 클리어함(c):
			return c
	var 다 := 조각들()
	return 다[다.size() - 1] if not 다.is_empty() else {}


static func 길_완료(길: Dictionary) -> bool:
	for id in 길.get("조각", []):
		if not 클리어함(찾기(String(id))):
			return false
	return true
