extends SceneTree
## ============================================================================
## [2026-08-19 신규] 지형 보정기 — 막힌 길을 **원본을 안 부수고** 뚫는다
## ----------------------------------------------------------------------------
## 실행:
##   조사만 : Godot --headless --path . -s res://tools/지형_보정.gd -- <씬경로>
##   적용   : Godot --headless --path . -s res://tools/지형_보정.gd -- <씬경로> --적용
##   전부   : … -- --전부 --적용
##
## ▣ 왜 필요한가 (도형님 요청)
##   "너가 모든 맵을 플레이 돌려보고 막히는 부분을 수정해."
##   스테이지 1 은 밟는 지형 86 개 중 **11 개**밖에 못 간다. 원인은 하나가 아니라
##   "아깝게 못 닿는 자리" 가 사슬처럼 이어져 있어서, 하나를 뚫으면 다음이 드러난다.
##   손으로 좌표를 찍는 방식으로는 끝이 안 난다.
##
## ▣ 두 가지 보정을 한다 (둘 다 **멱등** — 몇 번 돌려도 결과가 같다)
##
##   [A] 끼임 얇게 — 선반이 두꺼워서 그 **아래를 못 지나가는** 자리
##       선반 아래를 깎아 머리 공간을 만든다. **윗면(밟는 면)은 1px 도 안 건드린다.**
##       → 단차·점프 계산이 그대로 유지된다. 이게 핵심이다.
##
##   [B] 디딤돌 놓기 — 아깝게 못 닿는 자리에 **작은 발판 하나**를 끼워 넣는다
##       예: 지형_20(y 528) → 지형_29(y 400) 은 128px 단차인데 한계가 102px 이다.
##           둘 사이 y 464 에 디딤돌을 놓으면 64px + 64px 두 번으로 올라간다.
##       ★기존 지형을 깎거나 옮기지 않는다. 원본 레벨 디자인의 실루엣이 보존된다.
##         (인수인계 문서 §작업A 의 "①번 안" — 도형님이 선호한다고 적어 둔 그 방식이다)
##
## ▣ 멱등을 지키는 법
##   `디딤_` 으로 시작하는 노드를 **먼저 전부 지우고** 다시 계산한다.
##   끼임 얇게는 이미 얇으면 아무것도 안 한다.
##   ⚠ "기존 값 + 여유" 같은 누적은 절대 하지 않는다 (지뢰밭 §5-2).
##
## ▣ 안전장치
##   · `--적용` 없이는 **아무것도 저장하지 않는다.** 기본은 조사다.
##   · 디딤돌을 놓을 자리에 이미 지형이 있으면 안 놓는다(겹치면 콜리전이 꼬인다).
##   · 디딤돌 위에 머리 공간이 없으면 안 놓는다(놔 봐야 못 밟는다).
##   · 한 번에 `최대_디딤` 개까지만 놓는다. 그 이상 필요하면 레벨 설계가 잘못된 것이다.
## ============================================================================

const 공통 := preload("res://tools/지형공통.gd")

const 표본간격 := 32.0
const 최대층 := 12
const 여유_세로 := 0.80          ## 레벨검사와 같은 기준 — 점프 높이의 80% 까지만 오른다고 본다
const 여유_가로 := 0.85
const 묶기_허용높이 := 26.0
const 머리_여유 := 6.0
const 발치_무시 := 16.0

## 디딤돌 규격. 얇아야 그 아래도 지나갈 수 있다(§[A] 와 같은 이유).
const 디딤_두께 := 16.0
const 디딤_길이 := 150.0
const 최대_디딤 := 40
## 이 배수를 넘게 모자란 자리는 "아깝게" 가 아니라 원래 길이 아니다 — 건드리지 않는다.
const 아까움_배수 := 2.2
## 단차가 한계에 **딱 맞는** 자리도 고치기 위한 여유(px). 자세한 근거는 _아까운_자리 주석.
const 단차_안전여유 := 10.0

const 구조물_접두 := ["천장", "벽", "굴뚝벽", "받침", "가로막이", "뒷벽", "다락왼벽", "거실왼벽"]

const 전체스테이지 := [
	"res://scenes/스마트월드/스마트월드_1.tscn",
	"res://scenes/스마트월드/스마트월드_2.tscn",
	"res://scenes/스마트월드/스마트월드_3.tscn",
	"res://scenes/스마트월드/스마트월드_4.tscn",
	"res://scenes/스마트월드/스마트월드_5.tscn",
	"res://scenes/스마트월드/스마트월드_6.tscn",
	"res://scenes/스마트월드/스마트월드_7.tscn",
]

