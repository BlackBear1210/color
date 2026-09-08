extends SceneTree
## ============================================================================
## [2026-09-05 신규] LightOccluder2D 자동 생성 — **멱등 · 콜리전 무변경**
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/그림자_가림막.gd            # 표대로 적용
##   godot --headless --path . -s res://tools/그림자_가림막.gd -- --조사   # 보기만
##
## ▣ 무엇을 하나
##   지형의 **기존 CollisionPolygon2D 점 배열을 읽어**, 같은 모양의
##   OccluderPolygon2D 를 가진 LightOccluder2D 를 그 지형의 **형제**로 만든다.
##
##       [지형/벽_왼위_BRICK_01]
##        ├ StaticBody2D
##        │  └ CollisionPolygon2D      ← 읽기만 한다. 한 점도 안 고친다.
##        └ 빛가림 (LightOccluder2D)   ← 이 도구가 만든다
##           └ occluder: OccluderPolygon2D
##
## ▣ ★건드리지 않는 것 (지시서 §4)
##   · SmartShape2D 애드온 · 지형의 점 배열 · shape_material
##   · StaticBody2D · CollisionPolygon2D  ← **읽기 전용**
##   · 씬의 다른 노드
##   씬은 instantiate→pack 이 아니라 **텍스트로** 고친다(SS2D 구운 데이터 보호).
##
## ▣ 왜 모든 지형에 안 거나
##   지시서 §4: "모든 지형에 무조건 그림자를 켜지 않는다.
##   벽/큰 구조물처럼 실제로 빛을 차단해야 하는 요소부터 적용한다."
##   천장·바닥에 걸면 방 전체가 그림자에 잠겨 플레이어가 통째로 묻힌다.
##   → 아래 `대상표` 에 **이름을 적은 것만** 만든다.
##
## ▣ 멱등 (CLAUDE.md §5)
##   `빛가림` 노드와 `빛가림_` 로 시작하는 sub_resource 를 먼저 전부 지우고 다시 쓴다.
## ============================================================================

const 노드이름 := "빛가림"
const 리소스_접두 := "빛가림_"

## 씬 → 그림자를 드리울 지형 노드 이름들 (씬 뿌리 기준 경로)
const 대상표 := {
	"res://scenes/집/스테이지_1_2층방.tscn": [
		# 방을 가르는 진짜 벽·기둥만. 창문(오른쪽)에서 오는 빛을 실제로 막는 것들이다.
		"지형/벽_왼위_BRICK_01",
		"지형/벽_왼아래_BRICK_01",
		"지형/벽_오른_BRICK_01",
		"지형/SS_BRICK_POST_CORBEL_01",
		"지형/SS_BRICK_BREAK_WALL_01",
		"지형/SS_WOOD_WARDROBE_01",      # 방 한가운데 서 있는 옷장 = 큰 구조물
		# ⚠ 천장(천장_STAGE1_BRICK_01)·바닥(SS_WOOD_FLOOR_01)은 **일부러 뺐다**.
		#   방 전체를 덮는 폴리곤이라 그림자를 켜면 방이 통째로 어둠에 잠긴다.
	],
	# ★[2026-09-05] 조명/노멀맵 공식 검증 랩.
	#   그림자 테스트도 **프로덕션과 같은 도구**로 만든다 — 랩 전용 그림자 코드를
	#   따로 두면 "랩에서는 되는데 게임에서 다르다"가 생긴다.
	"res://scenes/집/테스트_2층방_노멀맵.tscn": [
		"테스트_브릭",   # 광원 바로 앞의 벽 → 아래쪽 발판에 그림자를 던진다
		"테스트_벽",     # 세로 벽
	],
}


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 조사만 := OS.get_cmdline_user_args().has("--조사")
	var 실패 := 0
	for 경로: String in 대상표:
		print("· %s" % 경로.get_file())
		var 조각 := await _폴리곤_읽기(경로, 대상표[경로])
		if 조각.is_empty():
			print("    ✗ 대상 지형을 하나도 못 찾았다")
			실패 += 1
			continue
		var 절대 := ProjectSettings.globalize_path(경로)
		var 원문 := FileAccess.get_file_as_string(절대)
		var 결과 := _고치기(원문, 조각)
		for 줄 in 결과["기록"]:
			print("    %s" % 줄)
		if 조사만:
			continue
		var f := FileAccess.open(절대, FileAccess.WRITE)
		if f == null:
			print("    ✗ 쓰기 실패")
			실패 += 1
			continue
		f.store_string(결과["글"])
		f.close()
	print("빛가림 %s (실패 %d)" % ["조사만" if 조사만 else "적용", 실패])
	quit(1 if 실패 > 0 else 0)


