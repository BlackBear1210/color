# 작업기록 2026-08-27 · 성진 — WOOD STAIRS 사방 미터 조인

## 목표

`res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn`의
각 계단 모서리에서 테두리 조각이 겹치거나 바깥으로 뾰족하게 튀는 현상을 없앤다.

기준은 `res://scenes/world_2/벽돌 테스.tscn`과 먼저 수정한
`TEMPLATE_WOOD_SOLID.tscn`의 360도 단일 엣지 방식이다.

## 참고한 문서

- `docs/작업기록_2026-08-25_성진_벽돌v2_불투명엣지_미터조인.md`
- `docs/작업기록_2026-08-27_성진_WOOD_SOLID_사방미터조인.md`
- `docs/SS2D_고해상도_타일셋_마스터템플릿.md`
- `docs/이슈_CORNER-SIDE-ROTATION-01.md`
- `docs/원본_소스_제작규칙.md`

WOOD v2 원본은 `SOURCE LOCK` 상태이므로 기존 PNG는 수정하거나 다시 굽지 않았다.

## 수정 전 문제

기존 계단은 아래 조각을 동시에 사용했다.

- TOP / LEFT / BOTTOM / RIGHT 방향별 엣지
- 각 방향의 좌우 taper
- `corner_outer`와 `corner_inner`를 사용하는 코너 전용 메타
- 코너 사이를 가리기 위한 투명 텍스처 메시

4단 계단의 직각 코너마다 이 조각들이 반복 생성되어 구운 메시가 총 61개였다.
실제 렌더에서는 다음 문제가 보였다.

- 각 디딤판 왼쪽 끝에 투명한 뾰족점이 바깥으로 돌출
- 세로면이 디딤판 끝을 덮어 코너마다 테두리 두께가 달라짐
- 안쪽 직각에서 엣지 조각끼리 겹침
- 아래쪽 긴 변의 코너에도 별도 쿼드 흔적이 남음

수정 전 이미지: `tools/_shots/나무_STAIRS_수정전.png`

## 적용한 해결

새 PNG를 만들지 않고 먼저 검증한 아래 재질을 재사용했다.

`res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_사방.tres`

핵심 설정:

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

방향별·코너별 기존 메시를 비운 뒤 Godot 4.6.3으로 다시 계산했다.
결과 메시 구성은 아래 2개뿐이다.

1. `fill_detail` 채움 메시
2. `edge_top` 360도 사방 엣지 메시

모든 직각 코너가 같은 엣지 런 안에서 미터 조인되므로 별도 코너 쿼드가 겹치지 않는다.

## 보존한 계단 구조

계단 점과 충돌 모양은 수정하지 않았다.

```text
(-450, 220) → (-270, 220) → (-270, 110) → (-90, 110)
→ (-90, 0) → (90, 0) → (90, -110) → (270, -110)
→ (270, -220) → (450, -220) → (450, 412) → (-450, 412)
```

- 가로 디딤판: 각 180px
- 단 높이: 각 110px
- 전체 폭: 900px
- 전체 높이: 632px
- 충돌 폴리곤: 위 12점과 동일
- `collision_update_mode = 2`
- `collision_size = 24`
- `collision_polygon_node_path = StaticBody2D/CollisionPolygon2D`
- 기존 씬 UID `uid://c15w11vr0ws52` 보존

## 렌더 결과

Godot `4.6.3.stable.official`로 수정된 실제 템플릿을 렌더했다.

수정 후 이미지: `tools/_shots/나무_STAIRS_수정후.png`

확인 결과:

- 각 디딤판과 세로면이 끊김 없이 이어진다.
- 모든 직각 코너가 일정한 45도 미터 조인으로 연결된다.
- 코너가 도형 바깥으로 튀어나오지 않는다.
- 안쪽 코너에서 엣지가 중첩되지 않는다.
- 테두리와 채움 사이에 빈 공간이 없다.
- 엣지 메시 AABB가 계단 도형 범위 `(-450,-220)~(450,412)`에 맞는다.

## 검사 결과

### 작업자 템플릿 검사

`res://tools/검증_작업자씬.gd`

- 작업자 템플릿 9개 모두 OK
- `TEMPLATE_WOOD_STAIRS.tscn` OK
- **316 통과 / 0 실패**

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
| `test_통로전환` | 19 통과 / 실패 0 |
| `test_카메라연출` | 10 통과 / 실패 0 |
| `test_카메라공간` | 15 통과 / 실패 0 |
| `test_lobby_flow` | 전부 통과 |
| `test_color_death` | exit 0 |
| `test_paint_system` | 전부 통과 |
| `test_stages` | exit 0 |
| `test_빛창문` | exit 0 |

**14개 프로세스 모두 exit 0.**

## 변경 파일

- `scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_STAIRS.tscn`
- `docs/작업기록_2026-08-27_성진_WOOD_STAIRS_사방미터조인.md`

이 계단이 참조하는 사방 재질과 작업자 검증기 변경은 바로 앞의
WOOD SOLID 작업에서 생성했다. 다른 WOOD 템플릿과 기존 WOOD PNG는 건드리지 않았다.