var _경로들: Array[String] = []
var _적용 := false
var _n := 0
var _루트: Node2D = null
var _재질 := ""

var _키 := 97.0
var _폭 := 44.0
var _점프높이 := 160.0
var _점프거리 := 240.0
var _시작위치 := Vector2.ZERO
var _치명낙하 := 520.0

var _선반: Array[Dictionary] = []
var _총_얇게 := 0
var _총_디딤 := 0


func _init() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a == "--적용":
			_적용 = true
		elif a == "--전부":
			for s in 전체스테이지:
				_경로들.append(s)
		elif not a.begins_with("--"):
			_경로들.append(a)
	if _경로들.is_empty():
		print("사용법: -s res://tools/지형_보정.gd -- <씬경로>|--전부 [--적용]")
		quit(2)
		return
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	var 주기 := 10
	var 안 := _n % 주기
	var 순번 := (_n - 1) / 주기
	if 순번 >= _경로들.size():
		print("\n════════════════════════════════════════════════")
		print(" 합계 — 얇게 %d · 디딤돌 %d%s"
			% [_총_얇게, _총_디딤, "" if _적용 else "   (조사만 함 — 적용하려면 --적용)"])
		print("════════════════════════════════════════════════")
		quit(0)
		return

	if 안 == 1:
		if _루트:
			_루트.queue_free()
			_루트 = null
		var 경로: String = _경로들[순번]
		if not ResourceLoader.exists(경로):
			push_error("씬이 없다: %s" % 경로)
			return
		_루트 = (load(경로) as PackedScene).instantiate() as Node2D
		root.add_child(_루트)
		_루트.set_physics_process(false)
	elif 안 == 5 and _루트:
		await _보정(_경로들[순번])


# ============================================================================
func _보정(경로: String) -> void:
	print("\n════════════════════════════════════════════════")
	print(" 지형 보정 — %s%s" % [경로.get_file(), "" if _적용 else "   [조사만]"])
	print("════════════════════════════════════════════════")
	_재질 = 공통.재질_준비("기본")
	_성능_계측()

	var 바뀜 := false
	if _A_끼임_얇게():
		바뀜 = true
	if await _B_디딤돌():
		바뀜 = true

	if not 바뀜:
		print("  · 고칠 것이 없다.")
		return
	if not _적용:
		print("  · `--적용` 을 붙이면 위 내용을 씬에 저장한다.")
		return
	_저장(경로)


func _성능_계측() -> void:
	var p := _루트.get_node_or_null("Player") as Node2D
	if p == null:
		return
	# ★[2026-08-25] `플레이어몸.재기()` 로 통일 (scripts/플레이어_몸.gd 주석 참고).
	#   못 재면 기본값으로 디딤돌을 놓게 되는데, 몸 크기가 틀리면 **닿지도 않는 자리에
	#   발판을 깔거나 통행을 막는다.** 그래서 조용히 넘어가지 않고 알린다.
	var 잰것 := 플레이어몸.재기(p)
	if 잰것["찾음"]:
		_폭 = (잰것["크기"] as Vector2).x
		_키 = (잰것["크기"] as Vector2).y
	else:
		print("  ⚠ 플레이어 콜리전을 못 찾음 → 기본 몸 크기로 보정한다(결과를 확인할 것)")
	# player.gd 의 export 에서 실제 점프 성능을 역산한다(하드코딩하지 않는다).
	var 타일: float = float(p.get("타일_크기")) if p.get("타일_크기") != null else 16.0
	var 높이칸: float = float(p.get("점프_높이_칸")) if p.get("점프_높이_칸") != null else 10.0
	var 거리칸: float = float(p.get("점프_거리_칸")) if p.get("점프_거리_칸") != null else 10.0
	_점프높이 = 타일 * 높이칸
	_점프거리 = 타일 * 거리칸
	_시작위치 = _루트.get("시작_위치") if _루트.get("시작_위치") != null else Vector2.ZERO
	if _루트.get("치명_낙하거리") != null:
		_치명낙하 = float(_루트.get("치명_낙하거리"))
	print("  플레이어 — 키 %.0f · 점프 높이 %.0f (오를 수 있는 단차 %.0f) · 거리 %.0f (건널 수 있는 폭 %.0f)"
		% [_키, _점프높이, _점프높이 * 여유_세로, _점프거리, _점프거리 * 여유_가로])


