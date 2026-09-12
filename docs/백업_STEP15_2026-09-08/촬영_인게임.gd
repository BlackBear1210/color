extends SceneTree
## ============================================================================
## [2026-09-05 신규] 인게임 실화면 촬영 — 비주얼 품질 작업 전용
## ----------------------------------------------------------------------------
## 실행:
##   godot --rendering-method gl_compatibility --audio-driver Dummy \
##         --resolution 1856x1044 --path . -s res://tools/촬영_인게임.gd -- \
##         <씬경로> <저장.png> [옵션...]
##
## 옵션 (전부 `키=값`)
##   대기=<프레임>        기본 90 — 카메라 스냅·라이트·배경이 자리 잡는 시간
##   위치=<x>,<y>         플레이어를 그 자리로 옮긴다 (구역별 확인)
##   색=black|white       Shift 를 누른 것과 같은 효과 (자유색 강제)
##   어둠=<0~1>           CanvasModulate 밝기를 런타임에 바꿔 본다 (씬 파일은 안 고친다)
##   빛높이=<px>          모든 PointLight2D 의 height
##   빛세기=<배율>        모든 PointLight2D 의 energy 배율
##   HUD배율=<배율>       HUD 본체 scale (크기 비교용)
##   그림자=on|off        모든 LightOccluder2D · Light2D 그림자 토글
##
## ★이 도구는 **씬 파일을 절대 저장하지 않는다.** 런타임 값만 바꿔 찍는다.
##   그래서 "값을 정하기 전에 화면으로 비교"할 때 안전하게 쓸 수 있다.
## ============================================================================

var _인자: Dictionary = {}
var _씬경로 := ""
var _저장 := ""


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_go")


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("사용법: -- <씬경로> <저장.png> [키=값 ...]")
		quit(1)
		return
	_씬경로 = args[0]
	_저장 = args[1]
	for i in range(2, args.size()):
		var s := String(args[i])
		var k := s.split("=", true, 1)
		if k.size() == 2:
			_인자[k[0]] = k[1]

	var ps := load(_씬경로) as PackedScene
	if ps == null:
		push_error("씬을 못 읽었다: %s" % _씬경로)
		quit(1)
		return
	var 노드 := ps.instantiate()
	root.add_child(노드)
	current_scene = 노드

	# 월드.gd 가 카메라·HUD·총을 붙이는 데 몇 프레임이 걸린다.
	for _i in 20:
		await process_frame

	_적용(노드)

	var 대기 := int(_인자.get("대기", "90"))
	for _i in 대기:
		await process_frame

	var img := root.get_texture().get_image()
	var err := img.save_png(_저장)
	print("촬영: %s -> %s" % [error_string(err), _저장])
	quit(0 if err == OK else 1)


