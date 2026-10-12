"""Godot 없이 걷기 자산 연결, 수위 좌표, 기존 동작 보존을 확인한다."""
from pathlib import Path
import json
import re
import hashlib
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/characters/paint_head_a'
OUT=ROOT/'docs/visual_review/player_walk_20261012/적용검토'


def animations(text):
    return {m.group(2):m.group(1) for m in re.finditer(r'("frames": \[.*?\],\s*"loop": (?:true|false),\s*"name": &"([^"]+)",\s*"speed": [\d.]+)',text,re.S)}


def main():
    checks={}
    text=(ASSETS/'player_frames.tres').read_text(encoding='utf-8')
    before=(OUT/'before/assets/characters/paint_head_a/player_frames.tres').read_text(encoding='utf-8')
    old,new=animations(before),animations(text)
    assert old.keys()==new.keys()
    for name in old:
        if not name.endswith('_walk'):assert old[name]==new[name],name
    checks['대기_점프_낙하_착지_발사_밀기_사망_리소스_보존']=True
    data=(ASSETS/'walk_cycle_data.gd').read_text(encoding='utf-8')
    rects=json.loads(re.search(r'const FRAMES = (\{[^\n]+\})',data).group(1))
    errors={};feet={}
    for color,source_frame in [('black',6),('white',7)]:
        image=Image.open(ASSETS/f'{color}_walk_cross.png').convert('RGBA')
        assert image.size==(2560,5120)
        assert f'path="res://assets/characters/paint_head_a/{color}_walk_cross.png" id="{color}_walk"' in text
        entries=re.findall(r'\[sub_resource type="AtlasTexture" id="'+color+r'_walk_(\d+)"\]\s*atlas = ExtResource\("'+color+r'_walk"\)\s*region = Rect2\(([^)]+)\)',text)
        assert len(entries)==32 and len(rects[color+'_walk'])==32
        assert len(re.findall(r'SubResource\("'+color+r'_walk_\d+"\)',new[color+'_walk']))==32
        assert '"speed": 40.0' in new[color+'_walk']
        original=Image.open(ASSETS/f'{color}_walk.png').convert('RGBA')
        sx,sy=source_frame%4*640,source_frame//4*640
        source=np.array(original.crop((sx,sy,sx+640,sy+430)))
        approved=Image.open(ROOT/f'docs/visual_review/player_walk_20261012/발교대_박자조정_미적용시안/{color}_발목보존_16frames.png').convert('RGBA')
        errors[color]=[];feet[color]=[]
        for index,region in entries:
            i=int(index);actual=list(map(int,region.split(',')))
            x,y=i%4*640,i//4*640
            assert actual==[x,y,640,640]
            frame=image.crop((x,y,x+640,y+640));pixels=np.array(frame)
            opaque=source[:,:,3]>0
            assert np.array_equal(pixels[:430][opaque],source[opaque]),'상체 변형 감지'
            r=rects[color+'_walk'][i]
            assert x/2560<r[0]<r[2]<(x+640)/2560
            assert y/5120<r[1]<r[3]<(y+640)/5120
            assert (r[3]*5120-y)<430
            ys=np.where(pixels[:,:,3]>200)[0];feet[color].append(int(ys.max()))
            if i%2==0:
                j=i//2;expected=approved.crop((j%4*320,j//4*320,j%4*320+320,j//4*320+320))
                scaled=frame.resize((320,320),Image.Resampling.LANCZOS)
                # 투명 픽셀의 숨은 RGB 대신 회색 배경 위 실제 보이는 차이를 비교한다.
                def visible(im):
                    bg=Image.new('RGBA',im.size,'#444950');bg.alpha_composite(im);return np.array(bg.convert('RGB')).astype(float)
                error=float(np.abs(visible(scaled)-visible(expected)).mean())
                errors[color].append(error)
                assert error<3.,f'시안 차이 과다: {color}/{i}: {error}'
        # 원본 걷기 그림은 별도 파일로 남아 있다.
        backup=ROOT/f'docs/visual_review/player_walk_20261012/before/{color}_walk.png'
        assert hashlib.sha256(backup.read_bytes()).digest()==hashlib.sha256((ASSETS/f'{color}_walk.png').read_bytes()).digest()
    checks['흑백32프레임_아틀라스범위_수위좌표']=True
    checks['40fps_한주기0_8초']=True
    checks['원본걷기그림_보존']=True
    checks['상체_픽셀_보존']=True
    checks['확인된시안과_해상도외_일치']=True
    anim=(ROOT/'scripts/paint_head_anim.gd').read_text(encoding='utf-8')
    sound=(ROOT/'scripts/플레이어_효과음.gd').read_text(encoding='utf-8')
    shader=(ROOT/'shaders/paint_head.gdshader').read_text(encoding='utf-8')
    assert '플레이어_양발보행.gd' not in anim and '_다리_앞뒤_갱신' not in anim
    assert 'walk_rig_active' not in shader and 'walk_rig_cut_y' not in shader
    assert '보행_발디딤_프레임' in anim and '보행_발디딤_프레임' in sound
    assert 'FOOT_CONTACT_FRAMES := [15, 31]' in data
    assert 'submerged_pixel(world_pos)' in shader and 'region_color - sheet_color' in shader
    assert all(ord(c)<128 for c in shader)
    checks['예전다리변형_중복차단']=True
    checks['발소리_0_4초간격_새프레임연결']=True
    checks['색분할_물가림_유지_셰이더ASCII']=True
    report={'engine_run':False,'checks':checks,'preview_mean_rgb_errors':errors,'foot_bottom_pixels':feet}
    (OUT/'정적확인.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(checks)} static checks passed; Godot not run.')
    print({color:max(values) for color,values in errors.items()})


if __name__=='__main__':main()
