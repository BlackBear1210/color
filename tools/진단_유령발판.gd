extends SceneTree
## ============================================================================
## [2026-09-06 STEP 8 신규 · STEP 10 일반화] 흑백·유령 발판 검사
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/진단_유령발판.gd -- <씬경로>
##       (인자가 없으면 STAGE 1)
##
## ▣ 무엇을 보나 — 레벨검사도 메시검사도 이걸 못 본다
##   ① 유령 발판 : 칠하기 전 `밟을_수_있나 = false` · layer 8
##                 칠한 뒤   `"painted"` · `밟을_수_있나 = true` · layer 1 · 실제 착지
##   ② 흑백 지형 : 그림(시작상태)과 **판정색**이 같은가.
##                 `색규칙.위험한가()` 로 검정/흰색 플레이어 각각을 물어본다.
##                 ★여기가 어긋나면 "보이는 색"과 "죽는 색"이 다른 거짓말이 된다.
##   ③ 탄약 예산 : 유령을 전부 칠하는 데 몇 발이 드는지 · 탄창(최대_탄약)에 드는지
##
## ⚠ 확인용이다. 아무것도 안 고친다.
## ============================================================================

const 기본씬 := "res://scenes/집/스테이지_1_2층방.tscn"

var _루트: Node = null
var _p: CharacterBody2D = null


func _init() -> void:
	Engine.max_fps = 0
	call_deferred("_실행")


func _실행() -> void:
	var args := OS.get_cmdline_user_args()
	var 씬경로: String = args[0] if args.size() > 0 else 기본씬
	_루트 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_루트)
	for i in 6:
		await physics_frame
	_p = _루트.get_node_or_null("Player")
	var 지 := _루트.get_node_or_null("지형")
	if 지 == null:
		print("  ✗ '지형' 노드가 없다"); quit(1); return

	print("\n════════ 흑백 · 유령 발판 검사 — %s ════════" % 씬경로.get_file())

	var 유령들: Array[Node2D] = []
	var 흰것: Array[Node2D] = []
	var 검은것: Array[Node2D] = []
	print("  %-30s %-6s %-5s %-8s %-6s %s"
		% ["이름", "칠가능", "유령", "시작상태", "필요", "밟을수있나"])
	for c in 지.get_children():
		var t := c as Node2D
		if t == null or not t.has_method("밟을_수_있나"):
			continue
		var 칠: bool = t.get("칠하기_허용")
		var 유령: bool = t.get("무색일때_통과")
		var 시작: int = t.get("시작상태")     # 0 무색 · 1 검정 · 2 흰색 · 3 회색
		if not 칠:
			continue                          # 구조물은 색 규칙 밖 — 볼 필요 없다
		var 이름표: String = ["무색", "검정", "흰색", "회색"][시작]
		print("  %-30s %-6s %-5s %-8s %-6d %s"
			% [t.name, 칠, 유령, 이름표, int(t.call("필요횟수")), t.call("밟을_수_있나")])
		if 유령:
			유령들.append(t)
		elif 시작 == 2:
			흰것.append(t)
		else:
			검은것.append(t)

	# ── ② 흑백 판정 — 그림과 규칙이 같은 말을 하는가 ──
	print("\n  ── 흑백 판정 (색규칙.위험한가) ──")
	print("     흰 지형 %d 개 · 검정(무색) 지형 %d 개" % [흰것.size(), 검은것.size()])
	for 묶음 in [["흰 지형", 흰것, ColorDefs.WHITE], ["검정 지형", 검은것, ColorDefs.BLACK]]:
		var 목록: Array = 묶음[1]
		if 목록.is_empty():
			continue
		var t: Node2D = 목록[0]
		var 기본색: int = t.call("기본_아트색") if t.has_method("기본_아트색") else -1
		var 검정_죽나 := 색규칙.위험한가(-1, ColorDefs.BLACK, 기본색)
		var 흰_죽나 := 색규칙.위험한가(-1, ColorDefs.WHITE, 기본색)
		print("     %-10s (예: %s) — 검정 플레이어 죽음=%s · 흰색 플레이어 죽음=%s  [기대: %s]"
			% [묶음[0], t.name, 검정_죽나, 흰_죽나,
				"검정만 죽는다" if 묶음[2] == ColorDefs.WHITE else "흰색만 죽는다"])

	# ── ① 유령 — 칠하면 실체가 되는가 ──
	if 유령들.is_empty():
		print("\n  (유령 발판 없음)")
	else:
		print("\n  ── 유령 발판: 검정 물감을 필요횟수만큼 쏜다 ──")
		var 총발수 := 0
		for t in 유령들:
			var 필요: int = int(t.call("필요횟수"))
			총발수 += 필요
			var 결과 := ""
			for i in 필요:
				결과 = str(t.call("명중", 0, t.global_position))
			for i in 4:
				await physics_frame
			var 레이어: int = t.call("get_collision_polygon_node").get_parent().collision_layer
			print("     %-28s %d발 → \"%s\" · 밟을수있나=%s · 레이어=%d"
				% [t.name, 필요, 결과, t.call("밟을_수_있나"), 레이어])

		# ── ③ 탄약 예산 ──
		var 코어 := _루트.get_tree().get_first_node_in_group("페인트코어")
		var 최대: int = int(코어.get("최대_탄약")) if 코어 else 12
		print("\n  ── 탄약 예산 ── 유령 합계 %d 발 / 탄창 %d 발 → 여유 %d 발%s"
			% [총발수, 최대, 최대 - 총발수, "  ✗ 초과!" if 총발수 > 최대 else "  ✔"])

		print("\n  ── 실제로 서지는가 (칠한 뒤 위에서 떨어뜨린다) ──")
		for t in 유령들:
			var 윗면: float = t.global_position.y - 80.0
			_p.velocity = Vector2.ZERO
			_p.global_position = Vector2(t.global_position.x, 윗면 - 200.0)
			await physics_frame
			for i in 240:
				await physics_frame
				if _p.is_on_floor():
					break
			print("     %-28s 착지 y %.0f  (기대 %.0f)"
				% [t.name, _p.global_position.y, 윗면])

	print("════════ 끝 ════════\n")
	quit(0)