## 씬을 **읽기 전용으로** 인스턴스해서, 대상 지형의 콜리전 폴리곤을
## 그 지형의 로컬 좌표로 옮겨 온다. 저장은 절대 하지 않는다.
func _폴리곤_읽기(경로: String, 대상: Array) -> Array:
	var ps := load(경로) as PackedScene
	if ps == null:
		return []
	var 뿌리 := ps.instantiate()
	root.add_child(뿌리)
	# SS2D 가 콜리전을 다시 굽는 데 몇 프레임이 걸린다.
	for _i in 12:
		await process_frame

	var 결과: Array = []
	for 길: String in 대상:
		var n := 뿌리.get_node_or_null(NodePath(길)) as Node2D
		if n == null:
			print("    ⚠ 없음: %s" % 길)
			continue
		var cps: Array = []
		_콜리전_모으기(n, cps)
		if cps.is_empty():
			print("    ⚠ 콜리전 없음: %s" % 길)
			continue
		for i in cps.size():
			var cp: CollisionPolygon2D = cps[i]
			if cp.polygon.size() < 3:
				continue
			# 콜리전 점은 cp 의 로컬 좌표다. 가림막은 지형 노드의 자식이 되므로
			# **지형 노드의 로컬 좌표**로 옮겨야 모양이 정확히 겹친다.
			var 점: PackedVector2Array = PackedVector2Array()
			for p in cp.polygon:
				점.append(n.to_local(cp.to_global(p)))
			결과.append({"길": 길, "번호": i, "점": 점})
	뿌리.queue_free()
	for _i in 3:
		await process_frame
	return 결과


func _콜리전_모으기(n: Node, 모음: Array) -> void:
	for c in n.get_children():
		if c is CollisionPolygon2D:
			모음.append(c)
		_콜리전_모으기(c, 모음)


func _고치기(원문: String, 조각: Array) -> Dictionary:
	var 기록: Array = []
	var 줄들 := 원문.split("\n")

	# ── ① 예전 빛가림 노드 / sub_resource 지우기 (멱등) ──
	var 남길: Array = []
	var 버리는중 := false
	for L: String in 줄들:
		if L.begins_with("["):
			버리는중 = (L.begins_with("[node ") and L.contains('name="%s' % 노드이름)) \
				or (L.begins_with("[sub_resource ") and L.contains('id="%s' % 리소스_접두))
		if not 버리는중:
			남길.append(L)
	var 지움 := 줄들.size() - 남길.size()
	if 지움 > 0:
		기록.append("기존 빛가림 %d줄 제거" % 지움)

	# ── ② OccluderPolygon2D sub_resource 를 첫 [node] 앞에 넣는다 ──
	var 첫노드 := -1
	for i in 남길.size():
		if String(남길[i]).begins_with("[node "):
			첫노드 = i
			break
	if 첫노드 < 0:
		return {"글": "\n".join(남길), "기록": 기록 + ["✗ [node] 를 못 찾았다"]}

	var 리소스: Array = []
	var 노드: Array = []
	for k in 조각.size():
		var 줄: Dictionary = 조각[k]
		var rid := "%s%03d" % [리소스_접두, k]
		리소스.append('[sub_resource type="OccluderPolygon2D" id="%s"]' % rid)
		# closed = true (기본) — 지형은 속이 찬 덩어리라 닫힌 폴리곤이 맞다.
		리소스.append("polygon = " + _점글(줄["점"]))
		리소스.append("")
		var 이름: String = 노드이름 if int(줄["번호"]) == 0 \
			else "%s%d" % [노드이름, int(줄["번호"])]
		노드.append("")
		노드.append('[node name="%s" type="LightOccluder2D" parent="%s"]'
			% [이름, 줄["길"]])
		노드.append('occluder = SubResource("%s")' % rid)
		# occluder_light_mask 는 기본(모든 레이어). 특정 광원만 막고 싶어지면
		# 여기서 마스크를 나누면 된다 — 지금은 나눌 이유가 없다.

	var 새: Array = []
	새.append_array(남길.slice(0, 첫노드))
	새.append_array(리소스)
	새.append_array(남길.slice(첫노드))
	while not 새.is_empty() and String(새[-1]).strip_edges() == "":
		새.remove_at(새.size() - 1)
	새.append_array(노드)
	새.append("")
	기록.append("빛가림 %d개 생성 (콜리전은 읽기만 함)" % 조각.size())
	return {"글": "\n".join(새), "기록": 기록}


func _점글(점: PackedVector2Array) -> String:
	var 조각: Array = []
	for p in 점:
		조각.append(_수(p.x))
		조각.append(_수(p.y))
	return "PackedVector2Array(%s)" % ", ".join(조각)


func _수(v: float) -> String:
	var s := String.num(v, 3)
	if s.contains("."):
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s
