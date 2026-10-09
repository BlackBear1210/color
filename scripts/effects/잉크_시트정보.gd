# [자동 생성] tools/생성_신규기믹_게임용.py — 손으로 고치지 말 것. 다시 돌리면 덮어쓴다.
# 이펙트 띠 시트(게임용/이펙트/*.png)의 칸 크기·기준점(발 자리). 시트는 게임 크기의 2배로 저장돼 있다.
extends RefCounted

const 시트 := {
	"약":{"경로": "res://assets/textures/props/신규기믹_v02/게임용/이펙트/점프_약.png", "프레임": 4, "칸": Vector2(120, 62), "기준": Vector2(60.0, 1.36)},
	"강":{"경로": "res://assets/textures/props/신규기믹_v02/게임용/이펙트/점프_강.png", "프레임": 4, "칸": Vector2(137, 95), "기준": Vector2(68.5, 0.68)},
	"점프대":{"경로": "res://assets/textures/props/신규기믹_v02/게임용/이펙트/점프대.png", "프레임": 6, "칸": Vector2(241, 144), "기준": Vector2(120.5, 49.12)},
	"솟구침":{"경로": "res://assets/textures/props/신규기믹_v02/게임용/이펙트/솟구침.png", "프레임": 6, "칸": Vector2(93, 236), "기준": Vector2(46.5, 1.5)},
	"그을음_소멸":{"경로": "res://assets/textures/props/신규기믹_v02/게임용/그을음/소멸.png", "프레임": 8, "칸": Vector2(312, 184), "기준": Vector2(156.0, 180.52)},
}
