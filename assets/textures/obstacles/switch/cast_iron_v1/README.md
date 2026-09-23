# 주철 압력 발판 / 직선 레버

2026-09-23 승인 시안을 built-in image_gen으로 게임용 RGBA 부품 아틀라스로 제작.
`parts.png`: 1254×1254, 투명 배경. 픽셀 편집 없이 생성 원본 복사.
코드에서 `draw_texture_rect_region`으로 영역을 읽는다. 좌상단의 생성된 상판은 사용하지 않고 프레임 아래 영역만 사용한다.
압력 발판은 프레임과 별도 상판, 레버는 받침과 별도 손잡이로 애니메이션한다.
생성 원본: exec-f06abc84-7682-45d6-bcc1-2345b42a5c01.png.

## 생성 프롬프트

Create a production transparent RGBA sprite atlas, 1024x1024, for the approved worn cast iron pressure plate and lever in the reference image (reference is STYLE only). Exactly FOUR isolated mechanical parts arranged in 2x2 equal 512px cells, no labels, no background, no floor, no shadows outside silhouettes. Grayscale aged iron with restrained silver worn edges, frontal orthographic 2D platformer view, very slight top bevel only. TOP LEFT cell: fixed low pressure plate base housing alone, rectangular 440px wide and 100px high centered at (256,350), bolted left/right ends, narrow DARK empty indicator window center front, no moving upper lid. TOP RIGHT cell: separate pressure plate moving top lid alone, 400px wide 55px high centered (768,350), thin heavy textured metal slab with slight top bevel. BOTTOM LEFT cell: fixed lever housing alone centered x256: low rectangular bolted foot at y940, semicircular arched housing above it from y760 to940, pivot circular bolt centered exactly (256,825), NO HANDLE attached. BOTTOM RIGHT cell: isolated lever HANDLE ONLY, perfectly VERTICAL, round black grip centered (768,650), metal straight shaft to a round pivot at (768,890). Designed to rotate about bottom pivot, no base. Objects fully separated, transparent background including between parts. Match approved reference material and detailing closely. No text or gridlines.