# ============================================================================
# [A] 끼임 얇게 — 선반 아래를 깎아 사람이 지나가게 한다
# ============================================================================
## ▣ 왜 "옮기기" 가 아니라 "얇게" 인가
##   선반을 위로 올리면 그 선반으로 **올라오는 단차**가 같이 커진다.
##   120px 짜리 계단을 17px 올리면 137px 이 되어 이번엔 못 올라간다 — 문제가 옮겨 갈 뿐이다.
##   아래를 깎으면 **밟는 면은 그대로**라 점프 계산이 하나도 안 흔들린다.
func _A_끼임_얇게() -> bool:
	print("\n── [A] 끼임 — 선반 아래 깎기 ─────────────────")
	var 공간 := _루트.get_world_2d().direct_space_state
	var 필요 := _키 + 머리_여유
	var 후보 := {}                       # 노드 → 깎아야 할 px

	for s in _표면_훑기():
		if _몸통_들어가나(공간, float(s["x"]), float(s["y"])):
			continue
		var 머리 := _머리높이(공간, float(s["x"]), float(s["y"]))
		var 막는 := _막는노드(공간, float(s["x"]), float(s["y"]), 머리)
		if 막는 == null or _구조물인가(막는.name):
			continue
		var 필요깎기 := 필요 - 머리
		if 필요깎기 <= 0.0:
			continue
		후보[막는] = maxf(float(후보.get(막는, 0.0)), 필요깎기)

	if 후보.is_empty():
		print("  ✔ 없음")
		return false

	var 한것 := 0
	for 노드 in 후보:
		var 깎기: float = float(후보[노드])
		var 결과 := _아래_깎기(노드, 깎기)
		if 결과 > 0.0:
			한것 += 1
			_총_얇게 += 1
			print("  ✔ %-16s 아래를 %.0fpx 깎았다 (두께 %.0f → %.0f)"
				% [노드.name, 결과, 결과 + _두께(노드), _두께(노드)])
		else:
			print("  ⚠ %-16s 는 깎을 수 없다 (덩어리 지형이거나 이미 최소 두께) — 손으로 봐야 한다"
				% 노드.name)
	return 한것 > 0


func _두께(노드: Node2D) -> float:
	var pa = 노드.call("get_point_array") if 노드.has_method("get_point_array") else null
	if pa == null:
		return 0.0
	var 점들: PackedVector2Array = pa.get_tessellated_points()
	if 점들.size() < 3:
		return 0.0
	var mn := 점들[0].y
	var mx := 점들[0].y
	for p in 점들:
		mn = minf(mn, p.y)
		mx = maxf(mx, p.y)
	return mx - mn


## 이 지형의 **아랫부분만** 잘라 올린다. 윗면은 건드리지 않는다.
## 반환: 실제로 깎은 px (못 깎으면 0)
func _아래_깎기(노드: Node2D, 깎기: float) -> float:
	if not 노드.has_method("get_point_array"):
		return 0.0
	var pa = 노드.call("get_point_array")
	if pa == null:
		return 0.0
	var 키들: PackedInt32Array = pa.get_all_point_keys()
	if 키들.size() < 3:
		return 0.0

	var mn := INF
	var mx := -INF
	var 좌 := INF
	var 우 := -INF
	for k in 키들:
		var p: Vector2 = pa.get_point_position(k)
		mn = minf(mn, p.y)
		mx = maxf(mx, p.y)
		좌 = minf(좌, p.x)
		우 = maxf(우, p.x)
	var 두께 := mx - mn
	var 폭 := 우 - 좌
	# ★덩어리 지형(바닥·천장 매스)은 건드리지 않는다. 얇고 긴 것만 선반으로 본다.
	#   덩어리를 깎으면 그 아래 공간이 통째로 사라져 다른 곳이 무너진다.
	if 두께 > 90.0 or 폭 < 두께 * 2.0:
		return 0.0
	var 새두께 := maxf(두께 - 깎기, 8.0)
	if 새두께 >= 두께 - 0.5:
		return 0.0                        # 이미 충분히 얇다

	var 한계 := mn + 새두께
	for k in 키들:
		var p: Vector2 = pa.get_point_position(k)
		if p.y > 한계:
			pa.set_point_position(k, Vector2(p.x, 한계))
	_콜리전_다시굽기(노드)
	return 두께 - 새두께


