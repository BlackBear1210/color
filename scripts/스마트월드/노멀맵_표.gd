extends RefCounted
## ============================================================================
## [2026-09-05 신규] 지형 채우기 텍스처 → 노멀맵이 붙은 CanvasTexture 대응표
## ----------------------------------------------------------------------------
## ▣ 무엇을 하나
##   `지형.gd` 가 재질 사본을 만들 때, 채우기 텍스처를 여기서 한 번 물어본다.
##   표에 있으면 **같은 그림 + 노멀맵** 이 묶인 CanvasTexture 로 바꿔 끼운다.
##
## ▣ ★왜 재질 .tres 를 복사하지 않고 런타임에 바꾸나
##   재질(.tres)은 30 개가 넘고, 스테이지 7 개의 지형 인스턴스가 제각각 참조한다.
##   노멀맵 버전을 따로 만들면 **재질이 두 벌**이 되고, 앞으로 재질을 고칠 때마다
##   두 곳을 똑같이 고쳐야 한다(언젠가 반드시 한쪽만 고친다).
##   → 파일은 그대로 두고 **런타임 사본에서만** 텍스처를 바꾼다.
##     `지형.gd` 는 어차피 인스턴스마다 `shape_material.duplicate(true)` 를 하므로
##     원본 .tres 는 한 글자도 안 바뀐다.
##
## ▣ 흑↔백 짝이 안 깨지는 이유
##   바꿔 끼우는 CanvasTexture 는 **디스크의 .tres 파일**이라 `resource_path` 가 있고,
##   이름에 `black` / `white` 토큰이 남아 있다.
##   → `지형.gd` 의 `_짝_찾기()` 가 지금까지와 똑같이 반대색을 찾는다.
##     (인라인 서브리소스로 만들면 여기가 깨진다 — 2026-09-05 BRICK 작업 §5 참고)
##
## ▣ 표를 늘리려면
##   `tools/생성_지형_노멀맵.gd` 로 노멀맵 + .tres 를 굽고, 여기 한 줄을 더한다.
##   두 곳의 경로가 어긋나면 조용히 노멀맵이 안 붙으므로
##   `tools/진단_노멀맵_적용.gd` 로 실런타임에서 몇 개가 붙었는지 확인할 것.
## ============================================================================
class_name 지형노멀맵표

## diffuse 원본 경로 → 노멀맵이 붙은 CanvasTexture(.tres) 경로
const 표 := {
	# BRICK — texturemap.app 수제 노멀맵 (2026-09-05 실런타임 검증 통과)
	"res://assets/tileset/brick_black_seamless_341x307.png":
		"res://assets/textures/smartshape/brick_v2_opaque/노멀/벽돌_노멀_black.tres",
	"res://assets/tileset/brick_white_seamless_341x307.png":
		"res://assets/textures/smartshape/brick_v2_opaque/노멀/벽돌_노멀_white.tres",
	# WOOD
	"res://assets/textures/smartshape/wood_v2/black/fill_detail.png":
		"res://assets/textures/smartshape/wood_v2/노멀/나무_노멀_black.tres",
	"res://assets/textures/smartshape/wood_v2/white/fill_detail.png":
		"res://assets/textures/smartshape/wood_v2/노멀/나무_노멀_white.tres",
	# GRASS
	"res://assets/textures/smartshape/grass_v4/black/grass_fill_detail.png":
		"res://assets/textures/smartshape/grass_v4/노멀/잔디_노멀_black.tres",
	"res://assets/textures/smartshape/grass_v4/white/grass_fill_detail.png":
		"res://assets/textures/smartshape/grass_v4/노멀/잔디_노멀_white.tres",
	# IRON (METAL)
	"res://assets/textures/smartshape/metal_v1/black/fill_patchwork.png":
		"res://assets/textures/smartshape/metal_v1/노멀/철판_노멀_black.tres",
	"res://assets/textures/smartshape/metal_v1/white/fill_patchwork.png":
		"res://assets/textures/smartshape/metal_v1/노멀/철판_노멀_white.tres",
}

## 한 번 읽은 CanvasTexture 는 전 지형이 공유한다.
## (지형마다 load 하면 같은 파일을 수십 번 읽는다 — 리소스 캐시가 있긴 하지만
##  경로 문자열 조회까지 매번 하는 것은 낭비다)
static var _캐시: Dictionary = {}


## 노멀맵이 붙은 짝을 돌려준다. 없으면 **받은 것을 그대로** 돌려준다.
## → 표에 없는 재질은 지금까지와 100 % 똑같이 동작한다(회귀 없음).
static func 노멀_입히기(tex: Texture2D) -> Texture2D:
	if tex == null or tex is CanvasTexture:
		return tex
	var 경로 := tex.resource_path
	if 경로.is_empty() or not 표.has(경로):
		return tex
	if _캐시.has(경로):
		return _캐시[경로]
	var 새경로: String = 표[경로]
	if not ResourceLoader.exists(새경로):
		# 조용히 실패하면 "왜 노멀맵이 안 보이지"로 며칠을 쓴다 → 반드시 경고를 남긴다.
		push_warning("지형노멀맵표: %s 가 없다 (원본 그대로 씀)" % 새경로)
		_캐시[경로] = tex
		return tex
	var ct := load(새경로) as CanvasTexture
	if ct == null or ct.diffuse_texture == null:
		push_warning("지형노멀맵표: %s 를 CanvasTexture 로 못 읽었다" % 새경로)
		_캐시[경로] = tex
		return tex
	_캐시[경로] = ct
	return ct
