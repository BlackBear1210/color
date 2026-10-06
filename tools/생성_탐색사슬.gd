extends SceneTree
## 방 → 수평 복도(방층.gd) → 방 시험 사슬. 기존 스테이지와 챕터 표는 수정하지 않는다.
## --씨앗=1,2 --설정=작은|표준 --미리보기 --다음=res://...tscn
## Godot 실행 허가를 받은 세션에서만 실행한다. 기본 출력은 탐색/사슬/ 아래다.
const 방_S = preload("res://tools/생성기/탐색방.gd")
const 검증_S = preload("res://tools/생성기/탐색검증.gd")
const 난수_S = preload("res://tools/생성기/난수.gd")
const 설정_S = preload("res://tools/생성기/설정.gd")
const 방층_S = preload("res://tools/생성기/방층.gd")
const 연결_S = preload("res://tools/생성기/탐색연결.gd")
const 윤곽_S = preload("res://tools/생성기/윤곽.gd")
const 조립_S = preload("res://tools/생성기/조립2.gd")
const 미리보기_S = preload("res://tools/생성기/미리보기.gd")
const 배경_S = preload("res://tools/생성기/배경슬롯.gd")
var 씨앗들: Array[int] = [1, 2]
var 표준 := false
var 미리보기만 := false
var 다음씬 := ""
var 폴더 := "res://scenes/집/생성/탐색/사슬/"

func _init() -> void:
	call_deferred("_실행")

func _실행() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--씨앗="):
			씨앗들.clear()
			for s in arg.trim_prefix("--씨앗=").split(","):
				if not s.is_valid_int():
					_실패("씨앗은 정수 두 개를 쉼표로 구분한다")
					return
				씨앗들.append(int(s))
		elif arg in ["--설정=작은", "--설정=표준"]:
			표준 = arg == "--설정=표준"
		elif arg == "--미리보기":
			미리보기만 = true
		elif arg.begins_with("--다음="):
			다음씬 = arg.trim_prefix("--다음=")
		elif arg.begins_with("--출력="):
			폴더 = arg.trim_prefix("--출력=").trim_suffix("/") + "/"
		else:
			_실패("지원하지 않는 옵션: " + arg)
			return
	if 씨앗들.size() != 2 or not 연결_S.출력허용(폴더):
		_실패("씨앗 두 개와 탐색 생성 폴더 안의 출력 경로가 필요하다")
		return
	if 다음씬 != "" and (not 다음씬.begins_with("res://") or not 다음씬.ends_with(".tscn") or not ResourceLoader.exists(다음씬)):
		_실패("다음 씬이 존재하지 않는다: " + 다음씬)
		return
	# 이후의 모든 생성은 이 검사에 종속된다. 실패 후 보고/씬을 만들지 않는다.
	if not 난수_S.자가검사():
		_실패("난수 자가검사 실패")
		return
	print("난수 자가검사 통과")
	var 앞 = _방준비(씨앗들[0], 0)
	if 앞.is_empty():
		return
	var 진행: int = 앞["출구방향"]
	var 뒤 = _방준비(씨앗들[1], -진행)
	if 뒤.is_empty():
		return
	var 복도 = _복도준비(진행)
	if 복도.is_empty():
		return
	var items = [앞, 복도, 뒤]
	var prefix := "사슬_%s_%d_%d" % ["표준" if 표준 else "작은", 씨앗들[0], 씨앗들[1]]
	for i in items.size():
		items[i]["경로"] = 폴더 + prefix + "_%d.tscn" % (i + 1)
	for i in items.size():
		var target: String = items[i + 1]["경로"] if i + 1 < items.size() else 다음씬
		연결_S.출구연결(items[i]["방"]["통로들"], target)
	var errors := 연결_S.사슬검사(items)
	if not errors.is_empty():
		_실패("; ".join(errors))
		return
	# 하나라도 실패하면 새 씬을 만들지 않도록 전체 기하를 먼저 준비한다.
	for item in items:
		item["방"] = 연결_S.개구부(item["방"])
		if item["방"].is_empty():
			_실패("문 개구부 검증 실패")
			return
		var outline := 윤곽_S.뽑기(item["방"])
		if outline.is_empty() or int(outline["잘린빈칸"]) != 0:
			_실패("윤곽 생성 실패")
			return
		if not 연결_S.통로여유(item["방"], outline):
			_실패("최종 윤곽이 문 개구부를 막는다")
			return
		item["윤곽"] = outline
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	if error != OK:
		_실패("출력 폴더 생성 실패: " + error_string(error))
		return
	var manifest = {"버전": "exploration_chain_v1", "씨앗": 씨앗들, "표준": 표준,
		"씬저장": not 미리보기만, "장면전환실측": "미실행", "구성": []}
	for item in items:
		if not _저장(item):
			_실패("산출물 저장 실패: " + item["경로"])
			return
		manifest["구성"].append({"씬": item["경로"], "종류": item["종류"],
			"사슬반전": item.get("사슬반전", false), "연결": _연결기록(item["방"]["통로들"])})
	var f := FileAccess.open(폴더 + prefix + "_연결.json", FileAccess.WRITE)
	if f == null:
		_실패("연결 기록 저장 실패")
		return
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("방 → 수평 복도 → 방 사슬 준비 완료: " + 폴더 + prefix + "_1.tscn")
	if 다음씬 == "":
		print("마지막 방은 시험 종점이다. 외부 연결은 --다음으로 명시한다.")
	quit(0)

