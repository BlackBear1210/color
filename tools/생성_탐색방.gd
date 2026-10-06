extends SceneTree
## ============================================================================
## [2026-09-28 신규] 탐색방 생성기 — 진입점
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_탐색방.gd -- [옵션]
##
##   --설정=작은|표준    방 크기(작은 60×24 칸 · 표준 72×36 칸 · 내부 기준)
##   --씨앗=1-10 또는 1,3,7   같은 씨앗 = 같은 맵
##   --사슬              만든 방들을 **문으로 이어** 준다(1 → 2 → 3 …)
##   --다음=res://...    출구 통로가 넘겨줄 다음 스테이지(예: 집-2 복도계단)
##   --미리보기          PNG 와 검사 결과만 내고 씬은 굽지 않는다
##   --출력=res://...    저장 폴더(기본 res://scenes/집/생성/탐색/)
##
## ▣ ★기존 씬을 덮어쓰는 옵션은 **일부러 만들지 않았다**
##   `--적용` 이 없다. 새 경로에만 굽는다(작업지시 §8-1 "생성 결과는 새 경로에 출력한다").
##   집-1 은 a4e4e1a 복원본 그대로 두고, 충분히 검증된 뒤에 사람이 옮긴다.
##
## ▣ ★`배치.gd 통행_보정` 을 부르지 않는다
##   그 단계는 못 닿는 칸을 보면 디딤 발판을 놓는데, 그게 **관문을 우회하는 다리**가 될 수 있다.
##   탐색방은 파기 단계에서 통행을 보장하고, 그 사실을 `탐색검증.gd` 가 대조 검사로 증명한다.
##
## ▣ 제일 먼저 난수 자가검사를 돌린다
##   파이썬 프로토타입(씨앗 1~10 검증본)과 **같은 수열**이어야 그 검증이 여기에도 유효하다.
## ============================================================================

const 설정_S := preload("res://tools/생성기/설정.gd")
const 난수_S := preload("res://tools/생성기/난수.gd")
const 탐색방_S := preload("res://tools/생성기/탐색방.gd")
const 탐색검증_S := preload("res://tools/생성기/탐색검증.gd")
const 배경슬롯_S := preload("res://tools/생성기/배경슬롯.gd")
const 윤곽_S := preload("res://tools/생성기/윤곽.gd")
const 조립2_S := preload("res://tools/생성기/조립2.gd")
const 미리보기_S := preload("res://tools/생성기/미리보기.gd")
const 연결_S := preload("res://tools/생성기/탐색연결.gd")

var _설정이름 := "작은"
var _씨앗들: Array[int] = []
var _미리보기만 := false
var _사슬 := false
var _출력폴더 := "res://scenes/집/생성/탐색/"
## 출구 통로가 넘겨줄 다음 스테이지. 비우면 안 꽂는다(사슬로 이을 때는 자동으로 채운다).
## ⚠ 스테이지 순서의 유일한 출처는 `scripts/스마트월드/챕터.gd` 표다. 여기 값은 **시험용**이다.
var _다음씬 := ""


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--설정="):
			_설정이름 = a.substr("--설정=".length())
		elif a.begins_with("--씨앗="):
			_씨앗들 = _씨앗_읽기(a.substr("--씨앗=".length()))
		elif a.begins_with("--출력="):
			_출력폴더 = a.substr("--출력=".length())
		elif a == "--미리보기":
			_미리보기만 = true
		elif a.begins_with("--다음="):
			_다음씬 = a.substr("--다음=".length())
		elif a == "--사슬":
			_사슬 = true
		else:
			push_error("지원하지 않는 옵션: " + a)
			quit(1)
			return
	# --적용이 없어도 임의 --출력으로 원본 폴더에 쓸 수 있었으므로 정규화까지 검사한다.
	if not 연결_S.출력허용(_출력폴더):
		push_error("출력은 res://scenes/집/생성/탐색/ 아래만 허용한다")
		quit(1)
		return
	_출력폴더 = _출력폴더.trim_suffix("/") + "/"
	if _다음씬 != "" and (not _다음씬.begins_with("res://") or not _다음씬.ends_with(".tscn") or not ResourceLoader.exists(_다음씬)):
		push_error("존재하는 다음 씬 경로가 필요하다: " + _다음씬)
		quit(1)
		return
	if _씨앗들.is_empty():
		_씨앗들 = [1]
	if _설정이름 != "작은" and _설정이름 != "표준":
		print("✗ 모르는 설정: %s  (쓸 수 있는 것: 작은 · 표준)" % _설정이름)
		quit(1)
		return

	if not 난수_S.자가검사():
		print("✗ 난수 자가검사 실패 — 포팅이 깨졌다. 여기서 나온 맵은 믿지 말 것.")
		quit(1)
		return
	print("✔ 난수 자가검사 통과(파이썬 프로토타입과 같은 수열)")

	var 설정: RefCounted = 설정_S.집_탐색방_표준() if _설정이름 == "표준" \
		else 설정_S.집_탐색방_작은()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_출력폴더))

	var 통과 := 0
	var 출구분포 := {}
	for n in _씨앗들.size():
		var 다음경로 := _다음씬
		if _사슬 and n + 1 < _씨앗들.size():
			다음경로 = "%s%s.tscn" % [_출력폴더, _씬이름(_씨앗들[n + 1])]
		var r := _한판(설정, _씨앗들[n], 다음경로)
		if r.is_empty():
			continue
		if bool(r["통과"]):
			통과 += 1
		var 키 := String(r["출구"])
		출구분포[키] = int(출구분포.get(키, 0)) + 1

	print("")
	print("════════ 합계 : %d / %d 씨앗 통과 ════════" % [통과, _씨앗들.size()])
	print("  출구 분포 : %s" % str(출구분포))
	if _사슬:
		print("  ⚠ 사슬로 이은 것은 **생성된 방들끼리**다. 실제 스테이지 순서는")
		print("    `scripts/스마트월드/챕터.gd` 표가 유일한 출처다 — 거기에 넣는 것은 사람이 한다.")
	# 저장 실패도 배치 작업 실패다. 검사 통과 숫자만 보고 성공으로 종료하지 않는다.
	quit(0 if 통과 == _씨앗들.size() else 1)


