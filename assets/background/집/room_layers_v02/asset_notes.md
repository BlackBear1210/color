# 집 배경 — 같은 방을 깊이별로 나눈 레이어 v02

2026-09-26 · Codex · 내장 image_gen 사용

## 방향 변경

사용자 피드백: 이전의 벽 텍스처·독립 창·독립 아치는 레퍼런스의 방 분위기와 층층이 쌓이는 입체감을 만들지 못했다.
이번에는 제공된 레퍼런스를 실제 입력 이미지로 사용하고, 한 방의 같은 좌표계를 공유하는 3장의 배경 레이어를 만들었다.
최신 요청에 맞춰 기존 H01/H10/H31 원문 프롬프트 방식에서 방 단위 프롬프트로 변경했다.
기존 결과는 보존하고 이 폴더에 새 결과를 저장했다. 다른 25종을 확대 생성하지 않았다.

## 세 장과 배치

모두 **1536 × 1024**. PNG 원본을 보정·잘라내기·배경 제거 없이 복사했다.
원점은 세 장 모두 좌상단 (0,0), 동일 배율·동일 위치로 L1→L2→L3 순서로 겹친다.
투명 여백은 방 내부 배치 좌표이므로 자동 트리밍하면 안 된다.

| 파일 | 역할 | 투명성 | 반복 축 |
|---|---|---|---|
| L1_far_room.png | 큰 아치 창·커튼, 먼 벽, 먼 출입구, 방 바닥 | RGB 완전 불투명 | 없음 |
| L2_mid_furnishings_stairs.png | 창 앞의 책장·소파·탁자, 오른쪽 계단·난간 | RGBA, A=0 픽셀 1,282,153개 (81.52%) | 없음 |
| L3_near_frame.png | 가까운 양옆 기둥·커튼·상단 보·샹들리에 | RGBA, A=0 픽셀 1,221,239개 (77.64%) | 없음 |

창틀과 창 커튼은 L1에서 함께 움직인다. 전경 커튼은 창 커튼과 별개로 가까운 문틀에 붙어 있다.
가구와 계단은 이번 구도 확인을 위해 한 중경에 배치했다. 가구별 재배치용 낱장 키트는 아직 아니다.
이 3장은 방 하나의 깊이 구성 시안이다. 22,272px 스테이지 전체나 무한 반복용 타일이 아니다.

## 직접 확인한 것

- 생성 이미지 3장이 모두 같은 1536×1024 좌표계인지 파일로 확인.
- L1 불투명, L2·L3 실제 RGBA 및 알파 0 픽셀 존재 확인.
- L2 빈 공간과 난간 사이, L3 중앙과 샹들리에 주변을 체커보드 합성으로 직접 확인.
- L1→L1+L2→L1+L2+L3 단계별 합성 확인. 창 뒤·가구/계단 중간·기둥/커튼 앞의 가림 관계 확인.
- 레퍼런스의 캐릭터·톱날·물·공중 발판은 넣지 않음. 명시적인 광선·빛기둥·불꽃은 육안으로 보이지 않음.
- 커튼이 책장 일부를 가리고, 계단이 먼 출입구 상단 일부를 가림. 의도된 깊이 관계.
- 움직임 미리보기는 게임 엔진이 아닌 이미지 합성. 뒤/중간/앞 레이어에 각각 ±5/15/33px의 수평 이동을 적용.
- 원본 PNG는 생성 결과와 바이트가 동일하다. 검수 합성에만 축소·크롭·상대 이동을 사용했다.

## 확인하지 않은 것 / 한계

- Godot 실행, 실제 파랄랙스 수치 적용, 게임 지형·캐릭터 가독성: 미실행·미확인.
- 양축/가로 seamless: 이 세트는 비반복 방 구도이므로 해당 없음.
- 기존 §8의 엄격한 45~55% 명도 금지·완전한 중성 회색·모든 외부 픽셀의 정확한 A=0: 이번 버전 전수 검증하지 않음. 전체 제작 규격 통과라고 주장하지 않음.
- L2 계단/창턱의 수평선은 보인다. 실제 지형과 겹칠 때 오인 여부는 엔진에서 확인 필요.
- L2·L3 최대 알파는 254/255. 투명 외부가 있는 실제 RGBA이지만 물체가 수치상 완전 불투명인 것은 아님.
- 확대·큰 이동·반복에 필요한 화면 밖 추가 그림은 없음. GIF는 10% 확대와 크롭으로 작은 이동만 시연.
- 스타일과 층 분리 구도에 대한 최종 사용자 확인은 아직 받지 않음.

## 검수 자료

저장소 `artifacts/집배경_방레이어_v02/검수/`:

- 03_complete_room.png — 실제 3장 합성
- layer_stack_comparison.jpg — 왼쪽 개별 층 / 오른쪽 누적 합성
- room_parallax_preview.gif — 레이어별 상대 속도 차이 미리보기
- L2_mid_furnishings_stairs_checkerboard.png / L3_near_frame_checkerboard.png — 알파 검수
- alpha_report.json — 실제 해상도·알파 측정

## 실제 사용 프롬프트

### L1

