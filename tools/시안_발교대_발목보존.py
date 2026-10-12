"""발목ㆍ신발 원화를 함께 보존하는 별도 시안. 실제 게임에는 연결하지 않는다."""
from pathlib import Path
import json
import math
import numpy as np
from PIL import Image, ImageDraw
from 검토_양발보행_정적 import render_triangle, smooth, rotate
from 시안_발교대_미적용 import protected_hashes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/visual_review/player_walk_20261012/발교대_발목보존_미적용시안'
# 앞꿈치가 치켜 올라간 0번 자세 대신 원화의 평평한 신발 자세를 선택한다.
DESIGN = {
    'black': {'frame':6,'cut':440,'cover':470,'split':300,'A':{'hip':(282,440),'ankle':(242,525),'sole':(253,556)},
              'B':{'hip':(330,440),'ankle':(329,526),'sole':(350,556)}},
    'white': {'frame':7,'cut':450,'cover':496,'split':310,'A':{'hip':(270,450),'ankle':(248,527),'sole':(266,561)},
              'B':{'hip':(338,450),'ankle':(338,529),'sole':(355,556)}},
}
FOOT_POINTS = {}
LEG_IMAGES = {}
ORIGINAL_LEG_MASKS = {}
FRAME_DURATIONS = 50
for _design in DESIGN.values():
    # 원화에서 종아리ㆍ발목이 곧게 이어진 쪽을 두 다리의 기준으로 쓴다.
    # 비스듬한 뒷다리를 반대 방향으로 돌리면 앞꿈치가 과하게 치켜 올라가기 때문이다.
    _design['A'] = dict(_design['B'])


