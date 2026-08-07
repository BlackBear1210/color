# SmartShape2D 도입 가이드 (2026-08-01)

> 대상: Godot **4.6-beta2** / SmartShape2D **v3.3.1**
> 이 문서 하나만 보고 따라 하면 지형을 그릴 수 있게 쓴다.

---

## 0. 요약 — 이미 끝나 있는 것

아래는 **이미 설치·설정·검증까지 끝난 상태**다. 다시 할 필요 없다.

| 항목 | 위치 |
|---|---|
| 플러그인 본체 | `addons/rmsmartshape/` (v3.3.1) |
| 플러그인 활성화 | `project.godot` → `[editor_plugins] enabled=...` |
| 아트 PNG 21장 | `assets/textures/smartshape/*.png` |
| 지형 머티리얼 2종 | `assets/textures/smartshape/검정_지형.tres`, `흰색_지형.tres` |
| 확인용 데모 씬 | `scenes/smartshape_test/스마트셰이프_테스트.tscn` |
| 재생성 스크립트 | `tools/build_smartshape_demo.gd` |
| Aseprite 내보내기 | `tools/aseprite_export.ps1` |

**바로 보려면**: Godot 에디터에서 `scenes/smartshape_test/스마트셰이프_테스트.tscn` 열기.

---

## 1. 깃허브에서 뭘 받아야 하나

- 저장소: `SirRamEsq/SmartShape2D`
- **받은 것: `v3.3.1` 태그의 소스 zip** (2025-12-21 릴리스, 현재 최신)
- 주의할 점 2가지
  1. 저장소 안에 **Godot 3 전용 브랜치(`Godot3-latest`)** 가 따로 있다. 그걸 받으면 안 된다.
     우리가 받은 `master`/`v3.3.1` 계열이 Godot 4 용이다.
  2. zip 안에 `addons/`, `examples/`, `README.md`, `LICENSE` 가 들어 있는데
     **프로젝트에 넣어야 하는 건 `addons/rmsmartshape/` 폴더 하나뿐이다.**
     (`examples/` 는 안 넣었다 — 필요하면 나중에 따로 받아서 열어보면 된다)
- 용량 줄이려고 `addons/rmsmartshape/documentation/imgs/` (9MB, 마크다운 문서용 스크린샷)만
  지웠다. 코드가 참조하지 않는 폴더라 기능에는 영향 없다.

### 릴리스 대신 "Godot 애셋 라이브러리"에서 받아도 되나
된다. 에디터의 AssetLib 탭에서 "SmartShape2D" 검색 → 설치. 다만 애셋 라이브러리 쪽 버전이
릴리스보다 늦게 갱신되는 경우가 있어서, 이번엔 깃허브 릴리스(v3.3.1)를 직접 받았다.

---

## 2. Aseprite 파일 문제 — "고도에서 못 쓴다"가 맞다

### 결론
`.aseprite` (그리고 `.ase`) 는 Aseprite 전용 포맷이라 **Godot 이 임포트하지 못한다.**
프로젝트 폴더에 넣어도 파일시스템 독에 아예 안 뜨거나, 떠도 텍스처로 쓸 수 없다.
반드시 **PNG 로 내보내야(Export)** 한다.

> "파일이 Aseprite 로 연결되어 있다"(더블클릭하면 Aseprite 가 열린다)는 건
> 윈도우 파일 연결 문제이고, Godot 이 못 읽는 것과는 별개의 이야기다.
> **연결 프로그램을 바꾼다고 Godot 이 읽게 되지는 않는다.** 포맷 자체를 바꿔야 한다.

### 바꾸는 법 (이미 해둠 — 다시 할 때 쓰는 절차)

**방법 A. 스크립트 (권장, 21장을 한 번에)**

```bash
powershell -ExecutionPolicy Bypass -File tools\aseprite_export.ps1
```

그 다음 반드시:

```bash
Godot --headless --path . --import
```

**방법 B. Aseprite GUI 에서 수동**

1. 파일 열기 → `File > Export Sprite Sheet` 말고 **`File > Export`** 선택
   (한 장짜리 그림이라 스프라이트시트로 묶을 필요 없음)