# ============================================================================
# [B] 디딤돌 — 아깝게 못 닿는 자리에 발판 하나를 끼운다
# ============================================================================
func _B_디딤돌() -> bool:
	print("\n── [B] 디딤돌 — 아깝게 못 닿는 자리 ───────────")
	# 멱등: 이전에 놓은 디딤돌을 먼저 전부 지운다 (지뢰밭 §5-2)
	var 지운수 := _디딤_지우기()
	if 지운수 > 0:
		print("  · 이전 디딤돌 %d 개를 지우고 다시 계산한다 (멱등)" % 지운수)

	var 놓은수 := 0
	var 첫보고 := true
	# 디딤돌 하나를 놓으면 도달 범위가 넓어져 **다음 막힌 곳이 드러난다.**
	# 그래서 한 번에 끝나지 않는다 — 더 못 놓을 때까지 반복한다.
	for 회차 in 12:
		_선반_다시읽기()
		var 도달 := _도달_BFS()
		if 첫보고:
			첫보고 = false
			var 닿음0 := 도달_인덱스(도달).size()
			print("  · 시작 선반 #%d · 지금 도달 %d / %d"
				% [_시작선반(), 닿음0, _선반.size()])
		var 후보 := _아까운_자리(도달)
		if 후보.is_empty() and 놓은수 == 0 and 회차 == 0:
			# 왜 후보가 없는지 알려 준다 — 조용히 "할 게 없다" 로 끝나면 도구를 못 믿는다
			print("  · 아깝게 못 닿는 이웃 없음 (단차 %.0f~%.0f · 가로 %.0f 이내만 본다)"
				% [_점프높이 * 여유_세로, _점프높이 * 여유_세로 * 아까움_배수,
				   _점프거리 * 여유_가로 * 1.6])
		if 후보.is_empty():
			break
		var 이번 := 0
		for c in 후보:
			if 놓은수 >= 최대_디딤:
				break
			var 개수 := _디딤_사다리(c, 놓은수 + 1)
			놓은수 += 개수
			이번 += 개수
		if 이번 == 0:
			break
		# 새로 놓은 디딤돌의 콜리전이 물리 서버에 등록되도록 한 프레임 기다린다
		await physics_frame

	if 놓은수 == 0:
		print("  ✔ 놓을 곳이 없다 (전부 닿거나, 닿기엔 너무 먼 곳뿐이다)")
		return 지운수 > 0
	_총_디딤 += 놓은수
	print("  ✔ 디딤돌 %d 개를 놓았다" % 놓은수)

	_선반_다시읽기()
	var 최종 := _도달_BFS()
	var 밟는 := 0
	for i in _선반.size():
		if not _구조물인가(String(_선반[i]["주인"])):
			밟는 += 1
	var 닿음 := 0
	for i in 도달_인덱스(최종):
		if not _구조물인가(String(_선반[i]["주인"])):
			닿음 += 1
	print("  → 도달 %d / %d (%.0f%%)" % [닿음, 밟는, 100.0 * float(닿음) / maxf(float(밟는), 1.0)])
	return true


func 도달_인덱스(도달: Array) -> Array:
	var r := []
	for i in 도달.size():
		if 도달[i]:
			r.append(i)
	return r


func _디딤_지우기() -> int:
	var 층 := _루트.get_node_or_null("지형")
	if 층 == null:
		return 0
	var 수 := 0
	for c in 층.get_children():
		if String(c.name).begins_with("디딤_"):
			층.remove_child(c)
			c.queue_free()
			수 += 1
	return 수


