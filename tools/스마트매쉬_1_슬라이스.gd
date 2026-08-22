extends SceneTree
## ============================================================================
## [2026-08-22 신규] 타일셋 → SmartShape 조각 슬라이서
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/스마트매쉬_1_슬라이스.gd
##
## ▣ 왜 만들었나 (도형님 지시)
##   "기존 타일셋을 스마트매쉬 타일셋으로 바꾸고 싶다. 작업자가 씬으로 불러오기만 하면
##    스테이지 플랫폼을 만들 수 있게 해달라."
##   SmartShape2D 는 **타일맵이 아니라** 테두리에 바르는 '엣지 스트립'과 내부를 채우는
##   '채움 텍스처'를 먹는다. 그래서 `assets/tileset/*.png`(미리보기 시트)를 그대로 못 쓰고
##   여기서 **조각으로 잘라내야** 한다. 이 도구가 그 첫 단계다.
##
## ▣ 원본 타일셋 레이아웃 (브릭구조.gd 와 동일한 4분면 규약)
##   시트 하나(예: brick.png)는 가로/세로 절반씩 4분면이다:
##     좌상 = 검정 '꽉찬'(솔리드) · 우상 = 흰색 솔리드
##     좌하 = 검정 '테두리 프레임' · 우하 = 흰색 프레임
##   ★우리는 **솔리드 분면(윗줄)** 만 쓴다. 이유:
##     프레임 분면은 NinePatch(9-슬라이스)용이라 모서리 장식이 있어 스트립으로 자르면
##     이음새가 튄다. 반면 솔리드 벽면은 연속 무늬라 스트립·채움 둘 다 자연스럽게 이어진다.
##
## ▣ 왜 흑/백을 둘 다 뽑나 — **페인트 셰이더 계약**
##   `지형.gd _짝_텍스처()` 는 `black_xxx.png` 를 보면 같은 폴더의 `white_xxx.png` 를 찾아
##   셰이더 `alt_tex` 에 물린다. 칠하면 검정↔흰색이 스왑된다. 그래서 파일 이름은 반드시
##   `black_`/`white_` 로 시작해야 하고, 둘이 **짝**으로 존재해야 칠이 작동한다.
##
## ▣ 산출물 (assets/textures/smartshape/)
##   타일셋마다 4장:  black_<slug>_fill.png / white_<slug>_fill.png
##                    black_<slug>_edge.png / white_<slug>_edge.png
##   fill = 내부 채움(128×128) · edge = 테두리 띠(128×24, 길이 방향으로 반복)
##
## ▣ 멱등: 같은 입력이면 같은 결과. 여러 번 돌려도 안전(항상 원본에서 다시 계산·덮어씀).
## ============================================================================

const 타일셋_폴더 := "res://assets/tileset/"
const 출력_폴더 := "res://assets/textures/smartshape/"

## 타일셋 slug(=영문 파일 이름) → 한글 이름표. 재질/템플릿 도구가 이 표를 공유한다.
const 타일셋들 := {
	"brick": "벽돌",
	"wood": "나무",
	"soil": "흙",
	"grass": "잔디",
	"rock": "바위",
}

## 잘라낼 조각 크기(px).
const 채움_크기 := Vector2i(128, 128)   ## 내부 채움 — 정사각 타일
const 테두리_폭 := 128                   ## 엣지 스트립 길이(반복 단위)
const 테두리_높이 := 24                  ## 엣지 스트립 두께


func _init() -> void:
	var 실패 := 0
	var 만든수 := 0
	for slug in 타일셋들.keys():
		var 결과 := _한_타일셋_자르기(slug)
		실패 += 결과[0]
		만든수 += 결과[1]
	print("\n[스마트매쉬_1_슬라이스] 완료 — PNG %d장 생성, 실패 %d건" % [만든수, 실패])
	quit(실패)


## 반환 [실패건수, 생성장수]
func _한_타일셋_자르기(slug: String) -> Array:
	var 경로 := "%s%s.png" % [타일셋_폴더, slug]
	var 절대 := ProjectSettings.globalize_path(경로)
	# Image.load_from_file 은 임포트(.import) 없이도 원본 PNG 를 바로 읽는다 →
	# 이 도구는 임포트 순서에 얽매이지 않는다.
	var 원본 := Image.load_from_file(절대)
	if 원본 == null:
		push_error("[%s] 원본을 못 읽음: %s" % [slug, 경로])
		return [1, 0]

	# 4분면 크기 — 시트 크기의 절반. (brick/wood/soil/rock=768×768 → 384, grass=768×896 → 384×448)
	var 분면 := Vector2i(원본.get_width() / 2, 원본.get_height() / 2)

	# 솔리드 분면 원점: 검정=좌상(0,0), 흰색=우상(분면.x,0). (윗줄 = 솔리드, 브릭구조.gd 규약)
	var 만든수 := 0
	var 실패 := 0
	for 색 in [["black", Vector2i(0, 0)], ["white", Vector2i(분면.x, 0)]]:
		var 접두: String = 색[0]
		var 원점: Vector2i = 색[1]
		# fill — 분면 정중앙에서 채움 정사각을 뜬다(가장자리 캡스톤 립을 피해 안쪽에서).
		var fill_원점 := 원점 + 분면 / 2 - 채움_크기 / 2
		실패 += _조각_저장(원본, fill_원점, 채움_크기, "%s_%s_fill" % [접두, slug])
		만든수 += 1
		# edge — 분면 중앙의 가로 띠. 솔리드 벽면이라 가로로 이어져 반복돼도 자연스럽다.
		var edge_크기 := Vector2i(테두리_폭, 테두리_높이)
		var edge_원점 := 원점 + Vector2i(분면.x / 2 - 테두리_폭 / 2, 분면.y / 2 - 테두리_높이 / 2)
		실패 += _조각_저장(원본, edge_원점, edge_크기, "%s_%s_edge" % [접두, slug])
		만든수 += 1
	print("  [%s→%s] 조각 %d장" % [slug, 타일셋들[slug], 만든수])
	return [실패, 만든수]


## 원본에서 사각 영역을 떠서 PNG 로 저장. 영역이 원본을 벗어나면 잘라 맞춘다.
func _조각_저장(원본: Image, 원점: Vector2i, 크기: Vector2i, 이름: String) -> int:
	var 안전영역 := Rect2i(원점, 크기).intersection(Rect2i(Vector2i.ZERO, 원본.get_size()))
	if 안전영역.size.x <= 0 or 안전영역.size.y <= 0:
		push_error("  '%s' 잘라낼 영역이 비었다(%s)" % [이름, str(Rect2i(원점, 크기))])
		return 1
	var 조각 := 원본.get_region(안전영역)
	var 출력 := ProjectSettings.globalize_path("%s%s.png" % [출력_폴더, 이름])
	var e := 조각.save_png(출력)
	if e != OK:
		push_error("  '%s' 저장 실패: %s" % [이름, error_string(e)])
		return 1
	return 0