```text
Create ONE production background layer, not a sprite sheet, for a three-layer parallax room scene. Use the attached image as the ART DIRECTION reference: painterly monochrome decaying Victorian grand interior, cinematic atmospheric depth, immense tall windows, layered architectural masses, worn wood and plaster, broad painted shapes rather than photoreal stone detailing. This is LAYER 1, the distant room shell. Wide landscape canvas 1536x1024, full bleed opaque. A straight-on side-scroller camera inside an imposing double-height drawing room. The room fills the whole canvas with a continuous coherent space, not an isolated wall texture or a centered object. At x 18%-43%, an enormous arched window spans y 10%-78%, translucent old curtains attached to the window, softly luminous overcast pale gray outside with only very faint distant silhouettes. Its blank light is about 65-72% gray. At x 48%-90%, receding interior wall bays, tall recessed panels, a shadowy doorway to another room at lower right, faint distant ceiling mouldings and architectural columns that read as much farther back. Quiet floor/back wall junction near y 87%, no obvious playable floor edge. Soft dusty ambient atmosphere, distant shapes low contrast, wall values mostly 20-38%. Room feels spacious and inhabited in its architecture, softly decayed and melancholy. Keep lower third mostly open for separate furniture and staircase layers to be composited later. Keep outer edges continuous room architecture; no foreground framing in this layer. Do NOT draw any staircase, foreground railing, furniture, chandelier, hanging chains, close columns, platforms, character, sawblade, spikes, pools, water, text, logo, or interface. No sharp white contour edges. No discrete light shafts, rays, visible cones, or flame. The beauty comes from the immense pale window receding behind dusky interior bays and painterly tonal atmosphere. Strictly neutral grayscale. This is only the rear room layer; do not reproduce gameplay objects from the reference. One image only.
```

### L2

```text
Create ONE transparent full-canvas MIDDLE LAYER to be placed directly over reference image 2 (the empty mansion room). Reference image 1 is the original painterly artistic direction, reference image 2 is the precise composition and alignment guide. Output ONLY new middle-distance furnishings and stairs with REAL transparent alpha everywhere else. Wide landscape 1536x1024, exact same framing as reference 2. Do not redraw the room shell, windows, curtains, walls, floor or background. Do not output a flattened room illustration. Think of a theater set separated into depth planes: this layer is a coherent arrangement within the room, NOT an isolated centered prop, NOT a sheet of unrelated items. Preserve the very large transparent negative space in the upper-left two thirds so the tall luminous window at x18%-43% remains visible behind these elements.
Paint at x5%-17%, y54%-87% a worn tall bookcase with leaning books, obscured details, dark painterly silhouette. Paint at x22%-43%, y73%-87% an old tufted sofa, one small side table with an UNLIT shaded lamp, all naturally arranged as one seating area in front of the rear window. Paint at x48%-78%, y50%-87% a substantial old wooden staircase with carved balustrade ascending to the right to a short landing at y50%; the stair skirt is an enclosed dark wood mass, the gaps between individual balusters must be true transparent holes. A slender landing support at x78% ends at y87%. Leave x80%-93% around the distant doorway open/transparent. All elements meet one consistent implied floor at y87%; no floor pixels or shadow plane across the empty canvas. The spaces around and between all objects must have alpha=0. Nothing touches the canvas edges unless specified. Restrained brushed monochrome dark fantasy illustration, broad broken brushwork, neutral grayscale matching the attached art, mid-distance values mainly 17-33%, moderate soft contrast, distinctly darker and clearer than the far room wall. Soft dark stair tread edges, no brilliant horizontal top edges, no white outlines, no polished photoreal 3D rendering, no glow, no light beams, no flames, no character, no water, no saw, no spikes, no suspended gameplay platform, no text. SINGLE RGBA layer, no checkerboard drawn into the picture.
```

### L3

```text
Create ONE transparent FOREGROUND OCCLUSION LAYER for a layered 2D dark Victorian room. Image 1 is painterly atmosphere reference, image 2 is the far room shell, image 3 is the separate middle-distance furniture/stair layer. Use these only as alignment and style guides. Output ONLY close-camera framing architecture on REAL transparent alpha, wide landscape 1536x1024 with the same full-frame layout. NO room, NO wall backdrop, NO floor, NO window, NO staircase or sofa repeated into this layer. The middle 75 percent of the image is completely transparent, so the existing window, stairs and furnishings show through when layers are stacked.
At the extreme LEFT x0%-8%, paint the cropped inner face of a thick old wooden doorway pier, with ornate brackets and subtle worn carved profile, running off top and bottom of frame. A near-black heavy velvet curtain attached here hangs down to y63%, cropped mostly outside the left edge, irregular folds extend at most to x12%. At extreme RIGHT x94%-100%, a second much nearer dark carved pier runs off the top/bottom; its carved bracket projects to x88% only within top 15% of canvas. A shallow broken moulded beam frames just the uppermost 0%-7%, with irregular worn underside, integrated with these two piers. In the upper middle at x65%, ONE unlit wrought iron chandelier hangs by a thin chain from the top to y23%, small enough not to cover the main window, candles NOT lit. There is NO bottom horizontal border or floor and NO railing across the lower center. It must read like peering past close interior architecture into the large room behind. Broad hand-painted weathered silhouettes, muted charcoal black values 5%-16%, very subtle edge texture, slightly softer focus than the middle layer. No bright trim, no white outlines, no rim lighting, no glow, no volumetric light, no flame, no dust haze filling the transparent center. Strict neutral grayscale. Do not paint cast shadows onto empty canvas. All empty space, including holes in the chandelier and carved brackets, must be actual alpha transparency, not a black backdrop or baked checkerboard. No character, no gameplay platform, no saw blade, no water, no text. One RGBA image only.
```

입력 참조: L1은 사용자 레퍼런스 1장, L2는 레퍼런스+L1, L3는 레퍼런스+L1+L2.
사용자 레퍼런스: C:/Users/김도형/Desktop/Codex 이미지 2026년 9월 20일 오후 12_11_15.png
씬·스크립트·.import 수정/생성 없음. Godot 및 빌드/엔진 검사 미실행. 커밋·푸시 없음.

