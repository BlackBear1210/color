"""승인된 Python 후처리: 생성된 상판 원화를 회색조·반복 경계 규격으로 정규화한다."""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'목재_v03_검토'
TARGET=ROOT/'assets/textures/smartshape/wood_deck_v4'

def main():
    info=json.loads((HERE/'목재_v03_생성목록.json').read_text(encoding='utf-8'))
    cached=OUT/'상판_생성원본.png'
    if not cached.exists(): shutil.copy2(info['source'],cached)
    a=np.asarray(Image.open(cached).convert('L').resize((512,512),Image.Resampling.LANCZOS),dtype=float)
    lo,hi=np.percentile(a,[1,99])
    a=18+np.clip((a-lo)/(hi-lo),0,1)*140
    # 네 가장자리의 실제 픽셀을 맞추되, 가운데 판자 결은 유지한다.
    for axis in (0,1):
        a=np.swapaxes(a,axis,0)
        edge=(a[0]+a[-1])/2
        for i in range(12):
            t=(1-i/12)**2
            a[i]=a[i]*(1-t)+edge*t
            a[-1-i]=a[-1-i]*(1-t)+edge*t
        a=np.swapaxes(a,0,axis)
    a=np.uint8(np.rint(a))
    rgb=np.repeat(a[:,:,None],3,axis=2)
    assert np.array_equal(rgb[:,0],rgb[:,-1]) and np.array_equal(rgb[0],rgb[-1])
    TARGET.mkdir(parents=True,exist_ok=True)
    Image.fromarray(rgb).save(TARGET/'top_grain.png')
    print('512×512, R=G=B, LR/TB seam=0',float(a.mean()))

if __name__=='__main__': main()
