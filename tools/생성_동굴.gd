extends SceneTree
## ============================================================================
## [2026-09-21 신규] v2 동굴 스테이지 생성기 — 진입점
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_동굴.gd -- [옵션]
##
##   --설정=집             챕터 설정 (지금은 집만)
##   --씨앗=1,2,3          같은 씨앗 = 같은 맵
##   --미리보기            PNG 만 찍는다 (씨앗 고르기용 · 씨앗 하나 0.2 초)
##   --출력=res://...tscn  저장 경로
##   --적용                ★`scenes/집/스테이지_1_2층방.tscn` 을 **통째로 새로 만든다**
##
## ▣ v1(`생성_스테이지.gd`)과 무엇이 다른가
##   v1 = 발판 조각을 이어 붙인다 → 한 줄기 길 · 도형을 붙여 놓은 모양
##   v2 = 꽉 찬 바위를 **파낸다** → 껍데기가 하나로 이어진 캡슐 · 고리가 있는 탐험형 구조
##   v1 은 지우지 않았다(하수도 쪽에서 아직 참고한다). 집 1-1 은 이제 v2 를 쓴다.
## ============================================================================

const 설정_S := preload("res://tools/생성기/설정.gd")
const 동굴_S := preload("res://tools/생성기/동굴.gd")
const 동굴층_S := preload("res://tools/생성기/동굴층.gd")
## ★[2026-09-23] 「복도와 계단」용 파기. 같은 뒷단(관문·윤곽·배치·조립)을 쓴다.
const 계단층_S := preload("res://tools/생성기/계단층.gd")
const 미리보기_S := preload("res://tools/생성기/미리보기.gd")
const 윤곽_S := preload("res://tools/생성기/윤곽.gd")
const 배치_S := preload("res://tools/생성기/배치.gd")
const 조립2_S := preload("res://tools/생성기/조립2.gd")
const 관문_S := preload("res://tools/생성기/관문.gd")

var _설정이름 := "집"
var _씨앗들: Array[int] = []
var _미리보기만 := false
var _출력 := ""
var _적용 := false
var _대상 := "res://scenes/집/스테이지_1_2층방.tscn"
## ★[2026-09-23] 설정마다 `--적용` 이 고칠 씬. `--대상=` 을 직접 주면 그쪽이 이긴다.
const _기본_대상 := {
	"집": "res://scenes/집/스테이지_1_2층방.tscn",
	"복도계단": "res://scenes/집/스테이지_2_복도계단.tscn",
}
var _대상_지정됨 := false


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--설정="):
			_설정이름 = a.substr("--설정=".length())
		elif a.begins_with("--씨앗="):
			for s in a.substr("--씨앗=".length()).split(","):
				_씨앗들.append(int(s))
		elif a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length())
		elif a.begins_with("--대상="):
			_대상 = a.substr("--대상=".length())
			_대상_지정됨 = true
		elif a == "--미리보기":
			_미리보기만 = true
		elif a == "--적용":
			_적용 = true
	if _씨앗들.is_empty():
		_씨앗들 = [1]

	# ★[2026-09-23] 설정 이름이 **어떤 알고리즘으로 팔지**까지 고른다.
	#   집       → `동굴층.gd` (평평한 띠가 여러 겹인 동굴)
	#   복도계단 → `계단층.gd` (뱀처럼 꺾이며 내려가는 한 줄기 계단)
	var 설정: RefCounted = null
	match _설정이름:
		"집": 설정 = 설정_S.집_동굴()
		"복도계단": 설정 = 설정_S.집_복도계단()
	if 설정 == null:
		print("✗ 모르는 설정: %s  (쓸 수 있는 것: 집 · 복도계단)" % _설정이름)
		quit(1)
		return
	# ★`--대상` 을 안 준 채 `--적용` 하면 **설정에 맞는 씬**을 고친다.
	#   기본값이 2층 방이라, 이게 없으면 복도계단을 만들었는데 2층 방을 덮어쓴다.
	if not _대상_지정됨:
		_대상 = _기본_대상.get(_설정이름, _대상)

	for 씨앗 in _씨앗들:
		_한판(설정, 씨앗)
	quit(0)


