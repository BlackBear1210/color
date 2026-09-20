extends SceneTree
## ============================================================================
## [2026-09-20 신규] 지형 형태 검사 — "레벨검사는 통과하는데 지형이 삼각형" 을 잡는다
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/검사_지형형태.gd -- <씬경로> [<씬경로> ...] [옵션]
##
##   --삼각형최대=0.05    삼각형 비율 상한(기본 5 %). 넘으면 실패. 설계 원칙: 삼각형은 특수 상황에서 소량만
##   --표                 지형마다 분류를 한 줄씩 찍는다
##
## ▣ 언제 돌리나
##   · **에디터에서 씬을 저장한 직후.** 2026-09-20 에 1-1 이 에디터 저장 뒤 22/27 개가
##     삼각형으로 무너져 있었는데 아무도 몰랐다. 레벨검사는 통과했다(빗변 위도 걷는다).
##   · 생성기로 굽거나 `--적용` 한 직후 (조립.gd 도 같은 검사를 자동으로 한다)
##
## ▣ 종료 코드: 문제 없으면 0, 퇴화·붕괴가 있거나 삼각형 비율 초과면 1
## ============================================================================

const 형태_S := preload("res://tools/생성기/형태.gd")


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 씬들: Array[String] = []
	var 삼각형_상한 := 0.05
	var 표 := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--삼각형최대="):
			삼각형_상한 = float(a.substr("--삼각형최대=".length()))
		elif a == "--표":
			표 = true
		elif not a.begins_with("--"):
			씬들.append(a)
	if 씬들.is_empty():
		print("사용법: -- <씬경로> [--삼각형최대=0.05] [--표]")
		quit(2)
		return

	var 실패 := false
	for 경로 in 씬들:
		# 캐시를 무시하고 디스크에서 읽는다 — 방금 저장한 파일을 봐야 하므로
		var ps := ResourceLoader.load(경로, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if ps == null:
			print("✖ 씬을 못 읽었다: %s" % 경로)
			실패 = true
			continue
		var 루트 := ps.instantiate()
		var r := 형태_S.검사(루트)
		var 총: int = r["개수"]
		var 삼각 := (r["삼각형"] as Array).size()
		var 비율 := float(삼각) / maxf(float(총), 1.0)

		print("")
		print("════ %s ════" % 경로.get_file())
		var 줄: Array[String] = []
		for k in r["분류별"]:
			줄.append("%s %d (%.0f%%)" % [k, r["분류별"][k], 100.0 * float(r["분류별"][k]) / maxf(float(총), 1.0)])
		print("  SS2D 지형 %d 개 · %s" % [총, " / ".join(줄)])
		if 표:
			for row in r["표"]:
				print("    %-28s %s (유효점 %d)" % [row[0], row[1], row[2]])
		for m in r["문제"]:
			print("  ✖ %s" % m)
		if 비율 > 삼각형_상한:
			print("  ✖ 삼각형 비율 %.0f%% > 상한 %.0f%% — %s" % [비율 * 100.0, 삼각형_상한 * 100.0,
				", ".join((r["삼각형"] as Array).slice(0, 6))])
		if (r["문제"] as Array).is_empty() and 비율 <= 삼각형_상한:
			print("  ✔ 형태 정상")
		else:
			실패 = true
		루트.free()
	quit(1 if 실패 else 0)
