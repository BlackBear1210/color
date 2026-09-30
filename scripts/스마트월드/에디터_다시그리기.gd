## [2026-09-30 Claude] @tool 장치의 에디터 미리보기를 "값이 바뀐 프레임에만" 다시 그리게 하는 도우미.
##
## ★왜: _process 에서 매 프레임 queue_redraw() 하면 Godot 에디터가 쉬지 못하고 씬을 계속 다시 그린다.
##   2026-09-30 실측 — 가만히 있는 에디터(stage_2-5 열림)가 내장 GPU 3D 엔진을 41% 쓰고 있었고,
##   그 상태에서 F5 로 켠 게임은 GPU 를 나눠 써서 30ms(33FPS) 대로 떨어졌다(에디터가 쉬면 9~10ms).
##   셰이더의 TIME 도 같은 일을 한다 → 물 셰이더는 anim_time 유니폼으로 바꿨다(흰물_디자인.gd).
##
## 쓰는 법(에디터 분기 안에서):
##   var 서명 := 에디터_다시그리기.서명(self)
##   if 서명 != _에디터_서명: _에디터_서명 = 서명; queue_redraw()
extends RefCounted


## 인스펙터에 보이는 스크립트 변수 값 + 변환을 한 숫자로 묶는다. 값이 같으면 같은 숫자.
static func 서명(노드: Node) -> int:
	var 값들: Array = []
	if 노드 is Node2D:
		값들.append((노드 as Node2D).global_transform)
	for 속성 in 노드.get_property_list():
		var 쓰임: int = 속성["usage"]
		if 쓰임 & PROPERTY_USAGE_SCRIPT_VARIABLE and 쓰임 & PROPERTY_USAGE_EDITOR:
			값들.append(노드.get(속성["name"]))
	return hash(값들)