func _실패(message: String) -> void:
	push_error(message)
	quit(1)

func _방준비(seed_value: int, 입구방향: int) -> Dictionary:
	var room = 방_S.new(seed_value, 표준)
	room.생성()
	var validator = 검증_S.new(room)
	var picked: Dictionary = validator.출구고르기()
	if picked.get("출구", {}).is_empty():
		_실패("출구 후보 없음")
		return {}
	# 수평 복도를 통과한 방향으로 다음 방에 들어오도록 배치 변환을 별도로 기록한다.
	# 씨앗의 기본 생성은 유지하며, 사슬 배치에만 추가 반전을 적용한다.
	var mirror: bool = 입구방향 != 0 and int(room.입구()["방향"]) != 입구방향
	if mirror:
		room._반전()
		validator = 검증_S.new(room)
	var report: Dictionary = validator.검사(picked["출구"])
	if not report["실패"].is_empty():
		_실패(str(report["실패"]))
		return {}
	var config = 설정_S.집_탐색방_표준() if 표준 else 설정_S.집_탐색방_작은()
	var data: Dictionary = room.사전()
	data["사슬반전"] = mirror
	return {"방": data, "설정": config, "종류": "탐색방", "사슬반전": mirror,
		"씨앗": seed_value, "출구방향": picked["출구"]["방향"], "보고": report}

func _복도준비(진행: int) -> Dictionary:
	var config = 설정_S.집_복도()
	# 연결 시험의 복도는 내부 약60칸, 높이8~10칸. 기존 집-2 설정/씬은 수정하지 않는다.
	config.폭칸 = 76
	config.높이칸 = 28
	config.외곽두께 = 6
	config.원점_y = 0.0
	config.스테이지_이름 = "탐색 사슬 · 연결 복도"
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗들[0]
	var data := 방층_S.파기(config, rng)
	if data.is_empty():
		_실패("수평 복도 생성 실패")
		return {}
	# 첫 연결 시험에서는 장식용 선반/추가 관문을 넣지 않는다. 사슬 동작과 별도로 검증할 대상이다.
	data["배치물"] = {"플랫폼": [], "위험물": [], "체크포인트": [], "사격": []}
	var bounds: Rect2i = data["방들"][0]["사각"]
	var y: int = data["방들"][0]["바닥y"]
	data["통로들"] = []
	for entrance in [true, false]:
		var d: int = -진행 if entrance else 진행
		var x: int = bounds.position.x if d < 0 else bounds.end.x
		data["통로들"].append({"이름": "입구통로" if entrance else "출구통로",
			"역할": "입구" if entrance else "출구", "방향": d,
			"위치": Vector2(x * 96, y * 96), "다음_씬": "", "다음_진입점": "입구통로"})
		data["시작칸" if entrance else "출구칸"] = Vector2i(x if d < 0 else x - 1, y - 1)
	# 평평한 바닥 전 구간을 검사해 빈 공간만 이어지고 지지면이 끊긴 복도는 거부한다.
	var cells: PackedByteArray = data["칸"]
	for x in range(bounds.position.x, bounds.end.x):
		if cells[y * int(data["폭칸"]) + x] != 1 or cells[(y - 1) * int(data["폭칸"]) + x] != 0 or cells[(y - 2) * int(data["폭칸"]) + x] != 0:
			_실패("복도 지지면/머리 여유 불일치")
			return {}
	return {"방": data, "설정": config, "종류": "수평복도", "씨앗": 씨앗들[0]}

func _저장(item: Dictionary) -> bool:
	var data: Dictionary = item["방"]
	var placement: Dictionary = data["배치물"].duplicate(true)
	placement["씨앗"] = item["씨앗"]
	placement["통로들"] = data["통로들"]
	for k in ["껍데기", "섬들", "테두리원본"]:
		placement[k] = item["윤곽"][k]
	var path: String = item["경로"]
	if not 미리보기_S.저장(data, ProjectSettings.globalize_path(path.get_basename() + ".png"), placement, 10):
		return false
	if 미리보기만:
		return true
	var builder = 조립_S.new()
	var root: Node2D = builder.굽기(data, item["윤곽"], placement, item["설정"], path.get_file().get_basename())
	root.set_meta("gen_algo", "exploration_chain_v1")
	root.set_meta("chain_mirror", item.get("사슬반전", false))
	root.set_meta("chain_ports", data["통로들"])
	if item["종류"] == "탐색방":
		root.set_meta("background_slots", 배경_S.슬롯들(data))
	var ok: bool = builder.저장(root, path)
	root.free()
	return ok

func _연결기록(ports: Array) -> Array:
	var out = []
	for t in ports:
		var p: Vector2 = t["위치"]
		out.append({"이름": t["이름"], "역할": t["역할"], "방향": t["방향"],
			"위치": [p.x, p.y], "다음_씬": t["다음_씬"], "다음_진입점": t["다음_진입점"]})
	return out
