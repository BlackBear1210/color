extends RefCounted
## ============================================================================
## [2026-07-24 도형 · 신규] 장애물 공통 도우미
## ----------------------------------------------------------------------------
## 이 게임은 지형이 **순흑 아니면 순백**이라, 장애물을 한 가지 색으로만 그리면
## 어느 한쪽 지형 위에서 반드시 안 보인다. (조준 궤적에서 이미 겪은 문제 — 16차)
## → 모든 장애물은 "어두운 외곽선 + 밝은 코어" 2겹으로 그린다.
##   흰 지형에서는 외곽선이, 검은 지형에서는 코어가 보여 **항상 실루엣이 산다.**
##
## 위험물(닿으면 죽는 것)은 여기에 더해 **붉은 경고색**을 살짝 섞는다.
## 흑백 게임에서 유일하게 허용하는 색 = "위험" 신호. (색맹 대비로 형태도 뾰족하게)
## ============================================================================
class_name 장애물공통

## 위험(사망) 계열 공통 색
const 위험_외곽: Color = Color(0.06, 0.02, 0.02, 1.0)
const 위험_코어: Color = Color(0.92, 0.90, 0.88, 1.0)
const 위험_경고: Color = Color(0.85, 0.20, 0.16, 1.0)

## 중립(안전) 구조물 공통 색
const 구조_외곽: Color = Color(0.05, 0.05, 0.05, 1.0)
const 구조_코어: Color = Color(0.88, 0.88, 0.88, 1.0)

## 외곽선을 두른 폴리곤 그리기.
## ci      : 그릴 CanvasItem (보통 self)
## 점들    : 폴리곤 정점
## 코어색  : 안쪽 색
## 외곽두께: 외곽선 두께(px)
static func 폴리곤_외곽선(ci: CanvasItem, 점들: PackedVector2Array,
		코어색: Color, 외곽색: Color, 외곽두께: float = 2.5) -> void:
	if 점들.size() < 3:
		return
	# 외곽선은 "닫힌 선"으로 두껍게 한 번 그린 뒤, 그 위에 코어 폴리곤을 얹는다.
	var 닫힌 := PackedVector2Array(점들)
	닫힌.append(점들[0])
	ci.draw_polyline(닫힌, 외곽색, 외곽두께 * 2.0, true)
	ci.draw_colored_polygon(점들, 코어색)
	ci.draw_polyline(닫힌, 외곽색, 외곽두께, true)

## 톱니(삼각형 띠) 점 목록 생성.
## 폭·높이·개수와 방향(0=위 1=아래 2=왼 3=오)을 주면 가시 모양 폴리곤들을 돌려준다.
static func 가시_폴리곤들(폭: float, 높이: float, 개수: int, 방향: int) -> Array:
	var 결과: Array = []
	var 한칸 := 폭 / float(maxi(개수, 1))
	for i in 개수:
		var x0 := -폭 * 0.5 + 한칸 * float(i)
		var x1 := x0 + 한칸
		var xm := (x0 + x1) * 0.5
		var p := PackedVector2Array()
		match 방향:
			0:  # 위를 향한 가시 (바닥에 박힘)
				p = PackedVector2Array([Vector2(x0, 높이 * 0.5), Vector2(xm, -높이 * 0.5), Vector2(x1, 높이 * 0.5)])
			1:  # 아래를 향한 가시 (천장에 박힘)
				p = PackedVector2Array([Vector2(x0, -높이 * 0.5), Vector2(xm, 높이 * 0.5), Vector2(x1, -높이 * 0.5)])
			2:  # 왼쪽을 향한 가시 (오른쪽 벽에 박힘)
				p = PackedVector2Array([Vector2(높이 * 0.5, x0), Vector2(-높이 * 0.5, xm), Vector2(높이 * 0.5, x1)])
			_:  # 오른쪽을 향한 가시 (왼쪽 벽에 박힘)
				p = PackedVector2Array([Vector2(-높이 * 0.5, x0), Vector2(높이 * 0.5, xm), Vector2(-높이 * 0.5, x1)])
		결과.append(p)
	return 결과
