# 집(챕터 1) 배경 레이어 키트 — 3종 검수 제출

2026-09-26 · Codex · dev_4

**상태: 생성·저장·검수는 수행했으나 제작 규격 전체 통과 아님. 게임 투입 확정본으로 취급하지 말 것.**
H01·H10·H31만 제작했다. 나머지 25종은 만들지 않았다.
H01 및 H31은 각각 동일 프롬프트로 3회 생성해 비교했고, H10은 1회 생성했다.
총 생성 호출 7회, 자산 종류 3종, 지정 경로 선택본 3장이다.
모든 호출은 내장 image_gen 도구이며, §6 코드 블록 원문만 전달했다. 해상도 문구나 보충 지시를 붙이지 않았다.
배경 제거·명도 변환·크기 변환·알파 수정은 하지 않았다. PNG는 생성 원본과 바이트가 같다.
원본 시안은 `../../../artifacts/집배경_레이어키트_2026-09-26/생성원본/`, 검수 합성은 해당 폴더의 `검수/`에 분리했다.

## 파일 및 실제 규격

| ID | 파일 | 실제 해상도 | 반복 축 | 원점 기준(배치 제안, 씬 미수정) | 판정 |
|---|---|---|---|---|---|
| H01 | far/far_wall_plaster.png | 1254 × 1254 | X·Y 요청, 완전 seamless 불합격 | 좌상단 (0,0), 타일 주기 (1254,1254) | 불투명·정사각형 충족. 반복 경계와 큰 무늬 반복이 남음 |
| H10 | mid/mid_window_tall.png | 1024 × 1536 | 없음 | 하단 중앙 (512,1536); 실제 커튼 끝은 하단보다 위 | 실제 RGBA, 외곽 투명 확인. 엄격한 명도·중성 회색 규격은 미충족 |
| H31 | mid/mid_hall_arch_bay.png | 1374 × 1145 | X 요청·3회 검수, Y 반복 아님 | 하단 중앙 (687,1145), 가로 주기 1374 | 실제 RGBA. 가로형으로 생성되어 요청한 세로형 미충족. 내부 알파 극미량 잔여 |

원점 정보는 이미지 좌표상의 기준일 뿐 PNG에 엔진 피벗 정보를 넣은 것이 아니다.
H31 생성 재시도 해상도는 1312×1199 및 1536×1024로, 모두 세로형 조건에 실패했다.
선택본은 반복 띠와 조형을 비교해 첫 결과를 보존했다. H01 역시 세 결과의 반복 합성을 비교하고 첫 결과를 선택했다.

## 실제 확인한 것 — §8 검수표

| 항목 | 직접 확인 결과 | 근거 |
|---|---|---|
| 먼 벽 가로 3·세로 2 반복 | **검사 수행 / seamless 불합격.** H01을 겹침·블렌딩·반전 없이 3×2로 복사. 경계에서 균열·얼룩이 끊김 | H01_tile_3x2.png, H01_seam_detail.png |
| 진짜 알파 | **H10·H31 실제 알파 확인.** 체커보드는 별도 바탕에 원본 RGBA를 합성한 것. 원본에 체커무늬를 그려 넣지 않았음 | H10_checkerboard.png, H31_checkerboard.png, selected_metrics.json |
| 아치 내부가 실제 뚫림 | H31 중앙 픽셀 A=0. 내부 중앙 영역 X 40~60%, Y 40~90%의 최대 A=1/255. **시각적으로 뚫렸으나 100% 전부 A=0 조건은 불합격** | 픽셀 검사 및 체커보드 |
| 가로 3회 반복 띠 | H31 띠가 대체로 같은 높이로 이어지는 것을 확인. 표면·가장자리 미세 차이가 남아 완전 무이음은 보증하지 않음 | H31_repeat_3x1_checkerboard.png |
| 명도 45~55% 덩어리 없음 | **엄격한 통과 아님.** 세 장 전수 히스토그램과 연결 픽셀 검사. 수치는 아래 표 | 각 Hxx_histogram.png 및 원본별 histogram.csv |
| 빛기둥·광선·불꽃·발광 없음 | 세 장 합성에서 뚜렷한 빛기둥·광선·불꽃 없음 확인 | 원본 및 체커 합성 직접 확인 |
| 선명한 수평 윗면 없음 | **완전 통과 아님.** H10 창턱 및 H31 코니스·기둥 장식에 수평 경계가 읽힘 | 원본 및 합성 |
| 가구·복도 소품 바닥선 | 이번 대상에 가구·소품 없음. 해당 없음 | H20~H27·H34 미제작 |
| 흰 윤곽선·후광 없음 | 일반 보기에서 연속된 흰 테두리·후광은 관찰하지 못함. 가장자리 밝은 개별 픽셀은 존재하므로 픽셀 단위 무결점은 보증 안 함 | 체커보드 및 픽셀 명도 검사 |
| 글자·숫자·로고·워터마크 없음 | 선택한 세 장 육안 검사에서 없음 | 원본 및 검수 합성 |
| 검정·흰 발판 가독성 | 정적 합성에서 명도 5%·95% 표본 둘 다 읽힘. H10의 어두운 커튼 위 검정 표본은 주변 대비가 상대적으로 약함 | H01/H10/H31_platform_readability.png |
| 엔진 실행 안 함 | **실행하지 않음.** Godot 편집기·콘솔·headless·빌드 및 엔진 검사 모두 미실행 | 이번 작업 실행 내역 |

## 확인하지 못한 것 / 이번 범위 밖

