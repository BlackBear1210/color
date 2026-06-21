# 누끼(배경 제거) 가이드 — 임의 이미지 → 지형 PNG

> Godot 4.6.3 색상반전 플랫포머 / 2026-06-22
> 목적: 핀터레스트 등에서 가져온 지형 이미지를 "흑/백 실루엣 + 투명배경" PNG 로 만들어
> `silhouette_from_image.gd → bake_architecture_tileset.gd` 파이프라인에 넣는다.

---

## 0. 먼저 — 누끼가 필요한지 판단

| 배경 | 누끼 도구 | 다음 단계 |
|---|---|---|
| **흰색/단색 배경** (예: 올려주신 돌·발판 시트들) | **불필요** | 바로 `원본이미지/` → `silhouette_from_image.gd`(colorkey 자동) |
| 이미 투명 PNG | 불필요 | `원본이미지/` → 도구(alpha 자동) |
| **사진처럼 복잡한 배경** | **필요** (Photopea/rembg) | 누끼 → `원본이미지/` → 도구(alpha) |

> ※ **Godot 엔진 자체에는 AI 누끼가 없다.** 복잡한 배경만 아래 외부 도구를 쓴다.
> ※ 이 PC에는 python/rembg/ImageMagick 미설치 → 복잡배경은 **Photopea(웹·무설치)** 가 가장 쉽다.

---

## 1. Photopea 단계별 (무료 웹, 설치 없음 — https://www.photopea.com)

1. **열기**: 사이트 접속 → `File ▸ Open` → 이미지 선택.
2. **배경 자동 제거 시도**: 상단 `Select ▸ Magic Cut`(또는 `Select ▸ Subject`).
   - 피사체가 자동 선택되면 → `Edit ▸ Cut`(배경 잘림) 또는 선택 반전(`Select ▸ Inverse`) 후 `Delete`.
3. **수동 보정(필요 시)**:
   - 좌측 도구 `Magic Wand`(자동 선택) 로 배경 클릭 → `Delete` (단색 배경에 빠름).
   - 가장자리가 지저분하면 `Lasso`/`Polygonal Lasso` 로 다듬어 `Delete`.
4. **투명 확인**: 캔버스 배경이 체크무늬면 투명 OK. (레이어의 배경 잠금 해제 필요할 수 있음: 레이어 더블클릭)
5. **내보내기**: `File ▸ Export as ▸ PNG` → 저장.
   - 여러 조각이 한 장에 있어도 OK — 우리 도구가 조각을 자동 분리한다.
6. 저장한 PNG 를 프로젝트 `scenes/지형파일셋/원본이미지/` 에 넣는다.

### 대안: rembg (로컬 자동, Python 필요)
```
pip install rembg[cli]
rembg i 입력.png 출력.png          # 한 장
rembg p 입력폴더 출력폴더           # 폴더 일괄
```
결과(투명 PNG)를 `원본이미지/` 에 넣으면 됨.

---

## 2. 그다음 — 실루엣 변환 & 굽기 (공통)

```bash
# 1) 임의 이미지를 흑/백 실루엣+투명 PNG 로 (조각 자동분리, 밝기로 흑/백 자동)
"<godot>" --headless --path "<proj>" -s res://tools/silhouette_from_image.gd
# 2) 새 PNG 임포트
"<godot>" --headless --path "<proj>" --import
# 3) Arch 씬으로 굽기(물리레이어 자동: _W→흰레이어, _B→검정레이어)
"<godot>" --headless --path "<proj>" -s res://tools/bake_architecture_tileset.gd
```
- `silhouette_from_image.gd` 출력: `실루엣/<이름>_01_B.png`, `_02_W.png` …
  - `_B` = 검정 지형(layer 2), `_W` = 흰 지형(layer 3). 밝기 임계는 도구 `lum_split`(기본 0.5).
- 색을 강제하려면 도구 상단 `DEFAULTS["color"]` 를 `"BLACK"`/`"WHITE"` 로, 또는 `ENTRIES` 로 파일별 지정.
- 결과 Arch 씬: `실루엣/<이름>_NN_X.tscn` (Sprite + 폴리 + DeathDetector + Entry/Exit). 맵에 드래그해 배치.

---

## 3. 팁
- 시트의 조각이 너무 잘게 갈라지면(돌부스러기) 도구 `MIN_PIECE_AREA`(기본 600)를 키운다.
- 회색 계열 돌은 자동 판정상 WHITE 로 가기 쉽다 → 검정으로 쓰려면 `color:"BLACK"` 강제.
- 곡선/디테일은 비주얼(Sprite)에 그대로 남고, 충돌은 알파 외곽선을 따라 자동 생성된다(발걸림 방지를 위해 simplify 값으로 정점 최소화).
