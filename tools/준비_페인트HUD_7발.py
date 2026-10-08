"""힉스필드 원화를 HUD의 기존 72px 액체 창에 맞춘다. 엔진 실행 없이 멱등 처리한다."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/ui/paint_gauge'
image = Image.open(OUT / 'higgsfield_frame_source.png').convert('RGBA')
data = np.array(image)
# 생성 원화의 원형 유리 창을 측정한 중심/반지름. 현재 원화 파일 기준이며 누적 보정을 하지 않는다.
center = (1024, 1008)
radius = 554
y, x = np.indices(data.shape[:2])
distance = np.sqrt((x - center[0]) ** 2 + (y - center[1]) ** 2) / radius
# 중앙에 유리 반사가 남아 실시간 액체를 덮지 않도록 내부를 비우고 테 가장자리만 유지한다.
window = np.clip((distance - .93) / .055, 0, 1)
data[:, :, 3] = (data[:, :, 3] * window).astype(np.uint8)
# 투명 배경의 낮은 알파 후광을 제거하고 원화의 흑백 재질은 유지한다.
data[:, :, 3] = np.clip((data[:, :, 3].astype(float) - 30) * 255 / 224, 0, 255).astype(np.uint8)
gray = (data[:, :, :3].astype(float) @ np.array([.2126, .7152, .0722])).astype(np.uint8)
data[:, :, :3] = gray[:, :, None]
scale = 35.5 / radius
width = round(2048 * scale)
image = Image.fromarray(data).resize((width, width), Image.Resampling.LANCZOS)
# HUD 기준 40,40에 유리 창을 정렬한다. 커다란 원본은 작은 에셋으로만 게임에 사용한다.
offset = (round(40 - center[0] * scale), round(40 - center[1] * scale))
image.save(OUT / 'frame.png')
(OUT / 'frame_meta.json').write_text(json.dumps({'source_job': '92d6585a-7b1a-4946-925e-36be2268362b', 'offset': offset, 'size': [width, width], 'window_center': [40, 40], 'window_radius': 35.5}), encoding='utf-8')
print(f'HUD frame: {width}×{width}, offset={offset}, window=(40,40), r=35.5')
