extends SceneTree
## ============================================================================
## [2026-09-05 신규] 페인트 명중 이펙트 — 스테이지 전수 검사
## ----------------------------------------------------------------------------
## 실행 (로직만):
##   godot --headless --path . -s res://tools/test_물감명중.gd
## 실행 (실제 화면 + 스크린샷):
##   godot --rendering-method gl_compatibility --audio-driver Dummy --path . \
##         -s res://tools/test_물감명중.gd -- <스크린샷_저장폴더>
##
## ▣ 무엇을 확인하나 (도형님 지시)
##   "특정 Stage 하나만 테스트하지 마라. 더미 Area2D·더미 총알로 PASS 하지 마라."
##   → 그래서 이 검사는 **씬을 진짜로 띄우고**, 그 씬이 스스로 만든 **진짜 플레이어**와
##     **진짜 총**에 실제 마우스·발사 입력을 밀어 넣는다. 총알도 그 총이 만든 것이다.
##     검사용 총알·검사용 지형·검사용 Area2D 를 만들지 않는다.
##
## ▣ 왜 스테이지 목록을 손으로 안 적나
##   `챕터.gd` 의 스테이지표(=진행 순서의 유일한 출처)에서 읽고,
##   거기 없는 옛 월드 씬은 폴더를 훑어 덧붙인다. 스테이지가 늘어도 이 파일은 안 고친다.
## ============================================================================

const 옛_월드_폴더 := ["res://scenes/world_1/", "res://scenes/world_2/"]
## 지형을 찾을 때 쏘는 방향들. 발밑부터 본다.
const 조준_방향 := [Vector2.DOWN, Vector2(0.6, 1.0), Vector2(-0.6, 1.0),
	Vector2.RIGHT, Vector2.LEFT, Vector2(1.0, -0.4), Vector2(-1.0, -0.4)]
const 단단한_레이어 := 1 | 8

var _저장폴더 := ""
var _결과: Array = []
## 발사가 왜 안 됐는지 파고들 때만 켠다(총의 쿨·플레이어·코어 상태를 찍는다).
var _시끄럽게 := false


func _init() -> void: call_deferred("_go")


func _go() -> void:
	var 인자 := OS.get_cmdline_user_args()
	_저장폴더 = 인자[0] if 인자.size() > 0 else ""
	# 두 번째 인자를 주면 이름에 그 글자가 든 스테이지만 돌린다(한 곳만 다시 볼 때).
	var 걸러내기: String = 인자[1] if 인자.size() > 1 else ""
	randomize()

	for 경로 in _스테이지_목록():
		if 걸러내기 != "" and not 경로.contains(걸러내기):
			continue
		await _한_스테이지(경로)
		# ★앞 스테이지가 **완전히 사라진 뒤에** 다음 씬을 올린다.
		#   `월드.gd` 는 페인트 코어를 `get_tree().get_first_node_in_group("페인트코어")`
		#   로 **트리 전체에서** 찾는다. queue_free 는 프레임 끝에 처리되므로, 곧바로
		#   다음 씬을 add_child 하면 새 월드가 **죽어가는 앞 스테이지의 코어**를 집어 간다.
		#   그러면 총이 `코어 == null` 로 보고 아무것도 안 쏜다 —
		#   스테이지_2 만 FAIL 하던 원인이 이것이었다(이펙트와 무관한 검사 도구 문제).
		#   실제 게임은 change_scene 이 앞 씬을 먼저 지우므로 이런 일이 없다.
		for _i in 4:
			await process_frame

	print("\n================ 결과 ================")
	var 실패 := 0
	for r in _결과:
		print("%-52s %s   %s" % [r["씬"].get_file(), r["판정"], r["설명"]])
		if r["판정"] != "PASS": 실패 += 1
	print("======================================")
	print("총 %d개 중 %d개 PASS / %d개 FAIL" % [_결과.size(), _결과.size() - 실패, 실패])
	quit(1 if 실패 > 0 else 0)


