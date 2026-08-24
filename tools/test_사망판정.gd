extends SceneTree
## ============================================================================
## [2026-08-07 신규] 스마트월드 사망 판정 전수 검사 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_사망판정.gd
##
## ▣ 왜 합성 씬을 쓰나 (스마트월드_1.tscn 을 안 열고)
##   실제 스테이지는 지형이 30 개가 넘어 "왜 죽었는지"를 특정할 수 없다.
##   여기서는 **지형 하나 · 플레이어 하나**만 놓고 좌표를 손으로 정해서
##   `_사망_판정()` 이 정확히 그 상황에서만 true 인지 본다.
##
## ▣ 검사하는 것 (도형님 지적: "색 사망이 잘 안 되고, 가까이 가면 죽거나 통과한다")
##   A. 밟은 지형이 반대색 → 죽는다
##   B. 밟은 지형이 같은 색 / 무색 / 회색 → 안 죽는다
##   C. **옆에 서 있기만 하면(안 밟음) 안 죽는다**   ← "가까이 가면 죽는다"
##   D. **반대색 벽에 몸이 닿으면 죽는다**            ← "통과한다"
##   E. 반대색 유체 접촉 → 죽는다 / 끄면 안 죽는다
##   F. 색 레이저 안에서 색이 다르면 죽는다
##   G. 잎발판·통과플랫폼도 발밑 판정에 잡힌다
## ============================================================================

const 지형공통_S := preload("res://tools/지형공통.gd")
const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 유체_S := preload("res://scripts/스마트월드/유체.gd")
const 레이저_S := preload("res://scripts/스마트월드/색레이저.gd")
const 잎_S := preload("res://scripts/스마트월드/식물_잎.gd")
const 통과_S := preload("res://scripts/스마트월드/통과플랫폼.gd")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool) -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름)
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 스마트월드 사망 판정 검사 ===")
	await _바닥판정_검사()
	await _벽접촉_검사()
	await _유체_검사()
	await _레이저_검사()

	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	quit(1 if 실패 > 0 else 0)


# ── 공통: 최소 스테이지 하나 만들기 ─────────────────────────────────────────
## 월드.gd 가 요구하는 최소 구성(Player + 페인트코어)을 갖춘 스테이지를 만든다.
func _스테이지_만들기() -> Node2D:
	var 월드 := Node2D.new()
	월드.set_script(월드_S)
	월드.name = "테스트월드"
	월드.set("치명_낙하거리", 0.0)        # 낙하 사망은 여기서 검사 대상이 아니다
	월드.set("낙사_y", 100000.0)
	월드.set("안전지점_자동저장", false)
	월드.set("시작_위치", Vector2(0, 0))

	var 코어 := Node.new()
	코어.set_script(코어_S)
	코어.name = "페인트코어"
	코어.add_to_group("페인트코어")
	월드.add_child(코어)

	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	월드.add_child(p)

	root.add_child(월드)
	# ★월드.gd 의 _physics_process 를 끈다.
	#   켜두면 스스로 사망을 감지해 **리스폰(시작_위치로 순간이동)** 해 버려서,
	#   우리가 세워둔 좌표가 다음 프레임에 사라진다 — 검사가 통째로 무의미해진다.
	#   (실제로 이 함정 때문에 벽 접촉 검사가 계속 실패했다)
	월드.set_physics_process(false)
	return 월드


## 지형 하나를 만들어 붙인다. 폭 x 높이 사각형(윗면이 y=0).
func _지형_붙이기(월드: Node2D, 위치: Vector2, 폭: float, 높이: float) -> Node:
	var 재질 := 지형공통_S.재질_준비("기본")
	var 점들 := PackedVector2Array([
		Vector2(-폭 * 0.5, 0), Vector2(폭 * 0.5, 0),
		Vector2(폭 * 0.5, 높이), Vector2(-폭 * 0.5, 높이),
	])
	var 지형 := 지형공통_S.지형_노드("검사지형", 위치, 점들, 재질, true, false, 1, 8.0)
	월드.add_child(지형)
	return 지형


## 플레이어를 좌표에 세우고 물리를 몇 프레임 돌린다.
func _세우기(월드: Node2D, 좌표: Vector2, 색: int) -> void:
	var p: Node2D = 월드.get_node("Player")
	p.set("velocity", Vector2.ZERO)
	p.global_position = 좌표
	p.set("player_color", 색)
	await physics_frame
	await physics_frame


## 월드.gd 의 비공개 판정을 직접 부른다 (리스폰이 좌표를 흐트러뜨리지 않게).
func _죽나(월드: Node2D) -> bool:
	return bool(월드.call("_사망_판정"))


