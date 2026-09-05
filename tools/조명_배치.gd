extends SceneTree
## ============================================================================
## [2026-09-05 신규] 스테이지 조명 배치 — **텍스트 편집 · 멱등**
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/조명_배치.gd            # 표의 씬 전부
##   godot --headless --path . -s res://tools/조명_배치.gd -- --조사   # 안 고치고 보기만
##
## ▣ 무엇을 하나
##   ① 씬의 CanvasModulate(`어둠`) 색을 표의 값으로 맞춘다.
##   ② 씬에 `조명` Node2D 를 만들고 그 밑에 `발광체` 노드를 표대로 놓는다.
##
## ▣ ★왜 씬을 instantiate → pack 하지 않고 **텍스트로** 고치나
##   이 프로젝트의 스테이지에는 SS2D 가 구워 둔 `_meshes` · 점 배열 · 인스턴스
##   오버라이드가 잔뜩 들어 있다. 씬을 통째로 다시 구우면 그 값들이 재직렬화되면서
##   에디터에서 손본 것이 사라질 위험이 있다(CLAUDE.md §4 · §6 이 그 사고 기록이다).
##   → **손댈 줄만 손댄다.** 지형은 한 바이트도 안 바뀐다.
##
## ▣ 멱등 (CLAUDE.md §5)
##   `조명` 노드와 그 자식 블록을 **먼저 전부 지우고** 표대로 다시 쓴다.
##   "있으면 더한다" 같은 누적이 없다. 손으로 옮긴 광원은 날아가므로
##   자리를 바꾸고 싶으면 **아래 배치표를 고칠 것.**
## ============================================================================

const 발광체_경로 := "res://scripts/스마트월드/발광체.gd"
const 담을_이름 := "조명"