## 도달한 선반에서 **아깝게** 못 닿는 이웃을 찾는다.
## 반환: [{ "from":Dictionary, "to":Dictionary }]  (가까운 것부터)
func _아까운_자리(도달: Array) -> Array:
	var 오를수있음 := _점프높이 * 여유_세로
	var 건널수있음 := _점프거리 * 여유_가로
	var 결과 := []
	for i in _선반.size():
		if not 도달[i]:
			continue
		var a: Dictionary = _선반[i]
		for j in _선반.size():
			if 도달[j] or i == j:
				continue
			var b: Dictionary = _선반[j]
			if not _디딤_대상인가(b):
				continue
			var 가로 := _가로거리(a, b)
			var 세로 := float(a["y"]) - float(b["y"])       # +면 b 가 위
			if 세로 <= 0.0:
				continue                                     # 내려가는 건 늘 된다
			if 가로 > 건널수있음 * 1.6:
				continue
			# "아깝게" 의 정의: 한 번에는 못 가지만 **두 번에는 갈 수 있는** 거리
			#
			# ★★[2026-08-19] `<= 오를수있음` 이 아니라 `<= 오를수있음 − 안전여유` 다.
			#   스테이지 1·2 는 타일맵을 옮긴 것이라 단차가 **정확히 128px** 인 자리가 많다.
			#   점프 높이 160 × 0.80 = 128 이므로 한계도 정확히 128 —
			#   레벨검사가 `ⓘ 단차 128px (한계 128 · 0 초과)` 라고 찍는다.
			#   **딱 맞으면 부동소수점 한 끗으로 갈리고, 실제 플레이에서도 최고점에서 겨우 걸린다.**
			#   (인수인계 문서가 "이론상 가능하지만 실제로는 턱을 못 넘는 자리" 라고 부른 그것)
			#   → 여유 안쪽이면 "이미 갈 수 있다" 로 보고 넘어가되, **딱 맞는 자리는 고친다.**
			if 세로 <= 오를수있음 - 단차_안전여유:
				continue                                     # 넉넉히 갈 수 있는 자리다
			if 세로 > 오를수있음 * 아까움_배수:
				continue                                     # 원래 길이 아니다
			결과.append({"from": a, "to": b, "세로": 세로, "가로": 가로})
	결과.sort_custom(func(p, q): return float(p["세로"]) < float(q["세로"]))
	return 결과


## ★디딤돌을 놓아 줘도 되는 목표인가.
##
## ▣ 왜 거르나 — **자동 보정이 퍼즐을 지워 버릴 수 있다**
##   이 도구는 "지형만" 본다. 그래서 다음 두 가지를 구분하지 못한다.
##     · 진짜로 배치 실수라 못 가는 자리          → 디딤돌을 놓아야 한다
##     · **일부러** 못 가게 만든 자리             → 놓으면 퍼즐이 사라진다
##   후자를 이름과 레이어로 최대한 걸러낸다.
##
##   ① 유령 지형(레이어 8) : **칠해야 밟히는 발판**이다. 이 게임의 핵심 퍼즐이므로
##      옆에 디딤돌을 놓으면 "안 칠하고 지나가는 길" 이 생겨 규칙이 무너진다.
##   ② 통로·천장·뒷벽      : `연결통로.gd` 가 런타임에 만드는 구조물이다.
##      그 **윗면**은 밟으라고 만든 면이 아니라 통로를 덮은 암반의 등짝이다.
##   ③ 주인을 못 찾은 것(`?`·`오브젝트`) : 어떤 오브젝트인지 모르면 건드리지 않는다.
##      (물저장고·호퍼처럼 색 규칙이 걸린 장치일 수 있다)
func _디딤_대상인가(b: Dictionary) -> bool:
	var 이름 := String(b["주인"])
	if _구조물인가(이름):
		return false
	if bool(b.get("유령", false)):
		return false
	if 이름 == "?" or 이름 == "오브젝트" or 이름 == "지형":
		return false
	if 이름.ends_with("통로") or 이름.begins_with("천장") or 이름.begins_with("뒷벽"):
		return false
	return true


func _가로거리(a: Dictionary, b: Dictionary) -> float:
	var ax0: float = float(a["x0"])
	var ax1: float = float(a["x1"])
	var bx0: float = float(b["x0"])
	var bx1: float = float(b["x1"])
	if bx0 > ax1:
		return bx0 - ax1
	if ax0 > bx1:
		return ax0 - bx1
	return 0.0


