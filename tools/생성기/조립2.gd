extends RefCounted
## ============================================================================
## [2026-09-21 신규] 조립 v2 — 동굴 결과를 **실제 씬**으로 굽는다
## ----------------------------------------------------------------------------
## ▣ v1 조립기(`조립.gd`)를 두고 새로 만든 이유
##   v1 은 **직사각형만** 굽는다(점 4 개 고정 · 저장본 자기검증도 "삼각형이면 실패"다).
##   v2 는 점이 200 개 넘는 **임의 폴리곤**(껍데기)을 굽는다 — 같은 함수로는 안 된다.
##   v1 은 하수도 쪽에서 아직 쓰므로 건드리지 않는다.
##
## ▣ 굽는 것 세 가지
##   ① 껍데기  — 폴리곤 하나. 바닥·천장·벽·돌기가 **전부 이어진 하나의 SS2D**
##                `칠하기_방식 = 안칠해짐`(색 규칙 밖). 긴변이 1 만 px 이라 칠하게 두면
##                `전체_색칠_최대긴변(576)` 에 걸려 "아무리 쏴도 안 굳는 벽" 이 된다.
##   ② 바위 섬 — 동굴 안에 떠 있는 바위. 껍데기와 같은 성격(구조)이다.
##   ③ 발판    — 플레이어가 칠하고 밟는 조각. 여기만 색 규칙에 참여한다.
##
## ▣ 콜리전
##   껍데기는 점이 많고 오목해서 볼록 분해(SOLIDS)가 무겁다 → **SEGMENTS**(변 충돌)로 둔다.
##   플레이어는 동굴 **안**에 있으므로 벽면만 막으면 되고, 그게 정확히 SEGMENTS 가 하는 일이다.
##   발판처럼 작고 볼록한 것은 기본(SOLIDS) 그대로 둔다.
## ============================================================================

const 규격 := preload("res://tools/생성기/규격.gd")
const 형태_S := preload("res://tools/생성기/형태.gd")

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const S_플레이어 := "res://scenes/player/Player.tscn"
const S_체크포인트 := "res://scenes/장애물/체크포인트.tscn"

var _편집표시: Array = []