# ── A~C. 발밑 지형 ──────────────────────────────────────────────────────────
func _바닥판정_검사() -> void:
	print("\n[1] 발밑 지형 색 판정")
	var 월드 := _스테이지_만들기()
	await physics_frame
	var 지형 := _지형_붙이기(월드, Vector2(0, 0), 600.0, 200.0)
	await physics_frame
	await physics_frame

	# 지형 윗면은 y=0. 콜리전은 두께 8 만큼 부풀려져 윗면이 y=-8 근처.
	var 발판위 := Vector2(0, -8)

	# ── 무색 ──
	await _세우기(월드, 발판위, ColorDefs.BLACK)
	확인("무색 지형 위 = 안 죽는다", not _죽나(월드))

	# ── 검정으로 칠한다 ──
	지형.call("명중", ColorDefs.BLACK, 지형.global_position)
	await physics_frame
	확인("(전제) 지형이 검정이 됐다", int(지형.call("현재색")) == ColorDefs.BLACK)

	await _세우기(월드, 발판위, ColorDefs.BLACK)
	확인("검정 지형 + 검정 플레이어 = 안 죽는다", not _죽나(월드))

	await _세우기(월드, 발판위, ColorDefs.WHITE)
	확인("★검정 지형 + 흰 플레이어 = 죽는다", _죽나(월드))

	# ── C. 옆에 서 있기만 하면 안 죽어야 한다 ──
	# 지형 오른쪽 끝(x=300) 바깥, 지형 윗면보다 아래(허공)에 서 있는 상태.
	await _세우기(월드, Vector2(420, -8), ColorDefs.WHITE)
	확인("★지형 밖(안 밟음) = 안 죽는다", not _죽나(월드))

	# ── 플레이어 덮어쓰기 / 장애물 상호작용 회색 ──
	확인("★검정 위에 흰 총알 = 회색 없이 흰색 덮어쓰기",
		지형.call("명중", ColorDefs.WHITE, 지형.global_position) == "painted")
	await physics_frame
	확인("덮어쓴 지형의 현재색은 흰색", int(지형.call("현재색")) == ColorDefs.WHITE)
	await _세우기(월드, 발판위, ColorDefs.WHITE)
	확인("흰색 지형 + 흰 플레이어 = 안 죽는다", not _죽나(월드))
	# 플레이어 총알이 아닌 장애물 상호작용으로 회색이 전달된 상황을 직접 모사한다.
	지형.call("_회색으로")
	확인("장애물 상호작용 회색은 여전히 중립", int(지형.call("현재색")) == ColorDefs.GRAY)
	확인("회색 지형 = 누구나 안 죽는다", not _죽나(월드))

	# ── G. 잎발판 / 통과플랫폼도 발밑 판정에 잡히나 ──
	var 잎 := StaticBody2D.new()
	잎.set_script(잎_S)
	잎.set("잎색", ColorDefs.WHITE)
	잎.position = Vector2(1200, 0)
	var 잎모양 := CollisionShape2D.new()
	var 잎사각 := RectangleShape2D.new()
	잎사각.size = Vector2(160, 20)
	잎모양.shape = 잎사각
	잎.add_child(잎모양)
	월드.add_child(잎)

	var 통과 := StaticBody2D.new()
	통과.set_script(통과_S)
	통과.position = Vector2(1600, 0)
	월드.add_child(통과)
	await physics_frame
	통과.call("명중", ColorDefs.BLACK, 통과.global_position)
	통과.call("명중", ColorDefs.BLACK, 통과.global_position)
	await physics_frame

	await _세우기(월드, Vector2(1200, -10), ColorDefs.BLACK)
	확인("흰 잎발판 + 검정 플레이어 = 죽는다", _죽나(월드))
	await _세우기(월드, Vector2(1600, -13), ColorDefs.WHITE)
	확인("검정 통과플랫폼 + 흰 플레이어 = 죽는다", _죽나(월드))

	월드.free()