## 두 선반 사이에 디딤돌을 **사다리로** 놓는다. 놓은 개수를 돌려준다.
##
## ▣ ⚠왜 하나로는 안 되나 (2026-08-19 에 처음엔 하나만 놓았다가 실패했다)
##   지형_11(y 624) → 지형_29(y 400) 은 224px 단차다. 한가운데에 하나 놓으면
##   112px + 112px 이 되는데, 오를 수 있는 단차는 **102px** 이라 여전히 못 간다.
##   → 필요한 계단 수 = ceil(단차 / 오를수있음). 224 / 102 → 3 칸이므로 **디딤돌 2 개**.
##
## ▣ 왜 대각선으로 놓나
##   같은 x 에 위아래로 쌓으면 아래 디딤돌에서 위 디딤돌로 **똑바로 뛰어올라야 하는데**,
##   그러면 위 디딤돌의 아랫면에 머리를 박는다. A 에서 B 로 가는 선을 따라
##   x 도 같이 옮기면 자연스러운 계단이 되고, 원래 동선과도 맞는다.
func _디딤_사다리(후보: Dictionary, 시작번호: int) -> int:
	var a: Dictionary = 후보["from"]
	var b: Dictionary = 후보["to"]
	var 오를수있음 := _점프높이 * 여유_세로
	var 세로: float = float(후보["세로"])
	var 칸 := int(ceil(세로 / maxf(오를수있음 - 단차_안전여유, 1.0)))
	if 칸 < 2:
		return 0                                   # 원래 갈 수 있는 자리다
	# ── 마주 보는 가장자리를 잡는다 ──
	var ax := 0.0
	var bx := 0.0
	if float(b["x0"]) > float(a["x1"]):            # b 가 오른쪽
		ax = float(a["x1"])
		bx = float(b["x0"])
	elif float(a["x0"]) > float(b["x1"]):          # b 가 왼쪽
		ax = float(a["x0"])
		bx = float(b["x1"])
	else:                                          # x 가 겹친다 → 겹치는 구간 한가운데
		var lo: float = maxf(float(a["x0"]), float(b["x0"]))
		var hi: float = minf(float(a["x1"]), float(b["x1"]))
		ax = (lo + hi) * 0.5
		bx = ax
	var ay: float = float(a["y"])
	var by: float = float(b["y"])

	var 놓음 := 0
	for i in range(1, 칸):
		var t := float(i) / float(칸)
		var x: float = lerpf(ax, bx, t)
		var y: float = lerpf(ay, by, t)
		if _디딤_놓기(x, y, 시작번호 + 놓음, a, b, 세로):
			놓음 += 1
	return 놓음


## 디딤돌 하나를 실제로 놓는다. 자리가 안 되면 false.
func _디딤_놓기(x: float, y: float, 번호: int, a: Dictionary, b: Dictionary, 세로: float) -> bool:
	var 공간 := _루트.get_world_2d().direct_space_state
	# ① 그 자리가 이미 지형 속이면 안 된다 (겹치면 콜리전이 꼬인다)
	if _속인가(공간, x, y + 4.0) or _속인가(공간, x, y - 4.0):
		return false
	# ② 디딤돌 위에 사람이 설 자리가 있어야 한다
	if not _몸통_들어가나(공간, x, y):
		return false
	# ③ 디딤돌 좌우 끝도 비어 있어야 한다 (기둥 옆구리에 박히는 것 방지)
	for dx in [-디딤_길이 * 0.4, 디딤_길이 * 0.4]:
		if _속인가(공간, x + float(dx), y + 4.0):
			return false
	# ④ ★디딤돌이 **그 아래 통행을 막으면** 안 된다.
	#   [2026-08-19] 이 검사를 빼먹었더니, 끼임을 고치라고 만든 도구가
	#   스테이지 1·4 에 **새 끼임을 2 곳 만들었다**(디딤_02·디딤_03).
	#   길을 하나 뚫으면서 다른 길을 막으면 아무것도 나아지지 않는다.
	var 아래 := PhysicsRayQueryParameters2D.create(
		Vector2(x, y + 디딤_두께 + 4.0), Vector2(x, y + 2000.0), 1 | 8)
	var 바닥 := 공간.intersect_ray(아래)
	if not 바닥.is_empty():
		var 여유: float = float(바닥["position"].y) - (y + 디딤_두께)
		if 여유 < _키 + 머리_여유:
			return false

	var 지형층 := _루트.get_node_or_null("지형")
	if 지형층 == null:
		return false
	var 이름 := "디딤_%02d" % 번호
	var 점들 := 공통.선반_점들(디딤_길이, 디딤_두께, 1.0)
	# `선반_점들` 은 원점이 왼쪽 끝이다 → 가운데로 옮겨 놓는다
	var 노드 := 공통.지형_노드(이름, Vector2(x - 디딤_길이 * 0.5, y + 디딤_두께 * 0.5),
		점들, _재질, true, false, 0, 16.0)
	지형층.add_child(노드)
	노드.owner = _루트
	공통.주인_지정(노드, _루트)
	print("     · %s  x %.0f  y %.0f   (%s %.0f → %s %.0f · 단차 %.0f)"
		% [이름, x, y, a["주인"], a["y"], b["주인"], b["y"], 세로])
	return true