func _한판(설정: RefCounted, 씨앗: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗
	var t0 := Time.get_ticks_msec()
	# ★[2026-09-21] 층 기반 파기로 교체. 이유는 `동굴층.gd` 머리 주석 참고(통행을 보장한다).
	# ★[2026-09-23] 「복도계단」은 같은 자리에서 `계단층.gd` 로 갈아 끼운다.
	#   판 결과의 **모양(Dictionary 키)이 같아서** 뒤 단계는 하나도 안 고쳐도 된다.
	var 동굴 := 계단층_S.파기(설정, rng) if _설정이름 == "복도계단" \
		else 동굴층_S.파기(설정, rng)
	if 동굴.is_empty():
		print("✗ 씨앗 %d — 방을 못 놓았다(설정을 보라)" % 씨앗)
		return
	var 파기_ms := Time.get_ticks_msec() - t0

	# 통계 — 빈칸 비율이 너무 낮으면 답답하고, 너무 높으면 큰 방 하나가 된다
	var 빈 := 0
	for i in (동굴["칸"] as PackedByteArray).size():
		if (동굴["칸"] as PackedByteArray)[i] == 동굴_S.빈칸:
			빈 += 1
	var 전체: int = int(동굴["폭칸"]) * int(동굴["높이칸"])

	print("")
	print("════════ 동굴 — 씨앗 %d ════════" % 씨앗)
	print("  격자     : %d × %d 칸 (칸 %.0f px) = %.0f × %.0f px"
		% [동굴["폭칸"], 동굴["높이칸"], 동굴["칸크기"],
			int(동굴["폭칸"]) * float(동굴["칸크기"]), int(동굴["높이칸"]) * float(동굴["칸크기"])])
	print("  방       : %d 개 · 통로 %d 개" % [동굴["방들"].size(), 동굴["통로들"].size()])
	print("  빈 공간  : %.0f %% (%d / %d 칸)" % [float(빈) / float(전체) * 100.0, 빈, 전체])
	print("  층       : %d 개 · 층연결 %d 개" % [동굴["층들"].size(), 동굴["통로들"].size()])
	print("  시작 %s → 출구 %s · 파기 %d ms" % [str(동굴["시작칸"]), str(동굴["출구칸"]), 파기_ms])

	# ★관문 — **파기 뒤, 윤곽 앞**. 구덩이를 파므로 껍데기 폴리곤에 반영돼야 한다.
	#   이 단계가 "걸어 다닐 수 있는 동굴" 을 "게임" 으로 바꾼다(도형님 지적 2026-09-21).
	var 관문 := 관문_S.세우기(동굴, 설정, rng)
	var 관문종류 := {}
	for g in 관문["관문들"]:
		관문종류[g["종류"]] = int(관문종류.get(g["종류"], 0)) + 1
	print("  관문     : %d 개 %s   (J 도약 · C 색바닥 · G 유령다리)"
		% [관문["관문들"].size(), str(관문종류)])

	# 윤곽 — 껍데기 한 장 + 바위 섬들
	var t1 := Time.get_ticks_msec()
	var 윤 := 윤곽_S.뽑기(동굴)
	var 윤곽_ms := Time.get_ticks_msec() - t1
	if 윤.is_empty():
		print("  ✗ 윤곽을 못 뽑았다")
		return
	print("  껍데기   : 점 %d 개 · 섬 %d 개 · %d ms (단순화 오차 %.0f · 잘린 빈칸 %d)"
		% [(윤["껍데기"] as PackedVector2Array).size(), (윤["섬들"] as Array).size(), 윤곽_ms, 윤["단순화오차"], 윤["잘린빈칸"]])
	# ★윤곽 진단 — 이웃한 두 점이 한 칸보다 훨씬 멀면 추적이 끊긴 것이다.
	#   (미리보기에서 빈 공간을 가로지르는 선으로 보인다)
	for 이름 in ["테두리원본", "동굴테두리"]:
		var pts: PackedVector2Array = 윤[이름]
		var 최대 := 0.0
		var 긴변 := 0
		for i in pts.size():
			var d := pts[i].distance_to(pts[(i + 1) % pts.size()])
			최대 = maxf(최대, d)
			if d > float(동굴["칸크기"]) * 3.0:
				긴변 += 1
		print("    %-8s 점 %4d · 최대 변 %.0f px · 3칸 넘는 변 %d 개"
			% [이름, pts.size(), 최대, 긴변])

	# 배치 — 동굴 안에 발판·사다리·기믹
	# ★[2026-09-23] **이미 놓인 발판 목록을 넘긴다.** 관문 슬래브와 징검다리는 이 단계보다
	#   먼저 놓이는데, 안 넘기면 그 위에 방 발판이 겹쳐 앉는다(진단_플랫폼겹침 FAIL 실측).
	var 기존발판: Array = []
	for p in 관문["플랫폼"]:
		기존발판.append(p["사각"])
	if 동굴.has("배치물"):
		for p in (동굴["배치물"] as Dictionary)["플랫폼"]:
			기존발판.append(p["사각"])
	var 배치 := 배치_S.채우기(동굴, 설정, rng, 기존발판)
	var 유령수 := 0
	for p in 배치["플랫폼"]:
		if String(p["종류"]) == "유령":
			유령수 += 1
	print("  배치     : 발판 %d(유령 %d) · 위험물 %d · 체크포인트 %d"
		% [배치["플랫폼"].size(), 유령수, 배치["위험물"].size(), 배치["체크포인트"].size()])

	# 관문 배치물을 배치 결과에 합친다(발판·위험물·체크포인트·사격)
	for k in ["플랫폼", "위험물", "체크포인트", "사격"]:
		배치[k].append_array(관문[k])
	# ★[2026-09-23] 파기 단계가 직접 만든 것도 합친다(복도계단의 징검다리 구덩이).
	#   격자를 파면서 같이 만들어야 하는 것이라 `배치.gd` 가 아니라 파기가 들고 온다.
	if 동굴.has("배치물"):
		for k in ["플랫폼", "위험물", "체크포인트"]:
			배치[k].append_array((동굴["배치물"] as Dictionary)[k])

	# ★통행 보정 — 파낸 공간이 실제로 **걸어 다닐 수 있는지** 격자에서 확인하고 디딤을 놓는다.
	#   이게 없으면 2 칸 단차 때문에 바닥이 조각나 `레벨검사` 가 "도달 0" 을 낸다(실측).
	var 보정 := 배치_S.통행_보정(동굴, 배치, rng)
	print("  통행     : 닿는 칸 %d · 못 닿는 칸 %d · 디딤 발판 %d 개 추가 (발판 합계 %d)"
		% [보정["닿는칸"], 보정["못닿는칸"], 보정["추가발판"], 배치["플랫폼"].size()])
	# ★발판을 뺀 **동굴 자체**의 통행성 — 이걸 따로 봐야 "지형이 문제인가 배치가 문제인가" 가 갈린다
	var 동굴만 := 배치_S.연결_진단(동굴, {"플랫폼": []})
	print("  동굴자체 : 설 수 있는 칸 %d · 덩어리 %d 개 · 최대 %d · 시작 덩어리 %d 칸"
		% [동굴만["설칸수"], 동굴만["덩어리수"], 동굴만["최대크기"], 동굴만["시작덩어리_크기"]])
	var 진단 := 배치_S.연결_진단(동굴, 배치)
	print("  연결     : 설 수 있는 칸 %d · 덩어리 %d 개 · 최대 %d · 시작은 %d 순위 덩어리(%d 칸)"
		% [진단["설칸수"], 진단["덩어리수"], 진단["최대크기"], 진단["시작덩어리_순위"], 진단["시작덩어리_크기"]])
	for k in ["껍데기", "섬들", "테두리원본"]:
		배치[k] = 윤[k]

	if OS.get_cmdline_user_args().has("--진단"):
		for L in 배치_S.진단_그리기(동굴, 배치, 동굴["시작칸"]):
			print(L)
	# ★[2026-09-23] `--진단칸=x,y` — 미리보기 PNG 에서 이상해 보이는 자리를 **칸 좌표로** 들여다본다.
	#   PNG 픽셀 ÷ 배율(10) = 칸 좌표다. `--진단`(시작 주변)만으로는 맵 한가운데를 못 본다.
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--진단칸="):
			continue
		var xy := a.substr("--진단칸=".length()).split(",")
		if xy.size() < 2:
			continue
		print("── 칸 (%s, %s) 주변 ──" % [xy[0], xy[1]])
		for L in 배치_S.진단_그리기(동굴, 배치, Vector2i(int(xy[0]), int(xy[1])), 60, 28):
			print(L)
	if OS.get_cmdline_user_args().has("--진단계단") and not 동굴["통로들"].is_empty():
		print("── 계단 주변 ──")
		for L in 배치_S.진단_그리기(동굴, 배치, 동굴["통로들"][0]["꺾임"], 56, 26):
			print(L)
	var png := "res://scenes/집/생성/미리보기_%s_s%d.png" % [_설정이름, 씨앗]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/집/생성/"))
	if 미리보기_S.저장(동굴, ProjectSettings.globalize_path(png), 배치, 10):
		print("  미리보기 : %s" % png)
	if 미리보기_S.통행_덧칠(ProjectSettings.globalize_path(png), 동굴, 보정, 10):
		print("  통행그림 : 초록=닿는 자리 · 빨강=못 닿는 자리")
	if _미리보기만:
		return

	# ── 굽기 ────────────────────────────────────────────────────────────────
	배치["씨앗"] = 씨앗
	var 조립 = 조립2_S.new()
	var t2 := Time.get_ticks_msec()
	# 씬 루트 이름은 **적용 대상 파일 이름과 같게** 둔다 — 다른 작업자가 씬 트리에서
	# "이게 어느 스테이지지" 를 파일명으로 찾기 때문이다.
	var 씬이름 := _대상.get_file().get_basename()
	var 루트 := 조립.굽기(동굴, 윤, 배치, 설정, 씬이름)
	var 경로 := _출력
	if 경로 == "":
		경로 = _대상 if _적용 else ("res://scenes/집/생성/%s_s%d.tscn" % [씬이름, 씨앗])
	# ★덮어쓰기 전에 백업 — 되돌릴 수 없는 작업이다(CLAUDE.md §8 · 남의 작업이 사라진 적 있다)
	if _적용 and FileAccess.file_exists(_대상):
		var 절대 := ProjectSettings.globalize_path(_대상)
		DirAccess.copy_absolute(절대, 절대.get_basename() + ".bak.tscn")
		print("  백업     : %s" % (_대상.get_basename() + ".bak.tscn"))
	if 조립.저장(루트, 경로):
		print("  저장     : %s  (%d ms)" % [경로, Time.get_ticks_msec() - t2])
	else:
		print("  ✗ 저장 실패(자기검증에서 걸렸다) — %s" % 경로)
