# 작업기록 2026-09-05 · Claude — BRICK 노멀맵 + Light2D 검증 (테스트 전용)

> 한 줄 요약: **SmartShape2D 지형에 CanvasTexture(디퓨즈+노멀맵)를 물리면 Light2D 가
> 실제로 표면 요철에 반응한다** — 애드온·기존 재질·기존 스테이지를 한 글자도 안 고치고 확인했다.
> 이번 작업물은 **전부 새 파일**이고, 기존 파일 수정은 **0건**이다.

---

## 0. 시작 전에 걸렸던 것 — 노멀맵 파일이 다른 텍스처의 것이었다

처음 지시는 `dirt_rammed_earth_temp_black_v3.png` + 그 노멀맵이었다. 조사해 보니:

| | 파일 | 크기 |
|---|---|---|
| Diffuse | `dirt_rammed_earth_temp_black_v3.png` | 1254 × 1254 |
| Normal | `dirt_rammed_earth_temp_black_v3_normal.png**.png**` | **341 × 307** |

- 크기가 다를 뿐 아니라 노멀맵 그림 자체가 **벽돌**이었다.
- 341×307 은 `assets/tileset/brick_black_seamless_341x307.png` 와 픽셀 단위로 일치한다.
- 그리고 `dirt_rammed_earth_temp_black_v3.png` 는 **프로젝트 어디에서도 안 쓰인다**
  (파일명·uid 양쪽으로 전체 검색 → 자기 `.import` 파일 하나뿐).

→ 도형님 승인을 받아 **A안(BRICK 한 쌍)** 으로 진행했다.
원본 `*_normal.png.png` 는 지우지 않고 그대로 두고, 이름만 바로잡아 **복사**했다.

---

## 1. 만든 파일 (전부 신규)

| 파일 | 무엇 |
|---|---|
| `assets/png/brick_black_seamless_341x307_normal.png` | 노멀맵. 원본에서 **바이트 단위로 동일**하게 복사(md5 확인) |
| `assets/textures/smartshape/brick_v2_opaque/노멀테스트/벽돌_노멀테스트_black.tres` | CanvasTexture (검정 디퓨즈 + 노멀) |
| `assets/textures/smartshape/brick_v2_opaque/노멀테스트/벽돌_노멀테스트_white.tres` | CanvasTexture (흰색 디퓨즈 + 노멀) — 흑↔백 짝용 |
| `assets/textures/smartshape/brick_v2_opaque/노멀테스트/지형_벽돌v2_opaque_노멀테스트_black_사방.tres` | SS2D 재질 **사본** |
| `scenes/집/테스트_2층방_노멀맵.tscn` | 스테이지_1_2층방 **사본** + 테스트 광원 |
| `scripts/테스트/노멀맵_빛_왕복.gd` | 좌우 왕복 PointLight2D |
| `tools/test_노멀맵_벽돌.gd` | 실런타임 3장 비교 촬영 |
| `tools/진단_노멀맵_무결성.gd` | 원본 보호 · 흑백짝 · 콜리전 동일성 |
| `tools/진단_노멀맵_최소테스트.gd` | SS2D 렌더 경로 최소 재현(아래 §2) |

**수정한 기존 파일: 없음.** `git status` 전체가 `??`(신규)뿐이다.

---

## 2. ★가장 중요한 발견 — SS2D 렌더 경로에서 CanvasTexture 가 통한다

재질·씬을 다 만든 뒤에 "사실 이 경로로는 안 된다"가 되면 전부 헛수고이므로,
**먼저 최소 재현**을 돌렸다 (`tools/진단_노멀맵_최소테스트.gd`).

SS2D 는 지형을 이렇게 그린다:

```
addons/rmsmartshape/shapes/shape.gd:897        mesh.texture = fill_textures[0]
addons/rmsmartshape/shape_renderer.gd:61       RenderingServer.canvas_item_add_mesh(
                                                  item, mesh_rid, xform, color, mesh.texture.get_rid())
```

같은 API 만 써서 세 패널을 나란히 그리고 빛을 좌/우로 옮겨 봤다.

| 패널 | 결과 |
|---|---|
| ① `Sprite2D` + CanvasTexture (엔진 표준) | 요철 반응 ✔ |
| ② `RenderingServer.canvas_item_add_mesh` + CanvasTexture (**SS2D 와 같은 경로**) | 요철 반응 ✔ |
| ③ 같은 경로 + 그냥 Texture2D (대조군) | 반응 없음(전체 밝기만 변함) |

★ ①과 ②의 측정값이 **모든 조건에서 소수점까지 완전히 같았다.**
→ CanvasTexture 의 RID 에 실린 노멀맵이 `canvas_item_add_mesh` 를 그대로 통과한다.
   **애드온을 고칠 필요가 전혀 없다.**

