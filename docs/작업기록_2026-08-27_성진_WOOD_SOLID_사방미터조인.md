# 작업기록 2026-08-27 · 성진 — WOOD SOLID 사방 미터 조인

## 목표

`res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn`의
네 모서리에서 테두리 조각이 바깥으로 튀거나 서로 겹쳐 보이는 현상을 없앤다.

기준은 `res://scenes/world_2/벽돌 테스.tscn`에서 사용한 방식이다.
도형 모양을 바꾸어도 엣지 한 벌이 폐곡선 전체를 따라가고, 코너는 별도 그림을
덧대지 않고 SS2D의 미터 조인으로 연결되게 한다.

## 참고한 문서

- `docs/작업기록_2026-08-25_성진_벽돌v2_불투명엣지_미터조인.md`
- `docs/SS2D_고해상도_타일셋_마스터템플릿.md`
- `docs/이슈_CORNER-SIDE-ROTATION-01.md`
- `docs/원본_소스_제작규칙.md`

WOOD v2 원본은 `SOURCE LOCK` 상태이므로 `edge_top.png`, `fill_detail.png`,
`corner_inner.png`, `corner_outer.png` 등 기존 PNG는 다시 굽거나 수정하지 않았다.

## 원인

기존 `지형_나무v2_black_detail.tres`는 다음 구성이었다.

- TOP / LEFT / BOTTOM / RIGHT 방향별 엣지 4개
- 방향별 좌우 taper 텍스처
- 0~360도 코너 전용 메타 1개
- `corner_outer`와 `corner_inner`를 별도 쿼드로 덧그림

그 결과 사각형 한 모서리에 방향별 엣지·taper·코너 쿼드가 함께 모였다.
수정 전 렌더에서 네 바깥 모서리에 투명한 뾰족점이 생겼고, 계단의 안쪽 코너에서는
세로 엣지가 겹쳐 테두리가 더 두꺼워졌다.

## 적용한 해결

### 1. 단일 사방 재질 추가

새 파일:

`res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_사방.tres`

설정:

| 항목 | 값 |
|---|---:|
| 엣지 텍스처 | `wood_v2/black/edge_top.png` 1장 |
| Normal Range | `0~360°` |
| Fit Mode | `CROP(1)` |
| Uniform Width | `true` |
| Corner Texture | `false` |
| Taper Texture | `false` |
| Texture Scale | `0.35` |
| Edge Offset | `-1.0` |
| Fill | `wood_v2/black/fill_detail.png` |
| Fill Scale | `0.35` |

별도 코너와 taper를 없애고 엣지 하나가 모든 방향을 이어서 그리게 했다.
SS2D가 같은 엣지 런 안에서 코너를 미터 조인하므로 모서리 두께가 일정해진다.

### 2. WOOD SOLID 템플릿에 적용

`TEMPLATE_WOOD_SOLID.tscn`의 점·크기·콜리전은 유지했다.

- 점: `(-256,-96) → (256,-96) → (256,96) → (-256,96)`
- 충돌 폴리곤: 위 네 점과 동일
- `collision_update_mode = 2`
- `collision_size = 24`
- 재질만 새 사방 재질로 교체
- 기존 구운 메시를 비우고 Godot 4.6.3으로 다시 계산

구운 메시 수는 기존 21개에서 아래 2개로 줄었다.

1. `fill_detail` 채움 메시
2. `edge_top` 사방 엣지 메시

### 3. 작업자 검증기 갱신

`tools/검증_작업자씬.gd`가 기존 5메타 방식만 정답으로 취급하고 있었다.
다음 두 구성을 모두 검사하도록 갱신했다.

- 기존형: 방향별 4메타 + 코너 전용 1메타
- 사방형: 360도 단일 메타 1개

사방형은 단순히 메타 개수만 허용하지 않고 `360°`, `CROP`, `uniform_width`,
코너 꺼짐, taper 꺼짐, 텍스처 1개를 모두 확인한다.

## 렌더 검증

Godot `4.6.3.stable.official`의 실제 D3D12 렌더로 확인했다.

| 이미지 | 내용 |
|---|---|
| `tools/_shots/나무_SOLID_수정전.png` | 방향별·코너별 기존 재질의 뾰족점과 중첩 |
| `tools/_shots/나무_SOLID_사방재질_검증.png` | 계단·발판·기둥에서 단일 재질 검증 |
| `tools/_shots/나무_SOLID_수정후.png` | 수정된 실제 WOOD SOLID 템플릿 |

확인 결과:

- 네 모서리가 45도 미터 조인으로 연결된다.
- 엣지 메시의 AABB가 도형 좌표 `-256..256 / -96..96` 안에 맞는다.
- 바깥으로 튀는 코너 쿼드가 없다.
- 안쪽 코너에서 옆면끼리 중첩되지 않는다.
- 채움과 테두리 사이에 빈 공간이 없다.

## 검사 결과

### 작업자 씬 검사

`res://tools/검증_작업자씬.gd`

- 작업자 템플릿 9개 모두 OK
- **338 통과 / 0 실패**
- `TEMPLATE_WOOD_SOLID.tscn` OK

### 필수 회귀검사 14개

Godot 4.6.3으로 한 프로세스씩 순차 실행했다.

| 검사 | 결과 |
|---|---|
| `check_스마트월드` | 43개 중 실패 0 |
| `test_사망판정` | 25 / 25 |
| `test_지형규칙` | 28 / 28 |
| `test_챕터전환` | exit 0 |
| `test_페인트v4` | 47 통과 / 실패 0 |
| `test_낙하사망` | 11 통과 / 실패 0 |
| `test_통로전환` | 19 통과 / 실패 0 · 단독 재검사 2회 exit 0 |
| `test_카메라연출` | 10 통과 / 실패 0 |
| `test_카메라공간` | 15 통과 / 실패 0 |
| `test_lobby_flow` | 전부 통과 |
| `test_color_death` | exit 0 |
| `test_paint_system` | 전부 통과 |
| `test_stages` | exit 0 |
| `test_빛창문` | exit 0 |

첫 묶음 실행에서 `test_통로전환`이 19개 판정을 모두 통과한 뒤 Windows 종료 정리
단계에서 한 번 접근 위반(`0xC0000005`)으로 끝났다. 동일 테스트를 단독으로 두 번
재실행했을 때는 두 번 모두 exit 0이었으므로 나무 재질 회귀 실패가 아니라 일시적인
Godot 4.6.3 종료 충돌로 분류했다.

## 별도 확인 사항

`test_2층방_스마트매쉬.gd`는 현재 작업 중인 `집_2층방.tscn`의 `지형/발판_A` 노드가
없어서 실패한다. 이번 작업은 `집_2층방.tscn`을 수정하지 않았으며, WOOD SOLID 변경과
무관한 기존 작업 상태라 별도 이슈로 남겼다.

## 변경 파일

- `assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_사방.tres` — 신규
- `scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn` — 재질 교체·메시 재굽기
- `tools/검증_작업자씬.gd` — 단일 사방 재질 검증 추가
- `docs/작업기록_2026-08-27_성진_WOOD_SOLID_사방미터조인.md` — 이 문서

기존 WOOD PNG, 다른 WOOD 템플릿, 다른 사용자의 미커밋 변경은 수정하지 않았다.