## 씬 하나를 통째로 만든다.
func 굽기(동굴: Dictionary, 윤: Dictionary, 배치: Dictionary, 설정: RefCounted, 씬이름: String) -> Node2D:
	var 칸크기: float = float(동굴["칸크기"])
	var 원점: Vector2 = 동굴["원점"]
	var 전체 := Rect2(원점, Vector2(int(동굴["폭칸"]), int(동굴["높이칸"])) * 칸크기)

	var 루트: Node2D = 월드_S.new()
	루트.name = 씬이름
	루트.set("스테이지_이름", 설정.스테이지_이름)
	루트.set("카메라_리밋", 전체)
	루트.set("카메라_줌", 1.0)
	var 시작 := _칸_중심(동굴, 동굴["시작칸"])
	루트.set("시작_위치", 시작)
	# 낙사선 — 껍데기 바닥보다 아래. 동굴은 사방이 막혀 있어 원래 떨어져 나갈 곳이 없지만,
	# 안전장치로 둔다(월드.gd 가 이 값을 읽는다).
	루트.set("낙사_y", 전체.end.y + 320.0)
	루트.set("치명_낙하거리", 규격.치명_낙하)

	var 코어 := 코어_S.new()
	코어.name = "페인트코어"
	코어.set("최대_탄약", 규격.탄창)
	코어.add_to_group("페인트코어", true)
	루트.add_child(코어)

	var 통 := {}
	for n in ["지형", "장치", "위험물", "체크포인트"]:
		var g := Node2D.new()
		g.name = n
		루트.add_child(g)
		통[n] = g

	# ── ① 껍데기 (하나의 캡슐) ──────────────────────────────────────────────
	# 이름을 "벽_" 으로 시작하게 짓는다 — `레벨검사.gd` 가 이름 앞글자로 구조물을 가려낸다.
	var 껍 := _폴리곤_노드("벽_껍데기", 윤["껍데기"], 설정.구조_템플릿,
		규격.검정, 2, false, true)
	if 껍 != null:
		(통["지형"] as Node2D).add_child(껍)

	# ── ② 바위 섬 ──────────────────────────────────────────────────────────
	var i := 0
	for s in 윤["섬들"]:
		i += 1
		var n := _폴리곤_노드("벽_섬%02d" % i, s, 설정.구조_템플릿, 규격.검정, 2, false, false)
		if n != null:
			(통["지형"] as Node2D).add_child(n)

	# ── ③ 발판 (칠할 수 있는 것) ────────────────────────────────────────────
	for p in 배치["플랫폼"]:
		var 유령: bool = String(p["종류"]) == "유령"
		var 템플릿: String = 설정.유령_템플릿 if (유령 and 설정.유령_템플릿 != "") \
			else (설정.지형_템플릿_흰 if int(p["색"]) == 규격.흰색 else 설정.지형_템플릿_검)
		var r: Rect2 = p["사각"]
		var 점들 := PackedVector2Array([
			r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var n2 := _폴리곤_노드(String(p["이름"]), 점들, 템플릿,
			int(p["색"]), int(p["칠방식"]), 유령, false, bool(p.get("일방통행", false)))
		if n2 != null:
			(통["지형"] as Node2D).add_child(n2)

	# ── 위험물 · 체크포인트 ────────────────────────────────────────────────
	for h in 배치["위험물"]:
		var 씬 := load(h["씬"]) as PackedScene
		if 씬 == null:
			continue
		var t: Node2D = 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		t.name = "%s_%d" % [h["종류"], (통["위험물"] as Node2D).get_child_count() + 1]
		t.position = h["위치"]
		# ★[2026-09-23] `칸수` 가 오면 노드 하나가 여러 칸을 덮는다.
		#   hazard 그룹은 매 물리 프레임 전부 순회하므로 **노드 수가 곧 비용**이다.
		#   이유와 실측은 `계단층.gd _징검다리_구덩이()` 의 ③ 주석 참고.
		if h.has("칸수"):
			t.set("칸수", int(h["칸수"]))
		(통["위험물"] as Node2D).add_child(t)

	var cp := load(S_체크포인트) as PackedScene
	if cp != null:
		for c in _체크포인트_솎기(배치["체크포인트"]):
			var t2: Node2D = cp.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
			t2.name = "체크포인트_%d" % ((통["체크포인트"] as Node2D).get_child_count() + 1)
			t2.position = c
			(통["체크포인트"] as Node2D).add_child(t2)

	# ── 플레이어 · 끝점 ────────────────────────────────────────────────────
	var ps := load(S_플레이어) as PackedScene
	if ps != null:
		var pl: Node2D = ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		pl.name = "Player"
		pl.position = 시작
		pl.set("타일_크기", 규격.격자)
		pl.set("점프_높이_칸", 규격.점프_높이 / 규격.격자)
		pl.set("점프_거리_칸", 규격.점프_거리 / 규격.격자)
		루트.add_child(pl)

	var m := Marker2D.new()
	m.name = "끝도달_검사점"
	m.position = _칸_중심(동굴, 동굴["출구칸"])
	루트.add_child(m)

	루트.set_meta("gen_seed", int(배치.get("씨앗", 0)))
	루트.set_meta("gen_config", String(설정.이름))
	루트.set_meta("gen_algo", "v2_cave")
	return 루트


# ============================================================================
# ★[2026-09-23 신규] 체크포인트 솎기 — **광원 한계 때문**이지 디자인 취향이 아니다
# ----------------------------------------------------------------------------
# 체크포인트 하나가 PointLight2D 하나다. 그런데 v2 씬은 바닥·천장·벽이 전부
# `벽_껍데기` **노드 하나**라, 맵 어디에 있든 모든 체크포인트 빛이
# **같은 캔버스 아이템 하나**에 겹친다.
# Godot 4 의 2D 라이트는 캔버스 아이템당 15~16 개가 엔진 하드 한계다.
# 넘으면 껍데기가 통째로 빛을 안 받거나 광원이 깜빡인다.
#   실측(복도계단 s5): 관문 10 + 구덩이 6 + 방 3 = 19 개 → `진단_절차생성_예산` 이
#   "한 지형에 광원이 20 개 겹친다 ✖" 로 잡았다.
# → 서로 1,600 px 안에 있는 것을 합치고, 그래도 넘으면 고르게 솎아 10 개로 맞춘다.
#   (플레이어 보조광 1 개를 더해도 11 개 — 규격.한계_겹친광원 12 안이다)
# ⚠ 관문 바로 앞 체크포인트가 사라지면 난이도가 확 오른다. 솎을 때 **앞에서부터**
#   남기는 이유가 그것이다 — 앞쪽(쉬운 구간)이 아니라 몰려 있는 쪽이 솎인다.
# ============================================================================
const 최대_체크포인트: int = 10
const 최소_체크포인트_간격: float = 1600.0

static func _체크포인트_솎기(원본: Array) -> Array:
	# ① 가까이 몰린 것 합치기 — 관문 바로 뒤에 구덩이가 오면 둘이 몇백 px 안에 겹친다
	var 남김: Array = []
	for c: Vector2 in 원본:
		var 가깝다 := false
		for k: Vector2 in 남김:
			if c.distance_to(k) < 최소_체크포인트_간격:
				가깝다 = true
				break
		if not 가깝다:
			남김.append(c)
	if 남김.size() <= 최대_체크포인트:
		return 남김
	# ② 그래도 넘으면 **고르게** 솎는다. 앞에서 잘라 버리면 맵 뒷부분이 통째로 무체크포인트가 된다.
	var 결과: Array = []
	var 간격 := float(남김.size()) / float(최대_체크포인트)
	for i in 최대_체크포인트:
		결과.append(남김[mini(int(float(i) * 간격), 남김.size() - 1)])
	return 결과


func _칸_중심(동굴: Dictionary, 칸: Vector2i) -> Vector2:
	var 칸크기: float = float(동굴["칸크기"])
	return (동굴["원점"] as Vector2) + Vector2(칸.x + 0.5, 칸.y + 1.0) * 칸크기


## 임의 폴리곤 하나를 SS2D 지형 노드로.
##   칠방식: 0 전체칠 가능 · 1 부분칠만 · 2 안칠해짐(구조)
##   변_충돌: 콜리전을 **변(SEGMENTS)** 으로 만들까. 껍데기처럼 크고 오목한 것에 쓴다.
func _폴리곤_노드(이름: String, 점들: PackedVector2Array, 템플릿: String, 색: int,
		칠방식: int, 유령: bool, 변_충돌: bool, 일방통행: bool = false) -> Node2D:
	if 점들.size() < 3:
		return null
	var 씬 := load(템플릿) as PackedScene
	if 씬 == null:
		push_error("조립2: Template 을 못 읽었다 — %s" % 템플릿)
		return null
	var n: Node2D = 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	n.name = 이름

	# 노드 원점 = 점들의 바운딩 중심(하수도 빌더와 같은 방식)
	var 최소 := 점들[0]
	var 최대 := 점들[0]
	for p in 점들:
		최소 = 최소.min(p)
		최대 = 최대.max(p)
	n.position = (최소 + 최대) * 0.5

	# ★설정 순서 주의 — `칠하기_허용` 이 `칠하기_방식` 을 덮어쓴다(지형.gd 의 setter).
	n.set("칠하기_허용", 칠방식 != 2)
	n.set("칠하기_방식", 칠방식)
	n.set("무색일때_통과", 유령)
	n.set("시작상태", 규격.무색 if 유령 else 색)
	n.set("위치별_판정", true)
	# 콜리전 = 외곽선 그대로. 깎으면 조각 사이에 슬롯이 생겨 플레이어가 낀다.
	n.set("collision_offset", 0.0)
	n.set("collision_size", 0.0)

	var 로컬 := PackedVector2Array()
	for p in 점들:
		로컬.append(p - n.position)
	var 점배열 := SS2D_Point_Array.new()
	점배열.add_points(로컬)
	점배열.close_shape()
	n.set_point_array(점배열)

	var 폴리 := n.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	if 폴리 != null:
		폴리.polygon = 로컬
		if 변_충돌:
			# ★SEGMENTS 인 이유 — 껍데기는 점 200 개짜리 오목 폴리곤이다. SOLIDS 로 두면
			#   Godot 이 볼록 분해를 시도하다 **실패한다**(실측: "Convex decomposing failed!").
			#   분해가 실패하면 그 지형은 **콜리전이 통째로 없어진다** — 맵 전체가 뚫린다.
			#   플레이어는 동굴 안쪽에 있으므로 벽면만 막으면 되고, 그게 변 충돌이다.
			폴리.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
			# ★★이 줄이 없으면 위 설정이 **저장되지 않는다.**
			#   CollisionPolygon2D 는 Template 인스턴스가 원래 갖고 있는 노드라, 값을 바꿔도
			#   `[editable]` 표시가 없으면 저장에서 버려지고 기본값(SOLIDS)으로 되돌아간다.
			#   (2-2 탑 발판 일방통행이 통째로 사라졌던 것과 똑같은 사고다 · 작업기록 2026-09-17)
			_편집표시.append(폴리)
		if 일방통행:
			폴리.one_way_collision = true
			폴리.one_way_collision_margin = 4.0
			_편집표시.append(폴리)
	n.set_meta("role", "구조" if 칠방식 == 2 else "플랫폼")
	return n


## 저장 + **자기검증**. v1 과 달리 "직사각형이 아니면 실패" 로 보지 않는다 —
## 껍데기·섬은 원래 복합 다각형이다. 대신 **무너짐(붕괴)** 과 **퇴화점**만 본다.
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
		push_error("조립2: pack 실패 — %s" % error_string(e))
		return false
	for _시도 in 6:
		e = ResourceSaver.save(팩, 경로)
		if e == OK:
			break
		OS.delay_msec(400)
	if e != OK:
		push_error("조립2: 저장 실패 — %s" % error_string(e))
		return false
	return _저장본_검사(경로)


## 구운 파일을 **다시 읽어** 형태를 본다. 메모리 값이 아니라 파일에 적힌 값을 봐야
## "저장 과정에서 무너지는 것" 을 잡는다(2026-09-20 삼각형 사고 대응).
func _저장본_검사(경로: String) -> bool:
	var 팩 := ResourceLoader.load(경로, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if 팩 == null:
		push_error("조립2: 저장한 씬을 다시 못 읽었다")
		return false
	var 다시 := 팩.instantiate()
	var r := 형태_S.검사(다시)
	다시.free()
	if not (r["문제"] as Array).is_empty():
		for m in (r["문제"] as Array).slice(0, 5):
			push_error("조립2: 저장본 형태 이상 — %s" % m)
		return false
	# 발판(이름이 "벽_" 이 아닌 것)은 직사각형이어야 한다. 삼각형이면 무너진 것이다.
	var 무너짐: Array = []
	for 이름 in (r["삼각형"] as Array):
		if not String(이름).begins_with("벽_"):
			무너짐.append(이름)
	if not 무너짐.is_empty():
		push_error("조립2: 발판이 삼각형으로 무너졌다 %d 개 — %s"
			% [무너짐.size(), ", ".join(무너짐.slice(0, 5))])
		return false
	return true


func _주인(노드: Node, 루트: Node) -> void:
	for 자식 in 노드.get_children():
		if 자식.owner == null:
			자식.owner = 루트
		_주인(자식, 루트)