### 이때 알게 된 함정 두 가지 (다음 사람이 반드시 알아야 함)

1. **`PointLight2D.height` 가 0 이면 노멀맵이 사실상 안 보인다.**
   Godot 2D 라이트는 height 0 을 "광원이 표면과 같은 평면에 있다"로 계산해서,
   화면 밖(+Z)을 향하는 노멀이 빛을 거의 못 받는다. 같은 장면 평균 밝기가
   `height 0 → 0.033 / 32 → 0.047 / 128 → 0.079 / 400 → 0.105` 로 올라갔다.
   → 테스트 광원 기본값을 **128** 로 뒀다.
2. **RenderingServer 에 넘긴 `ArrayMesh` 는 참조를 붙들고 있어야 한다.**
   지역 변수로 두면 함수가 끝나며 Ref 가 풀려 RID 가 죽고
   `Parameter "mesh" is null` 만 뜨면서 아무것도 안 그려진다.
   (SS2D 가 `_meshes` 배열을 들고 있는 이유가 이것이다)

---

## 3. 최종 리소스 구조

```
scenes/집/테스트_2층방_노멀맵.tscn        (스테이지_1_2층방 사본)
 └─ 지형/…_BRICK_01  ×8  (SS2D_Shape)
     └─ shape_material
         → assets/textures/smartshape/brick_v2_opaque/노멀테스트/
              지형_벽돌v2_opaque_노멀테스트_black_사방.tres   (SS2D_Material_Shape)
            ├─ fill_textures[0]
            │   └─ 벽돌_노멀테스트_black.tres  (CanvasTexture)
            │       ├─ diffuse_texture → assets/tileset/brick_black_seamless_341x307.png
            │       └─ normal_texture  → assets/png/brick_black_seamless_341x307_normal.png
            ├─ _edge_meta_materials[0] → edge_top_thin.png      (원본과 동일)
            ├─ normal_range distance 360 · offset −1.0          (원본과 동일)
            └─ fill_texture_z_index −1                          (원본과 동일)
```

### ⚠ CanvasTexture 를 **별도 .tres 파일**로 만든 이유
`scripts/스마트월드/지형.gd` 의 `_짝_찾기()` 는 텍스처의 `resource_path` 파일명에서
`black ↔ white` 토큰을 바꿔 흰색 짝을 찾는다.
씬/재질 안에 **인라인 서브리소스**로 넣으면 `resource_path` 가 비어 짝 탐색이 실패하고,
페인트 셰이더가 밝기 반전 폴백(`alt_invert`)으로 떨어져 **칠하기 표현이 달라진다.**
→ 파일로 저장하고 이름에 토큰을 남겨 기존 규칙을 그대로 태웠다.
**런타임 확인 결과 8개 지형 전부 짝 찾기 성공, 폴백 0.**

### 일부러 지정하지 않은 것
CanvasTexture 의 `texture_filter` / `texture_repeat` 는 **기본값(부모 따름)** 으로 뒀다.
SS2D 렌더러가 캔버스 아이템에 `CANVAS_ITEM_TEXTURE_REPEAT_ENABLED` 를 걸어 주므로
그대로 물려받는다. 여기서 값을 박으면 지형 텍스처 반복이 깨진다.

---

## 4. 테스트 씬이 원본과 다른 점 (딱 4가지)

`diff 스테이지_1_2층방.tscn 테스트_2층방_노멀맵.tscn` 전체 결과:

1. 씬 `uid` 제거 (원본과 겹치면 안 되므로 Godot 이 새로 발급)
2. 벽돌 재질 `ext_resource` 를 테스트 재질로 교체 (id 는 그대로 → 벽돌 지형 8개가 한 번에 바뀜)
3. `어둠`(CanvasModulate) 0.72 → **0.30** (밝으면 라이트 반응이 안 보인다 · 테스트 씬에서만)
4. `노멀맵_테스트빛`(PointLight2D) 노드 + 그 텍스처 sub_resource 추가

지형 점 · Edge · Corner · Collision · 레이아웃 · 다른 재질은 **한 줄도 안 건드렸다.**

---

## 5. 실런타임 결과 (실제 화면 촬영)

`tools/test_노멀맵_벽돌.gd` 가 **같은 카메라 · 같은 지형 · 같은 빛 세기**로 3장을 찍는다.
대조군은 씬을 바꾸는 게 아니라 **CanvasTexture 의 `normal_texture` 만 런타임에 비워서**
다른 조건을 100% 동일하게 유지했다.

