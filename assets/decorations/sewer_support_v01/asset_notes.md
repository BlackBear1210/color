# sewer_support_v01 — 하수도 지지구조 장식 아트 노트

## 2026-09-14 아스트라 아트 교체 — 현재 기준

현재 세 PNG는 내장 ImageGen으로 기존 프로시저 그림의 배치/형상을 참고해 편집한 금속 아트다. 아래 Claude 초판 기록은 이전 상태이며 현재 크기 규칙으로 사용하지 않는다. 임시 원본은 `placeholder_archive/`에 보관했다. `생성_하수도_지지구조_아트.gd`를 다시 실행하면 임시 그림으로 덮일 수 있으므로 실행하지 않는다.

| 파일 | 실제 해상도 | 게임 표시/부착 계약 |
|---|---|---|
| bracket.png | 1254×1254 RGBA | 기본96×96, 배율0.75~1.5. 해상도와 표시 크기 분리. 왼쪽 위 원점 유지 |
| chain_repeat.png | 887×1774 RGBA | 기존 폭24·반복48 유지. UV 반복으로 표시하므로 원본 픽셀 높이를 간격에 넣지 않음 |
| chain_anchor.png | 1499×1049 RGBA | 표시40×28, 연결점 y20 유지. 발판형은 반전 |

세 이미지 모두 알파0~255가 존재하며 원본 알파를 보존했다. 비트맵 리사이즈/합성 없이 프로젝트에 복사했다. 브래킷/고정구는 Sprite 표시 크기를 기존 규격으로 정규화한다. 새 아트의 세부 마모는 생성 결과이며 실제 안전 색/충돌과 무관하다.

생성 도구: 내장 image_gen, 2026-09-14, 기존 PNG 각각을 편집 입력으로 사용.
핵심 프롬프트:
- bracket: polished hand-painted realistic 2D dark fantasy sewer wrought iron triangular wall bracket; preserve exact silhouette/layout, left vertical/top horizontal/diagonal brace, dark pitted iron, restrained silver wear, bolts, genuine transparency, no colored rust, no white outline.
- chain: one vertically seamless 1:2 repeat unit, front oval link and edge-facing connector crossing top/bottom, constant link scale, dark forged iron, transparent hole/background, no extra top/bottom margin.
- anchor: preserve normalized40:28 plate/two bolts/hanging ring centered at20,20; charcoal iron, subtle worn highlights, genuine transparency, fixed frontal view.

실제 렌더링 캡처: `docs/스크린샷_하수도_지지구조_정식아트_2026-09-14/`. 시차 배경은 검수 도구에서만 추가했으며 기존 맵 배경을 수정하지 않았다. 체인 이어짐은 게임 표시 크기에서 시각 확인했으며 픽셀 단위 완전 동일한 wrap 경계를 보장하는 것은 아니다.

---

## 아래는 프로시저 초판 기록(이전 규격)

작성 2026-09-14 · Claude. 생성기: `tools/생성_하수도_지지구조_아트.gd` (Godot 헤드리스 · 거리함수로 픽셀을 직접 칠함).

**★ 전부 기능 검증용 임시 아트(프로시저)다.** 이 세션에 이미지 생성 도구 권한이 없어 코드로 그렸다. 원화 수준이 아니다.
정식 아트가 오면 **같은 파일명 · 같은 크기 · 같은 원점 · 알파 0 배경**으로 덮어쓰면 코드 변경 없이 바뀐다.
외부 에셋 없음 · 라이선스 문제 없음. 참고 이미지(`scenes/world_2_클로드/참고_쇠사슬_삼각지지대.png`)는 형태만 참고했고 픽셀은 쓰지 않았다.

| 파일 | 크기 | 뜻 | 원점·반복 규칙 |
|---|---|---|---|
| `chain_repeat.png` | 24 × 48 | 쇠사슬 **반복 단위** — 앞고리(타원 링) 1 + 옆고리(막대) 1 | 세로로 이어 붙이면 고리가 연결된다(위아래 wrap 그림). 좌우 배경 알파 0. `하수도_쇠사슬.gd` 가 v 방향으로 `길이/고리_간격(48)` 만큼 반복. v = 0 이 **발판 쪽** |
| `chain_anchor.png` | 40 × 28 | 체인 고정구 — 볼트 2 개 판 + 아래로 나온 고리 | 판 윗변 가운데 = 씬 원점(`체인고정구.tscn` 이 맞춘다). 고리 중심 (20, 20) = 체인이 닿는 `연결점`. 발판용은 flip_v |
| `bracket.png` | 96 × 96 | 삼각 지지대 — 벽판(왼쪽 세로) + 가로대(위) + 대각대 + 볼트 4 + 모서리 거싯 | **왼쪽 벽 고정형** 한 장. 왼쪽 위 = 발판 밑면이 벽에 닿는 모서리(씬 원점). 오른쪽 벽은 `삼각지지대.tscn` 의 flip_h |

색: 무채색만(테두리 0.03 · 몸 0.14 · 하이라이트 최대 0.37). 흰 발판(0.9)보다 어둡고 검정 발판(0.09)과 구분되게 잡았다.
알파 가장자리: 거리함수 1px 부드럽게. 흰 테두리 없음(검정·밝은 배경 양쪽에서 확인 — `docs/스크린샷_하수도_지지구조_2026-09-14/`).

바꿀 때 지킬 것
- 쇠사슬 단위의 **높이를 바꾸면** `쇠사슬.tscn`/인스펙터의 `고리_간격` 도 같은 값으로(폭은 `고리_폭`). 24:48 비율이 깨지면 고리가 찌그러진다.
- 고정구 고리 중심 위치를 바꾸면 `하수도_체인고정구.gd` 의 `고리_거리`(20) 를 맞춘다.
- 브래킷 원점(왼쪽 위)과 벽판 두께(14)를 바꾸면 `삼각지지대.tscn` 의 `그림` 위치·`부착_오프셋` 기본값을 확인한다.
- 이 폴더의 파일을 바꾸면 **모든 맵의 장식이 한꺼번에** 바뀐다(공유 텍스처). 인스턴스별 차이는 `색조` 로만.

버전
- v01 (2026-09-14): 프로시저 초판. 검사 `tools/test_하수도_지지구조.gd` 17/17 통과 기준.
