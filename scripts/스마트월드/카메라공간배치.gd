extends RefCounted
## ============================================================================
## [2026-08-17 신규] 카메라 공간 자동 배치기 — 굴뚝/갱도를 **씬에서 찾아서** 놓는다
## ----------------------------------------------------------------------------
## ▣ 왜 좌표를 손으로 안 적나 (장식배치.gd 와 같은 이유)
##   굴뚝의 좌우 벽은 빌더가 만든 SS2D 지형이다. 벽을 1px 만 옮겨도
##   손으로 적어둔 카메라 공간 좌표는 어긋나고, **어긋난 걸 눈으로는 알 수 없다**
##   (카메라가 벽을 조금 넘겨 비추는 정도라 "왜 좀 이상하지?" 로만 느껴진다).
##   → 벽 지형의 **콜리전 실측값**에서 공간을 계산한다.
##
## ▣ 어떻게 찾나 — 이름 규약 하나만 쓴다
##   `<무엇>벽_좌` 와 `<무엇>벽_우` 가 짝으로 있으면 그 사이가 수직 통로다.
##   지금 씬에 있는 것: `굴뚝벽_좌` / `굴뚝벽_우` (build_스마트월드_1-2.gd 가 만든다).
##   새 스테이지에서도 이 규약만 지키면 카메라 연출이 **저절로 따라온다.**
##   (규약을 안 쓰고 싶으면 에디터에서 `카메라공간` 노드를 직접 놓으면 된다 —
##    이 배치기는 자동화일 뿐이고, 노드 자체는 손으로도 놓을 수 있다)
##
## ▣ 멱등 (2026-08-08 지뢰밭 §5-2)
##   `카메라공간_` 으로 시작하는 노드를 **먼저 다 지우고** 다시 만든다.
##   몇 번 돌려도 결과가 같다. "기존 값 + 여유" 같은 누적은 절대 하지 않는다.
##
## ▣ 왜 세로 범위를 벽 높이로 잡나
##   벽이 있는 곳이 곧 굴뚝이다. 벽보다 위/아래로 공간을 넓히면 굴뚝을 빠져나온
##   뒤에도 화면이 조여 있어 "나왔는데 안 펼쳐진다" 가 된다. 반대로 좁히면
##   굴뚝 끝에서 화면이 먼저 풀려 출구가 김빠진다.
##   → 벽의 세로 범위 그대로 + `리밋_여유` 로만 숨을 준다.
## ============================================================================
class_name 카메라공간배치

const 공간_S := preload("res://scripts/proto/카메라_공간.gd")

## 통로로 인정할 최소 안쪽 폭(px). 플레이어 폭 44 의 2 배 + 여유.
## 이보다 좁으면 사람이 못 지나가는 틈이라 카메라를 조일 이유가 없다.
const 최소_안쪽폭: float = 120.0
## 통로로 인정할 최소 높이(px). 점프 높이(160)의 2.5 배 — 이보다 낮으면
## "수직 통로" 가 아니라 그냥 문틀이다(들어가자마자 나오므로 연출이 깜빡인다).
const 최소_높이: float = 400.0
## 카메라 리밋의 세로 여유(px). 굴뚝 끝에서 화면이 벽에 막혀
## 플레이어가 화면 가장자리에 붙는 것을 막는다.
const 세로_여유: float = 260.0