2. 파일 형식 **PNG**, `Resize 100%`, **`Transparent color` 유지** (배경 투명해야 함)
3. 저장 위치는 `color/assets/textures/smartshape/`
4. 파일 이름은 **원본과 똑같이** (`black_fill.aseprite` → `black_fill.png`).
   이름이 달라지면 `tools/build_smartshape_demo.gd` 의 `색상표` 도 같이 고쳐야 한다.

> `.aseprite` 원본은 지우지 말고 계속 `타일셋도구들` 폴더에 두면 된다.
> PNG 는 "빌드 산출물"이고 원본은 Aseprite 쪽에 남겨두는 게 맞다.

### 내보낸 아트 목록 (실측)

| 역할 | 파일 | 크기 |
|---|---|---|
| 내부 채우기 | `black_fill` / `white_fill` | 64×64 (이어붙여도 티 안 남) |
| 윗면 테두리 | `black_center`, `black_center2` / `white_center`, `white_center2` | 32×9~12 |
| 아랫면 테두리 | `*_bottom_center` | 32×14~15 |
| 좌/우 테두리 | `*_left`, `*_left2`, `*_right`, `*_right2` | 13~16×10~13 |
| 모서리 | `*_bottom_left`, `*_bottom_right` | 16×13~15 |
| 사방 테두리 | `*_allaround` | 32×12 |

### ⚠ 크기 규격 — 변형(variant)을 쓸 때만 문제가 된다

SmartShape2D 가 테두리 텍스처를 쓰는 방식 (코드로 확인한 사실):

- **두께 = 텍스처 높이** (`shape.gd:1567` — 쿼드 폭에 `tex_size.y` 를 넘긴다)
- **쿼드는 도형 외곽선 위에 정중앙으로 걸친다** (`shape.gd:987` — `* 0.5`)
  → **텍스처 높이의 절반만 바깥으로 나온다.** `black_center`(12px)는 6px 만 삐져나온다.
  풀을 더 길게 보이고 싶으면 그림을 세로로 2배로 그리거나, 메타의 `Offset` 으로 밀어야 한다.
- **가로는 "몇 번 반복할지"만 정한다** (`edge.gd:216` — `round(변길이 / 텍스처폭)` 후 늘려 맞춤)
  → 폭이 13px 이든 16px 이든 **한 종류만 쓰면 어긋나지 않는다.**
- **`textures` 배열은 기본적으로 [0]번만 쓴다.** `randomize_texture` 를 켜거나 점마다
  텍스처 번호를 지정해야 나머지가 등장한다.

그래서 규격 문제는 **한 배열 안에 크기가 다른 그림을 섞을 때만** 터진다.

| 섞으면 생기는 일 | 이유 |
|---|---|
| 두께가 구간마다 튄다 | 높이가 다르면 쿼드 폭이 달라진다 (`center` 12px vs `center2` 9px) |
| 무늬가 늘어나거나 잘린다 | UV 길이 계산에 **첫 쿼드의 텍스처 폭 하나만** 쓴다 (`edge.gd:210-219`) |

**규격 제안** (같은 배열 안에서만 맞추면 된다. 위/아래/좌우끼리는 달라도 무방)

| 슬롯 | 권장 캔버스 | 지금 |
|---|---|---|
| 위 (`center`, `center2`) | **32×16** | 32×12, 32×9 |
| 아래 (`bottom_center`) | 32×16 | 32×14 |
| 좌/우 (`left`, `left2`, `right`, `right2`) | **16×16** | 16×11, 16×10, **13×11**, 16×10 |
| 모서리 (`bottom_left`, `bottom_right`) | 16×16 | 16×14, 16×13 |

그릴 때: 캔버스 **세로 한가운데가 지형의 외곽선**이다. 위 절반이 밖(배경 쪽), 아래 절반은
채우기 위에 겹쳐진다. 아래 절반은 채우기가 가려주므로 대충 채워도 되지만, **밖으로 나오는
건 위 절반뿐**이라는 걸 염두에 두고 그려야 한다.

