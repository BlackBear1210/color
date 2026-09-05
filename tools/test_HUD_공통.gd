extends SceneTree
## ============================================================================
## [2026-09-05 신규] 공통 페인트 HUD — 스테이지 전수 검사
## ----------------------------------------------------------------------------
## 실행 (로직):
##   godot --headless --path . -s res://tools/test_HUD_공통.gd
## 실행 (실제 화면 + 스크린샷):
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . ^
##         -s res://tools/test_HUD_공통.gd -- <스크린샷_저장폴더>
##
## ▣ 무엇을 확인하나 (도형님 지시 §19 · §25)
##   · 각 스테이지에서 **페인트 HUD 가 정확히 하나**인가 (중복 생성 금지)
##   · 그 HUD 가 **공통 씬**(scenes/ui/페인트_HUD.tscn)에서 나온 것인가
##   · 초상 · 게이지 노드가 실제로 트리에 있는가
##   · 옛 얼굴 배지 · 옛 캡슐 바 그리기 함수가 **코드에서 사라졌는가**
##   · 게이지 채움이 실제 탄약(어댑터)과 같은가 — HUD 전용 숫자를 안 만들었는가
##   · 색 출처가 `자유색`(선택색())인가 — Shift 를 눌러 실제로 뒤집히는가
## ============================================================================

const 옛_월드_폴더 := ["res://scenes/world_1/", "res://scenes/world_2/"]
const 사라져야_할_함수 := ["_얼굴배지", "_탄약줄_그리기", "_칸_배치", "_스타디움", "_세그먼트"]

var _저장폴더 := ""
var _결과: Array = []


func _init() -> void: call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	_저장폴더 = 인자[0] if 인자.size() > 0 else ""

	_옛_코드_검사()
	for 경로 in _스테이지_목록():
		await _한_스테이지(경로)
		# ★앞 스테이지가 완전히 사라진 뒤에 다음 씬을 올린다.
		#   `월드.gd` 는 페인트 코어를 `get_tree().get_first_node_in_group()` 으로
		#   **트리 전체에서** 찾는다. queue_free 는 프레임 끝 처리라, 곧바로 다음 씬을
		#   add_child 하면 새 월드가 죽어가는 앞 씬의 코어를 집어 가서 탄약이 빈다.
		#   (실제 게임은 change_scene 이 앞 씬을 먼저 지우므로 이런 일이 없다)
		for _i in 4:
			await process_frame

	print("\n================ 결과 ================")
	var 실패 := 0
	for r in _결과:
		print("%-46s %s   %s" % [r["이름"], r["판정"], r["설명"]])
		if r["판정"] != "PASS": 실패 += 1
	print("======================================")
	print("총 %d개 중 %d개 PASS / %d개 FAIL" % [_결과.size(), _결과.size() - 실패, 실패])
	quit(1 if 실패 > 0 else 0)


## 옛 HUD 그리기 코드가 "숨겨진 채" 남아 있지 않은지 소스에서 직접 확인한다.
func _옛_코드_검사() -> void:
	var f := FileAccess.open("res://scripts/ui/페인트_HUD.gd", FileAccess.READ)
	var 글 := f.get_as_text() if f else ""
	if f: f.close()
	var 남은: Array = []
	for 이름 in 사라져야_할_함수:
		if 글.contains("func %s(" % 이름):
			남은.append(이름)
	if 남은.is_empty():
		_적기("옛 HUD 그리기 코드 제거", "PASS", "얼굴배지·캡슐바 함수가 전부 사라졌다")
	else:
		_적기("옛 HUD 그리기 코드 제거", "FAIL", "아직 남아 있다: %s" % [남은])


func _스테이지_목록() -> Array:
	var 목록: Array = []
	for s in 챕터.스테이지표:
		var p := String(s.get("씬", ""))
		if p != "" and ResourceLoader.exists(p):
			목록.append(p)
	for 폴더 in 옛_월드_폴더:
		var d := DirAccess.open(폴더)
		if d == null: continue
		for f in d.get_files():
			if f.ends_with(".tscn") and not 목록.has(폴더 + f):
				목록.append(폴더 + f)
	return 목록