## ── 배치표 ─────────────────────────────────────────────────────────────────
## 광원 한 줄: {이름, 자리, 반경, 밝기, 색, 깜빡임, 흔들림}
##   ★"왜 여기인가"를 한 줄로 적는다. 근거 없는 광원은 나중에 아무도 못 고친다.
const 배치표 := {
	"res://scenes/집/스테이지_1_2층방.tscn": {
		"어둠": Color(0.62, 0.63, 0.60),
		# ══════════════════════════════════════════════════════════════════════
		# ★[2026-09-05 STEP 6] 광원 자리를 **원화가 그려 둔 밝기**에 맞췄다.
		# ----------------------------------------------------------------------
		# `tools/측정_원화_광원자리.gd` 로 `assets/background/room.png` 를 격자로 잘라
		# 밝기를 재고 월드 좌표로 옮겼다. 실측 결과(y ≈ −1000 높이 기준):
		#
		#   월드 x    5149   4842   4534   4380   4227   3458   2997   2536   1153   845
        #   원화밝기  0.72   0.70   0.44   0.41   0.33   0.21   0.21   0.21   0.13   0.14
		#
		#   · 원화 전체 평균 0.137. 창문(0.70~0.74)이 **압도적인 단 하나의 광원**이다.
		#   · 방 가운데(x 2400~3500)의 0.21 은 광원이 아니라 벽의 **반사(ambient) 수준**이다.
		#   · 왼쪽 절반 평균은 0.087 — 원화가 "여기는 어둡다"고 그려 놓았다.
		#   · 왼쪽에서 유일하게 밝은 곳은 **문틀 기둥**(x 845~999, y −1295 · 0.144).
		#
		# → 그래서 광원은 **창문 계열 3 개 + 문 1 개**뿐이다. 방 한가운데에 근거 없는
		#   채움광을 두지 않는다(예전 `방_중앙_채움` 이 정확히 그것이었다 · §아래).
		# ══════════════════════════════════════════════════════════════════════
		"광원": [
			# ① 이 방의 유일한 실제 광원. 원화 최대 밝기(0.74)가 찍힌 자리에 세운다.
			#    지형에도 창틀(SS_WOOD_WINDOW_TOP_01 · 커튼 3개 · 창턱)이 x 5000~5450 에 있다.
			{"이름": "창문_주광", "자리": Vector2(4950, -1150), "반경": 1700.0,
				"밝기": 0.85, "색": Color(0.86, 0.9, 1.0), "깜빡임": 0.0, "흔들림": 0.05,
				# ★그림자를 드리우는 것은 이 주광 **하나뿐**이다.
				#   채움광까지 켜면 그림자 방향이 여럿 겹쳐 "빛의 방향"이 오히려 사라진다.
				"그림자": true},
			# ② 창빛이 창턱·바닥에 떨어지는 자리. 원화 (4534,−373)=0.39 · (4380,−373)=0.36.
			{"이름": "창문_바닥번짐", "자리": Vector2(4450, -330), "반경": 1150.0,
				"밝기": 0.62, "색": Color(0.84, 0.88, 1.0), "깜빡임": 0.0, "흔들림": 0.0},
			# ③ ★`방_중앙_채움` 을 대체하는 광원.
			#    원화의 밝기가 0.44 → 0.21 로 **꺾이는 구간**(x 4227~4534)에 세운다.
			#    방 가운데의 그라데이션이 "어디선가"가 아니라 **창문 쪽에서** 오게 만드는 것이 전부다.
			#    반경만 창문~중앙 거리(2400px)에 맞춰 늘렸다 — 세기가 아니라 **도달거리**를 준다.
			#    ⚠ 세기를 더 올리면 다시 근거 없는 채움광이 된다 → 0.7 을 넘기지 말 것.
			{"이름": "창문_방안번짐", "자리": Vector2(4050, -800), "반경": 2400.0,
				"밝기": 0.62, "색": Color(0.82, 0.86, 0.96), "깜빡임": 0.0, "흔들림": 0.0},
			# ④ 왼쪽에서 원화가 유일하게 밝은 곳 = **문틀 기둥**(x 845~999, y −1295 · 0.144).
			#    게임 구조로도 같은 자리에 입구 통로(300, −2050)가 있다 —
			#    "내가 들어온 문에서 새어 드는 빛"이라 화면과 설명이 맞는다.
			#    시작 지점(1128, −1888)과 문틀 밝은 띠(y −1295)를 한 pool 로 덮는다.
			{"이름": "문_새는빛", "자리": Vector2(820, -1550), "반경": 1900.0,
				"밝기": 1.75, "색": Color(0.8, 0.8, 0.82), "깜빡임": 0.1, "흔들림": 0.1},
		],
	},
	"res://scenes/집/스테이지_2_복도계단.tscn": {
		"어둠": Color(0.62, 0.63, 0.6),
		# ★이 씬은 **이미 조명 설계가 있다** — 반딧불 11 개 · 벽등 · 계단창빛 · 홀천장등
		#   · 등 4 개. 그래서 새 광원은 하나도 안 놓는다. 여기에 광원을 더하면
		#   기존 배치가 뜻하던 "어디가 밝은 방인가"가 무너진다.
		"광원": [],
		# 대신 세기만 조명 표준 쪽으로 끌어올린다. 예전 값(반경 360~560 · 밝기 0.55~0.72)은
		# CanvasModulate 0.72 + height 0 시절에 맞춘 것이라, 표준(height 128 · ADD)에서는
		# 등이 켜져 있는지도 모를 만큼 약하다. 실험실 기준(반경 700 · 밝기 1.6)의
		# **실내 등 버전**으로 잡았다 — 창문 주광보다는 작고 어둡다.
		"기존광원": {
			"오브젝트/등_복도_A": {"반경": 620.0, "밝기": 1.15},
			"오브젝트/등_복도_B": {"반경": 620.0, "밝기": 1.15},
			"오브젝트/등_계단참": {"반경": 660.0, "밝기": 1.05},
			"오브젝트/등_홀샹들리에": {"반경": 900.0, "밝기": 1.35},
		},
	},
}


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var 조사만 := OS.get_cmdline_user_args().has("--조사")
	var 실패 := 0
	for 경로: String in 배치표:
		var 절대 := ProjectSettings.globalize_path(경로)
		if not FileAccess.file_exists(절대):
			print("  ✗ 씬 없음: %s" % 경로)
			실패 += 1
			continue
		var 원문 := FileAccess.get_file_as_string(절대)
		var 설정: Dictionary = 배치표[경로]
		var 결과 := _고치기(원문, 설정)
		print("· %s" % 경로.get_file())
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
	print("조명 배치 %s (실패 %d)" % ["조사만" if 조사만 else "적용", 실패])
	quit(1 if 실패 > 0 else 0)