# ── D. 반대색 벽에 몸이 닿았을 때 ───────────────────────────────────────────
func _벽접촉_검사() -> void:
	print("\n[2] 몸통 접촉 (벽·천장)")
	var 월드 := _스테이지_만들기()
	await physics_frame
	# 바닥(무색 · 안전) + 그 위에 흰색 벽
	var 바닥 := _지형_붙이기(월드, Vector2(0, 0), 800.0, 200.0)
	바닥.set("칠하기_허용", false)             # 영원히 무색 = 발밑은 언제나 안전

	var 재질 := 지형공통_S.재질_준비("기본")
	var 벽점 := PackedVector2Array([
		Vector2(-30, -300), Vector2(30, -300), Vector2(30, 0), Vector2(-30, 0),
	])
	var 벽 := 지형공통_S.지형_노드("벽", Vector2(200, -8), 벽점, 재질, true, false, 1, 8.0)
	월드.add_child(벽)
	await physics_frame
	await physics_frame
	벽.call("명중", ColorDefs.WHITE, 벽.global_position)
	await physics_frame
	확인("(전제) 벽이 흰색이 됐다", int(벽.call("현재색")) == ColorDefs.WHITE)

	# 벽 콜리전 왼쪽 면 = 원점 200 + 점 −30 = x 170.
	# 플레이어 폭은 실측 44px(반폭 22) → x=148 이면 오른쪽 어깨가 벽에 정확히 닿는다.
	await _세우기(월드, Vector2(148, 0), ColorDefs.BLACK)
	확인("★흰 벽에 몸이 닿은 검정 플레이어 = 죽는다", _죽나(월드))

	# 충분히 떨어져 있으면 안 죽는다
	await _세우기(월드, Vector2(-100, 0), ColorDefs.BLACK)
	확인("벽에서 떨어져 있으면 = 안 죽는다", not _죽나(월드))

	# 같은 색이면 벽에 붙어도 안전
	await _세우기(월드, Vector2(148, 0), ColorDefs.WHITE)
	확인("흰 벽 + 흰 플레이어 = 안 죽는다", not _죽나(월드))

	# ── 천장 ── 머리 위 반대색도 잡혀야 한다 (플레이어 키 실측 97px)
	var 천장점 := PackedVector2Array([
		Vector2(-120, -40), Vector2(120, -40), Vector2(120, 40), Vector2(-120, 40),
	])
	var 천장 := 지형공통_S.지형_노드("천장", Vector2(-600, -137), 천장점, 재질, true, false, 1, 8.0)
	월드.add_child(천장)
	await physics_frame
	await physics_frame
	천장.call("명중", ColorDefs.WHITE, 천장.global_position)
	await physics_frame
	# 천장 아랫면 = −137+40 = −97. 플레이어 키가 97 이라 발바닥 y=0 이면 정수리가 닿는다.
	await _세우기(월드, Vector2(-600, 0), ColorDefs.BLACK)
	확인("★흰 천장에 머리가 닿은 검정 플레이어 = 죽는다", _죽나(월드))

	월드.free()


# ── E. 유체 ─────────────────────────────────────────────────────────────────
func _유체_검사() -> void:
	print("\n[3] 유체 접촉")
	var 월드 := _스테이지_만들기()
	await physics_frame
	var 바닥 := _지형_붙이기(월드, Vector2(0, 0), 800.0, 200.0)
	바닥.set("칠하기_허용", false)

	var 물 := Area2D.new()
	물.set_script(유체_S)
	물.set("색", ColorDefs.WHITE)
	물.set("크기", Vector2(80, 300))
	물.position = Vector2(300, -300)
	월드.add_child(물)
	await physics_frame
	await physics_frame

	await _세우기(월드, Vector2(300, -8), ColorDefs.BLACK)
	확인("★흰 물 + 검정 플레이어 = 죽는다", _죽나(월드))
	await _세우기(월드, Vector2(300, -8), ColorDefs.WHITE)
	확인("흰 물 + 흰 플레이어 = 안 죽는다", not _죽나(월드))

	물.set("켜짐", false)
	await physics_frame
	await physics_frame
	await _세우기(월드, Vector2(300, -8), ColorDefs.BLACK)
	확인("꺼진 물 = 안 죽는다", not _죽나(월드))

	물.set("켜짐", true)
	물.set("색", ColorDefs.GRAY)
	await physics_frame
	await physics_frame
	await _세우기(월드, Vector2(300, -8), ColorDefs.BLACK)
	확인("회색 물 = 누구나 안 죽는다", not _죽나(월드))

	# 물에서 멀리 떨어지면 안 죽는다
	물.set("색", ColorDefs.WHITE)
	await physics_frame
	await _세우기(월드, Vector2(-200, -8), ColorDefs.BLACK)
	확인("물에서 떨어져 있으면 = 안 죽는다", not _죽나(월드))

	월드.free()


# ── F. 색 레이저 ────────────────────────────────────────────────────────────
func _레이저_검사() -> void:
	print("\n[4] 색 레이저")
	var 월드 := _스테이지_만들기()
	await physics_frame
	var 바닥 := _지형_붙이기(월드, Vector2(0, 0), 800.0, 200.0)
	바닥.set("칠하기_허용", false)

	var 빔 := Node2D.new()
	빔.set_script(레이저_S)
	빔.set("시작색", ColorDefs.BLACK)
	빔.set("주기", 0.0)                      # 색 고정 = 검사 중 안 바뀐다
	빔.set("각도", 90.0)                     # 아래로
	빔.set("길이", 400.0)
	빔.set("두께", 120.0)
	빔.position = Vector2(300, -400)
	월드.add_child(빔)
	await physics_frame
	await physics_frame

	await _세우기(월드, Vector2(300, -8), ColorDefs.WHITE)
	확인("★검정 빔 + 흰 플레이어 = 죽는다", _죽나(월드))
	await _세우기(월드, Vector2(300, -8), ColorDefs.BLACK)
	확인("검정 빔 + 검정 플레이어 = 안 죽는다", not _죽나(월드))
	await _세우기(월드, Vector2(-200, -8), ColorDefs.WHITE)
	확인("빔 밖 = 안 죽는다", not _죽나(월드))

	월드.free()
