extends SceneTree
## ============================================================================
## [2026-10-05 Claude] 쳅터1 기믹 엔진 시험 — 경로 재생이 건너뛴 부분(타이밍 기믹)을 따로 확인한다
##   Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_기믹.gd
##
##   빛줄기(색 고정)  : 빛 한가운데 바닥에 ① 빛과 같은 색으로 세우면 산다 ② 반대색으로 세우면 죽는다
##   도약대           : 위에 떨어뜨려 튀어 오른 높이를 잰다 → 도안 "오름"(칸)과 비교(±1칸)
##   움직이는 발판    : 검정 몸으로 태우고 왕복 1회 기다린다 → 안 죽고, 발판과 함께 끝까지 실려 갔나
## 결과: res://tools/_진단/기믹시험.txt
## ============================================================================

## [2026-10-05 2차] 도안 폴더의 모든 쳅터1 도안을 훑는다(스테이지가 늘어도 목록을 고칠 필요 없음)
const 도안폴더 := "res://scenes/쳅터1/도안/"

var _줄: PackedStringArray = []
var _할일: Array = []          # [{씬, 종류, 노드이름, 경우}]
var _i := -1
var _씬: Node = null
var _p: CharacterBody2D = null
var _f := 0
var _죽음 := false
var _일: Dictionary
var _재기 := {}
var _실패 := 0


func _initialize() -> void:
	var 이름들 := []
	for f in DirAccess.get_files_at(도안폴더):
		if f.begins_with("쳅터1_") and f.ends_with(".json"):
			이름들.append(f.get_basename())
	이름들.sort()
	for 이름 in 이름들:
		var 씬 := "res://scenes/쳅터1/스테이지/%s.tscn" % 이름
		var 도안: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/쳅터1/도안/%s.json" % 이름))
		var 셈 := {}
		for g in 도안.get("기믹", []):
			var k: String = g["종류"]
			셈[k] = int(셈.get(k, 0)) + 1
			var 노드 := "%s%02d" % [k, 셈[k]]
			if k == "빛줄기":
				if float(g.get("주기", 0)) > 0.0 or bool(g.get("점멸", false)):
					continue
				_할일.append({"씬": 씬, "종류": k, "노드": 노드, "경우": "같은색", "g": g, "가시": 도안.get("가시", [])})
				_할일.append({"씬": 씬, "종류": k, "노드": 노드, "경우": "반대색", "g": g, "가시": 도안.get("가시", [])})
			else:
				_할일.append({"씬": 씬, "종류": k, "노드": 노드, "경우": "", "g": g})
	_다음()


func _기록(s: String) -> void:
	_줄.append(s)
	print(s)


