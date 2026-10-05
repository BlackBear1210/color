"""실제 PNG·목재 수식의 정적 합성. Godot 캡처나 엔진 검증으로 사용하지 않는다."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from 목재_입체검토 import GRAIN, smooth

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'아트_v02_검토'
ASSET=ROOT/'assets/background/쳅터1/레이어_v01'

def tones(u,v,edge=False):
    tx,ty=u.copy(),v.copy()
    top=np.zeros_like(u)
    joint=np.zeros_like(u)
    board=np.zeros_like(u)
    if edge:
        top=(v<.72).astype(float)
        depth=np.minimum(v/.72,1)
        across=u*9+(1-depth)*.36
        board=np.floor(across)
        x=np.mod(across,1)
        joint=1-smooth(.008,.033,np.minimum(x,1-x))
        tx=np.where(top>.5,depth*.48+board*.173,x*.12+board*.173)
        ty=np.where(top>.5,(x*.75+.12)/9,.04+(v-.72)*.48)
    tx,ty=1-abs(np.mod(tx,2)-1),1-abs(np.mod(ty,2)-1)
    g=GRAIN[np.minimum((ty*GRAIN.shape[0]).astype(int),GRAIN.shape[0]-1),np.minimum((tx*GRAIN.shape[1]).astype(int),GRAIN.shape[1]-1)]
    black=np.clip(g*.66,.018,.25)
    white=(.12+(np.minimum(.84,.66+g*.52)-.12)*smooth(.01,.065,g))*.945
    if not edge: return black*.50,white*.90
    variation=.94+.06*np.sin(board*2.399)
    black*=.50*(1-top)+variation*top
    white*=.86*(1-top)+variation*top
    black=black*(1-joint*.85)+.012*joint*.85
    white=white*(1-joint*.72)+.24*joint*.72
    arris=smooth(.66,.69,v)*(1-smooth(.70,.73,v))
    shadow=(v>=.73)*(1-smooth(.75,.97,v))
    return black*(1-shadow*.30)+arris*.032,white*(1-shadow*.15)+arris*.035

def terrain(base,points,white=False):
    # 변 법선·28.8px 상판·원본 결을 합성한다. SS2D 메시의 실제 삼각분할은 엔진에서 확인해야 한다.
    w,h=base.size
    yy,xx=np.mgrid[:h,:w]
    mask=Image.new('L',(w,h)); ImageDraw.Draw(mask).polygon(points,fill=255)
    inside=np.asarray(mask)>0
    dst=np.asarray(base.convert('RGB')).copy()
    color=tones(xx/276.48,yy/184.32)[int(white)]
    for p,q in zip(points,points[1:]+points[:1]):
        dx,dy=q[0]-p[0],q[1]-p[1]
        if dx<=0 or abs(dy)>dx*.176: continue
        length=np.hypot(dx,dy)
        along=((xx-p[0])*dx+(yy-p[1])*dy)/length
        depth=(-(xx-p[0])*dy+(yy-p[1])*dx)/length
        valid=inside & (along>=0)&(along<=length)&(depth>=0)&(depth<28.8)
        e=tones(along/276.48,np.clip(depth/28.8,0,1),True)[int(white)]
        color[valid]=e[valid]
    values=np.uint8(np.clip(color*255,0,255))
    dst[inside]=values[inside,None]
    return Image.fromarray(dst)

def tinted(path,factor):
    im=Image.open(path).convert('RGBA')
    a=np.asarray(im).copy(); a[:,:,:3]=np.uint8(a[:,:,:3]*factor)
    return Image.fromarray(a)

def room(wall,brightness,furniture,shift=0):
    im=Image.new('RGBA',(700,440),(40,)*3+(255,))
    tile=tinted(ASSET/f'벽지/{wall}.png',brightness*.85)
    for y in (-512,0):
        for x in (-512,0,512): im.alpha_composite(tile,(x+round(shift*.035),y))
    trim=tinted(ASSET/'띠/징두리_판넬.png',brightness)
    for x in (-512,0,512): im.alpha_composite(trim,(x+round(shift*.022),160))
    for name,x,y in furniture:
        obj=tinted(ASSET/f'가구/{name}.png',brightness)
        im.alpha_composite(obj,(x+round(shift*.055),y))
    im=terrain(im,[(0,400),(700,400),(700,440),(0,440)])
    return im

def main():
    OUT.mkdir(exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',21)
    small=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',16)
    im=Image.new('RGB',(1440,1000),(50,)*3); d=ImageDraw.Draw(im)
    d.text((20,10),'상판 방향·부서진 밑면·배경 명도 검토 / 실제 엔진 캡처 아님',font=font,fill=(225,)*3)
    d.text((20,44),'발판의 윗선은 평평하게 · 사방 테두리 제거 · 앞뒤 방향 나뭇결과 어두운 앞 단면',font=small,fill=(190,)*3)
    black=[(20,40),(650,40),(664,52),(655,135),(623,155),(584,139),(568,163),(518,143),(470,151),(440,130),(407,157),(368,143),(328,150),(280,128),(245,149),(205,138),(177,163),(140,144),(106,153),(60,137),(32,150),(20,140)]
    for i,white in enumerate((False,True)):
        panel=Image.new('RGB',(700,215),(53,)*3)
        im.paste(terrain(panel,black,white),(20+i*710,90))
    a=room('다마스크',.61,[('액자_팔각',50,30),('거울',260,144),('소파',360,272)])
    b=room('판자',.60,[('벽등',50,40),('선반',165,80),('상자더미',455,272)])
    im.paste(a,(20,355)); im.paste(b,(730,355))
    d.text((20,324),'복도 B: 어두운 전시 공간',font=font,fill=(220,)*3)
    d.text((730,324),'복도 C: 낡은 수납 공간',font=font,fill=(220,)*3)
    d.text((20,820),'벽·균열: 카메라 이동의 3.5% / 몰딩: 2.2% / 가구: 5.5% / 샹들리에: ±0.52°',font=font,fill=(210,)*3)
    d.text((20,860),'가구의 바닥 높이는 고정. 원본 PNG의 회색조·투명도는 유지하고 씬 배경 밝기만 낮춥니다.',font=small,fill=(190,)*3)
    d.text((20,900),'이 자료는 수식과 PNG의 배치 검토용입니다. 실제 조명·색칠·충돌·카메라 전환은 엔진 확인 대기입니다.',font=small,fill=(190,)*3)
    im.save(OUT/'목재와_어두운배경_검토.png')
    u,v=np.meshgrid(np.linspace(0,1,512),np.linspace(0,1,128))
    for edge in (False,True):
        black,white=tones(u,v,edge)
        assert np.all(np.isfinite(black)) and np.all(white>black)
    (OUT/'수식검사.json').write_text(json.dumps({'finite':True,'white_above_black':True,'engine_run':False}),encoding='utf-8')
    print(OUT/'목재와_어두운배경_검토.png')

if __name__=='__main__': main()
