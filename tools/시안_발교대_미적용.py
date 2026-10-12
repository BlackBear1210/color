"""원본 그림을 이용한 발 교대 시안. 게임 파일을 수정하거나 Godot을 실행하지 않는다."""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image, ImageDraw
from 검토_양발보행_정적 import render_triangle, smooth, rotate

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/visual_review/player_walk_20261012/발교대_무릎굽힘없음_미적용시안'
COLORS = ('black', 'white')
# 원화의 두 다리를 구분해서 추적한다. A/B는 앞발/뒷발이라는 고정 역할이 아니다.
REST = {
    'black': {'cut': 470, 'A': [(275,470),(258,500),(243,529),(255,556),-.12],
              'B': [(355,470),(375,501),(385,530),(405,564),.32]},
    'white': {'cut': 478, 'A': [(268,478),(252,503),(250,529),(258,556),-.09],
              'B': [(351,478),(359,503),(355,530),(389,562),.12]},
}


def protected_hashes():
    # 시안 제작 전후에 실제 게임의 그림ㆍ씬ㆍ스크립트 전체가 그대로인지 확인한다.
    paths = [ROOT / 'project.godot']
    for folder in ('assets', 'scripts', 'scenes', 'shaders'):
        paths.extend(p for p in (ROOT / folder).rglob('*') if p.is_file())
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def pose(phase, color, side):
    hip, knee, ankle, sole, boot_angle = REST[color][side]
    hip, knee, ankle, sole = map(lambda p: np.array(p, dtype=float), (hip,knee,ankle,sole))
    # A는 뒤에서 앞으로, B는 앞에서 뒤로 이동한다. 반 주기 후 역할이 바뀐다.
    q = (phase + (0 if side == 'A' else .5)) % 1
    foot_x = 320 - 72 * math.cos(q * math.tau)
    # 사용자 요청대로 교차 때의 무릎 굽힘과 이에 맞춘 발 들기를 제거한다.
    # 발은 높이를 유지한 채 서로 앞뒤 위치만 바꾼다.
    sole_target = np.array((foot_x, 567.))
    ankle_target = sole_target - rotate(sole - ankle, boot_angle)
    # 절단선의 벌어진 허벅지 위치를 골반으로 오해하면 다리가 X자로 과하게 꼬인다.
    # 코트 아래의 축을 조금 모으되 원화와 접하는 맨 위 픽셀은 skin에서 고정한다.
    hip_target = np.array((305 if side == 'A' else 330, hip[1]),dtype=float)
    axis = ankle_target - hip_target
    # 모든 위상에서 골반ㆍ무릎ㆍ발목을 직선에 놓아 추가 굽힘이 생기지 않게 한다.
    knee_target = hip_target + axis * .48
    return {'hip':hip_target, 'knee':knee_target, 'ankle':ankle_target,
            'sole':sole_target, 'bend':0., 'boot_angle':boot_angle,
            'rest':(hip,knee,ankle,sole)}


def segment(p, a, b, ta, tb):
    direction = b - a
    along = np.dot(p-a,direction) / np.dot(direction,direction)
    normal = np.array((-direction[1],direction[0])) / np.linalg.norm(direction)
    perpendicular = np.dot(p-a,normal)
    target_axis = tb-ta
    target_normal = np.array((-target_axis[1],target_axis[0])) / np.linalg.norm(target_axis)
    return ta + along*target_axis + perpendicular*target_normal


def skin(p, target, cut):
    hip, knee, ankle, sole = target['rest']
    thigh = segment(p,hip,knee,target['hip'],target['knee'])
    calf = segment(p,knee,ankle,target['knee'],target['ankle'])
    moved = thigh*(1-smooth(knee[1]-5,knee[1]+5,p[1])) + calf*smooth(knee[1]-5,knee[1]+5,p[1])
    boot = target['ankle'] + rotate(p-ankle,target['boot_angle'])
    moved = moved*(1-smooth(508,520,p[1])) + boot*smooth(508,520,p[1])
    # 코트와 이어지는 절단선은 고정해 경계가 벌어지지 않게 한다.
    return p + (moved-p)*smooth(cut,cut+14,p[1])