## 씬 텍스트 한 벌을 받아 고친 텍스트를 돌려준다. 파일 입출력은 여기서 안 한다
## (그래야 `--조사` 가 진짜로 아무것도 안 건드린다).
func _고치기(원문: String, 설정: Dictionary) -> Dictionary:
	var 기록: Array = []
	var 줄들 :=원문.split("\n")

	# ── ① 기존 `조명` 노드 블록 지우기 (멱등) ──
	var 남길: Array = []
	var 버리는중 := false
	for L: String in 줄들:
		if L.begins_with("["):
			# 새 블록이 시작될 때마다 "이 블록을 버릴까"를 다시 판단한다.
			버리는중 = L.begins_with("[node ") and (
				L.contains('name="%s"' % 담을_이름) and L.contains('parent="."')
				or L.contains('parent="%s"' % 담을_이름))
		if not 버리는중:
			남길.append(L)
	var 지운줄 := 줄들.size() - 남길.size()
	if 지운줄 > 0:
		기록.append("기존 조명 블록 %d줄 제거" % 지운줄)

	# ── ② CanvasModulate 색 ──
	if 설정.has("어둠"):
		var 안에 := false
		for i in 남길.size():
			var L: String = 남길[i]
			if L.begins_with("["):
				안에 = L.begins_with("[node ") and L.contains('type="CanvasModulate"')
				continue
			if 안에 and L.begins_with("color = Color("):
				var 새 := _색글(설정["어둠"])
				if L != 새:
					기록.append("어둠 %s → %s" % [L, 새])
					남길[i] = 새
				안에 = false

	# ── ②-2 기존 광원의 반경/밝기 손보기 ──
	#   ⚠ 절대값을 쓴다. "기존 값 × 배수" 같은 누적은 다시 돌릴 때마다 값이 커져서
	#     멱등이 아니게 된다(CLAUDE.md §5).
	for 길: String in 설정.get("기존광원", {}):
		var 값: Dictionary = 설정["기존광원"][길]
		var 이름 := 길.get_file()
		var 부모 := 길.get_base_dir()
		var 안 := false
		for i in 남길.size():
			var L: String = 남길[i]
			if L.begins_with("["):
				안 = L.begins_with("[node ") and L.contains('name="%s"' % 이름) \
					and L.contains('parent="%s"' % 부모)
				continue
			if not 안:
				continue
			for 키: String in 값:
				if L.begins_with('"%s" = ' % 키):
					var 새 := '"%s" = %s' % [키, _수(float(값[키]))]
					if L != 새:
						기록.append("%s %s → %s" % [이름, L, 새])
						남길[i] = 새

	# ── ③ 발광체 스크립트 ext_resource 확보 ──
	var 아이디 := ""
	for L: String in 남길:
		if L.begins_with("[ext_resource") and L.contains(발광체_경로):
			# ⚠ "id=" 로 찾으면 같은 줄의 "uid=" 가 먼저 걸린다. 앞 공백까지 포함해 찾는다.
			아이디 = _속성(L, " id")
			break
	if 아이디 == "":
		아이디 = "조명_발광체"
		# 마지막 ext_resource 줄 뒤에 끼워 넣는다 (sub_resource 보다 앞이어야 한다)
		var 끝 := -1
		for i in 남길.size():
			if String(남길[i]).begins_with("[ext_resource"):
				끝 = i
		var 새줄 := '[ext_resource type="Script" path="%s" id="%s"]' % [발광체_경로, 아이디]
		남길.insert(끝 + 1, 새줄)
		기록.append("발광체 ext_resource 추가 (id=%s)" % 아이디)
	else:
		기록.append("발광체 ext_resource 재사용 (id=%s)" % 아이디)

	# ── ④ 조명 노드 블록 붙이기 ──
	var 광원들: Array = 설정.get("광원", [])
	var 덩어리: Array = []
	if not 광원들.is_empty():
		덩어리.append("")
		덩어리.append('[node name="%s" type="Node2D" parent="."]' % 담을_이름)
		for 줄: Dictionary in 광원들:
			덩어리.append("")
			덩어리.append('[node name="%s" type="Node2D" parent="%s"]'
				% [String(줄["이름"]), 담을_이름])
			덩어리.append("position = " + _벡터글(줄["자리"]))
			덩어리.append('script = ExtResource("%s")' % 아이디)
			덩어리.append('"종류" = 1')            # 구슬 = 빛만 있는 광원
			덩어리.append('"빛색" = ' + _색값(줄["색"]))
			덩어리.append('"반경" = %s' % _수(줄["반경"]))
			덩어리.append('"밝기" = %s' % _수(줄["밝기"]))
			덩어리.append('"깜빡임" = %s' % _수(float(줄.get("깜빡임", 0.0))))
			덩어리.append('"크기_흔들림" = %s' % _수(float(줄.get("흔들림", 0.0))))
			덩어리.append('"알갱이_보이기" = false')   # 허공에 흰 알갱이가 뜨면 반딧불이가 된다
			if bool(줄.get("그림자", false)):
				덩어리.append('"그림자" = true')
	# 파일 끝의 빈 줄을 정리하고 붙인다.
	while not 남길.is_empty() and String(남길[-1]).strip_edges() == "":
		남길.remove_at(남길.size() - 1)
	남길.append_array(덩어리)
	남길.append("")
	기록.append("광원 %d개 배치" % 광원들.size())
	return {"글": "\n".join(남길), "기록": 기록}


func _색글(c: Color) -> String:
	return "color = " + _색값(c)


func _색값(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_수(c.r), _수(c.g), _수(c.b), _수(c.a)]


func _벡터글(v: Vector2) -> String:
	return "Vector2(%s, %s)" % [_수(v.x), _수(v.y)]


## tscn 은 실수를 "0.62" 처럼 짧게 쓴다. %f 를 그대로 쓰면 0.620000 이 되어
## 매번 diff 가 생겨 멱등이 아닌 것처럼 보인다.
func _수(v: float) -> String:
	var s := String.num(v, 6)
	if s.contains(".") :
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s += "0"
	return s


func _속성(줄: String, 키: String) -> String:
	var 찾 := '%s="' % 키
	var i := 줄.find(찾)
	if i < 0:
		return ""
	var j := 줄.find('"', i + 찾.length())
	return 줄.substr(i + 찾.length(), j - i - 찾.length())