func _씬이름(씨앗: int) -> String:
	return "탐색방_%s_s%d" % [_설정이름, 씨앗]


func _씨앗_읽기(글: String) -> Array[int]:
	var out: Array[int] = []
	for 조각 in 글.split(","):
		var 조각2 := 조각.strip_edges()
		if 조각2.find("-") > 0:
			var 양 := 조각2.split("-")
			for v in range(int(양[0]), int(양[1]) + 1):
				out.append(v)
		elif 조각2 != "":
			out.append(int(조각2))
	return out


func _한판(설정: RefCounted, 씨앗: int, 다음경로: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var 방객체 = 탐색방_S.new(씨앗, _설정이름 == "표준")
	방객체.생성()

	print("")
	print("════════ 탐색방 — 씨앗 %d ════════" % 씨앗)
	print("  격자     : %d × %d 칸 (칸 96 px) = %d × %d px"
		% [방객체.W, 방객체.H, 방객체.W * 96, 방객체.H * 96])
	print("  구역     : %d 개 · 선반벽 %s · 좌우뒤집기 %s"
		% [(방객체.구역들 as Array).size(), 방객체.선반벽, str(방객체.뒤집기)])

	# ── 출구 선택 ───────────────────────────────────────────────────────────
	var 검증 = 탐색검증_S.new(방객체)
	var 고름: Dictionary = 검증.출구고르기()
	var 출구: Dictionary = 고름.get("출구", {})
	if 출구.is_empty():
		print("  ✗ %s" % 고름.get("실패", "출구 선택 실패"))
		for c in (고름.get("후보", []) as Array):
			print("      - %s (구역 %s · e%d · 비용 %s) — %s"
				% [c["id"], c["구역"], int(c["높이단"]), str(c["비용"]), c["제외"]])
		return {}
	print("  출구     : %s (구역 %s · e%d · %s쪽 벽 · 비용 %s)"
		% [출구["id"], 출구["구역"], int(출구["높이단"]),
			"오른" if int(출구["방향"]) > 0 else "왼", str(고름.get("비용", -1))])
	for c2 in (고름.get("후보", []) as Array):
		if String(c2["제외"]) != "":
			print("      · 탈락 %s — %s" % [c2["id"], c2["제외"]])

	# ── 검증(행동 제거 대조 검사) ──────────────────────────────────────────
	var v: Dictionary = 검증.검사(출구)
	for it in (v["항목"] as Array):
		print("    [%s] %s%s" % ["v" if bool(it["통과"]) else "X", it["이름"],
			("" if String(it["설명"]) == "" else " — " + String(it["설명"]))])
	var 통과 := (v["실패"] as Array).is_empty()
	print("  판정     : %s (%d ms)" % ["통과" if 통과 else "✗ 실패", Time.get_ticks_msec() - t0])
	if not 통과:
		return {"통과": false, "출구": String(출구["id"])}

	# ── 파이프라인 사전으로 옮긴다 ─────────────────────────────────────────
	# 통로 노드만 붙이면 외벽에 막힌다. 윤곽을 뽑기 전에 선택된 두 문을 판다.
	var 방: Dictionary = 연결_S.개구부(방객체.사전())
	if 방.is_empty():
		return {"통과": false, "출구": String(출구["id"])}
	var 윤 := 윤곽_S.뽑기(방)
	if 윤.is_empty():
		print("  ✗ 윤곽을 못 뽑았다")
		return {"통과": false, "출구": String(출구["id"])}
	if not 연결_S.통로여유(방, 윤):
		return {"통과": false, "출구": String(출구["id"])}
	print("  껍데기   : 점 %d 개 · 섬 %d 개 (단순화 오차 %.0f · 잘린 빈칸 %d)"
		% [(윤["껍데기"] as PackedVector2Array).size(), (윤["섬들"] as Array).size(),
			윤["단순화오차"], 윤["잘린빈칸"]])
	# ★윤곽 진단 — 이웃한 두 점이 한 칸보다 훨씬 멀면 **추적이 끊긴 것**이다
	#   (미리보기에서 빈 공간을 가로지르는 선으로 보인다).
	for 이름 in ["테두리원본", "껍데기"]:
		var pts: PackedVector2Array = 윤[이름]
		var 최대 := 0.0
		var 긴변 := 0
		for i in pts.size():
			var d := pts[i].distance_to(pts[(i + 1) % pts.size()])
			최대 = maxf(최대, d)
			if d > 96.0 * 3.0:
				긴변 += 1
		print("    %-8s 점 %4d · 최대 변 %.0f px · 3칸 넘는 변 %d 개" % [이름, pts.size(), 최대, 긴변])

	var 통로들: Array = 방["통로들"]
	if 다음경로 != "":
		for t in 통로들:
			if String(t["역할"]) == "출구":
				t["다음_씬"] = 다음경로
	var 배치 := {
		"플랫폼": (방["배치물"] as Dictionary)["플랫폼"],
		"위험물": (방["배치물"] as Dictionary)["위험물"],
		"체크포인트": (방["배치물"] as Dictionary)["체크포인트"],
		"사격": (방["배치물"] as Dictionary)["사격"],
		"씨앗": 씨앗, "통로들": 통로들,
	}
	for k in ["껍데기", "섬들", "테두리원본"]:
		배치[k] = 윤[k]

	# ── 배경 슬롯 · 커버리지 ───────────────────────────────────────────────
	var 슬롯 := 배경슬롯_S.슬롯들(방)
	var 커버 := 배경슬롯_S.커버리지(방)
	var 전경: Dictionary = (커버["층"] as Dictionary)["L4_전경"]
	print("  배경     : 슬롯 %d 개 · 커버리지(전경 1.25) %.0f × %.0f px"
		% [슬롯.size(), 전경["필요폭"], 전경["필요높이"]])

	# ── 미리보기 ───────────────────────────────────────────────────────────
	var png := "%s미리보기_%s_s%d.png" % [_출력폴더, _설정이름, 씨앗]
	if 미리보기_S.저장(방, ProjectSettings.globalize_path(png), 배치, 10):
		print("  미리보기 : %s" % png)
	else:
		return {"통과": false, "출구": String(출구["id"])}
	if _미리보기만:
		return {"통과": 통과, "출구": String(출구["id"])}

	# ── 굽기 ───────────────────────────────────────────────────────────────
	var 씬이름 := _씬이름(씨앗)
	var 조립 = 조립2_S.new()
	var 루트 := 조립.굽기(방, 윤, 배치, 설정, 씬이름)
	var 경로 := "%s%s.tscn" % [_출력폴더, 씬이름]
	if 조립.저장(루트, 경로):
		print("  저장     : %s%s" % [경로, ("  → 다음 씬 " + 다음경로.get_file()) if 다음경로 != "" else ""])
	else:
		print("  ✗ 저장 실패(자기검증에서 걸렸다) — %s" % 경로)
		통과 = false
	# SceneTree에 붙이지 않은 신규 루트도 명시적으로 해제해 다중 시드 실행에 누적되지 않게 한다.
	루트.free()
	return {"통과": 통과, "출구": String(출구["id"])}
