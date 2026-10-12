"""확인된 발 교대 시안을 원본 해상도 PNG와 걷기 리소스로 연결한다. Godot 실행 없음."""
import json
import re
from PIL import Image,ImageDraw
import 시안_발교대_발목보존 as preview
from 시안_발교대_박자 import foot_position

ROOT=preview.ROOT
ASSETS=ROOT/'assets/characters/paint_head_a'
OUT=ROOT/'docs/visual_review/player_walk_20261012/적용검토'


def animation_text(color):
    frames=', '.join('{\n"duration": 1.0,\n"texture": SubResource("'+color+'_walk_'+str(i)+'")\n}' for i in range(32))
    return '"frames": ['+frames+'],\n"loop": true,\n"name": &"'+color+'_walk",\n"speed": 40.0'


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    preview.foot_position=foot_position
    originals=preview.prepare_images()
    tank_source=(ASSETS/'tank_rects.gd').read_text(encoding='utf-8')
    old_tanks=json.loads(re.search(r'const FRAMES = (\{[^\n]+\})',tank_source).group(1))
    tank_rects={};review=[];images={}
    for color in ('black','white'):
        sheet=Image.new('RGBA',(2560,5120));images[color]=[]
        original_frame=preview.DESIGN[color]['frame']
        old_rect=old_tanks[color+'_walk'][original_frame]
        # 상체는 같은 원화 프레임이므로 탱크의 로컬 좌표를 새 아틀라스로 옮긴다.
        ox,oy=original_frame%4*640,original_frame//4*640
        local=[old_rect[0]*2560-ox,old_rect[1]*2560-oy,old_rect[2]*2560-ox,old_rect[3]*2560-oy]
        tank_rects[color+'_walk']=[]
        for i in range(32):
            frame=preview.render(i/32,color,originals[color],render_scale=1.)
            x,y=i%4*640,i//4*640;sheet.alpha_composite(frame,(x,y));images[color].append(frame)
            tank_rects[color+'_walk'].append([(x+local[0])/2560,(y+local[1])/5120,(x+local[2])/2560,(y+local[3])/5120])
        sheet.save(ASSETS/f'{color}_walk_cross.png')
        print(f'{color}: 32 full-resolution frames saved',flush=True)
    # 배열 생성자 대신 리터럴을 사용해 기존에 발생했던 상수식 오류를 피한다.
    data='extends RefCounted\n# 확인된 발 교대 시트의 박자와 프레임별 잉크 수위 좌표를 함께 보관한다.\nconst FPS := 40.0\nconst FOOT_CONTACT_FRAMES := [15, 31]\nconst FRAMES = '+json.dumps(tank_rects,separators=(',',':'))+'\n'
    (ASSETS/'walk_cycle_data.gd').write_text(data,encoding='utf-8')
    resource=ASSETS/'player_frames.tres';text=resource.read_text(encoding='utf-8')
    for color in ('black','white'):
        # 걷기 텍스처만 새 시트로 교체하고 대기/점프/발사/사망 자산은 보존한다.
        text,count=re.subn(r'\[ext_resource type="Texture2D"[^\n]* id="'+color+r'_walk"\]',f'[ext_resource type="Texture2D" path="res://assets/characters/paint_head_a/{color}_walk_cross.png" id="{color}_walk"]',text)
        assert count==1
        text=re.sub(r'\[sub_resource type="AtlasTexture" id="'+color+r'_walk_\d+"\]\s*atlas = ExtResource\("'+color+r'_walk"\)\s*region = Rect2\([^)]+\)\s*','',text)
        definitions=''.join(f'[sub_resource type="AtlasTexture" id="{color}_walk_{i}"]\natlas = ExtResource("{color}_walk")\nregion = Rect2({i%4*640}, {i//4*640}, 640, 640)\n\n' for i in range(32))
        text=text.replace('[resource]',definitions+'[resource]',1)
        pattern=r'"frames": \[\{\s*"duration": [\d.]+,\s*"texture": SubResource\("'+color+r'_walk_0"\).*?\}\],\s*"loop": true,\s*"name": &"'+color+r'_walk",\s*"speed": [\d.]+'
        text,count=re.subn(pattern,lambda _:animation_text(color),text,flags=re.S)
        assert count==1
    resource.write_text(text,encoding='utf-8')
    # 실제 연결된 PNG를 다시 읽어서 검토용 프레임을 만든다. 엔진 캡처로 부르지 않는다.
    loaded={c:Image.open(ASSETS/f'{c}_walk_cross.png') for c in images}
    contacts=Image.new('RGBA',(1280,1280),'#444950')
    for i in range(32):
        canvas=Image.new('RGBA',(640,640),'#444950');draw=ImageDraw.Draw(canvas)
        for row,color in enumerate(('black','white')):
            x,y=i%4*640,i//4*640
            frame=loaded[color].crop((x,y,x+640,y+640)).resize((320,320),Image.Resampling.LANCZOS)
            canvas.alpha_composite(frame,(0,row*320))
            canvas.alpha_composite(frame.crop((85,220,235,295)).resize((320,160),Image.Resampling.NEAREST),(320,row*320+95))
            draw.text((10,row*320+10),'CONNECTED ASSET / OFFLINE',fill='white')
            if i%4==0:
                k=i//4;p=(k%4*320,(row*2+k//4)*320)
                contacts.alpha_composite(frame,p)
        review.append(canvas.convert('RGB'))
    review[0].save(OUT/'적용시트_재생.gif',save_all=True,append_images=review[1:],duration=[20,30]*16,loop=0,optimize=False)
    contacts.convert('RGB').save(OUT/'적용시트_8자세.png')
    print('Walking resources connected; Godot not run.',flush=True)


if __name__=='__main__':main()