# ============================================================================
# 선반 추출 · 도달 BFS (레벨검사.gd 와 같은 기준으로 계산한다)
# ============================================================================
func _선반_다시읽기() -> void:
	_선반.clear()
	var 표면 := _표면_훑기()
	표면.sort_custom(func(p, q):
		if not is_equal_approx(float(p["x"]), float(q["x"])):
			return float(p["x"]) < float(q["x"])
		return float(p["y"]) < float(q["y"]))
	for s in 표면:
		var 붙였나 := false
		for g in _선반:
			if g["주인"] != s["주인"]:
				continue
			if absf(float(g["y"]) - float(s["y"])) > 묶기_허용높이:
				continue
			if float(s["x"]) - float(g["x1"]) > 표본간격 * 1.5:
				continue
			g["x1"] = s["x"]
			g["y"] = s["y"]
			붙였나 = true
			break
		if not 붙였나:
			_선반.append({"x0": s["x"], "x1": s["x"], "y": s["y"],
				"주인": s["주인"], "유령": s["유령"]})


func _도달_BFS() -> Array:
	var 도달: Array = []
	도달.resize(_선반.size())
	도달.fill(false)
	var 시작 := _시작선반()
	if 시작 < 0:
		return 도달
	var 오를수있음 := _점프높이 * 여유_세로
	var 건널수있음 := _점프거리 * 여유_가로
	var 큐: Array[int] = [시작]
	도달[시작] = true
	while not 큐.is_empty():
		var i: int = 큐.pop_front()
		for j in _선반.size():
			if 도달[j] or i == j:
				continue
			var 가로 := _가로거리(_선반[i], _선반[j])
			var 세로 := float(_선반[i]["y"]) - float(_선반[j]["y"])
			if 가로 > 건널수있음:
				continue
			if 세로 > 0.0:
				if 세로 > 오를수있음:
					continue                        # 못 올라간다
			elif -세로 > _치명낙하:
				continue
				# ★[2026-08-19 중요] 내려가는 길도 **치명 낙하보다 깊으면 연결이 아니다.**
				#   처음엔 "내려가는 건 언제나 된다" 로 뒀다가, 높은 곳 하나에서
				#   아래 전부로 떨어질 수 있다고 계산해 **도달률 94%** 라는 거짓말을 냈다
				#   (레벨검사는 같은 씬을 11% 로 봤다). 판정 규칙이 게이트와 다르면
				#   도구는 "고쳤다" 고 하는데 게이트는 계속 빨간, 최악의 상태가 된다.
				#   → `레벨검사.gd _갈수있나()` 와 **한 글자도 다르지 않게** 맞춘다.
			도달[j] = true
			큐.append(j)
	return 도달


func _시작선반() -> int:
	var 최고 := -1
	var 최소 := INF
	for i in _선반.size():
		var g: Dictionary = _선반[i]
		# ⚠[2026-08-19] x 여유를 60 으로 조였다가 **시작 선반을 못 찾아** 도달 0 이 됐다.
		#   시작_위치(348, 746) 는 선반(x 158~318) 밖에 있다 — 통로에서 걸어 나오는 지점이라
		#   원래 지형 위가 아니다. 시작점은 "가장 가까운 발판" 으로 넉넉히 잡아야 한다.
		#   ★도구가 시작점을 못 찾으면 **아무 문제도 못 찾는다.** 조용히 통과해서 더 나쁘다.
		if _시작위치.x < float(g["x0"]) - 240.0 or _시작위치.x > float(g["x1"]) + 240.0:
			continue
		var d: float = float(g["y"]) - _시작위치.y
		if d < -40.0:
			continue                       # 시작 위치보다 위에 있는 발판은 후보가 아니다
		if d < 최소:
			최소 = d
			최고 = i
	return 최고


