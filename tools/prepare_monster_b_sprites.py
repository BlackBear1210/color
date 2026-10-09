"""힉스필드 B 몬스터 원본을 엔진 실행 없이 멱등하게 프레임으로 정리한다."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/visual_review/monster_b_sprites_20261008/source'
OUT = ROOT / 'assets/characters/paint_beast_b'
REVIEW = SOURCE.parent
SIZE = 512
FOOT = 452


def clean(frame):
    # 생성 원본의 반투명 후광을 지워 검정/흰색 배경에서 테두리가 번지지 않게 한다.
    a = np.array(frame)
    alpha = a[:, :, 3]
    solid = Image.fromarray(np.uint8(alpha >= 235) * 255)
    # 유리 내부는 원래 반투명하다. 닫힌 내부를 채워 유리가 구멍처럼 잘리지 않게 한다.
    # 외부/내부 구분만 작은 마스크로 계산해 큰 원본에서도 불필요한 픽셀 순회를 줄인다.
    flood = solid.resize((max(1,solid.width//4),max(1,solid.height//4)),Image.Resampling.NEAREST)
    ImageDraw.floodfill(flood, (0,0), 128)
    enclosed = np.array(flood.resize(solid.size,Image.Resampling.NEAREST)) != 128
    edge = np.array(solid.filter(ImageFilter.MaxFilter(5))) > 0
    a[:, :, 3] = np.where(enclosed, np.minimum(alpha.astype(float)*255/254,255),
                          np.where(edge,np.clip((alpha.astype(float)-160)*255/94,0,255),0))
    gray = np.array(Image.fromarray(a).convert('L'))
    a[:, :, :3] = gray[:, :, None]
    frame = Image.fromarray(a)
    return frame, solid.getbbox()


def normalize(name):
    original = Image.open(SOURCE / f'{name}.png').convert('RGBA')
    w, h = original.size
    result, boxes = [], []
    # 원본 격자에서 매번 같은 비율로 읽으므로 재실행해도 변형이 누적되지 않는다.
    for i in range(8):
        x, y = i % 4, i // 4
        frame = original.crop((x*w//4, y*h//2, (x+1)*w//4, (y+1)*h//2))
        frame, box = clean(frame)
        result.append(frame)
        boxes.append(box)
    factor = min(414 / max(b[2]-b[0] for b in boxes), 360 / max(b[3]-b[1] for b in boxes))
    tiles = []
    for frame, box in zip(result, boxes):
        # 모든 모션의 발바닥을 동일한 지점에 두고 프레임 내부의 스케일은 유지한다.
        resized = frame.resize((round(frame.width*factor), round(frame.height*factor)), Image.Resampling.LANCZOS)
        pos = (round(256-(box[0]+box[2])*factor/2), round(FOOT-box[3]*factor))
        tile = Image.new('RGBA', (SIZE, SIZE))
        tile.paste(resized, pos)
        tiles.append(tile)
    return tiles


def save_tiles(name, tiles):
    atlas = Image.new('RGBA', (SIZE*4, SIZE*2))
    folder = OUT / 'frames' / name
    folder.mkdir(parents=True, exist_ok=True)
    for i, tile in enumerate(tiles):
        atlas.paste(tile, (i%4*SIZE, i//4*SIZE))
        tile.save(folder / f'{i:02d}.png')
    atlas.save(OUT / f'{name}.png')


def black_body(tile, glass=None):
    # 부족한 생성 크레딧을 대신해 동일 프레임의 몸만 명암 변환한다. 유리와 금속은 유지한다.
    a = np.array(tile)
    gray = a[:,:,0].copy()
    yy, xx = np.indices(gray.shape)
    # 움직이는 통을 수평선으로 자르면 검정 변환 경계가 보이므로 통의 사각형을 따라 제외한다.
    glass=glass or [(173,121),(276,122),(273,203),(165,205)]
    equipment=Image.new('L',(SIZE,SIZE))
    p0,p1,p2,p3=glass
    ImageDraw.Draw(equipment).polygon([(p0[0]-55,p0[1]-22),(p1[0]+65,p1[1]-22),(p2[0]+65,p2[1]+22),(p3[0]-55,p3[1]+22)],fill=255)
    glass_mask=Image.new('L',(SIZE,SIZE))
    ImageDraw.Draw(glass_mask).polygon(glass,fill=255)
    # 유리 밖의 밝은 천까지 장비 영역에 묶이지 않도록 해 흰 어깨 조각이 남는 것을 막는다.
    body = ((np.array(equipment)==0) | ((gray>140)&(np.array(glass_mask)==0))) & (a[:,:,3]>0)
    a[:,:,:3] = np.where(body[:,:,None],a[:,:,:3]*.23,a[:,:,:3]).astype('uint8')
    # 흰 얼굴의 작은 검정 눈 덩어리만 찾아 검정 얼굴에서도 밝게 읽히게 한다.
    mask = (gray < 45) & (xx>350) & (xx<487) & (yy>230) & (yy<360) & (a[:,:,3]>200)
    seen = np.zeros_like(mask)
    for y,x in zip(*np.nonzero(mask)):
        if seen[y,x]:
            continue
        stack, group = [(int(y),int(x))], []
        seen[y,x] = True
        while stack:
            cy,cx = stack.pop()
            group.append((cy,cx))
            for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
                ny,nx = cy+dy,cx+dx
                if 0<=ny<SIZE and 0<=nx<SIZE and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True
                    stack.append((ny,nx))
        gx=[v[1] for v in group]
        gy=[v[0] for v in group]
        if 6 <= len(group) <= 100 and max(gx)-min(gx)<15 and max(gy)-min(gy)<20 and min(gx)>390:
            for ey,ex in group:
                a[ey,ex,:3]=225
    return Image.fromarray(a)


def black_shoot(tile, glass):
    a=np.array(black_body(tile,glass))
    mask=Image.new('L',(SIZE,SIZE))
    p0,p1,p2,p3=glass
    # 각 프레임의 기울어진 유리 안쪽 하반부만 칠해 흰색 발사 물감을 검정으로 바꾼다.
    left=((p0[0]+p3[0])/2,(p0[1]+p3[1])/2)
    right=((p1[0]+p2[0])/2,(p1[1]+p2[1])/2)
    ImageDraw.Draw(mask).polygon([left,right,p2,p3],fill=255)
    liquid=np.array(mask)>0
    value=10+a[:,:,0].astype(float)*.065
    for c in range(3):
        a[:,:,c]=np.where(liquid,value,a[:,:,c]).astype('uint8')
    return Image.fromarray(a)


def fill_tiles(base, paint):
    # 정지 몸체 위에 정확한 액면을 만든다. 첫 발의 끝과 둘째 발의 시작은 같은 50%다.
    mask = Image.new('L',(SIZE,SIZE))
    ImageDraw.Draw(mask).polygon([(173,121),(276,122),(273,203),(165,205)],fill=255)
    inside = np.array(mask)>0
    yy,xx = np.indices((SIZE,SIZE))
    tiles=[]
    for level in (0,1/6,1/3,.5,.5,2/3,5/6,1):
        a=np.array(base)
        # 곡선 한두 픽셀로 물감 표면의 작은 출렁임을 표현하되 수위는 단조롭게 높인다.
        surface=205-round(84*level)+np.sin(xx/13)*1.2
        liquid=inside & (yy>=surface) if level else np.zeros_like(inside)
        source_gray=a[:,:,0].astype(float)
        value=205+source_gray*.13 if paint=='white' else 10+source_gray*.065
        for c in range(3):
            a[:,:,c]=np.where(liquid,value,a[:,:,c]).astype('uint8')
        a[:,:,3]=np.where(liquid,255,a[:,:,3])
        tiles.append(Image.fromarray(a))
    return tiles


def resources(sheets):
    lines=['[gd_resource type="SpriteFrames" format=3]','']
    for name in sheets:
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/paint_beast_b/{name}.png" id="{name}"]')
    for name in sheets:
        for i in range(8):
            lines += ['',f'[sub_resource type="AtlasTexture" id="{name}_{i}"]',f'atlas = ExtResource("{name}")',f'region = Rect2({i%4*SIZE}, {i//4*SIZE}, {SIZE}, {SIZE})']
    animations=[]
    for color in ('black','white'):
        # 첫 발/둘째 발을 따로 재생하면 첫 발만 맞은 몬스터가 절반 수위를 유지할 수 있다.
        for motion,indices,loop,speed in [('walk',range(8),True,10),('fill',range(8),False,12),('shoot',range(8),False,12),('fill_first',range(4),False,12),('fill_second',range(4,8),False,12),('return',range(7,-1,-1),False,12),('idle',[0],True,1)]:
            source=f'{color}_{"walk" if motion=="idle" else "fill" if motion in ("fill_first","fill_second","return") else motion}'
            frames=', '.join('{"duration": 1.0, "texture": SubResource("'+source+'_'+str(i)+'")}' for i in indices)
            animations.append('{"frames": ['+frames+'], "loop": '+str(loop).lower()+', "name": &"'+color+'_'+motion+'", "speed": '+str(float(speed))+'}')
    lines += ['','[resource]','animations = ['+',\n'.join(animations)+']']
    (OUT/'monster_frames.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')


def preview(sheets):
    images=[]
    names=['black_walk','black_fill','black_shoot','white_walk','white_fill','white_shoot']
    for step in range(16):
        canvas=Image.new('RGB',(960,610),'#626262')
        d=ImageDraw.Draw(canvas)
        for j,name in enumerate(names):
            i=step%8 if not name.endswith('fill') else [0,1,2,3,3,3,3,4,5,6,7,7,7,7,7,7][step]
            tile=sheets[name][i].resize((300,300),Image.Resampling.LANCZOS)
            x,y=j%3*320,j//3*305
            canvas.paste(tile,(x+10,y+10),tile)
            d.text((x+15,y+10),name,fill='white')
        images.append(canvas)
    images[0].save(REVIEW/'animations_preview.gif',save_all=True,append_images=images[1:],duration=100,loop=0)
    images[7].save(REVIEW/'sprites_overview.png')


def validate(sheets):
    # 투명 여백과 정렬·프레임 수를 검증한다. 실제 엔진 재생 검사와는 구분한다.
    for name,tiles in sheets.items():
        assert len(tiles)==8
        assert Image.open(OUT/f'{name}.png').size==(2048,1024)
        for i,tile in enumerate(tiles):
            a=np.array(tile)
            yy,xx=np.nonzero(a[:,:,3]>200)
            assert len(yy)>5000,(name,i,'empty')
            assert 449<=yy.max()<=455,(name,i,'foot',yy.max())
            assert xx.min()>3 and xx.max()<509,(name,i,'clipped')
            assert a[0,0,3]==0 and a[-1,-1,3]==0
            assert np.max(a[:,:,:3].max(axis=2)-a[:,:,:3].min(axis=2))==0
    print('6 sheets / 48 frames: alpha, bounds, foot alignment, monochrome passed')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets={name:normalize(name) for name in ('black_walk','white_walk','white_fill','white_shoot')}
    empty=sheets['white_fill'][0]
    sheets['white_fill']=fill_tiles(empty,'black')
    sheets['black_fill']=fill_tiles(black_body(empty),'white')
    glasses=[[(154,124),(286,124),(282,222),(153,220)],[(166,144),(298,170),(282,248),(154,224)],[(158,156),(298,178),(280,264),(156,248)],[(158,182),(288,172),(296,266),(158,286)],[(152,162),(292,172),(286,266),(152,266)],[(154,130),(282,126),(282,218),(154,232)],[(156,120),(284,130),(284,226),(156,222)],[(156,136),(288,142),(288,238),(156,234)]]
    sheets['black_shoot']=[black_shoot(tile,glass) for tile,glass in zip(sheets['white_shoot'],glasses)]
    for name,tiles in sheets.items():
        save_tiles(name,tiles)
        # 검토 이미지는 실제 엔진 캡처가 아니라 정리된 자산을 회색 배경에 합성한 것이다.
        canvas = Image.new('RGB', (1024, 512), '#666666')
        for i, tile in enumerate(tiles):
            canvas.paste(tile.resize((256,256)), (i%4*256, i//4*256), tile.resize((256,256)))
        canvas.save(REVIEW / f'{name}_review.jpg')
    resources(sheets)
    preview(sheets)
    validate(sheets)
    manifest={'frame_size':[SIZE,SIZE],'grid':[4,2],'frames_per_motion':8,'foot_y':FOOT,'direction':'right','fill_levels':[0,1/6,1/3,.5,.5,2/3,5/6,1], 'shoot_release_frame':4,'sources':{'black_fill':'white_fill frame 0; palette + liquid mask','black_shoot':'white_shoot palette conversion'},'engine_verified':False}
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('스프라이트 6장과 Godot SpriteFrames 리소스 정리 완료')


if __name__ == '__main__':
    main()