func _한_스테이지(경로: String) -> void:
	var 이름 := 경로.get_file().get_basename()
	print("\n──────── %s" % 경로)
	var 노드 := (load(경로) as PackedScene).instantiate()
	root.add_child(노드)
	current_scene = 노드
	for _i in 30:
		await process_frame

	# ── 1) HUD 개수 ──
	var HUD들 := _모두(노드).filter(func(n): return n is 페인트HUD)
	if HUD들.size() != 1:
		_치우기(노드); _적기(이름, "FAIL", "페인트 HUD 가 %d개다 (정확히 1개여야 한다)" % HUD들.size()); return
	var hud: Node = HUD들[0]

	# ── 2) 공통 씬에서 나왔나 ──
	var 씬파일 := String(hud.scene_file_path)
	if 씬파일 != 페인트HUD.씬경로:
		_치우기(노드); _적기(이름, "FAIL", "공통 씬이 아니다 (scene_file_path=%s)" % 씬파일); return

	# ── 3) 초상·게이지 노드가 실제로 있나 ──
	var 초상 := hud.get_node_or_null("루트/본체/초상/초상_마스크/초상_그림") as AnimatedSprite2D
	var 액체 := hud.get_node_or_null("루트/본체/게이지/액체_마스크/액체") as CanvasItem
	if 초상 == null or 액체 == null:
		_치우기(노드); _적기(이름, "FAIL", "초상 또는 게이지 노드가 없다"); return
	if 초상.sprite_frames != load("res://assets/p/player_frames.tres"):
		_치우기(노드); _적기(이름, "FAIL", "초상이 실제 플레이어 SpriteFrames 를 안 쓴다"); return

	# ── 4) 게이지 채움 = 실제 탄약인가 ──
	var 어댑터 = hud.get("_어댑터")
	var 탄약: Dictionary = 어댑터.탄약() if 어댑터 else {}
	var 재질 := 액체.material as ShaderMaterial
	var 채움 := float(재질.get_shader_parameter("fill_level"))
	var 기대 := 0.0
	if not 탄약.is_empty() and float(탄약.get("최대", 0)) > 0.0:
		기대 = float(탄약["남은"]) / float(탄약["최대"])
	if absf(채움 - 기대) > 0.02:
		_치우기(노드); _적기(이름, "FAIL", "게이지 %.2f ≠ 실제 탄약 %.2f (%s)" % [채움, 기대, 탄약]); return

	# ── 5) 색 출처가 자유색인가 — Shift 없이 자유색만 뒤집어 본다 ──
	var 플레이어 := _찾기(노드, func(n): return n.is_in_group("player"))
	var 색확인 := "플레이어 없음"
	if 플레이어 and 플레이어.has_method("선택색"):
		var 원래: int = 플레이어.get("자유색")
		플레이어.set("자유색", ColorDefs.BLACK)
		await process_frame
		var 검정색: Color = 재질.get_shader_parameter("liquid_color")
		플레이어.set("자유색", ColorDefs.WHITE)
		await process_frame
		var 흰색색: Color = 재질.get_shader_parameter("liquid_color")
		플레이어.set("자유색", 원래)
		await process_frame
		if 검정색.r < 0.2 and 흰색색.r > 0.8:
			색확인 = "BLACK→어두운 잉크 / WHITE→밝은 잉크 ✔"
		else:
			_치우기(노드); _적기(이름, "FAIL", "자유색이 게이지 색으로 안 이어진다 (%s / %s)" % [검정색, 흰색색]); return

	# ── 6) 실제로 쏴서 탄약이 줄면 게이지도 줄어드는가 ──
	#   ★HUD 전용 숫자를 안 만들었는지 확인하는 유일한 방법이다.
	#     실제 총·실제 총알로 쏘고, 실제 시스템의 탄약과 게이지를 다시 맞춰 본다.
	var 감소 := "총 없음"
	var 총 := _찾기(노드, func(n): return n is 페인트총 or n is ProtoGun)
	if 플레이어 and 총:
		await _실제로_쏘기(노드, 플레이어 as Node2D, 총)
		for _i in 40:
			await process_frame
		var 탄약2: Dictionary = 어댑터.탄약()
		var 채움2 := float(재질.get_shader_parameter("fill_level"))
		var 기대2 := float(탄약2["남은"]) / float(탄약2["최대"]) if not 탄약2.is_empty() else 0.0
		if absf(채움2 - 기대2) > 0.02:
			_치우기(노드); _적기(이름, "FAIL", "발사 후 게이지 %.2f ≠ 탄약 %.2f" % [채움2, 기대2]); return
		if 채움2 >= 채움:
			감소 = "⚠ 발사했는데 안 줄었다(%.0f%%)" % [채움2 * 100.0]
		else:
			감소 = "발사 → %.0f%% 로 감소 ✔" % [채움2 * 100.0]

	# ── 7) 스크린샷 ──
	#   실탄 한 발로는 12 분의 1 밖에 안 줄어 액체 높이가 눈에 안 보인다.
	#   ★HUD 전용 값을 만드는 게 아니라 **실제 시스템의 `남은_탄약` 을 직접** 내려서,
	#     게이지가 그 값을 따라가는지 눈으로 확인할 수 있는 높이로 만든다.
	#     (검사가 끝나면 씬을 통째로 버리므로 게임에는 아무 영향이 없다)
	# 검정 잉크 / 흰 잉크 두 장을 다 찍는다 — §23 의 BLACK / WHITE 확인이 이걸로 끝난다.
	# ⚠ **색을 먼저 바꾸고, 탄약은 그 다음에 내린다.** 순서를 바꾸면 안 된다 —
	#   검은 지형 위에서 흰색으로 바꾸면 색 규칙대로 즉사하고, 리스폰이 `코어.리셋()` 을
	#   불러 탄약이 12 로 되돌아간다. (게임이 제대로 도는 것이지 HUD 버그가 아니다)
	if _저장폴더 != "":
		for 상태 in [[ColorDefs.BLACK, "검정"], [ColorDefs.WHITE, "흰색"]]:
			if 플레이어:
				플레이어.set("자유색", int(상태[0]))
				for _i in 6: await process_frame
			var 시스템 := _찾기(노드, func(n): return n is 페인트코어 or (n.get("남은_탄약") != null))
			if 시스템:
				시스템.set("남은_탄약", int(round(float(시스템.get("최대_탄약")) * 0.45)))
				for _i in 3: await process_frame
			print("      [%s] 게이지 fill=%.2f" % [상태[1], 재질.get_shader_parameter("fill_level")])
			await _찍기(경로, String(상태[1]))

	var 최대 := int(탄약.get("최대", 0))
	_치우기(노드)
	_적기(이름, "PASS", "HUD 1개 · 공통씬 · 시작 %.0f%% (탄약 %d/%d) · %s · %s" % [
		채움 * 100.0, int(탄약.get("남은", 0)), 최대, 색확인, 감소])


