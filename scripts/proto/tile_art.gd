extends RefCounted
## ============================================================================
## [2026-07-24 도형 · 신규] 디자이너 타일셋 카탈로그 (Tile Art Catalog)
## ----------------------------------------------------------------------------
## ▣ 왜 필요한가
##   디자이너가 `assets/tileset/` 에 올린 PNG 5장은 "32px 타일 아틀라스"가 아니라
##   **한 칸이 384×384 인 '덩어리(블록) 아트'** 다. 한 장 안에 흑 버전과 백 버전이
##   나란히 들어 있고, 가장자리가 유기적(풀·돌 부스러기·벽돌 테두리)으로 뜯겨 있다.
##   → 그래서 타일맵 셀로 쓰는 게 아니라 "플랫폼 한 덩어리 = 스프라이트 한 장"으로
##     쓰고, 크기 차이는 9슬라이스 셰이더가 흡수한다 (shaders/ink_spread.gdshader).
##
## ▣ 실측 결과 (2026-07-24, PIL 알파 바운딩박스로 확인)
##   | 파일       | 해상도    | 셀 배치            | 내용                                  |
##   |-----------|----------|-------------------|---------------------------------------|
##   | brick.png | 768×768  | 2×2 (384 격자)     | 상단행=평면 벽돌, 하단행=액자형 벽돌      |
##   | wood.png  | 768×768  | 2×2               | 좌열=액자형, 우열=평면 / 상행 흑, 하행 백 |
##   | rock.png  | 768×384  | 2×1               | 흑 / 백 (균열 무늬)                     |
##   | soil.png  | 768×384  | 2×1               | 흑 / 백 (흙 알갱이 가장자리)             |
##   | grass.png | 768×896  | 2×2 (우하단 비어있음) | 상행=풀 가장자리 흑/백, 좌하=두꺼운 흑    |
##   실제 그림은 각 셀 안에서 약 350×350 만 채우고 바깥 ~17px 는 투명 여백이다.
##   → CONTENT_PX(350) 기준으로 스프라이트 배율을 잡으면 콜리전 사각형과 그림이 맞는다.
##
## ▣ 아트를 교체하려면
##   같은 파일명·같은 셀 배치로 PNG 만 덮어쓰면 코드는 손댈 필요 없다.
##   배치가 달라지면 아래 CATALOG 의 Rect2 좌표만 고치면 전 스테이지에 자동 반영된다.
class_name TileArt

## 셀 한 칸(격자) 크기 — 디자이너 파일 공통
const CELL_PX: float = 384.0
## 셀 안에서 실제 그림이 차지하는 크기 (바깥은 투명 여백)
const CONTENT_PX: float = 350.0
## 게임의 논리 타일 크기(칸). 플랫폼 크기를 "몇 칸"으로 세는 기준.
const TILE: int = 32

## 재질 카탈로그.
##   sheet        : PNG 경로
##   sheet_size   : PNG 해상도 (UV 계산용)
##   black/white  : 그 재질의 흑/백 셀 위치 (픽셀 Rect)
##   border_px    : 9슬라이스에서 "유기적 가장자리"로 보존할 두께
##   tile_middle  : 9슬라이스에서 가운데를 반복(true)할지 늘릴(false)지.
##                  ⚠[2026-07-24 수정] 처음엔 돌·흙·풀을 false(늘리기)로 뒀는데,
##                  가로 1920px 짜리 바닥에서 무늬가 6배로 늘어나 뭉개졌다(스크린샷 확인).
##                  → **전 재질 true**. 원본 픽셀 비율에 가깝게 반복돼 항상 또렷하다.
##   한글이름     : 문서/에디터 표시용
const CATALOG := {
	"벽돌": {
		"sheet": "res://assets/tileset/brick.png",
		"sheet_size": Vector2(768.0, 768.0),
		"black": Rect2(0.0, 0.0, 384.0, 384.0),
		"white": Rect2(384.0, 0.0, 384.0, 384.0),
		"border_px": 46.0, "tile_middle": true,
	},
	"벽돌액자": {
		"sheet": "res://assets/tileset/brick.png",
		"sheet_size": Vector2(768.0, 768.0),
		"black": Rect2(0.0, 384.0, 384.0, 384.0),
		"white": Rect2(384.0, 384.0, 384.0, 384.0),
		"border_px": 60.0, "tile_middle": true,
	},
	"나무": {
		"sheet": "res://assets/tileset/wood.png",
		"sheet_size": Vector2(768.0, 768.0),
		"black": Rect2(384.0, 0.0, 384.0, 384.0),
		"white": Rect2(384.0, 384.0, 384.0, 384.0),
		"border_px": 44.0, "tile_middle": true,
	},
	"나무액자": {
		"sheet": "res://assets/tileset/wood.png",
		"sheet_size": Vector2(768.0, 768.0),
		"black": Rect2(0.0, 0.0, 384.0, 384.0),
		"white": Rect2(0.0, 384.0, 384.0, 384.0),
		"border_px": 58.0, "tile_middle": true,
	},
	"바위": {
		"sheet": "res://assets/tileset/rock.png",
		"sheet_size": Vector2(768.0, 384.0),
		"black": Rect2(0.0, 0.0, 384.0, 384.0),
		"white": Rect2(384.0, 0.0, 384.0, 384.0),
		"border_px": 52.0, "tile_middle": true,
	},
	"흙": {
		"sheet": "res://assets/tileset/soil.png",
		"sheet_size": Vector2(768.0, 384.0),
		"black": Rect2(0.0, 0.0, 384.0, 384.0),
		"white": Rect2(384.0, 0.0, 384.0, 384.0),
		"border_px": 50.0, "tile_middle": true,
	},
	"풀": {
		"sheet": "res://assets/tileset/grass.png",
		"sheet_size": Vector2(768.0, 896.0),
		"black": Rect2(0.0, 0.0, 384.0, 384.0),
		"white": Rect2(384.0, 0.0, 384.0, 384.0),
		"border_px": 54.0, "tile_middle": true,
	},
	"풀두꺼움": {
		"sheet": "res://assets/tileset/grass.png",
		"sheet_size": Vector2(768.0, 896.0),
		"black": Rect2(0.0, 384.0, 384.0, 384.0),
		"white": Rect2(384.0, 0.0, 384.0, 384.0),   # 백 두꺼움 셀이 없어 기본 백 셀 재사용
		"border_px": 54.0, "tile_middle": true,
	},
}

## 재질 이름 목록 (에디터 드롭다운 힌트용)
static func 재질_목록() -> PackedStringArray:
	var out := PackedStringArray()
	for k in CATALOG.keys():
		out.append(String(k))
	return out

## 재질 정보 조회. 없는 이름이면 "벽돌"로 폴백한다(씬이 깨지지 않게).
static func 정보(재질: String) -> Dictionary:
	if CATALOG.has(재질):
		return CATALOG[재질]
	return CATALOG["벽돌"]

## 픽셀 Rect → UV Rect (셰이더 uv_black / uv_white 유니폼용)
static func uv_rect(픽셀: Rect2, 시트크기: Vector2) -> Vector4:
	return Vector4(
		픽셀.position.x / 시트크기.x,
		픽셀.position.y / 시트크기.y,
		픽셀.size.x / 시트크기.x,
		픽셀.size.y / 시트크기.y
	)