## 챕터표 + 옛 월드 폴더에서 "실제로 파일이 있는" 플레이 가능한 씬만 모은다.
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
	print("\n──────── %s" % 경로)
	var 씬 := load(경로) as PackedScene
	if 씬 == null:
		_적기(경로, "FAIL", "씬을 못 읽었다"); return
	var 노드 := 씬.instantiate()
	root.add_child(노드)
	# 이펙트는 `get_tree().current_scene` 밑으로 들어간다. 실제 플레이와 같게 맞춰 준다.
	current_scene = 노드
	for _i in 30:
		await process_frame

	var 플레이어 := _찾기(노드, func(n): return n.is_in_group("player"))
	if 플레이어 == null:
		_치우기(노드); _적기(경로, "SKIP", "플레이어가 없는 씬(플레이 대상 아님)"); return
	var 행동효과 := 플레이어.get_node_or_null("ActionFX")
	if 행동효과 == null:
		_치우기(노드); _적기(경로, "FAIL", "Player 밑에 ActionFX 가 없다"); return
	var 총 := _찾기(노드, func(n): return n is 페인트총 or n is ProtoGun)
	if 총 == null:
		_치우기(노드); _적기(경로, "SKIP", "총이 없는 씬(플레이 대상 아님)"); return

	# ── 어디를 쏠지: **실제 총구**에서 지형을 레이캐스트로 찾는다 ──
	#   ⚠ 플레이어 중심에서 재면 안 된다. 총알은 총구(플레이어보다 한참 위)에서 나가므로
	#     플레이어 발밑 벽을 겨누면 총알이 그 벽의 윗모서리를 스치고 지나가 버린다.
	#     (스테이지_2 가 이 이유로 한 번 헛발질했다 — 이펙트가 아니라 겨냥이 틀렸던 것)
	#   ⚠ 총구는 **마우스를 옮기면 같이 돈다**(총.gd 가 매 프레임 look_at 한다).
	#     그래서 두 번 겨눈다 — 대충 겨눠 총을 그쪽으로 돌린 뒤, 움직인 총구에서 다시 잰다.
	#     (이걸 안 해서 스테이지_2 만 헛발질했다. 이펙트가 아니라 겨냥이 틀렸던 것)
	var 원점 := Vector2.ZERO
	var 과녁 := Vector2.INF
	for _회 in 2:
		원점 = _발사원점(플레이어, 총)
		과녁 = _가까운_지형(원점, 플레이어)
		if 과녁 == Vector2.INF:
			_치우기(노드); _적기(경로, "FAIL", "총구 주위에서 지형을 못 찾았다"); return
		_마우스(노드, 과녁)
		await process_frame
		await process_frame

	print("    총구=%s  과녁=%s  거리=%.0f" % [원점, 과녁, 원점.distance_to(과녁)])
	# ── 진짜 입력을 밀어 넣는다 (좌클릭 = shoot) ──
	await _쏘기(노드, 과녁)

	# 총알이 날아가 맞을 때까지 기다린다.
	# ★총알이 아예 안 나온 것과, 총알은 났는데 이펙트가 안 붙은 것은 원인이 전혀 다르다.
	#   앞은 "겨냥/탄약/입력" 문제, 뒤가 진짜 이펙트 문제다. 반드시 갈라서 보고한다.
	var 효과: Node = null
	var 총알_봤나 := false
	var 마지막_총알 := Vector2.ZERO
	for _i in 90:
		await process_frame
		var 총알 := _찾기(current_scene, func(n): return n is 페인트총알 or n is ProtoBullet) as Node2D
		if 총알 != null:
			총알_봤나 = true
			마지막_총알 = 총알.global_position
		효과 = _찾기(current_scene, func(n): return n is 페인트명중효과)
		if 효과 != null: break

	if 효과 == null:
		var 왜 := ("총알은 날았는데(마지막 %s) 명중 이펙트가 안 생겼다" % 마지막_총알) \
			if 총알_봤나 else "총알 자체가 안 만들어졌다 (겨냥·탄약·입력 문제)"
		_치우기(노드); _적기(경로, "FAIL", 왜); return

	var 본체 := 효과.get_node_or_null("본체") as AnimatedSprite2D
	var 애니 := String(본체.animation)
	var 장수 := 본체.sprite_frames.get_frame_count(애니)
	var 시작프레임 := 본체.frame

	# 프레임이 실제로 넘어가는지(0 → 1 → 2 …) 본다. 멈춰 있으면 FAIL.
	# 스크린샷은 **물이 가장 크게 벌어지는 중간쯤**에서 찍는다. 다 끝난 뒤에 찍으면
	# 빈 화면만 남아서 "화면에서 확인했다"는 말이 거짓이 된다.
	var 최대프레임 := 시작프레임
	var 찍었나 := false
	for _i in 40:
		await process_frame
		if not is_instance_valid(본체): break
		최대프레임 = maxi(최대프레임, 본체.frame)
		if _저장폴더 != "" and not 찍었나 and 최대프레임 >= mini(3, 장수 - 1):
			찍었나 = true
			await _찍기(경로)

	var 진행함 := 최대프레임 > 시작프레임
	_치우기(노드)
	if 진행함:
		_적기(경로, "PASS", "%s · %d프레임 · %d번까지 재생 · 총=%s" % [애니, 장수, 최대프레임, 총.get_class()])
	else:
		_적기(경로, "FAIL", "%s 가 %d프레임에서 안 넘어간다" % [애니, 시작프레임])