func _표면_훑기() -> Array:
	var 범위 := _범위()
	var 공간 := _루트.get_world_2d().direct_space_state
	var 결과: Array = []
	var x := 범위.position.x
	while x <= 범위.end.x:
		var y := 범위.position.y
		var 층 := 0
		while 층 < 최대층 and y < 범위.end.y:
			var q := PhysicsRayQueryParameters2D.create(
				Vector2(x, y), Vector2(x, 범위.end.y), 1 | 8)
			var r := 공간.intersect_ray(q)
			if r.is_empty():
				break
			var 맞은y: float = r["position"].y
			var 법선: Vector2 = r["normal"]
			var 주인 := _주인이름(r["collider"])
			# 레이어 8 = 무색 유령 지형(칠해야 밟힌다). 디딤돌 대상에서 빼려면 표시해 둬야 한다.
			var 유령 := int(r["collider"].collision_layer) == 8
			# ★★[2026-08-19] 여기 판정은 `레벨검사.gd _머리공간()` 과 **글자 그대로 같아야 한다.**
			#   처음엔 몸통 사각형으로 쟀더니 레벨검사보다 관대해서 선반을 더 많이 주웠고,
			#   그 결과 도구는 "도달 94%" 라고 하는데 게이트는 "11%" 라고 하는 최악의 상태가 됐다.
			#   보정 도구가 게이트와 다른 자를 쓰면, 고쳤다는 곳이 계속 빨갛게 남는다.
			#   → 자를 하나로 통일한다. (진단은 `지형_진단.gd` 가 몸통으로 따로 본다)
			if 주인 != "Player" and 법선.y < -0.55 and _머리공간(공간, x, 맞은y):
				결과.append({"x": x, "y": 맞은y, "주인": 주인, "유령": 유령})
			y = 맞은y + 4.0
			var 안전 := 0
			while 안전 < 900 and y < 범위.end.y and _속인가(공간, x, y):
				y += 8.0
				안전 += 1
			y += 2.0
			층 += 1
		x += 표본간격
	return 결과


func _범위() -> Rect2:
	var r: Variant = _루트.get("카메라_리밋")
	if r is Rect2 and (r as Rect2).size.length() > 1.0:
		return r as Rect2
	return Rect2(-2000, -3000, 30000, 6000)


## `레벨검사.gd _머리공간()` 과 **완전히 같은** 판정. 절대 따로 두지 말 것.
## 플레이어 키 + 8px 만큼 위가 비어 있어야 그 자리에 설 수 있다. 3 지점만 찍는다.
func _머리공간(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> bool:
	var 키 := _키 + 8.0
	for 비율 in [0.15, 0.55, 1.0]:
		if _속인가(공간, x, 표면y - 키 * float(비율)):
			return false
	return true


func _몸통_들어가나(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> bool:
	var 높이 := _키 - 발치_무시
	var 모양 := RectangleShape2D.new()
	모양.size = Vector2(maxf(_폭 - 4.0, 8.0), 높이)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = 모양
	q.transform = Transform2D(0.0, Vector2(x, 표면y - 발치_무시 - 높이 * 0.5))
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return 공간.intersect_shape(q, 1).is_empty()


func _머리높이(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float) -> float:
	var 최대 := _키 + 머리_여유 + 40.0
	var d := 6.0
	while d < 최대:
		if _속인가(공간, x, 표면y - d):
			return d
		d += 6.0
	return 최대


func _막는노드(공간: PhysicsDirectSpaceState2D, x: float, 표면y: float, 머리: float) -> Node2D:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, 표면y - 머리 - 2.0)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	var r := 공간.intersect_point(q, 1)
	if r.is_empty():
		return null
	var n := r[0].get("collider") as Node
	while n != null and n != _루트:
		if n.has_method("get_point_array"):
			return n as Node2D
		n = n.get_parent()
	return null


func _속인가(공간: PhysicsDirectSpaceState2D, x: float, y: float) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(x, y)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 | 8
	return not 공간.intersect_point(q, 1).is_empty()


func _주인이름(맞은것: Object) -> String:
	var n := 맞은것 as Node
	while n != null and n != _루트:
		if n is Node2D and not (n is CollisionPolygon2D) and not (n is CollisionShape2D) \
				and not (n is StaticBody2D):
			return n.name
		n = n.get_parent()
	return "?"


func _구조물인가(이름: String) -> bool:
	for p in 구조물_접두:
		if 이름.begins_with(String(p)):
			return true
	return false


## SS2D 는 점을 바꿔도 콜리전을 바로 다시 굽지 않는다. 명시적으로 시킨다.
func _콜리전_다시굽기(노드: Node2D) -> void:
	if 노드.has_method("set_as_dirty"):
		노드.call("set_as_dirty")
	if 노드.has_method("bake_collision"):
		노드.call("bake_collision")


func _저장(경로: String) -> void:
	var 팩 := PackedScene.new()
	var err := 팩.pack(_루트)
	if err != OK:
		push_error("  pack 실패: %s" % error_string(err))
		return
	err = ResourceSaver.save(팩, 경로)
	print("  저장 %s → %s" % [error_string(err), 경로])