func _적용(뿌리: Node) -> void:
	var 전부 := _모두(뿌리)

	# ── 플레이어 위치 · 색 ──
	var 플레이어: Node = null
	for n in 전부:
		# 랩 씬은 `테스트_Player` 라는 이름을 쓴다 → 뒤에 "Player" 가 붙으면 전부 인정.
		if String(n.name).ends_with("Player"):
			플레이어 = n
			break
	if 플레이어:
		if _인자.has("위치"):
			var xy := String(_인자["위치"]).split(",")
			if xy.size() == 2:
				플레이어.set("velocity", Vector2.ZERO)
				플레이어.set("global_position", Vector2(float(xy[0]), float(xy[1])))
		if _인자.has("색"):
			# 자유색은 ColorDefs 의 정수다. 플레이어의 공개 창구만 쓴다.
			var 값 := 0 if String(_인자["색"]) == "black" else 1
			if 플레이어.has_method("색_설정"):
				플레이어.call("색_설정", 값)
			else:
				플레이어.set("자유색", 값)
				플레이어.set("player_color", 값)
		# ★[2026-09-05 추가] 세워 둔 자리에서 그대로 찍는다.
		#   `위치` 만 주면 중력에 끌려 내려가서 매번 다른 자리가 찍힌다 —
		#   "같은 자리에서 값만 다른" 비교가 안 된다.
		if String(_인자.get("멈춤", "")) == "on":
			플레이어.set_physics_process(false)
			플레이어.set("velocity", Vector2.ZERO)

	# ── CanvasModulate ──
	if _인자.has("어둠"):
		var v := float(_인자["어둠"])
		for n in 전부:
			if n is CanvasModulate:
				(n as CanvasModulate).color = Color(v, v, v)

	# ── 광원 ──
	for n in 전부:
		if n is PointLight2D:
			var L := n as PointLight2D
			if _인자.has("빛높이"):
				L.height = float(_인자["빛높이"])
			if _인자.has("빛세기"):
				L.energy *= float(_인자["빛세기"])
			if _인자.has("반경배율"):
				# texture_scale 이 곧 반경이다(텍스처가 256px 기준).
				L.texture_scale *= float(_인자["반경배율"])
			if _인자.has("그림자알파"):
				var a := float(_인자["그림자알파"])
				L.shadow_color = Color(0, 0, 0, a)
		if n is Light2D and _인자.has("그림자"):
			(n as Light2D).shadow_enabled = String(_인자["그림자"]) == "on"
		# 발광체는 매 프레임 `밝기`·`반경` 으로 energy/texture_scale 을 다시 쓴다(깜빡임).
		# 그래서 PointLight2D 값만 곱하면 다음 프레임에 원래대로 돌아간다 → 원본을 곱한다.
		if n.get("밝기") != null and n.get("반경") != null:
			if _인자.has("빛세기"):
				n.set("밝기", float(n.get("밝기")) * float(_인자["빛세기"]))
			if _인자.has("반경배율"):
				n.set("반경", float(n.get("반경")) * float(_인자["반경배율"]))

	# ── 플레이어 보조광 (STEP 5) ──
	#   보조광=off / 보조광=<밝기> / 보조반경=<px>
	for n in 전부:
		if n.name != "플레이어_보조광":
			continue
		if _인자.has("보조광"):
			var v := String(_인자["보조광"])
			if v == "off":
				n.set("켜기", false)
			elif v == "on":
				n.set("켜기", true)
			else:
				n.set("켜기", true)
				n.set("밝기", float(v))
		if _인자.has("보조반경"):
			n.set("반경", float(_인자["보조반경"]))

	# ── ★[2026-09-05 STEP 5] 조명 Debug 모드 ──
	#   조명모드=1 환경만 / 2 보조만 / 3 환경+보조 / 4 환경+그림자 / 5 전체
	#   ⚠ 게임플레이 입력은 건드리지 않는다. 이 도구(촬영)와 실험실 씬에서만 쓴다.
	if _인자.has("조명모드"):
		var m := int(_인자["조명모드"])
		var 환경 := m != 2
		var 보조 := m == 2 or m == 3 or m == 5
		var 그늘 := m == 4 or m == 5
		for n in 전부:
			# 환경광 = 발광체가 만든 빛 + 씬에 직접 놓인 PointLight2D.
			#   보조광은 `플레이어_보조광` 밑에 있으므로 부모 이름으로 갈라낸다.
			if n is PointLight2D:
				var 부모이름 := String(n.get_parent().name) if n.get_parent() != null else ""
				var 보조광인가 := 부모이름 == "플레이어_보조광"
				if not 보조광인가:
					(n as PointLight2D).visible = 환경
					(n as PointLight2D).shadow_enabled = 그늘 and _그림자_원래(n)
			if n.name == "플레이어_보조광":
				n.set("켜기", 보조)

	# ── HUD ──
	for n in 전부:
		if n is CanvasLayer and n.name == "페인트HUD":
			if _인자.has("HUD배율"):
				n.set("배율", float(_인자["HUD배율"]))
			if _인자.has("초상채움"):
				n.set("초상_담을_비율", float(_인자["초상채움"]))
				n.call("_초상_담기")

	# ── 조명 실험실 전용 창구 ──
	# 실험실 씬(Lighting_Standard_Lab)의 컨트롤러가 있으면 그쪽 창구로 넘긴다.
	# 여기서 광원을 직접 만지면 실험실이 정해 둔 "조건"과 어긋나 비교가 무의미해진다.
	if 뿌리.has_method("조건_세우기"):
		if _인자.has("조건"):
			뿌리.call("조건_세우기", String(_인자["조건"]))
		if _인자.has("빛높이"):
			뿌리.call("높이_세우기", float(_인자["빛높이"]))
		if _인자.has("빛세기"):
			뿌리.call("세기_세우기", float(_인자["빛세기"]))
		if _인자.has("어둠"):
			뿌리.call("어둠_세우기", float(_인자["어둠"]))
		if _인자.has("빛반경"):
			뿌리.call("반경_세우기", float(_인자["빛반경"]))
		if _인자.has("노멀"):
			뿌리.call("노멀_켜기", String(_인자["노멀"]) == "on")

	# ── 노멀맵 테스트 랩(테스트_2층방_노멀맵) 전용 창구 ──
	if 뿌리.has_method("빛_자리"):
		if _인자.has("빛자리"):
			뿌리.call("빛_자리", String(_인자["빛자리"]))
		if _인자.has("노멀"):
			뿌리.call("노멀_켜기", String(_인자["노멀"]) == "on")
		if _인자.has("환경광"):
			뿌리.call("환경광_켜기", String(_인자["환경광"]) == "on")
		if _인자.has("보조광"):
			뿌리.call("보조광_켜기", String(_인자["보조광"]) != "off")
		if _인자.has("그림자"):
			뿌리.call("그림자_켜기", String(_인자["그림자"]) == "on")
		if _인자.has("빛반경"):
			뿌리.call("반경_세우기", float(_인자["빛반경"]))
		뿌리.call("카메라_맞추기")

	# 카메라가 플레이어를 바로 잡게 한다 (스냅)
	var _줌값 := float(_인자.get("줌", "0"))
	# ProtoCamera 가 없는 씬(실험실 등)은 씬에 박힌 Camera2D 를 그대로 옮긴다.
	if _줌값 > 0.0:
		var 붙는캠 := false
		for n in 전부:
			if n is Camera2D and n.has_method("setup"):
				붙는캠 = true
		if not 붙는캠:
			for n in 전부:
				if n is Camera2D and (n as Camera2D).enabled:
					(n as Camera2D).zoom = Vector2(_줌값, _줌값)
					if _인자.has("카메라"):
						var c2 := String(_인자["카메라"]).split(",")
						if c2.size() == 2:
							(n as Camera2D).global_position = Vector2(
								float(c2[0]), float(c2[1]))
					break
	for n in 전부:
		if n is Camera2D and n.has_method("setup") and 플레이어:
			n.call("setup", 플레이어)
			if _줌값 > 0.0:
				# ProtoCamera 는 리밋/줌을 스스로 굴린다 → 스크립트를 떼고 값을 박는다(촬영 전용)
				n.set_script(null)
				(n as Camera2D).make_current()
				(n as Camera2D).global_position = 플레이어.global_position
				(n as Camera2D).zoom = Vector2(_줌값, _줌값)
				# `카메라=x,y` 를 주면 플레이어가 아니라 그 좌표를 본다
				# (플레이어를 세울 자리와 보고 싶은 자리가 다를 때).
				if _인자.has("카메라"):
					var cxy := String(_인자["카메라"]).split(",")
					if cxy.size() == 2:
						(n as Camera2D).global_position = Vector2(
							float(cxy[0]), float(cxy[1]))


## 그림자를 **원래 켜기로 되어 있던 광원**인가.
## 조명모드 4·5 에서 모든 광원의 그림자를 켜 버리면 "주광 하나만 그림자"라는
## 설계가 무너져서, 그림자 방향이 여럿 겹친 화면을 보고 판단하게 된다.
func _그림자_원래(빛: PointLight2D) -> bool:
	var 부모 := 빛.get_parent()
	if 부모 != null and 부모.get("그림자") != null:
		return bool(부모.get("그림자"))
	return 빛.shadow_enabled


func _모두(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r