def source_frame(color, frame):
    sheet = Image.open(ROOT/f'assets/characters/paint_head_a/{color}_walk.png')
    x,y = (frame%4)*640,(frame//4)*640
    return sheet.crop((x,y,x+640,y+640)).convert('RGBA')


def foot_position(q):
    # 기본 시안의 박자를 보존한다. 박자 비교 도구는 이 함수만 별도로 교체한다.
    return 320-60*math.cos(q*math.tau)


def pose(phase,color,side):
    q=(phase+(0 if side=='A' else .5))%1
    # 발목을 따로 꺾지 않고 다리 전체를 같은 각도로 움직여 신발과 종아리의 연결을 보존한다.
    foot_x=foot_position(q)
    rest=DESIGN[color][side]
    source_hip=np.array(rest['hip'])
    source_axis=np.array(rest['ankle'])-source_hip
    angle=math.atan2(165.,foot_x-320)-math.atan2(source_axis[1],source_axis[0])
    sole_offset=rotate(np.array(rest['sole'])-source_hip,angle)
    rotated_feet=np.array([rotate(p-source_hip,angle) for p in FOOT_POINTS[color,side]])
    # 가장 낮은 뒤꿈치/앞꿈치가 바닥에 닿게 한다. 신발 자체는 찌그러뜨리지 않는다.
    hip=np.array((foot_x-sole_offset[0],567.-float(rotated_feet[:,1].max())))
    return {'sole':hip+sole_offset,'ankle':hip+rotate(source_axis,angle),'hip':hip,'angle':angle}


def skin(p,target,rest,cut):
    # 코트 아래의 다리 전체를 강체로 움직인다. 발목ㆍ신발 사이 각도와 길이는 원화 그대로다.
    moved=target['hip']+rotate(p-np.array(rest['hip']),target['angle'])
    return p+(moved-p)*smooth(cut,cut+25,p[1])


def render(phase,color,original,render_scale=.5):
    design=DESIGN[color];cut=design['cut']
    size=int(640*render_scale)
    canvas=Image.new('RGBA',(size,size))
    # 두 신발 사이 실제 빈틈으로 나눈다. 검정 캐릭터의 뒷신발에 앞신발 조각이 섞이지 않게 한다.
    for side,bounds in (('A',(design['split'],460)),('B',(design['split'],460))):
        rest=design[side];target=pose(phase,color,side)
        leg_image=LEG_IMAGES[color,side]
        xx=np.linspace(*bounds,9)
        yy=sorted(set([cut,cut+3,cut+7,cut+12,cut+18,470,480,490,500,507,514,520,530,550,570,590]))
        yy=[y for y in yy if y>=cut]
        pts=[[np.array((x,y)) for x in xx] for y in yy]
        moved=[[skin(p,target,rest,cut) for p in row] for row in pts]
        for y in range(len(yy)-1):
            for x in range(8):
                for ids in (((y,x),(y,x+1),(y+1,x+1)),((y,x),(y+1,x+1),(y+1,x))):
                    tri=[pts[i][j] for i,j in ids]
                    box=(math.floor(min(p[0] for p in tri)),math.floor(min(p[1] for p in tri)),math.ceil(max(p[0] for p in tri))+1,math.ceil(max(p[1] for p in tri))+1)
                    if leg_image.crop(box).getchannel('A').getbbox() is not None:
                        render_triangle(canvas,leg_image,tri,[moved[i][j] for i,j in ids],render_scale=render_scale)
    # 같은 원화 프레임의 코트 경계를 덮어 연결선을 숨긴다. 상체의 추가 움직임은 없다.
    upper=original.copy();alpha=np.array(upper.getchannel('A'))
    legs=ORIGINAL_LEG_MASKS[color]
    alpha[design['cover']:][legs[design['cover']:] > 0]=0
    upper.putalpha(Image.fromarray(alpha));canvas.alpha_composite(upper.resize((size,size),Image.Resampling.LANCZOS))
    return canvas


def prepare_images():
    originals={c:source_frame(c,DESIGN[c]['frame']) for c in DESIGN}
    for color,original in originals.items():
        design=DESIGN[color]
        for side in ('A','B'):
            mask=Image.new('L',(640,640));d=ImageDraw.Draw(mask)
            if side=='A':
                d.rectangle((180,design['cut'],design['split']-1,590),fill=255)
            else:
                # 흰색 총의 호스가 다리 그림에 들어가 움직이지 않도록 신발/종아리 영역만 선택한다.
                right=365 if color=='white' else 380
                d.polygon([(design['split'],design['cut']),(right,design['cut']),(right,523),(430,531),(430,590),(design['split'],590)],fill=255)
            leg=original.copy();leg.putalpha(Image.fromarray(np.minimum(np.array(original.getchannel('A')),np.array(mask))))
            LEG_IMAGES[color,side]=leg
        ORIGINAL_LEG_MASKS[color]=np.maximum(np.array(LEG_IMAGES[color,'A'].getchannel('A')),np.array(LEG_IMAGES[color,'B'].getchannel('A')))
        # 회전 대상에서 코트/호스 픽셀을 제거한다. 원래 코트는 위 레이어에 그대로 남긴다.
        leg=LEG_IMAGES[color,'B'];alpha=np.array(leg.getchannel('A'))
        # 코트 바로 아래의 좁은 바지 연결부는 남겨 회전할 때 다리가 분리돼 보이지 않게 한다.
        alpha[:design['cover']-10]=0
        hip_x=int(design['B']['hip'][0])
        alpha[:design['cover'],:hip_x-20]=0
        alpha[:design['cover'],hip_x+20:]=0
        leg.putalpha(Image.fromarray(alpha))
        LEG_IMAGES[color,'A']=leg.copy()
        for side in ('A','B'):
            leg=LEG_IMAGES[color,side]
            ys,xs=np.where((np.array(leg.getchannel('A'))>200)&(np.indices((640,640))[0]>=520))
            FOOT_POINTS[color,side]=np.column_stack((xs,ys))[::8]
    return originals


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    before=protected_hashes()
    originals=prepare_images()
    frames=[];renders={c:[] for c in DESIGN};samples=[]
    poses=Image.new('RGBA',(1280,1280),'#444950')
    closeups=Image.new('RGBA',(1280,640),'#444950')
    for i in range(32):
        phase=i/32
        canvas=Image.new('RGBA',(640,640),'#444950');draw=ImageDraw.Draw(canvas)
        for row,color in enumerate(DESIGN):
            preview=render(phase,color,originals[color]);renders[color].append(preview)
            canvas.alpha_composite(preview,(0,row*320))
            zoom=preview.crop((85,220,235,295)).resize((320,160),Image.Resampling.NEAREST)
            canvas.alpha_composite(zoom,(320,row*320+95))
            draw.text((10,row*320+10),f'{color.upper()} / ANKLE PRESERVED',fill='white')
            draw.text((330,row*320+10),'A cyan / B amber = same feet',fill='white')
            for side,tint in (('A','#62d9f6'),('B','#ffc660')):
                target=pose(phase,color,side);x,y=target['sole']*.5
                sx,sy=320+(x-85)*320/150,row*320+95+(y-220)*160/75
                draw.ellipse((sx-3,sy-3,sx+3,sy+3),fill=tint)
                draw.text((sx-4,sy+6),side,fill=tint)
                samples.append({'color':color,'frame':i,'foot':side,'x':float(target['sole'][0]),'y':float(target['sole'][1])})
                # 발목ㆍ신발에 속한 두 점 사이 벡터가 어떤 위상에서도 원본과 같은지 확인한다.
                a=np.array(DESIGN[color][side]['ankle'])+np.array((0,2))
                b=a+np.array((20,20));delta=skin(b,target,DESIGN[color][side],DESIGN[color]['cut'])-skin(a,target,DESIGN[color][side],DESIGN[color]['cut'])
                assert np.allclose(delta,rotate(b-a,target['angle']))
            if i%4==0:
                k=i//4;position=((k%4)*320,(row*2+k//4)*320)
                poses.alpha_composite(preview,position)
                ImageDraw.Draw(poses).text((position[0]+10,position[1]+10),f'{color} phase {phase:.3f}',fill='white')
                closeups.alpha_composite(zoom,((k%4)*320,(row*2+k//4)*160))
        frames.append(canvas.convert('RGB'))
        if i%8==0:print(f'Preview {i+1}/32',flush=True)
    frames[0].save(OUT/'발목보존_발교대.gif',save_all=True,append_images=frames[1:],duration=FRAME_DURATIONS,loop=0,optimize=False)
    poses.convert('RGB').save(OUT/'전체_8자세.png')
    closeups.convert('RGB').save(OUT/'발목_교차_8자세_확대.png')
    for color in DESIGN:
        sheet=Image.new('RGBA',(1280,1280))
        for i in range(16):sheet.alpha_composite(renders[color][i*2],((i%4)*320,(i//4)*320))
        sheet.save(OUT/f'{color}_발목보존_16frames.png')
        assert pose(0,color,'A')['sole'][0]<pose(0,color,'B')['sole'][0]
        assert pose(.5,color,'A')['sole'][0]>pose(.5,color,'B')['sole'][0]
    assert before==protected_hashes(),'게임 파일 변경 감지'
    (OUT/'검토.json').write_text(json.dumps({'game_files_unchanged':True,'engine_run':False,'ankle_boot_rigid_transform':True,'samples':samples},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Preview only; game files unchanged.',flush=True)


if __name__=='__main__':main()