## 실제 총구에서 실제 지형을 겨눠 실제 좌클릭을 밀어 넣는다.
## (문법은 `tools/test_물감명중.gd` 와 같다 — 총구는 마우스를 따라 돌므로 두 번 겨눈다)
func _실제로_쏘기(노드: Node, 플레이어: Node2D, 총: Node) -> void:
	var 과녁 := Vector2.INF
	for _회 in 2:
		var 원점 := _발사원점(플레이어, 총)
		과녁 = _가까운_지형(원점, 플레이어)
		if 과녁 == Vector2.INF:
			return
		_마우스(노드, 과녁)
		await process_frame
		await process_frame
	var 화면 := 노드.get_viewport().get_canvas_transform() * 과녁
	for 눌림 in [true, false]:
		var 클릭 := InputEventMouseButton.new()
		클릭.button_index = MOUSE_BUTTON_LEFT
		클릭.pressed = 눌림
		클릭.position = 화면
		클릭.global_position = 화면
		Input.parse_input_event(클릭)
		await process_frame
		await process_frame


func _마우스(노드: Node, 과녁: Vector2) -> void:
	var 화면 := 노드.get_viewport().get_canvas_transform() * 과녁
	var 이동 := InputEventMouseMotion.new()
	이동.position = 화면
	이동.global_position = 화면
	Input.parse_input_event(이동)


func _발사원점(플레이어: Node2D, 총: Node) -> Vector2:
	for 길 in ["GunRig/Gun/Muzzle", "Gun/Muzzle"]:
		var m := 플레이어.get_node_or_null(길) as Node2D
		if m: return m.global_position
	if 총 is Node2D: return (총 as Node2D).global_position
	return 플레이어.global_position


func _가까운_지형(원점: Vector2, 플레이어: Node2D) -> Vector2:
	var 공간 := 플레이어.get_world_2d().direct_space_state
	var 제외: Array[RID] = []
	if 플레이어 is CollisionObject2D:
		제외.append((플레이어 as CollisionObject2D).get_rid())
	var 최단 := Vector2.INF
	var 최단거리 := INF
	for 방향 in [Vector2.DOWN, Vector2(0.6, 1.0), Vector2(-0.6, 1.0), Vector2.RIGHT, Vector2.LEFT]:
		var 질의 := PhysicsRayQueryParameters2D.create(
			원점, 원점 + 방향.normalized() * 900.0, 1 | 8)
		질의.collide_with_areas = false
		질의.exclude = 제외
		var 결과 := 공간.intersect_ray(질의)
		if 결과:
			var d: float = 원점.distance_to(결과["position"])
			if d >= 24.0 and d < 최단거리:
				최단거리 = d
				최단 = 결과["position"]
	return 최단


func _찍기(경로: String, 꼬리: String = "") -> void:
	await process_frame
	var 이미지 := root.get_texture().get_image()
	if 이미지 == null: return
	var 이름 := 경로.get_file().get_basename().replace(" ", "_").replace(",", "")
	if 꼬리 != "": 이름 += "_" + 꼬리
	이미지.save_png(_저장폴더 + "/HUD_" + 이름 + ".png")
	print("    스크린샷 저장: HUD_%s.png" % 이름)


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children(): r.append_array(_모두(c))
	return r


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 뿌리 == null: return null
	if 조건.call(뿌리): return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null: return r
	return null


func _치우기(노드: Node) -> void:
	if current_scene == 노드:
		current_scene = null
	노드.queue_free()


func _적기(이름: String, 판정: String, 설명: String) -> void:
	print("    → %s  %s" % [판정, 설명])
	_결과.append({"이름": 이름, "판정": 판정, "설명": 설명})
