extends SceneTree
## ============================================================================
## [2026-09-06 STEP 11 신규] PLATFORM OVERLAP AUDIT — 플랫폼끼리 실제로 겹치는가
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/진단_플랫폼겹침.gd -- <씬경로>
##       (인자 없으면 STAGE 2)
##
## ▣ 왜 필요한가 — 기존 검사 셋이 전부 이걸 못 본다
##   `레벨검사`      : 표면을 위에서 레이캐스트한다 → **덮인 지형은 아예 안 보인다**
##   `진단_지형메시`  : 노드 하나의 점·메시 수만 본다 → 이웃과의 관계를 모른다
##   `진단_콜리전대_그림`: 한 노드 안에서 그림과 콜리전이 맞는지만 본다
##   → "A 의 콜리전이 B 의 콜리전 속에 박혀 있다" 는 **아무도 안 잡는다.**
##     STEP 10 에서 실제로 터진 것: B1 슬래브 옆면이 B2 출구를 막았고,
##     A2 바로 밑에 B0 을 깔아 내려갈 수 없는 자리가 생겼다.
##
## ▣ "겹침" 과 "접합" 을 어떻게 가르나 (도형님 §11)
##   두 다각형의 실제 교집합 면적을 `Geometry2D.intersect_polygons()` 로 잰다.
##     · 교집합 면적 ≤ `접합_허용면적`            → 접합(edge-to-edge). PASS
##     · 한쪽이 다른 쪽에 파고든 깊이가 얕다(≤24) → SS2D 콜리전 부풀림(24). PASS
##     · 그 밖의 실제 침투                        → **FAIL**
##   ★수직으로 겹치지 않더라도 **"밟을 수 없게 만드는 근접"** 도 같이 잡는다:
##     x 가 겹치는 두 발판의 윗면 간격이 352 미만이면 아래 발판이 설 수 없는 면이 된다
##     (프로젝트 규칙 3). 이건 겹침은 아니지만 같은 부류의 사고라 WARN 으로 보고한다.
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 재서 보고만 한다.
## ============================================================================

const 기본씬 := "res://scenes/집/스테이지_2_복도계단.tscn"

## SS2D 콜리전은 사방 24 부푼다 — 그만큼의 파고듦은 정상으로 본다.
const 부풀림 := 24.0
## 이 면적 이하의 교집합은 모서리가 스친 것으로 본다(24 × 24 의 두 배).
const 접합_허용면적 := 1200.0
## 규칙 3 — x 가 겹치는 두 발판의 윗면 간격 하한.
const 규칙3_간격 := 352.0

var _이름: Array[String] = []
var _폴리: Array = []          ## 월드 좌표 다각형
var _구조물: Array[bool] = []
var _박스: Array[Rect2] = []


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	var args := OS.get_cmdline_user_args()
	var 씬경로: String = args[0] if args.size() > 0 else 기본씬
	var 루트 := (load(씬경로) as PackedScene).instantiate()
	root.add_child(루트)
	await physics_frame
	await physics_frame
	await physics_frame

	print("\n════════════════════════════════════════════════")
	print(" PLATFORM OVERLAP AUDIT — %s" % 씬경로.get_file())
	print("════════════════════════════════════════════════")

	_모으기(루트)
	if _폴리.size() < 2:
		print("  지형이 2 개 미만이다"); quit(0); return
	print("  검사 대상 지형 %d 개  ·  쌍 %d 개\n"
		% [_폴리.size(), _폴리.size() * (_폴리.size() - 1) / 2])

	var 침투: Array[String] = []
	var 접합: int = 0
	var 근접: Array[String] = []

	for i in _폴리.size():
		for j in range(i + 1, _폴리.size()):
			if not _박스[i].intersects(_박스[j]):
				continue
			var 면적 := _교집합_면적(_폴리[i], _폴리[j])
			if 면적 > 0.0:
				if 면적 <= 접합_허용면적:
					접합 += 1
				else:
					var 깊이 := _파고든_깊이(_박스[i], _박스[j])
					if 깊이 <= 부풀림:
						접합 += 1
					else:
						침투.append("%-28s ↔ %-28s  교집합 %.0f px²  파고듦 %.0f px"
							% [_이름[i], _이름[j], 면적, 깊이])
			# ★규칙 3 — 겹치지 않아도 "밟을 수 없게 만드는" 근접
			var a := _박스[i]
			var b := _박스[j]
			var x겹침 := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			if x겹침 > 40.0 and not (_구조물[i] and _구조물[j]):
				var 간격 := absf(a.position.y - b.position.y)
				if 간격 > 1.0 and 간격 < 규칙3_간격:
					근접.append("%-28s(y%.0f) ↕ %-28s(y%.0f)  간격 %.0f < 352  x겹침 %.0f"
						% [_이름[i], a.position.y, _이름[j], b.position.y, 간격, x겹침])

	print("── 실제 침투 (FAIL) ──────────────────────────")
	if 침투.is_empty():
		print("  ✔ 없음")
	else:
		for s in 침투:
			print("  ✖ %s" % s)

	print("\n── 규칙 3 근접 경고 (겹침은 아니지만 밟을 수 없게 될 수 있다) ──")
	if 근접.is_empty():
		print("  ✔ 없음")
	else:
		for s in 근접:
			print("  ⚠ %s" % s)

	print("\n────────────────────────────────────────────────")
	print("  Total platform pairs : %d" % [_폴리.size() * (_폴리.size() - 1) / 2])
	print("  정상 접합(edge)      : %d" % 접합)
	print("  Unintended overlap   : %d   %s" % [침투.size(), "PASS" if 침투.is_empty() else "FAIL"])
	print("  규칙 3 근접 경고      : %d" % 근접.size())
	print("════════════════════════════════════════════════\n")
	quit(0)


## 지형 노드의 **콜리전 폴리곤**을 월드 좌표로 모은다.
func _모으기(루트: Node) -> void:
	var 지 := 루트.get_node_or_null("지형")
	if 지 == null:
		return
	for c in 지.get_children():
		var t := c as Node2D
		if t == null:
			continue
		var 폴리 := t.get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
		if 폴리 == null or 폴리.polygon.size() < 3:
			continue
		var 월드 := PackedVector2Array()
		var 최소 := 폴리.to_global(폴리.polygon[0])
		var 최대 := 최소
		for p in 폴리.polygon:
			var w := 폴리.to_global(p)
			월드.append(w)
			최소 = 최소.min(w)
			최대 = 최대.max(w)
		_이름.append(t.name)
		_폴리.append(월드)
		_박스.append(Rect2(최소, 최대 - 최소))
		# 이름이 "천장"·"벽" 으로 시작하거나 칠할 수 없으면 구조물로 본다.
		var 칠: bool = bool(t.get("칠하기_허용")) if t.get("칠하기_허용") != null else false
		_구조물.append(not 칠)


func _교집합_면적(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var 결과 := Geometry2D.intersect_polygons(a, b)
	var 합 := 0.0
	for p in 결과:
		합 += absf(_다각형_면적(p))
	return 합


func _다각형_면적(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		s += p[i].x * q.y - q.x * p[i].y
	return s * 0.5


## 두 AABB 가 겹친 부분의 **짧은 쪽 길이** = 얼마나 파고들었나.
func _파고든_깊이(a: Rect2, b: Rect2) -> float:
	var w := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var h := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	return minf(maxf(w, 0.0), maxf(h, 0.0))
