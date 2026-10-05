"""목재 셰이더 수식을 비교하는 정적 시각 보조자료. 실제 엔진 캡처가 아니다.

직각 외곽·오목 코너에서 마감판이 어떻게 이어지는지, 흑백 명도 차이를 검토한다.
게임 조명·색공간·SS2D 메시 분할 결과는 재현하지 않으므로 엔진 검증을 대체하지 않는다.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / '아트_v01_원본'
GRAIN = np.asarray(Image.open(ROOT/'assets/textures/smartshape/wood_deck_v3/grain.png').convert('L'), dtype=float)/255


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def tones(u, v, edge=False, new=True):
    tx, ty = u.copy(), v.copy()
    top, joint = np.zeros_like(u), np.zeros_like(u)
    if edge:
        top = (v < .72).astype(float)
        row = np.minimum(np.floor(v/.24), 2)
        y = np.mod(v/.24, 1)
        x = np.mod(u+row*.37+v*.035, 1)
        gap = np.minimum.reduce([x, 1-x, abs(x-.17), abs(x-.43), abs(x-.75)])
        joint = np.maximum(1-smooth(0, .005, gap), 1-smooth(0, .10, np.minimum(y, 1-y)))*top
        tx = u+row*.19
        ty = np.where(top > .5, (row+.15+y*.65)/9, .04+(v-.72)*.24)
    tx, ty = 1-abs(np.mod(tx, 2)-1), 1-abs(np.mod(ty, 2)-1)
    g = GRAIN[np.minimum((ty*GRAIN.shape[0]).astype(int), GRAIN.shape[0]-1),
              np.minimum((tx*GRAIN.shape[1]).astype(int), GRAIN.shape[1]-1)]
    black = np.clip(g*.66, .018, .25)
    white = (.12+(np.minimum(.84, .66+g*.52)-.12)*smooth(.01, .065, g))*.945
    if new and not edge:
        black *= .58
        white *= .90
    if edge:
        if new:
            black *= .58+.42*top
            white *= .90+.10*top
            black = black*(1-joint*.60)+.018*joint*.60
            white = white*(1-joint*.60)+.22*joint*.60
            bevel = smooth(.65,.68,v)*(1-smooth(.70,.72,v))
            shadow = (v>=.72)*(1-smooth(.73,.94,v))
            black = black*(1-shadow*.38)+bevel*.025
            white = white*(1-shadow*.20)+bevel*.025
        else:
            black = black*(.90+.38*top)+top*.020
            white *= .85+.18*top
            black = black*(1-joint*.75)+.025*joint*.75
            white = white*(1-joint*.75)+.16*joint*.75
            lip = 1-smooth(.006,.024,abs(v-.72))
            black *= 1-lip*.24
            white *= 1-lip*.20
    return black, white


def shape(points, color, new, size=(820,310)):
    w,h = size
    yy,xx = np.mgrid[:h,:w]
    mask = Image.new('L',size)
    ImageDraw.Draw(mask).polygon(points,fill=255)
    inside = np.asarray(mask)>0
    fill = tones(xx/276.48,yy/184.32,new=new)[color]
    result = np.full((h,w),107/255)
    result[inside] = fill[inside]
    # 각 변의 거리 중 가장 가까운 변을 택하면 직각 외곽은 대각 마이터로 만난다.
    # 오목 코너도 연장된 변의 유효 구간을 검사하므로 틈 없이 이어진다.
    best = np.full((h,w),1e9)
    for p,q in zip(points,points[1:]+points[:1]):
        p,q = np.asarray(p),np.asarray(q)
        vec = q-p
        length = np.linalg.norm(vec)
        tangent = vec/length
        inward = np.array([-tangent[1],tangent[0]])
        along = (xx-p[0])*tangent[0]+(yy-p[1])*tangent[1]
        distance = (xx-p[0])*inward[0]+(yy-p[1])*inward[1]
        if not new and not (vec[0]>0 and vec[1]==0):
            continue
        valid = inside & (distance>=0) & (distance<28.8) & (along>=-28.8) & (along<=length+28.8) & (distance<best)
        edge = tones(along/276.48,np.clip(distance/28.8,0,1),edge=True,new=new)[color]
        result[valid]=edge[valid]
        best[valid]=distance[valid]
    return Image.fromarray(np.uint8(np.clip(result,0,1)*255)).convert('RGB')


def main():
    OUT.mkdir(exist_ok=True)
    im = Image.new('RGB',(1720,1050),(107,)*3)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',23)
    d.text((20,15),'목재 명도·코너 정적 비교 — 실제 엔진 캡처 아님',font=f,fill=(230,)*3)
    d.text((20,55),'왼쪽: 이전 수식 / 오른쪽: 변경 수식 · 충돌/조명/색공간/실제 SS2D 분할은 엔진 검증 대기',font=f,fill=(215,)*3)
    shapes=[([(20,100),(800,100),(800,300),(20,300)],0),
            ([(20,30),(370,30),(370,140),(800,140),(800,300),(20,300)],0),
            ([(20,65),(800,65),(800,285),(20,285)],1)]
    for row,(points,color) in enumerate(shapes):
        for col,new in enumerate((False,True)):
            im.paste(shape(points,color,new),(20+col*860,110+row*310))
    im.save(OUT/'목재_변경전후_정적비교.png')
    # 결 전체에 대해 흰색/검정 순서가 뒤집히지 않는지, 앞면만 어두워졌는지 확인한다.
    u,v=np.meshgrid(np.linspace(0,1,512),np.linspace(0,1,256))
    old=tones(u,v,new=False)
    new=tones(u,v,new=True)
    assert np.all(new[0]<new[1])
    assert np.all(new[0]<=old[0]) and np.all(new[1]<=old[1])
    report={'kind':'offline_formula_check_not_engine',
            'black_front_mean_before':float(old[0].mean()),'black_front_mean_after':float(new[0].mean()),
            'white_front_mean_before':float(old[1].mean()),'white_front_mean_after':float(new[1].mean()),
            'paint_color_order':'pass','front_darkening':'pass'}
    (OUT/'목재_수식검사.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))


if __name__=='__main__':
    main()
