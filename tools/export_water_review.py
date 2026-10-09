from pathlib import Path
from PIL import Image
import json
import numpy as np
# 실제 엔진 캡처만 묶어 생성형 시안과 검증 결과가 혼동되지 않게 한다.
r=Path(__file__).resolve().parents[1]/'docs/visual_review/water_reference_20261008'
frames=[Image.open(r/'motion'/f'{i:02d}.png').convert('RGB') for i in range(48)]
frames[0].save(r/'actual_game_motion.webp',save_all=True,append_images=frames[1:],duration=42,loop=0,quality=88)
contact=Image.new('RGB',(1140,1280))
for k,f in enumerate([0,12,24,36]): contact.paste(frames[f],((k%2)*570,(k//2)*640))
contact.save(r/'actual_motion_contact.jpg',quality=94)
for stage in [1,2]:
    before=Image.open(r/f'stage_2-{stage}_before.png').convert('RGB')
    after=Image.open(r/f'stage_2-{stage}_after.png').convert('RGB')
    comparison=Image.new('RGB',(1920,1080))
    comparison.paste(before.resize((960,540)),(0,0));comparison.paste(after.resize((960,540)),(960,0))
    comparison.paste(before.crop((480,270,1440,810)),(0,540));comparison.paste(after.crop((480,270,1440,810)),(960,540))
    comparison.save(r/f'comparison_2-{stage}.jpg',quality=93)
v=json.loads((r/'validation.json').read_text(encoding='utf-8-sig'))
v['pixel_change_frame0_to12']=float(np.mean(np.abs(np.array(frames[0],dtype=float)-np.array(frames[12],dtype=float))))
(r/'validation.json').write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
print('Actual engine motion exported: 48 frames')
