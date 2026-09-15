extends SceneTree
## ============================================================================
## [2026-09-14 신규] 하수도 지지구조 장식 아트 생성 — 쇠사슬 반복 단위 · 체인 고정구 · 삼각 지지대
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/생성_하수도_지지구조_아트.gd
## 출력: assets/decorations/sewer_support_v01/*.png
##
## ▣ 왜 코드로 그리나
##   이 세션에는 이미지 생성 도구 권한이 없다(higgsfield 미인증). 참고 이미지를 잘라 쓰면 배경과 조명이
##   섞여 재사용이 안 된다. → 거리 함수(SDF)로 픽셀을 직접 칠한다. **기능 검증용 임시 아트**다.
##   원화 수준이 아니다. 정식 아트가 오면 같은 파일명·같은 크기·같은 원점으로 덮어쓰면 된다
##   (asset_notes.md 에 원점·반복 단위·알파 규칙을 적어 둔다).
##
## ▣ 규칙 (프롬프트 §9)
##   · 투명 배경 = 진짜 알파 0. 흰 테두리 없음. 강조색 없음(무채색만).
##   · 쇠사슬 단위는 세로로 이어 붙여도 고리가 이어지게 **위아래 감싸(wrap) 그린다.**
##   · 고리 구멍이 읽히게 앞고리(타원 링)와 옆고리(납작한 막대)를 번갈아 둔다.
## ============================================================================

const 출력폴더 := "res://assets/decorations/sewer_support_v01/"

## 어두운 하수도 철재. 하이라이트도 0.45 를 넘지 않게 — 흰 발판보다 튀면 안 된다.
const 금속_어둠 := Color(0.055, 0.058, 0.065, 1.0)
const 금속_기본 := Color(0.14, 0.145, 0.16, 1.0)
const 금속_밝음 := Color(0.34, 0.35, 0.37, 1.0)
const 테두리 := Color(0.03, 0.03, 0.035, 1.0)


func _init() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(출력폴더))
	_저장(_쇠사슬_단위(), "chain_repeat.png")
	_저장(_체인_고정구(), "chain_anchor.png")
	_저장(_삼각_지지대(), "bracket.png")
	print("=== 지지구조 아트 3 장 생성 완료 → %s ===" % 출력폴더)
	quit(0)


func _저장(img: Image, 이름: String) -> void:
	var 경로 := ProjectSettings.globalize_path(출력폴더 + 이름)
	var e := img.save_png(경로)
	print("   %-18s %dx%d  %s" % [이름, img.get_width(), img.get_height(), error_string(e)])


# ============================================================================
# 거리 함수 (양수 = 바깥)
# ============================================================================
static func _sd_타원링(p: Vector2, c: Vector2, r: Vector2, 두께: float) -> float:
	# 타원 거리의 근사: 정규화 반지름 방향 거리 × 작은 반지름. 24px 짜리 고리에는 충분하다.
	var q := (p - c) / r
	var d := (q.length() - 1.0) * minf(r.x, r.y)
	return absf(d) - 두께 * 0.5