- 나머지 far 4종 및 mid·props·fg 전체 검수: 미제작이므로 미확인.
- H12 아치, H15 반복 띠, H42 난간, 가구·복도 소품 바닥선: 미제작이므로 미확인.
- 실제 Godot 배율·필터·파랄랙스 이동 중 이음매, 충돌 지형과의 혼동, 실제 게임 화면 가독성: 엔진 실행 금지에 따라 미확인.
- 지정 해상도 일치: H01·H10은 비율 유형은 충족하나 숫자는 다름. H31은 세로형 비율 유형까지 미충족.
- 모든 픽셀 R=G=B: 세 장 모두 불일치. 눈에 강한 색조는 보이지 않지만 엄격한 중성 회색 조건은 미충족.

## 전수 픽셀 측정

명도는 8비트 sRGB 채널값으로 `round(0.2126 R + 0.7152 G + 0.0722 B)`를 계산했다.
선형 광량·엔진 색공간 판정이 아니다. 금지 구간은 정수 115~140(약 45~55%)이다.
히스토그램은 A>0인 원본 RGB를 집계하며, 아래 금지 대역 및 연결 덩어리는 A≥250에서 집계한다.
연결 덩어리는 상하좌우 4방향 기준이다. 체커보드 합성의 회색은 통계에 포함하지 않았다.

| ID | A=0 픽셀 수 | A 최대 | A≥250 금지대역 픽셀 | 최대 연결 덩어리 | RGB 채널차 99백분위 |
|---|---:|---:|---:|---:|---:|
| H01 | 0 | 255 | 29 | 4 px | 5/255 |
| H10 | 756,262 | 254 | 7,523 | 74 px | 5/255 |
| H31 | 1,182,993 | 255 | 12,731 | 156 px | 3/255 |

H01은 45~55% 큰 덩어리는 없지만 소수 픽셀이 존재하고, 18~38% 범위를 모든 픽셀에서 지키지는 않는다.
H10은 창 유리 이외 경계도 금지대역을 지나며, H31은 조각 밝은 부분에 금지대역 픽셀이 더 많다.
H01 경계 평균 명도차: X 6.259/255, Y 5.593/255. 내부 인접 평균차: X 4.283/255, Y 4.266/255.
수치만으로 seamless 판정하지 않고 실제 3×2 합성을 함께 확인했다.

## 실제 사용한 프롬프트 (원문 그대로)

### H01

생성 원본: `exec-2ab78631-521d-45b6-aac7-0c9b8201dc78.png`

```text
Production 2D game seamless tileable square background texture, grayscale strictly neutral.
Decaying Victorian mansion interior plaster wall seen flat-on: cracked lime plaster over old
masonry, faint water stains, hairline cracks. Uniform medium-dark gray, value range 18-38
percent brightness only, absolutely no mid-gray patches at 45-55 percent. Very low local
contrast, soft painterly, no focal point, no single landmark, no arches no openings no doors
no windows no pipes no furniture no floor no ceiling. Flat even ambient illumination, no
gradient, no vignette, no perspective, no cast shadows, no light shafts, no white outlines.
Fully opaque, fills the entire square, truly seamless on BOTH axes edge to edge. This is the
rearmost parallax layer of a monochrome side-scroller. Single square texture only, no border,
no text.
```

SHA-256: `7194f6c015fde26f5a432ebf9fc3af639e2486503298c2328fb2991770eda804`

### H10

생성 원본: `exec-96bdd4c4-e6a1-4765-9dc2-c46e9c654eab.png`

```text
Single isolated middle-ground background element for a monochrome 2D side-scroller, on REAL
transparent alpha background, grayscale strictly neutral. One tall arched Victorian mansion
window with a carved stone surround and heavy hanging curtains tied to one side; small leaded
glass panes show only a flat pale gray blank sky, no city, no landscape, no detail. Flat
orthographic side elevation, no perspective distortion. EVERYTHING outside the window surround
and curtains must be fully transparent - no wall, no floor, no ceiling, no background fill. The
glass is the brightest thing in the whole kit but stays around 60-75 percent brightness, soft
and even. ABSOLUTELY NO light shaft, no god ray, no volumetric beam leaving the window - the
game draws its own light. No white outlines, no glow, no characters, no platforms, no text.
Painterly restrained, low contrast, sized to stand about two thirds of a 1080 pixel tall screen.
```

SHA-256: `b968a251b7cd157af65f784464666dc6635f646c661d6830c3570a5e0a6c6fe9`

### H31

생성 원본: `exec-ece1b24c-5d90-425c-8cc3-d037c22ae731.png`

```text
Single isolated middle-ground background element on REAL transparent alpha background,
grayscale strictly neutral. ONE structural bay of a long mansion corridor: a pointed stone rib
arch springing from two slim engaged shafts, with a short length of moulded cornice above.
Designed to be REPEATED horizontally to build an endless arcade - the cornice must meet the left
and right image borders at exactly the same height so tiled copies join invisibly, and the
shafts continue off the bottom edge. The whole interior of the arch is 100 percent transparent -
no wall, no room, no dark fill, no floor. Flat orthographic side elevation with NO vanishing
point and NO receding repetition drawn inside the image - depth comes from the game engine
stacking layers, not from painted perspective. Value 18-38 percent brightness, no mid-gray 45-55
percent, low contrast, no white outlines, no glow, no light shafts, no text, no characters.
```

SHA-256: `0f1cb5e29b9fe617d9091a056fdd28654abf585b060c15ef76faeb18f56abb11`

## 작업 범위

`git pull --ff-only` 결과 Already up to date. 씬·스크립트·프로젝트 설정 미수정, .import 미생성.
Godot 및 엔진 검사 미실행. 커밋·푸시 미실행. 자산 파일·검수 자료·작업기록만 추가했다.
