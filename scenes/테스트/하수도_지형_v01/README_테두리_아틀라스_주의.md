# 하수도 지형 v01 — 테두리(edge) 텍스처 주의 (2026-09-15 · Claude)

> 도형님 지시로 여기 남긴다. 옆면 아트를 정식으로 다시 만드는 날 **반드시 먼저 읽을 것.**

## 지금 상태

`sewer_masonry_v01/masonry_black.tres` · `masonry_white.tres` 의 top · side · corner 는
`trim_atlas.png`(1254×1254)의 **AtlasTexture 영역**으로 잡혀 있다.

그런데 SS2D 는 edge 를 그릴 때 `addons/rmsmartshape/shape_renderer.gd:61` 에서
`mesh.texture.get_rid()` 를 넘기고, **AtlasTexture 의 `get_rid()` 는 원본 아틀라스 전체의 RID** 다.
→ region 이 무시되고 1254px 벽 그림 전체가 8px 띠에 눌려 반복된다.
에디터를 확대하면 테두리에 보이는 "작은 벽돌 줄 + 세로 기둥 무늬" 가 그 아틀라스다.
**잘라 둔 옆면 조각은 화면에 한 번도 나온 적이 없다.** 흑·백 둘 다 같다.

줌 1.0 에서는 어두운 선으로만 보여 티가 안 나고 플레이(콜리전·색 판정)에도 영향이 없다.
그래서 **지금은 손대지 않는다.** 2-8(줌 1.35)·카메라 조이기·확대 캡처에서는 드러난다.

## 다시 만들 때 지킬 것

1. **edge 텍스처는 AtlasTexture 가 아니라 단독 PNG 파일**로. (top.png · side.png · corner.png 각각)
   기존 WALL 키트 `wall_sparse_bricks_v1/wall_sparse_bricks_edge_black.png` 가 이 방식이다.
2. 조각은 "돌 몰딩(선반 띠)" 이 아니라 **채움과 같은 벽돌의 좁은 옆면**이어야 한다.
   - 위 edge: 채움보다 조금 밝게(윗면) · 아래: 조금 어둡게 · 좌우: 중간 · 채움과 만나는 곳 1px 어두운 이음선
   - 두께 10~12px(줌 1.0 기준). edge 는 콜리전 안쪽(offset −1)에 그려지므로 밟는 면과 혼동되지 않는다. 그 이상 넓히지 말 것.
   - 모서리: 같은 톤의 작은 사각 + 대각 음영 한 장 (기둥·몰딩 이음쇠 아님)
3. 원본을 1254px 로 만들어 `texture_scale 0.16` 으로 줄이면 디테일이 뭉개진다.
   edge PNG 는 표시 크기의 2배(예 48×24) 로 만들고 scale 0.5 정도.
4. 고친 뒤 `tools/test_하수도_벽돌_색칠사망.gd`(132 검사)와 실행 화면 캡처(`tools/촬영_인게임.gd`)로 흑·백 둘 다 확인.

관련: 이 폴더의 `공중_*발판.tscn` 3종(+흰색), `색칠_사망_플레이시험.tscn`, `scripts/스마트월드/하수도_벽돌지형.gd`.