def render(phase, color, original):
    cut = REST[color]['cut']
    upper = original.copy()
    alpha = np.array(upper.getchannel('A'))
    alpha[cut:] = 0
    upper.putalpha(Image.fromarray(alpha))
    canvas = Image.new('RGBA',(320,320))
    for side, bounds in (('A',(180,321)),('B',(321,490))):
        target = pose(phase,color,side)
        xx = np.linspace(*bounds,9)
        yy = sorted(set([cut,cut+7,cut+14,490,500,508,514,520,530,550,570,590]))
        yy = [y for y in yy if y >= cut]
        pts = [[np.array((x,y)) for x in xx] for y in yy]
        moved = [[skin(p,target,cut) for p in row] for row in pts]
        for y in range(len(yy)-1):
            for x in range(8):
                for indices in (((y,x),(y,x+1),(y+1,x+1)),((y,x),(y+1,x+1),(y+1,x))):
                    tri = [pts[i][j] for i,j in indices]
                    box = (math.floor(min(p[0] for p in tri)),math.floor(min(p[1] for p in tri)),math.ceil(max(p[0] for p in tri))+1,math.ceil(max(p[1] for p in tri))+1)
                    if original.crop(box).getchannel('A').getbbox() is not None:
                        render_triangle(canvas,original,tri,[moved[i][j] for i,j in indices])
    canvas.alpha_composite(upper.resize((320,320),Image.Resampling.LANCZOS))
    return canvas


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    before = protected_hashes()
    originals = {c:Image.open(ROOT/f'assets/characters/paint_head_a/{c}_walk.png').crop((0,0,640,640)).convert('RGBA') for c in COLORS}
    frames, measures = [], []
    keyposes = Image.new('RGBA',(1280,640),'#444950')
    for i in range(32):
        phase = i/32
        canvas = Image.new('RGBA',(640,640),'#444950')
        draw = ImageDraw.Draw(canvas)
        for row,color in enumerate(COLORS):
            preview = render(phase,color,originals[color])
            canvas.alpha_composite(preview,(0,row*320))
            # 오른쪽 확대는 관찰용이다. 게임에는 점ㆍ색ㆍ설명을 넣지 않는다.
            zoom = preview.crop((80,210,250,295)).resize((320,160),Image.Resampling.NEAREST)
            canvas.alpha_composite(zoom,(320,row*320+95))
            draw.line((0,row*320+284,310,row*320+284),fill='#8d9298')
            draw.text((10,row*320+10),f'{color.upper()} / PROPOSAL ONLY',fill='white')
            draw.text((330,row*320+10),'A cyan / B amber = same feet',fill='white')
            for side,tint in (('A','#62d9f6'),('B','#ffc660')):
                target = pose(phase,color,side)
                x,y = target['sole']*.5
                sx,sy = 320+(x-80)*320/170,row*320+95+(y-210)*160/85
                draw.ellipse((sx-4,sy-4,sx+4,sy+4),fill=tint)
                draw.text((sx-4,sy+6),side,fill=tint)
                measures.append({'color':color,'frame':i,'foot':side,'x':float(target['sole'][0]),'y':float(target['sole'][1]),'knee_bend_window':target['bend']})
            if i in (0,8,16,24):
                keyposes.alpha_composite(preview,((i//8)*320,row*320))
                label = ('A BACK / B FRONT','CROSS / NO BEND','A FRONT / B BACK','CROSS / NO BEND')[i//8]
                ImageDraw.Draw(keyposes).text(((i//8)*320+10,row*320+10),label,fill='white')
        frames.append(canvas.convert('RGB'))
        if i%8 == 0:
            print(f'Preview {i+1}/32',flush=True)
    frames[0].save(OUT/'발교대_시안.gif',save_all=True,append_images=frames[1:],duration=60,loop=0,optimize=False)
    keyposes.convert('RGB').save(OUT/'발교대_주요자세.png')
    # 16프레임 전체를 투명 배경 시트로 따로 제공한다. 게임 리소스에는 연결하지 않는다.
    for color in COLORS:
        sprite_sheet = Image.new('RGBA',(1280,1280))
        for i in range(16):
            sprite_sheet.alpha_composite(render(i/16,color,originals[color]),((i%4)*320,(i//4)*320))
        sprite_sheet.save(OUT/f'{color}_발교대_시안_16frames.png')
    unchanged = before == protected_hashes()
    assert unchanged, '게임 파일 변경 감지'
    # 두 발이 반 주기마다 앞뒤 순서를 실제로 바꾸는지 숫자로 확인한다.
    for color in COLORS:
        assert pose(0,color,'A')['sole'][0] < pose(0,color,'B')['sole'][0]
        assert pose(.5,color,'A')['sole'][0] > pose(.5,color,'B')['sole'][0]
        for side in ('A','B'):
            for i in range(32):
                target = pose(i/32,color,side)
                assert target['bend'] == 0
                assert target['sole'][1] == 567.
                assert np.allclose(target['knee'],target['hip']+(target['ankle']-target['hip'])*.48)
    (OUT/'검토.json').write_text(json.dumps({'game_files_unchanged':unchanged,'engine_run':False,'frame_count':32,'frame_duration_ms':60,'samples':measures},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Preview only; game files unchanged.',flush=True)


if __name__ == '__main__':
    main()