static func _sd_둥근막대(p: Vector2, a: Vector2, b: Vector2, 반폭: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
	return (pa - ba * h).length() - 반폭


static func _sd_둥근사각(p: Vector2, 중심: Vector2, 반크기: Vector2, 둥글기: float) -> float:
	var q := (p - 중심).abs() - 반크기 + Vector2(둥글기, 둥글기)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 둥글기


static func _sd_원(p: Vector2, c: Vector2, r: float) -> float:
	return (p - c).length() - r


## 안쪽(d<0)은 1, 바깥은 0. 1px 폭으로 부드럽게.
static func _덮개(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)


## 금속 명암: 형태 안쪽에서 위(빛)쪽이 밝고 테두리 근처가 어둡다.
static func _금속색(d: float, 빛: float) -> Color:
	var 안쪽 := clampf(-d, 0.0, 3.0) / 3.0            # 테두리에서 3px 들어오면 1
	var 몸 := 금속_기본.lerp(금속_밝음, clampf(빛, 0.0, 1.0) * 0.8)
	return 테두리.lerp(몸, 안쪽)


static func _섞기(아래: Color, 위: Color, a: float) -> Color:
	var out_a := a + 아래.a * (1.0 - a)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	var rgb := (Color(위.r, 위.g, 위.b) * a + Color(아래.r, 아래.g, 아래.b) * 아래.a * (1.0 - a)) / out_a
	return Color(rgb.r, rgb.g, rgb.b, out_a)


# ============================================================================
# 1. 쇠사슬 반복 단위 24×48 — 앞고리(타원 링) + 옆고리(막대). 위아래로 감싸 그린다
# ============================================================================
func _쇠사슬_단위() -> Image:
	var W := 24
	var H := 48
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var 링중심 := Vector2(12.0, 13.0)
	var 링반지름 := Vector2(9.0, 12.5)
	var 링두께 := 5.0
	var 막대a := Vector2(12.0, 26.0)
	var 막대b := Vector2(12.0, 48.0)
	var 막대반폭 := 3.2
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var 픽셀 := Color(0, 0, 0, 0)
			# 옆고리(막대)를 먼저, 그 위에 앞고리. 단 링 아래쪽 교차부는 막대가 앞으로 오게 —
			# 그래야 "끼워진" 고리로 읽힌다.
			var 막대d := 1e9
			for 오프셋 in [-48.0, 0.0, 48.0]:
				막대d = minf(막대d, _sd_둥근막대(p, 막대a + Vector2(0, 오프셋), 막대b + Vector2(0, 오프셋), 막대반폭))
			var 링d := 1e9
			var 링y := 0.0
			for 오프셋 in [-48.0, 0.0, 48.0]:
				var c := 링중심 + Vector2(0, 오프셋)
				var d := _sd_타원링(p, c, 링반지름, 링두께)
				if d < 링d:
					링d = d
					링y = (p.y - (c.y - 링반지름.y)) / (링반지름.y * 2.0)   # 0 = 위, 1 = 아래
			var 막대a_ := _덮개(막대d)
			var 링a := _덮개(링d)
			var 막대색 := _금속색(막대d, 0.55 - 0.35 * fmod(p.y + 22.0, 48.0) / 48.0)
			var 링색 := _금속색(링d, 1.0 - 링y)              # 위가 밝고 아래가 어둡다
			# 교차 순서: 링 위쪽 절반(구멍 위)에서는 링이 앞, 아래쪽 절반에서는 막대가 앞
			if 링y < 0.5:
				픽셀 = _섞기(픽셀, 막대색, 막대a_)
				픽셀 = _섞기(픽셀, 링색, 링a)
			else:
				픽셀 = _섞기(픽셀, 링색, 링a)
				픽셀 = _섞기(픽셀, 막대색, 막대a_)
			img.set_pixel(x, y, 픽셀)
	return img


# ============================================================================
# 2. 체인 고정구 40×28 — 볼트 2 개 박힌 판 + 아래로 나온 고리. 원점 = 판 윗변 가운데(씬에서 맞춘다)
#    고리 중심 (20, 20) = 체인이 닿는 자리.
# ============================================================================
func _체인_고정구() -> Image:
	var W := 40
	var H := 28
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var 픽셀 := Color(0, 0, 0, 0)
			var 고리d := _sd_타원링(p, Vector2(20.0, 19.5), Vector2(7.5, 6.5), 4.0)
			픽셀 = _섞기(픽셀, _금속색(고리d, 1.0 - (p.y - 13.0) / 13.0), _덮개(고리d))
			var 판d := _sd_둥근사각(p, Vector2(20.0, 7.0), Vector2(19.0, 6.0), 2.5)
			픽셀 = _섞기(픽셀, _금속색(판d, 0.7 - 0.5 * (p.y / 14.0)), _덮개(판d))
			for bx in [8.0, 32.0]:
				var 볼트d := _sd_원(p, Vector2(bx, 7.0), 2.6)
				픽셀 = _섞기(픽셀, _금속색(볼트d, 1.0 if p.y < 7.0 else 0.2), _덮개(볼트d))
			img.set_pixel(x, y, 픽셀)
	return img


# ============================================================================
# 3. 삼각 지지대 96×96 — 왼쪽 벽 고정형. 원점 = 왼쪽 위(발판 밑면이 벽에 닿는 점).
#    벽판(왼쪽 세로) + 가로대(위) + 대각대 + 볼트 4 + 모서리 거싯. 오른쪽용은 씬에서 flip_h.
# ============================================================================
func _삼각_지지대() -> Image:
	var S := 96
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var 픽셀 := Color(0, 0, 0, 0)
			# 대각대 (뒤) — 벽판 아래에서 가로대 끝으로
			var 대각d := _sd_둥근막대(p, Vector2(11.0, 86.0), Vector2(86.0, 10.0), 5.0)
			픽셀 = _섞기(픽셀, _금속색(대각d, 0.5 + 0.4 * ((p.x - p.y) / 96.0)), _덮개(대각d))
			# 모서리 거싯 (삼각 판) — 벽판·가로대 사이를 메운다
			var 거싯d := maxf(maxf(_sd_둥근사각(p, Vector2(20.0, 20.0), Vector2(20.0, 20.0), 1.0), (p.x + p.y) - 44.0), -1e9)
			픽셀 = _섞기(픽셀, _금속색(거싯d, 0.35), _덮개(거싯d))
			# 가로대 (위) — 발판 밑면을 받친다. 오른끝은 살짝 둥글다
			var 가로d := _sd_둥근사각(p, Vector2(46.0, 6.5), Vector2(46.0, 6.5), 2.0)
			픽셀 = _섞기(픽셀, _금속색(가로d, 0.9 - 0.6 * (p.y / 13.0)), _덮개(가로d))
			# 벽판 (왼쪽 세로) — 뒤 벽에 볼트로 고정
			var 벽d := _sd_둥근사각(p, Vector2(7.0, 48.0), Vector2(7.0, 48.0), 2.0)
			픽셀 = _섞기(픽셀, _금속색(벽d, 0.75 - 0.5 * (p.x / 14.0)), _덮개(벽d))
			# 볼트 — 벽판 2 개 · 가로대 2 개
			for c in [Vector2(7.0, 20.0), Vector2(7.0, 78.0), Vector2(34.0, 6.5), Vector2(72.0, 6.5)]:
				var 볼트d := _sd_원(p, c, 2.8)
				픽셀 = _섞기(픽셀, _금속색(볼트d, 1.0 if (p.y < c.y and p.x < c.x + 1.0) else 0.15), _덮개(볼트d))
			img.set_pixel(x, y, 픽셀)
	return img