| 상태 | 화면에서 본 것 |
|---|---|
| ① 노멀맵 없음 + 빛 왼쪽 | 벽 전체가 **납작하게** 균일 조명. 벽돌 하나하나의 입체감 없음 |
| ② 노멀맵 + 빛 왼쪽 | 벽돌마다 **왼쪽·위 모서리**가 밝고 오른쪽이 어둡다. 확실한 요철 |
| ③ 노멀맵 + 빛 오른쪽 | 하이라이트가 **오른쪽 모서리로 이동**. 왼쪽이 어두워진다 |

★ 단순히 밝아진 것이 아니라 **벽돌마다 하이라이트의 위치가 반대편으로 옮겨갔다.**

### 노멀맵 Y 방향
빛이 왼쪽일 때 볼록한 벽돌의 **왼쪽 면**이 밝다 = 물리적으로 올바르다.
**Invert Y 가 필요 없다.** texturemap.app 의 `Invert Y: OFF` 설정 그대로 맞다.

---

## 6. 무결성 검사 (`tools/진단_노멀맵_무결성.gd`)

```
① 원본 재질 fill_textures[0] = CompressedTexture2D (brick_black_seamless_341x307.png) → 원본 그대로 ✔
② 노멀맵(CanvasTexture) 물린 지형 = 8개 / 흑백짝 성공 8 · 폴백 0 → 진짜 흰색 아트를 물었다 ✔
③ 콜리전 폴리곤: 테스트 35개 / 원본 35개 → 완전히 동일 ✔
```

### 기존 검사 (회귀)

| 검사 | 결과 |
|---|---|
| `check_스마트월드` | 55개 중 실패 0 ✔ |
| `test_지형규칙` | 28 / 28 ✔ |
| `test_브릭구조` | 통과 3 / 실패 0 ✔ |
| `test_사방재질_칠하기` | 통과 58 · 실패 13 — **전부 잔디 템플릿("구형 구성 · 예상 실패")로 기존 그대로.** 이 검사는 `scenes/집/스마트 매쉬 assets/` 만 훑으므로 이번 신규 파일과 무관하다 |

→ **새로 깨진 검사 없음.**

---

## 7. 판정

| 항목 | 결과 |
|---|---|
| Normal Map 이 실제 Lighting 에 반응한다 | **PASS** |
| Light 위치에 따라 표면 명암이 변한다 | **PASS** |
| Diffuse 가 변하지 않는다 | **PASS** |
| 노멀맵이 보라색으로 화면에 출력되지 않는다 | **PASS** |
| UV / Texture Repeat 가 깨지지 않는다 | **PASS** (반복·seam 이상 없음) |
| SmartShape2D Edge / Corner 유지 | **PASS** (위·아래 석재 마감 정상) |
| Collision 유지 | **PASS** (35개 완전 동일) |
| 기존 프로젝트 Regression | **없음** (기존 파일 수정 0건) |

---

## 8. 다음 단계 판단

### ✅ 이제 다른 타일셋에도 Normal Map 을 적용해도 되는 상태

기술적 전제가 전부 확인됐다 — SS2D 애드온 무수정, 기존 재질 무수정, 흑백 짝 유지,
콜리전 무영향. WOOD / GRASS / IRON 으로 넓힐 때는 이 순서만 지키면 된다.

1. 각 타일셋의 **채우기 텍스처와 같은 해상도**로 노멀맵을 뽑는다
   (이번처럼 크기가 다르면 UV 가 어긋난다)
2. `벽돌_노멀테스트_black/white.tres` 와 같은 형식으로 CanvasTexture 를 **파일로** 만든다
   — 이름에 `black` / `white` 토큰을 반드시 남긴다(짝 찾기)
3. 그 타일셋 재질의 **사본**에 물려 테스트 씬에서 먼저 확인한다
4. 게임 스테이지에 반영하는 것은 **조명 설계가 정해진 뒤**에 한다

### ⚠ 게임 본편에 넣기 전에 남은 결정 두 가지

1. **`PointLight2D.height` 를 프로젝트 표준으로 정해야 한다.**
   0 이면 노멀맵이 사실상 안 보인다. 기존 광원(`발광체.gd`, `연결통로.gd`)은
   전부 height 를 안 건드리므로 기본값 0 이다.
2. **`어둠`(CanvasModulate) 밝기.** 스테이지_1 은 0.72 라 라이트 대비가 거의 안 산다.
   테스트 씬에서는 0.30 으로 낮춰야 요철이 보였다.
   그리고 `world_2/stage_2-1` 에는 CanvasModulate 자체가 없다(2026-09-05 STEP 1 에서 확인).

Cast Shadow(LightOccluder2D)는 이번 범위 밖이다. 다음 단계에서 별도로 한다.
