extends SceneTree
## ============================================================================
## [2026-09-27 신규] 타일셋 깨짐 진단 — "지형이 작아서 재질이 뭉개지지 않는가"
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/진단_타일셋_깨짐.gd -- <씬> [<씬> ...]
##
## ▣ 왜 만들었나 (도형님 지시 2026-09-27)
##   "지형의 크기는 안에 타일셋 이미지가 깨지지는 않는지 확실하게 확인해봐."
##
##   SS2D 는 지형 하나를 **채우기 메시 + 테두리 메시**로 그린다. 테두리는 지형 둘레를
##   따라 **일정한 두께의 띠**로 붙는다. 그래서 지형이 얇으면 이런 일이 생긴다:
##
##      두꺼운 지형            얇은 지형(문제)
##      ┌──────────┐          ┌──────────┐
##      │▒▒테두리▒▒│          │▒▒테두리▒▒│
##      │          │          │▒▒테두리▒▒│  ← 위아래 테두리가 만나서
##      │  채우기  │          └──────────┘     채우기가 사라진다
##      │          │                            = "타일셋이 깨진 것처럼" 보인다
##      │▒▒테두리▒▒│
##      └──────────┘
##
##   실제로 2026-09-25 캡처에서 발판(192 × 112)이 **검은 테두리 + 얇은 심지**로 보였다.
##   테두리 띠가 38 px 이라 112 − 38 × 2 = 36 px 만 채우기로 남았기 때문이다.
##
## ▣ 무엇을 재나 (전부 실측 — 추정 없음)
##   1. 지형의 월드 크기
##   2. 테두리 띠 두께 = 테두리 텍스처 **세로 px × texture_scale**
##   3. 남는 채우기 = 짧은 변 − 띠 × 2.  이게 짧은 변의 **35 % 미만이면 ✖**
##   4. 채우기 타일이 지형 안에 몇 번 들어가나. **1 회 미만이면 ⚠**(무늬가 잘려 단색으로 보인다)
##
## ▣ 아무것도 안 고친다. 재기만 한다.
## ============================================================================

const 기본대상 := [
	"res://scenes/집/스테이지_1_2층방.tscn",
	"res://scenes/집/스테이지_2_복도.tscn",
]

## 짧은 변에서 채우기가 이 비율 미만으로 남으면 "깨졌다"로 본다.
const 한계_채우기비율 := 0.35
## 채우기 타일이 지형 안에 이만큼도 안 들어가면 무늬가 잘려 단색으로 보인다.
const 한계_타일반복 := 1.0

var _대상: Array = []


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			_대상.append(a)
	if _대상.is_empty():
		_대상 = 기본대상.duplicate()

	var 나쁜 := 0
	for 경로: String in _대상:
		나쁜 += await _한판(경로)
	print("")
	print("════════ 재질이 깨지는 지형 합계: %d 개 ════════" % 나쁜)
	quit(0 if 나쁜 == 0 else 1)


func _한판(경로: String) -> int:
	var ps := load(경로) as PackedScene
	if ps == null:
		print("✗ 씬을 못 읽었다: %s" % 경로)
		return 1
	var 뿌리 := ps.instantiate()
	root.add_child(뿌리)
	current_scene = 뿌리
	for _i in 60:
		await process_frame

	print("")
	print("════════════════════════════════════════════════════════════════")
	print("  %s" % 경로.get_file())
	print("════════════════════════════════════════════════════════════════")
	print("%-26s %12s %7s %9s %8s %s" % ["지형", "월드 크기", "띠", "남는채움", "타일반복", "판정"])

	var 지형들: Array = []
	_모으기(뿌리, 지형들)
	var 나쁜 := 0

	for t in 지형들:
		var 크기 := _월드크기(t)
		if 크기 == Vector2.ZERO:
			continue
		var mat = t.get("shape_material")
		if mat == null:
			continue

		# ── 테두리 띠 두께 ────────────────────────────────────────────────
		# SS2D 는 테두리 텍스처를 **세로를 띠 두께로** 써서 둘레를 따라 붙인다.
		var 띠 := 0.0
		for 메타 in mat.get_all_edge_meta_materials():
			if 메타 == null or 메타.edge_material == null:
				continue
			var et: Texture2D = 메타.edge_material.get_texture(0)
			if et == null:
				continue
			var s := float(메타.edge_material.texture_scale)
			띠 = maxf(띠, float(et.get_height()) * s)

		# ── 채우기 타일 크기 ──────────────────────────────────────────────
		var 타일 := Vector2.ZERO
		if not mat.fill_textures.is_empty() and mat.fill_textures[0] != null:
			var ft: Texture2D = mat.fill_textures[0]
			var fs := float(mat.fill_texture_scale)
			타일 = Vector2(ft.get_width(), ft.get_height()) * fs

		var 짧은변 := minf(크기.x, 크기.y)
		var 남는 := 짧은변 - 띠 * 2.0
		var 비율 := 남는 / maxf(짧은변, 1.0)
		var 반복 := 0.0
		if 타일.x > 0.0 and 타일.y > 0.0:
			반복 = minf(크기.x / 타일.x, 크기.y / 타일.y)

		var 판정 := "✔"
		var 말 := ""
		if 비율 < 한계_채우기비율:
			판정 = "✖"
			말 = "테두리가 %.0f%% 를 먹는다" % ((1.0 - 비율) * 100.0)
			나쁜 += 1
		elif 반복 > 0.0 and 반복 < 한계_타일반복:
			판정 = "⚠"
			말 = "채움 타일이 %.2f 회밖에 안 들어간다(무늬가 잘린다)" % 반복

		if 판정 != "✔":
			print("%-26s %5.0f×%-6.0f %7.0f %8.0f%% %8.2f %s %s" % [
				String(t.name).substr(0, 26), 크기.x, 크기.y, 띠, 비율 * 100.0, 반복, 판정, 말])

	print("────────────────────────────────────────────────────────────────")
	print("지형 %d 개 중 재질이 깨지는 것 %d 개" % [지형들.size(), 나쁜])
	if 나쁜 == 0:
		print("  ✔ 모든 지형이 테두리 띠보다 충분히 두껍다")
	뿌리.queue_free()
	await process_frame
	return 나쁜


## SS2D 점 배열의 월드 크기(배율 반영).
func _월드크기(t: Node) -> Vector2:
	var pa = t.call("get_point_array")
	if pa == null:
		return Vector2.ZERO
	var pts: PackedVector2Array = pa.get_tessellated_points()
	if pts.is_empty():
		return Vector2.ZERO
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var 배율: Vector2 = t.global_scale if t.is_inside_tree() else t.scale
	return Vector2(absf(mx.x - mn.x) * absf(배율.x), absf(mx.y - mn.y) * absf(배율.y))


func _모으기(n: Node, 통: Array) -> void:
	if n.has_method("get_point_array") and n.has_method("전체_색칠_가능"):
		통.append(n)
	for c in n.get_children():
		_모으기(c, 통)
