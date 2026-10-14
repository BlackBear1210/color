extends RefCounted
## ============================================================================
## [2026-10-14 Claude] 플레이어 찾기 — **한 곳에서만 정한다** (코드 정리 2 단계 ①)
## ----------------------------------------------------------------------------
## ▣ 왜 만들었나
##   플레이어를 찾는 코드가 22 개 파일 29 곳에 세 가지 모양으로 흩어져 있었다.
##     · get_tree().get_first_node_in_group("player")            (대부분)
##     · get_tree().get_nodes_in_group("player")                 (밟힘·겹침 검사)
##     · get_tree().current_scene.get_node_or_null("Player")     (쳅터1 거울·반사빛길·창문빛)
##   셋째 모양은 current_scene 이 비어 있으면(씬을 내리는 순간 · 시험 도구가 씬을 띄울 때) 매 프레임
##   null 오류를 낸다 — 10-14 프레임 측정에서 15 스테이지가 이 오류 1,342 번 때문에 "느리다" 고 잘못 재졌다.
##
## ▣ 셋이 같은 것을 찾는다는 근거
##   "player" 그룹에 들어가는 것은 player.gd `_ready` 의 add_to_group 하나뿐이고,
##   전경전환.gd 는 옛 스테이지를 트리에서 **뺀 뒤** 새 스테이지를 넣는다(보관한 씬도 트리 밖).
##   → 트리 안의 플레이어는 늘 하나이고, 그게 곧 현재 씬의 "Player" 다.
##
## ▣ 쓰는 법
##   var p := 플레이어찾기.찾기(self) as CharacterBody2D
##   for 몸 in 플레이어찾기.모두(self): ...
##   ⚠ 돌려주는 값은 옛 코드(get_first_node_in_group)와 똑같이 형 변환 없는 Node 다 —
##     필요한 형은 부르는 쪽에서 `as` 로 바꾼다(옛 코드의 변환을 그대로 두려고).
##   ⚠ 플레이어 그룹 이름을 바꾸면 player.gd 의 add_to_group 과 여기 `그룹` 을 같이 바꾼다.
## ============================================================================
class_name 플레이어찾기

const 그룹 := "player"


## 트리 안의 플레이어(없으면 null). 기준 = 아무 노드나(보통 self) — 트리를 얻으려고만 쓴다.
## 트리 밖 노드에서 부르면 옛 코드는 get_tree() 가 null 이라 오류로 멈췄다 → 여기서는 null 을 돌려준다.
static func 찾기(기준: Node) -> Node:
	if 기준 == null or not 기준.is_inside_tree():
		return null
	return 기준.get_tree().get_first_node_in_group(그룹)


## 트리 안의 플레이어 전부(보통 하나). 밟힘·겹침 검사처럼 "누구든 닿았나" 를 볼 때.
static func 모두(기준: Node) -> Array[Node]:
	if 기준 == null or not 기준.is_inside_tree():
		return []
	return 기준.get_tree().get_nodes_in_group(그룹)