> 변형을 안 쓸 거라면(=`center2`, `left2`, `right2` 를 배열에서 빼면) 지금 크기 그대로도
> 아무 문제 없다. 실제로 데모 씬은 [0]번만 쓰고 있어서 멀쩡히 나온다.

---

## 3. Godot 에서 실제로 쓰는 법

### 3-1. 새 지형 만들기 (에디터에서)

1. 씬에 노드 추가 → **`SS2D_Shape_Closed`** 검색해서 추가
   (닫힌 덩어리 = 땅/섬. 줄 하나짜리 지형이면 `SS2D_Shape_Open`)
2. 인스펙터 → **Materials > Shape Material** 슬롯에
   `assets/textures/smartshape/검정_지형.tres` 를 드래그
3. 화면 위쪽에 SS2D 툴바가 뜬다. **Alt + 좌클릭**으로 점 찍기
   - 점 3개를 찍으면 자동으로 도형이 닫힌다
   - **Shift + 드래그** = 베지어 곡선 (부드러운 언덕)
   - 점을 잡고 드래그 = 이동 / **Alt + 클릭(기존 점 위)** = 삭제
4. **Collision** — 툴바의 콜리전 생성 버튼을 누르면 `StaticBody2D > CollisionPolygon2D` 가
   자동으로 붙는다. 인스펙터 `Collision > Collision Size` 로 그림과 충돌면을 맞춘다 (기본 32)

### 3-2. ⚠ 픽셀아트라서 반드시 해야 하는 것

지형 노드 인스펙터 → **`CanvasItem > Texture > Filter` 를 `Nearest`** 로.
프로젝트 전역 기본값이 `Linear` 라서, 이걸 안 하면 16px 픽셀아트가 뿌옇게 뭉개진다.
(데모 씬의 두 지형에는 이미 걸어뒀다)

### 3-3. ❌ 안 해도 되는 것 — "Import 탭에서 Repeat 켜기"

제미나이가 알려준 절차 중 이 단계는 **Godot 3 시절 이야기**다.
Godot 4 텍스처 임포트에는 Repeat 항목이 없고, SS2D v3.3 부터는 테두리 텍스처를
플러그인이 강제로 반복 처리한다 (`addons/rmsmartshape/shape_renderer.gd:56`).
**아무것도 안 해도 반복된다.**

---

## 4. 머티리얼(.tres) 구조 — 뭘 만지면 뭐가 바뀌나

`검정_지형.tres` = `SS2D_Material_Shape` 한 덩어리. 안에 이렇게 들어 있다.

```
SS2D_Material_Shape (검정_지형.tres)
├─ fill_textures[0]        = black_fill.png        ← 내부 채우기
├─ fill_texture_scale      = 1.0                   ← 무늬 크기
└─ _edge_meta_materials[4]                          ← 테두리 4종
   ├─ [0] 아래  normal_range 225°~315°  ← bottom_center + 모서리 조각
   ├─ [1] 왼쪽  normal_range 135°~225°  ← left, left2
   ├─ [2] 오른쪽 normal_range 315°~45°  ← right, right2
   └─ [3] 위    normal_range  45°~135°  ← center, center2  (z_index 1 = 제일 위)
```

**노멀 각도 읽는 법**: `0°=오른쪽, 90°=위, 180°=왼쪽, 270°=아래` (화면 기준).
"이 변이 어느 쪽을 바라보고 있냐"로 어떤 테두리를 쓸지 고른다.
예를 들어 윗면 테두리를 더 넓게(비스듬한 경사에도) 쓰고 싶으면
`[3] 위` 의 `Normal Range > Distance` 를 90 → 120 으로 키우면 된다.

**흔한 조정**

| 하고 싶은 것 | 만질 곳 |
|---|---|
| 풀(윗면 테두리)을 더 두껍게 | 테두리 텍스처를 세로로 더 크게 그린다 (두께 = 텍스처 높이) |
| 테두리를 안쪽/바깥쪽으로 밀기 | `_edge_meta_materials[n] > Offset` |
| 내부 무늬가 너무 잘다 | `fill_texture_scale` 을 2.0 등으로 |
| 특정 방향 테두리 끄기 | 해당 메타의 `Render` 체크 해제 |
| 테두리가 도형 안쪽에 그려짐 | 지형 노드의 `Edges > Flip Edges` 켜기 |

