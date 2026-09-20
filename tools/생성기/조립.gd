extends RefCounted
## ============================================================================
## [2026-09-20 신규] 조립 — 생성 결과(좌표표)를 **실제 SS2D 씬**으로 굽는다
## ----------------------------------------------------------------------------
## ▣ 왜 생성기가 씬을 직접 안 만들고 여기로 넘기나
##   씬을 만드는 데는 1 년치 사고 대응이 들어 있다 — 편집상태 인스턴스, 일방통행 owner,
##   콜리전 offset, 칠하기_허용/칠하기_방식 설정 순서. 생성 알고리즘이 그걸 같이 들고 있으면
##   알고리즘을 고칠 때마다 그 사고를 다시 겪는다. **좌표를 만드는 일과 씬을 굽는 일을 나눈다.**
##
## ▣ 여기 들어 있는 지뢰 대응 (전부 저장소에서 한 번씩 터진 것)
##   · `instantiate(GEN_EDIT_STATE_INSTANCE)` — 그냥 instantiate 하면 서브씬과 다른 값이
##     "스크립트 기본값과 같다" 는 이유로 저장에서 빠진다(흰 물이 회색으로 되살아난 사고).
##   · `칠하기_허용` 을 먼저, `칠하기_방식` 을 나중에 — 지형.gd 에서 앞의 것이 뒤의 것을 덮어쓴다.
##   · `collision_offset = 0` — 깎으면 이웃 사이에 슬롯이 생겨 플레이어가 낀다.
##   · 일방통행 콜리전은 프리팹이 원래 갖고 있는 노드라 owner 를 뺏지 않고
##     `set_editable_instance()` 로 표시한다(안 그러면 다음 저장 때 값이 통째로 사라진다).
## ============================================================================

const 규격 := preload("res://tools/생성기/규격.gd")

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const S_플레이어 := "res://scenes/player/Player.tscn"

## 일방통행처럼 **프리팹 내부 노드의 값**을 씬에 남겨야 하는 것들
var _편집표시: Array = []


## 생성 결과를 새 씬으로 굽는다.
func 굽기(결과: Dictionary, 설정: RefCounted, 씬이름: String) -> Node2D:
	var 범위: Rect2 = 결과["범위"]
	var 루트: Node2D = 월드_S.new()
	루트.name = 씬이름
	루트.set("스테이지_이름", 설정.스테이지_이름)
	# 카메라는 지형 바깥으로 조금 더 보여 준다(외곽 셸이 화면 끝에 딱 붙으면 답답하다).
	루트.set("카메라_리밋", Rect2(범위.position - Vector2(64, 64), 범위.size + Vector2(128, 128)))
	루트.set("카메라_줌", 1.0)
	루트.set("시작_위치", 결과["시작"])
	# 낙사선 — 제일 낮은 지형보다 아래. 치명 낙하(1500)보다 가깝게 두면
	# "떨어졌는데 안 죽고 갇히는" 자리가 생긴다.
	루트.set("낙사_y", 규격.격자맞춤(범위.end.y + 640.0))
	루트.set("치명_낙하거리", 규격.치명_낙하)

	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 규격.탄창)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)

	var 통: Dictionary = {}
	for n in ["지형", "장치", "위험물", "체크포인트"]:
		var g := Node2D.new()
		g.name = n
		루트.add_child(g)
		통[n] = g

	for p in 결과["플랫폼"]:
		var n := 지형_노드(p, 설정)
		if n != null:
			(통["지형"] as Node2D).add_child(n)

	for h in 결과["위험물"]:
		var 씬 := load(h["씬"]) as PackedScene
		if 씬 == null:
			continue
		var t: Node2D = 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		t.name = "%s_%d" % [h["종류"], (통["위험물"] as Node2D).get_child_count() + 1]
		t.position = h["위치"]
		(통["위험물"] as Node2D).add_child(t)

	# 플레이어 — ★스테이지가 기본값을 덮어쓴다.
	#   Player.tscn 기본은 점프 거리 10칸(160)이라 20칸(320)으로 설계한 틈을 못 건넌다.
	var ps := load(S_플레이어) as PackedScene
	if ps != null:
		var pl: Node2D = ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		pl.name = "Player"
		pl.position = 결과["시작"]
		pl.set("타일_크기", 규격.격자)
		pl.set("점프_높이_칸", 규격.점프_높이 / 규격.격자)
		pl.set("점프_거리_칸", 규격.점프_거리 / 규격.격자)
		루트.add_child(pl)

	var m := Marker2D.new()
	m.name = "끝도달_검사점"
	m.position = 결과["끝"]
	루트.add_child(m)

	# 씨앗을 씬에 박아 둔다 — "이 맵 어떻게 나왔지" 를 나중에 추적할 수 있어야 한다.
	루트.set_meta("gen_seed", int(결과["씨앗"]))   # ⚠ 메타 이름은 ASCII 여야 한다(한글은 Invalid metadata identifier)
	루트.set_meta("gen_config", String(설정.이름))
	루트.set_meta("gen_date", "2026-09-20")
	return 루트


