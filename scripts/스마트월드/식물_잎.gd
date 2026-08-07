extends StaticBody2D
## [2026-08-01 신규] 식물 A 가 만들어내는 잎 발판.
## 잎은 **이미 색칠된 상태**라 다시 칠할 수 없고(총알은 그냥 튕김),
## 플레이어와 색이 다르면 밟았을 때 죽는다.
## 별도 파일로 뺀 이유: StaticBody2D 에 스크립트를 붙여야 `반대색인가()` 를
## 발밑 판정(월드.gd)이 물어볼 수 있는데, 인라인 클래스로는 set_script 를 못 쓴다.
class_name 식물잎

@export var 잎색: int = ColorDefs.BLACK:
	set(v):
		잎색 = v
		queue_redraw()

@export var 크기: Vector2 = Vector2(78, 18)


func _ready() -> void:
	add_to_group("잎발판")
	queue_redraw()


## 총알이 맞아도 아무 일도 없다 = 페인트는 회수된다(코어가 "blocked" 를 환급 처리).
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return 잎색


func 반대색인가(플레이어색: int) -> bool:
	if 잎색 == ColorDefs.GRAY:
		return false
	return 플레이어색 != 잎색


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var c := Color(0.10, 0.10, 0.11) if 잎색 == ColorDefs.BLACK else Color(0.93, 0.93, 0.90)
	# 잎사귀 — 양 끝이 뾰족한 타원
	var pts := PackedVector2Array()
	var n := 18
	for i in n:
		var t := TAU * float(i) / float(n)
		# cos 을 세제곱해서 양 끝을 뾰족하게 만든다 (그냥 타원이면 알약처럼 보인다)
		pts.append(Vector2(cos(t) * 크기.x * 0.5, sin(t) * 크기.y * 0.5 * (1.0 - 0.35 * absf(cos(t)))))
	draw_colored_polygon(pts, c)
	# 잎맥
	draw_line(Vector2(-크기.x * 0.45, 0), Vector2(크기.x * 0.45, 0),
		Color(0.5, 0.5, 0.5, 0.55), 1.5)
