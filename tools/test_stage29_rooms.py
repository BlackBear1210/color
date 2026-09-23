"""새 방 연결형 2-9 정적 검수. 실제 Godot 이동/색/호퍼 혼합 검증을 대신하지 않는다."""
from pathlib import Path
import re,math,json
P=Path('scenes/world_2_클로드/stage_2-9.tscn');s=P.read_text(encoding='utf-8')
def vec(b):return tuple(map(float,re.search(r'position = Vector2\(([^)]+)\)',b)[1].split(',')))
rs={k:b for k,b in re.findall(r'^\[sub_resource[^\n]*id="([^"]+)"\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S)}
nodes={}
for h,b in re.findall(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S):
    a=dict(re.findall(r'(\w+)="([^"]*)"',h));key=(a.get('parent',''),a['name']);assert key not in nodes;nodes[key]=(h,b)
polys={};bounds={}
for (parent,name),(h,b) in nodes.items():
    if parent!='지형':continue
    ident=re.search(r'_points = SubResource\("([^"]+)"\)',b)[1]
    pts=[vec(rs[k]) for k in re.findall(r'\d+: SubResource\("([^"]+)"\)',rs[ident])]
    assert pts[0]==pts[-1],name
    collision=nodes[(f'지형/{name}/StaticBody2D','CollisionPolygon2D')][1]
    actual=list(map(float,re.search(r'polygon = PackedVector2Array\(([^)]+)\)',collision)[1].split(',')))
    assert actual==[v for p in pts[:-1] for v in p],name
    ox,oy=vec(b);ps=[(x+ox,y+oy) for x,y in pts[:-1]];polys[name]=ps
    bounds[name]=(min(x for x,y in ps),min(y for x,y in ps),max(x for x,y in ps),max(y for x,y in ps))
assert len(polys)==27
# 실제 저장 윤곽의 AABB에 플레이어44×96을 대입한 보수적 궤적 검사.
# 움직이는 장치·원웨이 판정·가감속·색 전환은 별도 엔진 검증 대상이다.
def arc(a,b):
    ax,ay,ar,_=bounds[a];bx,by,br,_=bounds[b];direction=1 if bx>ax else -1
    start=ar-24 if direction==1 else ax+24;end=bx+24 if direction==1 else br-24
    rise=ay-by;g=1901.25;v=780.;t=(v+math.sqrt(v*v-2*g*rise))/g
    speed=abs(end-start)/t;assert speed<=390,(a,b,speed)
    for i in range(161):
        z=t*i/160;x=start+(end-start)*i/160;y=ay-v*z+.5*g*z*z
        # 접촉면 자체는 통과로 세되 0.5px 이상의 실체 침범은 실패 처리한다.
        body=(x-21.5,y-95.5,x+21.5,y-.5)
        for name,(l,top,r,bot) in bounds.items():
            assert not(body[0]<r-.1 and body[2]>l+.1 and body[1]<bot-.1 and body[3]>top+.1),(a,b,name,i)
    return round(speed,1)
for a,b in [('A_출발','A_징검'),('A_징검','A_갱도접근'),('G_출발','G_흰발판'),('G_흰발판','G_검정높은발판'),('G_검정높은발판','G_출구길')]:print('arc',a,b,arc(a,b))
print('arc 외곽 복귀',arc('E_외곽복귀발판','E_물받이바닥'))
assert bounds['외벽_오른쪽위'][3]==1792 and bounds['외벽_오른쪽아래'][1]==2240
for prefix in ['B_상승','F_상승']:
    steps=[(n,vec(b)) for (p,n),(h,b) in nodes.items() if p=='장치' and n.startswith(prefix)]
    for (n,a),(m,b) in zip(steps,steps[1:]):
        assert a[1]-b[1]==128 and abs(a[0]-b[0])==64
        assert a[1]-b[1]-16>=112,'머리 공간'
        assert abs(a[0]-b[0])+44<160*(1+math.sqrt(1-128/160)),'128 상승 도약 예산'
    for n,_ in steps:assert 'one_way_collision = true' in nodes[(f'장치/{n}','충돌')][1]
for n in ['C_검정공급','C_흰공급']:
    b=nodes[('장치',n)][1];assert '"호퍼_유입" = true' in b and 'Vector2(64, 524)' in b
assert 2688+524==3364-164+12,'호퍼 입구 물 겹침'
assert 3364+112*(164/328)==3420,'호퍼 노즐/출력 정렬'
assert bounds['E_진입수문']==(2432,3200,2560,3712)
assert bounds['E_수문아래벽'][1]==3712 and bounds['E_수문위벽'][3]==3200
assert 'Vector2(0, -512)' in nodes[('장치','C_배수문버튼')][1]
assert bounds['E_기계실'][2]==3648 and 3968-3648+44>320,'연결 발판 없이 바로 승강기 점프 불가'
assert 'Vector2(0, -256)' in nodes[('장치','E_연결버튼')][1]
assert len([n for p,n in nodes if '왕복톱' in n])==2
assert '"점프_높이_칸" = 10.0' in nodes[('.','Player')][1]
print('PASS: 27 SS2D/충돌, 6개 몸통 궤적, 원웨이 상승, 호퍼 입출구, 수문/연결 발판/출구; 엔진 미실행')

# 저장 씬에서 바로 배치도를 그린다. 참조 이미지를 편집하는 작업이 아니다.
from PIL import Image,ImageDraw,ImageFont
scale=.18;im=Image.new('RGB',(1320,730),'#20242b');d=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',18);small=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',13)
def xy(x,y):return(24+x*scale,80+(y-1408)*scale)
for name,ps in polys.items():
    h=nodes[('지형',name)][0];fill='#ddd9cf' if '"white"' in h else '#687482'
    if name in ['E_진입수문','E_연결발판']:fill='#e6ae64'
    d.polygon([xy(x,y) for x,y in ps],fill=fill,outline='#a9b1ba')
for (p,n),(h,b) in nodes.items():
    if p!='장치' or 'position = Vector2' not in b:continue
    x,y=vec(b);px,py=xy(x,y)
    if 'script = ExtResource("grate")' in b:d.line([xy(x-96,y-8),xy(x+96,y-8)],fill='#7ad7ca',width=3)
    if '왕복톱' in n:d.ellipse((px-7,py-7,px+7,py+7),fill='#f07f73')
    if n.startswith('체크포인트'):d.ellipse((px-4,py-8,px+4,py),fill='#83e7a6')
    if 'script = ExtResource("water_art")' in b:
        w,hh=map(float,re.search(r'"크기" = Vector2\(([^,]+), ([^)]+)\)',b).groups());color='#f1f1eb' if '"색" = 1' in b else '#959ca6'
        d.rectangle([xy(x-w/2,y),xy(x+w/2,y+hh)],fill=color)
    if '"hopper"' in h:d.polygon([xy(x-160,y-164),xy(x+160,y-164),xy(x+35,y),xy(x-35,y)],fill='#a5a39c',outline='white')
route=[(768,4032),(2080,4032),(2304,3136),(960,3136),(640,3648),(2768,3648),(4064,3648),(4064,2880),(3024,2880),(2816,2112),(3104,1888),(6016,1888)]
for a,b in zip(route,route[1:]):
    pa,pb=xy(*a),xy(*b);d.line([pa,pb],fill='#f6c775',width=2)
    angle=math.atan2(pb[1]-pa[1],pb[0]-pa[0]);d.polygon([pb,(pb[0]-9*math.cos(angle-.45),pb[1]-9*math.sin(angle-.45)),(pb[0]-9*math.cos(angle+.45),pb[1]-9*math.sin(angle+.45))],fill='#f6c775')
for x,y,label in [(560,3950,'① 입구 →'),(1990,3520,'② 상승'),(820,3000,'③ 호퍼실 ←'),(800,3530,'④ 배수로 →'),(2650,3470,'⑤ 기계실 →'),(3120,2740,'⑥ 상부 통로 ←'),(3300,1770,'⑦ 출구 →')]:d.text(xy(x,y),label,font=small,fill='#ffe2a5')
d.text((24,15),'2-9 · 엇갈린 배수실 — 새 구역 연결 배치도',font=font,fill='white')
d.text((24,44),'저장된 씬 좌표 도식 / 실제 게임 화면 아님 · 민트: 복귀·상승 격자 · 빨강: 톱 · 녹색: 체크포인트',font=small,fill='#c1cbd8')
im.save('docs/stage29_rooms_layout.png')