## 플랫폼 스펙 하나 → SS2D 지형 노드
func 지형_노드(p: Dictionary, 설정: RefCounted) -> Node2D:
	var 종류: String = p["종류"]
	var 유령: bool = 종류 == "유령"
	var 색: int = int(p["색"])
	var 칠방식: int = int(p["칠방식"])

	var 템플릿: String = ""
	if 유령 and 설정.유령_템플릿 != "":
		템플릿 = 설정.유령_템플릿
	elif 종류 == "구조" and 설정.구조_템플릿 != "":
		템플릿 = 설정.구조_템플릿
	else:
		템플릿 = 설정.지형_템플릿_흰 if 색 == 규격.흰색 else 설정.지형_템플릿_검

	var 씬 := load(템플릿) as PackedScene
	if 씬 == null:
		push_error("조립: Template 을 못 읽었다 — %s" % 템플릿)
		return null
	var n: Node2D = 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	n.name = String(p["이름"])

	var r: Rect2 = p["사각"]
	var 중심 := r.get_center()
	n.position = 중심

	# ★순서 주의 — `칠하기_허용` 이 `칠하기_방식` 을 덮어쓴다(지형.gd 의 setter).
	#   먼저 허용을 주고, 그 다음 방식을 준다.
	n.set("칠하기_허용", 칠방식 != 2)
	n.set("칠하기_방식", 칠방식)
	n.set("무색일때_통과", 유령)
	# 유령은 **안 칠한 상태로 시작**해야 "칠해야 생긴다" 가 성립한다.
	n.set("시작상태", 규격.무색 if 유령 else 색)
	n.set("위치별_판정", true)
	# 콜리전 = 외곽선 그대로. 깎으면 이웃 사이 슬롯에 플레이어가 낀다.
	n.set("collision_offset", 0.0)
	n.set("collision_size", 0.0)

	var 로컬 := PackedVector2Array([
		Vector2(-r.size.x * 0.5, -r.size.y * 0.5),
		Vector2(r.size.x * 0.5, -r.size.y * 0.5),
		Vector2(r.size.x * 0.5, r.size.y * 0.5),
		Vector2(-r.size.x * 0.5, r.size.y * 0.5),
	])
	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(로컬)
	점배열.close_shape()
	n.set_point_array(점배열)

	var 폴리 := n.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		폴리.polygon = 로컬
		if bool(p.get("일방통행", false)):
			# 공중 발판은 아래에서 위로 통과. 두 칸 위 발판 밑면에 머리가 박히는 것을 막는다.
			폴리.one_way_collision = true
			폴리.one_way_collision_margin = 4.0
			_편집표시.append(폴리)
	n.set_meta("role", "구조" if 종류 == "구조" else "플랫폼")
	return n


## 씬으로 저장한다. (하수도_빌더_공통.저장() 과 같은 절차 — 사고 대응이 들어 있다)
func 저장(루트: Node, 경로: String) -> bool:
	var dir := 경로.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_주인(루트, 루트)
	for n in _편집표시:
		if n.owner != null and n.owner != 루트 and 루트.is_ancestor_of(n.owner):
			루트.set_editable_instance(n.owner, true)
		elif n.owner == null:
			n.owner = 루트
	var 팩 := PackedScene.new()
	var e := 팩.pack(루트)
	if e != OK:
		push_error("pack 실패: %s" % error_string(e))
		return false
	# 에디터가 같은 프로젝트를 열어 두면 파일을 잠깐 잠근다 → 몇 번 다시 시도한다.
	for _시도 in 6:
		e = ResourceSaver.save(팩, 경로)
		if e == OK:
			break
		OS.delay_msec(400)
	return e == OK


