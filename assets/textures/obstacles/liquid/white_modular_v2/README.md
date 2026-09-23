# 흰 물 v2 — 물살과 착수 물보라

### 2026-09-20 플레이 피드백 수정

stage_2-1의 W5는 390px/s(기존 3배). 세로는 거울 반복 대신 방향을 유지하는 두 표본 블렌드를 사용한다. 64px 물줄기의 착수 물보라는 224px로 확대했으며, 사각 테두리/대각 밝기 반복을 억제했다. 최신 그리기 여백은 좌우130/아래32px다. 선택된 흰 웅덩이는 침수된 지형 마감만 가리며 물을 끄거나 삭제하면 복원한다. 아래 초기 v2의 수치와 미적용 상태 설명보다 이 항목 및 최신 작업기록이 우선한다.

v1의 반듯한 실루엣과 저대비 질감이 종이 조각처럼 보인다는 사용자 피드백을 반영했다.

## 파일

- `flow_white.png`: 내장 image_gen으로 새로 생성한 난류·거품·여러 굵기의 물살 텍스처.
- `splash_white.png`: 내장 image_gen으로 생성한 RGBA 물보라. 실제 알파 0~254 확인. 이미지 원본을 편집하지 않고 셰이더에서 알파와 밝기를 사용한다.
- `preview.html`: 이미지가 내장된 독립 브라우저 미리보기. 실제 프로젝트의 sewer_masonry_v02/black/fill.png를 주변 벽돌로 사용. Godot 캡처가 아닌 동일 셰이더 함수의 WebGL2 미리보기.
- `res://shaders/white_water_modular_v2.gdshader`
- 공용 프리팹 `res://scenes/장식/유체/흰물_디자인.tscn`은 이제 v2를 사용한다.
- 비교 씬 `res://scenes/테스트/흰물_디자인_비교.tscn`도 같은 프리팹을 사용한다.

## 변경

몸통은 로컬 픽셀 UV로 반복하므로 크기를 바꿔도 질감 밀도를 유지한다. 속도가 다른 두 물결 표본과 미세한 변형을 겹쳐 흐른다. 외곽은 일정한 직선 대신 물결 밝기와 서로 다른 위상의 흔들림으로 흩어진다. 위험 몸통 대부분은 밝고 불투명하며 가장자리만 부드럽게 분산한다.

`착수_물보라` 기본 true. 물줄기 끝이 공중이거나 다른 물줄기로 이어지면 false로 설정한다. 물보라는 텍스처의 국소 변형·밝기 변화와 분리된 물방울 궤적으로 움직인다. 영상에서 추출한 프레임 애니메이션은 아니다. 물막은 120px 기준으로 착수 지점을 나눠 물보라의 가로 확대를 제한한다. 몸통 도형 밖의 분무를 위해 그리기 영역을 좌우 84px/아래 24px 확장한다. 이는 충돌 크기 확장이 아니다.

웅덩이는 얕은 수평 물결, 앞쪽 명암, 깊이에 따른 어두워짐을 넣었다. 지형의 윗면 규칙인 뒤깊이 4px/끝 모따기 3px를 유지한다. 가로 크기와 함께 깊이를 확대하지 않는다. 비교 화면의 수조 벽돌은 배치 참고용이며 물 이미지 안에 구워 넣지 않았다.

## 상태·제한

시각 전용. 기존 stage_2-1 등 맵과 유체.gd/웅덩이.gd는 교체하지 않았다. 실제 물의 색 혼합·꺼짐·차오름·판정은 아직 연결 전이며 흰색 전용이다. 폭/높이 조절, 가장자리와 물보라, 정지/재생은 브라우저에서 검수. Godot 실행 및 성능 검증은 저장소 안전 규칙에 따라 미실행.

기존 유체는 이전 아트에서 추출한 판정이므로 그림만 교체해서는 안 된다. 분무/장식 물방울을 치명 판정에 포함하지 말고 몸통과 구분해 후속 연결해야 한다.

## 생성 프롬프트 기록

생성 도구: 내장 image_gen (Higgsfield 아님). 이미지 생성 후 원본 그대로 저장.

Flow: Production grayscale texture for the interior of a roaring white waterfall in a gritty realistic side-view sewer platformer. Square full-bleed, no environment, no text. Uneven fast vertical streaks, fine spray grain, aerated ribbons, liquid folds, tiny bubbles, torn foam pockets. Midtones #959595 to #D0D0D0, white #FAFAFA highlights, restrained #606060 shadows. Uniform density, x/y repeat intent, orthographic. Avoid smooth silk, paper, hair and uniform waves.

Splash: Isolated white water impact splash, real transparent alpha, landscape 3:2, side-on orthographic. No ground, pool, pipe, text or rectangle. Low wide asymmetric fan, dense white froth, thin branching fingers, fine arcing droplets, concentrated mist. Monochrome realistic dark-fantasy rendering, base at 85% height, padded bounds, no incoming stream.


## 2026-09-20 얕은 웅덩이 수정
교차 반사선 제거. stage_2-1의 B 웅덩이 깊이64, 폭384, 오른쪽 안쪽폭64. 수면 y1408 유지. SS2D 바닥과 접촉 폴리곤도 변경. 상세 기록: docs/작업기록_2026-09-20_Codex_얕은비대칭웅덩이.md. Godot 실플레이 미검증.