## 한 스테이지에 카메라 공간을 전부 깐다.
##   루트 : 스테이지 루트 (월드.gd)
##   반환 : { "만든수": int, "이름들": Array[String] }
##
## ⚠ 부모를 `오브젝트` 층으로 두는 이유: `지형` 층에 넣으면
##   `tools/지형_다듬기.gd` 나 레벨검사기가 지형을 훑을 때 Area2D 가 섞여 들어온다.
##   판정 노드는 판정 노드끼리 모여 있어야 한다(연결통로도 오브젝트 층에 있다).
static func 깔기(루트: Node2D) -> Dictionary:
	var 결과 := {"만든수": 0, "이름들": []}
	if 루트 == null:
		return 결과

	var 지형층 := 루트.get_node_or_null("지형")
	if 지형층 == null:
		return 결과
	var 부모: Node = 루트.get_node_or_null("오브젝트")
	if 부모 == null:
		부모 = 루트

	# ── 멱등 ── 지난번에 만든 공간을 먼저 지운다
	_기존_지우기(루트)

	# ── 벽 짝 찾기 ──
	var 좌벽 := {}      # 접두사 → Rect2(월드)
	var 우벽 := {}
	for c in 지형층.get_children():
		var 이름 := String(c.name)
		var 범위 := _범위(c)
		if 범위.size == Vector2.ZERO:
			continue
		if 이름.ends_with("벽_좌"):
			좌벽[이름.trim_suffix("벽_좌")] = 범위
		elif 이름.ends_with("벽_우"):
			우벽[이름.trim_suffix("벽_우")] = 범위

	for 접두 in 좌벽:
		if not 우벽.has(접두):
			continue
		var L: Rect2 = 좌벽[접두]
		var R: Rect2 = 우벽[접두]
		# 안쪽 = 왼쪽 벽의 오른쪽 면 ~ 오른쪽 벽의 왼쪽 면
		var x0: float = L.end.x
		var x1: float = R.position.x
		# 세로는 두 벽이 **겹치는** 구간만 (한쪽만 있는 높이는 통로가 아니다)
		var y0: float = maxf(L.position.y, R.position.y)
		var y1: float = minf(L.end.y, R.end.y)
		if x1 - x0 < 최소_안쪽폭 or y1 - y0 < 최소_높이:
			push_warning("카메라공간배치: '%s' 는 통로 조건에 안 맞다 (폭 %.0f · 높이 %.0f)"
				% [접두, x1 - x0, y1 - y0])
			continue

		var 공간: 카메라공간 = 공간_S.new()
		공간.name = "카메라공간_%s" % 접두
		공간.position = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
		공간.크기 = Vector2(x1 - x0, y1 - y0)
		공간.리밋_여유 = Vector2(0, 세로_여유)
		# 나머지 값(줌_배수·시선·시간)은 노드 기본값을 쓴다.
		# ★기본값을 여기서 덮어쓰지 않는 이유: 튜닝은 **한 곳**에만 있어야 한다.
		#   숫자를 배치기와 노드 양쪽에 두면 나중에 어디를 고쳐야 하는지 알 수 없다.
		부모.add_child(공간)
		결과["만든수"] = int(결과["만든수"]) + 1
		(결과["이름들"] as Array).append(공간.name)
	return 결과


## `카메라공간_` 으로 시작하는 노드를 트리에서 전부 제거한다(멱등용).
static func _기존_지우기(루트: Node) -> void:
	var 대기: Array[Node] = [루트]
	var 지울것: Array[Node] = []
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			if String(c.name).begins_with("카메라공간_"):
				지울것.append(c)
			else:
				대기.append(c)
	for n in 지울것:
		n.get_parent().remove_child(n)
		n.queue_free()


## 이 노드(자손 포함) 콜리전을 감싸는 월드 사각형. 없으면 크기 0.
static func _범위(노드: Node) -> Rect2:
	var 결과 := Rect2()
	var 처음 := true
	var 대기: Array[Node] = [노드]
	while not 대기.is_empty():
		var n: Node = 대기.pop_back()
		for c in n.get_children():
			대기.append(c)
		if not (n is CollisionPolygon2D):
			continue
		var poly := (n as CollisionPolygon2D).polygon
		if poly.size() < 3:
			continue
		var mn := poly[0]
		var mx := poly[0]
		for p in poly:
			mn = mn.min(p)
			mx = mx.max(p)
		var g := (n as Node2D).global_transform
		var r := Rect2(g * mn, Vector2.ZERO).expand(g * mx)
		결과 = r if 처음 else 결과.merge(r)
		처음 = false
	return 결과