---

## 5. 재생성 스크립트

머티리얼과 데모 씬은 코드로 만들었다 (인스펙터에서 배열 40번 클릭하는 걸 피하려고).

```bash
Godot --headless --path . -s res://tools/build_smartshape_demo.gd
```

⚠ **이걸 다시 돌리면 `검정_지형.tres` / `흰색_지형.tres` / 데모 씬이 덮어써진다.**
에디터에서 값을 튜닝했다면 다시 돌리지 말 것. 아트 파일이 늘어나서 슬롯을 새로 잡아야 할 때만
`tools/build_smartshape_demo.gd` 의 `색상표` 를 고치고 재실행한다.

---

## 6. 지금 프로젝트에 어떻게 얹을까 (판단 필요)

현재 지형 표현은 **3종류가 공존**한다. SmartShape2D 는 4번째가 된다.

| | 쓰는 곳 | 색칠 시스템 연동 |
|---|---|---|
| v2 TileMapLayer | zone_01/02, world_1 | `paint_system.gd` (타일 1칸 단위) |
| v3 PaintPlatform (384px 덩어리) | 스테이지 1~5 | `paint_platform.gd` (플랫폼 1개 단위) |
| TilePaintMap (24px 타일) | stage_1-1 | `tile_paint_map.gd` |
| **SS2D (신규)** | 데모 씬만 | **아직 없음** |

**핵심 쟁점**: 이 게임의 규칙은 "지형을 흑/백/회로 칠한다"인데,
SmartShape2D 지형은 **칠하는 단위가 정의되어 있지 않다.** 붙이려면 셋 중 하나를 골라야 한다.

1. **SS2D 도형 1개 = 칠하기 1단위** — 가장 단순. `paint_platform.gd` 와 같은 사고방식이라
   기존 v3 규칙(1플랫폼 = 4번 칠하기)을 그대로 재사용할 수 있다. 지형 하나를 통째로
   흑↔백 전환하려면 `shape_material` 을 `검정_지형.tres` ↔ `흰색_지형.tres` 로 교체하면 끝.
   → **추천.** 붙이는 비용이 제일 싸다.
2. **셰이더로 부분 칠하기** — `shaders/ink_spread.gdshader` 처럼 월드좌표 기반 마스크를
   `SS2D_Material_Edge.material` / `fill_mesh_material` 에 물린다. 예쁘지만 작업량 크다.
3. **안 붙인다** — 배경/장식 지형에만 SS2D 를 쓰고, 밟는 발판은 기존 방식 유지.
   가장 안전하고 오늘 당장 쓸 수 있다.

먼저 데모 씬을 눈으로 보고 "이 그림체가 우리 게임에 어울리나"부터 판단하는 걸 권한다.
어울린다면 1번으로 스테이지 하나만 시범 제작해 보는 게 다음 단계.

---

## 7. 참고 — 발견한 저장소 문제 (SmartShape2D 와 무관)

`OneDrive/Desktop/새 폴더 (2)/color/` 경로로 **프로젝트 전체 사본이 저장소 안에 커밋되어 있다.**
(커밋 `6d3f9cb` "요청하신거")

그리고 그 다음 커밋 `5e7a773` "수정1차 안성진" 의 수정 2건이 **전부 그 사본 쪽에만** 들어갔다.

- `scripts/proto/ammo_manager.gd` (스테이지별 탄약 오토로드) — **진짜 프로젝트에는 없음**
- `stage_lab.gd` 의 탄약 리셋, `_발밑_위험한가()` 로의 교체 — **진짜 프로젝트에는 없음**
  (타일맵 페인트 스테이지에서 반대색을 밟아도 안 죽는 버그 수정이 여기 들어 있다)

즉 **안성진님 수정은 지금 게임에 반영되어 있지 않다.** 사본을 지우고 수정분을 진짜 경로로
옮기는 작업이 필요하다. 누가 어느 쪽을 정본으로 볼지 팀에서 정하고 진행할 것.