## 새로 만든 노드에만 owner 를 준다.
## ⚠ 인스턴스가 원래 갖고 있던 내부 노드(owner 가 인스턴스 루트)는 건드리지 않는다 —
##   다시 박으면 다음 로드 때 노드가 두 벌이 되고 씬 교체에서 세그폴트가 난다(CLAUDE.md §6).
func _주인(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		if 자식.owner == null:
			자식.owner = 루트
		_주인(자식, 루트)


## ============================================================================
## 기존 씬에 **지형만 갈아 끼운다** (도형님 요청: "씬 안에 지형 플랫폼들을 랜덤 재배치")
## ----------------------------------------------------------------------------
## 배경·조명·오브젝트는 **그대로 두고** `지형` 노드의 자식만 새 것으로 바꾼다.
## ⚠ 되돌릴 수 없으므로 항상 `.bak` 을 먼저 만든다. 그리고 이 함수는 기본값이 아니다 —
##   `tools/생성_스테이지.gd -- --적용` 을 명시적으로 줘야 돈다.
## ============================================================================
func 지형만_교체(대상_씬: String, 결과: Dictionary, 설정: RefCounted) -> bool:
	var ps := load(대상_씬) as PackedScene
	if ps == null:
		push_error("적용: 대상 씬을 못 읽었다 — %s" % 대상_씬)
		return false
	# 백업 — 남의 작업을 지우는 사고가 이 저장소에서 실제로 있었다(CLAUDE.md §8)
	var 절대 := ProjectSettings.globalize_path(대상_씬)
	var 백업 := 절대.get_basename() + ".bak.tscn"
	if DirAccess.copy_absolute(절대, 백업) != OK:
		push_error("적용: 백업을 못 만들었다 — 중단한다")
		return false
	print("   백업: %s" % 백업.get_file())

	var 루트 := ps.instantiate() as Node2D
	var 지형통 := 루트.get_node_or_null("지형") as Node2D
	if 지형통 == null:
		push_error("적용: `지형` 노드가 없다 — 이 씬은 구조가 다르다")
		return false
	for c in 지형통.get_children():
		지형통.remove_child(c)
		c.queue_free()
	for p in 결과["플랫폼"]:
		var n := 지형_노드(p, 설정)
		if n != null:
			지형통.add_child(n)

	# ★출구 통로를 새 끝 지점으로 옮긴다.
	#   안 옮기면 예전 출구(집 1-1 은 x 5891)가 새 스테이지 **한가운데 공중**에 남는다 —
	#   플레이어가 중간에서 다음 스테이지로 넘어가 버리거나, 아예 도달을 못 한다.
	#   자식(바닥·천장·뒷벽·속빛)은 상대 좌표라 부모만 옮기면 같이 따라온다.
	var 출구 := 루트.get_node_or_null("오브젝트/출구통로") as Node2D
	if 출구 != null:
		출구.position = Vector2(결과["끝"].x + 160.0, 결과["끝"].y)
		print("   출구통로를 끝 지점으로 이동: %s" % str(출구.position.round()))

	# 카메라·낙사선·시작 위치는 새 지형에 맞춰 다시 박는다(안 맞추면 화면 밖을 본다)
	var 범위: Rect2 = 결과["범위"]
	루트.set("카메라_리밋", Rect2(범위.position - Vector2(64, 64), 범위.size + Vector2(128, 128)))
	루트.set("시작_위치", 결과["시작"])
	루트.set("낙사_y", 규격.격자맞춤(범위.end.y + 640.0))
	루트.set("치명_낙하거리", 규격.치명_낙하)
	var pl := 루트.get_node_or_null("Player") as Node2D
	if pl != null:
		pl.position = 결과["시작"]
		pl.set("타일_크기", 규격.격자)
		pl.set("점프_높이_칸", 규격.점프_높이 / 규격.격자)
		pl.set("점프_거리_칸", 규격.점프_거리 / 규격.격자)
	루트.set_meta("gen_seed", int(결과["씨앗"]))   # ⚠ 메타 이름은 ASCII 여야 한다(한글은 Invalid metadata identifier)
	return 저장(루트, 대상_씬)