func _다음() -> void:
	if _씬:
		_씬.queue_free()
		_씬 = null
	_i += 1
	if _i >= _할일.size():
		_기록("\n기믹 시험 %d 건 · 실패 %d" % [_할일.size(), _실패])
		var f := FileAccess.open("res://tools/_진단/기믹시험.txt", FileAccess.WRITE)
		f.store_string("\n".join(_줄))
		f.close()
		quit(0 if _실패 == 0 else 2)
		return
	_일 = _할일[_i]
	_씬 = (load(_일["씬"]) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_죽음 = false
	_씬.connect("사망함", func(): _죽음 = true)
	_f = 0
	_재기 = {}


func _판정(ok: bool, 메모: String) -> void:
	if not ok:
		_실패 += 1
	_기록("%s %s · %s %s · %s" % ["○" if ok else "×", String(_일["씬"]).get_file().get_basename(), _일["노드"], _일["경우"], 메모])
	_다음()


func _physics_process(_d: float) -> bool:
	if _씬 == null:
		return false
	_f += 1
	if _f < 30:
		return false
	var g: Dictionary = _일["g"]
	var 노드 := _씬.get_node("장애물").get_node_or_null(String(_일["노드"]))
	if 노드 == null:
		_판정(false, "노드 없음")
		return false
	if _f == 30:
		_씬.get_node("연결").process_mode = Node.PROCESS_MODE_DISABLED
	match String(_일["종류"]):
		"빛줄기":
			_빛(노드, g)
		"도약대":
			_도약(노드, g)
		"움직이는발판":
			_발판(노드, g)
	return false


func _빛(노드: Node, g: Dictionary) -> void:
	# [2026-10-05 2차] 비스듬한 창문 달빛도 있으므로 씬 노드 값(위치·각도·길이)으로 빛 끝(바닥에 닿는 점)을 구한다
	var 빛색 := int(노드.get("시작색"))
	if _f == 30:
		var 방향 := Vector2.RIGHT.rotated(deg_to_rad(float(노드.get("각도"))))
		var 끝 := (노드 as Node2D).global_position + 방향 * (float(노드.get("길이")) - 2.0)
		_p.set("자유색", 빛색 if _일["경우"] == "같은색" else (ColorDefs.WHITE if 빛색 == ColorDefs.BLACK else ColorDefs.BLACK))
		# 빛 아래가 유령판이면 플레이어가 자기 색으로 칠해 두고 선다
		for n in _씬.get_node("지형").get_children():
			if n.get_meta("design_kind", "") == "유령":
				n.call("_전체_즉시", 1 + int(_p.get("자유색")), true)
				n.call("_충돌레이어_갱신")
		_p.global_position = Vector2(끝.x, 끝.y - 1.0)
		_p.velocity = Vector2.ZERO
		_재기["시작"] = _p.global_position
		# 빛 끝이 가시 위(예: 08 무너진 마루의 그을음 — 구덩이 바닥까지 쏟아진다)면 가시에 죽으므로 색 판정 시험이 안 된다
		var 가시_위 := false
		for 가 in _일["가시"]:
			# 도안 "가시": [x, 바닥y, 폭] — 바닥y 칸 위에 폭 칸
			if absf(끝.y - float(가[1]) * 32.0) < 8.0 and 끝.x >= float(가[0]) * 32.0 and 끝.x <= (float(가[0]) + float(가[2])) * 32.0:
				가시_위 = true
		_재기["가시"] = 가시_위
	elif _f == 75:
		if _재기.get("가시", false):
			_기록("- %s · %s %s · 건너뜀(빛 끝이 가시 구덩이 — 색 판정 대신 경로 재생이 확인)" % [String(_일["씬"]).get_file().get_basename(), _일["노드"], _일["경우"]])
			_다음()
			return
		var 기대_죽음: bool = _일["경우"] == "반대색"
		_판정(_죽음 == 기대_죽음, "죽음=%s (기대 %s) @%s" % [_죽음, 기대_죽음, _재기["시작"]])


func _도약(노드: Node2D, g: Dictionary) -> void:
	if _f == 30:
		# 색 도약대("색": "흰" 등)는 그 색 몸일 때만 튄다 → 도약대 색으로 맞춰 떨어뜨린다
		if bool(노드.get("색_제한")):
			_p.set("자유색", int(노드.get("색")))
		_p.global_position = 노드.global_position + Vector2(0, -23.0 - 40.0)
		_p.velocity = Vector2.ZERO
		_재기 = {"최고": INF, "튐": false, "시작y": 노드.global_position.y - 23.0}
	elif _f > 30:
		if _p.velocity.y < -700.0:
			_재기["튐"] = true
		if _재기["튐"]:
			_재기["최고"] = minf(_재기["최고"], _p.global_position.y)
		if (_재기["튐"] and _p.velocity.y > 0.0) or _f > 200:
			var 오름px: float = _재기["시작y"] - _재기["최고"]
			var 기대 := float(g["오름"]) * 32.0
			_판정(_재기["튐"] and absf(오름px - 기대) <= 32.0 and not _죽음,
				"튐=%s · 오른 높이 %.0fpx (도안 %d칸 = %.0fpx) · 죽음=%s" % [_재기["튐"], 오름px, int(g["오름"]), 기대, _죽음])


func _발판(노드: Node2D, g: Dictionary) -> void:
	if _f == 30:
		_p.set("자유색", ColorDefs.BLACK)       # 안 칠한 발판 = 검정
		# 발판은 씬이 뜨자마자 움직이기 시작했으므로, 지금 위치가 아니라 **출발 자리**(_시작위치)에서 잰다
		var 출발: Vector2 = 노드.get("_시작위치")
		_재기 = {"원점": (노드.get_parent() as Node2D).to_global(출발)}
	if _f <= 32:
		# 발판 윗면(두께 28 → 위로 14px) 가운데에 세운다. 발판이 움직이기 전 몇 프레임 동안 다시 맞춘다
		_p.global_position = 노드.global_position + Vector2(0, -14.0 - 1.0)
		_p.velocity = Vector2.ZERO
		return
	var 끝프레임 := 33 + int(float(g["왕복"]) * 60.0)
	var 거리 := float(g["거리"]) * 32.0
	var 상하: bool = g["방향"] == "상하"
	var 상대 := _p.global_position - 노드.global_position
	if absf(상대.x) > float(g["폭"]) * 16.0 + 30.0 or absf(상대.y + 14.0) > 24.0:
		_판정(false, "발판에서 떨어짐 @%s · 발판 %s · 프레임 %d" % [_p.global_position.round(), 노드.global_position.round(), _f])
		return
	if _죽음:
		_판정(false, "죽음 @%s · 프레임 %d" % [_p.global_position.round(), _f])
		return
	var 이동 := (노드.global_position - _재기["원점"]) as Vector2
	_재기["최대이동"] = maxf(float(_재기.get("최대이동", 0.0)), absf(이동.y if 상하 else 이동.x))
	if _f >= 끝프레임:
		_판정(float(_재기["최대이동"]) >= 거리 * 0.95, "왕복 1회 동안 함께 이동 %.0fpx (도안 %.0fpx) · 안 죽음" % [_재기["최대이동"], 거리])