## 마우스를 월드 좌표 위로 옮긴다. 총은 이 좌표를 보고 돈다.
func _마우스(노드: Node, 과녁: Vector2) -> void:
	var 화면 := 노드.get_viewport().get_canvas_transform() * 과녁
	var 이동 := InputEventMouseMotion.new()
	이동.position = 화면
	이동.global_position = 화면
	Input.parse_input_event(이동)


## 실제 총의 발사 경로를 그대로 탄다 — 마우스를 과녁에 올린 뒤 좌클릭.
func _쏘기(노드: Node, 과녁: Vector2) -> void:
	var 뷰 := 노드.get_viewport()
	var 화면 := 뷰.get_canvas_transform() * 과녁
	_마우스(노드, 과녁)
	await process_frame
	for 눌림 in [true, false]:
		var 클릭 := InputEventMouseButton.new()
		클릭.button_index = MOUSE_BUTTON_LEFT
		클릭.pressed = 눌림
		클릭.position = 화면
		클릭.global_position = 화면
		Input.parse_input_event(클릭)
		await process_frame
		await process_frame
	if _시끄럽게:
		# 총이 실제로 방아쇠를 당겼으면 쿨이 0 보다 크다. 0 이면 발사()가 도중에 되돌아간 것 —
		# 그때는 총이 들고 있는 플레이어·코어가 살아 있는지부터 본다.
		var 총3 := _찾기(노드, func(n): return n is 페인트총 or n is ProtoGun)
		print("      [진단] 쿨=%s  총.플레이어=%s  총.코어=%s" % [
			총3.get("_쿨"), 총3.get("플레이어"), 총3.get("코어")])


## 총알이 실제로 떠나는 자리. 스마트월드 총은 Muzzle, ProtoGun 은 총 노드 자신이다.
func _발사원점(플레이어: Node2D, 총: Node) -> Vector2:
	for 길 in ["GunRig/Gun/Muzzle", "Gun/Muzzle"]:
		var m := 플레이어.get_node_or_null(길) as Node2D
		if m: return m.global_position
	if 총 is Node2D: return (총 as Node2D).global_position
	return 플레이어.global_position


## 총구에서 제일 가까운 단단한 지형 점. 못 찾으면 Vector2.INF.
func _가까운_지형(원점: Vector2, 플레이어: Node2D) -> Vector2:
	var 공간 := 플레이어.get_world_2d().direct_space_state
	var 제외: Array[RID] = []
	if 플레이어 is CollisionObject2D:
		제외.append((플레이어 as CollisionObject2D).get_rid())
	var 최단 := Vector2.INF
	var 최단거리 := INF
	for 방향 in 조준_방향:
		var 질의 := PhysicsRayQueryParameters2D.create(
			원점, 원점 + 방향.normalized() * 900.0, 단단한_레이어)
		질의.collide_with_areas = false
		질의.exclude = 제외
		var 결과 := 공간.intersect_ray(질의)
		if 결과:
			var d: float = 원점.distance_to(결과["position"])
			# 너무 붙어 있는 점은 겨눠 봐야 방향이 안 잡힌다(총.gd 가 4px 미만이면 안 쏜다).
			if d >= 24.0 and d < 최단거리:
				최단거리 = d
				최단 = 결과["position"]
	return 최단


func _찍기(경로: String) -> void:
	await process_frame
	var 이미지 := root.get_texture().get_image()
	if 이미지 == null: return
	var 이름 := 경로.get_file().get_basename().replace(" ", "_").replace(",", "")
	이미지.save_png(_저장폴더 + "/명중_" + 이름 + ".png")
	print("    스크린샷 저장: 명중_%s.png" % 이름)


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


func _적기(경로: String, 판정: String, 설명: String) -> void:
	print("    → %s  %s" % [판정, 설명])
	_결과.append({"씬": 경로, "판정": 판정, "설명": 설명})
